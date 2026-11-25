using Aqua

@testset "Aqua.jl" begin
    Aqua.test_all(
        ParSitter;
        piracies = false,
        persistent_tasks = (tmax = 10,)
    )
end
