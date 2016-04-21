# test 8: read args from file

function ap_settings8a()

    s = ArgParseSettings(fromfile_prefix_chars=['@'])

    @add_arg_table s begin
        "--opt1"               # an option (will take an argument)
        "--opt2", "-o"         # another option, with short form
        "arg1"                 # a positional argument
    end

    s.exc_handler = ArgParse.debug_handler

    return s
end

function ap_settings8b()  # unicode

    s = ArgParseSettings(fromfile_prefix_chars="@∘")

    @add_arg_table s begin
        "--opt1"               # an option (will take an argument)
        "--opt2", "-o"         # another option, with short form
        "arg1"                 # a positional argument
    end

    s.exc_handler = ArgParse.debug_handler

    return s
end

let s = ap_settings8a()
    ap_test8(args) = parse_args(args, s)

    @compat @test ap_test8(["@args-file1"]) == Dict(
        "opt1"=>nothing, "opt2"=>"y", "arg1"=>nothing)
    @compat @test ap_test8(["@args-file1", "arg"]) == Dict(
        "opt1"=>nothing, "opt2"=>"y", "arg1"=>"arg")
    @compat @test ap_test8(["@args-file2"]) == Dict(
        "opt1"=>"x", "opt2"=>"y", "arg1"=>nothing)
    @compat @test ap_test8(["@args-file2", "arg"]) == Dict(
        "opt1"=>"x", "opt2"=>"y", "arg1"=>"arg")
end

let s = ap_settings8b()
    ap_test8(args) = parse_args(args, s)

    @compat @test ap_test8(["∘args-file1"]) == Dict(
        "opt1"=>nothing, "opt2"=>"y", "arg1"=>nothing)
    @compat @test ap_test8(["@args-file1", "arg"]) == Dict(
        "opt1"=>nothing, "opt2"=>"y", "arg1"=>"arg")
    @compat @test ap_test8(["∘args-file2"]) == Dict(
        "opt1"=>"x", "opt2"=>"y", "arg1"=>nothing)
    @compat @test ap_test8(["@args-file2", "arg"]) == Dict(
        "opt1"=>"x", "opt2"=>"y", "arg1"=>"arg")
end

# not allowed
@ap_test_throws ArgParseSettings(fromfile_prefix_chars=['-'])
@ap_test_throws ArgParseSettings(fromfile_prefix_chars=['Å'])
@ap_test_throws ArgParseSettings(fromfile_prefix_chars=['8'])
