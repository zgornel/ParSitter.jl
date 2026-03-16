"""
    QueryLanguage

A module for converting code snippets with capture placeholders into TreeQueryExpr
objects that can be used with ParSitter.match_tree for code tree querying.

Placeholder formats:
- {{capture_name::capture_type}} - Named capture with type specification
- {{::capture_type}} - Will not capture, used for insertion of valid `capture_type` code
- {{some_valid_code}} - Generic valid code placeholder
"""
module QueryLanguage

import Base.Regex
import ..ParSitter
using Random
using EzXML
using AbstractTrees

export parse_code_snippet_to_query

# Type for {{some_code}} i.e. replacements without `::`
const GENERIC_TYPE = "GENERIC_CODE"

# Default placeholder replacements by language and type
const DEFAULT_TYPE_REPLACEMENTS = Dict(
    # Python replacements
    "python" => Dict(
        "COMMENT" => "#comment",
        "IDENTIFIER" => "var",
        "NUMBER" => "0",
        "STRING" => "\"\"",
        "VARIABLE" => "x",
        "BOOLEAN" => "True",
        "FUNCTION" => "def f(): pass",
    ),
    # Julia replacements
    "julia" => Dict(
        "COMMENT" => "#comment",
        "IDENTIFIER" => "var",
        "NUMBER" => "0",
        "STRING" => "\"\"",
        "VARIABLE" => "x",
        "BOOLEAN" => "true",
        "FUNCTION" => "function f() end",
    ),
    # C replacements
    "c" => Dict(
        "COMMENT" => "//comment",
        "IDENTIFIER" => "var",
        "NUMBER" => "0",
        "STRING" => "\"\"",
        "VARIABLE" => "x",
        "TYPE" => "int",
        "BOOLEAN" => "1",
        "FUNCTION" => "void f() {}",
    ),
    # C# replacements
    "c#" => Dict(
        "COMMENT" => "//comment",
        "IDENTIFIER" => "var",
        "NUMBER" => "0",
        "STRING" => "\"\"",
        "VARIABLE" => "x",
        "BOOLEAN" => "true",
        "FUNCTION" => "void F() { }",
    ),
    # R replacements
    "r" => Dict(
        "COMMENT" => "#comment",
        "IDENTIFIER" => "var",
        "NUMBER" => "0",
        "STRING" => "\"\"",
        "VARIABLE" => "x",
        "BOOLEAN" => "TRUE",
        "FUNCTION" => "f <- function() {}",
        "R_FORMULA" => "y~x",
    ),
)

"""
Retrieves the comment symbol from DEFAULT_TYPE_REPLACEMENTS.
All comments are assument to be of the form: \"<COMMENT_SYMBOL>comment\".
"""
function _get_comment_symbol(language; capture_type = "COMMENT")
    return first(split(DEFAULT_TYPE_REPLACEMENTS[language][capture_type], "comment"))
end


"""
    _extract_placeholders(code::String) -> Vector{Tuple{String, String, String}}

Extract all placeholders from code in the format `"{{capture_name::capture_type}}\"`
or `\"{{code}}\"`. Returns a vector of tuples: (original_placeholder, capture_name_or_code,
capture_type).
"""
function _extract_placeholders(code::String)::Vector{Tuple{String, String, String}}
    placeholders = Tuple{String, String, String}[]
    pattern = r"\{\{([^}]+)\}\}"
    for match in eachmatch(pattern, code)
        content = match.captures[1]
        original = match.match
        if contains(content, "::")
            @assert length(findall("::", content)) == 1 "Malformed specification; only one use of \"::\" allowed"
            # Named capture format: name::type
            parts = split(content, "::")
            capture_name = strip(parts[1])
            capture_type = strip(parts[2])
            push!(placeholders, (original, capture_name, capture_type))
        else
            # Generic code placeholder (no "::" found)
            push!(placeholders, (original, strip(content), GENERIC_TYPE))
        end
    end
    return placeholders
end

"""
Generates a valid symbol name depending on original capture_name, the type and language replacements.
"""
function _generate_name(capture_name, capture_type, language)
    @assert haskey(DEFAULT_TYPE_REPLACEMENTS, language)
    lang_replacements = DEFAULT_TYPE_REPLACEMENTS[language]
    @assert haskey(lang_replacements, capture_type)
    return if isempty(capture_name)
        if capture_type ∉ ["NUMBER", "BOOLEAN"]
            return lang_replacements[capture_type] * "_" * randstring(10)
        else
            return lang_replacements[capture_type]  # numbers/booleans are not randomized
        end
    else
        if capture_type == "COMMENT"
            # Note: assumes NO space after comment symbol in  DEFAULT_TYPE_REPLACEMENTS
            _comment_symbol = _get_comment_symbol(language; capture_type)
            return _comment_symbol * capture_name * "_" * randstring(10)
        else
            # Symbols that are captured have the original
            # capture name in the randomized value
            return capture_name * "_" * randstring(10)
        end
    end
