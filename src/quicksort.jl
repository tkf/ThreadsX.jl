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
    _quicksort!(
        similar(ys),
        ys,
        a,
        o,
        Vector{Int8}(undef, length(ys)),
        false,  # ys_is_result
        true,   # mutable_xs
    )
    return v
end

function _quicksort!(
    ys,
    xs,
    alg,
    order,
    cs = Vector{Int8}(undef, length(ys)),
    ys_is_result = true,
    mutable_xs = false,
)
    @check length(ys) == length(xs)
    if length(ys) <= max(8, alg.basesize)
        return _quicksort_serial!(ys, xs, alg, order, cs, ys_is_result, mutable_xs)
    end
    pivot = _median(
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

    # TODO: Calculate extrema during the first pass if it's possible
    # to use counting sort.
    # TODO: When recursing, fuse copying _from_ `ys` to `xs` with the
    # first pass.

    # Compute sizes of each partition for each chunks.
    chunks = zip(_partition(xs, alg.basesize), _partition(cs, alg.basesize))
    results = maptasks(partition_sizes!(pivot, order), chunks)
    nbelows::Vector{Int} = map(first, results)
    nequals::Vector{Int} = map(last, results)
    naboves::Vector{Int} =
        [length(c) - (b + e) for (b, e, (c, _)) in zip(nbelows, nequals, chunks)]
    @check length(chunks) == length(nbelows) == length(nequals) == length(naboves)
    @check all(>=(0), naboves)
    singleton_chunkid = map(nbelows, nequals, naboves) do nb, ne, na
        if (nb > 0) + (ne > 0) + (na > 0) == 1
            return 1 * (nb > 0) + 2 * (ne > 0) + 3 * (na > 0)
        else
            return 0
        end
    end

    below_offsets = copy(nbelows)
    equal_offsets = copy(nequals)
    above_offsets = copy(naboves)
    acc = exclusive_cumsum!(below_offsets)
    acc = exclusive_cumsum!(equal_offsets, acc)
    acc = exclusive_cumsum!(above_offsets, acc)
    @check acc == length(xs)

    @sync begin
        for (i, (xs_chunk, cs_chunk)) in enumerate(chunks)
            singleton_chunkid[i] > 0 && continue
            @spawn unsafe_quicksort_scatter!(
                ys,
                xs_chunk,
                cs_chunk,
                below_offsets[i],
                equal_offsets[i],
                above_offsets[i],
            )
        end
        for (i, (xs_chunk, _)) in enumerate(chunks)
            singleton_chunkid[i] > 0 || continue
            idx = (
                below_offsets[i]+1:get(below_offsets, i + 1, equal_offsets[1]),
                equal_offsets[i]+1:get(equal_offsets, i + 1, above_offsets[1]),
                above_offsets[i]+1:get(above_offsets, i + 1, length(ys)),
            )[singleton_chunkid[i]]
            # There is only one partition. Short-circuit scattering.
            ys_chunk = view(ys, idx)
            copyto!(ys_chunk, xs_chunk)
            # Is it better to multi-thread this?
        end
    end

    partitions = (1:equal_offsets[1], above_offsets[1]+1:length(xs))
    @sync begin
        for idx in partitions
            length(idx) <= alg.smallsize && continue
            ys_new = view(ys, idx)
            xs_new = view(xs, idx)
            cs_new = view(cs, idx)
            @spawn let zs
                if mutable_xs
                    zs = xs_new
                else
                    zs = similar(ys_new)
                end
                _quicksort!(zs, ys_new, alg, order, cs_new, !ys_is_result, true)
            end
        end
        for idx in partitions
            length(idx) <= alg.smallsize || continue
            if ys_is_result
                ys_new = view(ys, idx)
            else
                ys_new = copyto!(view(xs, idx), view(ys, idx))
            end
            sort!(ys_new, alg.smallsort, order)
        end
        if !ys_is_result
            let idx = equal_offsets[1]+1:above_offsets[1]
                copyto!(view(xs, idx), view(ys, idx))
            end
        end
    end

    return ys_is_result ? ys : xs
end

function _quicksort_serial!(
    ys,
    xs,
    alg,
    order,
    cs = Vector{Int8}(undef, length(ys)),
    ys_is_result = true,
    mutable_xs = false,
)
    # @check length(ys) == length(xs)
    if length(ys) <= max(8, alg.smallsize)
        if ys_is_result
            zs = copyto!(ys, xs)
        else
            zs = xs
        end
        return sort!(zs, alg.smallsort, order)
    end
    pivot = _median(
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

    (nbelows, nequals) = partition_sizes!(xs, cs, pivot, order)
    if nequals == length(xs)
        if ys_is_result
            copyto!(ys, xs)
            return ys
        else
            return xs
        end
    end
    @assert nequals > 0
    below_offset = 0
    equal_offset = nbelows
    above_offset = nbelows + nequals
    unsafe_quicksort_scatter!(ys, xs, cs, below_offset, equal_offset, above_offset)

    below = 1:equal_offset
    above = above_offset+1:length(xs)
    ya = view(ys, above)
    yb = view(ys, below)
    ca = view(cs, above)
    cb = view(cs, below)
    if mutable_xs
        _quicksort_serial!(view(xs, above), ya, alg, order, ca, !ys_is_result, true)
        _quicksort_serial!(view(xs, below), yb, alg, order, cb, !ys_is_result, true)
    else
        let zs = similar(ys)
            _quicksort_serial!(view(zs, above), ya, alg, order, ca, !ys_is_result, true)
            _quicksort_serial!(view(zs, below), yb, alg, order, cb, !ys_is_result, true)
        end
    end
    if !ys_is_result
        let idx = equal_offset+1:above_offset
            copyto!(view(xs, idx), view(ys, idx))
        end
    end

    return ys_is_result ? ys : xs
end

partition_sizes!(pivot, order) = ((xs, cs),) -> partition_sizes!(xs, cs, pivot, order)

function partition_sizes!(xs, cs, pivot, order)
    nbelows = 0
    nequals = 0
    @inbounds for i in eachindex(xs, cs)
        x = xs[i]
        b = Base.lt(order, x, pivot)
        a = Base.lt(order, pivot, x)
        cs[i] = ifelse(b, -Int8(1), ifelse(a, Int8(1), Int8(0)))
        nbelows += Int(b)
        nequals += Int(!(a | b))
    end
    return (nbelows, nequals)
end

function unsafe_quicksort_scatter!(
    ys,
    xs_chunk,
    cs_chunk,
    below_offset,
    equal_offset,
    above_offset,
)
    b = below_offset
    e = equal_offset
    a = above_offset
    _foldl((b, a, e), Unroll{4}(eachindex(xs_chunk, cs_chunk))) do (b, a, e), i
        @inbounds x = xs_chunk[i]
        @inbounds c = cs_chunk[i]
        is_equal = c == 0
        is_above = c > 0
        is_below = c < 0
        e += Int(is_equal)
        a += Int(is_above)
        b += Int(is_below)
        @inbounds ys[ifelse(is_equal, e, ifelse(is_above, a, b))] = x
        (b, a, e)
    end
    return
end
