# Usage

## Intro

**ParSitter.jl** supports matching and querying any tree that supports the [AbstractTrees.jl](https://github.com/JuliaCollections/AbstractTrees.jl) interface. Throughout the documentation, two types of trees will be mentioned:
 - **query tree** the tree which is used extract values from the target tree.
 - **target tree** the tree which one queries

!!! note

    The difference between _matching_ and _querying_ is that matching attempts to match trees starting from the root and progressing recursively towards the leafs while querying matches a query tree with all possible sub-trees of a target tree.

### Support functions for matching
Because matching or querying trees can be done on very different trees (some tree nodes may be complex objects), the querying and matching functions rely on six helper functions. These are provided to the [`match_tree`](@ref) and [`query`](@ref) matching and querying functions as keyword arguments:
 - `targe_tree_nodevalue`: extract the target tree node's value
 - `query_tree_nodevalue`: extract the query tree node's value
 - `capture_function`: extract captured values from matched target nodes
 - `node_comparison_yields_true`: make two nodes always match; this is useful when one wants to skip node comparison i.e. capture nodes or explicitly ignore nodes
 - `is_capture_node`: check is a node is a capture node or not
 - `node_equality_function`: compares the values of target and query nodes

With the help of the functions, the matching function becomes generic as it becomes possible to match arbitrarily complex trees: node values are extracted from nodes, the equality function over extracted values, custom capture symbols and wild-cards are applied through the conditions for skipping nodes from comparison. Finally, custom value capture is applied for nodes of matching target sub-trees.

## Building trees

### Query trees

The library defines a single structure for working with query trees, a **tree-query-expression**, through [`ParSitter.TreeQueryExpr`](@ref) object. It is a simple object whose purpose is to adhere to the `AbstractTrees.jl` interface. Query trees can be constructed from `Tuples` or `NTuples`
```@repl index
using ParSitter, AbstractTrees
tt = (1,2,(3,(4,5,(6,),7,5)));
tq = ParSitter.build_tq_tree(tt)
print_tree(tq)
```
and converted back to `Tuples` and `NTuples`:
```@repl index
tt = convert(Tuple, tq)
```
The basic operating principle is that in the tuple, the first value is the root of the tree and the rest are leafs. When nesting tuples, the first value of an enclosed tuple is the root and the rest become leafs.
```@repl index
tt = ("root", "L1_leaf1", "L1_leaf2", ("L2_root", "L2_leaf2"))
tq = ParSitter.build_tq_tree(tt)
print_tree(tq)
```

### Code trees

Code is represented as `EzXML.Node` objects. Therefore code querying will resort to matching `::TreeQueryExpr`-based trees with `::EzXML.Node`-based trees.
This is because under the hood, ParSitter relies on `tree-sitter` to parse code through the following sequence of operations:
 - shell out from Julia and run `tree-sitter` on either code i.e. a string, file content or directory
 - `tree-sitter` parses the code and outputs an XML string that contains the code AST
 - the XML AST content is read back into Julia
 - `EzXML` parses the XML and outputs an `EzXML.Node` object.

In order to parse code, files and directories one needs to wrap wither the code's string, file path of directory path into [`ParSitter.Code`](@ref), [`ParSitter.File`](@ref) and [`ParSitter.Directory`](@ref) objects respectively.
```@repl index
code = ParSitter.Code("def hello(): pass")
result = parse(code, "python")
ct = build_xml_tree(result)
print_tree(ct.root)
```

## Matching trees

### Basics
As previously mentioned, matching trees requires specifying functions that applied to a node of the tree extract its value for the purpose of comparison. A *capture function* needs to be provided for extracting a specific value from the node. These functions are necessary as target and query trees may contain complex nodes that are objects themselves and may need processing for matching and value capture to occur. In order to be able to match values and at the same time skip comparisons when capturing values, the argument `node_comparison_yields_true` needs to be specified. Its value should be a function that takes two nodes and returns true if the value needs to be captured.

```@repl index
# Define the helper functions
_capture_function(n) = "captured_value=" * string(n.head);
_query_tree_nodevalue(n) = ParSitter.is_capture_node(n).is_match ?
                            split(n.head, "@")[1] : n.head;
_target_tree_nodevalue(n) = string(n.head);
_when_to_yield_true(t1,t2) = ParSitter.is_capture_node(t2).is_match &&
                                isempty(_query_tree_nodevalue(t2));
```
```@repl index
tt = ParSitter.build_tq_tree((1,2,(3,(4,)))); # a target tree
tq = ParSitter.build_tq_tree(("1","@v","3")); # a query tree, capture to 'v'
print_tree(tt)
print_tree(tq)
ParSitter.match_tree(
    tt,
    tq;
    capture_function = _capture_function,
    target_tree_nodevalue = _target_tree_nodevalue,
    query_tree_nodevalue = _query_tree_nodevalue,
    node_comparison_yields_true = _when_to_yield_true)
```

A full example which matches numerical trees to string queries:
```@repl index
my_matcher(t,q) = ParSitter.match_tree(
                       ParSitter.build_tq_tree(t),
                       ParSitter.build_tq_tree(q);
                       target_tree_nodevalue = _target_tree_nodevalue,
                       query_tree_nodevalue = _query_tree_nodevalue,
                       capture_function = _capture_function,
                       node_comparison_yields_true = _when_to_yield_true);
query = ("1@v0", "2", "@v2")   # - query means: capture in "v0" if target value is 1, match on 2, capture any symbol in "v2"

t=(1,2,10); my_matcher( t, query)[1:2] |> println
t=(10,2,11); my_matcher( t, query)[1:2] |> println
t=(1,2,3,4,5); my_matcher( t, query)[1:2] |> println
```

### Querying trees

Tree queries match the query tree to the target tree and all its sub-trees.
```@repl index
query = ("1@v0", "2", "@v2");   # - query means: capture in "v0" if target value is 1, match on 2, capture any symbol in "v2"
target = (1, 2, 3, (10, 2, 3)); # - only the (1,2,3) sub-tree will match, the second will not bevause of the 10;
                                # - @v2 will always capture values (due to `_capture_on_empty_query_value`)
query_tq = ParSitter.build_tq_tree(query);
target_tq = ParSitter.build_tq_tree(target);
print_tree(target_tq);
print_tree(query_tq);
```
The `:strict` query mode matches exactly i.e. order counts as well as values, query nodes to target tree nodes.
```@repl index
r=ParSitter.query(target_tq,
                  query_tq;
                  match_type = :strict,
                  target_tree_nodevalue = _target_tree_nodevalue,
                  query_tree_nodevalue = _query_tree_nodevalue,
                  capture_function = _capture_function,
                  node_comparison_yields_true = _when_to_yield_true);
map(t->t[1:2], r)
```
The `:nonstrict` query mode will match all nodes if possible.
```@repl index
r=ParSitter.query(target_tq,
                  query_tq;
                  match_type = :nonstrict,
                  target_tree_nodevalue = _target_tree_nodevalue,
                  query_tree_nodevalue = _query_tree_nodevalue,
                  capture_function = _capture_function,
                  node_comparison_yields_true = _when_to_yield_true);
map(t->t[1:2], r)
```
!!! note

    The `:nonstrict` matching matching mode may return multiple captured values
    for a specific named capture however it will not be possible to trace back
    the whole tree to which the capture belongs. This means that it is not
    possible to retrieve the other associated matches

### The `:speculative` match mode

!!! compat "This feature is only available if v0.2.0"

The `:speculative` matching mode is faster that `:nonstrict` because it stops after the first sub-tree match at each level during the recursive search. The result is that it will return a single value for each named capture even if more could be retrieved.
```@repl index
_when_to_yield_true(tt, qt) =
    (
    ParSitter.is_capture_node(qt; capture_sym = "@").is_match
        && isempty(_query_tree_nodevalue(qt))
) ||
    _query_tree_nodevalue(qt) == "*"
```
```@repl index
target = ParSitter.build_tq_tree((1, 2, (3, (4, 5)), (-3, -4)))
query = ParSitter.build_tq_tree(("*", ("*", "*"), ("*", ("@v"))))
results = ParSitter.query(
    target,
    query;
    match_type = :speculative,
    target_tree_nodevalue = _target_tree_nodevalue,
    query_tree_nodevalue = _query_tree_nodevalue,
    capture_function = _capture_function,
    node_comparison_yields_true = _when_to_yield_true)
get_capture(results, "v")
```
In contrast, `:nonstrict` will return more captured values since two sub-trees match:
```@repl index
results = ParSitter.query(
    target,
    query;
    match_type = :nonstrict,
    target_tree_nodevalue = _target_tree_nodevalue,
    query_tree_nodevalue = _query_tree_nodevalue,
    capture_function = _capture_function,
    node_comparison_yields_true = _when_to_yield_true)
get_capture(results, "v")
```
More examples of tree-matching behavior can be found in the [query tests](https://github.com/zgornel/ParSitter.jl/blob/master/test/query.jl).

### Query DSL

!!! compat "This feature is only available if v0.2.0"

A high-level DSL for writing queries as real code snippets with placeholders aimed ad intuitive, language-native querying is available on top of the low-level S-Tuple based querying. It is based on the concept that querying code should be done with real code snippets. The locations or _placeholders_ where code is to be captured or ignored are marked with `{{}}`. Currently, the current query string placeholders are supported:
 - `{{capture_name::CAPTURE_TYPE}}` - named capture (extracts value into capture_name).
 - `{{::CAPTURE_TYPE}}` - non-capturing placeholder (matches tree structure only).
 - `{{some_valid_code}}` - Generic code insertion (use `custom_replacements` argument), non-capturing.



```@repl index
using ParSitter.QueryLanguage, AbstractTrees

code_snippet = """
def {{func_name::IDENTIFIER}}():
   x = {{::STRING}}
"""
query_expr, _ = parse_code_snippet_to_query(code_snippet, "python")
print_tree(query_expr, maxdepth=10)
```

```@repl index
# Optional custom replacements for generic placeholders
query_expr, _ = parse_code_snippet_to_query(
   "x = {{my_expr}}",
   "julia";
   custom_replacements = Dict("my_expr" => "1 + 2")
)
print_tree(query_expr)
```

How query generation from snippet works internally:
 - placeholders are replaced with valid language-specific code (e.g., randomized identifiers or type-specific literals). Supported `CAPTURE_TYPE`s and associated code are present in [`ParSitter.DEFAULT_TYPE_REPLACEMENTS`](@ref)) and loaded from the [`languages/`](https://github.com/zgornel/ParSitter.jl/tree/master/languages) directory.
 - the snippet is parsed with tree-sitter to an XML AST.
 - the XML AST is parsed to an `EzXML` tree and converted to [`ParSitter.TreeQueryExpr`](@ref) where:
     - each node is a [`ParSitter.TreeQueryNode`](@ref) containing value and type. The types of query nodes will be node types supported by tree-sitter exclusively.
     - captures become `@capture_name`.
     - Non-captures become wildcards ("*")
     - structure is preserved exactly.
 - The final generated query can be used with [`match_tree`](@ref) or [`query`](@ref).

### Querying code

Below is a minimal example of querying a snippet of code written in R.
```@repl index
using ParSitter, AbstractTrees
_target_nodevalue(n) = strip(replace(n.content, r"[\s]" => ""));
_query_nodevalue(n) = ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head.value, "@")[1]), n.head.value);
_apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym = "@").is_match || qn.head.value == "*";
_capture_function(n) = (v = strip(replace(n.content, r"[\s]" => "")), srow = n["srow"], erow = n["erow"], scol = n["scol"], ecol = n["ecol"]);

R_code = ParSitter.Code(
    """
    # a comment
    mod12 <- glmmTMB(y ~ x1 + x2 + x3 + x4 + (0 | x5),
                     data = data_variable,
                     family = binomial(link = "linear"))
    """
)
language = "r"
_parsed = ParSitter.parse(R_code, language);
target = ParSitter.build_xml_tree(_parsed);

query_snippet = """
        {{comment::COMMENT}}
        {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                  family ={{family::IDENTIFIER}}({{identifier::IDENTIFIER}}={{id_val::STRING}}))
"""
generated_query, _, _ = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language)
print_tree(generated_query, maxdepth=10)
query_results = ParSitter.query(
    target.root,
    generated_query;
    match_type = :speculative,
    target_tree_nodevalue = _target_nodevalue,
    query_tree_nodevalue = _query_nodevalue,
    capture_function = _capture_function,
    node_comparison_yields_true = _apply_regex_glob
)
filter!(first, query_results); # keep only matches
println(query_results[1][2])
```
More examples of tree-matching behavior can be found in the [query language tests](https://github.com/zgornel/ParSitter.jl/blob/master/test/ql.jl).

## CLI-based parsing
**ParSitter.jl** comes with an CLI tool that allows easy parsing of inline code, files and directories. Currently, it supports the following languages: [Python](https://www.python.org/), [Julia](https://julialang.org/), [C](https://en.wikipedia.org/wiki/C_(programming_language)), [C#](https://en.wikipedia.org/wiki/C_Sharp_(programming_language)) and [R](https://www.r-project.org/). This can be extended by adding more language files in [`languages/`](https://github.com/zgornel/ParSitter.jl/tree/master/languages).

### Installing `tree-sitter` languages
In order to be able to parse code, `tree-sitter` and plugins for specific languages need to be installed. For example, to install the python language parser and Assuming that we want to install it to a directory named `_parsers`, located in the current directory, the following sequence of commands should do it:
```sh
cd _parsers
git clone https://github.com/tree-sitter/tree-sitter-python
cd tree-sitter-python
tree-sitter generate
```

### Running the CLI tool
When ran, it returns a JSON string of the form:
```
{ "path/to/file":"parsed code in XML format",
  ...
}
```
For directories the JSON will contain more key-value pairs and for inline code the file path key is an empty string. For example, the following command
```sh
julia --project parsitter.jl ./test/code/python/test_project/main.py --input-type file --language python --log-level error
```
will result in
```
{".../ParSitter.jl/test/code/python/test_project/main.py":"<?xml version=\"1.0\"?><module srow=\"0\" scol=\"0\" erow=\"15\" ecol=\"0\">  <import_from_sta...
}
```
 > Note the `--escape-chars` option should be used if parsing inline code with `\n`, '\t' or '\r' characters.

For example the following works,
```sh
$ julia parsitter.jl 'def foo():pass' --input-type code --language python --log-level debug
```
however if escape chars are present, use the `--escape-chars` option:
```sh
$ julia parsitter.jl 'def foo():\n\tpass' --input-type code --escape-chars --language python --log-level debug
```
