## All types, functions and constants related to the actual process of
## parsing the arguments

# ArgParseError
struct ArgParseError <: Exception
    text::AbstractString
end

argparse_error(x...) = throw(ArgParseError(string(x...)))

# parsing checks
function test_range(range_tester::Function, arg, name::AbstractString)
    local rng_chk::Bool
    try
        rng_chk = range_tester(arg)
    catch
        rng_chk = false
    end
    rng_chk || argparse_error("out of range input for $name: $arg")
    return
end

function test_exclusive_groups!(exc_groups::Dict{ArgParseGroup,AbstractString},
                                settings::ArgParseSettings,
                                f::ArgParseField,
                                name::AbstractString)
    arg_group = get_group(f.group, f, settings)
    if haskey(exc_groups, arg_group)
        prev_id = exc_groups[arg_group]
        if isempty(prev_id)
            exc_groups[arg_group] = idstring(f)
        elseif prev_id != idstring(f)
            argparse_error("option $name not allowed with $prev_id")
        end
    end
    return
end

function test_required_args(settings::ArgParseSettings, found_args::Set{AbstractString})
    req_groups = Dict{ArgParseGroup,Bool}(g=>false for g in settings.args_groups if g.required)
    fields = settings.args_table.fields
    for f in fields
        found = idstring(f) ∈ found_args
        !is_cmd(f) && f.required && !found &&
            argparse_error("required $(idstring(f)) was not provided")
        found && (req_groups[get_group(f.group, f, settings)] = true)
    end
    for (g,found) in req_groups
        found && continue
        ids = String[idstring(f) for f in fields if get_group(f.group, f, settings) ≡ g]
        argparse_error("one of these is required: " * join(ids, ", "))
    end
    return true
end

function check_settings_can_use_symbols(settings::ArgParseSettings)
    args_table = settings.args_table
    if !isempty(args_table.subsettings)
        for f in args_table.fields
            if f.dest_name == string(scmd_dest_name)
                serror("the dest_name $scmd_dest_name cannot be used with the as_symbols option")
            end
        end
        for subs in values(args_table.subsettings)
            check_settings_can_use_symbols(subs)
        end
    end
    settings.suppress_warnings && return true
    for f in args_table.fields
        if '-' in f.dest_name
            @warn "dest_name=$(f.dest_name) contains a hyphen; use the autofix_names=true setting to have it converted to an underscore"
        end
    end
    return true
end

# parsing aux functions
function parse_item_wrapper(::Type{T}, x::AbstractString) where {T}
    local r::T
    try
        r = parse_item(T, x)
    catch err
        argparse_error("""
            invalid argument: $x (conversion to type $T failed; you may need to overload
                              ArgParse.parse_item; the error was: $err)""")
    end
    return r
end

parse_item(::Type{Any}, x::AbstractString) = x
parse_item(::Type{T}, x::AbstractString) where {T<:Number} = parse(T, x)
parse_item(::Type{T}, x::AbstractString) where {T} = applicable(convert, T, x) ? convert(T, x) : T(x)

function parse_item_eval(::Type{T}, x::AbstractString) where {T}
    local r::T
    try
        r = convert(T, eval(Meta.parse(x)))
    catch err
        argparse_error("""
            invalid argument: $x (must evaluate or convert to type $T;
                              the error was: $err)""")
    end
    return r
end

const number_regex =
    r"^[+-]?                                          # optional sign
        (
          0x[0-9a-fA-F](_?[0-9a-fA-F])*             | # hex
          0o[0-7](_?[0-7])*                         | # oct
          0b[01](_?[01])*                           | # bin
          (                                           # float mantissa
            [0-9](_?[0-9])*(\.([0-9](_?[0-9])*)?)?  | #   start with digit
            \.[0-9](_?[0-9])*                         #   start with dot
          )([eEf][-+]?[0-9]+)?                        # float optional exp
        )
      $"x

function looks_like_an_option(arg::AbstractString, settings::ArgParseSettings)
    arg == "-" && return false
    startswith(arg, "--") && return true
    startswith(arg, '-') || return false
    # begins with '-'
    # check if it's a number:
    occursin(number_regex, arg) || return true
    # looks like a number; but is it overridden by an option?
    d = arg[2:2]
    for a in settings.args_table.fields, s in a.short_opt_name
        s == d && return true
    end
    # it's a number
    return false
