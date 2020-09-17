__map(f, itr; kwargs...) =
    tcollect(Map(f), itr; basesize = default_basesize(itr), kwargs...)
__map(f, itrs...; kwargs...) =
    tcollect(MapSplat(f), zip(itrs...); basesize = default_basesize(itrs[1]), kwargs...)

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

function ThreadsX.map!(f, dest, array, arrays...; kw...)
    ThreadsX.foreach(referenceable(dest), array, arrays...; kw...) do y, xs...
        Base.@_inline_meta
        y[] = f(xs...)
    end
    return dest
end

struct ConvertTo{T} end
(::ConvertTo{T})(x) where {T} = convert(T, x)

ThreadsX.collect(::Type{T}, itr; kwargs...) where {T} =
    tcopy(Map(ConvertTo{T}()), Vector{T}, itr; basesize = default_basesize(itr), kwargs...)

ThreadsX.collect(itr; kwargs...) =
    tcollect(itr; basesize = default_basesize(itr), kwargs...)
