## All types, functions and constants related to the specification of the arguments

# actions
const all_actions = [:store_arg, :store_true, :store_false, :store_const,
                     :append_arg, :append_const, :count_invocations,
                     :command, :show_help, :show_version]

const internal_actions = [:store_arg, :store_true, :store_false, :store_const,
                          :append_arg, :append_const, :count_invocations,
                          :command_arg, :command_flag,
                          :show_help, :show_version]

const nonflag_actions = [:store_arg, :append_arg, :command_arg]
is_flag_action(a::Symbol) = a ∉ nonflag_actions

const multi_actions = [:append_arg, :append_const]
is_multi_action(a::Symbol) = a ∈ multi_actions

const command_actions = [:command_arg, :command_flag]
is_command_action(a::Symbol) = a ∈ command_actions

# ArgConsumerType
struct ArgConsumerType
    desc::Union{Int,Symbol}
    function ArgConsumerType(n::Integer)
        n ≥ 0 || throw(ArgumentError("nargs can't be negative"))
        new(n)
    end
    function ArgConsumerType(s::Symbol)
        s ∈ [:A, :?, :*, :+, :R] ||
            throw(ArgumentError("nargs must be an integer or one of 'A', '?', '*', '+', 'R'"))
        new(s)
    end
end
ArgConsumerType(c::Char) = ArgConsumerType(Symbol(c))
ArgConsumerType() = ArgConsumerType(:A)

function show(io::IO, nargs::ArgConsumerType)
    print(io, nargs.desc isa Int ? nargs.desc : "'" * string(nargs.desc) * "'")
end

is_multi_nargs(nargs::ArgConsumerType) = nargs.desc ∉ (0, :A, :?)

default_action(nargs::Integer) = nargs == 0 ? :store_true : :store_arg
default_action(nargs::Char) = :store_arg
default_action(nargs::Symbol) = :store_arg

default_action(nargs::ArgConsumerType) = default_action(nargs.desc)

# ArgParseGroup
mutable struct ArgParseGroup
    name::AbstractString
    desc::AbstractString
    exclusive::Bool
    required::Bool
    function ArgParseGroup(name::AbstractString,
                  desc::AbstractString,
                  exclusive::Bool = false,
                  required::Bool = false
                 )
        new(name, desc, exclusive, required)
    end
end

const cmd_group = ArgParseGroup("commands", "commands")
const pos_group = ArgParseGroup("positional", "positional arguments")
const opt_group = ArgParseGroup("optional", "optional arguments")

const std_groups = [cmd_group, pos_group, opt_group]

# ArgParseField
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
    metavar::Union{AbstractString,Vector{<:AbstractString}}
    cmd_aliases::Vector{AbstractString}
    group::AbstractString
    fake::Bool
    ArgParseField() = new("", AbstractString[], AbstractString[], Any, :store_true,
                          ArgConsumerType(), nothing, nothing, _->true, false, false, "", "",
                          AbstractString[], "", false)
end

is_flag(arg::ArgParseField) = is_flag_action(arg.action)

is_arg(arg::ArgParseField) = isempty(arg.long_opt_name) && isempty(arg.short_opt_name)

is_cmd(arg::ArgParseField) = is_command_action(arg.action)

const cmd_dest_name = "%COMMAND%"
const scmd_dest_name = :_COMMAND_

function show(io::IO, s::ArgParseField)
    println(io, "ArgParseField(")
    for f in fieldnames(ArgParseField)
        println(io, "  ", f, "=", getfield(s, f))
    end
    print(io, "  )")
end

