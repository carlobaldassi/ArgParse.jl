 # test 5: commands & subtables

function ap_settings5()

    s = ArgParseSettings("Test 5 for ArgParse.jl",
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table s begin
        "run"
            action = :command
            help = "start running mode"
        "jump"
            action = :command
            help = "start jumping mode"
    end

    @add_arg_table s["run"] begin
        "--speed"
            arg_type = Float64
            default = 10.
            help = "running speed, in Å/month"
    end

    s["jump"].description = "Jump mode"
    s["jump"].commands_are_required = false
    s["jump"].autofix_names = true

    @add_arg_table s["jump"] begin
        "--higher"
            action = :store_true
            help = "enhance jumping"
        "--somersault", "-s"
            action = :command
            dest_name = "som"
            help = "somersault jumping mode"
        "--clap-feet", "-c"
            action = :command
            help = "clap feet jumping mode"
    end

    s["jump"]["som"].description = "Somersault jump mode"

    @add_arg_table s["jump"]["som"] begin
        "-t"
            nargs = '?'
            arg_type = Int
            default = 1
            constant = 1
            help = "twist a number of times"
        "-b"
            action = :store_true
            help = "blink"
    end

    return s
end

let s = ap_settings5()
    ap_test5(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) {run|jump}

        Test 5 for ArgParse.jl

        commands:
          run   start running mode
          jump  start jumping mode

        """

    @test stringhelp(s["run"]) == """
        usage: $(basename(Base.source_path())) run [--speed SPEED]

        optional arguments:
          --speed SPEED  running speed, in Å/month (type: Float64, default:
                         10.0)

        """

    @test stringhelp(s["jump"]) == """
        usage: $(basename(Base.source_path())) jump [--higher] [-s|-c]

        Jump mode

        commands:
          -s, --somersault  somersault jumping mode
          -c, --clap-feet   clap feet jumping mode

        optional arguments:
          --higher          enhance jumping

        """

    @test stringhelp(s["jump"]["som"]) == """
        usage: $(basename(Base.source_path())) jump -s [-t [T]] [-b]

        Somersault jump mode

        optional arguments:
          -t [T]  twist a number of times (type: $Int, default: 1, without
                  arg: 1)
          -b      blink

        """

    @ap_test_throws ap_test5([])
    @test ap_test5(["run", "--speed", "3"]) == Dict{AbstractString,Any}("%COMMAND%"=>"run", "run"=>Dict{AbstractString,Any}("speed"=>3.0))
    @test ap_test5(["jump"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "jump"=>Dict{AbstractString,Any}("higher"=>false, "%COMMAND%"=>nothing))
    @test ap_test5(["jump", "--higher", "--clap"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "jump"=>Dict{AbstractString,Any}("higher"=>true, "%COMMAND%"=>"clap_feet", "clap_feet"=>Dict{AbstractString,Any}()))
    @ap_test_throws ap_test5(["jump", "--clap", "--higher"])
    @test ap_test5(["jump", "--somersault"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "jump"=>Dict{AbstractString,Any}("higher"=>false, "%COMMAND%"=>"som", "som"=>Dict{AbstractString,Any}("t"=>1, "b"=>false)))
    @test ap_test5(["jump", "-s", "-t"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "jump"=>Dict{AbstractString,Any}("higher"=>false, "%COMMAND%"=>"som", "som"=>Dict{AbstractString,Any}("t"=>1, "b"=>false)))
    @test ap_test5(["jump", "-st"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "jump"=>Dict{AbstractString,Any}("higher"=>false, "%COMMAND%"=>"som", "som"=>Dict{AbstractString,Any}("t"=>1, "b"=>false)))
    @test ap_test5(["jump", "-sbt"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "jump"=>Dict{AbstractString,Any}("higher"=>false, "%COMMAND%"=>"som", "som"=>Dict{AbstractString,Any}("t"=>1, "b"=>true)))
    @test ap_test5(["jump", "-s", "-t2"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "jump"=>Dict{AbstractString,Any}("higher"=>false, "%COMMAND%"=>"som", "som"=>Dict{AbstractString,Any}("t"=>2, "b"=>false)))
    @test ap_test5(["jump", "-sbt2"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "jump"=>Dict{AbstractString,Any}("higher"=>false, "%COMMAND%"=>"som", "som"=>Dict{AbstractString,Any}("t"=>2, "b"=>true)))
    @ap_test_throws ap_test5(["jump", "-st2b"])
    @ap_test_throws ap_test5(["jump", "-stb"])
    @ap_test_throws ap_test5(["jump", "-sb-"])
    @ap_test_throws ap_test5(["jump", "-s-b"])

    @test parse_args(["jump", "-sbt2"], s, as_symbols = true) ==
        Dict{Symbol,Any}(:_COMMAND_=>:jump, :jump=>Dict{Symbol,Any}(:higher=>false, :_COMMAND_=>:som, :som=>Dict{Symbol,Any}(:t=>2, :b=>true)))

    # argument after command
    @ee_test_throws @add_arg_table(s, "arg_after_command")
    # same name as command
    @ee_test_throws @add_arg_table(s, "run")
    @ee_test_throws @add_arg_table(s["jump"], "-c")
    @ee_test_throws @add_arg_table(s["jump"], "--somersault")
    # same dest_name as command
    @ee_test_throws @add_arg_table(s["jump"], "--som")
    @ee_test_throws @add_arg_table(s["jump"], "-s", dest_name = "som")

    @add_arg_table(s, "--COMMAND", dest_name="_COMMAND_")
    @ee_test_throws parse_args(["run", "--speed", "3"], s, as_symbols = true)
end

function ap_settings5b()

    s0 = ArgParseSettings()

    s = ArgParseSettings(error_on_conflict = false,
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table s0 begin
        "run"
            action = :command
            help = "start running mode"
        "jump"
            action = :command
            help = "start jumping mode"
        "--time"
            arg_type = AbstractString
            default = "now"
            metavar = "T"
            help = "time at which to " *
                   "perform the command"
    end

    @add_arg_table s0["run"] begin
        "--speed"
            arg_type = Float64
            default = 10.
            help = "running speed, in Å/month"
    end

    s0["jump"].description = "Jump mode"
    s0["jump"].commands_are_required = false
    s0["jump"].autofix_names = true
    s0["jump"].add_help = false

    add_arg_group(s0["jump"], "modifiers", "modifiers")
    set_default_arg_group(s0["jump"])

    @add_arg_table s0["jump"] begin
        "--higher"
            action = :store_true
            help = "enhance jumping"
            group = "modifiers"
        "--somersault"
            action = :command
            dest_name = "som"
            help = "somersault jumping mode"
        "--clap-feet", "-c"
            action = :command
            help = "clap feet jumping mode"
    end

    add_arg_group(s0["jump"], "other")
    @add_arg_table s0["jump"] begin
        "--help"
            action = :show_help
            help = "show this help message " *
                   "and exit"
    end

    s0["jump"]["som"].description = "Somersault jump mode"

    @add_arg_table s begin
        "jump"
            action = :command
            help = "start jumping mode"
        "fly"
            action = :command
            help = "start flying mode"
        "-T" # will be overridden (same dest_name as s0's --time,
             # incompatible arg_type)
            dest_name = "time"
            arg_type = Int
    end

    s["jump"].autofix_names = true
    s["jump"].add_help = false

    add_arg_group(s["jump"], "modifiers", "modifiers")
    @add_arg_table s["jump"] begin
        "--lower"
            action = :store_false
            dest_name = "higher"
            help = "reduce jumping"
    end

    set_default_arg_group(s["jump"])

    @add_arg_table s["jump"] begin
        "--clap-feet"
            action = :command
            help = "clap feet jumping mode"
        "--som", "-s" # will be overridden (same dest_name as s0 command)
            action = :store_true
            help = "overridden"
        "--somersault" # will be overridden (same option as s0 command)
            action = :store_true
            help = "overridden"
    end

    @add_arg_table s["fly"] begin
        "--glade"
            action = :store_true
            help = "glade mode"
    end

    @add_arg_table s["jump"]["clap_feet"] begin
        "--whistle"
            action = :store_true
    end

    import_settings(s, s0)

    return s
end

let s = ap_settings5b()
    ap_test5b(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--time T] {fly|run|jump}

        commands:
          fly       start flying mode
          run       start running mode
          jump      start jumping mode

        optional arguments:
          --time T  time at which to perform the command (default: "now")

        """

    stringhelp(s["jump"]) == """
        usage: argparse_test5.jl jump [--lower] [--higher] [--help]
                                {-c|--somersault}

        commands:
          -c, --clap-feet  clap feet jumping mode
          --somersault     somersault jumping mode

        modifiers:
          --lower          reduce jumping
          --higher         enhance jumping

        other:
          --help           show this help message and exit

        """

    @ap_test_throws ap_test5b([])
    @test ap_test5b(["fly"]) == Dict{AbstractString,Any}("%COMMAND%"=>"fly", "time"=>"now", "fly"=>Dict{AbstractString,Any}("glade"=>false))
    @test ap_test5b(["jump", "--lower", "--clap"]) == Dict{AbstractString,Any}("%COMMAND%"=>"jump", "time"=>"now",
        "jump"=>Dict{AbstractString,Any}("%COMMAND%"=>"clap_feet", "higher"=>false, "clap_feet"=>Dict{AbstractString,Any}("whistle"=>false)))
    @ap_test_throws ap_test5b(["jump"])
    @test ap_test5b(["run", "--speed=3"]) == Dict{AbstractString,Any}("%COMMAND%"=>"run", "time"=>"now", "run"=>Dict{AbstractString,Any}("speed"=>3.0))
end
