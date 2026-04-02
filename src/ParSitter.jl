module ParSitter

# Includes
include("utils.jl")  # init code, defaults, etc.
include("parse.jl")  # code parsing
include("query.jl")  # tree building and matching
include("ql.jl")     # generation of trees from code snippets

using Reexport
@reexport import .QueryLanguage: parse_code_snippet_to_query

# Init function: initializes languages
function __init__()
    # Intialize
    language_directory = joinpath(dirname(abspath(@__FILE__)), "..", "languages")
    return populate!(
        LANGUAGE_MAP,
        FILE_EXTENSIONS,
        DEFAULT_TYPE_REPLACEMENTS,
        STRING_DELIMS;
        language_directory
    )
end

# Public API
export check_tree_sitter, # checks tree sitter install
    parse, # parses code, files and directories
    print_code_tree, # prints code using AbstractTrees
    build_tq_tree, # builds TreeQueryExpr's from tuples
    build_xml_tree, # builds an XML tree from XML string
    match_tree, # matches two trees
    query, # queries a tree (matches also all subtrees)
    get_capture, # get values of captured symbols from query results
    parse_code_snippet_to_query  # generate a tree query from a code snippet
end  # module
