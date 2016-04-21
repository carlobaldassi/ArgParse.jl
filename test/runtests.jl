module ArgParseTests

include("common.jl")

for i = 1:8
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
