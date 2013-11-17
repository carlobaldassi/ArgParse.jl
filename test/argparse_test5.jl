# test 5: commands & subtables

using ArgParse
using Base.Test

function ap_test5(args)

    s = ArgParseSettings("Test 5 for ArgParse.jl",
                         exc_handler = (settings, err)->error(err.text))

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

    @add_arg_table s["jump"] begin
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

    s["jump"].description = "Jump mode"
    s["jump"].commands_are_required = false
    s["jump"]["som"].description = "Somersault jump mode"

    parsed_args = parse_args(args, s)
end

function ap_test5b(args)

    s0 = ArgParseSettings()

    s = ArgParseSettings(exc_handler = (settings, err)->error(err.text),
                         error_on_conflict = false)

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

    s0["jump"].description = "Jump mode"
    s0["jump"].commands_are_required = false
    s0["jump"]["som"].description = "Somersault jump mode"

    @add_arg_table s begin
        "jump"
            action = :command
            help = "start jumping mode"
        "fly"
            action = :command
            help = "start flying mode"
    end

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

    @add_arg_table s["jump"]["clap-feet"] begin
        "--whistle"
            action = :store_true
    end

    import_settings(s, s0)

    parsed_args = parse_args(args, s)
end

@test_throws ap_test5([])
@test ap_test5(["run", "--speed", "3"]) == (String=>Any)["%COMMAND%"=>"run", "run"=>(String=>Any)["speed"=>3.0]]
@test ap_test5(["jump"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>false, "%COMMAND%"=>nothing]]
@test ap_test5(["jump", "--higher", "--clap"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["higher"=>true, "%COMMAND%"=>"clap-feet", "clap-feet"=>(String=>Any)[]]]
@test_throws ap_test5(["jump", "--clap", "--higher"])

@test_throws ap_test5b([])
@test ap_test5b(["fly"]) == (String=>Any)["%COMMAND%"=>"fly", "fly"=>(String=>Any)["glade"=>false]]
@test ap_test5b(["jump", "--lower", "--clap"]) == (String=>Any)["%COMMAND%"=>"jump", "jump"=>(String=>Any)["%COMMAND%"=>"clap-feet", "higher"=>false, "clap-feet"=>(String=>Any)["whistle"=>false]]]
@test ap_test5b(["run", "--speed=3"]) == (String=>Any)["%COMMAND%"=>"run", "run"=>(String=>Any)["speed"=>3.0]]

