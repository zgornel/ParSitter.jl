using AbstractTrees, ParSitter

#_target_nodevalue(n) = strip(string(n.name))
_target_nodevalue(n) = (string.(strip(replace(n.content, r"[\s]" => ""))), n.name)
_query_nodevalue(n) = (ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head.value, "@")[1]), n.head.value), n.head.type)
_apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym = "@").is_match || qn.head.value == "*"
_capture_function(n) = (v = strip(replace(n.content, r"[\s]" => "")), srow = n["srow"], erow = n["erow"], scol = n["scol"], ecol = n["ecol"])
_capture_on_empty_query_value(tt, qt) = ((ParSitter.is_capture_node(qt; capture_sym = "@").is_match &&
                                                   isempty(first(_query_nodevalue(qt)))
                                            ) || first(_query_nodevalue(qt)) == "*"
                                         ) && _target_nodevalue(tt)[2] == _query_nodevalue(qt)[2]

_node_equality_function(n1, n2) = begin
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
target = ParSitter.build_xml_tree(ParSitter.parse(_code, language))
query_snippet = """
    def {{func_name::IDENTIFIER}}({{::IDENTIFIER}}):
        {{ex1::EXPRESSION}}
        {{ex2::EXPRESSION}}
"""

generated_query, _aaa, _bbb = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
print_tree(generated_query, maxdepth=20)
@info generated_query
@time query_results = ParSitter.query(
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
if isempty(query_results)
    println("No query results")
else
    for r in query_results
        @info r[1:2]
    end
end
