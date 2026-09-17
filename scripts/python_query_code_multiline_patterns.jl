using ParSitter, AbstractTrees

# Define helper functions
_target_nodevalue(n) = (string.(strip(replace(n.content, r"[\s]" => ""))), n.name)
_query_nodevalue(n) = (ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head.value, "@")[1]), n.head.value), n.head.type)
_apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym = "@").is_match || qn.head.value == "*"
_capture_function(n) = (v = strip(replace(n.content, r"[\s]" => "")), srow = n["srow"], erow = n["erow"], scol = n["scol"], ecol = n["ecol"])
_capture_on_empty_query_value(tt, qt) = (
    (
        ParSitter.is_capture_node(qt; capture_sym = "@").is_match &&
            isempty(first(_query_nodevalue(qt)))
    ) || first(_query_nodevalue(qt)) == "*"
) && _target_nodevalue(tt)[2] == _query_nodevalue(qt)[2]

_node_equality_function(n1, n2) = begin
    return n1[2] == n2[2] && n1[1] == n2[1] # type and value equality
end

# Two-liner patterns
code = """
from sklearn import linear_model
clf = linear_model.MultiTaskElasticNet(alpha=0.1)            # FIRST PART
clf.fit([[0,0], [1, 1], [2, 2]], [[0, 0], [1, 1], [2, 2]])   # SECOND PART
"""

target = ParSitter.build_xml_tree(ParSitter.parse(ParSitter.Code(code), "python"))
OBJ_IDENTIFIER = "obj"
queries_obj = [
    "{{$OBJ_IDENTIFIER::IDENTIFIER}} = {{::IDENTIFIER}}.{{func::IDENTIFIER}}({{::ARGUMENT_LIST}})",
    "{{$OBJ_IDENTIFIER::IDENTIFIER}} = {{::IDENTIFIER}}.{{::IDENTIFIER}}{{func::IDENTIFIER}}({{::ARGUMENT_LIST}})",
    "{{$OBJ_IDENTIFIER::IDENTIFIER}} = {{func::IDENTIFIER}}({{::ARGUMENT_LIST}})",
]
query_obj_exprs = map(x -> first(parse_code_snippet_to_query(x, "python")), queries_obj)

obj_results = []
for (i, q) in enumerate(query_obj_exprs)
    results = ParSitter.query(
        target.root,
        q;
        match_type = :strict,
        target_tree_nodevalue = _target_nodevalue,
        query_tree_nodevalue = _query_nodevalue,
        capture_function = _capture_function,
        node_comparison_yields_true = _capture_on_empty_query_value,
        node_equality_function = _node_equality_function
    )
    filter!(first, results)
    if !isempty(results)
        println("OK for query: \"$(queries_obj[i])\"")
        #print_tree(q, maxdepth=20)
        #@info results
        capture_info = map(x -> (string(x.v), parse(Int, x.srow), parse(Int, x.scol)), results[1][2][OBJ_IDENTIFIER])
        append!(obj_results, capture_info)
    end
end

queries_fitcall = [
    "{{::IDENTIFIER}} = {{$OBJ_IDENTIFIER::IDENTIFIER}}.fit({{::ARGUMENT_LIST}})",
    "{{$OBJ_IDENTIFIER::IDENTIFIER}}.fit({{::ARGUMENT_LIST}})",
]
query_fitcall_exprs = map(x -> first(parse_code_snippet_to_query(x, "python")), queries_fitcall)
fitcall_results = []
for (i, q) in enumerate(query_fitcall_exprs)
    results = ParSitter.query(
        target.root,
        q;
        match_type = :strict,
        target_tree_nodevalue = _target_nodevalue,
        query_tree_nodevalue = _query_nodevalue,
        capture_function = _capture_function,
        node_comparison_yields_true = _capture_on_empty_query_value,
        node_equality_function = _node_equality_function
    )
    filter!(first, results)
    if !isempty(results)
        println("OK for query: \"$(queries_obj[i])\"")
        #print_tree(q, maxdepth=20)
        #@info results
        capture_info = map(x -> (string(x.v), parse(Int, x.srow), parse(Int, x.scol)), results[1][2][OBJ_IDENTIFIER])
        append!(fitcall_results, capture_info)
    end
end

# Reconciliation stage
for (inst_obj, inst_srow, inst_scol) in obj_results
    for (fitcall_obj, fitcall_srow, fitcall_scol) in fitcall_results
        if inst_obj == fitcall_obj &&
                (inst_srow < fitcall_srow || (inst_srow == fitcall_srow && inst_scol < fitcall_scol))
            println("Found `fit` method call for object `$inst_obj` at row:$fitcall_srow, col:$fitcall_scol")
        end
    end
end
