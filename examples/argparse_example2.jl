# example 2: add some flags and the help lines for options

using ArgParse

function main(args)

    s = ArgParseSettings("Example 2 for argparse.jl: " *  # description
                         "flags, options help, " *
                         "required arguments.")

    @add_arg_table! s begin
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
    for (key,val) in parsed_args
        println("  $key  =>  $(repr(val))")
    end
end

main(ARGS)
