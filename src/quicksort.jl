Base.@kwdef struct ParallelQuickSortAlg{Alg,SmallSize,BaseSize} <: ParallelSortAlgorithm
    smallsort::Alg = Base.Sort.DEFAULT_UNSTABLE
    smallsize::SmallSize = nothing  # lazily determined
    basesize::BaseSize = 10_000
end
# `basesize` is tuned using `Float64`.  Make it `eltype`-aware?
#
# Note: Small `smallsize` (e.g., 32) is beneficial on random data. However, it
# is slower on sorted data with small number of worker threads.
# TODO: Implement some heuristics for `smallsize`.

function Base.sort!(
    v::AbstractVector,
    lo::Integer,
    hi::Integer,
    a::ParallelQuickSortAlg,
    o::Ordering,
)
    if a.basesize === nothing
        a = @set a.basesize = default_basesize(hi - lo + 1)
    end
    if a.smallsize === nothing
        a = @set a.smallsize = a.basesize
    end
    ys = view(v, lo:hi)
    xs = similar(ys)
    _quicksort!(ys, xs, a, o)
    return v
end

function choose_pivot(xs, order)
    return _median(
        order,
        (
            xs[1],
            xs[end÷8],
            xs[end÷4],
            xs[3*(end÷8)],
            xs[end÷2],
            xs[5*(end÷8)],
            xs[3*(end÷4)],
            xs[7*(end÷8)],
            xs[end],
        ),
    )
end

function _quicksort!(ys, xs, alg, order)
    @check length(ys) == length(xs)
    if length(ys) <= max(8, alg.basesize)
        return _quicksort_serial!(ys, xs, alg, order)
    end
    pivot = choose_pivot(ys, order)
    chunksize = alg.basesize

    # TODO: Calculate extrema during the first pass if it's possible
    # to use counting sort.

    # (1) `quicksort_partition!` -- partition each chunk in parallel
    xs_chunk_list = _partition(xs, chunksize)
    ys_chunk_list = _partition(ys, chunksize)
    nchunks = cld(length(xs), chunksize)
    nbelows = Vector{Int}(undef, nchunks)
    naboves = Vector{Int}(undef, nchunks)
    @DBG begin
        VERSION >= v"1.4" &&
            @check length(xs_chunk_list) == length(ys_chunk_list) == nchunks
        fill!(nbelows, -1)
        fill!(naboves, -1)
    end
    @sync for (nb, na, xs_chunk, ys_chunk) in zip(
        referenceable(nbelows),
        referenceable(naboves),
        xs_chunk_list,
        ys_chunk_list,
    )
        @spawn (nb[], na[]) = quicksort_partition!(xs_chunk, ys_chunk, pivot, order)
    end
    @DBG begin
        @check all(>=(0), nbelows)
        @check all(>=(0), naboves)
        @check nbelows .+ nbelows == map(length, xs_chunk_list)
    end

    below_offsets = nbelows
    above_offsets = naboves
    acc = exclusive_cumsum!(below_offsets)
    acc = exclusive_cumsum!(above_offsets, acc)
    @check acc == length(xs)

    total_nbelows = above_offsets[1]
    total_nbelows == 0 && return sort!(ys, alg.smallsort, order)
    # TODO: Fallback to parallel mergesort? Scan the array to check degeneracy
    # and also to estimate a good pivot?

    # (2) `quicksort_copyback!` -- Copy partitions back to the original
    # (destination) array `ys` in the natural order
    @sync for (i, (xs_chunk, below_offset, above_offset)) in
              enumerate(zip(xs_chunk_list, below_offsets, above_offsets))
        local nb = get(below_offsets, i + 1, total_nbelows) - below_offsets[i]
        @spawn quicksort_copyback!(ys, xs_chunk, nb, below_offset, above_offset)
    end

    # (3) Recursively sort each partion
    below = 1:total_nbelows
    above = total_nbelows+1:length(xs)
    @sync begin
        @spawn _quicksort!(view(ys, above), view(xs, above), alg, order)
        _quicksort!(view(ys, below), view(xs, below), alg, order)
    end

    return ys
end

function _quicksort_serial!(ys, xs, alg, order)
    # @check length(ys) == length(xs)
    if length(ys) <= max(8, alg.smallsize)
        return sort!(ys, alg.smallsort, order)
    end
    pivot = choose_pivot(ys, order)

    nbelows, naboves = quicksort_partition!(xs, ys, pivot, order)
    @DBG @check nbelows + naboves == length(xs)
    nbelows == 0 && return sort!(ys, alg.smallsort, order)

    below_offset = 0
    above_offset = nbelows
    quicksort_copyback!(ys, xs, nbelows, below_offset, above_offset)

    below = 1:above_offset
    above = above_offset+1:length(xs)
    _quicksort_serial!(view(xs, below), view(ys, below), alg, order)
    _quicksort_serial!(view(xs, above), view(ys, above), alg, order)

    return ys
end

function quicksort_partition!(xs, ys, pivot, order)
    _foldl((0, 0), Unroll{4}(eachindex(xs, ys))) do (nbelows, naboves), i
        @_inline_meta
        x = @inbounds ys[i]
        b = Base.lt(order, x, pivot)
        nbelows += Int(b)
        naboves += Int(!b)
        @inbounds xs[ifelse(b, nbelows, end - naboves + 1)] = x
        return (nbelows, naboves)
    end
end

function quicksort_copyback!(ys, xs_chunk, nbelows, below_offset, above_offset)
    copyto!(ys, below_offset + 1, xs_chunk, firstindex(xs_chunk), nbelows)
    @simd ivdep for i in 1:length(xs_chunk)-nbelows
        @inbounds ys[above_offset+i] = xs_chunk[end-i+1]
    end
end
