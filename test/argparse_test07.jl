# test 07: required options, line breaks in desc/epilog

@testset "test 07" begin

function ap_settings7()

    s = ArgParseSettings(description = "Test 7 for ArgParse.jl\n\nTesting oxymoronic options",
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table! s begin
        "--oxymoronic", "-x"
            required = true
            help = "a required option"
        "--opt"
            required = false
            help = "a true option"
        "--flag", "-f"
            action = :store_true
            help = "a flag"
        "-o"
            required = true
            help = "yet another oxymoronic option"
    end

    s.epilog = """
        Example:\n
        \n
        \ua0\ua0<program> --oxymoronic X -o 1\n
        \n
        Not a particularly enlightening example, but
        on the other hand this program does not really
        do anything useful.
        """

    return s
end

let s = ap_settings7()
    ap_test7(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) -x OXYMORONIC [--opt OPT] [-f] -o O

        Test 7 for ArgParse.jl
        Testing oxymoronic options

        optional arguments:
          -x, --oxymoronic OXYMORONIC
                                a required option
          --opt OPT             a true option
          -f, --flag            a flag
          -o O                  yet another oxymoronic option

        Example:

          <program> --oxymoronic X -o 1

        Not a particularly enlightening example, but on the other hand this
        program does not really do anything useful.

        """

    @ap_test_throws ap_test7([])
    @test ap_test7(["--oxymoronic=A", "-o=B"]) == Dict{String,Any}("oxymoronic"=>"A", "opt"=>nothing, "o"=>"B", "flag"=>false)
    @ap_test_throws ap_test7(["--oxymoronic=A", "--opt=B"])
    @ap_test_throws ap_test7(["--opt=A, -o=B"])
    s.suppress_warnings = true
    add_arg_table!(s, "-g", Dict(:action=>:store_true, :required=>true))
    @test ap_test7(["--oxymoronic=A", "-o=B"]) == Dict{String,Any}("oxymoronic"=>"A", "opt"=>nothing, "o"=>"B", "flag"=>false, "g"=>false)
end

end
