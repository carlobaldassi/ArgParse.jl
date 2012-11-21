# example 3: version information, default values, options with
#            types and variable number of arguments

using ArgParse

function main(args)

    s = ArgParseSettings("argparse_example_3.jl",
                         "Example 3 for argparse.jl: " *
                         "version info, default values, " *
                         "options with types, variable " *
                         "number of arguments.")

    s.version = "Version 1.0" # version info
    s.add_version = true      # audo-add version option

    @add_arg_table s begin
        "--opt1"
            nargs = '?'              # '?' means optional argument
            arg_type = Int           # only Int arguments allowed
            default = 0              # this is used when the option is not passed
            constant = 1             # this is used if --opt1 is paseed with no argument
            help = "an option"
        "--karma", "-k"
            action = :count_invocations  # increase a counter each time the option is given
            help = "increase karma"
        "arg1"
            nargs = 2                        # eats up two arguments; puts the result in a Vector
            help = "first argument, two " *
                   "entries at once"
            required = true
        "arg2"
            nargs = '*'                            # eats up as many arguments as possible before an option
            default = {"no_arg_given"}             # since the result will be a Vector{Any}, the default must
                                                   # also be (or it can be [] or nothing)
            help = "second argument, eats up " *
                   "as many items as possible " *
                   "before an option"
    end

    parsed_args = parse_args(args, s)
    println("Parsed args:")
    for pa in parsed_args
        println("  $(pa[1])  =>  $(pa[2])")
    end
end

main(ARGS)
