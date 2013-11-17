# test 2: version information, default values, flags,
#         options with types, optional arguments, variable
#         number of arguments

using ArgParse
using Base.Test

function ap_test2(args)

    s = ArgParseSettings(description = "Test 2 for ArgParse.jl",
                         version = "Version 1.0", # version info
                         add_version = true)      # audo-add version option

    @add_arg_table s begin
        "--opt1"
            nargs = '?'              # '?' means optional argument
            arg_type = Int           # only Int arguments allowed
            default = 0              # this is used when the option is not passed
            constant = 1             # this is used if --opt1 is paseed with no argument
            help = "an option"
        "--flag", "-f"
            action = :store_true   # this makes it a flag
            help = "a flag"
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

    s.exc_handler = (settings, err)->error(err.text)

    parsed_args = parse_args(args, s)
end

@test_throws ap_test2([])
@test ap_test2(["X", "Y"]) == (String=>Any)["opt1"=>0, "flag"=>false, "karma"=>0, "arg1"=>{"X", "Y"}, "arg2"=>{"no_arg_given"}]
@test ap_test2(["X", "Y", "-k", "-f", "Z", "--karma", "--opt"]) == (String=>Any)["opt1"=>1, "flag"=>true, "karma"=>2, "arg1"=>{"X", "Y"}, "arg2"=>{"Z"}]
@test ap_test2(["--opt", "-3", "X", "Y", "-k", "-f", "Z", "--karma"]) == (String=>Any)["opt1"=>-3, "flag"=>true, "karma"=>2, "arg1"=>{"X", "Y"}, "arg2"=>{"Z"}]
@test_throws ap_test2(["--opt", "1e-2", "X", "Y"])

