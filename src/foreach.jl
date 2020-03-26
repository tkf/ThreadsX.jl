ThreadsX.foreach(
    f,
    xs::AbstractArray;
    basesize::Integer = default_basesize(xs),
    simd::SIMDFlag = Val(false),
) = foreach_array(f, IndexStyle(xs), xs, basesize, verify_simd_flag(simd))

function foreach_array(f, ::IndexLinear, xs, basesize, simd::SIMDValFlag)
    @argcheck basesize >= 1
    # TODO: Switch to `Channel`-based implementation when
    # `length(partition(xs, basesize))` is much larger than
    # `nthreads`?
    @sync for p in _partition(xs, basesize)
        @spawn foreach_linear_seq(f, p, simd::SIMDValFlag)
    end
    return
end

function _simdify_if(simd, expr)
    simd === false && return expr
    simd === true && return :(@simd $expr)
    simd === :ivdep && return :(@simd ivdep $expr)
    throw(ArgumentError("simd = $simd"))
end

for simd in [false, true, :ivdep]
    # Note: Using `for x in xs` is sometimes _much_ slower when
    # `@simd` is not used (e.g., `bench_foreach_seq_double.jl`).  This
    # is probably because `@simd` macro forces indexing-based loop.
    body = :(
        for i in eachindex(xs)
            f(@inbounds xs[i])
        end
    )
    @eval @inline foreach_linear_seq(f, xs, ::Val{$(QuoteNode(simd))}) =
        $(_simdify_if(simd, body))
end

function foreach_array(f, style::IndexCartesian, xs, basesize, simd::SIMDValFlag)
    @argcheck basesize >= 1
    if length(xs) == 0
        return
    elseif length(xs) <= basesize
        foreach_cartesian_seq(f, xs, simd)
        return
    end
    left, right = SplittablesBase.halve(xs)
    @sync begin
        @spawn foreach_array(f, style, right, basesize, simd)
        foreach_array(f, style, left, basesize, simd)
    end
    return
end

# Until https://github.com/JuliaLang/julia/pull/35036 is merged and
# released, implement special `foreach` here.
# TODO: Upstream this to Transducers.jl?
@inline foreach_cartesian_seq(
    f::F,
    xs::AbstractArray,
    simd::SIMDValFlag,
    idx::CartesianIndex = CartesianIndex(),
) where {F} = foreach_cartesian_seq(
    f,
    xs,
    simd,
    idx,
    CartesianIndex(1, idx), # "dummy index" used to capture the last loop
)
# Not using default argument for "dummy index" here to make sure
# @inline works.

@inline function foreach_cartesian_seq(
    f::F,
    xs::AbstractArray{<:Any,N},
    simd::SIMDValFlag,
    idx::CartesianIndex{M},
    ::CartesianIndex,
) where {F,N,M}
    for i in axes(xs, N - M)
        foreach_cartesian_seq(f, xs, simd, CartesianIndex(i, idx))
    end
end

for simd in [false, true, :ivdep]
    body = :(
        for i in axes(xs, 1)
            f(@inbounds xs[CartesianIndex(i, idx)])
        end
    )
    @eval @inline foreach_cartesian_seq(
        f::F,
        xs::AbstractArray{<:Any,N},
        ::Val{$(QuoteNode(simd))},
        idx::CartesianIndex{M},
        ::CartesianIndex{N},  # the "dummy index"
    ) where {F,N,M} = $(_simdify_if(simd, body))
end

ThreadsX.foreach(
    f,
    array::AbstractArray{<:Any,N},
    arrays::AbstractArray{<:Any,N}...;
    kw...,
) where {N} =
    ThreadsX.foreach(eachindex(array, arrays...); kw...) do i
        Base.@_inline_meta
        f((@inbounds array[i]), map(x -> (@inbounds x[i]), arrays)...)
    end

#=
ThreadsX.foreach(f, array::AbstractArray, arrays::AbstractArray; kw...) =
    ThreadsX.foreach(f, map(vec, tuple(array, arrays...))...; kw...)
=#

@inline return_nothing(_...) = nothing

ThreadsX.foreach(f::F, itr; kw...) where {F} = reduce(
    return_nothing,
    Map(f),
    itr;
    init = nothing,
    basesize = default_basesize(itr),
    kw...,
)

ThreadsX.foreach(f::F, itr, itrs...; kw...) where {F} = reduce(
    return_nothing,
    MapSplat(f),
    zip(itr, itrs...);
    init = nothing,
    basesize = default_basesize(itr),
    kw...,
)
