@testset "Language support: Python" begin
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
        return ((ParSitter.is_capture_node(qn; capture_sym = "@").is_match &&
                                                   isempty(first(_query_nodevalue(qn)))
                                            ) || first(_query_nodevalue(qn)) == "*"
                                         ) && _target_nodevalue(tn)[2] == _query_nodevalue(qn)[2]
    end

    function _node_equality_function(n1, n2)
        return n1[2] == n2[2] && n1[1] == n2[1] # type and value equality
    end

    _code = (
        ParSitter.Code(
            """
            # a comment
            def foo(a, b, c):
                a = "vv"
                b = b+c
                c = bar(a,b, method=true)
                return c
            """))
    language = "python"

    # Strict querying
    @testset "match_type=:strict, partial arguments: (OK)" begin
        target = ParSitter.build_xml_tree(ParSitter.parse(_code, language))
        query_snippet = """
            def {{func_name::IDENTIFIER}}({{::IDENTIFIER}}):
                {{ex1::EXPRESSION}}
                {{ex2::EXPRESSION}}
        """

        generated_query, _aaa, _bbb = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        query_results = ParSitter.query(
            target.root,
            generated_query;
            match_type = :strict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _capture_on_empty_query_value,
            node_equality_function = _node_equality_function
        )
        filter!(first, query_results) # keep only matches
        @test length(query_results) == 0  # no match
    end
end
