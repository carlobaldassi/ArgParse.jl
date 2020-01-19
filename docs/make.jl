using Documenter, ArgParse

makedocs(
    modules  = [ArgParse],
    format = Documenter.HTML(prettyurls = "--local" ∉ ARGS),
    sitename = "ArgParse.jl",
    pages    = [
        "Home" => "index.md",
        "Manual" => [
            "parse_args.md",
            "settings.md",
            "arg_table.md",
            "import.md",
            "conflicts.md",
            "custom.md",
            "details.md"
        ]
    ]
)

deploydocs(
    repo   = "github.com/carlobaldassi/ArgParse.jl.git",
)
