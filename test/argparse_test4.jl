# test 4: manual help/version, import another parser

function ap_settings4()

    s0 = ArgParseSettings()  # a "parent" structure e.g. one with some useful set of rules
                             # which we want to extend

    # So we just add a simple table
    @add_arg_table s0 begin
        "--parent-flag", "-o"
            action = "store_true"
            help = "parent flag"
        "--flag"
            action = "store_true"
            help = "another parent flag"
        "parent-argument"
            help = "parent argument"
    end

    s = ArgParseSettings("Test 4 for ArgParse.jl",
                         add_help = false,           # disable auto-add of --help option
                         version = "Version 1.0",    # we set the version info, but --version won't be added
                         error_on_conflict = false,  # do not error-out when trying to override an option
                         exc_handler = ArgParse.debug_handler)

    import_settings(s, s0)       # now s has all of s0 arguments (except help/version)

    @add_arg_table s begin
        "-o"                       # this will partially override s0's --parent-flag
            action = :store_true
            help = "child flag"
        "--flag"                   # this will fully override s0's --flag
            action = :store_true
            help = "another child flag"
        "-?", "--HELP", "--¡ḧëļṕ"                # (almost) all characters allowed
            action = :show_help                  # will invoke the help generator
            help = "this will help you"
        "-v", "--VERSION"
            action = :show_version               # will show version information
            help = "show version information " *
                   "and exit"
    end

    return s
end

function ap_settings4b()

    # same as ap_settings4(), but imports all settings

    s0 = ArgParseSettings(add_help = false,
                          error_on_conflict = false,
                          exc_handler = ArgParse.debug_handler)

    # So we just add a simple table
    @add_arg_table s0 begin
        "--parent-flag", "-o"
            action = "store_true"
            help = "parent flag"
        "--flag"
            action = "store_true"
            help = "another parent flag"
        "parent-argument"
            help = "parent argument"
    end

    s = ArgParseSettings("Test 4 for ArgParse.jl",
                         version = "Version 1.0")

    import_settings(s, s0, false)  # args_only set to false

    @add_arg_table s begin
        "-o"
            action = :store_true
            help = "child flag"
        "--flag"
            action = :store_true
            help = "another child flag"
        "-?", "--HELP", "--¡ḧëļṕ"
            action = :show_help
            help = "this will help you"
        "-v", "--VERSION"
            action = :show_version
            help = "show version information " *
                   "and exit"
    end

    return s
end


for s = [ap_settings4(), ap_settings4b()]
    ap_test4(args) = parse_args(args, s)

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--parent-flag] [-o] [--flag] [-?] [-v]
                                [parent-argument]

        Test 4 for ArgParse.jl

        positional arguments:
          parent-argument      parent argument

        optional arguments:
          --parent-flag        parent flag
          -o                   child flag
          --flag               another child flag
          -?, --HELP, --¡ḧëļṕ  this will help you
          -v, --VERSION        show version information and exit

        """

    @test stringversion(s) == "Version 1.0\n"

    @compat @test ap_test4([]) == Dict{AbstractString,Any}("parent-flag"=>false, "o"=>false, "flag"=>false, "parent-argument"=>nothing)
    @compat @test ap_test4(["-o", "X"]) == Dict{AbstractString,Any}("parent-flag"=>false, "o"=>true, "flag"=>false, "parent-argument"=>"X")
    @ap_test_throws ap_test4(["-h"])

    # same metavar as another argument
    s.error_on_conflict = true
    @ee_test_throws @add_arg_table(s, "other-arg", metavar="parent-argument")
end


function ap_settings4_base()

    s = ArgParseSettings("Test 4 for ArgParse.jl",
                         add_help = false,
                         version = "Version 1.0",
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table s begin
        "-o"
            action = :store_true
            help = "child flag"
        "--flag"
            action = :store_true
            help = "another child flag"
    end

    return s
end

function ap_settings4_conflict1()

    s0 = ArgParseSettings()

    @add_arg_table s0 begin
        "--parent-flag", "-o"
            action = "store_true"
            help = "parent flag"
    end

    return s0
end

function ap_settings4_conflict2()

    s0 = ArgParseSettings()

    @add_arg_table s0 begin
        "--flag"
            action = "store_true"
            help = "another parent flag"
    end

    return s0
end

let s = ap_settings4_base()

    for s0 = [ap_settings4_conflict1(), ap_settings4_conflict2()]
        @ee_test_throws import_settings(s, s0)
    end
end
