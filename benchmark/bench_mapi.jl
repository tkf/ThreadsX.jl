module BenchMapi

using BenchmarkTools
using ThreadsX

collatz(x) =
    if iseven(x)
        x ÷ 2
    else
        3x + 1
    end

function collatz_stopping_time(x)
    n = 0
    while true
        x == 1 && return n
        n += 1
        x = collatz(x)
    end
end

function consume(ns)
    t0 = time_ns()
    d = 0
    while d < ns
        d = Int(time_ns() - t0)
    end
    return d
end

constant(x) = _ -> x

const SUITE = BenchmarkGroup()

let s0 = SUITE["collatz"] = BenchmarkGroup()
    s0["base"] = @benchmarkable map(collatz_stopping_time, 1:1000_000)
    s0["tx"] =
        @benchmarkable ThreadsX.mapi(collatz_stopping_time, 1:1000_000; basesize = 12500)
end

let s0 = SUITE["consume-1ms"] = BenchmarkGroup()
    s0["base"] = @benchmarkable map(consume ∘ constant(1_000_000), 1:20)
    s0["tx"] = @benchmarkable ThreadsX.mapi(consume ∘ constant(1_000_000), 1:20)
end

let s0 = SUITE["consume-100us"] = BenchmarkGroup()
    s0["base"] = @benchmarkable map(consume ∘ constant(100_000), 1:20)
    s0["tx"] = @benchmarkable ThreadsX.mapi(consume ∘ constant(100_000), 1:20)
end

end  # module
BenchMapi.SUITE
