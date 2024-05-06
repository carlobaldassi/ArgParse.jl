# test 14: default values converted to arg_type

@testset "test 14" begin

function ap_settings14()

    s = ArgParseSettings(description = "Test 14 for ArgParse.jl",
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table! s begin
        "--opt1"
            nargs = '?'
            arg_type = Int
            default = 0.0
            constant = 1.0
            help = "an option"
        "-O"
            arg_type = Symbol
            default = "xyz"
            help = "another option"
        "--opt2"
            nargs = '+'
            arg_type = Int
            default = [0.0]
            help = "another option, many args"
        "--opt3"
            action = :append_arg
            arg_type = Int
            default = [0.0]
            help = "another option, appends arg"
        "--opt4"
            action = :append_arg
            nargs = '+'
            arg_type = Int
            default = [[0.0]]
            help = "another option, appends many args"
    end

    return s
end

let s = ap_settings14()
    ap_test14(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--opt1 [OPT1]] [-O O]
                                [--opt2 OPT2 [OPT2...]] [--opt3 OPT3]
                                [--opt4 OPT4 [OPT4...]]

        Test 14 for ArgParse.jl

        optional arguments:
          --opt1 [OPT1]         an option (type: $(Int), default: 0, without
                                arg: 1)
          -O O                  another option (type: Symbol, default: :xyz)
          --opt2 OPT2 [OPT2...]
                                another option, many args (type: $(Int),
                                default: [0])
          --opt3 OPT3           another option, appends arg (type: $(Int),
                                default: [0])
          --opt4 OPT4 [OPT4...]
                                another option, appends many args (type:
                                $(Int), default: $([[0]]))

        """

    @test ap_test14([]) == Dict{String,Any}("opt1"=>0, "O"=>:xyz, "opt2"=>[0], "opt3"=>[0], "opt4"=>[[0]])
    @test ap_test14(["--opt1"]) == Dict{String,Any}("opt1"=>1, "O"=>:xyz, "opt2"=>[0], "opt3"=>[0], "opt4"=>[[0]])
    @test ap_test14(["--opt1", "33", "--opt2", "5", "7"]) == Dict{String,Any}("opt1"=>33, "O"=>:xyz, "opt2"=>[5, 7], "opt3"=>[0], "opt4"=>[[0]])
    @test ap_test14(["--opt3", "5", "--opt3", "7"]) == Dict{String,Any}("opt1"=>0, "O"=>:xyz, "opt2"=>[0], "opt3"=>[0, 5, 7], "opt4"=>[[0]])
    @test ap_test14(["--opt4", "5", "7", "--opt4", "11", "13", "17"]) == Dict{String,Any}("opt1"=>0, "O"=>:xyz, "opt2"=>[0], "opt3"=>[0], "opt4"=>[[0], [5, 7], [11, 13, 17]])
end

end
