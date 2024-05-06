# test 13: help_width and help_alignment_width settings

@testset "test 13" begin

function ap_settings13()

    s = ArgParseSettings(description = "Test 13 for ArgParse.jl. This description is made unnecessarily long for the sake of testing the help_text_width setting.",
                         epilog = "This epilog is also made unnecessarily long for the same reason as the description, i.e., testing the help_text_width setting.",
                         exc_handler = ArgParse.debug_handler)

    @add_arg_table! s begin
        "--option1"
            arg_type = Int
            default = 0
            help = "an option, not used for much really, " *
                   "indeed it is not actually used for anything. " *
                   "That is why its name is so undescriptive."
        "-O", "--long-option"
            arg_type = Symbol
            default = :xyz
            help = "another option, this time it has a fancy name " *
                   "and yet it is still completely useless."
        "arg1"
            help = "first argument"
            required = true
        "arg2"
            default = "no arg2 given"
            help = "second argument"
    end

    return s
end

let s = ap_settings13()
    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--option1 OPTION1] [-O LONG-OPTION] arg1
                                [arg2]

        Test 13 for ArgParse.jl. This description is made unnecessarily long
        for the sake of testing the help_text_width setting.

        positional arguments:
          arg1                  first argument
          arg2                  second argument (default: "no arg2 given")

        optional arguments:
          --option1 OPTION1     an option, not used for much really, indeed it
                                is not actually used for anything. That is why
                                its name is so undescriptive. (type: $Int,
                                default: 0)
          -O, --long-option LONG-OPTION
                                another option, this time it has a fancy name
                                and yet it is still completely useless. (type:
                                Symbol, default: :xyz)

        This epilog is also made unnecessarily long for the same reason as the
        description, i.e., testing the help_text_width setting.

        """

    s.help_width = 120

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--option1 OPTION1] [-O LONG-OPTION] arg1 [arg2]

        Test 13 for ArgParse.jl. This description is made unnecessarily long for the sake of testing the help_text_width
        setting.

        positional arguments:
          arg1                  first argument
          arg2                  second argument (default: "no arg2 given")

        optional arguments:
          --option1 OPTION1     an option, not used for much really, indeed it is not actually used for anything. That is why
                                its name is so undescriptive. (type: $Int, default: 0)
          -O, --long-option LONG-OPTION
                                another option, this time it has a fancy name and yet it is still completely useless. (type:
                                Symbol, default: :xyz)

        This epilog is also made unnecessarily long for the same reason as the description, i.e., testing the help_text_width
        setting.

        """

    s.help_width = 50

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--option1 OPTION1]
                                [-O LONG-OPTION] arg1
                                [arg2]

        Test 13 for ArgParse.jl. This description is made
        unnecessarily long for the sake of testing the
        help_text_width setting.

        positional arguments:
          arg1                  first argument
          arg2                  second argument (default:
                                "no arg2 given")

        optional arguments:
          --option1 OPTION1     an option, not used for
                                much really, indeed it is
                                not actually used for
                                anything. That is why its
                                name is so undescriptive.
                                (type: $Int, default: 0)
          -O, --long-option LONG-OPTION
                                another option, this time
                                it has a fancy name and
                                yet it is still completely
                                useless. (type: Symbol,
                                default: :xyz)

        This epilog is also made unnecessarily long for
        the same reason as the description, i.e., testing
        the help_text_width setting.

        """

    s.help_width = 100
    s.help_alignment_width = 50

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--option1 OPTION1] [-O LONG-OPTION] arg1 [arg2]

        Test 13 for ArgParse.jl. This description is made unnecessarily long for the sake of testing the
        help_text_width setting.

        positional arguments:
          arg1                           first argument
          arg2                           second argument (default: "no arg2 given")

        optional arguments:
          --option1 OPTION1              an option, not used for much really, indeed it is not actually used
                                         for anything. That is why its name is so undescriptive. (type:
                                         $Int, default: 0)
          -O, --long-option LONG-OPTION  another option, this time it has a fancy name and yet it is still
                                         completely useless. (type: Symbol, default: :xyz)

        This epilog is also made unnecessarily long for the same reason as the description, i.e., testing
        the help_text_width setting.

        """

    s.help_width = 50
    s.help_alignment_width = 4

    @test stringhelp(s) == """
        usage: $(basename(Base.source_path())) [--option1 OPTION1]
            [-O LONG-OPTION] arg1 [arg2]

        Test 13 for ArgParse.jl. This description is made
        unnecessarily long for the sake of testing the
        help_text_width setting.

        positional arguments:
          arg1
            first argument
          arg2
            second argument (default: "no arg2 given")

        optional arguments:
          --option1 OPTION1
            an option, not used for much really, indeed it
            is not actually used for anything. That is why
            its name is so undescriptive. (type: $Int,
            default: 0)
          -O, --long-option LONG-OPTION
            another option, this time it has a fancy name
            and yet it is still completely useless. (type:
            Symbol, default: :xyz)

        This epilog is also made unnecessarily long for
        the same reason as the description, i.e., testing
        the help_text_width setting.

        """

end

end
