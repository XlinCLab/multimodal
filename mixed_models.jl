using MixedModels

model = fit(MixedModel, @formula(surface ~ face + session + (1+face + session | participant)), target_gazes)
describe(target_gazes)
    print(summary(model))
    pvalues = coeftable(model).cols[4]
    print(pvalues)


model = fit(MixedModel, 
            @formula(surface ~ 1 + (1 | participant)), 
            target_gazes)