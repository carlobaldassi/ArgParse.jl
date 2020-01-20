@testset "test 11" begin

    ARGS = split("say hello --to world")

    s = ArgParseSettings()

    @add_arg_table s begin
        "say"
            action = :command
    end

    @add_arg_table s["say"] begin
        "what"
            help = "a positional argument"
            required = true
        "--to"
            help = "an option with an argument"
    end

    args = parse_args(ARGS, s, as_symbols=true)

    # make sure keys in args[:say] dict are of type Symbol
    # when as_symbols=true
    for (arg, val) in args[:say]
        @test typeof(arg) == Symbol
    end

end
