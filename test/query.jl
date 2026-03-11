# Define utiliy function for the types of trees and node captures used
_capture_function(target_node) = target_node.head

_target_tree_nodevalue(target_node) = string(target_node.head)

_query_tree_nodevalue(query_node) =
    ParSitter.is_capture_node(query_node).is_match ? split(query_node.head, "@")[1] : query_node.head

# Functions that will always capture when reaching query nodes of the form: "@query_key"
_capture_on_empty_query_value(tt, qt) =
    (
    ParSitter.is_capture_node(qt; capture_sym = "@").is_match
        && isempty(_query_tree_nodevalue(qt))
) ||
    _query_tree_nodevalue(qt) == "*"


@testset "match_type==:strict quering" begin
    @testset "case 1" begin
        target = ParSitter.build_tq_tree(
            (1, 2)
        )
        query = ParSitter.build_tq_tree(
            (1, 2)
        )
        results = ParSitter.query(target, query; match_type = :strict)
        @test sum(first, results) == 1
        @test sum(p -> !isempty(p[2]), results) == 0
    end
    @testset "case 2" begin
        target = ParSitter.build_tq_tree(
            (1, 2)
        )
        query = ParSitter.build_tq_tree(
            ("@v1", "@v2")
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :strict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 1
        for (is_match, captures) in results
            if is_match
                @test only(get(captures, "v1", -1)) == 1
                @test only(get(captures, "v2", -1)) == 2
                @test length(keys(captures)) == 2
            end
        end
    end
    @testset "case 3" begin
        target = ParSitter.build_tq_tree(
            (1, (2, 3, "3a"), (4, 5), 6)
        )
        query = ParSitter.build_tq_tree(
            ("@v0", ("2", "@v2", "3a"))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :strict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test any(first, results)
        for (is_match, captures) in results
            if is_match
                @test only(get(captures, "v0", -1)) == 1
                @test only(get(captures, "v2", -1)) == 3
                @test length(keys(captures)) == 2
            end
        end
    end
    @testset "case 4" begin
        target = ParSitter.build_tq_tree(
            (1, (2, 3), (2, (2, 3)))
        )
        query = ParSitter.build_tq_tree(
            (2, 3)
        )
        results = ParSitter.query(target, query; match_type = :strict)
        @test sum(first, results) == 2
        @test sum(p -> !isempty(p[2]), results) == 0  # no captured values
    end
    @testset "case 5" begin
        target = ParSitter.build_tq_tree(
            (1, 2, 3, (4, 2, 6, (1, 2, 1)), ("@v0", 2, "@v2"))
        )
        query = ParSitter.build_tq_tree(
            ("@v0", "2", "@v2")
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :strict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 4
        @test sum(p -> !isempty(p[2]), results) == 3
        expected_captures = [
            MultiDict("v2" => 3, "v0" => 1),
            MultiDict("v2" => 6, "v0" => 4),
            MultiDict("v2" => 1, "v0" => 1),
            MultiDict(),
        ]
        for (is_match, captures) in results
            if is_match
                @test captures in expected_captures
            end
        end
    end
end


@testset "match_type==:nonstrict quering" begin
    @testset "case 1" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "@v1"
        # └─ "@v2"
        # will match from the target:
        # 	1->2 or 1->3 or 1->-3  # thats a single match (starting at root of tree)
        #   3->4, -3->-4, 4->5  # three distict matches (subtrees)
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("@v1", "@v2")
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 4
        @test sum(p -> !isempty(p[2]), results) == 4

        expected_captures = [
            MultiDict(["v1" => 1, ["v2" => v for v in [2, 3, -3]]...]),
            MultiDict("v2" => 4, "v1" => 3),
            MultiDict("v2" => -4, "v1" => -3),
            MultiDict("v2" => 5, "v1" => 4),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
    @testset "case 2" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        #"@v1"
        #└─ "@v2"
        #   └─ "@v3"
        # will match from the target:
        # 	1->3->4 or 1->-3->-4 # thats a single match (starting at root of tree)
        #   3->4->5  # another tree (subtrees)
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("@v1", ("@v2", "@v3"))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 2  # two full matches
        @test sum(p -> !isempty(p[2]), results) == 2

        expected_captures = [
            MultiDict(
                [
                    "v1" => 1,
                    ["v2" => v for v in [3, -3]]...,
                    ["v3" => v for v in [4, -4]]...,
                ]
            ),
            MultiDict("v2" => 4, "v1" => 3, "v3" => 5),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
    @testset "case 3" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "@v1"
        # └─ "3"
        #    └─ "@v3"
        #          └─ "5"
        # will match from the target:
        # 	1->3->4->5
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("@v1", ("3", ("@v3", "5")))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 1  # the only match
        @test sum(p -> !isempty(p[2]), results) == 1

        expected_captures = [
            MultiDict("v3" => 4, "v1" => 1),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
    @testset "case 4" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "@v1"
        # └─ "@v2"
        #    ├─ "4"
        #    └─ "5"
        # will NOT match from the target:
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("@v1", ("@v2", "4", "5"))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 0  # no match
        @test sum(p -> !isempty(p[2]), results) == 2
    end
    @testset "case 5: unordered query" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "1"
        # ├─ "-3"
        # │  └─ "*"
        # └─ "3"
        #    └─ "*"
        #       └─ "@v"
        # will match
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("1", ("-3", "*"), ("3", ("*", "@v")))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 1  # match
        expected_captures = [
            MultiDict("v" => 5),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
    @testset "case 6: ambiguous query" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "*"
        # ├─ "*"
        # │  └─ "*"
        # └─ "*"
        #    └─ "@v"
        # will match however match could be either v=4 or v=-4
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("*", ("*", "*"), ("*", ("@v")))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 1  # match
        expected_captures = [
            MultiDict([["v" => v for v in [-4, 4]]...]),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
end


@testset "match_type==:speculative quering" begin
    @testset "case 1" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "@v1"
        # └─ "@v2"
        # will match from the target:
        # 	1->2 or 1->3 or 1->-3  # thats a single match (starting at root of tree)
        #   3->4, -3->-4, 4->5  # three distict matches (subtrees)
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("@v1", "@v2")
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :speculative,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 4
        @test sum(p -> !isempty(p[2]), results) == 4

        expected_captures = [
            (MultiDict("v1" => 1, "v2" => v2) for v2 in [2, 3, -3])...,
            MultiDict("v2" => 4, "v1" => 3),
            MultiDict("v2" => -4, "v1" => -3),
            MultiDict("v2" => 5, "v1" => 4),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
    @testset "case 2" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        #"@v1"
        #└─ "@v2"
        #   └─ "@v3"
        # will match from the target:
        # 	1->3->4 or 1->-3->-4 # thats a single match (starting at root of tree)
        #   3->4->5  # another tree (subtrees)
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("@v1", ("@v2", "@v3"))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :speculative,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 2  # two full matches
        @test sum(p -> !isempty(p[2]), results) == 2

        expected_captures = [
            MultiDict("v1" => 1, "v2" => 3, "v3" => 4),
            MultiDict("v1" => 1, "v2" => 3, "v3" => 4),
            MultiDict("v2" => 4, "v1" => 3, "v3" => 5),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
    @testset "case 3" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "@v1"
        # └─ "3"
        #    └─ "@v3"
        #          └─ "5"
        # will match from the target:
        # 	1->3->4->5
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("@v1", ("3", ("@v3", "5")))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :speculative,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 1  # the only match
        @test sum(p -> !isempty(p[2]), results) == 1

        expected_captures = [
            MultiDict("v3" => 4, "v1" => 1),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
    @testset "case 4" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "@v1"
        # └─ "@v2"
        #    ├─ "4"
        #    └─ "5"
        # will NOT match from the target:
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("@v1", ("@v2", "4", "5"))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :speculative,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 0  # no match
        @test sum(p -> !isempty(p[2]), results) == 2
    end
    @testset "case 5: unordered query" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "1"
        # ├─ "-3"
        # │  └─ "*"
        # └─ "3"
        #    └─ "*"
        #       └─ "@v"
        # will match
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("1", ("-3", "*"), ("3", ("*", "@v")))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :speculative,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 1  # match
        expected_captures = [
            MultiDict("v" => 5),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
    @testset "case 6: ambiguous query" begin
        # target:
        # 1
        # ├─ 2
        # ├─ 3
        # │  └─ 4
        # │     └─ 5
        # └─ -3
        #    └─ -4
        # query:
        # "*"
        # ├─ "*"
        # │  └─ "*"
        # └─ "*"
        #    └─ "@v"
        # will match however match could be either v=4 or v=-4
        target = ParSitter.build_tq_tree(
            (1, 2, (3, (4, 5)), (-3, -4))
        )
        query = ParSitter.build_tq_tree(
            ("*", ("*", "*"), ("*", ("@v")))
        )
        results = ParSitter.query(
            target,
            query;
            match_type = :speculative,
            target_tree_nodevalue = _target_tree_nodevalue,
            query_tree_nodevalue = _query_tree_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        @test sum(first, results) == 1  # match
        expected_captures = [
            MultiDict("v" => -4),
            MultiDict("v" => 4),
        ]
        for (is_match, captures) in results
            if is_match
                _captures = MultiDict{String, Int}(string(k) => Int.(v) for (k, v) in captures)
                @test _captures in expected_captures
            end
        end
    end
end
