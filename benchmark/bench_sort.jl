module BenchSort

using BenchmarkTools
using Random: Random, shuffle
using ThreadsX

Random.seed!(1234)

n = 100_000
datasets = [
    # (label, setup)
    ("I64 (wide)", rand(Int64, n)),
    ("I64 (narrow)", rand(0:9, n)),
    ("F64 (wide)", rand(Float64, n)),
    ("F64 (narrow)", rand(0:0.1:0.9, n)),
    ("sorted", [1:n;]),
    ("reversed", [reverse(1:n);]),
]

suite = BenchmarkGroup()

for (label, xs) in datasets
    s = suite[label] = BenchmarkGroup()
    for algname in [:MergeSort, :QuickSort, :StableQuickSort]
        alg = getproperty(ThreadsX, algname)
        s["ThreadsX.$algname"] =
            @benchmarkable(ThreadsX.sort!(xs; alg = $alg), setup = (xs = copy($xs)))
    end
    s["Base"] = @benchmarkable(sort!(xs), setup = (xs = copy($xs)))
end

end  # module
BenchSort.suite
