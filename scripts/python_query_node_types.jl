# Run this with `julia --project ./scripts/tq_trees_query_example.jl`
using AbstractTrees, EzXML
using Revise
using ParSitter

_PYTHON = (ParSitter.File(abspath("./test/code/python/test_project/main.py")), "python")
_C = (ParSitter.File(abspath("./test/code/c/test_pass_value_lib/test_pass_value.c")), "c")

_parsed = ParSitter.parse(_PYTHON...)
#_parsed_c = ParSitter.parse(_C...)

target = ParSitter.build_xml_tree(_parsed)
#print_tree(target.root, maxdepth=20)

# ("module", "Ptr{EzXML._Node} @0x000055bdc0d73350")
# ├─ ("import_from_statement", "Ptr{EzXML._Node} @0x000055bdbca669c0")
# │  ├─ ("dotted_name", "Ptr{EzXML._Node} @0x000055bdc712c000")
# │  │  └─ ("identifier", "Ptr{EzXML._Node} @0x000055bdc54f2180")
# │  └─ ("dotted_name", "Ptr{EzXML._Node} @0x000055bdbdaacf90")
# │     └─ ("identifier", "Ptr{EzXML._Node} @0x000055bdbc39aa10")
# ├─ ("comment", "Ptr{EzXML._Node} @0x000055bdc1a9ce60")
# ├─ ("function_definition", "Ptr{EzXML._Node} @0x000055bdc6b9d160")
# │  ├─ ("identifier", "Ptr{EzXML._Node} @0x000055bdc352cc80")
# │  ├─ ("parameters", "Ptr{EzXML._Node} @0x000055bdc6ab7430")
# │  └─ ("block", "Ptr{EzXML._Node} @0x000055bdc5de1b50")

query = ParSitter.build_tq_tree(
    ("import_from_statement", ("dotted_name@dotted_name_val",), ("dotted_name@dotted_name_val2"))
)
#query = ParSitter.build_tq_tree( ("comment@captured_comment",) )

_target_nodevalue(n) = strip(string(n.name))

_query_nodevalue(n) = ifelse(
    ParSitter.is_capture_node(n).is_match,
    string(split(n.head, "@")[1]),
    n.head
)

_apply_regex_glob(tree1, tree2) = ParSitter.is_capture_node(tree2; capture_sym = "@").is_match && _query_nodevalue(tree2) == "*"

@time r = ParSitter.query(
    target.root,
    query;
    target_tree_nodevalue = _target_nodevalue,
    query_tree_nodevalue = _query_nodevalue,
    capture_function = node -> strip(node.content),
    node_comparison_yields_true = _apply_regex_glob
)
@time r = ParSitter.query(
    target.root,
    query;
    target_tree_nodevalue = _target_nodevalue,
    query_tree_nodevalue = _query_nodevalue,
    capture_function = node -> strip(node.content),
    node_comparison_yields_true = _apply_regex_glob
)

r_true = filter(x -> x[1], r)
@show r_true[1][1:2]
