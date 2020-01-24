
@deprecate add_arg_table add_arg_table!
@deprecate import_settings(settings, other) import_settings!(settings, other)
@deprecate import_settings(settings, other, ao) import_settings!(settings, other; args_only=ao)
@deprecate add_arg_group(args...; kw...) add_arg_group!(args...; kw...)
@deprecate set_default_arg_group set_default_arg_group!

# The Base.@deprecate macro doesn't work with macros
# Here's an attempt at mimicking most of what that does
# and deprecate @add_arg_table -> @add_arg_table!
using Base: JLOptions, CoreLogging
using Logging: @logmsg

function callframe(st, name)
    found = false
    for sf in st
        sf == StackTraces.UNKNOWN && continue
        if found && sf.func == Symbol("top-level scope")
            return sf
        end
        sf.func == name && (found = true)
    end
    return StackTraces.UNKNOWN
end

export @add_arg_table
macro add_arg_table(s, x...)
    opts = JLOptions()
    msg = "`@add_arg_table` is deprecated, use `@add_arg_table!` instead"
    opts.depwarn == 2 && throw(ErrorException(msg))
    deplevel = opts.depwarn == 1 ? CoreLogging.Warn : CoreLogging.BelowMinLevel
    st = stacktrace()
    caller = callframe(st, Symbol("@add_arg_table"))
    @logmsg(deplevel, msg,
            _file = String(caller.file),
            _line = caller.line,
            _group = :depwarn,
            maxlog = 1)

    return _add_arg_table!(s, x...)
end
