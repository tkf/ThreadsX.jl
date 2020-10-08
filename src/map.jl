__map(f, itr; kwargs...) =
    tcollect(Map(f), itr; basesize = default_basesize(itr), kwargs...)
__map(f, itrs...; kwargs...) =
    tcollect(MapSplat(f), zip(itrs...); basesize = default_basesize(itrs[1]), kwargs...)

reshape_as(ys, xs) = reshape_as(ys, xs, IteratorSize(xs))
reshape_as(ys, xs, ::IteratorSize) = ys
reshape_as(ys, xs, ::HasShape) = reshape(ys, size(xs))
reshape_as(::Empty{T}, xs, isize::HasShape) where {T<:AbstractVector} =
    reshape_as(T(undef, length(xs)), xs, isize)

function _map(f, itr, itrs...; kwargs...)
    ys = __map(f, itr, itrs...; kwargs...)
    isempty(ys) && return map(f, itr, itrs...)
    return reshape_as(ys, itr)
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

ThreadsX.collect(::Type{T}, itr; kwargs...) where {T} = reshape_as(
    tcopy(Map(ConvertTo{T}()), Vector{T}, itr; basesize = default_basesize(itr), kwargs...),
    itr,
)

ThreadsX.collect(itr; kwargs...) =
    reshape_as(tcollect(itr; basesize = default_basesize(itr), kwargs...), itr)


ThreadsX.mapi(f, itr; kwargs...) =
    itr |>
    NondeterministicThreading(; kwargs...) |>
    Map(f) |>
    Map(SingletonVector) |>
    foldxl(append!!; init = EmptyVector())

ThreadsX.mapi(f, itr1, itrs...; kwargs...) =
    ThreadsX.mapi(Base.splat(f), zip(itr1, itrs...); kwargs...)
