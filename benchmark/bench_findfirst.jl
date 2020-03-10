module BenchFindfirst

import Random
using BenchmarkTools
using ThreadsX

Random.seed!(1234)

n = 2^18

suite = BenchmarkGroup()

xs0 = rand(n)
for percent in [0, 10, 20, 30, 40, 50]
    xs = copy(xs0)
    xs[max(1, floor(Int, length(xs) * percent / 100))] = -1
    s = suite["$(percent)%"] = BenchmarkGroup()
    s["tx"] = @benchmarkable(ThreadsX.findfirst(==(-1), $xs))
    s["tx-seq"] = @benchmarkable(ThreadsX.findfirst(==(-1), $xs, basesize = typemax(Int)))
    s["base"] = @benchmarkable(findfirst(==(-1), $xs))
end

end  # module
BenchFindfirst.suite
