# test 3: dest_name, metavar, range_tester, alternative
#         actions

function ap_settings3()

    s = ArgParseSettings("Test 3 for ArgParse.jl",
                         exc_handler = ArgParse.debug_handler)

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
        "-u"
            action = :store_const    # stores constant if given, default otherwise
            default = 0
            constant = 42.0
            help = "provide the answer as floating point"
        "--awkward-option"
            nargs = '+'                         # eats up as many argument as found (at least 1)
            action = :append_arg                # argument chunks are appended when the option is
                                                # called repeatedly
            dest_name = "awk"
            range_tester = (x->x=="X"||x=="Y")  # each argument must be either "X" or "Y"
            default = Any[Any["X"]]
            metavar = "XY"
            help = "either X or Y; all XY's are " *
                   "stored in chunks"
    end

    return s
end

let s = ap_settings3()
    ap_test3(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--opt1] [--opt2] [-k] [-u]
                                [--awkward-option XY [XY...]]

        Test 3 for ArgParse.jl

        optional arguments:
          --opt1                append O1
          --opt2                append O2
          -k                    provide the answer
          -u                    provide the answer as floating point
          --awkward-option XY [XY...]
                                either X or Y; all XY's are stored in chunks
                                (default: $(vecanyopen)$(vecanyopen)"X"$(vecanyclose)$(vecanyclose))

        """

    @compat @test ap_test3([]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "awk"=>Any[Any["X"]])
    @compat @test ap_test3(["--opt1", "--awk", "X", "X", "--opt2", "--opt2", "-k", "-u", "--awkward-option=Y", "X", "--opt1"]) ==
        Dict{String,Any}("O_stack"=>String["O1", "O2", "O2", "O1"], "k"=>42, "u"=>42.0, "awk"=>Any[Any["X"], Any["X", "X"], Any["Y", "X"]])
    @ap_test_throws ap_test3(["X"])
    @ap_test_throws ap_test3(["--awk", "Z"])
    @ap_test_throws ap_test3(["--awk", "-2"])

    # invalid option name
    @ee_test_throws @add_arg_table(s, "-2", action = :store_true)
    # wrong constants
    @ee_test_throws @add_arg_table(s, "--opt", action = :store_const, arg_type = Int, default = 1, constant = 1.5)
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_const, arg_type = Int, constant = 1.5)
    # wrong defaults
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_arg, arg_type = Int, default = Float64[])
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_arg, nargs = '+', arg_type = Int, default = Vector{Float64}[])
    @ee_test_throws @add_arg_table(s, "--opt", action = :store_arg, nargs = '+', arg_type = Int, default = [1.5])
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_arg, arg_type = Int, range_tester=x->x<=1, default = Int[0, 1, 2])
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_arg, nargs = '+', arg_type = Int, range_tester=x->x<=1, default = Vector{Int}[[1,1],[0,2]])
    @ee_test_throws @add_arg_table(s, "--opt", action = :store_arg, nargs = '+', range_tester = x->x<=1, default = [1.5])
    # no constants
    @ee_test_throws @add_arg_table(s, "--opt", action = :store_const, arg_type = Int, default = 1)
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_const, arg_type = Int)
    # incompatible action
    @ee_test_throws @add_arg_table(s, "--opt3", action = :store_const, arg_type = String, constant = "O3", dest_name = "O_stack", help = "append O3")
    # wrong range tester
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_arg, arg_type = Int, range_tester=x->string(x), default = Int[0, 1, 2])
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_arg, nargs = '+', arg_type = Int, range_tester=x->string(x), default = Vector{Int}[[1,1],[0,2]])
    @ee_test_throws @add_arg_table(s, "--opt", action = :store_arg, nargs = '+', range_tester = x->string(x), default = [1.5])
    @ee_test_throws @add_arg_table(s, "--opt", action = :store_arg, nargs = '+', range_tester = x->sqrt(x)<2, default = [-1.5])
    @ee_test_throws @add_arg_table(s, "--opt", action = :append_arg, nargs = '+', arg_type = Int, range_tester=x->sqrt(x)<2, default = Vector{Int}[[1,1],[0,-2]])

    # allow ambiguous options
    s.allow_ambiguous_opts = true
    @add_arg_table(s, "-2", action = :store_true)
    @compat @test ap_test3([]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "awk"=>Any[Any["X"]], "2"=>false)
    @compat @test ap_test3(["-2"]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "awk"=>Any[["X"]], "2"=>true)
    @compat @test ap_test3(["--awk", "X", "-2"]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "awk"=>Any[Any["X"], Any["X"]], "2"=>true)
    @ap_test_throws ap_test3(["--awk", "X", "-3"])

end
