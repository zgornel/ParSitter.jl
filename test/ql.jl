@testset "Query language (R support)" begin
    # Query helper functions
    #_target_nodevalue(n) = strip(string(n.name))
    _target_nodevalue(n) = strip(replace(n.content, r"[\s]" => ""))
    _query_nodevalue(n) = ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head, "@")[1]), n.head)
    _apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym = "@").is_match || qn.head == "*"
    _capture_function(n) = (v = strip(replace(n.content, r"[\s]" => "")), srow = n["srow"], erow = n["erow"], scol = n["scol"], ecol = n["ecol"])
    R_code = ParSitter.Code(
        """
        # a comment
        mod12 <- glmmTMB(y ~ x1 + x2 + x3 + x4 + (0 | x5),
                         data = data_variable,
                         family = binomial(link = "linear"))
        """
    )
    language = "r"

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
            node_comparison_yields_true = _apply_regex_glob
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
            node_comparison_yields_true = _apply_regex_glob
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
            node_comparison_yields_true = _apply_regex_glob
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
            node_comparison_yields_true = _apply_regex_glob
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
            node_comparison_yields_true = _apply_regex_glob
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
            node_comparison_yields_true = _apply_regex_glob
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
end
