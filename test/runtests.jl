module ArgParseTests

include("common.jl")

for i = 1:7
    print("\rRunning argparse_test$i")
    try
        include("argparse_test$i.jl")
    catch err
        println()
        rethrow(err)
    end
end
println()

end
