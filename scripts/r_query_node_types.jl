using AbstractTrees, EzXML
using Revise
using ParSitter

_R_file = (ParSitter.File(abspath(expanduser("~/vub/code/aivet/notes/extracted_code.r"))), "r")
_R_code = (
    ParSitter.Code(
        """
        mod13 <- glmmTMB(Center_ownership ~ Gender + Nationality + Income_quintile +
        				   P80P20 + Study_degree + ISCED_origin + Year +
        				   (1 | Family),
        			  data = practiques,
        			  family = binomial(link = "logit"))
        """
    ), "r",
)
#_parsed = ParSitter.parse(_PYTHON...)
#_parsed = ParSitter.parse(_C...)
_parsed = ParSitter.parse(_R_code...)

target = ParSitter.build_xml_tree(_parsed)

# "call@v_call"                             --> captures: glmmTMB
# ├─ "identifier"
# └─ "arguments"
#    └─ "argument"
#       ├─ "identifier@v_identifier"        --> captures: family
#       └─ "call"
#          ├─ "identifier@v_identifier2"    --> captures: binomial
#          └─ "arguments@v_arguments"       --> captures: (link = "logit")
query = ParSitter.build_tq_tree(
    (
        "call@v_call", "identifier", (
            "arguments", (
                "argument", "identifier@v_identifier",
                ("call", "identifier@v_identifier2", "arguments@v_arguments"),
            ),
        ),
    )
)

# Query helper functions
_target_nodevalue(n)::String = string(strip(n.name))
_query_nodevalue(n)::String = ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head, "@")[1]), string(n.head))
_apply_regex_glob(tn, qn)::Bool = ParSitter.is_capture_node(qn; capture_sym = "@").is_match && _query_nodevalue(qn) == "*"
_capture_function(n)::String = string(strip(n.content))

@time qr = ParSitter.query(
    target.root, query;
    match_type = :nonstrict,
    target_tree_nodevalue = _target_nodevalue,
    query_tree_nodevalue = _query_nodevalue,
    capture_function = _capture_function,
    node_comparison_yields_true = _apply_regex_glob
);

@time qr = ParSitter.query(
    target.root, query;
    match_type = :nonstrict,
    target_tree_nodevalue = _target_nodevalue,
    query_tree_nodevalue = _query_nodevalue,
    capture_function = _capture_function,
    node_comparison_yields_true = _apply_regex_glob
);

function search_for_term(query_results, t_key, t_value)
    findings = Dict{Int, EzXML.Node}()
    for (i, r) in enumerate(query_results)
        (match, captures, target_subtree) = r
        if match && any(s -> contains(s, t_value), get(captures, t_key, []))
            #println(i, ParSitter._strip_spaces((target_subtree.content, maxlen=150)))
            push!(findings, i => target_subtree)
        end
    end
    return findings
end

findings = search_for_term(qr, "v_call", "glmm")
tree_idxs = keys(findings) |> collect

for i in tree_idxs # iterate over matches
    _, _captures, _tree = qr[i]   # get stuff
    @info "v_identifier = \"$(_captures["v_identifier"] |> first)\""
    @info "v_identifier2 = \"$(_captures["v_identifier2"] |> first)\""
    @info "v_arguments = \"$(_captures["v_arguments"] |> first |> s -> ParSitter._strip_spaces(s, maxlen = 100))\""
    print("---")
    print_tree(last(qr[i]), maxdepth = 100)
end
