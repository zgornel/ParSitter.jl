```@meta
CurrentModule=ParSitter
```

# Introduction
**ParSitter.jl** is a library for parsing and querying code. It supports parsing of code to abstract syntax trees (ASTs) and extracting information from the trees by executing code queries over the ASTs.

Querying code essentially consists in two operations: parsing the code and running a query over the code to verify that the query pattern is found in the code and optionally, to extract or _capture_ specific parts of the code. Under the hood, the querying operation boils down to applying a [tree pattern matching](https://en.wikipedia.org/wiki/Pattern_matching#Tree_patterns) method with capturing of values. This [paper](https://theory.stanford.edu/~tim/papers/ijcai11.pdf) provides a nice introduction into the main concepts behind the matching.

# Features
 - flexible tree matching for [AbstractTrees.jl](https://github.com/JuliaCollections/AbstractTrees.jl) interface compatible trees
 - low-level [S-Expression](https://en.wikipedia.org/wiki/S-expression)-based code querying
 - multiple structural tree matching methods
 - pluggable language support through [tree-sitter](https://tree-sitter.github.io/tree-sitter/)
 - high-level domain-specific-language (DSL) -based code querying
 - tested language support: `Python`, `Julia`, `C`, `C#` and `R`

# Installation

**ParSitter.jl** is a registered package and can be easily installed with
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
