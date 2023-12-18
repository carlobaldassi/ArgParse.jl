using ArgParse
using Test

macro ap_test_throws(args)
    :(@test_throws ArgParseError $(esc(args)))
end

macro aps_test_throws(args)
    :(@test_throws ArgParseSettingsError $(esc(args)))
end

macro noout_test(args)
    quote
        mktemp() do _,io
            redirect_stdout(io) do
                @test $(esc(args))
            end
        end
    end
end

macro test_addtable_failure(ex...)
    ex = [nothing, ex...]
    ex = Expr(:call, :macroexpand, @__MODULE__, Expr(:quote, Expr(:macrocall, Symbol("@add_arg_table!"), ex...)))
    err = @static VERSION ≥ v"1.7.0-DEV.937" ? ArgParseSettingsError : LoadError
    quote
        @test_throws $err $ex
    end
end

macro tostring(ex)
    @assert ex.head == :call
    f = esc(ex.args[1])
    a = map(esc, ex.args[2:end])
    newcall = Expr(:call, f, :io, a...)
    quote
        io = IOBuffer()
        $newcall
        String(take!(io))
    end
end

stringhelp(s::ArgParseSettings) = @tostring ArgParse.show_help(s, exit_when_done = false)
stringversion(s::ArgParseSettings) = @tostring ArgParse.show_version(s, exit_when_done = false)
