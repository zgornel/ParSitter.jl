@testset "Query language" begin
    # Query helper functions
    #_target_nodevalue(n) = strip(string(n.name))
    _target_nodevalue(n) = strip(replace(n.content, r"[\s]" => ""))
    _query_nodevalue(n) = ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head, "@")[1]), n.head)
    _apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym = "@").is_match || qn.head == "*"
    _capture_function(n) = (v = strip(replace(n.content, r"[\s]" => "")), srow = n["srow"], erow = n["erow"], scol = n["scol"], ecol = n["ecol"])

    @testset "R language: " begin
        _R_code = (
            ParSitter.Code(
                """
                mod12 <- glmmTMB(Center_ownership ~ Gender + Nationality + Income_quintile +
                                                   P79P20 + Study_degree + ISCED_origin + Year +
                                                   (0 | Family),
                                          data = practiques,
                                          family = binomial(link = "linear"))
                """
            ), "r",
        )
        _parsed = ParSitter.parse(_R_code...)
        _parsed = first(values(_parsed))
        target = ParSitter.build_xml_tree(_parsed)

        language = "r"
        query_snippet = """
                {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                          family ={{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}))
        """
        generated_query = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)

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

        CORRECT_CAPTURES = ["family" => "binomial", "id_val" => "\"linear\"", "identifier" => "link"]
        _, qres = first(query_results)
        @test length(keys(qres)) == 3  # there are 3 capture patterns
        for (k, correct_val) in CORRECT_CAPTURES
            @test qres[k][1].v == correct_val
        end
    end
end
