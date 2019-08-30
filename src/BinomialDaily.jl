
"""
Modelo de apreçamento por árvore binomial
onde o time-step é casado com as datas de fechamento
entre a data de apreçamento e o vencimento da opção.

Utiliza como input uma curva de juros.
Apura a taxa risk-free para cada time-step da árvore
com base nas taxas forward da curva.
"""
module BinomialDaily

"""
    volatility_match(σ, Δt)

Retorna tupla (u, d) para Árvore Binomial
baseado no procedimento de Volatility Match
proposto por Cox, Ross, Rubinstein (1979).
"""
function volatility_match(σ, Δt) :: Tuple{Float64, Float64}
    @assert σ ≧ 0 && Δt > 0

    u = exp(σ*sqrt(Δt))
    d = 1/u
    return u, d
end

end # module