end

function usage_string(settings::ArgParseSettings)
    isempty(settings.usage) || return settings.usage

    usage_pre = "usage: " * (isempty(settings.prog) ? "<PROGRAM>" : settings.prog)

    lc_len_limit = settings.help_alignment_width

    cmd_lst = String[]
    pos_lst = String[]
    opt_lst = String[]
    exc_lst = Dict{String,Tuple{Bool,Vector{String}}}()
    for f in settings.args_table.fields
        arg_group = get_group(f.group, f, settings)
        if arg_group.exclusive
            (is_cmd(f) || is_arg(f)) && found_a_bug()
            _, tgt_opt_lst = get!(exc_lst, arg_group.name, (arg_group.required, String[]))
        else
            tgt_opt_lst = opt_lst
        end
        if is_cmd(f)
            if !isempty(f.short_opt_name)
                idstr = "-" * f.short_opt_name[1]
            elseif !isempty(f.long_opt_name)
                idstr = "--" * f.long_opt_name[1]
            else
                idstr = f.metavar
            end
            push!(cmd_lst, idstr)
        elseif is_arg(f)
            bra_pre, bra_post = f.required ? ("","") : ("[","]")
            if isa(f.nargs.desc, Int)
                if f.metavar isa AbstractString
                    arg_str = join(repeat([f.metavar], f.nargs.desc), nbsps)
                else
                    found_a_bug()
                end
            elseif f.nargs.desc == :A
                arg_str = f.metavar
            elseif f.nargs.desc == :?
                found_a_bug()
            elseif f.nargs.desc == :* || f.nargs.desc == :R || f.nargs.desc == :+
                arg_str = f.metavar * "..."
            else
                found_a_bug()
            end
            push!(pos_lst, bra_pre * arg_str * bra_post)
        else
            bra_pre, bra_post = (f.required || arg_group.exclusive) ? ("","") : ("[","]")
            if !isempty(f.short_opt_name)
                opt_str1 = "-" * f.short_opt_name[1]
            else
                opt_str1 = "--" * f.long_opt_name[1]
            end
            if is_flag(f)
                opt_str2 = ""
            else
                if f.nargs.desc isa Int
                    if f.metavar isa AbstractString
                        opt_str2 = string(ntuple(i->(nbsps * f.metavar), f.nargs.desc)...)
                    elseif f.metavar isa Vector
                        opt_str2 = string(ntuple(i->(nbsps * f.metavar[i]), f.nargs.desc)...)
                    else
                        found_a_bug()
                    end
                elseif f.nargs.desc == :A
                    opt_str2 = nbsps * f.metavar
                elseif f.nargs.desc == :?
                    opt_str2 = nbsps * "[" * f.metavar * "]"
                elseif f.nargs.desc == :* || f.nargs.desc == :R
                    opt_str2 = nbsps * "[" * f.metavar * "...]"
                elseif f.nargs.desc == :+
                    opt_str2 = nbsps * f.metavar * nbsps * "[" * f.metavar * "...]"
                else
                    found_a_bug()
                end
            end
            new_opt = bra_pre * opt_str1 * opt_str2 * bra_post
            push!(tgt_opt_lst, new_opt)
        end
    end
    excl_str = ""
    for (req,lst) in values(exc_lst)
        pre, post = req ? ("{","}") : ("[","]")
        excl_str *= " " * pre * join(lst, " | ") * post
    end
    if isempty(opt_lst)
        optl_str = ""
    else
        optl_str = " " * join(opt_lst, " ")
    end
    if isempty(pos_lst)
        posl_str = ""
    else
        posl_str = " " * join(pos_lst, " ")
    end
    if isempty(cmd_lst)
        cmdl_str = ""
    else
        bra_pre, bra_post = settings.commands_are_required ? ("{","}") :  ("[","]")
        cmdl_str = " " * bra_pre * join(cmd_lst, "|") * bra_post
    end

    usage_len = length(usage_pre) + 1

    str_nonwrapped = usage_pre * excl_str * optl_str * posl_str * cmdl_str
    str_wrapped = TextWrap.wrap(str_nonwrapped, break_long_words = false, break_on_hyphens = false,
                                subsequent_indent = min(usage_len, lc_len_limit),
                                width = settings.help_width)


    out_str = replace(str_wrapped, nbspc => ' ')
    return out_str
