# test 6: argument groups

function ap_settings6()

    s = ArgParseSettings("Test 6 for ArgParse.jl",
                         exc_handler = ArgParse.debug_handler)

    add_arg_group(s, "stack options")
    @add_arg_table s begin
        "--opt1"
            action = :append_const
            arg_type = String
            constant = "O1"
            dest_name = "O_stack"
            help = "append O1 to the stack"
        "--opt2"
            action = :append_const
            arg_type = String
            constant = "O2"
            dest_name = "O_stack"
            help = "append O2 to the stack"
    end

    add_arg_group(s, "weird options", "weird")

    set_default_arg_group(s, "weird")

    @add_arg_table s begin
        "--awkward-option"
            nargs = '+'
            action = :append_arg
            dest_name = "awk"
            arg_type = String
            range_tester = (x->x=="X"||x=="Y")
            metavar = "XY"
            help = "either X or Y; all XY's are " *
                   "stored in chunks"
    end

    set_default_arg_group(s)

    @add_arg_table s begin
        "-k"
            action = :store_const
            default = 0
            constant = 42
            help = "provide the answer"
        "--şİłłÿ"
            nargs = 3
            help = "an option with a silly name, " *
                   "which expects 3 arguments"
            metavar = "☺"
            group = "weird"
    end

    set_default_arg_group(s, "weird")

    @add_arg_table s begin
        "--rest"
            nargs = 'R'
            help = "an option which will consume " *
                   "all following arguments"
    end

    return s
end

let s = ap_settings6()
    ap_test6(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--opt1] [--opt2]
                                [--awkward-option XY [XY...]] [-k]
                                [--şİłłÿ ☺ ☺ ☺] [--rest [REST...]]

        Test 6 for ArgParse.jl

        optional arguments:
          -k                    provide the answer

        stack options:
          --opt1                append O1 to the stack
          --opt2                append O2 to the stack

        weird options:
          --awkward-option XY [XY...]
                                either X or Y; all XY's are stored in chunks
          --şİłłÿ ☺ ☺ ☺         an option with a silly name, which expects 3
                                arguments
          --rest [REST...]      an option which will consume all following
                                arguments

        """

    @test ap_test6([]) == Dict{String,Any}("O_stack"=>String[], "k"=>0, "awk"=>Vector{Any}[], "şİłłÿ"=>Any[], "rest"=>[])
    @test ap_test6(["--opt1", "--awk", "X", "X", "--opt2", "--opt2", "-k", "--awkward-option=Y", "X", "--opt1", "--şİł=-1", "-2", "-3"]) ==
        Dict{String,Any}("O_stack"=>String["O1", "O2", "O2", "O1"], "k"=>42, "awk"=>Any[Any["X", "X"], Any["Y", "X"]], "şİłłÿ"=>["-1", "-2", "-3"], "rest"=>[])
    @test ap_test6(["--opt1", "--awk", "X", "X", "--opt2", "--opt2", "--r", "-k", "--awkward-option=Y", "X", "--opt1", "--şİł", "-1", "-2", "-3"]) ==
        Dict{String,Any}("O_stack"=>String["O1", "O2", "O2"], "k"=>0, "awk"=>Any[Any["X", "X"]], "şİłłÿ"=>[], "rest"=>Any["-k", "--awkward-option=Y", "X", "--opt1", "--şİł", "-1", "-2", "-3"])
    @test ap_test6(["--opt1", "--awk", "X", "X", "--opt2", "--opt2", "--r=-k", "--awkward-option=Y", "X", "--opt1", "--şİł", "-1", "-2", "-3"]) ==
        Dict{String,Any}("O_stack"=>String["O1", "O2", "O2"], "k"=>0, "awk"=>Any[Any["X", "X"]], "şİłłÿ"=>[], "rest"=>Any["-k", "--awkward-option=Y", "X", "--opt1", "--şİł", "-1", "-2", "-3"])
    @ap_test_throws ap_test6(["X"])
    @ap_test_throws ap_test6(["--awk"])
    @ap_test_throws ap_test6(["--awk", "Z"])
    @ap_test_throws ap_test6(["--şİł", "-1", "-2"])
    @ap_test_throws ap_test6(["--şİł", "-1", "-2", "-3", "-4"])

    # invalid groups
    @ee_test_throws add_arg_group(s, "invalid commands", "")
    @ee_test_throws add_arg_group(s, "invalid commands", "#invalid")
    @ee_test_throws @add_arg_table(s, "--opt", action = :store_true, group = "none")
end
