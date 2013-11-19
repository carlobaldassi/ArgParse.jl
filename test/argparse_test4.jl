# test 4: manual help/version, import another parser

using ArgParse
using Base.Test

function ap_test4(args)

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
                         error_on_conflict = false)  # do not error-out when trying to override an option

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
            help = "show version information" *
                   "and exit"
    end

    s.exc_handler = (settings, err)->error(err.text)

    parsed_args = parse_args(args, s)
end

function ap_test4_fails(args)

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
                         add_help = false,
                         version = "Version 1.0")

    import_settings(s, s0)       # now s has all of s0 arguments (except help/version)

    @add_arg_table s begin
        "-o"                       # this will partially override s0's --parent-flag
            action = :store_true
            help = "child flag"
        "--flag"                   # this will fully override s0's --flag
            action = :store_true
            help = "another child flag"
    end

    s.exc_handler = (settings, err)->error(err.text)

    parsed_args = parse_args(args, s)
end

@test ap_test4([]) == (String=>Any)["parent-flag"=>false, "o"=>false, "flag"=>false, "parent-argument"=>nothing]
@test ap_test4(["-o", "X"]) == (String=>Any)["parent-flag"=>false, "o"=>true, "flag"=>false, "parent-argument"=>"X"]
@test_throws ap_test4(["-h"])
@test_throws ap_test4_fails([])
