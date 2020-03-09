Base.@kwdef struct ParallelQuickSortAlg{Alg,SmallSize,BaseSize} <: ParallelSortAlgorithm
    smallsort::Alg = Base.Sort.DEFAULT_UNSTABLE
    smallsize::SmallSize = nothing  # lazily determined
    basesize::BaseSize = nothing  # lazily determined
end

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
    return _quicksort!(ys, copy(ys), a, o, Vector{Int8}(undef, length(ys)), true, true)
end

function _quicksort!(
    ys,
    xs,
    alg,
    order,
    cs = Vector{Int8}(undef, length(ys)),
    ys_eq_xs = false,
    mutable_xs = false,
)
    @check length(ys) == length(xs)
    if length(ys) <= alg.smallsize
        ys_eq_xs || copyto!(ys, xs)
        return sort!(ys, alg.smallsort, order)
    end
    pivot = xs[end÷2]

    # TODO: Calculate extrema during the first pass if it's possible
    # to use counting sort.
    # TODO: When recursing, fuse copying _from_ `ys` to `xs` with the
    # first pass.

    # Compute sizes of each partition for each chunks.
    chunks = zip(_partition(xs, alg.basesize), _partition(cs, alg.basesize))
    results = maptasks(partition_sizes!(pivot, order), chunks)
    nbelows = map(first, results)
    nequals = map(last, results)
    naboves = [length(c) - (b + e) for (b, e, (c, _)) in zip(nbelows, nequals, chunks)]
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
            @spawn begin
                if mutable_xs
                    copyto!(xs_new, ys_new)
                else
                    xs_new = copy(ys_new)
                end
                _quicksort!(ys_new, xs_new, alg, order, cs_new, true, true)
            end
        end
        for idx in partitions
            length(idx) <= alg.smallsize || continue
            sort!(view(ys, idx); alg = QuickSort, order = order)
        end
    end

    return ys
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

quicksort(
    xs;
    lt = isless,
    by = identity,
    rev::Bool = false,
    order = Base.Forward,
    basesize::Integer = default_basesize(xs),
) = _quicksort!(similar(xs), xs, Base.ord(lt, by, rev, order), basesize)
