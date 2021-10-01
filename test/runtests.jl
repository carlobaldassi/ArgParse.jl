module ArgParseTests

include("common.jl")

for i = 1:13
    try
        s_i = lpad(string(i), 2, "0")
        include("argparse_test$s_i.jl")
    catch err
        println()
        rethrow(err)
    end
end
println()

end
