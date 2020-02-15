# Argument table

The argument table is used to store allowed arguments and options in an [`ArgParseSettings`](@ref) object.

Each entry of the table consist of an argument name and a list of argument settings, e.g.:

```julia
"--verbose"
    help = "verbose output"
    action = :store_true
```

There are two very similar methods to populate a table:

```@docs
@add_arg_table!
```

```@docs
add_arg_table!
```

## Argument names

Argument names are strings or, in the case of options, lists of strings. An argument is an option if it begins with a `'-'`
character, otherwise it'a positional argument. A single `'-'` introduces a short option, which must consist of a single
character; long options begin with `"--"` instead.

Positional argument names can be any string, except all-uppercase strings between `'%'` characters, which are reserved
(e.g. `"%COMMAND%"`).
Option names can contain any character except `'='`, whitespaces and non-breakable spaces.
Depending on the value of the `add_help` and `add_version` settings, options `--help`, `-h` and `--version` may
be reserved.
If the `allow_ambiguous_opts` setting is `false`, some characters are not allowed as short options: all digits, the dot,
the underscore and the opening parethesis (e.g. `-1`, `-.`, `-_`, `-(`).

For positional arguments, the argument name will be used as the key in the `Dict` object returned by the [`parse_args`](@ref)
function.  For options, it will be used to produce a default key in case a `dest_name` is not explicitly specified in the table
entry, using either the first long option name in the list or the first short option name if no long options are present.
For example:

| argument name                | default `dest_name`     |
|:-----------------------------|:------------------------|
| `"--long"`                   | `"long"`                |
| `"--long", "-s"`             | `"long"`                |
| `"-s", "--long1", "--long2"` | `"long1"`               |
| `"-s", "-x"`                 | `"s"`                   |

In case the `autofix_names` setting is `true` (it is `false` by default), dashes in the names of arguments and long options will be
converted to underscores: for example, `"--my-opt"` will yield `"my_opt"` as the default `dest_name`.

The argument name is also used to generate a default metavar in case `metavar` is not explicitly set in the table entry. The rules
are the same used to determine the default `dest_name`, but for options the result will be uppercased (e.g. `"--long"` will
become `LONG`). Note that this poses additional constraints on the positional argument names (e.g. whitespace is not allowed in
metavars).

## Argument entry settings

Argument entry settings determine all aspects of an argument's behavior. Some settings combinations are contradictory and will produce
an error (e.g. using both `action = :store_true` and `nargs = 1`, or using `action = :store_true` with a positional argument).
Also, some settings are only meaningful under some conditions (e.g. passing a `metavar` to a flag-like option does not make sense)
and will be ignored with a warning (unless the `suppress_warnings` general setting is `true`).

This is the list of all available settings:

* `nargs` (default = `'A'`): the number of extra command-line tokens parsed with the entry. See
  the section [Available actions and nargs values](@ref) for a complete desctiption.
* `action`: the action performed when the argument is parsed. It can be passed as a `String` or as a `Symbol` (e.g. both
  `:store_arg` and `"store_arg"` are accepted). The default action is `:store_arg` unless `nargs` is `0`, in which case the
  default is `:store_true`. See the section [Available actions and nargs values](@ref) for a list of all available actions and a
  detailed explanation.
* `arg_type` (default = `Any`): the type of the argument. Only makes sense with non-flag arguments. Only works out-of-the-box with
  string and number types, but see the section [Parsing to custom types](@ref) for details on how to make it work for general types
  (including user-defined ones).
* `default` (default = `nothing`): the default value if the option or positional argument is not parsed. Only makes sense with
  non-flag arguments, or when the action is `:store_const` or `:append_const`. Unless it's `nothing`, it must be consistent with
  `arg_type` and `range_tester`.
* `constant` (default = `nothing`): this value is used by the `:store_const` and `:append_const` actions, or when `nargs = '?'`
  and the option argument is not provided.
* `required` (default = `false`): determines if an argument is required (this setting is ignored by flags, which are always
  optional, and in general should be avoided for options if possible).
* `range_tester` (default = `x->true`): a function returning a `Bool` value which tests whether an argument is allowed (e.g.
  you could use `arg_type = Integer` and `range_tester = isodd` to allow only odd integer values)
