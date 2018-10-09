# test 09: preformatted desc/epilog

@testset "test 09" begin

function ap_settings9()

    s = ArgParseSettings(description = """
                         Test 9 for ArgParse.jl
                         Testing preformatted description/epilog

                             1
                            1 1
                           1 2 1
                          1 3 3 1
                         """,
                         preformatted_description=true,
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table s begin
        "--opt"
            required = true
            help = "a required option"
    end

    s.epilog = """
               Example:

                 <program> --opt X

               - one
               - two
               - three
               """
    s.preformatted_epilog = true

    return s
end

let s = ap_settings9()
    ap_test7(args) = parse_args(args, s)

    @test stringhelp(s) == """
                           usage: argparse_test9.jl --opt OPT

                           Test 9 for ArgParse.jl
                           Testing preformatted description/epilog

                               1
                              1 1
                             1 2 1
                            1 3 3 1

                           optional arguments:
                             --opt OPT  a required option

                           Example:

                             <program> --opt X

                           - one
                           - two
                           - three

                           """

    @ap_test_throws ap_test7([])
    @test ap_test7(["--opt=A"]) == Dict{String,Any}("opt"=>"A")
end

end
