__precompile__()

"""
    ArgParse

This module allows the creation of user-friendly command-line interfaces to Julia programs:
the program defines which arguments, options and sub-commands it accepts, and the `ArgParse` module
does the actual parsing, issues errors when the input is invalid, and automatically generates help
and usage messages.

Users familiar with Python's `argparse` module will find many similarities, but some important differences
as well.
"""
module ArgParse

using Compat
using Compat.Unicode
using Compat: @warn
using TextWrap

export
# types
    ArgParseSettings,
    ArgParseError,

# functions & macros
    add_arg_table,
    @add_arg_table,
    add_arg_group,
    set_default_arg_group,
    import_settings,
    usage_string,
    parse_args

import Base: show, getindex, setindex!, haskey

@static if VERSION >= v"0.7.0"
    @nospecialize # use only declared type signatures, helps with compile time
end

# auxiliary functions/constants
found_a_bug() = error("you just found a bug in the ArgParse module, please report it.")
const nbspc = '\u00a0'
const nbsps = "$nbspc"
println_unnbsp(io::IO, args...) = println(io, map(s->replace(s, nbspc => ' '), args)...)

# actions
#{{{
const all_actions = [:store_arg, :store_true, :store_false, :store_const,
                     :append_arg, :append_const, :count_invocations,
                     :command, :show_help, :show_version]

const internal_actions = [:store_arg, :store_true, :store_false, :store_const,
                          :append_arg, :append_const, :count_invocations,
                          :command_arg, :command_flag,
                          :show_help, :show_version]

const nonflag_actions = [:store_arg, :append_arg, :command_arg]
is_flag_action(a::Symbol) = !(a in nonflag_actions)

const multi_actions = [:append_arg, :append_const]
is_multi_action(a::Symbol) = a in multi_actions

const command_actions = [:command_arg, :command_flag]
is_command_action(a::Symbol) = a in command_actions
#}}}

# ArgConsumerType
#{{{
struct ArgConsumerType
    desc::Union{Int,Symbol}
    function ArgConsumerType(n::Integer)
        n ≥ 0 || error("nargs can't be negative")
        new(n)
    end
    function ArgConsumerType(s::Symbol)
        s in [:A, :?, :*, :+, :R] || error("nargs must be an integer or one of 'A', '?', '*', '+', 'R'")
        new(s)
    end
end
ArgConsumerType(c::Char) = ArgConsumerType(Symbol(c))
ArgConsumerType() = ArgConsumerType(:A)

function show(io::IO, nargs::ArgConsumerType)
    print(io, isa(nargs.desc, Int) ? nargs.desc : "'"*string(nargs.desc)*"'")
end

is_multi_nargs(nargs::ArgConsumerType) = (nargs.desc != 0 && nargs.desc != :A && nargs.desc != :?)

function default_action(nargs::Integer)
    nargs == 0 && return :store_true
    return :store_arg
end
default_action(nargs::Char) = :store_arg
default_action(nargs::Symbol) = :store_arg

default_action(nargs::ArgConsumerType) = default_action(nargs.desc)
#}}}

# ArgParseGroup
#{{{
mutable struct ArgParseGroup
    name::AbstractString
    desc::AbstractString
    ArgParseGroup(n::AbstractString, d::AbstractString) = new(n, d)
end

const cmd_group = ArgParseGroup("commands", "commands")
const pos_group = ArgParseGroup("positional", "positional arguments")
const opt_group = ArgParseGroup("optional", "optional arguments")

const std_groups = [cmd_group, pos_group, opt_group]
#}}}

# ArgParseField
#{{{
mutable struct ArgParseField
    dest_name::AbstractString
    long_opt_name::Vector{AbstractString}
    short_opt_name::Vector{AbstractString}
    arg_type::Type
    action::Symbol
    nargs::ArgConsumerType
    default
    constant
    range_tester::Function
    required::Bool
    eval_arg::Bool
    help::AbstractString
    metavar::Union{AbstractString,Vector}
    group::AbstractString
    fake::Bool
    function ArgParseField()
        return new("", AbstractString[], AbstractString[], Any, :store_true, ArgConsumerType(),
                   nothing, nothing, x->true, false, false, "", "", "", false)
    end
end

is_flag(arg::ArgParseField) = is_flag_action(arg.action)

is_arg(arg::ArgParseField) = isempty(arg.long_opt_name) && isempty(arg.short_opt_name)

is_cmd(arg::ArgParseField) = is_command_action(arg.action)

const cmd_dest_name = "%COMMAND%"
const scmd_dest_name = :_COMMAND_

function show(io::IO, s::ArgParseField)
    p(x) = "  $x=$(getfield(s, x))\n"
    str = "ArgParseField(\n"
    for f in fieldnames(ArgParseField)
        str *= p(f)
    end
    str *= "  )"
    print(io, str)
end
#}}}

# ArgParseTable
#{{{
mutable struct ArgParseTable
    fields::Vector{ArgParseField}
    subsettings::Dict{AbstractString,Any} # this in fact will be a Dict{AbstractString,ArgParseSettings}
    ArgParseTable() = new(ArgParseField[], Dict{AbstractString,Any}())
end

# disallow alphanumeric, -
function check_prefix_chars(chars)
    result = Set{Char}()
    for c in chars
        if isletter(c) || isnumeric(c) || c == '-'
            throw(ArgParseError("‘$(c)’ is not allowed as prefix character"))
        end
        push!(result, c)
    end
    result
end

# ArgParseSettings
#{{{


