@testset "Language support: R" begin
    # Query helper functions
    function _target_nodevalue(n)
        return (
            string.(strip(replace(n.content, r"[\s]" => ""))), # node content (string with spaces removed)
            n.name,  # tree-sitter type
        )
    end

    function _query_nodevalue(n)
        _node_value = if ParSitter.is_capture_node(n).is_match
            string(split(n.head.value, "@")[1])
        else
            n.head.value
        end
        return _node_value, n.head.type  # node value and type
    end

    function _capture_function(n)
        return (
            v = strip(replace(n.content, r"[\s]" => "")),
            srow = n["srow"],
            erow = n["erow"],
            scol = n["scol"],
            ecol = n["ecol"],
        )
    end

    function _capture_on_empty_query_value(tn, qn)
        return (
            ParSitter.is_capture_node(qn; capture_sym = "@").is_match &&
                isempty(first(_query_nodevalue(qn)))
        ) ||
            first(_query_nodevalue(qn)) == "*"
    end

    function _node_equality_function(n1, n2)
        if n2[2] in ("string", "identifier")  # check query capturabile types
            return n1[2] == n2[2] && n1[1] == n2[1] # type and value equality
        else
            return n1[1] == n2[1]  # value equality
        end
    end

    R_code = ParSitter.Code(
        """
        # a comment
        mod12 <- glmmTMB(y ~ x1 + x2 + x3 + x4 + (0 | x5),
                         data = data_variable,
                         family = binomial(link = "linear"))
        """
    )
    language = "r"

    # Strict querying
    @testset "match_type=:strict, partial arguments: (NO MATCHES)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
                {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                          family ={{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}))
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :strict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 0  # no match
    end

    @testset "match_type=:strict, unordered arguments: (NO MATCHES)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
         {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                      family = {{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}),
                                      data = {{data::IDENTIFIER}})
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :strict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 0  # no match
    end

    @testset "match_type=:strict, ordered arguments: (OK)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
         {{comment::COMMENT}}
         {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                      data = {{data::IDENTIFIER}},
                                      family = {{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}))
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :strict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match

        CORRECT_CAPTURES = [
            "family" => "binomial",
            "id_val" => "\"linear\"",
            "identifier" => "link",
            "data" => "data_variable",
            "comment" => "#acomment",
        ]  # no spaces in comments
        _, qres = first(query_results)
        @test length(keys(qres)) == 5
        for (k, correct_val) in CORRECT_CAPTURES
            @test qres[k][1].v == correct_val
        end
    end

    # Non-strict querying
    @testset "match_type=:nonstrict, partial arguments: (OK)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
                {{comment::COMMENT}}
                {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                          family ={{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}))
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match

        CORRECT_CAPTURES = [
            "family" => "binomial",
            "id_val" => "\"linear\"",
            "identifier" => "link",
            "comment" => "#acomment",
        ]  # no spaces in comments
        _, qres = first(query_results)
        @test length(keys(qres)) == 4  # there are 3 capture patterns
        for (k, correct_val) in CORRECT_CAPTURES
            @test qres[k][1].v == correct_val
        end
    end

    @testset "match_type=:nonstrict, unordered arguments: (OK)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
         {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                      family = {{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}),
                                      data = {{data::IDENTIFIER}})
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match

        CORRECT_CAPTURES = ["family" => "binomial", "id_val" => "\"linear\"", "identifier" => "link", "data" => "data_variable"]
        _, qres = first(query_results)
        @test length(keys(qres)) == 4
        for (k, correct_val) in CORRECT_CAPTURES
            @test qres[k][1].v == correct_val
        end
    end

    @testset "match_type=:nonstrict, ordered arguments: (OK)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
         {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                      data = {{data::IDENTIFIER}},
                                      family = {{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}))
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match

        CORRECT_CAPTURES = ["family" => "binomial", "id_val" => "\"linear\"", "identifier" => "link", "data" => "data_variable"]
        _, qres = first(query_results)
        @test length(keys(qres)) == 4
        for (k, correct_val) in CORRECT_CAPTURES
            @test qres[k][1].v == correct_val
        end
    end

    @testset "match_type=:nonstrict, custom node equality" begin
        R_code_2 = ParSitter.Code(
            """
            # a comment
            z <- "AA"
            y <- "BB"
            """
        )
        language = "r"
        _parsed = ParSitter.parse(R_code_2, language)
        target = ParSitter.build_xml_tree(_parsed)
        query_snippet = """
            {{::IDENTIFIER}} <- {{a_string::STRING}}
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value,
            node_equality_function = _node_equality_function
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match
        @test length(query_results[1][2]["a_string"]) == 2 # both "AA" and "BB" captured
    end

    # Speculative querying
    @testset "match_type=:speculative, partial arguments: (OK)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
                {{comment::COMMENT}}
                {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                          family ={{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}))
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :speculative,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value,
            node_equality_function = _node_equality_function
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match

        CORRECT_CAPTURES = [
            "family" => "binomial",
            "id_val" => "\"linear\"",
            "identifier" => "link",
            "comment" => "#acomment",
        ]  # no spaces in comments
        _, qres = first(query_results)
        @test length(keys(qres)) == 4
        for (k, correct_val) in CORRECT_CAPTURES
            @test qres[k][1].v == correct_val
        end
    end

    @testset "match_type=:speculative, unordered arguments: (OK)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
         {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                      family = {{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}),
                                      data = {{data::IDENTIFIER}})
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :speculative,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value,
            node_equality_function = _node_equality_function
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match

        CORRECT_CAPTURES = ["family" => "binomial", "id_val" => "\"linear\"", "identifier" => "link", "data" => "data_variable"]
        _, qres = first(query_results)
        @test length(keys(qres)) == 4
        for (k, correct_val) in CORRECT_CAPTURES
            @test qres[k][1].v == correct_val
        end
    end

    @testset "match_type=:speculative, ordered arguments: (OK)" begin
        _parsed = ParSitter.parse(R_code, language)
        target = ParSitter.build_xml_tree(_parsed)

        query_snippet = """
         {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                      data = {{data::IDENTIFIER}},
                                      family = {{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}))
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :speculative,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match

        CORRECT_CAPTURES = ["family" => "binomial", "id_val" => "\"linear\"", "identifier" => "link", "data" => "data_variable"]
        _, qres = first(query_results)
        @test length(keys(qres)) == 4
        for (k, correct_val) in CORRECT_CAPTURES
            @test qres[k][1].v == correct_val
        end
    end

    @testset "match_type=:speculative, test correct capturing" begin
        test_val = "AA"
        R_code_2 = ParSitter.Code(
            """
            # a comment
            z <- "$test_val"
            y <- "BB"
            """
        )
        language = "r"
        _parsed = ParSitter.parse(R_code_2, language)
        target = ParSitter.build_xml_tree(_parsed)
        query_snippet = """
            z <- {{a_string::STRING}}
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :speculative,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match
        @test first(get_capture(query_results, "a_string")).v == "\"$test_val\""
    end

    @testset "match_type=:speculative, custom node equality" begin
        R_code_2 = ParSitter.Code(
            """
            # a comment
            z <- "AA"
            y <- "BB"
            """
        )
        language = "r"
        _parsed = ParSitter.parse(R_code_2, language)
        target = ParSitter.build_xml_tree(_parsed)
        query_snippet = """
            {{::IDENTIFIER}} <- {{a_string::STRING}}
        """
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :speculative,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value,
            node_equality_function = _node_equality_function
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 1  # single match
        @test length(query_results[1][2]["a_string"]) == 1  # either "AA" or "BB" captured
    end
end

