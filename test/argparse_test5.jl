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
          -t [T]  twist a number of times (type: Int64, default: 1, without
                  arg: 1)
          -b      blink

        """

    @ap_test_throws ap_test5([])
    @test ap_test5(["run", "--speed", "3"]) == (String=>Any)["%COMMAND%"=>"run", "run"=>(String=>Any)["speed"=>3.0]]
    @test ap_test5(["jump"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>false, "%COMMAND%"=>nothing]]
    @test ap_test5(["jump", "--higher", "--clap"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>true, "%COMMAND%"=>"clap_feet", "clap_feet"=>(String=>Any)[]]]
    @ap_test_throws ap_test5(["jump", "--clap", "--higher"])
    @test ap_test5(["jump", "--somersault"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>false, "%COMMAND%"=>"som", "som"=>(String=>Any)["t"=>1, "b"=>false]]]
    @test ap_test5(["jump", "-s", "-t"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>false, "%COMMAND%"=>"som", "som"=>(String=>Any)["t"=>1, "b"=>false]]]
    @test ap_test5(["jump", "-st"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>false, "%COMMAND%"=>"som", "som"=>(String=>Any)["t"=>1, "b"=>false]]]
    @test ap_test5(["jump", "-sbt"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>false, "%COMMAND%"=>"som", "som"=>(String=>Any)["t"=>1, "b"=>true]]]
    @test ap_test5(["jump", "-s", "-t2"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>false, "%COMMAND%"=>"som", "som"=>(String=>Any)["t"=>2, "b"=>false]]]
    @test ap_test5(["jump", "-sbt2"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>false, "%COMMAND%"=>"som", "som"=>(String=>Any)["t"=>2, "b"=>true]]]
    @ap_test_throws ap_test5(["jump", "-st2b"])
    @ap_test_throws ap_test5(["jump", "-stb"])
    @ap_test_throws ap_test5(["jump", "-sb-"])
    @ap_test_throws ap_test5(["jump", "-s-b"])

    @test_throws_02 ErrorException @add_arg_table(s, "arg_after_command")
    @test_throws_02 ErrorException @add_arg_table(s, "run") # arg with same name as command
    @test_throws_02 ErrorException @add_arg_table(s["jump"], "-c") # short option with same name as command
    @test_throws_02 ErrorException @add_arg_table(s["jump"], "--somersault") # long option with same name as command
    @test_throws_02 ErrorException @add_arg_table(s["jump"], "--som") # long option with same dest_name as command
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

    @add_arg_table s0["jump"] begin
        "--higher"
            action = :store_true
            help = "enhance jumping"
        "--somersault"
            action = :command
            dest_name = "som"
            help = "somersault jumping mode"
        "--clap-feet"
            action = :command
            help = "clap feet jumping mode"
    end

    s0["jump"]["som"].description = "Somersault jump mode"

    @add_arg_table s begin
        "jump"
            action = :command
            help = "start jumping mode"
        "fly"
            action = :command
            help = "start flying mode"
    end

    s["jump"].autofix_names = true

    @add_arg_table s["jump"] begin
        "--lower"
            action = :store_false
            dest_name = "higher"
            help = "reduce jumping"
        "--clap-feet"
            action = :command
            help = "clap feet jumping mode"
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
        usage: $(basename(Base.source_path())) {fly|run|jump}

        commands:
          fly   start flying mode
          run   start running mode
          jump  start jumping mode

        """

    @ap_test_throws ap_test5b([])
    @test ap_test5b(["fly"]) == (String=>Any)["%COMMAND%"=>"fly", "fly"=>(String=>Any)["glade"=>false]]
    @test ap_test5b(["jump", "--lower", "--clap"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["%COMMAND%"=>"clap_feet", "higher"=>false, "clap_feet"=>(String=>Any)["whistle"=>false]]]
    @test ap_test5b(["run", "--speed=3"]) == (String=>Any)["%COMMAND%"=>"run", "run"=>(String=>Any)["speed"=>3.0]]
end
