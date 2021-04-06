# test 08: read args from file, read version from project

@testset "test 08" begin

function ap_settings8a()

    s = ArgParseSettings(fromfile_prefix_chars=['@'])

    @add_arg_table! s begin
        "--opt1"               # an option (will take an argument)
        "--opt2", "-o"         # another option, with short form
        "arg1"                 # a positional argument
    end

    s.exc_handler = ArgParse.debug_handler

    return s
end

function ap_settings8b()  # unicode

    s = ArgParseSettings(fromfile_prefix_chars="@∘")

    @add_arg_table! s begin
        "--opt1"               # an option (will take an argument)
        "--opt2", "-o"         # another option, with short form
        "arg1"                 # a positional argument
    end

    s.exc_handler = ArgParse.debug_handler

    return s
end

let s = ap_settings8a()
    ap_test8(args) = parse_args(args, s)

    @test ap_test8(["@args-file1"]) == Dict(
        "opt1"=>nothing, "opt2"=>"y", "arg1"=>nothing)
    @test ap_test8(["@args-file1", "arg"]) == Dict(
        "opt1"=>nothing, "opt2"=>"y", "arg1"=>"arg")
    @test ap_test8(["@args-file2"]) == Dict(
        "opt1"=>"x", "opt2"=>"y", "arg1"=>nothing)
    @test ap_test8(["@args-file2", "arg"]) == Dict(
        "opt1"=>"x", "opt2"=>"y", "arg1"=>"arg")
end

let s = ap_settings8b()
    ap_test8(args) = parse_args(args, s)

    @test ap_test8(["∘args-file1"]) == Dict(
        "opt1"=>nothing, "opt2"=>"y", "arg1"=>nothing)
    @test ap_test8(["@args-file1", "arg"]) == Dict(
        "opt1"=>nothing, "opt2"=>"y", "arg1"=>"arg")
    @test ap_test8(["∘args-file2"]) == Dict(
        "opt1"=>"x", "opt2"=>"y", "arg1"=>nothing)
    @test ap_test8(["@args-file2", "arg"]) == Dict(
        "opt1"=>"x", "opt2"=>"y", "arg1"=>"arg")
end

# not allowed
@ap_test_throws ArgParseSettings(fromfile_prefix_chars=['-'])
@ap_test_throws ArgParseSettings(fromfile_prefix_chars=['Å'])
@ap_test_throws ArgParseSettings(fromfile_prefix_chars=['8'])

# default project version
@test stringversion(ArgParseSettings(
    add_version = true, 
    version = @project_version
)) == "1.0.0\n"

# project version from filepath
@test stringversion(ArgParseSettings(
    add_version = true, 
    version = @project_version "Project.toml"
)) == "1.0.0\n"

# project version from expression that returns a filepath
@test stringversion(ArgParseSettings(
    add_version = true, 
    version = @project_version(joinpath(@__DIR__, "Project.toml"))
)) == "1.0.0\n"

# throws an error if the file doesn't contain a version
@test_throws ArgumentError ArgParse.project_version("args-file1")

end