"""
    ArgParseSettings

The `ArgParseSettings` object contains all the settings to be used during argument parsing. Settings are divided
in two groups: general settings and argument-table-related settings.
While the argument table requires specialized functions such as [`@add_arg_table`](@ref) to be defined and manipulated,
general settings are simply object fields (most of them are `Bool` or `String`) and can be passed to the
constructor as keyword arguments, or directly set at any time.

This is the list of general settings currently available:

* `prog` (default = `""`): the name of the program, as displayed in the auto-generated help and usage screens.
  If left empty, the source file name will be used.
* `description` (default = `""`): a description of what the program does, to be displayed in the auto-generated
  help-screen, between the usage lines and the arguments description. If `preformatted_description` is `false` (see below),
  it will be automatically formatted, but you can still force newlines by using two consecutive newlines in the string, and
  manually control spaces by using non-breakable spaces (the character `'\\ua0'`).
* `preformatted_description` (default = `false`): disable automatic formatting of `description`.
* `epilog` (default = `""`): like `description`, but will be displayed at the end of the help-screen, after the
  arguments description. The same formatting rules also apply.
* `preformatted_epilog` (default = `false`): disable automatic formatting of `epilog`.
* `usage` (default = `""`): the usage line(s) to be displayed in the help screen and when an error is found during parsing.
  If left empty, it will be auto-generated.
* `version` (default = `"Unknown version"`): version information. It's used by the `:show_version` action.
* `add_help` (default = `true`): if `true`, a `--help, -h` option (triggering the `:show_help` action) is added
  to the argument table.
* `add_version` (default = `false`): if `true`, a `--version` option (triggering the `:show_version` action) is added
  to the argument table.
* `fromfile_prefix_chars` (default = `Set{Char}()`): an argument beginning with one of these characters will specify a file from which
  arguments will be read, one argument read per line. Alphanumeric characters and the hyphen-minus (`'-'`) are prohibited.
* `autofix_names` (default = `false`): if `true`, will try to automatically fix the uses of dashes (`'-'`) and underscores (`'_'`)
  in option names and destinations: all underscores will be converted to dashes in long option names; also, associated destination names, if
  auto-generated (see the [Argument names](@ref) section), will have dashes replaced with underscores, both for long options and for
  positional arguments. For example, an option declared as `"--my-opt"` will be associated with the key `"my_opt"` by default.
  It is especially advisable to turn this option on then parsing with the `as_symbols=true` argument to `parse_args`.
* `error_on_conflict` (default = `true`): if `true`, throw an error in case conflicting entries are added to the argument table;
  if `false`, later entries will silently take precedence.
  See the [Conflicts and overrides](@ref) srction for a detailed description of what conflicts are and what is the exact behavior
  when this setting is `false`.
* `suppress_warnings` (default = `false`): is `true`, all warnings will be suppressed.
* `allow_ambiguous_opts` (default = `false`): if `true`, ambiguous options such as `-1` will be accepted.
* `commands_are_required` (default = `true`): if `true`, commands will be mandatory. See the [Commands](@ref) section.
* `exc_handler` (default = `ArgParse.default_handler`): this is a function which is invoked when an error is detected
  during parsing (e.g. an option is not recognized, a required argument is not passed etc.). It takes two arguments:
  the `settings::ArgParseSettings` object and the `err::ArgParseError` exception. The default handler prints the error text
  and the usage screen on standard error and exits with error code 1:

  ```julia
  function default_handler(settings::ArgParseSettings, err, err_code::Int = 1)
      println(stderr, err.text)
      println(stderr, usage_string(settings))
      exit(err_code)
  end
  ```

  The module also provides a function `ArgParse.debug_handler` (not exported) which will just rethrow the error.
* `exit_after_help` (default = `true`): exits Julia (with error code `0`) when the `:show_help` or `:show_version` actions
  are triggered. If `false`, those actions will just stop the parsing and make `parse_args` return `nothing`.

Here is a usage example:

```julia
settings = ArgParseSettings(description = "This program does something",
                            commands_are_required = false,
                            version = "1.0",
                            add_version = true)
```

which is also equivalent to:

```julia
settings = ArgParseSettings()
settings.description = "This program does something."
settings.commands_are_required = false
settings.version = "1.0"
settings.add_version = true
```

As a shorthand, the `description` field can be passed without keyword, which makes this equivalent to the above:

```julia
settings = ArgParseSettings("This program does something",
                            commands_are_required = false,
                            version = "1.0",
                            add_version = true)
```

Most settings won't take effect until `parse_args` is invoked, but a few will have immediate effects: `autofix_names`,
`error_on_conflict`, `suppress_warnings`, `allow_ambiguous_opts`.
"""
mutable struct ArgParseSettings
    prog::AbstractString
    description::AbstractString
    epilog::AbstractString
    usage::AbstractString
    version::AbstractString
    add_help::Bool
    add_version::Bool
    fromfile_prefix_chars::Set{Char}
    autofix_names::Bool
    error_on_conflict::Bool
    suppress_warnings::Bool
    allow_ambiguous_opts::Bool
    commands_are_required::Bool
    args_groups::Vector{ArgParseGroup}
    default_group::AbstractString
    args_table::ArgParseTable
    exc_handler::Function
    preformatted_description::Bool
    preformatted_epilog::Bool
    exit_after_help::Bool

    function ArgParseSettings(;prog::AbstractString = Base.source_path() != nothing ? basename(Base.source_path()) : "",
                               description::AbstractString = "",
                               epilog::AbstractString = "",
                               usage::AbstractString = "",
                               version::AbstractString = "Unspecified version",
                               add_help::Bool = true,
                               add_version::Bool = false,
                               fromfile_prefix_chars = Set{Char}(),
                               autofix_names::Bool = false,
                               error_on_conflict::Bool = true,
                               suppress_warnings::Bool = false,
                               allow_ambiguous_opts::Bool = false,
                               commands_are_required::Bool = true,
                               exc_handler::Function = default_handler,
                               preformatted_description::Bool = false,
                               preformatted_epilog::Bool = false,
                               exit_after_help::Bool = true
                               )
        fromfile_prefix_chars = check_prefix_chars(fromfile_prefix_chars)
        return new(
            prog, description, epilog, usage, version, add_help, add_version,
            fromfile_prefix_chars, autofix_names, error_on_conflict,
            suppress_warnings, allow_ambiguous_opts, commands_are_required,
            copy(std_groups), "", ArgParseTable(), exc_handler,
            preformatted_description, preformatted_epilog,
            exit_after_help
            )
    end
end

# the "add_help" is kept for backwards compatibility and is now undocumented
ArgParseSettings(desc::AbstractString, add_help = true; kw...) = ArgParseSettings(;Any[(:description, desc), (:add_help, add_help), kw...]...)

function show(io::IO, s::ArgParseSettings)
    p(x) = "  $x=$(getfield(s, x))\n"
    str = "ArgParseSettings(\n"
    for f in setdiff(fieldnames(ArgParseSettings), [:args_groups, :args_table])
        str *= p(f)
    end
    str *= "  >> " * usage_string(s) * "\n"
    str *= "  )"
    print(io, str)
end

ArgName{T<:AbstractString} = Union{T, Vector{T}}

getindex(s::ArgParseSettings, c::AbstractString) = s.args_table.subsettings[c]
haskey(s::ArgParseSettings, c::AbstractString) = haskey(s.args_table.subsettings, c)
setindex!(s::ArgParseSettings, x::ArgParseSettings, c::AbstractString) = setindex!(s.args_table.subsettings, x, c)

#}}}

# fields declarations sanity checks
#{{{
function check_name_format(name::ArgName)
    isempty(name) && error("empty name")
    isa(name, Vector) || return true
    for n in name
        isempty(n)         && error("empty name")
        startswith(n, '-') || error("only options can have multiple names")
    end
    return true
end

function check_type(opt, T::Type, message::AbstractString)
    isa(opt, T) || error(message)
    return true
end

function check_eltype(opt, T::Type, message::AbstractString)
    eltype(opt) <: T || error(message)
    return true
end

function warn_extra_opts(opts, valid_keys::Vector{Symbol})

    for k in opts
        k in valid_keys || @warn "ignored option: $k"
    end
    return true
end

function check_action_is_valid(action::Symbol)
    action in all_actions || error("invalid action: $action")
end

function check_nargs_and_action(nargs::ArgConsumerType, action::Symbol)
    is_flag_action(action) && nargs.desc != 0 && nargs.desc != :A &&
        error("incompatible nargs and action (flag-action $action, nargs=$nargs)")
    is_command_action(action) && nargs.desc != :A &&
        error("incompatible nargs and action (command action, nargs=$nargs)")
    !is_flag_action(action) && nargs.desc == 0 &&
        error("incompatible nargs and action (non-flag-action $action, nargs=$nargs)")
    return true
end

function check_long_opt_name(name::AbstractString, settings::ArgParseSettings)
    '=' in name           && error("illegal option name: $name (contains '=')")
    occursin(r"\s", name) && error("illegal option name: $name (contains whitespace)")
    nbspc in name         && error("illegal option name: $name (contains non-breakable-space)")
    settings.add_help     &&
        name == "help"    && error("option --help is reserved in the current settings")
    settings.add_version  &&
        name == "version" && error("option --version is reserved in the current settings")
    return true
end

function check_short_opt_name(name::AbstractString, settings::ArgParseSettings)
    length(name) != 1                && error("short options must use a single character")
    name == "="                      && error("illegal short option name: $name")
    occursin(r"\s", name)            && error("illegal option name: $name (contains whitespace)")
    nbspc in name                    && error("illegal option name: $name (contains non-breakable-space)")
    !settings.allow_ambiguous_opts   &&
        occursin(r"[0-9.(]", name)   && error("ambiguous option name: $name (disabled in the current settings)")
    settings.add_help && name == "h" && error("option -h is reserved for help in the current settings")
    return true
end

function check_arg_name(name::AbstractString)
    occursin(r"^%[A-Z]*%$", name) && error("invalid positional arg name: $name (is reserved)")
    return true
end

function check_dest_name(name::AbstractString)
    occursin(r"^%[A-Z]*%$", name) && error("invalid dest_name: $name (is reserved)")
    return true
end

function idstring(arg::ArgParseField)
    if is_arg(arg)
        return "argument $(arg.metavar)"
    elseif !isempty(arg.long_opt_name)
        return "option --$(arg.long_opt_name[1])"
    else
        return "option -$(arg.short_opt_name[1])"
    end
end

# TODO improve (test more nonsensical cases)
function check_arg_makes_sense(settings::ArgParseSettings, arg::ArgParseField)
    is_arg(arg) || return true
    is_command_action(arg.action) && return true

    has_cmd = false
    has_nonreq = false
    for f in settings.args_table.fields
        if is_arg(f)
            is_command_action(f.action) && (has_cmd = true)
            f.required || (has_nonreq = true)
        end
    end
    has_cmd && error("non-command $(idstring(arg)) can't follow commands")
    has_nonreq && arg.required && error("required $(idstring(arg)) can't follow non-required arguments")
    return true
end