# ArgParseTable
mutable struct ArgParseTable
    fields::Vector{ArgParseField}
    subsettings::Dict{AbstractString,Any} # will actually be a Dict{AbstractString,ArgParseSettings}
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
"""
    ArgParseSettings

The `ArgParseSettings` object contains all the settings to be used during argument parsing. Settings
are divided in two groups: general settings and argument-table-related settings.
While the argument table requires specialized functions such as [`@add_arg_table!`](@ref) to be
defined and manipulated, general settings are simply object fields (most of them are `Bool` or
`String`) and can be passed to the constructor as keyword arguments, or directly set at any time.

This is the list of general settings currently available:

* `prog` (default = `""`): the name of the program, as displayed in the auto-generated help and
  usage screens. If left empty, the source file name will be used.
* `description` (default = `""`): a description of what the program does, to be displayed in the
  auto-generated help-screen, between the usage lines and the arguments description. If
  `preformatted_description` is `false` (see below), it will be automatically formatted, but you can
  still force newlines by using two consecutive newlines in the string, and manually control spaces
  by using non-breakable spaces (the character `'\\ua0'`).
* `preformatted_description` (default = `false`): disable automatic formatting of `description`.
* `epilog` (default = `""`): like `description`, but will be displayed at the end of the
  help-screen, after the arguments description. The same formatting rules also apply.
* `preformatted_epilog` (default = `false`): disable automatic formatting of `epilog`.
* `usage` (default = `""`): the usage line(s) to be displayed in the help screen and when an error
  is found during parsing. If left empty, it will be auto-generated.
* `version` (default = `"Unknown version"`): version information. It's used by the `:show_version`
  action.
* `add_help` (default = `true`): if `true`, a `--help, -h` option (triggering the `:show_help`
  action) is added to the argument table.
* `add_version` (default = `false`): if `true`, a `--version` option (triggering the `:show_version`
  action) is added to the argument table.
* `fromfile_prefix_chars` (default = `Set{Char}()`): an argument beginning with one of these
  characters will specify a file from which arguments will be read, one argument read per line.
  Alphanumeric characters and the hyphen-minus (`'-'`) are prohibited.
* `autofix_names` (default = `false`): if `true`, will try to automatically fix the uses of dashes
  (`'-'`) and underscores (`'_'`) in option names and destinations: all underscores will be
  converted to dashes in long option names; also, associated destination names, if auto-generated
  (see the [Argument names](@ref) section), will have dashes replaced with underscores, both for
  long options and for positional arguments. For example, an option declared as `"--my-opt"` will be
  associated with the key `"my_opt"` by default. It is especially advisable to turn this option on
  then parsing with the `as_symbols=true` argument to `parse_args`.
* `error_on_conflict` (default = `true`): if `true`, throw an error in case conflicting entries are
  added to the argument table; if `false`, later entries will silently take precedence. See the
  [Conflicts and overrides](@ref) srction for a detailed description of what conflicts are and what
  is the exact behavior when this setting is `false`.
* `suppress_warnings` (default = `false`): if `true`, all warnings will be suppressed.
* `allow_ambiguous_opts` (default = `false`): if `true`, ambiguous options such as `-1` will be
  accepted.
* `commands_are_required` (default = `true`): if `true`, commands will be mandatory. See the
  [Commands](@ref) section.
* `exc_handler` (default = `ArgParse.default_handler`): this is a function which is invoked when an
  error is detected during parsing (e.g. an option is not recognized, a required argument is not
  passed etc.). It takes two arguments: the `settings::ArgParseSettings` object and the
  `err::ArgParseError` exception. The default handler behaves differently depending on whether it's
  invoked from a script or in an interactive environment (e.g. REPL/IJulia). In non-interactive
  (script) mode, it calls `ArgParse.cmdline_handler`, which prints the error text and the usage
  screen on standard error and exits Julia with error code 1:
* `ignore_unrecognized_opts` (default = `false`): if `true`, unrecognized options will be skipped.
  `ignore_unrecognized_opts=true` cannot be used when there are any positional arguments, because it
  is potentially ambiguous whether values after the unrecoginized option are supposed to be handled
  by the option or by the positional argument.

  ```julia
  function cmdline_handler(settings::ArgParseSettings, err, err_code::Int = 1)
      println(stderr, err.text)
      println(stderr, usage_string(settings))
      exit(err_code)
  end
  ```

  In interactive mode instead it calls the function `ArgParse.debug_handler`, which just rethrows
  the error.
* `exit_after_help` (default = `!isinteractive()`): exit Julia (with error code `0`) when the
  `:show_help` or `:show_version` actions are triggered. If `false`, those actions will just stop
  the parsing and make `parse_args` return `nothing`.

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

As a shorthand, the `description` field can be passed without keyword, which makes this equivalent
to the above:

```julia
settings = ArgParseSettings("This program does something",
                            commands_are_required = false,
                            version = "1.0",
                            add_version = true)
```

Most settings won't take effect until `parse_args` is invoked, but a few will have immediate
effects: `autofix_names`, `error_on_conflict`, `suppress_warnings`, `allow_ambiguous_opts`.
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
    ignore_unrecognized_opts::Bool

    function ArgParseSettings(;prog::AbstractString = Base.source_path() ≢ nothing ?
                                                          basename(Base.source_path()) :
                                                          "",
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
                               exit_after_help::Bool = !isinteractive(),
                               ignore_unrecognized_opts::Bool = false
                               )
        fromfile_prefix_chars = check_prefix_chars(fromfile_prefix_chars)
        return new(
            prog, description, epilog, usage, version, add_help, add_version,
            fromfile_prefix_chars, autofix_names, error_on_conflict,
            suppress_warnings, allow_ambiguous_opts, commands_are_required,
            copy(std_groups), "", ArgParseTable(), exc_handler,
            preformatted_description, preformatted_epilog,
            exit_after_help, ignore_unrecognized_opts
            )
    end
end

ArgParseSettings(desc::AbstractString; kw...) = ArgParseSettings(; description = desc, kw...)

function show(io::IO, s::ArgParseSettings)
    println(io, "ArgParseSettings(")
    for f in fieldnames(ArgParseSettings)
        f ∈ (:args_groups, :args_table) && continue
        println(io, "  ", f, "=", getfield(s, f))
    end
    println(io, "  >> ", usage_string(s))
    print(io, "  )")
end

ArgName{T<:AbstractString} = Union{T, Vector{T}}

getindex(s::ArgParseSettings, c::AbstractString) = s.args_table.subsettings[c]
haskey(s::ArgParseSettings, c::AbstractString) = haskey(s.args_table.subsettings, c)
setindex!(s::ArgParseSettings, x::ArgParseSettings, c::AbstractString) =
    setindex!(s.args_table.subsettings, x, c)

# fields declarations sanity checks
function check_name_format(name::ArgName)
    isempty(name) && error("empty name")
    name isa Vector || return true
    allopts = true
    allargs = true
    for n in name
        isempty(n) && error("empty name")
        if startswith(n, '-')
            allargs = false
        else
            allopts = false
        end
    end
    !(allargs || allopts) && error("multiple names must be either all options or all non-options")
    for i1 = 1:length(name), i2 = i1+1:length(name)
        name[i1] == name[i2] && error("duplicate name $(name[i1])")
    end
    return true
end

function check_type(opt, T::Type, message::AbstractString)
    opt isa T || error(message)
    return true
end

function check_eltype(opt, T::Type, message::AbstractString)
    eltype(opt) <: T || error(message)
    return true
end

function warn_extra_opts(opts, valid_keys::Vector{Symbol})
    for k in opts
        k ∈ valid_keys || @warn "ignored option: $k"
    end
    return true
end

function check_action_is_valid(action::Symbol)
    action ∈ all_actions || error("invalid action: $action")
end

function check_nargs_and_action(nargs::ArgConsumerType, action::Symbol)
    is_flag_action(action) && nargs.desc ≠ 0 && nargs.desc ≠ :A &&
        error("incompatible nargs and action (flag-action $action, nargs=$nargs)")
    is_command_action(action) && nargs.desc ≠ :A &&
        error("incompatible nargs and action (command action, nargs=$nargs)")
    !is_flag_action(action) && nargs.desc == 0 &&
        error("incompatible nargs and action (non-flag-action $action, nargs=$nargs)")
    return true
end

function check_ignore_unrecognized_opts(settings::ArgParseSettings, is_opt::Bool)
    !is_opt && settings.ignore_unrecognized_opts &&
        error("cannot use ignore_unrecognized_opts=true with positional arguments")
    return true
end

function check_long_opt_name(name::AbstractString, settings::ArgParseSettings)
    '=' ∈ name            && error("illegal option name: $name (contains '=')")
    occursin(r"\s", name) && error("illegal option name: $name (contains whitespace)")
    settings.add_help     &&
        name == "help"    && error("option --help is reserved in the current settings")
    settings.add_version  &&
        name == "version" && error("option --version is reserved in the current settings")
    return true
end

function check_short_opt_name(name::AbstractString, settings::ArgParseSettings)
    length(name) ≠ 1      && error("short options must use a single character")
    name == "="           && error("illegal short option name: $name")
    occursin(r"\s", name) && error("illegal option name: $name (contains whitespace)")
    !settings.allow_ambiguous_opts && occursin(r"[0-9.(]", name) &&
                             error("ambiguous option name: $name (disabled in current settings)")
    settings.add_help && name == "h" &&
                             error("option -h is reserved for help in the current settings")
    return true
end

function check_arg_name(name::AbstractString)
    occursin(r"^%[A-Z]*%$", name) && error("invalid positional arg name: $name (is reserved)")
    return true
end

function check_cmd_name(name::AbstractString)
    isempty(name) && found_a_bug()
    startswith(name, '-') && found_a_bug()
    occursin(r"\s", name) && error("invalid command name: $name (contains whitespace)")
    occursin(r"^%[A-Z]*%$", name) && error("invalid command name: $name (is reserved)")
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

    for f in settings.args_table.fields
        is_arg(f) || continue
        is_command_action(f.action) && error("non-command $(idstring(arg)) can't follow commands")
        !f.required && arg.required &&
            error("required $(idstring(arg)) can't follow non-required arguments")
    end
    return true
end

function check_conflicts_with_commands(settings::ArgParseSettings,
                                       new_arg::ArgParseField,
                                       allow_future_merge::Bool)
    for cmd in keys(settings.args_table.subsettings)
        cmd == new_arg.dest_name &&
            error("$(idstring(new_arg)) has the same destination of a command: $cmd")
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
        elseif is_cmd(a) && is_cmd(new_arg)
            if a.constant == new_arg.constant
                allow_future_merge || error("command $(a.constant) already in use")
                is_arg(a) ≠ is_arg(new_arg) &&
                    error("$(idstring(a)) and $(idstring(new_arg)) are incompatible")
            else
                for al in new_arg.cmd_aliases
                    al == a.constant && error("invalid alias $al, command already in use")
                end
            end
        end
    end
    return true
end

function check_conflicts_with_commands(settings::ArgParseSettings, new_cmd::AbstractString)
    for a in settings.args_table.fields
        new_cmd == a.dest_name &&
            error("command $new_cmd has the same destination of $(idstring(a))")
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
        if is_cmd(a) && is_cmd(new_arg)
            for al1 in a.cmd_aliases, al2 in new_arg.cmd_aliases
                al1 == al2 && error("both commands $(a.constant) and $(new_arg.constant) use the " *
                                    "same alias $al1")
            end
            for al1 in a.cmd_aliases
                al1 == new_arg.constant && error("$al1 already in use as an alias command " *
                                                 "$(a.constant)")
            end
            for al2 in new_arg.cmd_aliases
                al2 == a.constant && error("invalid alias $al2, command already in use")
            end
        end
        if a.dest_name == new_arg.dest_name
            a.arg_type == new_arg.arg_type ||
                error("$(idstring(a)) and $(idstring(new_arg)) have the same destination " *
                      "but different arg types")
            if (is_multi_action(a.action) && !is_multi_action(new_arg.action)) ||
               (!is_multi_action(a.action) && is_multi_action(new_arg.action))
                error("$(idstring(a)) and $(idstring(new_arg)) have the same destination " *
                      "but incompatible actions")
            end
        end
    end
    return true
end

check_default_type(default::Nothing, arg_type::Type) = true
function check_default_type(default::D, arg_type::Type) where D
    D <: arg_type || error("typeof(default)=$D is incompatible with arg_type=$arg_type)")
    return true
end

check_default_type_multi_action(default::Nothing, arg_type::Type) = true
function check_default_type_multi_action(default::Vector{D}, arg_type::Type) where D
    arg_type <: D || error("typeof(default)=Vector{$D} can't hold arguments " *
                           "of type arg_type=$arg_type)")
    all(x->(x isa arg_type), default) || error("all elements of the default value " *
                                               "must be of type $arg_type)")
    return true
end
check_default_type_multi_action(default::D, arg_type::Type) where D =
    error("typeof(default)=$D is incompatible with the action, it should be a Vector")

check_default_type_multi_nargs(default::Nothing, arg_type::Type) = true
function check_default_type_multi_nargs(default::Vector, arg_type::Type)
    all(x->(x isa arg_type), default) || error("all elements of the default value " *
                                               "must be of type $arg_type")
    return true
end
check_default_type_multi_nargs(default::D, arg_type::Type) where D =
    error("typeof(default)=$D is incompatible with nargs, it should be a Vector")

check_default_type_multi2(default::Nothing, arg_type::Type) = true
function check_default_type_multi2(default::Vector{D}, arg_type::Type) where D
    Vector{arg_type} <: D || error("typeof(default)=Vector{$D} can't hold Vectors of arguments " *
                                   "of type arg_type=$arg_type)")
    all(y->(y isa Vector), default) ||
        error("the default $(default) is incompatible with the action and nargs, " *
              "it should be a Vector of Vectors")
    all(y->all(x->(x isa arg_type), y), default) || error("all elements of the default value " *
                                                          "must be of type $arg_type")
    return true
end
check_default_type_multi2(default::D, arg_type::Type) where D =
    error("the default $(default) is incompatible with the action and nargs, " *
          "it should be a Vector of Vectors")

check_range_default(default::Nothing, range_tester::Function) = true
function check_range_default(default, range_tester::Function)
    local res::Bool
    try
        res = range_tester(default)
    catch err
        error("the range_tester function must be defined for the default value, and return a Bool")
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
            error("the range_tester function must be defined for all the default values, " *
                  "and return a Bool")
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
            error("the range_tester function must be defined for all the default values, " *
                  "and return a Bool")
        end
        res || error("all of the default values must pass the range_tester function")
    end
    return true
end

function check_metavar(metavar::AbstractString)
    isempty(metavar)         && error("empty metavar")
    startswith(metavar, '-') && error("metavars cannot begin with -")
    occursin(r"\s", metavar) && error("illegal metavar name: $metavar (contains whitespace)")
    return true
end

function check_metavar(metavar::Vector{<:AbstractString})
    foreach(check_metavar, metavar)
    return true
end

function check_group_name(name::AbstractString)
    isempty(name)         && error("empty group name")
    startswith(name, '#') && error("invalid group name (starts with #)")
    return true
end

# add_arg_table! and related
function name_to_fieldnames!(settings::ArgParseSettings, name::ArgName)
    pos_arg = ""
    long_opts = AbstractString[]
    short_opts = AbstractString[]
    aliases = AbstractString[]
    r(n) = settings.autofix_names ? replace(n, '_' => '-') : n
    function do_one(n, cmd_check = true)
        if startswith(n, "--")
            n == "--" && error("illegal option name: --")
            long_opt_name = r(n[3:end])
            check_long_opt_name(long_opt_name, settings)
            push!(long_opts, long_opt_name)
        elseif startswith(n, '-')
            n == "-" && error("illegal option name: -")
            short_opt_name = n[2:end]
            check_short_opt_name(short_opt_name, settings)
            push!(short_opts, short_opt_name)
        else
            if cmd_check
                check_cmd_name(n)
            else
                check_arg_name(n)
            end
            if isempty(pos_arg)
                pos_arg = n
            else
                push!(aliases, n)
            end
        end
    end

    if name isa Vector
        foreach(do_one, name)
    else
        do_one(name, false)
    end
    return pos_arg, long_opts, short_opts, aliases
end

function auto_dest_name(pos_arg::AbstractString,
                        long_opts::Vector{AbstractString},
                        short_opts::Vector{AbstractString},
                        autofix_names::Bool)
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
    add_arg_table!(settings, [arg_name [,arg_options]]...)

This function is very similar to the macro version [`@add_arg_table!`](@ref). Its syntax is stricter:
tuples and blocks are not allowed and argument options are explicitly specified as `Dict` objects.
However, since it doesn't involve macros, it offers more flexibility in other respects, e.g. the
`arg_name` entries need not be explicit, they can be anything which evaluates to a `String` or a
`Vector{String}`.

Example:

```julia
add_arg_table!(settings,
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
function add_arg_table!(settings::ArgParseSettings, table::Union{ArgName,Vector,Dict}...)
    has_name = false
    for i = 1:length(table)
        !has_name && !(table[i] isa ArgName) &&
            error("option field must be preceded by the arg name")
        has_name = true
    end
    i = 1
    while i ≤ length(table)
        if i+1 ≤ length(table) && !(table[i+1] isa ArgName)
            add_arg_field!(settings, table[i]; table[i+1]...)
            i += 2
        else
            add_arg_field!(settings, table[i])
            i += 1
        end
    end
    return settings
end

"""
    @add_arg_table!(settings, table...)

