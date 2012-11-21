# example 6: commands & subtables

using ArgParse

function main(args)

    s = ArgParseSettings("argparse_example_6.jl",
                         "Example 6 for argparse.jl: " *
                         "commands and their associated subtables.")

    @add_arg_table s begin
        "run"
            action = :command        # adds a command which will be read from an argument
            help = "start running mode"
        "jump"
            action = :command
            help = "start jumping mode"
    end

    @add_arg_table s["run"] begin    # add command arg_table: same as usual, but invoked on s["cmd"]
        "--speed"
            arg_type = Float64
            default = 10.
            help = "running speed, in Å/month"
    end

    @add_arg_table s["jump"] begin
        "--higher"
            action = :store_true
            help = "enhance jumping"
        "--somersault"
            action = :command        # this adds a sub-command (read from an option instead)
            dest_name = "som"        # flag commands can set a dest_name
            help = "somersault jumping mode"
        "--clap-feet"
            action = :command
            help = "clap feet jumping mode"
    end

    s["jump"].description = "Jump mode for example 6"  # this is how settings are tweaked
                                                       # for commands
    s["jump"].commands_are_required = false            # this makes the sub-commands optional

    s["jump"]["som"].description = "Somersault jump " *  # this is how settings are tweaked
                                   "mode for example 6"  # for sub-commands

    parsed_args = parse_args(args, s)
    println("Parsed args:")
    for pa in parsed_args
        println("  $(pa[1])  =>  $(pa[2])")
    end
    println()

    # parsed_args will have a special field "%COMMAND%"
    # which will hold the executed command name (or 'nothing')
    println("Command: ", parsed_args["%COMMAND%"])

    # thus, the command args are in parsed_args[parsed_args["%COMMAND%]]
    println("Parsed command args:")
    command_args = parsed_args[parsed_args["%COMMAND%"]]
    for pa in command_args
        println("  $(pa[1])  =>  $(pa[2])")
    end
end

main(ARGS)
