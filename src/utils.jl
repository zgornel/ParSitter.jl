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
Reads the contents of `language_directory` and populates the constants:
`LANGUAGE_MAP`, `FILE_EXTENSIONS` and `DEFAULT_TYPE_REPLACEMENTS`.
"""
function populate!(
        language_map,
        all_file_extensions,
        default_type_replacements,
        string_delims;
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
                parsitter_name = get(contents, "parsitter-name", nothing)
                tree_sitter_scope = get(contents, "tree-sitter-scope", nothing)
                file_extensions = get(contents, "file-extensions", nothing)
                type_replacements = get(contents, "type-replacements", nothing)
                string_delim = get(contents, "string-delim", nothing)
                # Checks of the fields
                @assert !isnothing(parsitter_name) "Missing \"parsitter-name\" field @$file"
                @assert !isnothing(tree_sitter_scope) "Missing \"tree-sitter-scope\" field @$file"
                @assert !isnothing(file_extensions) "Missing \"file-extensions\" field @$file"
                @assert !isnothing(type_replacements) "Missing \"type-replacements\" field @$file"
                @assert !isnothing(string_delim) "Missing \"string-delim\" field @$file"
                @assert !isempty(file_extensions) "Empty\"file-extensions\" value @$file"
                @assert !isempty(type_replacements) "Empty \"type-replacements\" value @$file"
                # Fill in the globals
                if is_enabled
                    push!(language_map, parsitter_name => tree_sitter_scope)
                    push!(all_file_extensions, parsitter_name => file_extensions)
                    push!(default_type_replacements, parsitter_name => type_replacements)
                    push!(string_delims, parsitter_name => string_delim)
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
