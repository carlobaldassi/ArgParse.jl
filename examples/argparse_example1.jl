# example 1: minimal options/arguments, auto-generated help/version

using ArgParse

function main(args)

    # initialize the settings (the description is for the help screen)
    s = ArgParseSettings(description = "Example 1 for argparse.jl: minimal usage.")

    @add_arg_table! s begin
        "--opt1"               # an option (will take an argument)
        "--opt2", "-o"         # another option, with short form
        "arg1"                 # a positional argument
    end

    parsed_args = parse_args(s) # the result is a Dict{String,Any}
    println("Parsed args:")
    for (key,val) in parsed_args
        println("  $key  =>  $(repr(val))")
    end
end

main(ARGS)
