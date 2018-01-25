# example 4: dest_name, metavar, range_tester, alternative
#            actions, epilog with examples

using ArgParse

function main(args)

    s = ArgParseSettings("Example 4 for argparse.jl: " *
                         "more tweaking of the arg fields: " *
                         "dest_name, metvar, range_tested, " *
                         "alternative actions.")

    @add_arg_table s begin
        "--opt1"
            action = :append_const   # appends 'constant' to 'dest_name'
            arg_type = String        # the only utility of this is restricting the dest array type
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
            arg_type = String
            dest_name = "awk"
            range_tester = (x->x=="X"||x=="Y")  # each argument must be either "X" or "Y"
            metavar = "XY"
            help = "either X or Y; all XY's are " *
                   "stored in chunks"
    end

    # we add an epilog and provide usage examples, also demonstrating
    # how to have some control on the formatting: we use additional '\n' at
    # the end of lines to force newlines, and '\ua0' to put non-breakable spaces.
    # Non-breakable spaces ensure will be substituted with spaces in the output.
    s.epilog = """
        examples:\n
        \n
        \ua0\ua0$(basename(Base.source_path())) --opt1 --opt2 --opt2 -k\n
        \n
        \ua0\ua0$(basename(Base.source_path())) --awkward X X --opt1 --awkward X Y X --opt2\n
        \n
        The first form takes option 1 once, than option 2, then activates the answer flag,
        while the second form takes only option 1 and then 2, and intersperses them with "X\ua0X"
        and "X\ua0Y\ua0X" groups, for no particular reason.
        """

    # the epilog section will be displayed like this in the help screen:
    #
    #     examples:
    #
    #       argparse_example4.jl --opt1 --opt2 --opt2 -kkkkk
    #
    #       argparse_example4.jl --awkward X X --opt1 --awkward X Y X --opt2
    #
    #     The first form takes option 1 once, than option 2, then activates the
    #     answer flag, while the second form takes only option 1 and then 2, and
    #     intersperses them with "X X" and "X Y X" groups, for no particular
    #     reason.

    parsed_args = parse_args(args, s)
    println("Parsed args:")
    for (key,val) in parsed_args
        println("  $key  =>  $(repr(val))")
    end
end

main(ARGS)