end

function string_compact(x...)
    io = IOBuffer()
    show(IOContext(io, :compact=>true), x...)
    return String(take!(io))
end

function gen_help_text(arg::ArgParseField, settings::ArgParseSettings)
    is_flag(arg) && return arg.help

    pre = isempty(arg.help) ? "" : " "
    type_str = ""
    default_str = ""
    const_str = ""
    alias_str = ""
    if !is_command_action(arg.action)
        if arg.arg_type ≠ Any && !(arg.arg_type <: AbstractString)
            type_str = pre * "(type: " * string_compact(arg.arg_type)
        end
        if arg.default ≢ nothing && !isequal(arg.default, [])
            mid = isempty(type_str) ? " (" : ", "
            default_str = mid * "default: " * string_compact(arg.default)
        end
        if arg.nargs.desc == :?
            mid = isempty(type_str) && isempty(default_str) ? " (" : ", "
            const_str = mid * "without arg: " * string_compact(arg.constant)
        end
    else
        is_arg(arg) || found_a_bug()
        if !isempty(arg.cmd_aliases)
            alias_str = pre * "(aliases: " * join(arg.cmd_aliases, ", ")
        end
    end
    post = all(isempty, (type_str, default_str, const_str, alias_str)) ? "" : ")"
    return arg.help * type_str * default_str * const_str * alias_str * post
end

function print_group(io::IO, lst::Vector, desc::AbstractString, lc_usable_len::Int, lc_len::Int,
                     lmargin::AbstractString, rmargin::AbstractString, sindent::AbstractString,
                     width::Int)
    isempty(lst) && return
    println(io, desc, ":")
    for l in lst
        l1len = length(l[1])
        if l1len ≤ lc_usable_len
            rfill = " "^(lc_len - l1len)
            ll_nonwrapped = l[1] * rfill * rmargin * l[2]
            ll_wrapped = TextWrap.wrap(ll_nonwrapped, break_long_words = false, break_on_hyphens = false,
                                       initial_indent = lmargin, subsequent_indent = sindent, width = width)
            println_unnbsp(io, ll_wrapped)
        else
            println_unnbsp(io, lmargin, l[1])
            l2_wrapped = TextWrap.wrap(l[2], break_long_words = false, break_on_hyphens = false,
                                       initial_indent = sindent, subsequent_indent = sindent, width = width)
            println_unnbsp(io, l2_wrapped)
        end
    end
    println(io)
end

show_help(settings::ArgParseSettings; kw...) = show_help(stdout, settings; kw...)

