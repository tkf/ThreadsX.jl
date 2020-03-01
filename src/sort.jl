function mergesorted!(dest, left, right, order, basesize)
    @assert length(dest) == length(left) + length(right)
    if length(left) <= basesize || length(right) <= basesize
        return mergesorted_basecase!(dest, left, right, order)
    end
    if length(left) < length(right)
        c, d = halve(right)
        a, b = halveat(left, searchsortedlast(left, last(c), order) + 1)
    else
        a, b = halve(left)
        c, d = halveat(right, searchsortedfirst(right, first(b), order))
    end
    # length(c) > 0 && length(b) > 0 && @assert Base.lt(order, last(c), first(b))  # stable sort
    ac, bd = halve(dest, length(a) + length(c))
    task = @spawn mergesorted!(ac, a, c, order, basesize)
    mergesorted!(bd, b, d, order, basesize)
    wait(task)
    return dest
end

function mergesorted_basecase!(dest, left, right, order)
    # @assert issorted(left; order = order)
    # @assert issorted(right; order = order)
    if isempty(left)
        copyto!(dest, right)
        return dest
    elseif isempty(right)
        copyto!(dest, left)
        return dest
    end
    @assert length(dest) == length(left) + length(right)
    i = firstindex(left)
    j = firstindex(right)
    k = firstindex(dest)
    a = @inbounds left[i]
    b = @inbounds right[j]
    while true
        if Base.lt(order, b, a)
            @inbounds dest[k] = b
            j += 1
            k += 1
            if j > lastindex(right)
                copyto!((@view dest[k:end]), (@view left[i:end]))
                break
            end
            b = @inbounds right[j]
        else
            @inbounds dest[k] = a
            i += 1
            k += 1
            if i > lastindex(left)
                copyto!((@view dest[k:end]), (@view right[j:end]))
                break
            end
            a = @inbounds left[i]
        end
    end
    # @assert issorted(dest; order = order)
    return dest
end

halve(arr::AbstractArray, mid = length(arr) ÷ 2) = halveat(arr, firstindex(arr) + mid)

function halveat(arr::AbstractArray, i)
    left = @view arr[firstindex(arr):i-1]
    right = @view arr[i:end]
    return (left, right)
end

function _mergesort!(xs, order, basesort!, basesize, tmp = nothing)
    if length(xs) <= basesize
        basesort!(xs; order = order)
        return xs
    end
    left, right = halve(xs)
    left_tmp, right_tmp = halve(tmp === nothing ? similar(xs) : tmp)
    task = @spawn _mergesort!(left, order, basesort!, basesize, left_tmp)
    _mergesort!(right, order, basesort!, basesize, right_tmp)
    wait(task)
    mergesorted!(xs, copyto!(left_tmp, left), copyto!(right_tmp, right), order, basesize)
    return xs
end

mergesort!(
    xs;
    lt = isless,
    by = identity,
    rev::Bool = false,
    order = Base.Forward,
    basesort! = sort!,
    basesize::Integer = length(xs) ÷ (5 * Threads.nthreads()),
) = _mergesort!(xs, Base.ord(lt, by, rev, order), basesort!, basesize)

ThreadsX.sort(xs; kwargs...) = ThreadsX.sort!(Base.copymutable(xs); kwargs...)
ThreadsX.sort!(xs; kwargs...) = mergesort!(xs; kwargs...)