* `dest_name` (default = auto-generated): the key which will be associated with the argument in the `Dict` object returned by
  `parse_args`. The auto-generation rules are explained in the [Argument names](@ref) section. Multiple arguments can share
  the same destination, provided their actions and types are compatible.
* `help` (default = `""`): the help string which will be shown in the auto-generated help screen. It's a `String` which will
  be automaticaly formatted; also, `arg_type` and `default` will be automatically appended to it if provided.
* `metavar` (default = auto-generated): a token which will be used in usage and help screens to describe the argument syntax. For
  positional arguments, it will also be used as an identifier in all other messages (e.g. in reporting errors), therefore it must
  be unique. For optional arguments, if `nargs > 1` then `metavar` can be a `Vector` of `String`s of length `nargs`. The
  auto-generations rules are explained in the [Argument names](@ref) section.
* `force_override`: if `true`, conflicts are ignored when adding this entry in the argument table (see also the
  [Conflicts and overrides](@ref) section). By default, it follows the general `error_on_conflict` settings.
* `group`: the option group to which the argument will be assigned to (see the [Argument groups](@ref) section). By default, the
  current default group is used if specified, otherwise the assignment is automatic.
* `eval_arg` (default: `false`): if `true`, the argument will be parsed as a Julia expression and evaluated, which means that
  for example `"2+2"` will yield the integer `4` rather than a string. Note that this is a security risk for outside-facing
  programs and should generally be avoided: overload `ArgParse.parse_item` instead (see the section [Parsing to custom types](@ref)).
  Only makes sense for non-flag arguments.

## Available actions and nargs values

The `nargs` and `action` argument entry settings are used together to determine how many tokens will be parsed from the command
line and what action will be performed on them.

The `nargs` setting can be a number or a character; the possible values are:

* `'A'`: automatic, i.e. inferred from the action (this is the default). In practice, it means `0` for options with flag actions
(see the actions categorization below, in this section) and `1` for options with non-flag actions (but it's different from
using an explicit `1` because the result is not stored in a `Vector`).
* `0`: this is the only possibility (besides `'A'`) for flag actions, and it means no extra tokens will be parsed from
  the command line. If `action` is not specified, setting `nargs` to `0` will make `action` default to `:store_true`.
* a positive integer number `N`: exactly `N` tokens will be parsed from the command-line, and the result stored into a `Vector`
  of length `N` (even for `N=1`).
* `'?'`: optional, i.e. a token will only be parsed if it does not look like an option (see the [Parsing details](@ref) section
  for a discussion of how exactly this is established), otherwise the `constant` argument entry setting will be used instead.
  This only makes sense with options.
* `'*'`: any number, i.e. all subsequent tokens are stored into a `Vector`, up until a token which looks like an option is
  encountered, or all tokens are consumed.
* `'+'`: like `'*'`, but at least one token is required.
* `'R'`: all remainder tokens, i.e. like `'*'` but it does not stop at options.

Actions can be categorized in many ways; one prominent distinction is flag vs. non-flag: some actions are for options which take no
argument (i.e. flags), all others (except `command`, which is special) are for other options and positional arguments:

* flag actions are only compatible with `nargs = 0` or `nargs = 'A'`
* non-flag actions are not compatible with `nargs = 0`.

In other words, all flags (takes no argument) are options (starts with a dash), but not all options (starts with a dash)
are flags (takes no argument).

This is the list of all available actions (in each example, suppose we defined `settings = ArgParseSettings()`):

* `store_arg` (non-flag): store the argument. This is the default unless `nargs` is `0`. Example:

  ```julia-repl
  julia> @add_arg_table!(settings, "arg", action => :store_arg);

  julia> parse_args(["x"], settings)
  Dict{String,Any} with 1 entry:
    "arg" => "x"
  ```

  The result is a vector if `nargs` is a non-zero number, or one of `'*'`, `'+'`, `'R'`:

  ```julia-repl
  julia> @add_arg_table!(settings, "arg", action => :store_arg, nargs => 2);

  julia> parse_args(["x", "y"], settings)
  Dict{String,Any} with 1 entry:
    "arg" => Any["x","y"]
  ```

* `store_true` (flag): store `true` if given, otherwise `false`. Example:

  ```julia-repl
  julia> @add_arg_table!(settings, "-v", action => :store_true);

  julia> parse_args([], settings)
  Dict{String,Any} with 1 entry:
    "v" => false

  julia> parse_args(["-v"], settings)
  Dict{String,Any} with 1 entry:
    "v" => true
  ```