function check_conflicts_with_commands(settings::ArgParseSettings, new_arg::ArgParseField, allow_future_merge::Bool)
    for (cmd, ss) in settings.args_table.subsettings
        cmd == new_arg.dest_name && error("$(idstring(new_arg)) has the same destination of a command: $cmd")
    end
    for a in settings.args_table.fields
        if is_cmd(a) && !is_cmd(new_arg)
            for l1 in a.long_opt_name, l2 in new_arg.long_opt_name
                # TODO be less strict here and below, and allow partial override?
                l1 == l2 && error("long opt name --$(l1) already in use by command $(a.constant)")
            end
            for s1 in a.short_opt_name, s2 in new_arg.short_opt_name
                s1 == s2 && error("short opt name -$(s1) already in use by command $(a.constant)")
            end
        elseif is_cmd(a) && is_cmd(new_arg) && a.constant == new_arg.constant
            allow_future_merge || error("command $(a.constant) already in use")
            ((is_arg(a) && !is_arg(new_arg)) || (!is_arg(a) && is_arg(new_arg))) &&
                error("$(idstring(a)) and $(idstring(new_arg)) are incompatible")
        end
    end
    return true
end

function check_conflicts_with_commands(settings::ArgParseSettings, new_cmd::AbstractString)
    for a in settings.args_table.fields
        new_cmd == a.dest_name && error("command $new_cmd has the same destination of $(idstring(a))")
    end
    return true
end

function check_for_duplicates(args::Vector{ArgParseField}, new_arg::ArgParseField)
    for a in args
        for l1 in a.long_opt_name, l2 in new_arg.long_opt_name
            l1 == l2 && error("duplicate long opt name $l1")
        end
        for s1 in a.short_opt_name, s2 in new_arg.short_opt_name
            s1 == s2 && error("duplicate short opt name $s1")
        end
        if is_arg(a) && is_arg(new_arg) && a.metavar == new_arg.metavar
            error("two arguments have the same metavar: $(a.metavar)")
        end
        if a.dest_name == new_arg.dest_name
            a.arg_type == new_arg.arg_type ||
                error("$(idstring(a)) and $(idstring(new_arg)) have the same destination but different arg types")
            if (is_multi_action(a.action) && !is_multi_action(new_arg.action)) ||
               (!is_multi_action(a.action) && is_multi_action(new_arg.action))
                error("$(idstring(a)) and $(idstring(new_arg)) have the same destination but incompatible actions")
            end
        end
    end
    return true
end

check_default_type(default::Nothing, arg_type::Type) = true
function check_default_type(default, arg_type::Type)
    isa(default, arg_type) && return true
    error("the default value is of the incorrect type (typeof(default)=$(typeof(default)), arg_type=$arg_type)")
end

check_default_type_multi_action(default::Nothing, arg_type::Type) = true
function check_default_type_multi_action(default, arg_type::Type)
    (isa(default, Vector) && (arg_type <: eltype(default))) ||
        error("the default value is of the incorrect type (typeof(default)=$(typeof(default)), should be a Vector{T} with $arg_type<:T)")
    all(x->isa(x, arg_type), default) || error("all elements of the default value must be of type $arg_type)")
    return true
end

check_default_type_multi_nargs(default::Nothing, arg_type::Type) = true
function check_default_type_multi_nargs(default::Vector, arg_type::Type)
    all(x->isa(x, arg_type), default) || error("all elements of the default value must be of type $arg_type")
    return true
end
check_default_type_multi_nargs(default, arg_type::Type) =
    error("the default value is of the incorrect type (typeof(default)=$(typeof(default)), should be a Vector)")

check_default_type_multi2(default::Nothing, arg_type::Type) = true
function check_default_type_multi2(default, arg_type::Type)
    (isa(default, Vector) && (Vector{arg_type} <: eltype(default))) ||
        error("the default value is of the incorrect type (typeof(default)=$(typeof(default)), should be a Vector{T} with Vector{$arg_type}<:T)")
    all(y->all(x->isa(x, arg_type), y), default) || error("all elements of the default value must be of type $arg_type")
    return true
end

check_range_default(default::Nothing, range_tester::Function) = true
function check_range_default(default, range_tester::Function)
    local res::Bool
    try
        res = range_tester(default)
    catch err
        error("the range_tester function must be defined for the default value and return a Bool")
    end
    res || error("the default value must pass the range_tester function")
    return true
end

check_range_default_multi(default::Nothing, range_tester::Function) = true
function check_range_default_multi(default::Vector, range_tester::Function)
    for d in default
        local res::Bool
        try
            res = range_tester(d)
        catch err
            error("the range_tester function must be a defined for all the default values and return a Bool")
        end
        res || error("all of the default values must pass the range_tester function")
    end
    return true
end

check_range_default_multi2(default::Nothing, range_tester::Function) = true
function check_range_default_multi2(default::Vector, range_tester::Function)
    for dl in default, d in dl
        local res::Bool
        try
            res = range_tester(d)
        catch err
            error("the range_tester function must be a defined for all the default values and return a Bool")
        end
        res || error("all of the default values must pass the range_tester function")
    end
    return true
end

function check_metavar(metavar::AbstractString)
    isempty(metavar)         && error("empty metavar")
    startswith(metavar, '-') && error("metavars cannot begin with -")
    occursin(r"\s", metavar) && error("illegal metavar name: $metavar (contains whitespace)")
    nbspc in metavar         && error("illegal metavar name: $metavar (contains non-breakable-space)")
    return true
end

function check_metavar(metavar::Vector{<:AbstractString})
    for single_value in metavar
        check_metavar(single_value)
    end
    return true
end

function check_group_name(name::AbstractString)
    isempty(name)         && error("empty group name")
    startswith(name, '#') && error("invalid group name (starts with #)")
    return true
end
#}}}

# add_arg_table and related
#{{{
function name_to_fieldnames(name::ArgName, settings::ArgParseSettings)
    pos_arg = ""
    long_opts = AbstractString[]
    short_opts = AbstractString[]
    r(n) = settings.autofix_names ? replace(n, '_' => '-') : n
    if isa(name, Vector)
        for n in name
            if startswith(n, "--")
                n == "--" && error("illegal option name: --")
                long_opt_name = r(n[3:end])
                check_long_opt_name(long_opt_name, settings)
                push!(long_opts, long_opt_name)
            else
                @assert startswith(n, '-')
                n == "-" && error("illegal option name: -")
                short_opt_name = n[2:end]
                check_short_opt_name(short_opt_name, settings)
                push!(short_opts, short_opt_name)
            end
        end
    else
        if startswith(name, "--")
            name == "--" && error("illegal option name: --")
            long_opt_name = r(name[3:end])
            check_long_opt_name(long_opt_name, settings)
            push!(long_opts, long_opt_name)
        elseif startswith(name, '-')
            name == "-" && error("illegal option name: -")
            short_opt_name = name[2:end]
            check_short_opt_name(short_opt_name, settings)
            push!(short_opts, short_opt_name)
        else
            check_arg_name(name)
            pos_arg = name
        end
    end
    return pos_arg, long_opts, short_opts
end

function auto_dest_name(pos_arg::AbstractString, long_opts::Vector{AbstractString}, short_opts::Vector{AbstractString}, autofix_names::Bool)
    r(n) = autofix_names ? replace(n, '-' => '_') : n
    isempty(pos_arg) || return r(pos_arg)
    isempty(long_opts) || return r(long_opts[1])
    @assert !isempty(short_opts)
    return short_opts[1]
end

function auto_metavar(dest_name::AbstractString, is_opt::Bool)
    is_opt || return dest_name
    prefix = occursin(r"^[[:alpha:]_]", dest_name) ? "" : "_"
    return prefix * uppercase(dest_name)
end

function get_cmd_prog_hint(arg::ArgParseField)
    isempty(arg.short_opt_name) || return "-" * arg.short_opt_name[1]
    isempty(arg.long_opt_name) || return "--" * arg.long_opt_name[1]
    return arg.constant
end


"""
    add_arg_table(settings, [arg_name [,arg_options]]...)

This function is very similar to the macro version [`@add_arg_table`](@ref). Its syntax is stricter: tuples and blocks are not allowed and argument options
are explicitly specified as `Dict` objects. However, since it doesn't involve macros, it offers more flexibility in other respects,
e.g. the `arg_name` entries need not be explicit, they can be anything which evaluates to a `String` or a `Vector{String}`.

Example:

```julia
add_arg_table(settings,
    ["--opt1", "-o"],
    Dict(
        :help => "an option with an argument"
    ),
    "--opt2",
    "arg1",
    Dict(
        :help => "a positional argument"
        :required => true
    ))
```
"""
function add_arg_table(settings::ArgParseSettings, table::Union{ArgName,Vector,Dict}...)
    has_name = false
    for i = 1:length(table)
        !has_name && !isa(table[i], ArgName) && error("option field must be preceded by the arg name")
        has_name = true
    end
    i = 1
    while i ≤ length(table)
        if i+1 ≤ length(table) && !isa(table[i+1], ArgName)
            add_arg_field(settings, table[i]; table[i+1]...)
            i += 2
        else
            add_arg_field(settings, table[i])
            i += 1
        end
    end
