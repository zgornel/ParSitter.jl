using Aqua

@testset "Aqua.jl" begin
    Aqua.test_all(
        ParSitter;
        unbound_args = false,
        #ambiguities=(exclude=[ParSitter.convert], broken=true),
        stale_deps = (ignore = [:ArgParse, :JSON],),
        deps_compat = (check_extras = false, ignore = [:Logging, :Pkg, :Test]),
        piracies = false
    )
end
