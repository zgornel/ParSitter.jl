using TOML

"""
Map from internal language names to `tree-sitter` compatible scopes.
"""
const LANGUAGE_MAP = Dict{String, String}()

"""
Supported file extensions for the languages.
"""
const FILE_EXTENSIONS = Dict{String, Vector{String}}()

"""
Query generation type-related placeholder replacements.
"""
const DEFAULT_TYPE_REPLACEMENTS = Dict{String, Dict{String, String}}()

"""
String delimiters for different languages
"""
const STRING_DELIMS = Dict{String, String}()

"""
ParSitter Types for which query children are skipped i.e. whole sub-tree is captured.
"""
const SKIP_CHILDREN_TYPES = Dict{String, Vector{String}}()

"""
Language-related type replacement from: ParSitter capture type to tree-sitter type.
"""
const OVERRIDE_TYPES = Dict{String, Dict{String, String}}()

"""
`tree-sitter` node types whose content will be kept in ParSitter generated
queries and not replaced with the wildcard '*'.
"""
const KEEP_CONTENT_TS_TYPES = Dict{String, Vector{String}}()


"""
Reads the contents of `language_directory` and populates the constants:
`LANGUAGE_MAP`, `FILE_EXTENSIONS` and `DEFAULT_TYPE_REPLACEMENTS`.
"""
function populate!(
        language_map,
        all_file_extensions,
        default_type_replacements,
        string_delims,
        skip_children_types,
        override_types,
        keep_content_ts_types;
        language_directory = ""
    )

    @assert ispath(language_directory) "No directory @$language_directory"

    for (root, _, files) in walkdir(language_directory)
        for file in files
            full_file = joinpath(language_directory, file)
            try
                # Read file
                contents = open(full_file, "r") do io
                    TOML.parse(io)
                end
                # Read file contents into variables
                is_enabled = get(contents, "enabled", false)
                _parsitter_name = get(contents, "parsitter-name", nothing)
                _tree_sitter_scope = get(contents, "tree-sitter-scope", nothing)
                _file_extensions = get(contents, "file-extensions", nothing)
                _type_replacements = get(contents, "type-replacements", nothing)
                _string_delims = get(contents, "string-delim", nothing)
                _skip_children_types = get(contents, "skip-children-types", nothing)
                _override_types = get(contents, "override-types", nothing)
                _keep_content_ts_types = get(contents, "keep-content-ts-types", nothing)
                # Checks of the fields presence
                @assert !isnothing(_parsitter_name) "Missing \"parsitter-name\" field @$file"
                @assert !isnothing(_tree_sitter_scope) "Missing \"tree-sitter-scope\" field @$file"
                @assert !isnothing(_file_extensions) "Missing \"file-extensions\" field @$file"
                @assert !isnothing(_type_replacements) "Missing \"type-replacements\" field @$file"
                @assert !isnothing(_string_delims) "Missing \"string-delim\" field @$file"
                @assert !isnothing(_skip_children_types) "Missing \"skip-children-types\" field @$file"
                @assert !isnothing(_override_types) "Missing \"override-types\" field @$file"
                @assert !isnothing(_keep_content_ts_types) "Missing \"keep-content-ts-types\" field @$file"
                # Checks of the fields values
                @assert !isempty(_file_extensions) "Empty\"file-extensions\" value @$file"
                @assert !isempty(_type_replacements) "Empty \"type-replacements\" value @$file"
                # Fill in the globals
                if is_enabled
                    push!(language_map, _parsitter_name => _tree_sitter_scope)
                    push!(all_file_extensions, _parsitter_name => _file_extensions)
                    push!(default_type_replacements, _parsitter_name => _type_replacements)
                    push!(string_delims, _parsitter_name => _string_delims)
                    push!(skip_children_types, _parsitter_name => _skip_children_types)
                    push!(override_types, _parsitter_name => _override_types)
                    push!(keep_content_ts_types, _parsitter_name => _keep_content_ts_types)
                end
            catch e
                @warn "Could not parse language file @$full_file\n$e"
            end
        end
    end

    return
end

# Tree pruning methods
"""
    prune!(node, value; nodevalue_function = AbstractTrees.nodevalue)

Recursively prunes an AbstractTrees.jl-compatible tree (in-place) rooted at `node`.
Pruning rule (applied at every level): after recursively pruning all child subtrees,
remove any direct child whose subtree contains `value` in any of its nodes
(including the child node itself). `value` is the input parameter (e.g. call
as `prune!(root, nodevalue(root))` to prune duplicates of the root value).
Assumes `AbstractTrees.children(node)` returns a mutable `Vector`, standard for most
custom `Node` types. A custom function `nodevalue_function` can be applied to
each node to extract its value for the comparision with `value`.
"""
function prune!(node, value; nodevalue_function = AbstractTrees.nodevalue)
    # 1. Recursively prune deeper levels first (bottom-up)
    for child in AbstractTrees.children(node)
        prune!(child, value; nodevalue_function)
    end

    # 2. Remove any child whose (now-pruned) subtree still contains the value
    return filter!(AbstractTrees.children(node)) do child
        !subtree_contains(child, value; nodevalue_function)
    end
end

# Small recursive helper used by prune!
function subtree_contains(node, value; nodevalue_function = AbstractTrees.nodevalue)
    return nodevalue_function(node) == value ||
        any(subtree_contains(c, value; nodevalue_function) for c in AbstractTrees.children(node))
end
