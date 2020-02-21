module BenchUnique

using BenchmarkTools
using Random: shuffle
using ThreadsX

n = 10_000
datasets = [
    # (label, setup)
    ("rand(1:10, $n)", rand(1:10, n)),
    ("rand(1:1000, $n)", rand(1:1000, n)),
]

suite = BenchmarkGroup()

for (label, xs) in datasets
    s = suite[label] = BenchmarkGroup()
    s["tx"] = @benchmarkable(ThreadsX.unique($xs))
    s["base"] = @benchmarkable(unique($xs))
end

end  # module
BenchUnique.suite
