# example 4: dest_name, metavar, range_tester, alternative
#            actions

using ArgParse

function main(args)

    s = ArgParseSettings("Example 4 for argparse.jl: " *
                         "more tweaking of the arg fields: " *
                         "dest_name, metvar, range_tested, " *
                         "alternative actions.")

    @add_arg_table s begin
        "--opt1"
            action = :append_const   # appends 'constant' to 'dest_name'
            arg_type = String
            constant = "O1"
            dest_name = "O_stack"    # this changes the destination
            help = "append O1"
        "--opt2"
            action = :append_const
            arg_type = String
            constant = "O2"
            dest_name = "O_stack"    # same dest_name as opt1, different constant
            help = "append O2"
        "-k"
            action = :store_const    # stores constant if given, default otherwise
            default = 0
            constant = 42
            help = "provide the answer"
        "--awkward-option"
            nargs = '+'                         # eats up as many argument as found (at least 1)
            action = :append_arg                # argument chunks are appended when the option is
                                                # called repeatedly
            dest_name = "awk"
            range_tester = (x->x=="X"||x=="Y")  # each argument must be either "X" or "Y"
            metavar = "XY"
            help = "either X or Y; all XY's are " *
                   "stored in chunks"
    end

    parsed_args = parse_args(args, s)
    println("Parsed args:")
    for pa in parsed_args
        println("  $(pa[1])  =>  $(pa[2])")
    end
end

main(ARGS)
