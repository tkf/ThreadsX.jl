module BenchForeachSeq

using BenchmarkTools
using ThreadsX.Implementations: foreach_cartesian_seq

const floatsink = Ref(0.0)
@inline consume(x) = floatsink[] = x

n = 1000
v = ones(n * n)
m = ones(n, n)
suite = BenchmarkGroup()

for (label, _foreach) in [("base", foreach), ("tx", foreach_cartesian_seq)]
    s = suite[label] = BenchmarkGroup()
    s["Vector"] = @benchmarkable($_foreach(consume, $v), setup = (floatsink[] = 0.0),)
    s["Matrix"] = @benchmarkable($_foreach(consume, $m), setup = (floatsink[] = 0.0),)
    s["Transpose"] =
        @benchmarkable($_foreach(consume, transpose($m)), setup = (floatsink[] = 0.0),)
end

end  # module
BenchForeachSeq.suite