function show_help(io::IO, settings::ArgParseSettings; exit_when_done = !isinteractive())

    lc_len_limit = settings.help_alignment_width
    lc_left_indent = 2
    lc_right_margin = 2

    lc_usable_len = lc_len_limit - lc_left_indent - lc_right_margin
    max_lc_len = 0

    usage_str = usage_string(settings)

    group_lists = Dict{AbstractString,Vector{Any}}()
    for ag in settings.args_groups
        group_lists[ag.name] = Any[]
    end
    for f in settings.args_table.fields
        dest_lst = group_lists[f.group]
        if is_arg(f)
            push!(dest_lst, Any[f.metavar, gen_help_text(f, settings)])
            max_lc_len = max(max_lc_len, length(f.metavar))
        else
            opt_str1 = join([["-"*x for x in f.short_opt_name];
                             ["--"*x for x in f.long_opt_name]],
                            ", ")
            if is_flag(f)
                opt_str2 = ""
            else
                if f.nargs.desc isa Int
                    if f.metavar isa AbstractString
                        opt_str2 = string(ntuple(i->(nbsps * f.metavar), f.nargs.desc)...)
                    elseif isa(f.metavar, Vector)
                        opt_str2 = string(ntuple(i->(nbsps * f.metavar[i]), f.nargs.desc)...)
                    else
                        found_a_bug()
                    end
                elseif f.nargs.desc == :A
                    opt_str2 = nbsps * f.metavar
                elseif f.nargs.desc == :?
                    opt_str2 = nbsps * "[" * f.metavar * "]"
                elseif f.nargs.desc == :* || f.nargs.desc == :R
                    opt_str2 = nbsps * "[" * f.metavar * "...]"
                elseif f.nargs.desc == :+
                    opt_str2 = nbsps * f.metavar * nbsps * "[" * f.metavar * "...]"
                else
                    found_a_bug()
                end
            end
            new_opt = Any[opt_str1 * opt_str2, gen_help_text(f, settings)]
            push!(dest_lst, new_opt)
            max_lc_len = max(max_lc_len, length(new_opt[1]))
        end
    end

    lc_len = min(lc_usable_len, max_lc_len)
    lmargin = " "^lc_left_indent
    rmargin = " "^lc_right_margin

    sindent = lmargin * " "^lc_len * rmargin

    println(io, usage_str)
    println(io)
    show_message(io, settings.description, settings.preformatted_description, settings.help_width)

    for ag in settings.args_groups
        print_group(io, group_lists[ag.name], ag.desc, lc_usable_len, lc_len,
                    lmargin, rmargin, sindent, settings.help_width)
    end

    show_message(io, settings.epilog, settings.preformatted_epilog, settings.help_width)
    exit_when_done && exit(0)
    return
end

function show_message(io::IO, message::AbstractString, preformatted::Bool, width::Int)
    if !isempty(message)
        if preformatted
            print(io, message)
        else
            for l in split(message, "\n\n")
                message_wrapped = TextWrap.wrap(l, break_long_words = false, break_on_hyphens = false, width = width)
                println_unnbsp(io, message_wrapped)
            end
        end
        println(io)
    end
end

show_version(settings::ArgParseSettings; kw...) = show_version(stdout, settings; kw...)

function show_version(io::IO, settings::ArgParseSettings; exit_when_done = !isinteractive())
    println(io, settings.version)
    exit_when_done && exit(0)
    return
end

has_cmd(settings::ArgParseSettings) = any(is_cmd, settings.args_table.fields)

# parse_args & friends
function default_handler(settings::ArgParseSettings, err, err_code::Int = 1)
    isinteractive() ? debug_handler(settings, err) : cmdline_handler(settings, err, err_code)
end

function cmdline_handler(settings::ArgParseSettings, err, err_code::Int = 1)
    println(stderr, err.text)
    println(stderr, usage_string(settings))
    exit(err_code)
end

function debug_handler(settings::ArgParseSettings, err)
    rethrow(err)
end

parse_args(settings::ArgParseSettings; kw...) = parse_args(ARGS, settings; kw...)