end

"""
    @add_arg_table(settings, table...)

This macro adds a table of arguments and options to the given `settings`. It can be invoked multiple times. The arguments groups
are determined automatically, or the current default group is used if specified (see the [Argument groups](@ref) section for
more details).

The `table` is a list in which each element can be either `String`, or a tuple or a vector of `String`, or an assigmment
expression, or a block:

* a `String`, a tuple or a vector introduces a new positional argument or option. Tuples and vectors are only allowed for options and
  provide alternative names (e.g. `["--opt", "-o"]`)
* assignment expressions (i.e. expressions using `=`, `:=` or `=>`) describe the previous argument behavior (e.g.
  `help = "an option"` or `required => false`).  See the [Argument entry settings](@ref) section for a complete description
* blocks (`begin...end` or lists of expressions in parentheses separated by semicolons) are useful to group entries and span
  multiple lines.

These rules allow for a variety usage styles, which are discussed in the [Argument table styles](@ref) section.
In the rest of the documentation, we will mostly use this style:

```julia
@add_arg_table settings begin
    "--opt1", "-o"
        help = "an option with an argument"
    "--opt2"
    "arg1"
        help = "a positional argument"
        required = true
end
```

In the above example, the `table` is put in a single `begin...end` block and the line `"--opt1", "-o"` is parsed as a tuple;
indentation is used to help readability.

See also the function [`add_arg_table`](@ref).
"""
macro add_arg_table(s, x...)
    # transform the tuple into a vector, so that
    # we can manipulate it
    x = Any[x...]
    # escape the ArgParseSettings
    s = esc(s)
    # start building the return expression
    exret = quote
        isa($s, ArgParseSettings) || error("first argument to @add_arg_table must be of type ArgParseSettings")
    end
    # initialize the name and the options expression
    name = nothing
    exopt = Any[:Dict]

    # iterate over the arguments
    i = 1
    while i ≤ length(x)
        y = x[i]
        if Meta.isexpr(y, :block)
            # found a begin..end block: expand its contents
            # in-place and restart from the same position
            splice!(x, i, y.args)
            continue
        elseif Meta.isexpr(y, :macrocall) &&
               ((y.args[1] == GlobalRef(Core, Symbol("@doc"))) ||
               (Meta.isexpr(y.args[1], :core) && y.args[1].args[1] == Symbol("@doc")))
            # Was parsed as doc syntax. Split into components
            splice!(x, i, y.args[2:end])
            continue
        elseif isa(y, AbstractString) || Meta.isexpr(y, (:vect, :tuple))
            Meta.isexpr(y, :tuple) && (y.head = :vect) # transform tuples into vectors
            if Meta.isexpr(y, :vect) && (isempty(y.args) || !all(x->x isa AbstractString, y.args))
                # heterogeneous elements: splice it in place, just like blocks
                splice!(x, i, y.args)
                continue
            end
            # found a string, or a vector/tuple of strings:
            # this must be the option name
            if name ≢ nothing
                # there was a previous arg field on hold
                # first, concretely build the options
                opt = Expr(:call, exopt...)
                kopts = Expr(:parameters, Expr(:(...), opt))
                # then, call add_arg_field
                aaf = Expr(:call, :add_arg_field, kopts, s, name)
                # store it in the output expression
                exret = quote
                    $exret
                    $aaf
                end
            end
            # put the name on hold, reinitialize the options expression
            name = y
            exopt = Any[:Dict]
            i += 1
        elseif Meta.isexpr(y, (:(=), :(:=), :kw))
            # found an assignment: add it to the current options expression
            name ≢ nothing || error("malformed table: description fields must be preceded by the arg name")
            push!(exopt, Expr(:call, :(=>), Expr(:quote, y.args[1]), esc(y.args[2])))
            i += 1
        elseif Meta.isexpr(y, :call) && y.args[1] == :(=>)
            # found an assignment: add it to the current options expression
            name ≢ nothing || error("malformed table: description fields must be preceded by the arg name")
            push!(exopt, Expr(:call, :(=>), Expr(:quote, y.args[2]), esc(y.args[3])))
            i += 1
        elseif isa(y, LineNumberNode) || Meta.isexpr(y, :line)
            # a line number node, ignore
            i += 1
            continue
        else
            # anything else: ignore, but issue a warning
            @warn "@add_arg_table: ignoring expression $y"
            i += 1
        end
    end
    if name ≢ nothing
        # there is an arg field on hold
        # same as above
        opt = Expr(:call, exopt...)
        kopts = Expr(:parameters, Expr(:(...), opt))
        aaf = Expr(:call, :add_arg_field, kopts, s, name)
        exret = quote
            $exret
            $aaf
        end
    end

    # the return value when invoking the macro
    # will be the ArgParseSettings object
    exret = quote
        $exret
        $s
    end

    # return the resulting expression
    exret
end

function get_group(group::AbstractString, arg::ArgParseField, settings::ArgParseSettings)
    if isempty(group)
        is_cmd(arg) && return cmd_group
        is_arg(arg) && return pos_group
        return opt_group
    else
        for ag in settings.args_groups
            group == ag.name && return ag
        end
        error("group $group not found, use add_arg_group to add it")
    end
    found_a_bug()
end
get_group_name(group::AbstractString, arg::ArgParseField, settings::ArgParseSettings) =
    get_group(group, arg, settings).name

#imported from Options.jl, with slight modifications
macro defaults(opts, ex...)
    # Transform the tuple into a vector, so that
    # we can manipulate it
    ex = Any[ex...]
    opts = esc(opts)
    # Transform the opts array into a Dict
    exret = :($opts = Dict{Symbol,Any}($opts))
    # Initialize the checks
    used = esc(gensym("opts"))
    exret = quote
        $exret
        $used = Dict{Symbol,Bool}([(k,false) for (k,v) in $opts])
    end

    # Check each argument in the assignment list
    i = 1
    while i ≤ length(ex)
        y = ex[i]
        if Meta.isexpr(y, :block)
            # Found a begin..end block: expand its contents in-place
            # and restart from the same position
            splice!(ex, i, y.args)
            continue
        elseif isa(y, LineNumberNode) || Meta.isexpr(y, :line)
            # A line number node, ignore
            i += 1
            continue
        elseif Meta.isexpr(y, :call) && y.args[1] == :(=>)
            y = Expr(:(=), y.args[2:end]...)
        elseif !Meta.isexpr(y, (:(=), :(:=), :kw))
            error("Arguments to @defaults following the options variable must be assignments, e.g., a=5 or a=>5")
        end
        y.head = :(=)

        sym = y.args[1]
        qsym = Expr(:quote, sym)
        exret = quote
            $exret
            if haskey($opts, $qsym)
                $(esc(sym)) = $opts[$qsym]
                $used[$qsym] = true
            else
                $(esc(y))
            end
        end
        i += 1
    end
    exret = quote
        $exret
        for (k,v) in $used
            v || error("unknown description field: $k")
        end
    end
    exret
end

