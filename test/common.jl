using ArgParse
using Base.Test

# backwards-compatible test_throws (works in julia 0.2)
macro test_throws_02(args...)
    if VERSION >= v"0.3-"
        :(@test_throws($(esc(args[1])), $(esc(args[2]))))
    else
        :(@test_throws($(esc(args[2]))))
    end
end

macro ap_test_throws(args)
    :(@test_throws_02 ArgParseError $(esc(args)))
end

macro tostring(ex)
    @assert ex.head == :call
    f = esc(ex.args[1])
    a = map(esc, ex.args[2:end])
    newcall = Expr(:call, f, :io, a...)
    quote
        io = IOBuffer()
        $newcall
        takebuf_string(io)
    end
end

stringhelp(s::ArgParseSettings) = @tostring ArgParse.show_help(s, exit_when_done = false)
stringversion(s::ArgParseSettings) = @tostring ArgParse.show_version(s, exit_when_done = false)
