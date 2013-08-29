# test 1: minimal options/arguments, auto-generated help/version

using ArgParse
using Base.Test

function ap_test1(args)

    s = ArgParseSettings()

    @add_arg_table s begin
        "--opt1"               # an option (will take an argument)
        "--opt2", "-o"         # another option, with short form
        "arg1"                 # a positional argument
    end

    s.exc_handler = (settings, err)->error(err.text)


    parsed_args = parse_args(args, s) # the result is a Dict{String,Any}
end

@test ap_test1([]) == (String=>Any)["opt1"=>nothing, "opt2"=>nothing, "arg1"=>nothing]
@test ap_test1(["arg"]) == (String=>Any)["opt1"=>nothing, "opt2"=>nothing, "arg1"=>"arg"]
@test ap_test1(["--opt1", "X", "-o=5", "--", "-arg"]) == (String=>Any)["opt1"=>"X", "opt2"=>"5", "arg1"=>"-arg"]
@test_throws ap_test1(["--opt1", "X", "-o=5", "-arg"])
@test ap_test1(["--opt1=", "--opt2=5"]) == (String=>Any)["opt1"=>"", "opt2"=>"5", "arg1"=>nothing]
