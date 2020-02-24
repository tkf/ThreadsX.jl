without_basesize(; basesize = nothing, kw...) = kw

function ThreadsX.reduce(op, itr; kw...)
    result = reduce(op, Map(identity), itr; init = Init(op), kw...)
    result === Init(op) && return reduce_empty(op, eltype(itr))
    return result
end

function ThreadsX.mapreduce(f, op, itr; kw...)
    result = reduce(op, Map(f), itr; init = Init(op), kw...)
    result === Init(op) && return mapreduce_empty(f, op, eltype(itr))
    return result
end

function ThreadsX.mapreduce(f, op, itr, itrs...; kw...)
    if isempty(itr)
        # `Base` just does `reduce(op, map(f, ...))`:
        return mapreduce(f, op, itr, itrs...; without_basesize(; kw...)...)
    end
    return reduce(op, MapSplat(f), zip(itr, itrs...); kw...)
end

# Maybe refactor the function based on mapreduce into AbstractReducers.jl?

ThreadsX.sum(itr; kw...) = ThreadsX.sum(identity, itr; kw...)
ThreadsX.sum(f, itr; kw...) = ThreadsX.mapreduce(f, add_sum, itr; simd = Val(true), kw...)

ThreadsX.prod(itr; kw...) = ThreadsX.prod(identity, itr; kw...)
ThreadsX.prod(f, itr; kw...) = ThreadsX.mapreduce(f, mul_prod, itr; simd = Val(true), kw...)

ThreadsX.count(itr; kw...) = ThreadsX.count(identity, itr; kw...)
ThreadsX.count(f, itr; kw...) =
    ThreadsX.sum(x -> Int(f(x)::Bool), itr; init = 0, simd = Val(true), kw...)

ThreadsX.maximum(itr; kw...) = ThreadsX.maximum(identity, itr; kw...)
ThreadsX.maximum(f, itr; kw...) = ThreadsX.mapreduce(f, max, itr; simd = Val(true), kw...)

ThreadsX.minimum(itr; kw...) = ThreadsX.minimum(identity, itr; kw...)
ThreadsX.minimum(f, itr; kw...) = ThreadsX.mapreduce(f, min, itr; simd = Val(true), kw...)

asbool(f) = x -> f(x)::Bool

# TODO: `any` and `all` should be done with "unordered" version
ThreadsX.any(itr; kw...) = ThreadsX.any(identity, itr; kw...)
ThreadsX.any(f, itr; kw...) = reduce(
    right,  # no need to use `|`
    Map(asbool(f)) |> ReduceIf(identity),
    simd = Val(true),
    itr;
    kw...,
    init = false,
)

ThreadsX.all(itr; kw...) = ThreadsX.all(identity, itr; kw...)
ThreadsX.all(f, itr; kw...) = reduce(
    right,  # no need to use `&`
    Map(asbool(f)) |> ReduceIf(!),
    itr;
    simd = Val(true),
    kw...,
    init = true,
)

ThreadsX.findfirst(itr; kw...) = ThreadsX.findfirst(identity, itr; kw...)
ThreadsX.findfirst(f, array::AbstractArray; kw...) = reduce(
    right,
    ReduceIf(i -> f(@inbounds array[i])),
    keys(array);
    init = nothing,
    simd = Val(true),
    kw...,
)

ThreadsX.findlast(itr; kw...) = ThreadsX.findlast(identity, itr; kw...)
function ThreadsX.findlast(f, array::AbstractArray; kw...)
    idx = keys(array)
    return reduce(
        right,
        Map(i -> idx[i]) |> ReduceIf(i -> f(@inbounds array[i])),
        lastindex(idx):-1:firstindex(idx);
        init = nothing,
        simd = Val(true),
        kw...,
    )
end

ThreadsX.findall(itr; kw...) = ThreadsX.findall(identity, itr; kw...)
function ThreadsX.findall(f, array::AbstractArray; kw...)
    idxs = tcollect(
        Filter(i -> f(@inbounds array[i])),
        keys(array);
        simd = Val(true),
        kw...,
    )
    isempty(idxs) && return keytype(array)[]
    return idxs
end

_minmax((min0, max0), (min1, max1)) = (min(min0, min1), max(max0, max1))

ThreadsX.extrema(itr; kw...) = ThreadsX.extrema(identity, itr; kw...)
ThreadsX.extrema(f, itr; kw...) =
    reduce(asmonoid(_minmax), Map(x -> (y = f(x); (y, y))), itr; simd = Val(true), kw...)

struct PushUnique{F} <: Function
    f::F
end
PushUnique(::Type{T}) where {T} = PushUnique{Type{T}}(T)

function (f!::PushUnique)((ys, seen), x)
    fx = f!.f(x)
    return fx in seen ? (ys, seen) : (push!!(ys, x), push!!(seen, fx))
end

# TODO: do this with public API of Transducers or make it public
function Transducers.combine(f!::PushUnique, (ys1, seen1), (ys2, seen2))
    seen3 = setdiff!(seen2, seen1)
    isempty(seen3) && return (ys1, seen1)
    return (append!!(Filter(x -> f!.f(x) in seen3), ys1, ys2), union!!(seen1, seen2))
end
# * Add an option to avoid re-compute `f(x)` in combine?
# * Iterate over `seen3` if `length(seen3) << length(ys2)`?

# Manually create a singleton callable since closure captures the
# types as `DataType` and causes type-instability:
struct InitUnique{X,Y} <: Function end
@inline function (::InitUnique{X,Y})() where {X,Y}
    if isbitstype(Y) || Base.isbitsunion(Y)
        return (X[], Set{Y}())
    else
        return (X[], Empty(Set))
    end
end

ThreadsX.unique(itr; kw...) = ThreadsX.unique(identity, itr; kw...)
function ThreadsX.unique(f::F, itr::AbstractVector{X}; kw...) where {F,X}
    # Using inference as an optimization. The result of this inference
    # does not affect the result:
    Y = Core.Compiler.return_type(f, Tuple{X})
    ys, = reduce(PushUnique(f), Map(identity), itr; kw..., init = OnInit(InitUnique{X,Y}()))
    return ys::Vector{X}
end
