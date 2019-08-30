
using Dates, Test, InterestRates, BusinessDays, BinomialDaily

riskfree_curve = InterestRates.IRCurve(
    "PRE DI-Futuro",
    InterestRates.BDays252(BusinessDays.BRSettlement()),
    InterestRates.ExponentialCompounding(),
    InterestRates.CompositeInterpolation(
        InterestRates.StepFunction(),
        InterestRates.CubicSplineOnRates(),
        InterestRates.FlatForward()),
    Date(2019, 3, 29),
    [1,22,44,63,86,108,129,152,172,193,215,233,255,275,316,381,444,505,567,632,695,757,819,884,946,1009,1070,1134,1195,1319,1449,1571,1702,1824,1952,2203,2452,2702,2955],
    [0.064, 0.06415013117991042, 0.06417973562801271, 0.06435017514839836, 0.06445015923797404, 0.06459993834431654, 0.06484999204034181, 0.06480997675886191, 0.06506999165262828, 0.06519999136895538, 0.0654599725012075, 0.06575998157842933, 0.06580000619449722, 0.0665099646050511, 0.06750002305865621, 0.06959999412826634, 0.07140001991101319, 0.07330002695898763, 0.07490002252270211, 0.0764499878843945, 0.07779999563726014, 0.07915001506388308, 0.08020000734028843, 0.08129998530743787, 0.08239998748126108, 0.08335000809507619, 0.08419999789502874, 0.08424999969811629, 0.08539998951248663, 0.0865000058002896, 0.08749999511076754, 0.08815999505768035, 0.08889000821092165, 0.08950001399465336, 0.09060000539862599, 0.09169999004106222, 0.09219999087854959, 0.09270000052984508, 0.09301999267274486]
)

@testset "risk-free" begin
    # Valores da aba "curvas", coluna "PRE DI-Futuro"
    @test InterestRates.discountfactor(riskfree_curve, Date(2019, 3, 29)) == 1.0
    @test InterestRates.discountfactor(riskfree_curve, Date(2019, 4, 1)) ≈ 0.999753858
    @test InterestRates.discountfactor(riskfree_curve, Date(2020, 4, 15)) ≈ 0.935174661
    @test InterestRates.discountfactor(riskfree_curve, Date(2021, 6, 15)) ≈ 0.853443772
end

@testset "Volatility Match" begin
    vol = 0.3
    dt = 1.0
    @test BinomialDaily.volatility_match(vol, dt) == (1.3498588075760032, 0.7408182206817179)
end

@testset "fwd rates" begin
    rates = BinomialDaily.daily_forward_rates_vector(riskfree_curve, 0.0, Date(2019, 3, 29), Date(2021, 6, 15))

    # o primeiro elemento é igual ao fator de desconto spot para o primeiro dia de prazo
    @test rates[1] ≈ -log(0.999753858111698)

    # o produtório de todos os fatores de desconto é igual ao fator de desconto para o prazo final
    @test reduce(*, map(exp, -rates)) ≈ 0.8534437717820871
end

@testset "Kep" begin
    am_call = BinomialDaily.AmericanCall(
        riskfree_curve,
        0.0, # dividend_yield
        17.3, # stock spot price
        38.66, # strike
        0.439026837963, # volatility
        Date(2019, 3, 29), # pricing_date
        Date(2021, 6, 15)) # maturity

    bin_tree = BinomialDaily.BinomialTree(am_call)
end
