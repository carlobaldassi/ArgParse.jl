"""
    ArgParse

This module allows the creation of user-friendly command-line interfaces to Julia programs:
the program defines which arguments, options and sub-commands it accepts, and the `ArgParse` module
does the actual parsing, issues errors when the input is invalid, and automatically generates help
and usage messages.

Users familiar with Python's `argparse` module will find many similarities, but some important
differences as well.
"""
module ArgParse

import TextWrap, Markdown

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@compiler_options"))
    @eval Base.Experimental.@compiler_options compile=min optimize=0 infer=false
end

export
# types
    ArgParseSettings,
    ArgParseSettingsError,
    ArgParseError,

# functions & macros
    add_arg_table!,
    @add_arg_table!,
    add_arg_group!,
    set_default_arg_group!,
    import_settings!,
    usage_string,
    parse_args,
    @project_version

import Base: show, getindex, setindex!, haskey

@nospecialize # use only declared type signatures, helps with compile time

include("common.jl")
include("settings.jl")
include("parsing.jl")
include("deprecated.jl")

end # module ArgParse