function add_arg_field(settings::ArgParseSettings, name::ArgName; desc...)
    check_name_format(name)

    supplied_opts = Symbol[k for (k,v) in desc]

    @defaults desc begin
        nargs = ArgConsumerType()
        action = default_action(nargs)
        arg_type = Any
        default = nothing
        constant = nothing
        required = false
        range_tester = x->true
        eval_arg = false
        dest_name = ""
        help = ""
        metavar = ""
        force_override = !settings.error_on_conflict
        group = settings.default_group
    end

    check_type(nargs, Union{ArgConsumerType,Int,Char}, "nargs must be an Int or a Char")
    check_type(action, Union{AbstractString,Symbol}, "action must be an AbstractString or a Symbol")
    check_type(arg_type, Type, "invalid arg_type")
    check_type(required, Bool, "required must be a Bool")
    check_type(range_tester, Function, "range_tester must be a Function")
    check_type(dest_name, AbstractString, "dest_name must be an AbstractString")
    check_type(help, AbstractString, "help must be an AbstractString")
    # Check metavar's type to be either an AbstractString or a
    # Vector{T<:AbstractString}
    metavar_error = "metavar must be an AbstractString or a Vector{T<:AbstractString}"
    isa(metavar, AbstractString) ||
        (
            check_type(metavar, Vector, metavar_error) &&
            check_eltype(metavar, AbstractString, metavar_error) &&
            check_type(nargs, Integer, "nargs must be an integer for multiple metavars") &&
            (length(metavar) == nargs || error("metavars array must have length of nargs"))
        )
    check_type(force_override, Bool, "force_override must be a Bool")
    check_type(group, Union{AbstractString,Symbol}, "group must be an AbstractString or a Symbol")

    isa(nargs, ArgConsumerType) || (nargs = ArgConsumerType(nargs))
    isa(action, Symbol) || (action = Symbol(action))

    is_opt = isa(name, Vector) || startswith(name, '-')

    check_action_is_valid(action)

    action == :command && (action = is_opt ? (:command_flag) : (:command_arg))

    check_nargs_and_action(nargs, action)

    new_arg = ArgParseField()

    is_flag = is_flag_action(action)

    if !is_opt
        is_flag && error("invalid action for positional argument: $action")
        nargs.desc == :? && error("invalid 'nargs' for positional argument: '?'")
        isa(metavar, Vector) && error("multiple metavars only supported for optional arguments")
    end

    pos_arg, long_opts, short_opts = name_to_fieldnames(name, settings)

    new_arg.dest_name = auto_dest_name(pos_arg, long_opts, short_opts, settings.autofix_names)

    new_arg.long_opt_name = long_opts
    new_arg.short_opt_name = short_opts
    new_arg.nargs = nargs
    new_arg.action = action

    group = string(group)
    if (:group in supplied_opts) && !isempty(group)
        check_group_name(group)
    end
    new_arg.group = get_group_name(group, new_arg, settings)

    if (action == :store_const || action == :append_const) &&
           !(:constant in supplied_opts)
        error("action $action requires the 'constant' field")
    end

    valid_keys = [:nargs, :action, :help, :force_override, :group]
    if is_flag
        if action == :store_const || action == :append_const
            append!(valid_keys, [:default, :constant, :arg_type, :dest_name])
        elseif action == :store_true || action == :store_false ||
               action == :count_invocations || action == :command_flag
            push!(valid_keys, :dest_name)
        elseif action == :show_help || action == :show_version
        else
            found_a_bug()
        end
    elseif is_opt
        append!(valid_keys, [:arg_type, :default, :range_tester, :dest_name, :required, :metavar, :eval_arg])
        nargs.desc == :? && push!(valid_keys, :constant)
    elseif action != :command_arg
        append!(valid_keys, [:arg_type, :default, :range_tester, :required, :metavar])
    end
    settings.suppress_warnings || warn_extra_opts(supplied_opts, valid_keys)

    if is_command_action(action)
        if (:dest_name in supplied_opts) && (:dest_name in valid_keys)
            cmd_name = dest_name
        else
            cmd_name = new_arg.dest_name
        end
    end
    if (:dest_name in supplied_opts) && (:dest_name in valid_keys) && (action != :command_flag)
        new_arg.dest_name = dest_name
    end

    check_dest_name(dest_name)

    set_if_valid(k, x) = k in valid_keys && setfield!(new_arg, k, x)

    set_if_valid(:arg_type, arg_type)
    set_if_valid(:default, deepcopy(default))
    set_if_valid(:constant, deepcopy(constant))
    set_if_valid(:range_tester, range_tester)
    set_if_valid(:required, required)
    set_if_valid(:help, help)
    set_if_valid(:metavar, metavar)
    set_if_valid(:eval_arg, eval_arg)

    if !is_flag
        isempty(new_arg.metavar) && (new_arg.metavar = auto_metavar(new_arg.dest_name, is_opt))
        check_metavar(new_arg.metavar)
    end

    if is_command_action(action)
        new_arg.dest_name = cmd_dest_name
        new_arg.arg_type = AbstractString
        new_arg.constant = cmd_name
        new_arg.metavar = cmd_name
        cmd_prog_hint = get_cmd_prog_hint(new_arg)
    end

    if is_flag
        if action == :store_true
            new_arg.arg_type = Bool
            new_arg.default = false
            new_arg.constant =  true
        elseif action == :store_false
            new_arg.arg_type = Bool
            new_arg.default = true
            new_arg.constant =  false
        elseif action == :count_invocations
            new_arg.arg_type = Int
            new_arg.default = 0
        elseif action == :store_const || action == :append_const
            if :arg_type in supplied_opts
                check_default_type(new_arg.default, new_arg.arg_type)
                check_default_type(new_arg.constant, new_arg.arg_type)
            else
                if typeof(new_arg.default) == typeof(new_arg.constant)
                    new_arg.arg_type = typeof(new_arg.default)
                else
                    new_arg.arg_type = Any
                end
            end
            if action == :append_const && (new_arg.default ≡ nothing || new_arg.default == [])
                new_arg.default = Array{new_arg.arg_type}(undef, 0)
            end
        elseif action == :command_flag
            # nothing to do
        elseif action == :show_help || action == :show_version
            # nothing to do
        else
            found_a_bug()
        end
    else
        arg_type = new_arg.arg_type
        range_tester = new_arg.range_tester
        default = new_arg.default

        if !is_multi_action(new_arg.action) && !is_multi_nargs(new_arg.nargs)
            check_default_type(default, arg_type)
            check_range_default(default, range_tester)
        elseif !is_multi_action(new_arg.action)
            check_default_type_multi_nargs(default, arg_type)
            check_range_default_multi(default, range_tester)
        elseif !is_multi_nargs(new_arg.nargs)
            check_default_type_multi_action(default, arg_type)
            check_range_default_multi(default, range_tester)
        else
            check_default_type_multi2(default, arg_type)
            check_range_default_multi2(default, range_tester)
        end
        if (is_multi_action(new_arg.action) && is_multi_nargs(new_arg.nargs)) && (default ≡ nothing || default == [])
            new_arg.default = Array{Vector{arg_type}}(undef, 0)
        elseif (is_multi_action(new_arg.action) || is_multi_nargs(new_arg.nargs)) && (default ≡ nothing || default == [])
            new_arg.default = Array{arg_type}(undef, 0)
        end

        if is_opt && nargs.desc == :?
            constant = new_arg.constant
            check_default_type(constant, arg_type)
            check_range_default(constant, range_tester)
        end
    end

    if action == :command_arg
        for f in settings.args_table.fields
            if f.action == :command_arg
                new_arg.fake = true
                break
            end
        end
    end

    check_arg_makes_sense(settings, new_arg)

    check_conflicts_with_commands(settings, new_arg, false)
    if force_override
        override_duplicates(settings.args_table.fields, new_arg)
    else
        check_for_duplicates(settings.args_table.fields, new_arg)
    end
    push!(settings.args_table.fields, new_arg)
    is_command_action(action) && add_command(settings, cmd_name, cmd_prog_hint, force_override)
    return
end

function add_command(settings::ArgParseSettings, command::AbstractString, prog_hint::AbstractString, force_override::Bool)
    haskey(settings, command) && error("command $command already added")
    if force_override
        override_conflicts_with_commands(settings, command)
    else
        check_conflicts_with_commands(settings, command)
    end
    settings[command] = ArgParseSettings()
    ss = settings[command]
    ss.prog = "$(isempty(settings.prog) ? "<PROGRAM>" : settings.prog) $prog_hint"
    ss.description = ""
    ss.preformatted_description = settings.preformatted_description
    ss.epilog = ""
    ss.preformatted_epilog = settings.preformatted_epilog
    ss.usage = ""
    ss.version = settings.version
    ss.add_help = settings.add_help
    ss.add_version = settings.add_version
    ss.autofix_names = settings.autofix_names
    ss.fromfile_prefix_chars = settings.fromfile_prefix_chars
    ss.error_on_conflict = settings.error_on_conflict
    ss.suppress_warnings = settings.suppress_warnings
    ss.allow_ambiguous_opts = settings.allow_ambiguous_opts
    ss.exc_handler = settings.exc_handler
    ss.exit_after_help = settings.exit_after_help

    return ss
end

autogen_group_name(desc::AbstractString) = "#$(hash(desc))"

add_arg_group(settings::ArgParseSettings, desc::AbstractString) =
    _add_arg_group(settings, desc, autogen_group_name(desc), true)


