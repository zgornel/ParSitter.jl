@testset "utils: prune!" begin
    @testset "case 1" begin
        tt = build_tq_tree((1, 2, 3, (1, 2), 1, (4, (5, 1))))
        ParSitter.prune!(tt, 1)
        @test tt == build_tq_tree((1, 2, 3, (4, 5)))
    end

    @testset "case 1-string" begin
        tt = build_tq_tree((1, 2, 3, (1, 2), 1, (4, (5, 1))))
        ParSitter.prune!(tt, "1", nodevalue_function = n -> string(n.head))
        @test tt == build_tq_tree((1, 2, 3, (4, 5)))
    end

    @testset "case 2" begin
        tt = build_tq_tree((1, 2, 3, (1, 2), 1, (4, (5, 1))))
        ParSitter.prune!(tt, 2)
        @test tt == build_tq_tree((1, 3, 1, 1, (4, (5, 1))))
    end

    @testset "case 2-string" begin
        tt = build_tq_tree((1, 2, 3, (1, 2), 1, (4, (5, 1))))
        ParSitter.prune!(tt, "2", nodevalue_function = n -> string(n.head))
        @test tt == build_tq_tree((1, 3, 1, 1, (4, (5, 1))))
    end

end


