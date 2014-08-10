# test 1: minimal options/arguments, auto-generated help/version

function ap_settings1()

    s = ArgParseSettings()

    @add_arg_table s begin
        "--opt1"               # an option (will take an argument)
        "--opt2", "-o"         # another option, with short form
        "arg1"                 # a positional argument
    end

    s.exc_handler = (settings, err)->throw(err)

    return s
end

let s = ap_settings1()
    ap_test1(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--opt1 OPT1] [-o OPT2] [arg1]

        positional arguments:
          arg1

        optional arguments:
          --opt1 OPT1
          -o, --opt2 OPT2

        """

    @test ap_test1([]) == (String=>Any)["opt1"=>nothing, "opt2"=>nothing, "arg1"=>nothing]
    @test ap_test1(["arg"]) == (String=>Any)["opt1"=>nothing, "opt2"=>nothing, "arg1"=>"arg"]
    @test ap_test1(["--opt1", "X", "-o=5", "--", "-arg"]) == (String=>Any)["opt1"=>"X", "opt2"=>"5", "arg1"=>"-arg"]
    @ap_test_throws ap_test1(["--opt1", "X", "-o=5", "-arg"])
    @test ap_test1(["--opt1=", "--opt2=5"]) == (String=>Any)["opt1"=>"", "opt2"=>"5", "arg1"=>nothing]
end
