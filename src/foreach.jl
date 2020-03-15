ThreadsX.foreach(f, xs::AbstractArray; basesize::Integer = default_basesize(xs)) =
    foreach_array(f, IndexStyle(xs), xs, basesize)

function foreach_array(f, ::IndexLinear, xs, basesize)
    @argcheck basesize >= 1
    # TODO: Switch to `Channel`-based implementation when
    # `length(partition(xs, basesize))` is much larger than
    # `nthreads`?
    @sync for p in _partition(xs, basesize)
        @spawn foreach(f, p)
    end
    return
end

function foreach_array(f, style::IndexCartesian, xs, basesize)
    @argcheck basesize >= 1
    if length(xs) == 0
        return
    elseif length(xs) <= basesize
        foreach_cartesian_seq(f, xs)
        return
    end
    left, right = SplittablesBase.halve(xs)
    @sync begin
        @spawn foreach_array(f, style, right, basesize)
        foreach_array(f, style, left, basesize)
    end
    return
end

# Until https://github.com/JuliaLang/julia/pull/35036 is merged and
# released, implement special `foreach` here.
# TODO: Upstream this to Transducers.jl?
@inline function foreach_cartesian_seq(
    f::F,
    xs::AbstractArray{<:Any,N},
    idx::CartesianIndex{M} = CartesianIndex(),
) where {F,N,M}
    for i in axes(xs, N - M)
        foreach_cartesian_seq(f, xs, CartesianIndex(i, idx))
    end
end

@inline function foreach_cartesian_seq(
    f,
    xs::AbstractArray{<:Any,N},
    idx::CartesianIndex{N},
) where {N}
    f(@inbounds xs[idx])
    return
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
