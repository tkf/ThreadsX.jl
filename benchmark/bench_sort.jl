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
    s = suite[label] = BenchmarkGroup()
    for algname in [:QuickSort, :StableQuickSort]
        alg = getproperty(ThreadsX, algname)
        s["ThreadsX.$algname"] =
            @benchmarkable(ThreadsX.sort!(xs; alg = $alg), setup = (xs = copy($xs)))
    end
    s["Base"] = @benchmarkable(sort!(xs), setup = (xs = copy($xs)))
end

end  # module
BenchSort.suite
