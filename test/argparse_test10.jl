# test 2: multiple metavars
#         function version of add_arg_table

function ap_settings10()

    s = ArgParseSettings(description = "Test 10 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table s begin
        "--opt1"
            nargs = 2              # exactly 2 arguments must be specified
            arg_type = Int           # only Int arguments allowed
            default = [0, 1]              # this is used when the option is not passed
            metavar = ["A", "B"]          # two metavars for two arguments
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
            default = Any["no_arg_given"]          # since the result will be a Vector{Any}, the default must
                                                   # also be (or it can be [] or nothing)
            help = "second argument, eats up " *
                   "as many items as possible " *
                   "before an option"
    end

    return s
end

@compat function ap_settings10b()

    s = ArgParseSettings(description = "Test 10 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    add_arg_table(s,
        "--opt1", Dict(
            :nargs => 2,             # exactly 2 arguments
            :arg_type => Int,          # only Int arguments allowed
            :default => [0, 1],             # this is used when the option is not passed
            :metavar => ["A", "B"],          # two metavars for two arguments
            :help => "an option"),
        ["--flag", "-f"], Dict(
            :action => :store_true,  # this makes it a flag
            :help => "a flag"),
        ["--karma", "-k"], Dict(
            :action => :count_invocations, # increase a counter each time the option is given
            :help => "increase karma"),
        "arg1", Dict(
            :nargs => 2,                       # eats up two arguments; puts the result in a Vector
            :help => "first argument, two " *
                     "entries at once",
            :required => true),
        "arg2", Dict(
            :nargs => '*',                           # eats up as many arguments as possible before an option
            :default => Any["no_arg_given"],         # since the result will be a Vector{Any}, the default must
                                                   # also be (or it can be [] or nothing)
            :help => "second argument, eats up " *
                     "as many items as possible " *
                     "before an option")
    )

    return s
end

# test to ensure length of vector is the same as nargs

function ap_settings10c(in_nargs)

    s = ArgParseSettings(description = "Test 10 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    add_arg_table(s,
        "--opt1", Dict(
            :nargs => in_nargs,
            :arg_type => Int,
            :default => [0, 1],
            :metavar => ["A", "B"])
    )

    return true
end

@test ap_settings10c(2)
@ee_test_throws ap_settings10c(1)
@ee_test_throws ap_settings10c(3)
@ee_test_throws ap_settings10c('*')
@ee_test_throws ap_settings10c('?')
@ee_test_throws ap_settings10c('+')
@ee_test_throws ap_settings10c('A')
@ee_test_throws ap_settings10c('R')
@ee_test_throws ap_settings10c('0')

# Test to ensure multiple metavars cannot be used on positional args

function ap_settings10d()
    s = ArgParseSettings(description = "Test 10 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    add_arg_table(s,
        "opt1", Dict(
            :nargs => 2,
            :arg_type => Int,
            :metavar => ["A", "B"])
    )

    return true
end

@ee_test_throws ap_settings10d()

for s = [ap_settings10(), ap_settings10b()]
    ap_test10(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--opt1 A B] [-f] [-k] arg1 arg1 [arg2...]

        Test 10 for ArgParse.jl

        positional arguments:
          arg1         first argument, two entries at once
          arg2         second argument, eats up as many items as possible
                       before an option (default: $(vecanyopen)"no_arg_given"$(vecanyclose))

        optional arguments:
          --opt1 A B   an option (type: $Int, default: [0,1])
          -f, --flag   a flag
          -k, --karma  increase karma

        Have fun!

        """

    @test stringversion(s) == "Version 1.0\n"

    @ap_test_throws ap_test10([])
    @compat @test ap_test10(["X", "Y"]) == Dict{AbstractString,Any}("opt1"=>[0, 1], "flag"=>false, "karma"=>0, "arg1"=>Any["X", "Y"], "arg2"=>Any["no_arg_given"])
    @compat @test ap_test10(["X", "Y", "-k", "-f", "Z", "--karma", "--opt1", "2", "3"]) == Dict{AbstractString,Any}("opt1"=>[2, 3], "flag"=>true, "karma"=>2, "arg1"=>Any["X", "Y"], "arg2"=>Any["Z"])
    @compat @test ap_test10(["--opt1", "-3", "-5", "X", "Y", "-k", "-f", "Z", "--karma"]) == Dict{AbstractString,Any}("opt1"=>[-3, -5], "flag"=>true, "karma"=>2, "arg1"=>Any["X", "Y"], "arg2"=>Any["Z"])
    @ap_test_throws ap_test10(["--opt"])
    @ap_test_throws ap_test10(["--opt="])
    @ap_test_throws ap_test10(["--opt", "", "X", "Y"])
    @ap_test_throws ap_test10(["--opt", "1e-2", "X", "Y"])
    @ap_test_throws ap_test10(["X", "Y", "--opt1", "1", "a"])
    @ap_test_throws ap_test10(["X", "Y", "--opt1", "1"])
    @ap_test_throws ap_test10(["X", "Y", "--opt1", "a", "b"])

    @ee_test_throws @add_arg_table(s, "required_arg_after_optional_args", required = true)
    # wrong default
    @ee_test_throws @add_arg_table(s, "--opt", arg_type = Int, default = 1.5)
    # wrong range tester
    @ee_test_throws @add_arg_table(s, "--opt", arg_type = Int, range_tester = x->string(x), default = 1)
    @ee_test_throws @add_arg_table(s, "--opt", arg_type = Int, range_tester = x->sqrt(x)<1, default = -1)
end
