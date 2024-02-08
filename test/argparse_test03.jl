# test 03: dest_name, metavar, range_tester, alternative
#          actions, custom parser

struct CustomType
end

@testset "test 03" begin

function ArgParse.parse_item(::Type{CustomType}, x::AbstractString)
    @assert x == "custom"
    return CustomType()
end

Base.show(io::IO, ::Type{CustomType}) = print(io, "CustomType")
Base.show(io::IO, c::CustomType) = print(io, "CustomType()")

function ap_add_table3!(s::ArgParseSettings)

    @add_arg_table! s begin
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
        "--array"
            default = [7, 3, 2]
            arg_type = Vector{Int}
            eval_arg = true          # enables evaluation of the argument. NOTE: security risk!
            help = "create an array"
        "--custom"
            default = CustomType()
            arg_type = CustomType    # uses the user-defined version of ArgParse.parse_item
            help = "the only accepted argument is \"custom\""
        "--oddint"
            default = 1
            arg_type = Int
            range_tester = x->(isodd(x) || error("not odd")) # range error ≡ false
            help = "an odd integer"
        "--collect"
            action = :append_arg
            arg_type = Int
            metavar = "C"
            help = "collect things"
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
end

function ap_settings3()

    s = ArgParseSettings("Test 3 for ArgParse.jl",
                         exc_handler = ArgParse.debug_handler)

    ap_add_table3!(s)

    return s
end

function ap_settings3b()

    s = ArgParseSettings("Test 3 for ArgParse.jl",
                         exc_handler = ArgParse.debug_handler,
                         ignore_unrecognized_opts = true)

    ap_add_table3!(s)

    return s
end

