# ParSitter.jl

A code querying and parsing library, written in Julia and build on top on [tree-sitter](https://tree-sitter.github.io/tree-sitter/). Designed for quick and easy parsing and querying of code.

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![Tests](https://github.com/zgornel/ParSitter.jl/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/zgornel/ParSitter.jl/actions/workflows/test.yml?query=branch%3Amaster)
[![codecov](https://codecov.io/gh/zgornel/ParSitter.jl/graph/badge.svg?token=GWKJKBZ5FB)](https://codecov.io/gh/zgornel/ParSitter.jl)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
[![Aqua QA](https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://zgornel.github.io/ParSitter.jl/dev)

## Installation

The installation can be done from Julia with
```julia
using Pkg; Pkg.add("ParSitter")
```
or through the `pkg` mode
```
] add ParSitter
```

Check out the [documentation](https://zgornel.github.io/ParSitter.jl/dev) for information on using the library.

## Differences from TreeSitter.jl
This package differs from [TreeSitter.jl](https://github.com/MichaelHatherly/TreeSitter.jl) in that it calls the tree-sitter parsing CLI externally and reads directly the XML result. TreeSitter.jl provides a much tighter integration with the tree-sitter parsing and querying APIs. ParSitter provides a looser coupling with tree-sitter and more flexible querying mechanisms.

## License

This code has an MIT license.


## Reporting Bugs

Please [file an issue](https://github.com/zgornel/ParSitter.jl/issues/new) to report a bug or request a feature.


## References

[1] https://tree-sitter.github.io/tree-sitter/

[2] https://en.wikipedia.org/wiki/Abstract_syntax_tree

## Acknowledgements

This work could not have been possible without the great work of the `tree-sitter` team and the individual maintainers of the specific parsers.
