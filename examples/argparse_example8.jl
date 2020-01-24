# example 8: mutually exculsive and required groups

using ArgParse

function main(args)

    s = ArgParseSettings("Example 8 for argparse.jl: " *
                         "mutually exclusive and requiredd groups.")

    add_arg_group!(s, "Mutually exclusive options", exclusive=true)
    @add_arg_table! s begin
        "--maybe", "-M"
            action = :store_true
            help = "maybe..."
        "--maybe-not", "-N"
            action = :store_true
            help = "maybe not..."
    end

    add_arg_group!(s, "Required mutually exclusive options", exclusive=true, required=true)
    @add_arg_table! s begin
        "--either", "-E"
            action = :store_true
            help = "choose the `either` option"
        "--or", "-O"
            action = :store_arg
            arg_type = Int
            help = "set the `or` option"
    end

    add_arg_group!(s, "Required arguments", required=true)
    @add_arg_table! s begin
        "--enhance", "-+"
            action = :store_const
            default = 0
            constant = 42
            help = "set the enhancement option"
        "arg1"
            nargs = 2                        # eats up two arguments; puts the result in a Vector
            help = "first argument, two " *
                   "entries at once"
    end

    parsed_args = parse_args(args, s)
    println("Parsed args:")
    for (key,val) in parsed_args
        println("  $key  =>  $(repr(val))")
    end
end

main(ARGS)