end


"""
    _replace_placeholder(capture_name::String, capture_type::String, language::String, custom_replacements::Dict) -> String

Replace a single placeholder with valid code based on its type and language.
"""
function _replace_placeholder(
        capture_name::String,
        capture_type::String,
        language::String,
        custom_replacements::Dict = Dict()
    )
    # Check custom replacements first
    if capture_type == GENERIC_TYPE
        if haskey(custom_replacements, capture_name)
            return custom_replacements[capture_name], false
        else
            @error "No replacement found for \"$capture_name\""
        end
    end
    # Check language-specific replacements
    generated_name = _generate_name(capture_name, capture_type, language)
    is_capturable = ifelse(!isempty(capture_name), true, false)
    return generated_name, is_capturable
end

"""
    _parse_code_to_xml_tree(code::String, language::String)

Parse code using tree-sitter and return the XML representation.
"""
function _parse_code_to_xml_tree(code::String, language::String)
    try
        _output = ParSitter.parse(ParSitter.Code(code), language; escape_chars = false, print_code = false)
        if isempty(_output.parsed)
            error("Tree-sitter parsing returned empty output for language: $language")
        end
        return ParSitter.build_xml_tree(_output)
    catch e
        error("Failed to parse code with tree-sitter: $(e.msg)")
    end
end


"""
Function that transforms an XML tree into a `TreeQueryExpr` based on the
information from symbol mappings.
"""
function _xml_node_to_tqexpr(node, symbol_map, language)
    node_name = node.name
    node_content = strip(replace(node.content, r"\s" => ""))
    node_value = node_content
    skip_children = false
    if node_content in keys(symbol_map)
        capture_type, is_capturable = symbol_map[node_content]
        # We are dealing with an expression generated
        if is_capturable
            if capture_type == "COMMENT"  # remove comment symbol from capturable name
                _comment_symbol = _get_comment_symbol(language; capture_type)
                node_value = replace(node_value, _comment_symbol => "")
            end
            node_value = "@" * replace(node_value, r"_.{10}$" => "")
        else
            if capture_type == "R_FORMULA"
                skip_children = true
            end
            node_value = "*"
        end
    else
        # This is a node that was not inserted by us or,
        # a node in a sub-tree of a generated expression
        if node_name == "identifier"  # this is a tree-sitter node type
            node_value = node_content
        else
            node_value = "*"
        end
    end
    child_exprs = ParSitter.TreeQueryExpr[]
    if !skip_children
        for child in children(node)
            push!(child_exprs, _xml_node_to_tqexpr(child, symbol_map, language))
        end
    end
    return ParSitter.TreeQueryExpr(node_value, child_exprs)
end


"""
    parse_code_snippet_to_query(
        code_snippet::String,
        language::String;
        custom_replacements::Dict = Dict()
    ) -> ParSitter.TreeQueryExpr

Parse a code snippet with capture placeholders and convert it to a TreeQueryExpr.

# Arguments
- `code_snippet::String`: Code with placeholders like `{{name::type}}`, `{{::type}}` or `{{custom_code}}`
- `language::String`: Programming language ("python", "julia", "c", "c#", "r")
- `custom_replacements::Dict`: Optional replacements for `{{custom_code}}` placeholders

# Returns
A `TreeQueryExpr` ready to be used with `ParSitter.match_tree`

# Example
```julia
code = \"\"\"
def {{func_name::identifier}}():
    {{code}}
\"\"\"
query_expr = ParSitter.QueryLanguage.parse_code_snippet_to_query(code, "python"; custom_replacements=Dict("code"=>"pass"))
"""
function parse_code_snippet_to_query(
        code_snippet::String,
        language::String;
        custom_replacements::Dict = Dict()
    )
    # Validate language
    valid_languages = collect(keys(ParSitter.LANGUAGE_MAP))
    if language ∉ valid_languages
        error("Unsupported language: $language. Supported: $valid_languages")
    end

    # step 1: find placeholders {{capture_name::capture_type}}, {{::no_capture_type}}
    #         or {{generic_code}} with valid code
    placeholders = _extract_placeholders(code_snippet)

    # step 2: transform code: placeholders get replaced by correct language mapping
    transformed_code = code_snippet
    symbol_map = Dict()
    for (original, capture_name, capture_type) in placeholders
        replacement, is_capturable = _replace_placeholder(
            capture_name,
            capture_type,
            language,
            custom_replacements
        )
        transformed_code = replace(transformed_code, original => replacement)
        push!(symbol_map, replacement => (capture_type, is_capturable))
    end

    # step 3: parse code with treesitter
    _tree = _parse_code_to_xml_tree(transformed_code, language)

    # step 4: transform parsed tree to TreeQueryExpr
    query_expr = _xml_node_to_tqexpr(_tree.root, symbol_map, language)

    return query_expr, symbol_map, transformed_code
end

end  # module
