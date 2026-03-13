module ParSitterApp

using Logging
using ParSitter
using ArgParse
using JSON

# Function that parses Garamond's unix-socket client arguments
function get_arguments(args::Vector{String})
    s = ArgParseSettings()
    @add_arg_table! s begin
        "input"
        help = "entitity to parse (directory, file or snippet of code)"
        arg_type = String
        "--input-type"
        help = "What is being parsed. Available 'file', 'directory', 'code'"
        arg_type = String
        "--language"
        help = "Programming language. Available: 'python', 'julia', 'c', 'c#', 'r'"
        arg_type = String
        "--print-code"
        help = "Whether to print out the code that is parsed"
        action = :store_true
        "--escape-chars"
        help = "Whether to parse \\n, \\t etc. as escape chars. Active only for 'code' inputs"
        action = :store_true
        "--log-level"
        help = "logging level"
        default = "error"
    end
    return parse_args(args, s)
end


############################
# Main entrypoint function #
############################
function @main(ARGS)
    # Parse command line arguments
    args = get_arguments(ARGS)

    # Logging
    log_levels = Dict(
        "debug" => Logging.Debug,
        "info" => Logging.Info,
        "warning" => Logging.Warn,
        "error" => Logging.Error
    )

    log_level = get(log_levels, lowercase(args["log-level"]), Logging.Error)
    logger = ConsoleLogger(stdout, log_level)
    global_logger(logger)

    ###
    input = args["input"]
    input_type = args["input-type"]
    language = args["language"]
    escape_chars = args["escape-chars"]
    print_code = args["print-code"]
    ###
    ParSitter.check_tree_sitter()
    ParSitter.check_language(language, ParSitter.LANGUAGE_MAP)

    parsed = if input_type == "directory"
        # iterate rcursively through directory and parse all files
        ParSitter.parse(ParSitter.Directory(input), language)
    elseif input_type == "file"
        # parse a single file
        ParSitter.parse(ParSitter.File(input), language)
    elseif input_type == "code"
        # parse code directly from stdin
        ParSitter.parse(ParSitter.Code(input), language; escape_chars, print_code)
    else
        @warn "Unrecognized input-type."
        Dict()  # return an empty dict
    end

    print(JSON.json(parsed))

    return 0
end

end  # module
