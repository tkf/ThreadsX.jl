__map(f, itr; kwargs...) = tcollect(Map(f), itr; kwargs...)
__map(f, itrs...; kwargs...) = tcollect(MapSplat(f), zip(itrs...); kwargs...)

function _map(f, itr, itrs...; kwargs...)
    ys = __map(f, itr, itrs...; kwargs...)
    isempty(ys) && return map(f, itr, itrs...)
    return ys
end

ThreadsX.map(f, itr, itrs...; kwargs...) = _map(f, itr, itrs...; kwargs...)

function ThreadsX.map(
    f,
    array::AbstractArray{<:Any,N},
    arrays::AbstractArray{<:Any,N}...;
    kwargs...,
) where {N}
    dims = size(array)
    if !all(a -> size(a) == dims, arrays)
        throw(ArgumentError("shape of arrays do not match"))
    end
    output = _map(f, array, arrays...; kwargs...)
    return reshape(output, dims)
end

function ThreadsX.foreach(f, xs::AbstractArray; basesize::Integer = default_basesize(xs))
    @argcheck basesize >= 1
    # TODO: Switch to `Channel`-based implementation when
    # `length(partition(xs, basesize))` is much larger than
    # `nthreads`?
    @sync for p in _partition(xs, basesize)
        @spawn foreach(f, p)
    end
    return
end

ThreadsX.foreach(
    f,
    array::AbstractArray{<:Any,N},
    arrays::AbstractArray{<:Any,N}...;
    kw...,
) where {N} =
    ThreadsX.foreach(eachindex(array, arrays...); kw...) do i
        f((@inbounds array[i]), map(x -> (@inbounds x[i]), arrays)...)
    end

#=
ThreadsX.foreach(f, array::AbstractArray, arrays::AbstractArray; kw...) =
    ThreadsX.foreach(f, map(vec, tuple(array, arrays...))...; kw...)
=#

function ThreadsX.map!(f, dest, array, arrays...; kw...)
    ThreadsX.foreach(referenceable(dest), array, arrays...; kw...) do y, xs...
        y[] = f(xs...)
    end
    return dest
end
