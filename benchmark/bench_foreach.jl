module BenchForeach

import ThreadsX
using BenchmarkTools
using Referenceables: referenceable

@inline function f(a, b, c)
    a[] = b + c
end

n = 2000
B = randn(n, n)
C = randn(n, n)
A = similar(B)
suite = BenchmarkGroup()

for (label, _foreach) in [("base", foreach), ("tx", ThreadsX.foreach)]
    s = suite[label] = BenchmarkGroup()
    s["A .= B .+ C"] = @benchmarkable($_foreach(f, referenceable($A), $B, $C))
    s["A .= B .+ B'"] = @benchmarkable($_foreach(f, referenceable($A), $B, $B'))
end

let s = suite["broadcast"] = BenchmarkGroup()
    s["A .= B .+ C"] = @benchmarkable $A .= $B .+ $C
    s["A .= B .+ B'"] = @benchmarkable $A .= $B .+ $B'
end

end  # module
BenchForeach.suite