"""
    parse_args([args,] settings; as_symbols::Bool = false)

This is the central function of the `ArgParse` module. It takes a `Vector` of arguments and an
[`ArgParseSettings`](@ref) object, and returns a `Dict{String,Any}`. If `args` is not provided, the
global variable `ARGS` will be used.

When the keyword argument `as_symbols` is `true`, the function will return a `Dict{Symbol,Any}`
instead.

The returned `Dict` keys are defined (possibly implicitly) in `settings`, and their associated
values are parsed from `args`. Special keys are used for more advanced purposes; at the moment, one
such key exists: `%COMMAND%` (`_COMMAND_` when using `as_symbols=true`; see the [Commands](@ref)
section).

Arguments are parsed in sequence and matched against the argument table in `settings` to determine
whether they are long options, short options, option arguments or positional arguments:

  * long options begin with a double dash `"--"`; if a `'='` character is found, the remainder is
    the option argument; therefore, `["--opt=arg"]` and `["--opt", "arg"]` are equivalent if `--opt`
    takes at least one argument. Long options can be abbreviated (e.g. `--opt` instead of
    `--option`) as long as there is no ambiguity.
  * short options begin with a single dash `"-"` and their name consists of a single character; they
    can be grouped together (e.g. `["-x", "-y"]` can become `["-xy"]`), but in that case only the
    last option in the group can take an argument (which can also be grouped, e.g.
    `["-a", "-f", "file.txt"]` can be passed as `["-affile.txt"]` if `-a` does not take an argument
    and `-f` does). The `'='` character can be used to separate option names from option arguments
    as well (e.g. `-af=file.txt`).
  * positional arguments are anything else; they can appear anywhere.

The special string `"--"` can be used to signal the end of all options; after that, everything is
considered as a positional argument (e.g. if `args = ["--opt1", "--", "--opt2"]`, the parser will
recognize `--opt1` as a long option without argument, and `--opt2` as a positional argument).

The special string `"-"` is always parsed as a positional argument.

The parsing can stop early if a `:show_help` or `:show_version` action is triggered, or if a parsing
error is found.

Some ambiguities can arise in parsing, see the [Parsing details](@ref) section for a detailed
description of how they're solved.
"""
function parse_args(args_list::Vector, settings::ArgParseSettings; as_symbols::Bool = false)
    as_symbols && check_settings_can_use_symbols(settings)
    local parsed_args
    try
        parsed_args = parse_args_unhandled(args_list, settings)
    catch err
        err isa ArgParseError || rethrow()
        settings.exc_handler(settings, err)
    end
    as_symbols && (parsed_args = convert_to_symbols(parsed_args))
    return parsed_args
end

mutable struct ParserState
    args_list::Vector
    arg_delim_found::Bool
    token::Union{AbstractString,Nothing}
    token_arg::Union{AbstractString,Nothing}
    arg_consumed::Bool
    last_arg::Int
    found_args::Set{AbstractString}
    command::Union{AbstractString,Nothing}
    truncated_shopts::Bool
    abort::Bool
    exc_groups::Dict{ArgParseGroup,AbstractString}
    out_dict::Dict{String,Any}
    function ParserState(args_list::Vector, settings::ArgParseSettings, truncated_shopts::Bool)
        exc_groups = Dict{ArgParseGroup,AbstractString}(
                g=>"" for g in settings.args_groups if g.exclusive)
        out_dict = Dict{String,Any}()
        for f in settings.args_table.fields
            f.action ∈ (:show_help, :show_version) && continue
            out_dict[f.dest_name] = deepcopy(f.default)
        end
        return new(deepcopy(args_list), false, nothing, nothing, false, 0, Set{AbstractString}(),
                   nothing, truncated_shopts, false, exc_groups, out_dict)
    end
end

found_command(state::ParserState) = state.command ≢ nothing
function parse_command_args!(state::ParserState, settings::ArgParseSettings)
    cmd = state.command
    haskey(settings, cmd) || argparse_error("unknown command: $cmd")
    #state.out_dict[cmd] = parse_args(state.args_list, settings[cmd])
    try
        state.out_dict[cmd] =
            parse_args_unhandled(state.args_list, settings[cmd], state.truncated_shopts)
    catch err
        err isa ArgParseError || rethrow(err)
        settings[cmd].exc_handler(settings[cmd], err)
    finally
        state.truncated_shopts = false
    end
    return state.out_dict[cmd]
end

function preparse!(c::Channel, state::ParserState, settings::ArgParseSettings)
    args_list = state.args_list
    while !isempty(args_list)
        state.arg_delim_found && (put!(c, :pos_arg); continue)
        arg = args_list[1]
        if state.truncated_shopts
            @assert arg[1] == '-'
            looks_like_an_option(arg, settings) ||
                argparse_error("illegal short options sequence after command: $arg")
            state.truncated_shopts = false
        end
        if arg == "--"
            state.arg_delim_found = true
            state.token = nothing
            state.token_arg = nothing
            popfirst!(args_list)
            continue
        elseif startswith(arg, "--")
            eq = findfirst(isequal('='), arg)
            if eq ≢ nothing
                opt_name = arg[3:prevind(arg,eq)]
                arg_after_eq = arg[nextind(arg,eq):end]
            else
                opt_name = arg[3:end]
                arg_after_eq = nothing
            end
            isempty(opt_name) && argparse_error("illegal option: $arg")
            popfirst!(args_list)
            state.token = opt_name
            state.token_arg = arg_after_eq
            put!(c, :long_option)
        elseif looks_like_an_option(arg, settings)
            shopts_lst = arg[2:end]
            popfirst!(args_list)
            state.token = shopts_lst
            state.token_arg = nothing
            put!(c, :short_option_list)
        else
            state.token = nothing
            state.token_arg = nothing
            put!(c, :pos_arg)
        end
    end
