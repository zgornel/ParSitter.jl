# Usage

TODO: Intro on tree matching - matches any tree, one needs to extract node values, provide a compare functuon, provide a capture function and one to extract values from nodes

## Building trees

## Support functions for matching

## Tree matching


## Querying code

### The query DSL

### Querying

## Limitations


## Getting started

The library defines a single structure for working with trees, a **tree-query-expression** through `TreeQueryExpr` object. These can be constructed from `Tuples` or `NTuples`
```@repl index
using ParSitter, AbstractTrees
tt = (1,2,(3,(4,5,(6,),7,5)));
tq = ParSitter.build_tq_tree(tt)
print_tree(tq, maxdepth=10)
```
and converted back to `Tuples` and `NTuples`:
```@repl index
tt = convert(Tuple, tq)
```

### Matching trees
Matching trees requires specifying functions that applied to a node of the tree extract its value for the purpose of comparison. A *capture function* needs to be provided for extracting a specific value from the node. These functions are necessary as target and query trees may contain complex nodes that are objects themselves and may need processing for matching and value capture to occur. In order to be able to match values and at the same time skip comparisons when capturing values, the argument `node_comparison_yields_true` needs to be specified. Its value should be a function that takes two nodes and returns true if the value needs to be captured.

```@repl index
tt = ParSitter.build_tq_tree((1,2,(3,(4,)))); # a target tree
tq = ParSitter.build_tq_tree(("1","@v","3")); # a query tree, capture to 'v'
print_tree(tt)
print_tree(tq)
ParSitter.match_tree(
    tt,
    tq;
    target_tree_nodevalue = n->string(n.head),
    query_tree_nodevalue = n->n.head,
    capture_function = n->n.head,
    node_comparison_yields_true = (t1,t2) -> true)  # all nodes will match!
```

A full example which matches numerical trees to string queries:
```@example matching
using ParSitter, AbstractTrees

_query_tree_nodevalue(n) = ParSitter.is_capture_node(n).is_match ? split(n.head, "@")[1] : n.head
_target_tree_nodevalue(n)=string(n.head)
_capture_on_empty_query_value(t1,t2) = ParSitter.is_capture_node(t2).is_match && isempty(_query_tree_nodevalue(t2))

my_matcher(t,q) = ParSitter.match_tree(
                       ParSitter.build_tq_tree(t),
                       ParSitter.build_tq_tree(q);
                       target_tree_nodevalue=_target_tree_nodevalue,
                       query_tree_nodevalue=_query_tree_nodevalue,
                       capture_function=n->n.head,
                       node_comparison_yields_true=_capture_on_empty_query_value)

query = ("1@v0", "2", "@v2")   # - query means: capture in "v0" if target value is 1, match on 2, capture any symbol in "v2"

t=(1,2,10); my_matcher( t, query)[1:2] |> println
t=(10,2,11); my_matcher( t, query)[1:2] |> println
t=(1,2,3,4,5); my_matcher( t, query)[1:2] |> println
```

### Querying trees

Tree queries match the query tree to the target tree and all its sub-trees.

```@example query
using ParSitter, AbstractTrees

query = ("1@v0", "2", "@v2")   # - query means: capture in "v0" if target value is 1, match on 2, capture any symbol in "v2"
target = (1, 2, 3, (10, 2, 3)) # - only the (1,2,3) sub-tree will match, the second will not bevause of the 10;
                               # - @v2 will always capture values (due to `_capture_on_empty_query_value`)
query_tq = ParSitter.build_tq_tree(query)
target_tq = ParSitter.build_tq_tree(target)

_query_tree_nodevalue(n) = ParSitter.is_capture_node(n).is_match ? split(n.head, "@")[1] : n.head
_target_tree_nodevalue(n) = string(n.head)
_capture_on_empty_query_value(t1,t2) = ParSitter.is_capture_node(t2).is_match && isempty(_query_tree_nodevalue(t2))
print_tree(target_tq); println("---")
print_tree(query_tq); println("---")
r=ParSitter.query(target_tq,
                  query_tq;
                  match_type=:strict,
                  target_tree_nodevalue=_target_tree_nodevalue,
                  query_tree_nodevalue=_query_tree_nodevalue,
                  capture_function=n->n.head,
                  node_comparison_yields_true=_capture_on_empty_query_value)
map(t->t[1:2], r)
```

```@example query
r=ParSitter.query(target_tq,
                  query_tq;
                  match_type=:nonstrict,
                  target_tree_nodevalue=_target_tree_nodevalue,
                  query_tree_nodevalue=_query_tree_nodevalue,
                  capture_function=n->n.head,
                  node_comparison_yields_true=_capture_on_empty_query_value)
map(t->t[1:2], r)
```

## CLI-based parsing
ParSitter.jl comes with a command line tool that allows easy parsing of inline code, files and directories. Currently, it supports the following languages: [Python](https://www.python.org/), [Julia](https://julialang.org/), [C](https://en.wikipedia.org/wiki/C_(programming_language)), [C#](https://en.wikipedia.org/wiki/C_Sharp_(programming_language)) and [R](https://www.r-project.org/)

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
For directories the JSON will contain more key-value paris and for inline code the file path key is an empty string. For example, the following command
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
