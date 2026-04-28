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

ParSitter is a registered package and can be easily installed with
```julia
using Pkg; Pkg.add("ParSitter")
```
or alternatively, using the `pkg` mode
```
] add ParSitter
```

## Prerequisites

ParSitter requires the tree-sitter CLI (≥ v0.20) and compiled parsers for the languages you want to use.
Installation:
 - macOS: `brew install tree-sitter`
 - Linux: install `tree-sitter` using the distribution package manager or download binary from GitHub releases
 - Windows: `winget install tree-sitter` or download `tree-sitter.exe` from https://github.com/tree-sitter/tree-sitter/releases and add to `PATH`
Then run
```bash
tree-sitter init-config
```
Edit `~/.config/tree-sitter/config.json` (or equivalent on Windows) and add parser directories. Build parsers with `tree-sitter generate` (see [languages/](https://github.com/zgornel/ParSitter.jl/tree/master/languages) TOML files for supported scopes).


# Contents
```@contents
Pages = ["examples.md", "api.md"]
Depth = 3
```