This macro adds a table of arguments and options to the given `settings`. It can be invoked multiple
times. The arguments groups are determined automatically, or the current default group is used if
specified (see the [Argument groups](@ref) section for more details).

The `table` is a list in which each element can be either `String`, or a tuple or a vector of
`String`, or an assigmment expression, or a block:

* a `String`, a tuple or a vector introduces a new positional argument or option. Tuples and vectors
  are only allowed for options or commands, and provide alternative names (e.g. `["--opt", "-o"]` or
  `["checkout", "co"]`)
* assignment expressions (i.e. expressions using `=`, `:=` or `=>`) describe the previous argument
  behavior (e.g.  `help = "an option"` or `required => false`).  See the
  [Argument entry settings](@ref) section for a complete description
* blocks (`begin...end` or lists of expressions in parentheses separated by semicolons) are useful
  to group entries and span multiple lines.

These rules allow for a variety usage styles, which are discussed in the
[Argument table styles](@ref) section. In the rest of the documentation, we will mostly use this
style:

```julia
@add_arg_table! settings begin
    "--opt1", "-o"
        help = "an option with an argument"
    "--opt2"
    "arg1"
        help = "a positional argument"
        required = true
end
```

In the above example, the `table` is put in a single `begin...end` block and the line
`"--opt1", "-o"` is parsed as a tuple; indentation is used to help readability.