"""
    add_arg_group(settings, description, [name , [set_as_default]])

This function adds an argument group to the argument table in `settings`. The `description` is a `String` used in
the help screen as a title for that group. The `name` is a unique name which can be provided to refer to that group
at a later time.

After invoking this function, all subsequent invocations of the [`@add_arg_table`](@ref) macro and [`add_arg_table`](@ref)
function will use the new group as the default, unless `set_as_default` is set to `false` (the default is `true`, and the
option can only be set if providing a `name`). Therefore, the most obvious usage pattern is: for each group, add it and
populate the argument table of that group. Example:

```
julia> settings = ArgParseSettings();

julia> add_arg_group(settings, "custom group");

julia> @add_arg_table settings begin
          "--opt"
          "arg"
       end;

julia> parse_args(["--help"], settings)
usage: <command> [--opt OPT] [-h] [arg]

optional arguments:
  -h, --help  show this help message and exit

custom group:
  --opt OPT
  arg
```

As seen from the example, new groups are always added at the end of existing ones.

The `name` can also be passed as a `Symbol`. Forbidden names are the standard groups names (`"command"`,
`"positional"` and `"optional"`) and those beginning with a hash character `'#'`.
"""
function add_arg_group(settings::ArgParseSettings, desc::AbstractString,
                       tag::Union{AbstractString,Symbol}, set_as_default::Bool = true)
    name = string(tag)
    check_group_name(name)
    _add_arg_group(settings, desc, name, set_as_default)
end

function _add_arg_group(settings::ArgParseSettings, desc::AbstractString, name::AbstractString, set_as_default::Bool)
    already_added = any(ag->ag.name==name, settings.args_groups)
    already_added || push!(settings.args_groups, ArgParseGroup(name, desc))
    set_as_default && (settings.default_group = name)
    return settings
end

set_default_arg_group(settings::ArgParseSettings) = set_default_arg_group(settings, "")

"""
    set_default_arg_group(settings, [name])

Set the default group for subsequent invocations of the [`@add_arg_table`](@ref) macro and [`add_arg_table`](@ref)
function. `name` is a `String`, and must be one of the standard group names (`"command"`, `"positional"` or
`"optional"`) or one of the user-defined names given in `add_arg_group` (groups with no assigned name cannot be
used with this function).

If `name` is not provided or is the empty string `""`, then the default behavior is reset (i.e. arguments will be
automatically assigned to the standard groups).
The `name` can also be passed as a `Symbol`.
"""
function set_default_arg_group(settings::ArgParseSettings, name::Union{AbstractString,Symbol})
    name = string(name)
    startswith(name, '#') && error("invalid group name: $name (begins with #)")
    isempty(name) && (settings.default_group = ""; return)
    found = any(ag->ag.name==name, settings.args_groups)
    found || error("group $name not found")
    settings.default_group = name
    return
end
#}}}

# import_settings & friends
#{{{
function override_conflicts_with_commands(settings::ArgParseSettings, new_cmd::AbstractString)
    ids0 = Int[]
    for ia in 1:length(settings.args_table.fields)
        a = settings.args_table.fields[ia]
        new_cmd == a.dest_name && push!(ids0, ia)
    end
    while !isempty(ids0)
        splice!(settings.args_table.fields, pop!(ids0))
    end
end
function override_duplicates(args::Vector{ArgParseField}, new_arg::ArgParseField)
    ids0 = Int[]
    for ia in 1:length(args)
        a = args[ia]
        if (a.dest_name == new_arg.dest_name) &&
            ((a.arg_type != new_arg.arg_type) ||
             (is_multi_action(a.action) && !is_multi_action(new_arg.action)) ||
             (!is_multi_action(a.action) && is_multi_action(new_arg.action)))
            # unsolvable conflict, mark for deletion
            push!(ids0, ia)
            continue
        end
        if is_arg(a) && is_arg(new_arg) && a.metavar == new_arg.metavar
            # unsolvable conflict, mark for deletion
            push!(ids0, ia)
            continue
        end

        if is_arg(a) || is_arg(new_arg)
            # not an option, skip
            continue
        end

        if is_cmd(a) && is_cmd(new_arg) && a.constant == new_arg.constant && !is_arg(a)
            @assert !is_arg(new_arg) # this is ensured by check_settings_are_compatible
            # two command flags with the same command -> should have already been taken care of,
            # by either check_settings_are_compatible or merge_commands
            continue
        end

        # delete conflicting long options
        ids = Int[]
        for il1 = 1:length(a.long_opt_name), l2 in new_arg.long_opt_name
            l1 = a.long_opt_name[il1]
            l1 == l2 && push!(ids, il1)
        end
        while !isempty(ids)
            splice!(a.long_opt_name, pop!(ids))
        end

        # delete conflicting short options
        ids = Int[]
        for is1 in 1:length(a.short_opt_name), s2 in new_arg.short_opt_name
            s1 = a.short_opt_name[is1]
            s1 == s2 && push!(ids, is1)
        end
        while !isempty(ids)
            splice!(a.short_opt_name, pop!(ids))
        end

        # if everything was deleted, remove the field altogether
        # (i.e. mark it for deletion)
        isempty(a.long_opt_name) && isempty(a.short_opt_name) && push!(ids0, ia)
    end

    # actually remove the marked fields
    while !isempty(ids0)
        splice!(args, pop!(ids0))
    end
end

function check_settings_are_compatible(settings::ArgParseSettings, other::ArgParseSettings)
    table = settings.args_table
    otable = other.args_table

    for a in otable.fields
        check_conflicts_with_commands(settings, a, true)
        settings.error_on_conflict && check_for_duplicates(table.fields, a)
    end

    for (subk, subs) in otable.subsettings
        settings.error_on_conflict && check_conflicts_with_commands(settings, subk)
        haskey(settings, subk) && check_settings_are_compatible(settings[subk], subs)
    end
    return true
end

function merge_commands(fields::Vector{ArgParseField}, ofields::Vector{ArgParseField})
    oids = Int[]
    for a in fields, ioa = 1:length(ofields)
        oa = ofields[ioa]
        if is_cmd(a) && is_cmd(oa) && a.constant == oa.constant && !is_arg(a)
            @assert !is_arg(oa) # this is ensured by check_settings_are_compatible
            for l in oa.long_opt_name
                l in a.long_opt_name || push!(a.long_opt_name, l)
            end
            for s in oa.short_opt_name
                s in a.short_opt_name || push!(a.short_opt_name, s)
            end
            a.group = oa.group # note: the group may not be present yet, but it will be
                               #       added later
            push!(oids, ioa)
        end
    end
    # we return the merged ofields indices, since we still need to use them for overriding options
    # before we actually remove them
    return oids
end

function fix_commands_fields(fields::Vector{ArgParseField})
    cmd_found = false
    for a in fields
        if is_arg(a) && is_cmd(a)
            a.fake = cmd_found
            cmd_found = true
        end
    end
end

"""
    import_settings(settings, other_settings [,args_only])

Imports `other_settings` into `settings`, where both are [`ArgParseSettings`](@ref) objects. If `args_only` is
`true` (this is the default), only the argument table will be imported; otherwise, the default argument group
will also be imported, and all general settings except `prog`, `description`, `epilog`, `usage` and `version`.

Sub-settings associated with commands will also be imported recursively; the `args_only` setting applies to
those as well. If there are common commands, their sub-settings will be merged.

While importing, conflicts may arise: if `settings.error_on_conflict` is `true`, this will result in an error,
otherwise conflicts will be resolved in favor of `other_settings` (see the [Conflicts and overrides](@ref) section
for a detailed discussion of how conflicts are handled).

Argument groups will also be imported; if two groups in `settings` and `other_settings` match, they are merged
(groups match either by name, or, if unnamed, by their description).

Note that the import will have effect immediately: any subsequent modification of `other_settings` will not have
any effect on `settings`.

This function can be used at any time.
"""
function import_settings(settings::ArgParseSettings, other::ArgParseSettings, args_only::Bool = true)
    check_settings_are_compatible(settings, other)

    fields = settings.args_table.fields
    ofields = deepcopy(other.args_table.fields)
    merged_oids = merge_commands(fields, ofields)
    if !settings.error_on_conflict
        for a in ofields
            override_duplicates(fields, a)
        end
        for (subk, subs) in other.args_table.subsettings
            override_conflicts_with_commands(settings, subk)
        end
    end
    while !isempty(merged_oids)
        splice!(ofields, pop!(merged_oids))
    end
    append!(fields, ofields)
    for oag in other.args_groups
        skip = false
        for ag in settings.args_groups
            # TODO: merge groups in some cases
            if oag.name == ag.name
                skip = true
                break
            end
        end
        skip && continue
        push!(settings.args_groups, deepcopy(oag))
    end

    fix_commands_fields(fields)

    if !args_only
        settings.add_help = other.add_help
        settings.add_version = other.add_version
        settings.error_on_conflict = other.error_on_conflict
        settings.suppress_warnings = other.suppress_warnings
        settings.exc_handler = other.exc_handler
        settings.allow_ambiguous_opts = other.allow_ambiguous_opts
        settings.commands_are_required = other.commands_are_required
        settings.default_group = other.default_group
        settings.preformatted_description = other.preformatted_description
        settings.preformatted_epilog = other.preformatted_epilog
        settings.fromfile_prefix_chars = other.fromfile_prefix_chars
        settings.autofix_names = other.autofix_names
        settings.exit_after_help = other.exit_after_help
    end
    for (subk, subs) in other.args_table.subsettings
        cmd_prog_hint = ""
        for oa in other.args_table.fields
            if is_cmd(oa) && oa.constant == subk
                cmd_prog_hint = get_cmd_prog_hint(oa)
                break
            end
        end
        if !haskey(settings, subk)
            add_command(settings, subk, cmd_prog_hint, !settings.error_on_conflict)
        elseif !isempty(cmd_prog_hint)
            settings[subk].prog = "$(settings.prog) $cmd_prog_hint"
        end
        import_settings(settings[subk], subs, args_only)
    end
    return settings
