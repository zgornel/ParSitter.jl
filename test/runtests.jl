using Test
using Logging
using ParSitter
using DataStructures

global_logger(ConsoleLogger(stdout, Logging.Error))  # supress test warnings

include("parse.jl")
include("query.jl")
include("convert.jl")
include("Aqua.jl")
