using AbstractTrees, ParSitter

#_target_nodevalue(n) = strip(string(n.name))
_target_nodevalue(n) = (string.(strip(replace(n.content, r"[\s]" => ""))), n.name)
_query_nodevalue(n) = (ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head.value, "@")[1]), n.head.value), n.head.type)
_apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym = "@").is_match || qn.head.value == "*"
_capture_function(n) = (v = strip(replace(n.content, r"[\s]" => "")), srow = n["srow"], erow = n["erow"], scol = n["scol"], ecol = n["ecol"])
_capture_on_empty_query_value(tt, qt) = (ParSitter.is_capture_node(qt; capture_sym = "@").is_match && isempty(first(_query_nodevalue(qt)))) || first(_query_nodevalue(qt)) == "*"
_node_equality_function(n1, n2) = begin
    if n2[2] in ("string", "identifier")  # check query capturabile types
        #@info "$n1 $n2"
        return n1[2] == n2[2] && n1[1] == n2[1] # type and value equality
    else
        return n1[1] == n2[1]  # value equality
    end
end

_R_code = (
    ParSitter.Code(
        """# a comment
        mod12 <- glmmTMB(y ~ x1 + x2 + x3 + x4 + (0 | x5),
                 data = data_variable,
                 family = binomial(link = "linear"))
        """

    ), "r",
)
target = ParSitter.build_xml_tree(ParSitter.parse(_R_code...))
language = "r"
query_snippet = """
        {{algorithm::IDENTIFIER}}( {{target_variable::IDENTIFIER}}~{{dependent_variables::IDENTIFIER}}, data={{::IDENTIFIER}})

"""

generated_query, _aaa, _bbb = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
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