See also the function [`add_arg_table!`](@ref).
"""
macro add_arg_table!(s, x...)
    _add_arg_table!(s, x...)
end

# Moved all the code to a function just to make the deprecation work
function _add_arg_table!(s, x...)
    # transform the tuple into a vector, so that
    # we can manipulate it
    x = Any[x...]
    # escape the ArgParseSettings
    s = esc(s)
    z = esc(gensym())
    # start building the return expression
    exret = quote
        $z = $s
        $z isa ArgParseSettings ||
            error("first argument to @add_arg_table! must be of type ArgParseSettings")
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
        elseif (y isa AbstractString) || Meta.isexpr(y, (:vect, :tuple))
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
                # then, call add_arg_field!
                aaf = Expr(:call, :add_arg_field!, kopts, z, name)
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
            name ≢ nothing ||
                error("malformed table: description fields must be preceded by the arg name")
            push!(exopt, Expr(:call, :(=>), Expr(:quote, y.args[1]), esc(y.args[2])))
            i += 1
        elseif Meta.isexpr(y, :call) && y.args[1] == :(=>)
            # found an assignment: add it to the current options expression
            name ≢ nothing ||
                error("malformed table: description fields must be preceded by the arg name")
            push!(exopt, Expr(:call, :(=>), Expr(:quote, y.args[2]), esc(y.args[3])))
            i += 1
        elseif (y isa LineNumberNode) || Meta.isexpr(y, :line)
            # a line number node, ignore
            i += 1
            continue
        else
            # anything else: ignore, but issue a warning
            @warn "@add_arg_table!: ignoring expression $y"
            i += 1
        end
    end
    if name ≢ nothing
        # there is an arg field on hold
        # same as above
        opt = Expr(:call, exopt...)
        kopts = Expr(:parameters, Expr(:(...), opt))
        aaf = Expr(:call, :add_arg_field!, kopts, z, name)
        exret = quote
            $exret
            $aaf
        end
    end

    # the return value when invoking the macro
    # will be the ArgParseSettings object
    exret = quote
        $exret
        $z
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
        error("group $group not found, use add_arg_group! to add it")
    end
    found_a_bug()
end

function add_arg_field!(settings::ArgParseSettings, name::ArgName; desc...)
    check_name_format(name)

    supplied_opts = keys(desc)

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
    metavar_error = "metavar must be an AbstractString or a Vector{<:AbstractString}"
    if !(metavar isa AbstractString)
        check_type(metavar, Vector, metavar_error)
        check_eltype(metavar, AbstractString, metavar_error)
        check_type(nargs, Integer, "nargs must be an integer for multiple metavars")
        length(metavar) == nargs || error("metavar array must have length of nargs")
    end
    check_type(force_override, Bool, "force_override must be a Bool")
    check_type(group, Union{AbstractString,Symbol}, "group must be an AbstractString or a Symbol")

    nargs isa ArgConsumerType || (nargs = ArgConsumerType(nargs))
    action isa Symbol || (action = Symbol(action))

    is_opt = name isa Vector ?
        startswith(first(name), '-') :
        startswith(name, '-')

    check_action_is_valid(action)

    action == :command && (action = is_opt ? :command_flag : :command_arg)

    check_nargs_and_action(nargs, action)

    check_ignore_unrecognized_opts(settings, is_opt)

    new_arg = ArgParseField()

    is_flag = is_flag_action(action)

    if !is_opt
        is_flag && error("invalid action for positional argument: $action")
        nargs.desc == :? && error("invalid 'nargs' for positional argument: '?'")
        metavar isa Vector && error("multiple metavars only supported for optional arguments")
    end

    pos_arg, long_opts, short_opts, cmd_aliases = name_to_fieldnames!(settings, name)

    if !isempty(cmd_aliases)
        is_command_action(action) || error("only command arguments can have multiple names (aliases)")
    end

    new_arg.dest_name = auto_dest_name(pos_arg, long_opts, short_opts, settings.autofix_names)

    new_arg.long_opt_name = long_opts
    new_arg.short_opt_name = short_opts
    new_arg.cmd_aliases = cmd_aliases
    new_arg.nargs = nargs
    new_arg.action = action

    group = string(group)
    if :group ∈ supplied_opts && !isempty(group)
        check_group_name(group)
    end
    arg_group = get_group(group, new_arg, settings)
    new_arg.group = arg_group.name
    if arg_group.exclusive && (!is_opt || is_command_action(action))
        error("group $(new_arg.group) is mutually-exclusive, actions and commands are not allowed")
    end

    if action ∈ (:store_const, :append_const) && :constant ∉ supplied_opts
        error("action $action requires the 'constant' field")
    end

    valid_keys = [:nargs, :action, :help, :force_override, :group]
    if is_flag
        if action ∈ (:store_const, :append_const)
            append!(valid_keys, [:default, :constant, :arg_type, :dest_name])
        elseif action ∈ (:store_true, :store_false, :count_invocations, :command_flag)
            push!(valid_keys, :dest_name)
        else
            action ∈ (:show_help, :show_version) || found_a_bug()
        end
    elseif is_opt
        append!(valid_keys,
                [:arg_type, :default, :range_tester, :dest_name, :required, :metavar, :eval_arg])
        nargs.desc == :? && push!(valid_keys, :constant)
    elseif action ≠ :command_arg
        append!(valid_keys, [:arg_type, :default, :range_tester, :required, :metavar])
    end
    settings.suppress_warnings || warn_extra_opts(supplied_opts, valid_keys)

    if is_command_action(action)
        if (:dest_name ∈ supplied_opts) && (:dest_name ∈ valid_keys)
            cmd_name = dest_name
        else
            cmd_name = new_arg.dest_name
        end
    end
    if (:dest_name ∈ supplied_opts) && (:dest_name ∈ valid_keys) && (action ≠ :command_flag)
        new_arg.dest_name = dest_name
    end

    check_dest_name(dest_name)

    set_if_valid(k, x) = k ∈ valid_keys && setfield!(new_arg, k, x)

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
        elseif action ∈ (:store_const, :append_const)
            if :arg_type ∈ supplied_opts
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
        if (is_multi_action(new_arg.action) && is_multi_nargs(new_arg.nargs)) &&
                (default ≡ nothing || default == [])
            new_arg.default = Array{Vector{arg_type}}(undef, 0)
        elseif (is_multi_action(new_arg.action) || is_multi_nargs(new_arg.nargs)) &&
                (default ≡ nothing || default == [])
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
        override_duplicates!(settings.args_table.fields, new_arg)
    else
        check_for_duplicates(settings.args_table.fields, new_arg)
    end
    push!(settings.args_table.fields, new_arg)
    is_command_action(action) && add_command!(settings, cmd_name, cmd_prog_hint, force_override)
    return
end

function add_command!(settings::ArgParseSettings,
                      command::AbstractString,
                      prog_hint::AbstractString,
                      force_override::Bool)
    haskey(settings, command) && error("command $command already added")
    if force_override
        override_conflicts_with_commands!(settings, command)
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

add_arg_group!(settings::ArgParseSettings, desc::AbstractString;
               exclusive::Bool = false, required::Bool = false) =
    _add_arg_group!(settings, desc, autogen_group_name(desc), true, exclusive, required)


"""
    add_arg_group!(settings, description, [name , [set_as_default]]; keywords...)