end

# faithful reproduction of Python 3.5.1 argparse.py
# partially Copyright © 2001-2016 Python Software Foundation; All Rights Reserved
function read_args_from_files(arg_strings, prefixes)
    new_arg_strings = AbstractString[]

    for arg_string in arg_strings
        if isempty(arg_string) || arg_string[1] ∉ prefixes
            # for regular arguments, just add them back into the list
            push!(new_arg_strings, arg_string)
        else
            # replace arguments referencing files with the file content
            open(arg_string[nextind(arg_string, 1):end]) do args_file
                arg_strings = AbstractString[]
                for arg_line in readlines(args_file)
                    push!(arg_strings, rstrip(arg_line, '\n'))
                end
                arg_strings = read_args_from_files(arg_strings, prefixes)
                append!(new_arg_strings, arg_strings)
            end
        end
    end

    # return the modified argument list
    return new_arg_strings
end

function parse_args_unhandled(args_list::Vector,
                              settings::ArgParseSettings,
                              truncated_shopts::Bool=false)
    all(x->(x isa AbstractString), args_list) || error("malformed args_list")
    if !isempty(settings.fromfile_prefix_chars)
        args_list = read_args_from_files(args_list, settings.fromfile_prefix_chars)
    end

    version_added = false
    help_added = false

    if settings.add_version
        settings.add_version = false
        add_arg_field!(settings, "--version",
            action = :show_version,
            help = "show version information and exit",
            group = ""
            )
        version_added = true
    end
    if settings.add_help
        settings.add_help = false
        add_arg_field!(settings, ["--help", "-h"],
            action = :show_help,
            help = "show this help message and exit",
            group = ""
            )
        help_added = true
    end

    state = ParserState(args_list, settings, truncated_shopts)
    preparser = Channel(c->preparse!(c, state, settings))

    try
        for tag in preparser
            if tag == :long_option
                parse_long_opt!(state, settings)
            elseif tag == :short_option_list
                parse_short_opt!(state, settings)
            elseif tag == :pos_arg
                parse_arg!(state, settings)
            else
                found_a_bug()
            end
            state.abort && return nothing
            found_command(state) && break
        end
        test_required_args(settings, state.found_args)
        if found_command(state)
            cmd_dict = parse_command_args!(state, settings)
            cmd_dict ≡ nothing && return nothing
        elseif settings.commands_are_required && has_cmd(settings)
            argparse_error("no command given")
        end
    catch err
        rethrow()
    finally
        if help_added
            pop!(settings.args_table.fields)
            settings.add_help = true
        end
        if version_added
            pop!(settings.args_table.fields)
            settings.add_version = true
        end
    end

    return state.out_dict
end

# common parse functions
function parse1_flag!(state::ParserState, settings::ArgParseSettings, f::ArgParseField,
                      has_arg::Bool, opt_name::AbstractString)
    has_arg && argparse_error("option $opt_name takes no arguments")
    test_exclusive_groups!(state.exc_groups, settings, f, opt_name)
    command = nothing
    out_dict = state.out_dict
    if f.action == :store_true
        out_dict[f.dest_name] = true
    elseif f.action == :store_false
        out_dict[f.dest_name] = false
    elseif f.action == :store_const
        out_dict[f.dest_name] = f.constant
    elseif f.action == :append_const
        push!(out_dict[f.dest_name], f.constant)
    elseif f.action == :count_invocations
        out_dict[f.dest_name] += 1
    elseif f.action == :command_flag
        out_dict[f.dest_name] = f.constant
        command = f.constant
    elseif f.action == :show_help
        show_help(settings, exit_when_done = settings.exit_after_help)
        state.abort = true
    elseif f.action == :show_version
        show_version(settings, exit_when_done = settings.exit_after_help)
        state.abort = true
    end
    state.command = command
    return
