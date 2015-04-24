# test 7: required options

using OptionsMod

function ap_settings7()

    s = ArgParseSettings(description = "Test 7 for ArgParse.jl",
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table s begin
        "--oxymoronic"
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

    return s
end

let s = ap_settings7()
    ap_test7(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) --oxymoronic OXYMORONIC [--opt OPT] [-f] -o O

        Test 7 for ArgParse.jl

        optional arguments:
          --oxymoronic OXYMORONIC
                                a required option
          --opt OPT             a true option
          -f, --flag            a flag
          -o O                  yet another oxymoronic option

        """

    @ap_test_throws ap_test7([])
    @compat @test ap_test7(["--oxymoronic=A", "-o=B"]) == Dict{String,Any}("oxymoronic"=>"A", "opt"=>nothing, "o"=>"B", "flag"=>false)
    @ap_test_throws ap_test7(["--oxymoronic=A", "--opt=B"])
    @ap_test_throws ap_test7(["--opt=A, -o=B"])
end
