
"""
Modelo de apreçameno por árvore binomial
onde o time-step é casado com as datas de fechamento
entre a data de apreçamento e o vencimento da opção.

Utiliza como input uma curva de juros.
Apura a taxa risk-free para cada time-step da árvore
com base nas taxas forward da curva.
"""
module BinomialDaily

import BusinessDays, InterestRates
using Dates

struct AmericanCall
    riskfree_curve::InterestRates.IRCurve
    dividend_yield::Float64
    s0::Float64
    k::Float64
    σ::Float64
    pricing_date::Date
    maturity::Date
end

abstract type AbstractBinomialTree end

mutable struct TreeNode{T<:AbstractBinomialTree}
    current_time::Int
    node_number::Int
    s::Float64
    payoff::Float64
    tree::T
end

struct BinomialTree <: AbstractBinomialTree
    contract::AmericanCall
    days_to_maturity::Int
    u::Float64
    d::Float64
    forward_rates::Vector{Float64}
    risk_neutral_probabilities::Vector{Float64}
    nodes::Vector{Vector{TreeNode}}
end

"""
    volatility_match(σ, Δt)

Retorna tupla (u, d) para Árvore Binomial
baseado no procedimento de Volatility Match
proposto por Cox, Ross, Rubinstein (1979).
"""
function volatility_match(σ, Δt) :: Tuple{Float64, Float64}
    @assert σ >= 0 && Δt > 0

    u = exp(σ*sqrt(Δt))
    d = 1/u
    return u, d
end

function discountfactorforward(curve::InterestRates.AbstractIRCurve, d0::Date, d1::Date)
    @assert d0 <= d1
    return InterestRates.discountfactor(curve, d1) / InterestRates.discountfactor(curve, d0)
end

function daily_forward_rates_vector(curve::InterestRates.AbstractIRCurve, dividend_yield::Float64, pricing_date::Date, maturity::Date)
    @assert maturity >= pricing_date
    @assert InterestRates.curve_get_date(curve) == pricing_date
    CAL = BusinessDays.BRSettlement()
    @assert curve.daycount == InterestRates.BDays252(CAL) "Unsupported daycount: $(contract.daycount)."

    result = Vector{Float64}()
    d0 = pricing_date
    Δt_days = 1
    Δt_years = Δt_days / 252
    d1 = BusinessDays.advancebdays(CAL, d0, Δt_days)

    while d1 <= maturity
        df = discountfactorforward(curve, d0, d1)
        rate_continuous = -log(df) / Δt_years
        push!(result, rate_continuous - dividend_yield)

        # update d0, d1
        d0 = d1
        d1 = BusinessDays.advancebdays(CAL, d1, Δt_days)
    end

    return result
end

function risk_neutral_probabilities(rates::Vector{Float64}, u::Real, d::Real, Δt::Real)
    return [ (exp(r*Δt) - d) / (u - d) for r in rates ]
end

function new_fwd_node(t::BinomialTree, current_time, node_number)
    node = TreeNode(current_time, node_number, NaN, NaN, t)

    if node.current_time == 0
        # primeiro node
        node.s = t.contract.s0
    else
        @assert node.current_time > 0
        if node.node_number == 1
            # up
            previous_node = t.nodes[current_time][1]
            node.s = previous_node.s * t.u
        else
            # down
            previous_node = t.nodes[current_time][node.node_number-1]
            node.s = previous_node.s * t.d
        end
    end

    return node
end

# preenche nós da árvore, sem calcular o preço do derivativo
function fwd_prop!(t::BinomialTree)
    @assert isempty(t.nodes)

    for current_time in 0:t.days_to_maturity
        push!(t.nodes, [ new_fwd_node(t, current_time, node_number) for node_number in 1:(current_time+1) ])
    end
end

# preenche preço do derivativo, a partir do final da árvore
function backward_prop!(t::BinomialTree)
    @assert !isempty(t.nodes)
    Δt = 1.0 / 252

    # preenche payoff no vencimento
    for node in t.nodes[end]
        node.payoff = max(node.s - t.contract.k, 0)
    end

    # preenche payoff antes do vencimento
    for current_time in (t.days_to_maturity-1):-1:0
        for node in t.nodes[current_time + 1]
            @assert node.current_time == current_time
            payoff_up = t.nodes[ current_time + 2 ][node.node_number].payoff
            payoff_down = t.nodes[ current_time + 2 ][node.node_number + 1].payoff

            r = t.forward_rates[current_time + 1]
            q = t.risk_neutral_probabilities[current_time + 1]
            node.payoff = max( exp(-r*Δt) * ( q * payoff_up + (1 - q) * payoff_down), max(node.s - t.contract.k, 0) )
        end
    end
end

function gen_tree!(t::BinomialTree)
    fwd_prop!(t)
    backward_prop!(t)
end

function BinomialTree(contract::AmericanCall)
    Δt = 1.0 / 252 # fixo
    @assert contract.riskfree_curve.daycount == InterestRates.BDays252(BusinessDays.BRSettlement()) "Unsupported daycount: $(contract.daycount)."
    dtm = BusinessDays.bdayscount(BusinessDays.BRSettlement(), contract.pricing_date, contract.maturity)

    u, d = volatility_match(contract.σ, Δt)
    rates = daily_forward_rates_vector(contract.riskfree_curve, contract.dividend_yield, contract.pricing_date, contract.maturity)

    bin_tree = BinomialTree(
        contract,
        dtm,
        u,
        d,
        rates,
        risk_neutral_probabilities(rates, u, d, Δt),
        Vector{Vector{TreeNode}}()
    )

    gen_tree!(bin_tree)

    return bin_tree
end

end # module
