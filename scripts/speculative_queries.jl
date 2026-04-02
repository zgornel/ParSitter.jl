using ParSitter
using AbstractTrees

# Define utiliy function for the types of trees and node captures used
_capture_function(target_node) = target_node.head
_target_tree_nodevalue(target_node) = string(target_node.head)
_query_tree_nodevalue(query_node) = ParSitter.is_capture_node(query_node).is_match ? string(split(query_node.head, "@")[1]) : query_node.head
# Functions that will always capture when reaching query nodes of the form: "@query_key"
_capture_on_empty_query_value(tt, qt) =
    (
    ParSitter.is_capture_node(qt; capture_sym = "@").is_match && isempty(_query_tree_nodevalue(qt))
) || _query_tree_nodevalue(qt) == "*"


target = ParSitter.build_tq_tree((1, 2, (3, (-4, 5), 10, 12, -2, (4, 5)), (-3,), (-10, 11), (12, 11, 45)))
query = ParSitter.build_tq_tree(("*", "*", "*", ("*", ("@v1", "*"))))
#@enter ParSitter.match_tree(
results = ParSitter.match_tree(
    target,
    query;
    match_type = :speculative,
    target_tree_nodevalue = _target_tree_nodevalue,
    query_tree_nodevalue = _query_tree_nodevalue,
    capture_function = _capture_function,
    node_comparison_yields_true = _capture_on_empty_query_value
)
print_tree(target)
print_tree(query)
println("Match: $(results[1]); values = $(results[2])")
