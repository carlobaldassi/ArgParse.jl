# example 7: argument groups

using ArgParse

function main(args)

    s = ArgParseSettings("argparse_example_7.jl",
                         "Example 7 for argparse.jl: " *
                         "argument groups.")

    add_arg_group(s, "stack options") # add a group and sets it as the default
    @add_arg_table s begin            # all options (and arguments) in this table
                                      # will be assigned to the newly added group
        "--opt1"
            action = :append_const
            arg_type = String
            constant = "O1"
            dest_name = "O_stack"
            help = "append O1 to the stack"
        "--opt2"
            action = :append_const
            arg_type = String
            constant = "O2"
            dest_name = "O_stack"
            help = "append O2 to the stack"
    end

    add_arg_group(s, "weird options", "weird") # another group, this time with a tag which allows
                                               # to refer to it

    set_default_arg_group(s, "weird") # set the default group (useless here, since we just added it)

    @add_arg_table s begin
        "--awkward-option"
            nargs = '+'
            action = :append_arg
            dest_name = "awk"
            range_tester = (x->x=="X"||x=="Y")
            metavar = "XY"
            help = "either X or Y; all XY's are " *
                   "stored in chunks"
    end

    set_default_arg_group(s) # reset the default arg group (which means arguments
                             # are automatically assigned to commands/options/pos.args
                             # groups)
    @add_arg_table s begin
        "-k"
            action = :store_const
            default = 0
            constant = 42
            help = "provide the answer"
        "--şİłłÿ"
            action = :store_true
            help = "an option with a silly name"
            group = "weird"   # this overrides the default group: this option
                              # will be grouped together with --awkward-option
    end

    parsed_args = parse_args(args, s)
    println("Parsed args:")
    for pa in parsed_args
        println("  $(pa[1])  =>  $(pa[2])")
    end
end

main(ARGS)
