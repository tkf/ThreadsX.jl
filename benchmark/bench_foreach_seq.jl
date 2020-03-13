module BenchForeachSeq

using BenchmarkTools
using ThreadsX.Implementations: foreach_cartesian_seq

const floatsink = Ref(0.0)
@inline consume(x) = floatsink[] = ifelse(x == 0, x, floatsink[])

n = 1000
v = ones(n * n)
m = ones(n, n)
suite = BenchmarkGroup()

for (label, _foreach) in [("base", foreach), ("tx", foreach_cartesian_seq)]
    s = suite[label] = BenchmarkGroup()
    s["Vector"] = @benchmarkable($_foreach(consume, $v))
    s["Matrix"] = @benchmarkable($_foreach(consume, $m))
    s["Transpose"] = @benchmarkable($_foreach(consume, transpose($m)))
end

end  # module
BenchForeachSeq.suite
