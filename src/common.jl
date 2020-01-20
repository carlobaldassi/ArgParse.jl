## Some common functions, constants, macros

# auxiliary functions/constants
found_a_bug() = error("you just found a bug in the ArgParse module, please report it.")
const nbspc = '\u00a0'
const nbsps = "$nbspc"
println_unnbsp(io::IO, args...) = println(io, map(s->replace(s, nbspc => ' '), args)...)

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
        $used = Dict{Symbol,Bool}(k => false for (k,v) in $opts)
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
        elseif (y isa LineNumberNode) || Meta.isexpr(y, :line)
            # A line number node, ignore
            i += 1
            continue
        elseif Meta.isexpr(y, :call) && y.args[1] == :(=>)
            y = Expr(:(=), y.args[2:end]...)
        elseif !Meta.isexpr(y, (:(=), :(:=), :kw))
            error("Arguments to @defaults following the options variable must be assignments, " *
                  "e.g., a=5 or a=>5")
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

