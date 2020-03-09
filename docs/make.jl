using Documenter, ThreadsX

makedocs(;
    modules=[ThreadsX],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tkf/ThreadsX.jl/blob/{commit}{path}#L{line}",
    sitename="ThreadsX.jl",
    authors="Takafumi Arakaki <aka.tkf@gmail.com>",
)

deploydocs(;
    repo="github.com/tkf/ThreadsX.jl",
    push_preview=true,
)
