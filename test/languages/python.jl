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
        return (
            (
                ParSitter.is_capture_node(qn; capture_sym = "@").is_match &&
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
            from sklearn.svm import SVC
            from sklearn.preprocessing import StandardScaler
            from sklearn.datasets import make_classification
            from sklearn.model_selection import train_test_split
            from sklearn.pipeline import Pipeline
            X, y = make_classification(random_state=0)
            X_train, X_test, y_train, y_test = train_test_split(X, y, random_state=0)
            pipe = Pipeline([('scaler', StandardScaler()), ('svc', SVC())])
            pipe2 = sklearn.pipeline.Pipeline([('svc', SVC())])
            # The pipeline can be used as any other estimator
            # and avoids leaking the test set into the train set
            pipe.fit(X_train, y_train)
            pipe.fit(X_train, y_train).score(X_test, y_test)
            # An estimator's parameter can be set using '__' syntax
            pipe.set_params(svc__C=10).fit(X_train, y_train).score(X_test, y_test)
            """
        )
    )
    language = "python"
    target = ParSitter.build_xml_tree(ParSitter.parse(_code, language))

    #=
        Strict querying will not be used as it is generally useless in more
        complex and generic querying patterns due to the fact that it stops imediately
        after an error in matching subtrees. Unless much of the query contains exact
        syntax, so that the order of the tree nodes is kept the same  as in the
        target tree- which is a very rare occurence - it does not make
        sense testing it.
    =#


    @testset "query pattern 1 (function call, multiple returns)" begin
        query_snippet = "{{::IDENTIFIER}}, {{::IDENTIFIER}} = {{function::IDENTIFIER}}({{args::ARGUMENT_LIST}})"
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        @testset "match_type=:strict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["function"]) == 2  # matches 'make_classification', 'Pipeline'
            @test length(query_results[1][2]["args"]) == 2  # matches argument lists for 'make_classification', 'Pipeline'
        end

        @testset "match_type=:speculative (WRONG)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["function"]) == 1  # matches 'make_classification'
            @test length(query_results[1][2]["args"]) == 1  # matches argument list for 'make_classification'
        end

        @testset "match_type=:nonstrict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["function"]) == 2  # matches 'make_classification', 'Pipeline'
            @test length(query_results[1][2]["args"]) == 2  # matches argument lists for 'make_classification', 'Pipeline'
        end
    end


    @testset "query pattern 2-1 (object instantiation, function call)" begin
        query_snippet = "{{::IDENTIFIER}} = {{function::IDENTIFIER}}({{args::ARGUMENT_LIST}})"
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        @testset "match_type=:strict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["function"]) == 1  # matches 'Pipeline'
            @test length(query_results[1][2]["args"]) == 1
        end
        @testset "match_type=:speculative (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["function"]) == 1  # matches 'Pipeline'
            @test length(query_results[1][2]["args"]) == 1
        end

        @testset "match_type=:nonstrict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["function"]) == 1  # matches 'Pipeline'
            @test length(query_results[1][2]["args"]) == 1
        end
    end


    @testset "query pattern 2-2 (object instantiation, module+function call)" begin
        query_snippet = "{{::IDENTIFIER}} = {{lib::IDENTIFIER}}.{{sublib::IDENTIFIER}}.{{function::IDENTIFIER}}({{args::ARGUMENT_LIST}})"
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        @testset "match_type=:strict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1  # matches the 'pipe2 = sklearn.pipeline.Pipeline(...)' line
            @test length(query_results[1][2]["function"]) == 1  # matches 'Pipeline'
            @test length(query_results[1][2]["lib"]) == 1  # matches 'sklearn'
            @test length(query_results[1][2]["sublib"]) == 1  # matches 'pipeline'
            @test length(query_results[1][2]["args"]) == 1
        end
        @testset "match_type=:speculative (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1  # matches the 'pipe2 = sklearn.pipeline.Pipeline(...)' line
            @test length(query_results[1][2]["function"]) == 1  # matches 'Pipeline'
            @test length(query_results[1][2]["lib"]) == 1  # matches 'sklearn'
            @test length(query_results[1][2]["sublib"]) == 1  # matches 'pipeline'
            @test length(query_results[1][2]["args"]) == 1
        end

        @testset "match_type=:nonstrict (WRONG)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1  # matches the 'pipe2 = sklearn.pipeline.Pipeline(...)' line
            @test length(query_results[1][2]["function"]) == 1  # matches 'Pipeline'
            @test length(query_results[1][2]["lib"]) == 2 # matches 'sklearn' and 'pipeline', WRONG, due to combinatoric search
            @test length(query_results[1][2]["sublib"]) == 2  # matches 'pipeline' and 'sklearn', WRONG, due to combinatoric search
            @test length(query_results[1][2]["args"]) == 1
        end
    end


    @testset "query pattern 3 (parameter capture in object instantiation)" begin
        query_snippet = "{{::IDENTIFIER}} = Pipeline( [ ({{::STRING}}, {{pipe_object::IDENTIFIER}}()) ] )"
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        @testset "match_type=:strict (OK, all matches)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["pipe_object"]) == 2  # matches 'StandardScaler' and 'SVC'
            @test isempty(setdiff(map(x -> x.v, query_results[1][2]["pipe_object"]), ["SVC", "StandardScaler"]))  # matches 'StandardScaler'
        end
        @testset "match_type=:speculative (OK, first match)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["pipe_object"]) == 1  # matches 'StandardScaler'
            @test query_results[1][2]["pipe_object"][1].v == "StandardScaler"  # matches 'StandardScaler'
        end

        @testset "match_type=:nonstrict (OK, all matches)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["pipe_object"]) == 2  # matches 'StandardScaler' and 'SVC'
            @test isempty(setdiff(map(x -> x.v, query_results[1][2]["pipe_object"]), ["SVC", "StandardScaler"]))  # matches 'StandardScaler'
        end
    end


    @testset "query pattern 4 (object method call)" begin
        query_snippet = "{{object::IDENTIFIER}}.fit({{args::ARGUMENT_LIST}})"
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        @testset "match_type=:strict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["object"]) == 1  # matches 'pipe'
            @test query_results[1][2]["object"][1].v == "pipe"
        end
        @testset "match_type=:speculative (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["object"]) == 1  # matches 'pipe'
            @test query_results[1][2]["object"][1].v == "pipe"
        end

        @testset "match_type=:nonstrict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["object"]) == 1  # matches 'pipe'
            @test query_results[1][2]["object"][1].v == "pipe"
        end
    end


    @testset "query pattern 5 (symbol capture in from import)" begin
        query_snippet = "from {{::IDENTIFIER}}.{{::IDENTIFIER}} import {{symbol::DOTTED_NAME}}"
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        @testset "match_type=:strict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["symbol"]) == 5  # matches all imported symbols
            @test isempty(
                setdiff(
                    map(x -> x.v, query_results[1][2]["symbol"]),
                    ["SVC", "StandardScaler", "make_classification", "train_test_split", "Pipeline"]
                )
            )  # matches all imported symbols
        end

        @testset "match_type=:speculative (WRONG)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["symbol"]) == 1  # matches only 'SVC' (i.e. first 'from' statement)
            @test query_results[1][2]["symbol"][1].v == "SVC"
        end

        @testset "match_type=:nonstrict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["symbol"]) == 5  # matches all imported symbols
            @test isempty(
                setdiff(
                    map(x -> x.v, query_results[1][2]["symbol"]),
                    ["SVC", "StandardScaler", "make_classification", "train_test_split", "Pipeline"]
                )
            )  # matches all imported symbols
        end
    end


    @testset "query pattern 6 (imported library capture in from import)" begin
        query_snippet = "from {{library::DOTTED_NAME}} import {{::IDENTIFIER}}"
        generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
        @testset "match_type=:strict (OK)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["library"]) == 5  # matches all importing libraries
            @test isempty(
                setdiff(
                    map(x -> x.v, query_results[1][2]["library"]),
                    [
                        "sklearn.svm", "sklearn.preprocessing", "sklearn.datasets",
                        "sklearn.model_selection", "sklearn.pipeline",
                    ]
                )
            )
        end

        @testset "match_type=:speculative (WRONG)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["library"]) == 1  # matches only 'sklearn.svm' (i.e. first 'from' statement)
            @test query_results[1][2]["library"][1].v == "sklearn.svm"
        end

        @testset "match_type=:nonstrict (WRONG)" begin
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
            filter!(first, query_results)
            @test length(query_results) == 1
            @test length(query_results[1][2]["library"]) == 10  # matches both importing libraries and imported symbols
        end
    end
end
