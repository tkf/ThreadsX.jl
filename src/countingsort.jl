maybe_counting_sort!(::Any, ::Any) = false

function maybe_counting_sort!(
    v::AbstractVector{<:Integer},
    order::Union{typeof(Base.Forward),typeof(Base.Reverse)},
)
    (rangelen, minval), ok = preprocess_counting_sort(v)
    (ok && rangelen < div(length(v), 2)) || return false

    # For `Vector{Int64}`, using threads starts to make sense when the
    # length is around 2^17.

    if length(v) >= 2^17
        parallel_sort_int_range!(v, rangelen, minval, order === Base.Reverse)
    else
        sort_int_range!(v, rangelen, minval, order === Base.Reverse ? reverse : identity)
    end

    return true
end

function preprocess_counting_sort(v::AbstractVector{<:Integer})
    minval, maxval = ThreadsX.extrema(v)
    (diff, o1) = Base.sub_with_overflow(maxval, minval)
    (rangelen, o2) = Base.add_with_overflow(diff, oneunit(diff))
    return (rangelen, minval, maxval), (!o1 && !o2)
end

function sort_int_range!(
    x::AbstractVector{<:Integer},
    rangelen,
    minval,
    maybereverse = identity,
)
    offs = 1 - minval

    where = fill(0, rangelen)
    for i in eachindex(x)
        where[x[i]+offs] += 1
    end

    idx = firstindex(x)
    for i in maybereverse(1:rangelen)
        lastidx = idx + where[i] - 1
        val = i - offs
        for j in idx:lastidx
            x[j] = val
        end
        idx = lastidx + 1
    end

    return x
end

function parallel_sort_int_range!(
    x::AbstractVector{<:Integer},
    rangelen,
    minval,
    rev = false;
    nthreads = Threads.nthreads(),
)

    tasks = Task[]
    chunks = Iterators.partition(x, cld(length(x), nthreads))
    @sync for xchunk in chunks
        push!(tasks, @spawn count_ints(xchunk, rangelen, minval))
    end
    where = fetch(tasks[1])
    for t in @view tasks[2:end]
        where .+= fetch(t)
    end
    if rev
        reverse!(where)
    end
    pushfirst!(where, 0)
    acc = 0
    for i in 2:length(where)
        acc = where[i] += acc
    end

    indices = Iterators.partition(1:rangelen, cld(rangelen, nthreads))
    if rev
        indices = reverse(indices)
    end
    @sync for ichunk in indices
        @spawn scatter_ints!(x, minval, where, ichunk)
    end

    return x
end

function count_ints(xs, rangelen, minval)
    offs = 1 - minval
    where = fill(0, rangelen)
    for x in xs
        where[x+offs] += 1
    end
    where
end

function scatter_ints!(x, minval, offsets, indices)
    offs = 1 - minval
    for i in indices
        val = i - offs
        for j in offsets[i]:offsets[i+1]-1
            x[firstindex(x)+j] = val
        end
    end
end

function parallel_counting_sort!(
    v::AbstractVector{<:Integer},
    order::Union{typeof(Base.Forward),typeof(Base.Reverse)} = Base.Forward,
)
    (rangelen, minval, maxval), ok = preprocess_counting_sort(v)
    ok || error("Value range too large: min = $(repr(minval)), max = $(repr(maxval))")
    parallel_sort_int_range!(v, rangelen, minval, order === Base.Reverse)
    return v
end
