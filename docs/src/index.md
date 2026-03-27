```@meta
CurrentModule=ParSitter
```

# Introduction
ParSitter.jl is a library for parsing and querying code. It supports parsing of code to abstract syntax trees (ASTs) and extracting information from the trees by executing code queries over the ASTs. This [paper](https://theory.stanford.edu/~tim/papers/ijcai11.pdf) provides a nice introduction into the main concepts behind the matching.

Querying code essentially consists in two operations: parsing the code and query to trees and applying a [tree pattern matching](https://en.wikipedia.org/wiki/Pattern_matching#Tree_patterns) method with capturing of values. Throughout the documentation we shall refer to:
 - **target tree** the tree which one queries
 - **query tree** the tree which is used extract values from the target tree.

# Features
 - pluggable language support through [tree-sitter](https://tree-sitter.github.io/tree-sitter/)
 - high-level domain-specific-language (DSL) for code querying
 - low-level code querying with queries expressed as `Tuple`s (in an [S-Expression](https://en.wikipedia.org/wiki/S-expression) fashion)
 - multiple structural tree matching algorithms
 - tested language support: `Python`, `Julia`, `C`, `C#` and `R`

# Installation

ParSitter.jl is a registered package and can be easily installed with
```julia
using Pkg; Pkg.add("ParSitter")
```
or alternatively, using the `pkg` mode
```
] add ParSitter
```

# Contents
```@contents
Pages = ["examples.md", "api.md"]
Depth = 3
```
