# test 02: version information, default values, flags,
#          options with types, optional arguments, variable
#          number of arguments;
#          function version of add_arg_table!

@testset "test 02" begin

function ap_settings2()

    s = ArgParseSettings(description = "Test 2 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table! s begin
        "--opt1"
            nargs = '?'              # '?' means optional argument
            arg_type = Int           # only Int arguments allowed
            default = 0              # this is used when the option is not passed
            constant = 1             # this is used if --opt1 is paseed with no argument
            help = "an option"
        "-O"
            arg_type = Symbol
            default = :xyz
            help = "another option"
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

function ap_settings2b()

    s = ArgParseSettings(description = "Test 2 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    add_arg_table!(s,
        "--opt1", Dict(
            :nargs => '?',             # '?' means optional argument
            :arg_type => Int,          # only Int arguments allowed
            :default => 0,             # this is used when the option is not passed
            :constant => 1,            # this is used if --opt1 is paseed with no argument
            :help => "an option"),
        ["-O"], Dict(
            :arg_type => Symbol,
            :default => :xyz,
            :help => "another option"),
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

function ap_settings2c()

    s = ArgParseSettings(description = "Test 2 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table!(s
        , "--opt1"
        ,     nargs = '?'              # '?' means optional argument
        ,     arg_type = Int           # only Int arguments allowed
        ,     default = 0              # this is used when the option is not passed
        ,     constant = 1             # this is used if --opt1 is paseed with no argument
        ,     help = "an option"
        , "-O"
        ,     arg_type = Symbol
        ,     default = :xyz
        ,     help = "another option"
        , ["--flag", "-f"]
        ,     action = :store_true   # this makes it a flag
        ,     help = "a flag"
        , ["--karma", "-k"]
        ,     action = :count_invocations  # increase a counter each time the option is given
        ,     help = "increase karma"
        , "arg1"
        ,     nargs = 2                        # eats up two arguments; puts the result in a Vector
        ,     help = "first argument, two " *
                     "entries at once"
        ,     required = true
        , "arg2"
        ,     nargs = '*'                            # eats up as many arguments as possible before an option
        ,     default = Any["no_arg_given"]          # since the result will be a Vector{Any}, the default must
                                                     # also be (or it can be [] or nothing)
        ,     help = "second argument, eats up " *
                     "as many items as possible " *
                     "before an option"
        )

    return s
end

function ap_settings2d()

    s = ArgParseSettings(description = "Test 2 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table! s begin
        ("--opt1";
              nargs = '?';              # '?' means optional argument
              arg_type = Int;           # only Int arguments allowed
              default = 0;              # this is used when the option is not passed
              constant = 1;             # this is used if --opt1 is paseed with no argument
              help = "an option"),
        ("-O";
              arg_type = Symbol;
              default = :xyz;
              help = "another option"),
        (["--flag", "-f"];
              action = :store_true;     # this makes it a flag
              help = "a flag")
        (["--karma", "-k"];
              action = :count_invocations; # increase a counter each time the option is given
              help = "increase karma")
        ("arg1";
              nargs = 2;                       # eats up two arguments; puts the result in a Vector
              help = "first argument, two " *
                     "entries at once";
              required = true)
        ("arg2";
              nargs = '*';                            # eats up as many arguments as possible before an option
              default = Any["no_arg_given"];          # since the result will be a Vector{Any}, the default must
                                                      # also be (or it can be [] or nothing)
              help = "second argument, eats up " *
                     "as many items as possible " *
                     "before an option")
    end

    return s
end

function ap_settings2e()

    s = ArgParseSettings(description = "Test 2 for ArgParse.jl",
                         epilog = "Have fun!",
                         version = "Version 1.0",
                         add_version = true,
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table!(s,
        "--opt1",
        begin
            nargs = '?'              # '?' means optional argument
            arg_type = Int           # only Int arguments allowed
            default = 0              # this is used when the option is not passed
            constant = 1             # this is used if --opt1 is paseed with no argument
            help = "an option"
        end,
        "-O",
        begin
            arg_type = Symbol
            default = :xyz
            help = "another option"
        end,
        ["--flag", "-f"],
        begin
            action = :store_true   # this makes it a flag
            help = "a flag"
        end,
        ["--karma", "-k"],
        begin
            action = :count_invocations  # increase a counter each time the option is given
            help = "increase karma"
        end,
        "arg1",
        begin
            nargs = 2                        # eats up two arguments; puts the result in a Vector
            help = "first argument, two " *
                   "entries at once"
            required = true
        end,
        "arg2",
        begin
            nargs = '*'                            # eats up as many arguments as possible before an option
            default = Any["no_arg_given"]          # since the result will be a Vector{Any}, the default must
                                                   # also be (or it can be [] or nothing)
            help = "second argument, eats up " *
                   "as many items as possible " *
                   "before an option"
        end)

    return s
end

for s = [ap_settings2(), ap_settings2b(), ap_settings2c(), ap_settings2d(), ap_settings2e()]
    ap_test2(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--opt1 [OPT1]] [-O O] [-f] [-k] arg1 arg1
                                [arg2...]

        Test 2 for ArgParse.jl

        positional arguments:
          arg1           first argument, two entries at once
          arg2           second argument, eats up as many items as possible
                         before an option (default: Any["no_arg_given"])

        optional arguments:
          --opt1 [OPT1]  an option (type: $Int, default: 0, without arg: 1)
          -O O           another option (type: $Symbol, default: :xyz)
          -f, --flag     a flag
          -k, --karma    increase karma

        Have fun!

        """

    @test stringversion(s) == "Version 1.0\n"

    @ap_test_throws ap_test2([])
    @test ap_test2(["X", "Y"]) == Dict{String,Any}("opt1"=>0, "O"=>:xyz, "flag"=>false, "karma"=>0, "arg1"=>Any["X", "Y"], "arg2"=>Any["no_arg_given"])
    @test ap_test2(["X", "Y", "-k", "-f", "Z", "--karma", "--opt"]) == Dict{String,Any}("opt1"=>1, "O"=>:xyz, "flag"=>true, "karma"=>2, "arg1"=>Any["X", "Y"], "arg2"=>Any["Z"])
    @test ap_test2(["X", "Y", "--opt", "-k", "-f", "Z", "--karma"]) == Dict{String,Any}("opt1"=>1, "O"=>:xyz, "flag"=>true, "karma"=>2, "arg1"=>Any["X", "Y"], "arg2"=>Any["Z"])
    @test ap_test2(["X", "Y", "--opt", "--karma", "-O", "XYZ", "-f", "Z", "-k"]) == Dict{String,Any}("opt1"=>1, "O"=>:XYZ, "flag"=>true, "karma"=>2, "arg1"=>Any["X", "Y"], "arg2"=>Any["Z"])
    @test ap_test2(["--opt", "-3", "X", "Y", "-k", "-f", "Z", "-O", "a b c", "--karma"]) == Dict{String,Any}("opt1"=>-3, "O"=>Symbol("a b c"), "flag"=>true, "karma"=>2, "arg1"=>Any["X", "Y"], "arg2"=>Any["Z"])
    @ap_test_throws ap_test2(["--opt"])
    @ap_test_throws ap_test2(["--opt="])
    @ap_test_throws ap_test2(["--opt", "", "X", "Y"])
    @ap_test_throws ap_test2(["--opt", "1e-2", "X", "Y"])
    @ap_test_throws ap_test2(["X", "Y", "-z"])
    @ap_test_throws ap_test2(["X", "Y", "-z", "a b c"])
    @ap_test_throws ap_test2(["X", "Y", "--zzz"])
    @ap_test_throws ap_test2(["X", "Y", "--zzz", "a b c"])

    @aps_test_throws @add_arg_table!(s, "required_arg_after_optional_args", required = true)
    # wrong default
    @aps_test_throws @add_arg_table!(s, "--opt", arg_type = Int, default = 1.5)
    @aps_test_throws @add_arg_table!(s, "--opt3", arg_type = Symbol, default = "string")
    # wrong range tester
    @aps_test_throws @add_arg_table!(s, "--opt", arg_type = Int, range_tester = x->string(x), default = 1)
    @aps_test_throws @add_arg_table!(s, "--opt", arg_type = Int, range_tester = x->sqrt(x)<1, default = -1)
end

end
