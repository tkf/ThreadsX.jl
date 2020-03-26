module BenchForeachSeq

using BenchmarkTools
using ThreadsX.Implementations: foreach_cartesian_seq

const floatsink = Ref(0.0)
@inline consume(x) = floatsink[] = ifelse(x == 0, x, floatsink[])

function foreachc(f::F, xs) where {F}
    foreach_cartesian_seq(f, xs, Val(false))
end

n = 1000
v = ones(n * n)
m = ones(n, n)
suite = BenchmarkGroup()

for (label, _foreach) in [("base", foreach), ("tx", foreachc)]
    s = suite[label] = BenchmarkGroup()
    s["Vector"] = @benchmarkable($_foreach(consume, $v))
    s["Matrix"] = @benchmarkable($_foreach(consume, $m))
    s["Transpose"] = @benchmarkable($_foreach(consume, transpose($m)))
end

end  # module
BenchForeachSeq.suite
