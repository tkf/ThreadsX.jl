module BenchForeachSeqDouble

using BenchmarkTools
using Referenceables
using ThreadsX

@inline function manual_double!(ys)
    @simd ivdep for i in eachindex(ys)
        @inbounds ys[i] *= 2
    end
end

@inline function manual_nested_double!(ys::AbstractMatrix)
    for j in axes(ys, 2)
        @simd ivdep for i in axes(ys, 1)
            @inbounds ys[i, j] *= 2
        end
    end
end

double!(y) = y[] *= 2

suite = BenchmarkGroup()

let s0 = suite["linear"] = BenchmarkGroup()
    ys = randn(2^10)
    s0["man"] = @benchmarkable manual_double!(ys) setup = (ys = copy($ys))
    s1 = s0["tx"] = BenchmarkGroup()
    for simd in [false, true, :ivdep]
        s1[:simd=>simd] = @benchmarkable(
            ThreadsX.Implementations.foreach_linear_seq(
                double!,
                referenceable(ys),
                $(Val(simd)),
            ),
            setup = (ys = copy($ys)),
        )
    end
end

let s0 = suite["cartesian"] = BenchmarkGroup()
    # `size(ys, 1)` seems to be large enough to make this benchmark
    # somewhat stable
    ys = randn(2^8, 2^5)
    s0["man"] = @benchmarkable manual_nested_double!(ys') setup = (ys = copy($ys))
    s1 = s0["tx"] = BenchmarkGroup()
    for simd in [false, true, :ivdep]
        s1[:simd=>simd] = @benchmarkable(
            ThreadsX.Implementations.foreach_cartesian_seq(
                double!,
                referenceable(ys'),
                $(Val(simd)),
            ),
            setup = (ys = copy($ys)),
        )
    end
end

end  # module
BenchForeachSeqDouble.suite
