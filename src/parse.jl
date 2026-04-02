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

"""
Checks that `tree-sitter` is installed and that the operating system is `Linux`.
"""
function check_tree_sitter(;
        system = :Linux,
        tree_sitter_path = nothing
    )
    return if system == :Linux
        @assert Sys.islinux() "This is not a Linux system."
        @assert !isempty(
            try
                read(`tree-sitter --version`, String)
            catch
                ""
            end
        ) ||
            isfile("/usr/bin/tree-sitter") ||
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
    _parse(code::String, language::String; escape_chars=false, print_code=false)

The code parsing function for `::String` inputs. It is part of the internal API and should not be
used. Use `escape_chars=true` if the code contains explicitly the `\n`, `\t`
and `\r` characters. If `print_code` is `true` it will print the code.
"""
function _parse(code::String, language::String; escape_chars = false, print_code = false)
    check_language(language, LANGUAGE_MAP)
    check_tree_sitter()
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
    check_tree_sitter()
    _file = abspath(_normalize_fs_path(file.name))
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
