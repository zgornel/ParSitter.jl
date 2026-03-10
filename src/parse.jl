struct Directory
    name::String
end

struct File
    name::String
end

struct Code
    code::String
end

"""
Map from input language to `tree-sitter` compatible language name.
"""
const LANGUAGE_MAP = Dict(
    "python" => "source.python",
    "julia" => "source.julia",
    "c" => "source.c",
    "cs" => "source.cs",
    "r" => "source.R"
)

"""
Map from input language to file extensions that can be parsed.
"""
const FILE_EXTENSIONS = Dict(
    "python" => [".py"],
    "julia" => [".jl"],
    "c" => [".c", ".h"],
    "cs" => [".cs"],
    "r" => [".r"]
)

function check_language(language, lang_map)
    return @assert language in keys(lang_map) "Unrecognized language $language, exiting..."
end

Base.isfile(::Nothing) = false
function check_tree_sitter(;
        system = :Linux,
        tree_sitter_path = nothing
    )
    return if system == :Linux
        @assert Sys.islinux() "This is not a Linux system."
        @assert isfile("/usr/bin/tree-sitter") ||
            isfile("/bin/tree-sitter") ||
            isfile(tree_sitter_path) "tree-sitter not found on system"
    end
end

function _normalize_fs_path(path::String)::String
    result = replace(path, "\\" => "/")
    result = String(strip(result))
    return result
end


# Returns a tree-sitter command
function _make_parse_code_cmd(code::String, language::String)
    _language = LANGUAGE_MAP[language]
    return pipeline(`tree-sitter parse -q -x --scope $_language /dev/stdin`, stdin = IOBuffer(code), stderr = devnull)
end

# Returns a tree-sitter command
function _make_parse_file_cmd(file::String, language::String)
    _language = LANGUAGE_MAP[language]
    return pipeline(`tree-sitter parse -q -x --scope $(_language) $(file)`, stderr = devnull)
end


_enable_escape_chars(code) = begin
    # "\n", "\t" in input code are treated as escape chars and not strings
    for ch in ["\\n" => '\n', "\\t" => '\t', "\\r" => '\r']
        code = replace(code, ch[1] => ch[2])
    end
    return code
end

"""
    parse(code::String, language::String; escape_chars=false, print_code=false)

Parsing function for strings. Use `escape_chars=true` if the code contains
explicitly the `\n`, `\t` and `\r` characters. If `print_code` is `true`
it will print the code.
"""
function parse(code::String, language::String; escape_chars = false, print_code = false)
    escape_chars && (code = _enable_escape_chars(code))
    print_code && println("---\n$code\n---\n")
    ts_cmd = _make_parse_code_cmd(code, language)
    out = try
        out = read(ts_cmd, String)
    catch e
        @warn "Could not parse code snippet.\n$e"
        ""
    end
    return replace(out, "\n" => "")
end

"""
    parse(code::Code, language::String; escape_chars=false, print_code=false)

Parsing function for `::Code` objects. Calls the method for `::String`. Use
`escape_chars=true` if the code contains explicitly the `\n`, `\t` and `\r`
characters. If `print_code` is `true` it will print the code.

"""
function parse(code::Code, language::String; escape_chars = false, print_code = false)
    return Dict("" => parse(code.code, language; escape_chars, print_code))
end

"""
    parse(code::File, language::String)

Parsing function for `::File` objects. Reads the content of the file, sends
it to tree-sitter for parsing and returns the parse results.
"""
function parse(file::File, language::String)
    _file = abspath(_normalize_fs_path(file.name))
    @debug "Parsing file @ $_file ..."
    ts_cmd = _make_parse_file_cmd(_file, language)
    out = try
        read(ts_cmd, String)
    catch
        @warn "Could not parse $_file"
        ""
    end
    return Dict(_file => replace(out, "\n" => ""))
end

"""
    parse(code::Directory, language::String)

Parsing function for `::Directory` objects. Reads the contents of the directory
and for supported files, calls the parsing method for `::File` objects.
"""
function parse(dir::Directory, language::String)
    parses = Dict{String, String}()
    for (root, _, files) in walkdir(dir.name)
        for file in files
            if any(
                    endswith(lowercase(file), lowercase(_ext))
                        for _ext in get(FILE_EXTENSIONS, language, [])
                )
                _file = File(joinpath(root, file))
                _parsed = parse(_file, language)
                for (k, v) in _parsed
                    push!(parses, k => v)
                end
            end
        end
    end
    return parses
end
