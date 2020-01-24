# ArgParse.jl documentation

```@meta
CurrentModule = ArgParse
```

This [Julia](http://julialang.org) package allows the creation of user-friendly command-line interfaces
to Julia programs: the program defines which arguments, options and sub-commands it accepts, and the
`ArgParse` module does the actual parsing, issues errors when the input is invalid, and automatically
generates help and usage messages.

Users familiar with Python's `argparse` module will find many similarities, but some important differences
as well.

## Installation

To install the module, use Julia's package manager: start pkg mode by pressing `]` and then enter:

```
(v1.3) pkg> add ArgParse
```

Dependencies will be installed automatically.

## Quick overview and a simple example

First of all, the module needs to be loaded:

```julia
using ArgParse
```

There are two main steps for defining a command-line interface: creating an [`ArgParseSettings`](@ref) object, and
populating it with allowed arguments and options using either the macro [`@add_arg_table!`](@ref) or the
function [`add_arg_table!`](@ref) (see the [Argument table](@ref) section):

```
s = ArgParseSettings()
@add_arg_table! s begin
    "--opt1"
        help = "an option with an argument"
    "--opt2", "-o"
        help = "another option with an argument"
        arg_type = Int
        default = 0
    "--flag1"
        help = "an option without argument, i.e. a flag"
        action = :store_true
    "arg1"
        help = "a positional argument"
        required = true
end
```

In the macro, options and positional arguments are specified within a `begin...end` block, by one or more names
in a line, optionally followed by a list of settings.
So, in the above example, there are three options:

* the first one, `"--opt1"` takes an argument, but doesn't check for its type, and it doesn't have a default value
* the second one can be invoked in two different forms (`"--opt2"` and `"-o"`); it also takes an argument, but
  it must be of `Int` type (or convertible to it) and its default value is `0`
* the third one, `--flag1`, is a flag, i.e. it doesn't take any argument.

There is also only one positional argument, `"arg1"`, which is declared as mandatory.

When the settings are in place, the actual argument parsing is performed via the [`parse_args`](@ref) function:

```julia
parsed_args = parse_args(ARGS, s)
```

The parameter `ARGS` can be omitted. In case no errors are found, the result will be a `Dict{String,Any}` object.
In the above example, it will contain the keys `"opt1"`, `"opt2"`, `"flag1"` and `"arg1"`, so that e.g.
`parsed_args["arg1"]` will yield the value associated with the positional argument.

(The `parse_args` function also accepts an optional `as_symbols` keyword argument: when set to `true`, the
result of the parsing will be a `Dict{Symbol,Any}`, which can be useful e.g. for passing it as the keywords to a Julia
function.)

Putting all this together in a file, we can see how a basic command-line interface is created:

```julia
using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--opt1"
            help = "an option with an argument"
        "--opt2", "-o"
            help = "another option with an argument"
            arg_type = Int
            default = 0
        "--flag1"
            help = "an option without argument, i.e. a flag"
            action = :store_true
        "arg1"
            help = "a positional argument"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    println("Parsed args:")
    for (arg,val) in parsed_args
        println("  $arg  =>  $val")
    end
end

main()
```

If we save this as a file called `myprog1.jl`, we can see how a `--help` option is added by default,
and a help message is automatically generated and formatted:

```text
$ julia myprog1.jl --help
usage: myprog1.jl [--opt1 OPT1] [-o OPT2] [--flag1] [-h] arg1

positional arguments:
  arg1             a positional argument

optional arguments:
  --opt1 OPT1      an option with an argument
  -o, --opt2 OPT2  another option with an argument (type: Int64,
                   default: 0)
  --flag1          an option without argument, i.e. a flag
  -h, --help       show this help message and exit
```

Also, we can see how invoking it with the wrong arguments produces errors:

```text
$ julia myprog1.jl
required argument arg1 was not provided
usage: myprog1.jl [--opt1 OPT1] [-o OPT2] [--flag1] [-h] arg1

$ julia myprog1.jl somearg anotherarg
too many arguments
usage: myprog1.jl [--opt1 OPT1] [-o OPT2] [--flag1] [-h] arg1

$ julia myprog1.jl --opt2 1.5 somearg
invalid argument: 1.5 (conversion to type Int64 failed; you may need to overload ArgParse.parse_item;
                  the error was: ArgumentError("invalid base 10 digit '.' in \"1.5\""))
usage: myprog1.jl [--opt1 OPT1] [-o OPT2] [--flag1] arg1
```

When everything goes fine instead, our program will print the resulting `Dict`:

```text
$ julia myprog1.jl somearg
Parsed args:
  arg1  =>  somearg
  opt2  =>  0
  opt1  =>  nothing
  flag1  =>  false

$ julia myprog1.jl --opt1 "2+2" --opt2 "4" somearg --flag
Parsed args:
  arg1  =>  somearg
  opt2  =>  4
  opt1  =>  2+2
  flag1  =>  true
```

From these examples, a number of things can be noticed:

* `opt1` defaults to `nothing`, since no `default` setting was used for it in `@add_arg_table!`
* `opt1` argument type, begin unspecified, defaults to `Any`, but in practice it's parsed as a
  string (e.g. `"2+2"`)
* `opt2` instead has `Int` argument type, so `"4"` will be parsed and converted to an integer,
  an error is emitted if the conversion fails
* positional arguments can be passed in between options
* long options can be passed in abbreviated form (e.g. `--flag` instead of `--flag1`) as long as
  there's no ambiguity

More examples can be found in the `examples` directory, and the complete documentation in the
manual pages.

## Contents

```@contents
Pages = [
  "parse_args.md",
  "settings.md",
  "arg_table.md",
  "import.md",
  "conflicts.md",
  "custom.md",
  "details.md"
]
```