* `store_false` (flag): store `false` if given, otherwise `true`. Example:

  ```julia-repl
  julia> @add_arg_table!(settings, "-v", action => :store_false);

  julia> parse_args([], settings)
  Dict{String,Any} with 1 entry:
    "v" => true

  julia> parse_args(["-v"], settings)
  Dict{String,Any} with 1 entry:
    "v" => false
  ```

* `store_const` (flag): store the value passed as `constant` in the entry settings if given, otherwise `default`.
  Example:

  ```julia-repl
  julia> @add_arg_table!(settings, "-v", action => :store_const,
                                         constant => 1,
                                         default => 0);

  julia> parse_args([], settings)
  Dict{String,Any} with 1 entry:
    "v" => 0

  julia> parse_args(["-v"], settings)
  Dict{String,Any} with 1 entry:
    "v" => 1
  ```

* `append_arg` (non-flag): append the argument to the result. Example:

  ```julia-repl
  julia> @add_arg_table!(settings, "-x", action => :append_arg);

  julia> parse_args(["-x", "1", "-x", "2"], settings)
  Dict{String,Any} with 1 entry:
    "x" => Any["1","2"]
  ```

  The result will be a `Vector{Vector}` if `nargs` is a non-zero number, or one of `'*'`, `'+'`, `'R'`:

  ```julia-repl
  julia> @add_arg_table!(settings, "-x", action => :append_arg, nargs => '*');

  julia> parse_args(["-x", "1", "2", "-x", "3"], settings)
  Dict{String,Any} with 1 entry:
    "x" => Array{Any,1}[Any["1","2"],Any["3"]]
  ```

* `append_const` (flag): append the value passed as `constant` in the entry settings. Example:

  ```julia-repl
  julia> @add_arg_table!(settings, "-x", action => :append_const, constant => 1);

  julia> parse_args(["-x", "-x", "-x"], settings)
  Dict{String,Any} with 1 entry:
    "x" => Any[1,1,1]
  ```

* `count_invocations` (flag): increase a counter; the final result will be the number of times the option was
  invoked. Example:

  ```julia-repl
  julia> @add_arg_table!(settings, "-x", action => :count_invocations);

  julia> parse_args(["-x", "-x", "-x"], settings)
  Dict{String,Any} with 1 entry:
    "x" => 3
  ```

* `show_help` (flag): show the help screen and exit. This is useful if the `add_help` general setting is
  `false`. Example:

  ```julia-repl
  julia> @add_arg_table!(settings, "-x", action => :show_help);

  julia> parse_args(["-x"], settings)
  usage: <PROGRAM> [-x]

  optional arguments:
    -x
  ```

* `show_version` (flag): show the version information and exit. This is useful if the `add_version` general
  setting is `false`. Example:

  ```julia-repl
  julia> settings.version = "1.0";

  julia> @add_arg_table!(settings, "-x", action => :show_version);

  julia> parse_args(["-v"], settings)
  1.0
  ```

* `command` (special): the argument or option is a command, i.e. it starts a sub-parsing session (see the
  [Commands](@ref) section).


## Commands

Commands are a special kind of arguments which introduce sub-parsing sessions as soon as they are encountered by `parse_args`
(and are therefore mutually exclusive).
The `ArgParse` module allows commands to look both as positional arguments or as options, with minor differences between the two.
Unlike actual positional arguments, commands that *look* like positional arguments can have extra names (aliases).

Commands are introduced by the `action = :command` setting in the argument table. Suppose we save the following script in
a file called `cmd_example.jl`:

```julia
using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "cmd1", "C"
            help = "first command"
            action = :command
        "cmd2", "K"
            help = "second command"
            action = :command
    end

    return parse_args(s)
end

parsed_args = parse_commandline()
println(parsed_args)
```

Invoking the script from the command line, we would get the following help screen:

```text
$ julia cmd_example.jl --help
usage: cmd_example.jl [-h] {cmd1|cmd2}

commands:
  cmd1        first command (aliases: C)
  cmd2        second command (aliases: K)

optional arguments:
  -h, --help  show this help message and exit
```

If commands are present in the argument table, `parse_args` will set the special key `"%COMMAND%"` in the returned `Dict` and
fill it with the invoked command (or `nothing` if no command was given):

