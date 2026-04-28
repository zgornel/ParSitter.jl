import ParSitter: LANGUAGE_MAP, parse, Code, Directory, ParseResult

test_dir = abspath(dirname(@__FILE__))

@testset "parser" begin
    for (language, ts_language) in LANGUAGE_MAP
        @test ParSitter._make_parse_file_cmd("", language) isa Base.AbstractCmd
    end

    @test ParSitter._enable_escape_chars("\\na\\tb\\rc") == "\na\tb\rc"

    @testset "parsing of Directory & File" begin
        for language in keys(LANGUAGE_MAP)
            language_dir = joinpath(test_dir, "code", language)
            parsed = parse(Directory(language_dir), language)
            @test parsed isa Vector{ParseResult}   # parsing command executed and returned
            @test !isempty(parsed)  # contents were parsed
            for p in parsed
                @test p.file isa String
                @test !isempty(p.file)
                @test !isempty(p.parsed)
            end
        end
    end

    @testset "parsing of String & Code" begin
        FILE_MAP = Dict(
            "python" => joinpath("test_project", "main.py"),
            "julia" => joinpath("test_project", "src", "cf1.jl"),
            "c" => joinpath("test_pass_value_lib", "test_pass_value.c"),
            "cs" => "hello_world.cs",
            "r" => "r_snippet_lm.r"
        )
        for language in keys(LANGUAGE_MAP)
            language_dir = joinpath(test_dir, "code", language)
            file_path = joinpath(language_dir, FILE_MAP[language])
            # String
            parsed = ParSitter._parse(
                read(file_path, String),
                language,
                escape_chars = false,
                print_code = false
            )
            @test parsed isa String         # parsing command executed and returned
            @test !isempty(parsed)          # contents were parsed
            # Code
            parsed = parse(
                Code(read(file_path, String)),
                language,
                escape_chars = false,
                print_code = false
            )
            @test parsed isa ParseResult    # parsing command executed and returned
            @test isnothing(parsed.file)    # contents were parsed
            @test !isempty(parsed.parsed)   # contents were parsed
        end
    end
end
