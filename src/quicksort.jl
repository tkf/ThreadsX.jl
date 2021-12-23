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

function _quicksort!(ys, xs, alg, order, givenpivot = nothing)
    @check length(ys) == length(xs)
    if length(ys) <= max(8, alg.basesize)
        return _quicksort_serial!(ys, xs, alg, order)
    end
    isrefined = false
    pivot = if givenpivot === nothing
        let pivot, ishomogenous
            pivot, ishomogenous, isrefined = choose_pivot(ys, alg.basesize, order)
            ishomogenous && return ys
            pivot
        end
    else
        something(givenpivot)
    end
    chunksize = alg.basesize

    # TODO: Calculate extrema during the first pass if it's possible
    # to use counting sort.

    # (1) `quicksort_partition!` -- Partition each chunk in parallel.
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
    if total_nbelows == 0
        @assert givenpivot === nothing
        @assert !isrefined
        betterpivot, ishomogenous = refine_pivot(ys, pivot, alg.basesize, order)
        ishomogenous && return ys
        return _quicksort!(ys, xs, alg, order, Some(betterpivot))
    end

    # (2) `quicksort_copyback!` -- Copy partitions back to the original
    # (destination) array `ys` in the natural order.
    @sync for (i, (xs_chunk, below_offset, above_offset)) in
              enumerate(zip(xs_chunk_list, below_offsets, above_offsets))
        local nb = get(below_offsets, i + 1, total_nbelows) - below_offsets[i]
        @spawn quicksort_copyback!(ys, xs_chunk, nb, below_offset, above_offset)
    end

    # (3) Recursively sort each partion.
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
    _, pivot = samples_and_pivot(ys, order)

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

@inline function samples_and_pivot(xs, order)
    samples = (
        xs[1],
        xs[end÷8],
        xs[end÷4],
        xs[3*(end÷8)],
        xs[end÷2],
        xs[5*(end÷8)],
        xs[3*(end÷4)],
        xs[7*(end÷8)],
        xs[end],
    )
    pivot = _median(order, samples)
    return samples, pivot
end

"""
    choose_pivot(xs, basesize, order) -> (pivot, ishomogenous::Bool, isrefined::Bool)
"""
function choose_pivot(xs, basesize, order)
    samples, pivot = samples_and_pivot(xs, order)
    if (
        eq(order, samples[1], pivot) &&
        eq(order, samples[1], samples[2]) &&
        eq(order, samples[2], samples[3]) &&
        eq(order, samples[3], samples[4]) &&
        eq(order, samples[4], samples[5]) &&
        eq(order, samples[5], samples[6]) &&
        eq(order, samples[6], samples[7]) &&
        eq(order, samples[7], samples[8]) &&
        eq(order, samples[8], samples[9])
    )
        pivot, ishomogenous = refine_pivot_serial(@view(xs[1:min(end, 128)]), pivot, order)
        if ishomogenous
            length(xs) <= 128 && return (pivot, true, true)
            pivot, ishomogenous = refine_pivot(@view(xs[129:end]), pivot, basesize, order)
            return (pivot, ishomogenous, true)
        end
    end
    return (pivot, false, false)
end

"""
    refine_pivot(ys, badpivot::T, basesize, order) -> (pivot::T, ishomogenous::Bool)

Iterate over `ys` for refining `badpivot` and checking if all elements in `ys`
are `order`-equal to `badpivot` (i.e., it is impossible to refine `badpivot`).

Return a value `pivot` in `ys` and a boolean `ishomogenous` indicating if `pivot`
is not `order`-greater than `badpivot`.

Given the precondition:

    badpivot ∈ ys
    all(!(y < badpivot) for y in ys)  # i.e., total_nbelows == 0

`ishomogenous` implies all elements in `ys` are `order`-equal to `badpivot` and
`pivot` is better than `badpivot` if and only if `!ishomogenous`.
"""
function refine_pivot(ys, badpivot, basesize, order)
    chunksize = max(basesize, cld(length(ys), Threads.nthreads()))
    nchunks = cld(length(ys), chunksize)
    nchunks == 1 && return refine_pivot_serial(ys, badpivot, order)
    ishomogenous = Vector{Bool}(undef, nchunks)
    pivots = Vector{eltype(ys)}(undef, nchunks)
    @sync for (i, ys_chunk) in enumerate(_partition(ys, chunksize))
        @spawn (pivots[i], ishomogenous[i]) = refine_pivot_serial(ys_chunk, badpivot, order)
    end
    allishomogenous = all(ishomogenous)
    allishomogenous && return (badpivot, true)
    @DBG for (i, p) in pairs(pivots)
        ishomogenous[i] && @check eq(order, p, badpivot)
    end
    # Find the smallest `pivot` that is not `badpivot`. Assuming that there are
    # a lot of `badpivot` entries, this is perhaps better than using the median
    # of `pivots`.
    i0 = findfirst(!, ishomogenous)
    goodpivot = pivots[i0]
    for i in i0+1:nchunks
        if @inbounds !ishomogenous[i]
            p = @inbounds pivots[i]
            if Base.lt(order, p, goodpivot)
                goodpivot = p
            end
        end
    end
    return (goodpivot, false)
end

function refine_pivot_serial(ys, badpivot, order)
    for y in ys
        if Base.lt(order, badpivot, y)
            return (y, false)
        else
            # Since `refine_pivot` is called only if `total_nbelows == 0` and
            # `y1` is the bad pivot, we have:
            @DBG @check !Base.lt(order, y, badpivot)  # i.e., y == y1
        end
    end
    return (badpivot, true)
end
# TODO: online median approximation
# TODO: Check if the homogeneity check can be done in `quicksort_partition!`
#       without overall performance degradation? Use it to determine the pivot
#       for the next recursion.
