# test 13: setting ignore_unrecognized_opts with positional arguments is an error

@testset "test 13" begin
s = ArgParseSettings(description = "Test 13 for ArgParse.jl",
                     epilog = "Have fun!",
                     version = "Version 1.0",
                     add_version = true,
                     exc_handler = ArgParse.debug_handler,
                     ignore_unrecognized_opts = true)

@ee_test_throws @add_arg_table! s begin
    "arg1"
        nargs = 2                        # eats up two arguments; puts the result in a Vector
        help = "first argument, two " *
               "entries at once"
        required = true
end

end
