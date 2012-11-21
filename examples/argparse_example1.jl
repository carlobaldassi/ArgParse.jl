# example 1: minimal options/arguments, auto-generated help/version

using ArgParse

function main(args)

    s = ArgParseSettings()

    s.prog = "argparse_example_1.jl"  # program name (for usage & help screen)
    s.description = "Example 1 for argparse.jl: minimal usage." # desciption (for help screen)

    @add_arg_table s begin
        "--opt1"               # an option (will take an argument)
        "--opt2", "-o"         # another option, with short form
        "arg1"                 # a positional argument
    end

    parsed_args = parse_args(s) # the result is a Dict{String,Any}
    println("Parsed args:")
    for pa in parsed_args
        println("  $(pa[1])  =>  $(pa[2])")
    end
end

main(ARGS)
