using Pkg.Artifacts

"""
    struct Directory
        name::String
    end

Wrapper object around a directory name or path.
"""
struct Directory
    name::String
end

"""
    struct File
        name::String
    end

Wrapper object around a file name or path.
"""
struct File
    name::String
end

"""
    struct Code
        code::String
    end

Wrapper object around a string that is supposed to contain code.
"""
struct Code
    code::String
end

"""
    struct ParseResult
        file::Union{Nothing, String}
        parsed::String
    end

Parsing result object. It is returned from parsing `::Code` and `::File objects.`
"""
struct ParseResult
    file::Union{Nothing, String}
    parsed::String
end

"""
Checks that a language is available.
"""
function check_language(language, lang_map)
    return @assert language in keys(lang_map) "Unrecognized language $language, exiting..."
end

Base.isfile(::Nothing) = false

# Returns a tree-sitter command
TREE_SITTER_LIBS = Dict(
    "r" => artifact"tree-sitter-r",
    "python" => artifact"tree-sitter-python",
    "julia" => artifact"tree-sitter-julia",
    "c" => artifact"tree-sitter-c",
    "cs" => artifact"tree-sitter-c-sharp",
)

function _make_parse_file_cmd(file::String, language::String)
    tree_sitter_bin_path = try
        if Sys.iswindows()
            joinpath(artifact"tree-sitter", "tree-sitter.exe")
        else
            joinpath(artifact"tree-sitter", "tree-sitter")
        end
    catch e
        @error("No tree-sitter binary artifact found. Supported are `linux`, `macos`, `windows` (x86_64/aarch64)")
    end
    tree_sitter_language_lib = TREE_SITTER_LIBS[language]
    return pipeline(`$tree_sitter_bin_path parse -q -x -p $tree_sitter_language_lib $(file)`, stderr = devnull)
end


_enable_escape_chars(code) = begin
    # "\n", "\t" in input code are treated as escape chars and not strings
    for ch in ["\\n" => '\n', "\\t" => '\t', "\\r" => '\r']
        code = replace(code, ch[1] => ch[2])
    end
    return code
end

"""
    _parse(code::String, language::String; escape_chars=false, print_code=false)

The code parsing function for `::String` inputs. It is part of the internal API and should not be
used. Use `escape_chars=true` if the code contains explicitly the `\n`, `\t`
and `\r` characters. If `print_code` is `true` it will print the code.
"""
function _parse(code::String, language::String; escape_chars = false, print_code = false)
    check_language(language, LANGUAGE_MAP)
    escape_chars && (code = _enable_escape_chars(code))
    print_code && println("---\n$code\n---\n")

    return mktemp() do tmp_path, io
        write(io, code)
        flush(io)
        ts_cmd = _make_parse_file_cmd(tmp_path, language)  # reuse the existing file parser
        out = read(ts_cmd, String)
        return replace(out, "\n" => "")
    end
end

"""
    parse(code::Code, language::String; escape_chars=false, print_code=false)

Parsing function for `::Code` objects. Calls the `_parse` function for `::String`s.
Use `escape_chars=true` if the code contains explicitly the `\n`, `\t` and `\r`
characters. If `print_code` is `true` it will print the code.

"""
function Base.parse(code::Code, language::String; escape_chars = false, print_code = false)
    return ParseResult(nothing, _parse(code.code, language; escape_chars, print_code))
end

"""
    parse(code::File, language::String)

Parsing function for `::File` objects. Reads the content of the file, sends
it to tree-sitter for parsing and returns a `ParseResult` with  parse results.
"""
function Base.parse(file::File, language::String)
    check_language(language, LANGUAGE_MAP)
    _file = abspath(file.name)
    @debug "Parsing file @ $_file ..."
    ts_cmd = _make_parse_file_cmd(_file, language)
    out = try
        read(ts_cmd, String)
    catch
        @warn "Could not parse $_file"
        ""
    end
    return ParseResult(_file, replace(out, "\n" => ""))
end

"""
    parse(code::Directory, language::String)

Parsing function for `::Directory` objects. Reads the contents of the directory
and for supported files, calls the parsing method for `::File` objects.
"""
function Base.parse(dir::Directory, language::String)
    parses = Vector{ParseResult}()
    for (root, _, files) in walkdir(dir.name)
        for file in files
            if any(
                    endswith(lowercase(file), lowercase(_ext))
                        for _ext in get(FILE_EXTENSIONS, language, [])
                )
                _file = File(joinpath(root, file))
                _parsed = parse(_file, language)
                push!(parses, _parsed)
            end
        end
    end
    return parses
end

"""
    print_code_tree(code::String, language::String; maxdepth=100)

Prints the AST of a gieven piece of `code` written in a given
programming `language`.
"""
print_code_tree(code::String, language::String; maxdepth = 100) = begin
    print_tree(ParSitter.build_xml_tree(ParSitter.parse(ParSitter.Code(code), language).parsed).root; maxdepth)
end