end
#}}}

# ArgParseError
#{{{
struct ArgParseError <: Exception
    text::AbstractString
end

argparse_error(x...) = throw(ArgParseError(string(x...)))
#}}}

# parsing checks
#{{{
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

function test_required_args(settings::ArgParseSettings, found_args::Set{AbstractString})
    for f in settings.args_table.fields
        !is_cmd(f) && f.required && !(idstring(f) in found_args) &&
            argparse_error("required $(idstring(f)) was not provided")
    end
    return true
end

function check_settings_can_use_symbols(settings::ArgParseSettings)
    args_table = settings.args_table
    if !isempty(args_table.subsettings)
        for f in args_table.fields
            f.dest_name == string(scmd_dest_name) && error("the dest_name $(string(scmd_dest_name)) cannot be used with the as_symbols option")
        end
        for subs in values(args_table.subsettings)
            check_settings_can_use_symbols(subs)
        end
    end
    settings.suppress_warnings && return true
    for f in args_table.fields
        '-' in f.dest_name && @warn "dest_name=$(f.dest_name) contains an hyphen; use the autofix_names=true setting to have it converted to an underscore"
    end
    return true
end
#}}}

# parsing aux functions
#{{{
function parse_item_wrapper(it_type::Type, x::AbstractString)
    local r::it_type
    try
        r = parse_item(it_type, x)
    catch err
        argparse_error("""
            invalid argument: $x (conversion to type $it_type failed; you may need to overload ArgParse.parse_item;
                              the error was: $err)""")
    end
    return r
end

parse_item(it_type::Type{Any}, x::AbstractString) = x
parse_item(it_type::Type{T}, x::AbstractString) where {T<:Number} = parse(it_type, x)
parse_item(it_type::Type{T}, x::AbstractString) where {T} = convert(T, x)

