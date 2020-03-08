module BenchSort

using BenchmarkTools
using Random: Random, shuffle
using ThreadsX

Random.seed!(1234)

n = 100_000
datasets = [
    # (label, setup)
    ("random", shuffle(1:n)),
    ("sorted", [1:n;]),
]

suite = BenchmarkGroup()

for (label, xs) in datasets
    suite[label] = BenchmarkGroup()
    s = suite[label]
    s["tx"] = @benchmarkable(ThreadsX.sort!(xs), setup = (xs = copy($xs)))
    s["base"] = @benchmarkable(sort!(xs), setup = (xs = copy($xs)))
end

end  # module
BenchSort.suite
