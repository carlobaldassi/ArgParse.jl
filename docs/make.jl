using Documenter, ArgParse

makedocs(
    modules  = [ArgParse],
    format   = :html,
    sitename = "ArgParse.jl",
    pages    = Any[
        "Home" => "index.md",
       ]
    )

deploydocs(
    repo   = "github.com/carlobaldassi/ArgParse.jl.git",
    target = "build",
    deps = nothing,
    make = nothing,
    julia  = "0.5"
)