```text
$ julia cmd_example.jl cmd1
Dict("%COMMAND%"=>"cmd1", "cmd1"=>Dict())
```

This is unless `parse_args` is invoked with `as_symbols=true`, in which case the special key becomes `:_COMMAND_`. (In that case,
no other argument is allowed to use `_COMMAND_` as its `dest_name`, or an error will be raised.)

Aliases are recognized when parsing, but the returned `Dict` will always use the command's name (the first entry in the
table):

```text
$ julia cmd_example.jl C
Dict("%COMMAND%"=>"cmd1", "cmd1"=>Dict())
```

Since commands introduce sub-parsing sessions, an additional key will be added for the called command (`"cmd1"` in this case) whose
associated value is another `Dict{String, Any}` containing the result of the sub-parsing (in the above case it's empty). In fact,
with the default settings, commands have their own help screens:

```text
$ julia cmd_example.jl cmd1 --help
usage: cmd_example.jl cmd1 [-h]

optional arguments:
  -h, --help  show this help message and exit
```

The argument settings and tables for commands can be accessed by using a dict-like notation, i.e. `settings["cmd1"]` is an
`ArgParseSettings` object specific to the `"cmd1"` command. Therefore, to populate a command sub-argument-table, simply
use `@add_arg_table!(settings["cmd1"], table...)` and similar.

These sub-settings are created when a command is added to the argument table, and by default they inherit their parent general
settings except for the `prog` setting (which is auto-generated, as can be seen in the above example) and the
`description`, `epilog` and `usage` settings (which are left empty).

Commands can also have sub-commands.

By default, if commands exist, they are required; this can be avoided by setting the `commands_are_required = false` general setting.

The only meaningful settings for commands in an argument entry besides `action` are `help`, `force_override`, `group` and
(for flags only) `dest_name`.

The only differences between positional-arguments-like and option-like commands are in the way they are parsed, and the fact
that options accept a `dest_name` setting.

Note that short-form option-like commands will be still be recognized in the middle of a short options group and trigger a sub-parsing
session: for example, if an option `-c` is associated to a command, then `-xch` will parse option `-x` according to the parent
settings, and option `-h` according to the command sub-settings.

## Argument groups

By default, the auto-generated help screen divides arguments into three groups: commands, positional arguments and optional
arguments, displayed in that order. Example:

```@setup args
using ArgParse
```

```@repl args
settings = ArgParseSettings();

@add_arg_table! settings begin
   "--opt"
   "arg"
     required = true
   "cmd1"
     action = :command
   "cmd2"
     action = :command
end;

parse_args(["--help"], settings)
```

It is possible to partition the arguments differently by defining and using customized argument groups.
Groups of options can also be declared to be mutually exclusive, meaning that no more than one of the
options in the group can be provided. A group can also be declared to be required, meaning that at least
one argument in the group needs to be provided.

```@docs
add_arg_group!
```

```@docs
set_default_arg_group!
```

Besides setting a default group with `add_arg_group!` and `set_default_group!`, it's also possible to assign individual arguments
to a group by using the `group` setting in the argument table entry, which follows the same rules as `set_default_group!`.

Note that if the `add_help` or `add_version` general settings are `true`, the `--help, -h` and `--version` options
will always be added to the `optional` group.

## Argument table styles

Here are some examples of styles for the [`@add_arg_table!`](@ref) marco and [`add_arg_table!`](@ref) function invocation:

```julia
@add_arg_table! settings begin
    "--opt", "-o"
        help = "an option"
    "arg"
        help = "a positional argument"
end

@add_arg_table!(settings
    , ["--opt", "-o"]
    ,    help => "an option"
    , "arg"
    ,    help => "a positional argument"
    )

@add_arg_table! settings begin
    (["--opt", "-o"]; help = an option)
    ("arg"; help = "a positional argument")
end

@add_arg_table!(settings,
    ["-opt", "-o"],
    begin
        help = "an option"
    end,
    "arg",
    begin
        help = "a positional argument"
    end)

add_arg_table!(settings,
    ["-opt", "-o"], Dict(:help => "an option"),
    "arg"         , Dict(:help => "a positional argument")
    )
```

One restriction is that groups introduced by `begin...end` blocks or semicolon-separated lists between parentheses
cannot introduce argument names unless the first item in the block is an argument name.