end

function parse1_optarg!(state::ParserState, settings::ArgParseSettings, f::ArgParseField,
                        rest, name::AbstractString)
    args_list = state.args_list
    arg_delim_found = state.arg_delim_found
    out_dict = state.out_dict

    test_exclusive_groups!(state.exc_groups, settings, f, name)

    arg_consumed = false
    parse_function = f.eval_arg ? parse_item_eval : parse_item_wrapper
    command = nothing
    is_multi_nargs(f.nargs) && (opt_arg = Array{f.arg_type}(undef, 0))
    if f.nargs.desc isa Int
        num::Int = f.nargs.desc
        num > 0 || found_a_bug()
        corr = (rest ≡ nothing) ? 0 : 1
        if length(args_list) + corr < num
            argparse_error("$name requires $num argument", num > 1 ? "s" : "")
        end
        if rest ≢ nothing
            a = parse_function(f.arg_type, rest)
            test_range(f.range_tester, a, name)
            push!(opt_arg, a)
            arg_consumed = true
        end
        for i = (1+corr):num
            a = parse_function(f.arg_type, popfirst!(args_list))
            test_range(f.range_tester, a, name)
            push!(opt_arg, a)
        end
    elseif f.nargs.desc == :A
        if rest ≢ nothing
            a = parse_function(f.arg_type, rest)
            test_range(f.range_tester, a, name)
            opt_arg = a
            arg_consumed = true
        else
            isempty(args_list) && argparse_error("option $name requires an argument")
            a = parse_function(f.arg_type, popfirst!(args_list))
            test_range(f.range_tester, a, name)
            opt_arg = a
        end
    elseif f.nargs.desc == :?
        if rest ≢ nothing
            a = parse_function(f.arg_type, rest)
            test_range(f.range_tester, a, name)
            opt_arg = a
            arg_consumed = true
        else
            if isempty(args_list) || looks_like_an_option(args_list[1], settings)
                opt_arg = deepcopy(f.constant)
            else
                a = parse_function(f.arg_type, popfirst!(args_list))
                test_range(f.range_tester, a, name)
                opt_arg = a
            end
        end
    elseif f.nargs.desc == :* || f.nargs.desc == :+
        arg_found = false
        if rest ≢ nothing
            a = parse_function(f.arg_type, rest)
            test_range(f.range_tester, a, name)
            push!(opt_arg, a)
            arg_consumed = true
            arg_found = true
        end
        while !isempty(args_list)
            if !arg_delim_found && looks_like_an_option(args_list[1], settings)
                break
            end
            a = parse_function(f.arg_type, popfirst!(args_list))
            test_range(f.range_tester, a, name)
            push!(opt_arg, a)
            arg_found = true
        end
        if f.nargs.desc == :+ && !arg_found
            argparse_error("option $name requires at least one not-option-looking argument")
        end
    elseif f.nargs.desc == :R
        if rest ≢ nothing
            a = parse_function(f.arg_type, rest)
            test_range(f.range_tester, a, name)
            push!(opt_arg, a)
            arg_consumed = true
        end
        while !isempty(args_list)
            a = parse_function(f.arg_type, popfirst!(args_list))
            test_range(f.range_tester, a, name)
            push!(opt_arg, a)
        end
    else
        found_a_bug()
    end
    if f.action == :store_arg
        out_dict[f.dest_name] = opt_arg
    elseif f.action == :append_arg
        push!(out_dict[f.dest_name], opt_arg)
    elseif f.action == :command_arg
        if !haskey(settings, opt_arg)
            found = false
            for f1 in settings.args_table.fields
                (is_cmd(f1) && is_arg(f1)) || continue
                for al in f1.cmd_aliases
                    if opt_arg == al
                        found = true
                        opt_arg = f1.constant
                        break
                    end
                end
                found && break
            end
            !found && argparse_error("unknown command: $opt_arg")
            haskey(settings, opt_arg) || found_a_bug()
        end
        out_dict[f.dest_name] = opt_arg
        command = opt_arg
    else
        found_a_bug()
    end
    state.arg_consumed = arg_consumed
    state.command = command
    return
