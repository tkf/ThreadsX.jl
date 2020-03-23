"""
This benchmark is for demonstrating that `@simd ivdep` can be
beneficial for some cases.  It is constructed such that it is hard for
LLVM to insert run-time memory aliasing check and include a vectorized
version of the loop.
"""
module BenchForeachSeqSumMany

using BenchmarkTools
using ThreadsX

@inline cumsumargs(x, xs...) = (x, _cumsumargs(x, xs...)...)
@inline _cumsumargs(acc, x, xs...) = (acc + x, _cumsumargs(acc + x, xs...)...)
@inline _cumsumargs(acc) = ()

@noinline function manual_sum_many!(vecs::NTuple{N,AbstractArray}) where {N}
    @simd ivdep for i in eachindex(vecs...)
        sums = cumsumargs(map(a -> (@inbounds a[i]), vecs)...)
        ntuple(Val(N)) do j
            Base.@_inline_meta
            @inbounds vecs[j][i] = sums[j]
        end
    end
end

@noinline foreach_sum_many!(vecs::NTuple{N,AbstractArray}, simd) where {N} =
    let nvecs = Val(N)
        ThreadsX.Implementations.foreach_linear_seq(eachindex(vecs...), simd) do i
            Base.@_inline_meta
            sums = cumsumargs(map(a -> (@inbounds a[i]), vecs)...)
            ntuple(nvecs) do j
                Base.@_inline_meta
                @inbounds vecs[j][i] = sums[j]
            end
        end
    end

suite = BenchmarkGroup()

for nvecs in [8]
    m = 2^10
    vecs = Tuple([randn(m) for _ in 1:nvecs])

    s0 = suite[:nvecs=>nvecs] = BenchmarkGroup()
    s0["man"] = @benchmarkable(manual_sum_many!(vecs), setup = (vecs = map(copy, $vecs)))
    s1 = s0["tx"] = BenchmarkGroup()
    for simd in [false, true, :ivdep]
        s1[:simd=>simd] = @benchmarkable(
            foreach_sum_many!(vecs, $(Val(simd))),
            setup = (vecs = map(copy, $vecs)),
        )
    end
end

end  # module
BenchForeachSeqSumMany.suite
