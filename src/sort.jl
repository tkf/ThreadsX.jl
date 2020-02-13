function mergesorted!(dest, left, right, order)
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

# Import from Transducers?
function halve(arr::AbstractArray)
    mid = length(arr) ÷ 2
    left = @view arr[firstindex(arr):firstindex(arr)-1+mid]
    right = @view arr[firstindex(arr)+mid:end]
    return (left, right)
end

function _mergesort!(xs, order, basesort!, basesize)
    if length(xs) <= basesize
        basesort!(xs; order = order)
        return xs
    end
    left, right = halve(xs)
    task = @spawn _mergesort!(left, order, basesort!, basesize)
    _mergesort!(right, order, basesort!, basesize)
    wait(task)
    mergesorted!(xs, copy(left), right, order)
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