This function adds an argument group to the argument table in `settings`. The `description` is a
`String` used in the help screen as a title for that group. The `name` is a unique name which can be
provided to refer to that group at a later time.

Groups can be declared to be mutually exclusive and/or required, see below.

After invoking this function, all subsequent invocations of the [`@add_arg_table!`](@ref) macro and
[`add_arg_table!`](@ref) function will use the new group as the default, unless `set_as_default` is
set to `false` (the default is `true`, and the option can only be set if providing a `name`).
Therefore, the most obvious usage pattern is: for each group, add it and populate the argument
table of that group. Example:

```julia-repl
julia> settings = ArgParseSettings();

julia> add_arg_group!(settings, "custom group");

julia> @add_arg_table! settings begin
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

The `name` can also be passed as a `Symbol`. Forbidden names are the standard groups names
(`"command"`, `"positional"` and `"optional"`) and those beginning with a hash character `'#'`.

In order to declare a group as mutually exclusive, use the keyword `exclusive = true`. Mutually
exclusive groups can only contain options, not arguments nor commands, and parsing will fail if more
than one option from the group is provided.

A group can be declared as required using the `required = true` keyword, in which case at least one
option or positional argument or command from the group must be provided.
"""
function add_arg_group!(settings::ArgParseSettings,
                        desc::AbstractString,
                        tag::Union{AbstractString,Symbol},
                        set_as_default::Bool = true;
                        exclusive::Bool = false,
                        required::Bool = false
                       )
    name = string(tag)
    check_group_name(name)
    _add_arg_group!(settings, desc, name, set_as_default, exclusive, required)
end

function _add_arg_group!(settings::ArgParseSettings,
                         desc::AbstractString,
                         name::AbstractString,
                         set_as_default::Bool,
                         exclusive::Bool,
                         required::Bool
                        )
    already_added = any(ag->ag.name==name, settings.args_groups)
    already_added || push!(settings.args_groups, ArgParseGroup(name, desc, exclusive, required))
    set_as_default && (settings.default_group = name)
    return settings
end

"""
    set_default_arg_group!(settings, [name])

Set the default group for subsequent invocations of the [`@add_arg_table!`](@ref) macro and
[`add_arg_table!`](@ref) function. `name` is a `String`, and must be one of the standard group names
(`"command"`, `"positional"` or `"optional"`) or one of the user-defined names given in
`add_arg_group!` (groups with no assigned name cannot be used with this function).

If `name` is not provided or is the empty string `""`, then the default behavior is reset (i.e.
arguments will be automatically assigned to the standard groups). The `name` can also be passed as a
`Symbol`.
"""
function set_default_arg_group!(settings::ArgParseSettings, name::Union{AbstractString,Symbol} = "")
    name = string(name)
    startswith(name, '#') && error("invalid group name: $name (begins with #)")
    isempty(name) && (settings.default_group = ""; return)
    found = any(ag->ag.name==name, settings.args_groups)
    found || error("group $name not found")
    settings.default_group = name
    return
end

# import_settings! & friends
function override_conflicts_with_commands!(settings::ArgParseSettings, new_cmd::AbstractString)
    ids0 = Int[]
    for ia in 1:length(settings.args_table.fields)
        a = settings.args_table.fields[ia]
        new_cmd == a.dest_name && push!(ids0, ia)
    end
    while !isempty(ids0)
        splice!(settings.args_table.fields, pop!(ids0))
    end
end
function override_duplicates!(args::Vector{ArgParseField}, new_arg::ArgParseField)
    ids0 = Int[]
    for (ia,a) in enumerate(args)
        if (a.dest_name == new_arg.dest_name) &&
            ((a.arg_type ≠ new_arg.arg_type) ||
             (is_multi_action(a.action) && !is_multi_action(new_arg.action)) ||
             (!is_multi_action(a.action) && is_multi_action(new_arg.action)))
            # unsolvable conflict, mark for deletion
            push!(ids0, ia)
            continue
        end
        if is_arg(a) && is_arg(new_arg) && !(is_cmd(a) && is_cmd(new_arg)) &&
            a.metavar == new_arg.metavar
            # unsolvable conflict, mark for deletion
            push!(ids0, ia)
            continue
        end

        # delete conflicting command aliases for different commands
        if is_cmd(a) && is_cmd(new_arg) && a.constant ≠ new_arg.constant
            ids = Int[]
            for (ial1, al1) in enumerate(a.cmd_aliases)
                if al1 == new_arg.constant
                    push!(ids, ial1)
                else
                    for al2 in new_arg.cmd_aliases
                        al1 == al2 && push!(ids, ial1)
                    end
                end
            end
            while !isempty(ids)
                splice!(a.cmd_aliases, pop!(ids))
            end
        end

        if is_arg(a) || is_arg(new_arg)
            # not an option, skip
            continue
        end

        if is_cmd(a) && is_cmd(new_arg) && a.constant == new_arg.constant && !is_arg(a)
            is_arg(new_arg) && found_a_bug() # this is ensured by check_settings_are_compatible
            # two command flags with the same command -> should have already been taken care of,
            # by either check_settings_are_compatible or merge_commands!
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

function merge_commands!(fields::Vector{ArgParseField}, ofields::Vector{ArgParseField})
    oids = Int[]
    for a in fields, ioa = 1:length(ofields)
        oa = ofields[ioa]
        if is_cmd(a) && is_cmd(oa) && a.constant == oa.constant
            is_arg(a) ≠ is_arg(oa) && found_a_bug() # ensured by check_settings_are_compatible
            for l in oa.long_opt_name
                l ∈ a.long_opt_name || push!(a.long_opt_name, l)
            end
            for s in oa.short_opt_name
                s ∈ a.short_opt_name || push!(a.short_opt_name, s)
            end
            for al in oa.cmd_aliases
                al ∈ a.cmd_aliases || push!(a.cmd_aliases, al)
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

function fix_commands_fields!(fields::Vector{ArgParseField})
    cmd_found = false
    for a in fields
        if is_arg(a) && is_cmd(a)
            a.fake = cmd_found
            cmd_found = true
        end
    end
end

"""
    import_settings!(settings, other_settings [,args_only])

Imports `other_settings` into `settings`, where both are [`ArgParseSettings`](@ref) objects. If
`args_only` is `true` (this is the default), only the argument table will be imported; otherwise,
the default argument group will also be imported, and all general settings except `prog`,
`description`, `epilog`, `usage` and `version`.

Sub-settings associated with commands will also be imported recursively; the `args_only` setting
applies to those as well. If there are common commands, their sub-settings will be merged.

While importing, conflicts may arise: if `settings.error_on_conflict` is `true`, this will result in
an error, otherwise conflicts will be resolved in favor of `other_settings` (see the
[Conflicts and overrides](@ref) section for a detailed discussion of how conflicts are handled).

Argument groups will also be imported; if two groups in `settings` and `other_settings` match, they
are merged (groups match either by name, or, if unnamed, by their description).

Note that the import will have effect immediately: any subsequent modification of `other_settings`
will not have any effect on `settings`.

This function can be used at any time.
"""
function import_settings!(settings::ArgParseSettings,
                          other::ArgParseSettings;
                          args_only::Bool = true)
    check_settings_are_compatible(settings, other)

    fields = settings.args_table.fields
    ofields = deepcopy(other.args_table.fields)
    merged_oids = merge_commands!(fields, ofields)
    if !settings.error_on_conflict
        for a in ofields
            override_duplicates!(fields, a)
        end
        for (subk, subs) in other.args_table.subsettings
            override_conflicts_with_commands!(settings, subk)
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

    fix_commands_fields!(fields)

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
            add_command!(settings, subk, cmd_prog_hint, !settings.error_on_conflict)
        elseif !isempty(cmd_prog_hint)
            settings[subk].prog = "$(settings.prog) $cmd_prog_hint"
        end
        import_settings!(settings[subk], subs, args_only=args_only)
    end
    return settings
end

"""
    @project_version
    @project_version(filename::String...)

Reads the version from the Project.toml file at the given filename, at compile time.
If no filename is given, defaults to `Base.current_project()`.
If multiple strings are given, they will be joined with `joinpath`.
Intended for use with the [`ArgParseSettings`](@ref) constructor,
to keep the settings version in sync with the project version.

## Example

```julia
ArgParseSettings(add_version = true, version = @project_version)
```
"""
macro project_version(filename::Vararg{String})
    project_version(isempty(filename) ? Base.current_project() : joinpath(filename...))
end

function project_version(filename::AbstractString)::String
    re = r"^version\s*=\s*\"(.*)\"\s*$"
    for line in eachline(filename)
        if startswith(line, "[")
            break
        end
        if !occursin(re, line)
            continue
        end
        return match(re, line)[1]
    end
    throw(ArgumentError("Could not find a version in the file at $(filename)"))
end