function runtest(s, ignore)
    ap_test3(args) = parse_args(args, s)

    ## ugly workaround for the change of printing Vectors in julia 1.6,
    ## from Array{Int,1} to Vector{Int}
    array_help_lines = if string(Vector{Any}) == "Vector{Any}"
        """
          --array ARRAY         create an array (type: Vector{$Int}, default:
                                $([7, 3, 2]))
        """
    else
        """
          --array ARRAY         create an array (type: Array{$Int,1},
                                default: $([7, 3, 2]))
        """
    end
    array_help_lines = array_help_lines[1:end-1] # remove an extra newline

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--opt1] [--opt2] [-k] [-u] [--array ARRAY]
                                [--custom CUSTOM] [--oddint ODDINT]
                                [--collect C] [--awkward-option XY [XY...]]

        Test 3 for ArgParse.jl

        optional arguments:
          --opt1                append O1
          --opt2                append O2
          -k                    provide the answer
          -u                    provide the answer as floating point
        $array_help_lines
          --custom CUSTOM       the only accepted argument is "custom" (type:
                                CustomType, default: CustomType())
          --oddint ODDINT       an odd integer (type: $Int, default: 1)
          --collect C           collect things (type: $Int)
          --awkward-option XY [XY...]
                                either X or Y; all XY's are stored in chunks
                                (default: Any[Any["X"]])

        """

    @test ap_test3([]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "array"=>[7, 3, 2], "custom"=>CustomType(), "oddint"=>1, "collect"=>[], "awk"=>Any[Any["X"]])
    @test ap_test3(["--opt1", "--awk", "X", "X", "--opt2", "--opt2", "-k", "--coll", "5", "-u", "--array=[4]", "--custom", "custom", "--collect", "3", "--awkward-option=Y", "X", "--opt1", "--oddint", "-1"]) ==
    Dict{String,Any}("O_stack"=>String["O1", "O2", "O2", "O1"], "k"=>42, "u"=>42.0, "array"=>[4], "custom"=>CustomType(), "oddint"=>-1, "collect"=>[5, 3], "awk"=>Any[Any["X"], Any["X", "X"], Any["Y", "X"]])
    @ap_test_throws ap_test3(["X"])
    @ap_test_throws ap_test3(["--awk", "Z"])
    @ap_test_throws ap_test3(["--awk", "-2"])
    @ap_test_throws ap_test3(["--array", "7"])
    @ap_test_throws ap_test3(["--custom", "default"])
    @ap_test_throws ap_test3(["--oddint", "0"])
    @ap_test_throws ap_test3(["--collect", "0.5"])
    if ignore
        ap_test3(["--foobar"])
        @test ap_test3(["--foobar"]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "array"=>[7, 3, 2], "custom"=>CustomType(), "oddint"=>1, "collect"=>[], "awk"=>Any[Any["X"]])
        @test ap_test3(["--foobar", "1"]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "array"=>[7, 3, 2], "custom"=>CustomType(), "oddint"=>1, "collect"=>[], "awk"=>Any[Any["X"]])
        @test ap_test3(["--foobar", "a b c", "--opt1", "--awk", "X", "X", "--opt2", "--opt2", "-k", "--coll", "5", "-u", "--array=[4]", "--custom", "custom", "--collect", "3", "--awkward-option=Y", "X", "--opt1", "--oddint", "-1"]) ==
        Dict{String,Any}("O_stack"=>String["O1", "O2", "O2", "O1"], "k"=>42, "u"=>42.0, "array"=>[4], "custom"=>CustomType(), "oddint"=>-1, "collect"=>[5, 3], "awk"=>Any[Any["X"], Any["X", "X"], Any["Y", "X"]])
    else
        @ap_test_throws ap_test3(["--foobar"])
        @ap_test_throws ap_test3(["--foobar", "1"])
        @ap_test_throws ap_test3(["--foobar", "a b c", "--opt1", "--awk", "X", "X", "--opt2", "--opt2", "-k", "--coll", "5", "-u", "--array=[4]", "--custom", "custom", "--collect", "3", "--awkward-option=Y", "X", "--opt1", "--oddint", "-1"])
    end

    # invalid option name
    @aps_test_throws @add_arg_table!(s, "-2", action = :store_true)
    # wrong constants
    @aps_test_throws @add_arg_table!(s, "--opt", action = :store_const, arg_type = Int, default = 1, constant = 1.5)
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_const, arg_type = Int, constant = 1.5)
    # wrong defaults
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_arg, arg_type = Int, default = Float64[])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_arg, nargs = '+', arg_type = Int, default = Vector{Float64}[])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :store_arg, nargs = '+', arg_type = Int, default = [1.5])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :store_arg, nargs = '+', arg_type = Int, default = 1)
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_arg, arg_type = Int, range_tester=x->x<=1, default = Int[0, 1, 2])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_arg, nargs = '+', arg_type = Int, range_tester=x->x<=1, default = Vector{Int}[[1,1],[0,2]])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :store_arg, nargs = '+', range_tester = x->x<=1, default = [1.5])
    # no constants
    @aps_test_throws @add_arg_table!(s, "--opt", action = :store_const, arg_type = Int, default = 1)
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_const, arg_type = Int)
    # incompatible action
    @aps_test_throws @add_arg_table!(s, "--opt3", action = :store_const, arg_type = String, constant = "O3", dest_name = "O_stack", help = "append O3")
    # wrong range tester
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_arg, arg_type = Int, range_tester=x->string(x), default = Int[0, 1, 2])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_arg, nargs = '+', arg_type = Int, range_tester=x->string(x), default = Vector{Int}[[1,1],[0,2]])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :store_arg, nargs = '+', range_tester = x->string(x), default = [1.5])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :store_arg, nargs = '+', range_tester = x->sqrt(x)<2, default = [-1.5])
    @aps_test_throws @add_arg_table!(s, "--opt", action = :append_arg, nargs = '+', arg_type = Int, range_tester=x->sqrt(x)<2, default = Vector{Int}[[1,1],[0,-2]])

    # allow ambiguous options
    s.allow_ambiguous_opts = true
    @add_arg_table!(s, "-2", action = :store_true)
    @test ap_test3([]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "array"=>[7, 3, 2], "custom"=>CustomType(), "oddint"=>1, "collect"=>[], "awk"=>Any[Any["X"]], "2"=>false)
    @test ap_test3(["-2"]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "array"=>[7, 3, 2], "custom"=>CustomType(), "oddint"=>1, "collect"=>[], "awk"=>Any[["X"]], "2"=>true)
    @test ap_test3(["--awk", "X", "-2"]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "u"=>0, "array"=>[7, 3, 2], "custom"=>CustomType(), "oddint"=>1, "collect"=>[], "awk"=>Any[Any["X"], Any["X"]], "2"=>true)
    @ap_test_throws ap_test3(["--awk", "X", "-3"])

end

for (s, ignore) = [(ap_settings3(), false), (ap_settings3b(), true)]
    runtest(s, ignore)
end

end
