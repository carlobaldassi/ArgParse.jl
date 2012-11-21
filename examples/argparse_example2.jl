# example 2: add some flags and the help lines for options

using ArgParse

function main(args)

    s = ArgParseSettings("argparse_example_2.jl",         # prog name
                         "Example 2 for argparse.jl: " *  # description
                         "flags, options help, " *
                         "required arguments.")

    @add_arg_table s begin
        "--opt1"
            help = "an option"     # used by the help screen
        "--opt2", "-o"
            action = :store_true   # this makes it a flag
            help = "a flag"
        "arg1"
            help = "an argument"
            required = true        # makes the argument mandatory
    end

    parsed_args = parse_args(args, s)
    println("Parsed args:")
    for pa in parsed_args
        println("  $(pa[1])  =>  $(pa[2])")
    end
end

main(ARGS)
