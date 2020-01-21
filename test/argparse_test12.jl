# test 12: mutually exclusive and required argument groups

@testset "test 12" begin

function ap_settings12()

    s = ArgParseSettings("Test 12 for ArgParse.jl",
                         exc_handler = ArgParse.debug_handler)

    add_arg_group(s, "mutually exclusive options", exclusive=true)
    @add_arg_table s begin
        "--maybe", "-M"
            action = :store_true
            help = "maybe..."
        "--maybe-not", "-N"
            action = :store_true
            help = "maybe not..."
    end

    add_arg_group(s, "required mutually exclusive options", "reqexc", exclusive=true, required=true)
    @add_arg_table s begin
        "--either", "-E"
            action = :store_true
            help = "choose the `either` option"
    end

    add_arg_group(s, "required arguments", required=true)
    @add_arg_table s begin
        "--enhance", "-+"
            action = :store_true
            help = "set the enhancement option"
        "arg1"
            nargs = 2                        # eats up two arguments; puts the result in a Vector
            help = "first argument, two " *
                   "entries at once"
    end

    set_default_arg_group(s, "reqexc")
    @add_arg_table s begin
        "--or", "-O"
            action = :store_arg
            arg_type = Int
            default = 0
            help = "set the `or` option"
    end

    set_default_arg_group(s)
    @add_arg_table s begin
        "-k"
            action = :store_const
            default = 0
            constant = 42
            help = "provide the answer"
        "--or-perhaps"
            action = :store_arg
            arg_type = String
            default = ""
            help = "set the `or-perhaps` option"
            group = "reqexc"
    end

    return s
end

let s = ap_settings12()
    ap_test12(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) {-E | -O OR | --or-perhaps OR-PERHAPS} [-M |
                                -N] [-+] [-k] [arg1 arg1]

        Test 12 for ArgParse.jl

        optional arguments:
          -k                    provide the answer

        mutually exclusive options:
          -M, --maybe           maybe...
          -N, --maybe-not       maybe not...

        required mutually exclusive options:
          -E, --either          choose the `either` option
          -O, --or OR           set the `or` option (type: Int64, default: 0)
          --or-perhaps OR-PERHAPS
                                set the `or-perhaps` option (default: \"\")

        required arguments:
          -+, --enhance         set the enhancement option
          arg1                  first argument, two entries at once

        """

    @ap_test_throws ap_test12([])
    @test ap_test12(["-E", "-+"]) ==
        Dict{String,Any}("k"=>0, "maybe"=>false, "maybe-not"=>false, "either"=>true, "or"=>0, "or-perhaps"=>"", "enhance"=>true, "arg1"=>[])
    @test ap_test12(["-E", "-+", "--either"]) ==
        Dict{String,Any}("k"=>0, "maybe"=>false, "maybe-not"=>false, "either"=>true, "or"=>0, "or-perhaps"=>"", "enhance"=>true, "arg1"=>[])
    @test ap_test12(["A", "B", "--either"]) ==
        Dict{String,Any}("k"=>0, "maybe"=>false, "maybe-not"=>false, "either"=>true, "or"=>0, "or-perhaps"=>"", "enhance"=>false, "arg1"=>["A", "B"])
    @test ap_test12(["--enhance", "A", "B", "--or", "55", "-k"]) ==
        Dict{String,Any}("k"=>42, "maybe"=>false, "maybe-not"=>false, "either"=>false, "or"=>55, "or-perhaps"=>"", "enhance"=>true, "arg1"=>["A", "B"])
    @test ap_test12(["A", "B", "-Mk+O55", "-M"]) ==
        Dict{String,Any}("k"=>42, "maybe"=>true, "maybe-not"=>false, "either"=>false, "or"=>55, "or-perhaps"=>"", "enhance"=>true, "arg1"=>["A", "B"])
    @test ap_test12(["--enhance", "A", "B", "--or=55", "-k", "--maybe-not"]) ==
        Dict{String,Any}("k"=>42, "maybe"=>false, "maybe-not"=>true, "either"=>false, "or"=>55, "or-perhaps"=>"", "enhance"=>true, "arg1"=>["A", "B"])
    @test ap_test12(["--enhance", "A", "B", "--or-perhaps", "--either", "-k", "--maybe-not"]) ==
        Dict{String,Any}("k"=>42, "maybe"=>false, "maybe-not"=>true, "either"=>false, "or"=>0, "or-perhaps"=>"--either", "enhance"=>true, "arg1"=>["A", "B"])

    # combinations of missing arguments and too many arguments from the same group
    @ap_test_throws ap_test12(["-M", "--enhance", "A", "B", "--or", "55", "-k", "--maybe-not"])
    @ap_test_throws ap_test12(["--maybe", "--enhance", "A", "B", "--or", "55", "-k", "-N"])
    @ap_test_throws ap_test12(["--enhance", "A", "B", "-MkNO=55"])
    @ap_test_throws ap_test12(["--maybe", "--enhance", "A", "B", "-N"])
    @ap_test_throws ap_test12(["-+NE", "--or-perhaps=?"])
    @ap_test_throws ap_test12(["-ME", "A", "A", "--or-perhaps=?"])
    @ap_test_throws ap_test12(["-MO55", "A", "A", "--or-perhaps=?"])
    @ap_test_throws ap_test12(["--enhanced", "-+MkO55", "A", "A", "--or-perhaps=?"])
    # invalid arguments in mutually exclusive groups
    @ee_test_throws @add_arg_table(s, "arg2", action = :store_arg, group = "reqexc")
    set_default_arg_group(s, "reqexc")
    @ee_test_throws @add_arg_table(s, "arg2", action = :store_arg)
end

end
