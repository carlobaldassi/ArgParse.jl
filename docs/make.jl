using Documenter, ArgParse

CIbuild = get(ENV, "CI", nothing) == "true"

makedocs(
    modules  = [ArgParse],
    format   = Documenter.HTML(prettyurls = CIbuild),
    sitename = "ArgParse.jl",
    pages    = Any[
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