end

# parse long opts
function parse_long_opt!(state::ParserState, settings::ArgParseSettings)
    opt_name = state.token
    arg_after_eq = state.token_arg
    local f::ArgParseField
    local fln::AbstractString
    exact_match = false
    nfound = 0
    for g in settings.args_table.fields
        for ln in g.long_opt_name
            if ln == opt_name
                exact_match = true
                nfound = 1
                f = g
                fln = ln
                break
            elseif startswith(ln, opt_name)
                nfound += 1
                f = g
                fln = ln
            end
        end
        exact_match && break
    end
    nfound == 0 && argparse_error("unrecognized option --$opt_name")
    nfound > 1 && argparse_error("long option --$opt_name is ambiguous ($nfound partial matches)")

    opt_name = fln

    if is_flag(f)
        parse1_flag!(state, settings, f, arg_after_eq ≢ nothing, "--"*opt_name)
    else
        parse1_optarg!(state, settings, f, arg_after_eq, "--"*opt_name)
    end
    push!(state.found_args, idstring(f))
    return
end

# parse short opts
function parse_short_opt!(state::ParserState, settings::ArgParseSettings)
    shopts_lst = state.token
    rest_as_arg = nothing
    sind = firstindex(shopts_lst)
    while sind ≤ ncodeunits(shopts_lst)
        opt_char, next_sind = iterate(shopts_lst, sind)
        if next_sind ≤ ncodeunits(shopts_lst)
            next_opt_char, next2_sind = iterate(shopts_lst, next_sind)
            if next_opt_char == '='
                next_is_eq = true
                rest_as_arg = shopts_lst[next2_sind:end]
            else
                next_is_eq = false
                rest_as_arg = shopts_lst[next_sind:end]
            end
        else
            next_is_eq = false
            rest_as_arg = nothing
        end

        opt_name = string(opt_char)

        local f::ArgParseField
        found = false
        for outer f in settings.args_table.fields
            found |= any(sn->sn==opt_name, f.short_opt_name)
            found && break
        end
        found || argparse_error("unrecognized option -$opt_name")
        if is_flag(f)
            parse1_flag!(state, settings, f, next_is_eq, "-"*opt_name)
        else
            parse1_optarg!(state, settings, f, rest_as_arg, "-"*opt_name)
        end
        push!(state.found_args, idstring(f))
        state.arg_consumed && break
        if found_command(state)
            if rest_as_arg ≢ nothing && !isempty(rest_as_arg)
                startswith(rest_as_arg, '-') &&
                    argparse_error("illegal short options sequence after command " *
                                   "$(state.command): $rest_as_arg")
                pushfirst!(state.args_list, "-" * rest_as_arg)
                state.truncated_shopts = true
            end
            return
        end
        sind = next_sind
    end
end

# parse arg
function parse_arg!(state::ParserState, settings::ArgParseSettings)
    found = false
    local f::ArgParseField
    for new_arg_ind = state.last_arg+1:length(settings.args_table.fields)
        f = settings.args_table.fields[new_arg_ind]
        if is_arg(f) && !f.fake
            found = true
            state.last_arg = new_arg_ind
            break
        end
    end
    found || argparse_error("too many arguments")

    parse1_optarg!(state, settings, f, nothing, f.dest_name)

    push!(state.found_args, idstring(f))
    return
end

# convert_to_symbols
convert_to_symbols(::Nothing) = nothing
function convert_to_symbols(parsed_args::Dict{String,Any})
    new_parsed_args = Dict{Symbol,Any}()
    cmd = nothing
    if haskey(parsed_args, cmd_dest_name)
        cmd = parsed_args[cmd_dest_name]
        if cmd ≡ nothing
            scmd = nothing
        else
            scmd = Symbol(cmd)
            new_parsed_args[scmd] = convert_to_symbols(parsed_args[cmd])
        end
        new_parsed_args[scmd_dest_name] = scmd
    end
    for (k,v) in parsed_args
        (k == cmd_dest_name || k == cmd) && continue
        new_parsed_args[Symbol(k)] = v
    end
    return new_parsed_args
end
