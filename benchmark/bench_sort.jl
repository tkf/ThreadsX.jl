module BenchSort

using BenchmarkTools
using Random: Random, shuffle
using ThreadsX

Random.seed!(1234)

n = 10_000
datasets = [
    # (label, setup)
    ("random", shuffle(1:n)),
    ("sorted", [1:n;]),
]

# modeling slow comparison:
function slow_identity(a)
    x = Float64(a)
    for _ in 1:1
        x = sin(x)
    end
    return a
end

suite = BenchmarkGroup()

for (label, xs) in datasets
    suite[label] = BenchmarkGroup()
    for by in [identity, slow_identity]
        s = suite[label][string(by)] = BenchmarkGroup()
        s["tx"] = @benchmarkable(ThreadsX.sort!(xs; by = $by), setup = (xs = copy($xs)))
        s["base"] = @benchmarkable(sort!(xs; by = $by), setup = (xs = copy($xs)))
    end
end

end  # module
BenchSort.suite
