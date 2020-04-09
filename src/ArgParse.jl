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

using TextWrap

export
# types
    ArgParseSettings,
    ArgParseError,

# functions & macros
    add_arg_table!,
    @add_arg_table!,
    add_arg_group!,
    set_default_arg_group!,
    import_settings!,
    usage_string,
    parse_args,
    @extract

import Base: show, getindex, setindex!, haskey

@nospecialize # use only declared type signatures, helps with compile time

include("common.jl")
include("settings.jl")
include("parsing.jl")
include("deprecated.jl")

"""
@extract(d, ks...)

Take the parsed args and bring all the keys in name space. If no keys are provided all are brought to namespace.

"""
macro extract(d)
    ks = keys(eval(d))
    ss = Symbol.(ks)
    quote
        data = $d
        ($(esc.(ss)...),) = ($([:(data[$k]) for k in ks]...),)
        nothing
    end
end

macro extract(d, ss...)
    ks = string.(ss)
    @assert all(k -> k ∈ keys(eval(d)), ks) "A key was not found in dictionary"
    quote
        data = $d
        ($(esc.(ss)...),) = ($([:(data[$k]) for k in ks]...),)
        nothing
    end
end

end # module ArgParse