function parse_item_eval(it_type::Type, x::AbstractString)
    local r::it_type
    try
        r = convert(it_type, eval(Meta.parse(x)))
    catch err
        argparse_error("""
            invalid argument: $x (must evaluate or convert to type $it_type;
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

    lc_len_limit = 24

    cmd_lst = Any[]
    pos_lst = Any[]
    opt_lst = Any[]
    for f in settings.args_table.fields
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
            if !f.required
                bra_pre = "["
                bra_post = "]"
            else
                bra_pre = ""
                bra_post = ""
            end
            if isa(f.nargs.desc, Int)
                if isa(f.metavar, AbstractString)
                    arg_str = string(ntuple(i->(i==1 ? f.metavar : (nbsps * f.metavar)), f.nargs.desc)...)
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
            if !f.required
                bra_pre = "["
                bra_post = "]"
            else
                bra_pre = ""
                bra_post = ""
            end
            if !isempty(f.short_opt_name)
                opt_str1 = "-" * f.short_opt_name[1]
            else
                opt_str1 = "--" * f.long_opt_name[1]
            end
            if is_flag(f)
                opt_str2 = ""
            else
                if isa(f.nargs.desc, Int)
                    if isa(f.metavar, AbstractString)
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
            new_opt = bra_pre * opt_str1 * opt_str2 * bra_post
            push!(opt_lst, new_opt)
        end
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
        if !settings.commands_are_required
            bra_pre = "["
            bra_post = "]"
        else
            bra_pre = "{"
            bra_post = "}"
        end
        cmdl_str = " " * bra_pre * join(cmd_lst, "|") * bra_post
    end

    usage_len = length(usage_pre) + 1

    str_nonwrapped = usage_pre * optl_str * posl_str * cmdl_str
    str_wrapped = wrap(str_nonwrapped, break_long_words = false, break_on_hyphens = false,
                                       subsequent_indent = min(usage_len, lc_len_limit))


    out_str = replace(str_wrapped, nbspc => ' ')
    return out_str
end

string_compact(x...) = (io = IOBuffer(); show(IOContext(io, :compact=>true), x...); String(take!(io)))

function gen_help_text(arg::ArgParseField, settings::ArgParseSettings)
    is_flag(arg) && return arg.help

    pre = isempty(arg.help) ? "" : " "
    type_str = ""
    default_str = ""
    const_str = ""
    if !is_command_action(arg.action)
        if arg.arg_type != Any && !(arg.arg_type <: AbstractString)
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
    end
    post = (isempty(type_str) && isempty(default_str) && isempty(const_str)) ? "" : ")"
    return arg.help * type_str * default_str * const_str * post
end

function print_group(io::IO, lst::Vector, desc::AbstractString, lc_usable_len::Int, lc_len::Int,
                     lmargin::AbstractString, rmargin::AbstractString, sindent::AbstractString)
    isempty(lst) && return
    println(io, desc, ":")
    for l in lst
        l1len = length(l[1])
        if l1len ≤ lc_usable_len
            rfill = " "^(lc_len - l1len)
            ll_nonwrapped = l[1] * rfill * rmargin * l[2]
            ll_wrapped = wrap(ll_nonwrapped, break_long_words = false, break_on_hyphens = false,
                              initial_indent = lmargin, subsequent_indent = sindent)
            println_unnbsp(io, ll_wrapped)
        else
            println_unnbsp(io, lmargin, l[1])
            l2_wrapped = wrap(l[2], break_long_words = false, break_on_hyphens = false,
                                    initial_indent = sindent, subsequent_indent = sindent)
            println_unnbsp(io, l2_wrapped)
        end
    end
    println(io)
end

show_help(settings::ArgParseSettings; kw...) = show_help(stdout, settings; kw...)

function show_help(io::IO, settings::ArgParseSettings; exit_when_done = true)

    lc_len_limit = 24
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
            opt_str1 = join([["-"*x for x in f.short_opt_name]; ["--"*x for x in f.long_opt_name]], ", ")
            if is_flag(f)
                opt_str2 = ""
            else
                if isa(f.nargs.desc, Int)
                    if isa(f.metavar, AbstractString)
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
    show_message(io, settings.description, settings.preformatted_description)

    for ag in settings.args_groups
        print_group(io, group_lists[ag.name], ag.desc, lc_usable_len, lc_len,
                    lmargin, rmargin, sindent)
    end

    show_message(io, settings.epilog, settings.preformatted_epilog)
    exit_when_done && exit(0)
    return
end

function show_message(io::IO, message::AbstractString, preformatted::Bool)
    if !isempty(message)
        if preformatted
            print(io, message)
        else
            for l in split(message, "\n\n")
                message_wrapped = wrap(l, break_long_words = false, break_on_hyphens = false)
                println_unnbsp(io, message_wrapped)
            end
        end
        println(io)
    end
end

show_version(settings::ArgParseSettings; kw...) = show_version(stdout, settings; kw...)

function show_version(io::IO, settings::ArgParseSettings; exit_when_done = true)
    println(io, settings.version)
    exit_when_done && exit(0)
    return
end

function has_cmd(settings::ArgParseSettings)
    for a in settings.args_table.fields
        is_cmd(a) && return true
    end
    return false
end
#}}}

# parse_args & friends
#{{{
function default_handler(settings::ArgParseSettings, err, err_code::Int = 1)
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
[`ArgParseSettings`](@ref) object, and returns a `Dict{String,Any}`. If `args` is not provided,
the global variable `ARGS` will be used.

When the keyword argument `as_symbols` is `true`, the function will return a `Dict{Symbol,Any}` instead.

The returned `Dict` keys are defined (possibly implicitly) in `settings`, and their associated values are parsed
from `args`. Special keys are used for more advanced purposes; at the moment, one such key exists: `%COMMAND%`
(`_COMMAND_` when using `as_symbols=true`; see the [Commands](@ref) section).

Arguments are parsed in sequence and matched against the argument table in `settings` to determine whether they are
long options, short options, option arguments or positional arguments:

  * long options begin with a double dash `"--"`; if a `'='` character is found, the remainder is the option argument;
    therefore, `["--opt=arg"]` and `["--opt", "arg"]` are equivalent if `--opt` takes at least one argument.
    Long options can be abbreviated (e.g. `--opt` instead of `--option`) as long as there is no ambiguity.
  * short options begin with a single dash `"-"` and their name consists of a single character; they can be grouped
    together (e.g. `["-x", "-y"]` can become `["-xy"]`), but in that case only the last option in the group can
    take an argument (which can also be grouped, e.g. `["-a", "-f", "file.txt"]` can be passed as
    `["-affile.txt"]` if `-a` does not take an argument and `-f` does). The `'='` character can be used to
    separate option names from option arguments as well (e.g. `-af=file.txt`).
  * positional arguments are anything else; they can appear anywhere.

The special string `"--"` can be used to signal the end of all options; after that, everything is considered as a
positional argument (e.g. if `args = ["--opt1", "--", "--opt2"]`, the parser will recognize `--opt1` as a long
option without argument, and `--opt2` as a positional argument).

The special string `"-"` is always parsed as a positional argument.

The parsing can stop early if a `:show_help` or `:show_version` action is triggered, or if a parsing error is
found.

Some ambiguities can arise in parsing, see the [Parsing details](@ref) section for a detailed description
of how they're solved.
"""
function parse_args(args_list::Vector, settings::ArgParseSettings; as_symbols::Bool = false)
    as_symbols && check_settings_can_use_symbols(settings)
    local parsed_args
    try
        parsed_args = parse_args_unhandled(args_list, settings)
    catch err
        isa(err, ArgParseError) || rethrow()
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
    out_dict::Dict{String,Any}
    function ParserState(args_list::Vector, settings::ArgParseSettings, truncated_shopts::Bool)
        out_dict = Dict{String,Any}()
        for f in settings.args_table.fields
            (f.action == :show_help || f.action == :show_version) && continue
            out_dict[f.dest_name] = deepcopy(f.default)
        end
        new(deepcopy(args_list), false, nothing, nothing, false, 0, Set{AbstractString}(), nothing, truncated_shopts, false, out_dict)
    end
end

found_command(state::ParserState) = state.command ≢ nothing
function parse_command_args(state::ParserState, settings::ArgParseSettings)
    cmd = state.command
    haskey(settings, cmd) || argparse_error("unknown command: $cmd")
    #state.out_dict[cmd] = parse_args(state.args_list, settings[cmd])
    try
        state.out_dict[cmd] = parse_args_unhandled(state.args_list, settings[cmd], state.truncated_shopts)
    catch err
        isa(err, ArgParseError) || rethrow(err)
        settings[cmd].exc_handler(settings[cmd], err)
    finally
        state.truncated_shopts = false
    end
    return state.out_dict[cmd]
end

function preparse(c::Channel, state::ParserState, settings::ArgParseSettings)
    args_list = state.args_list
    while !isempty(args_list)
        state.arg_delim_found && (put!(c, :pos_arg); continue)
        arg = args_list[1]
        if state.truncated_shopts
            @assert arg[1] == '-'
            looks_like_an_option(arg, settings) || argparse_error("illegal short options sequence after command: $arg")
            state.truncated_shopts = false
        end
        if arg == "--"
            state.arg_delim_found = true
            state.token = nothing
            state.token_arg = nothing
            popfirst!(args_list)
            continue
        elseif startswith(arg, "--")
            eq = something(findfirst(isequal('='), arg), 0)
            if eq ≠ 0
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

function parse_args_unhandled(args_list::Vector, settings::ArgParseSettings, truncated_shopts::Bool=false)
    any(x->!isa(x,AbstractString), args_list) && error("malformed args_list")
    if !isempty(settings.fromfile_prefix_chars)
        args_list = read_args_from_files(args_list, settings.fromfile_prefix_chars)
    end

    version_added = false
    help_added = false

    if settings.add_version
        settings.add_version = false
        add_arg_field(settings, "--version",
            action = :show_version,
            help = "show version information and exit",
            group = ""
            )
        version_added = true
    end
    if settings.add_help
        settings.add_help = false
        add_arg_field(settings, ["--help", "-h"],
            action = :show_help,
            help = "show this help message and exit",
            group = ""
            )
        help_added = true
    end

    state = ParserState(args_list, settings, truncated_shopts)
    preparser = Channel(c->preparse(c, state, settings))

    try
        for tag in preparser
            if tag == :long_option
                parse_long_opt(state, settings)
            elseif tag == :short_option_list
                parse_short_opt(state, settings)
            elseif tag == :pos_arg
                parse_arg(state, settings)
            else
                found_a_bug()
            end
            state.abort && return nothing
            found_command(state) && break
        end
        test_required_args(settings, state.found_args)
        if found_command(state)
            cmd_dict = parse_command_args(state, settings)
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
#{{{
function parse1_flag(state::ParserState, settings::ArgParseSettings, f::ArgParseField, has_arg::Bool, opt_name::AbstractString)
    has_arg && argparse_error("option $opt_name takes no arguments")
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

function parse1_optarg(state::ParserState, settings::ArgParseSettings, f::ArgParseField, rest, name::AbstractString)
    args_list = state.args_list
    arg_delim_found = state.arg_delim_found
    out_dict = state.out_dict

    arg_consumed = false
    parse_function = f.eval_arg ? parse_item_eval : parse_item_wrapper
    command = nothing
    is_multi_nargs(f.nargs) && (opt_arg = Array{f.arg_type}(undef, 0))
    if isa(f.nargs.desc, Int)
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
            if isempty(args_list)
                argparse_error("option $name requires an argument")
            end
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
            argparse_error("option $name requires at least one (not-looking-like-an-option) argument")
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
        out_dict[f.dest_name] = opt_arg
        command = opt_arg
    else
        found_a_bug()
    end
    state.arg_consumed = arg_consumed
    state.command = command
    return
end
#}}}

# parse long opts
#{{{
function parse_long_opt(state::ParserState, settings::ArgParseSettings)
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
        parse1_flag(state, settings, f, arg_after_eq ≢ nothing, "--"*opt_name)
    else
        parse1_optarg(state, settings, f, arg_after_eq, "--"*opt_name)
        push!(state.found_args, idstring(f))
    end
    return
end
#}}}

if VERSION < v"0.7.0-DEV.5126" # TODO: remove after 0.6 support is dropped
    # very crude hack to avoid deprecation warning
    const iterate = next
end

# parse short opts
#{{{
function parse_short_opt(state::ParserState, settings::ArgParseSettings)
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
        for f_ in settings.args_table.fields
            found |= any(sn->sn==opt_name, f_.short_opt_name)
            found && (f = f_; break) # TODO: use outer keyword instead of f_ when 0.6 support is dropped)
        end
        found || argparse_error("unrecognized option -$opt_name")
        if is_flag(f)
            parse1_flag(state, settings, f, next_is_eq, "-"*opt_name)
        else
            parse1_optarg(state, settings, f, rest_as_arg, "-"*opt_name)
            push!(state.found_args, idstring(f))
        end
        state.arg_consumed && break
        if found_command(state)
            if rest_as_arg ≢ nothing && !isempty(rest_as_arg)
                startswith(rest_as_arg, '-') && argparse_error("illegal short options sequence after command $(state.command): $rest_as_arg")
                pushfirst!(state.args_list, "-" * rest_as_arg)
                state.truncated_shopts = true
            end
            return
        end
        sind = next_sind
    end
end
#}}}

# parse arg
#{{{
function parse_arg(state::ParserState, settings::ArgParseSettings)
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

    parse1_optarg(state, settings, f, nothing, f.dest_name)

    push!(state.found_args, idstring(f))
    return
end
#}}}

# convert_to_symbols
#{{{
convert_to_symbols(::Nothing) = nothing
function convert_to_symbols(parsed_args::Dict{String,Any})
    new_parsed_args = Dict{Symbol,Any}()
    cmd = nothing
    if haskey(parsed_args, cmd_dest_name)
        cmd = parsed_args[cmd_dest_name]
        scmd = Symbol(cmd)
        new_parsed_args[scmd] = convert_to_symbols(parsed_args[cmd])
        new_parsed_args[scmd_dest_name] = scmd
    end
    for (k,v) in parsed_args
        (k == cmd_dest_name || k == cmd) && continue
        new_parsed_args[Symbol(k)] = v
    end
    return new_parsed_args
end
#}}}
#}}}

end # module ArgParse
