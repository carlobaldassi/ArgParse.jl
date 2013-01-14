# example 5: manual help/version, import another parser

using ArgParse

function main(args)

    s0 = ArgParseSettings()  # a "parent" structure e.g. one with some useful set of rules
                             # which we want to extend

    # So we just add a simple table
    @add_arg_table s0 begin
        "--parent-flag", "-o"
            action=>"store_true"
            help=>"parent flag"
        "--flag"
            action=>"store_true"
            help=>"another parent flag"
        "parent-argument"
            help = "parent argument"
    end

    s = ArgParseSettings("Example 5 for argparse.jl: " *
                         "importing another parser, " *
                         "manual help and version.")

    s.add_help = false           # disable auto-add of --help option
    s.version = "Version 1.0"    # we set the version info, but --version won't be added

    import_settings(s, s0)       # now s has all of s0 arguments (except help/version)

    s.error_on_conflict = false  # do not error-out when trying to override an option

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

    parsed_args = parse_args(args, s)
    println("Parsed args:")
    for pa in parsed_args
        println("  $(pa[1])  =>  $(pa[2])")
    end
end

main(ARGS)
