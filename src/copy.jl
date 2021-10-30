ThreadsX.copy!(dest::AbstractVector, src::AbstractVector; kwargs...) =
    ThreadsX.copyto!(resize!(dest, length(src)), src; kwargs...)

function ThreadsX.copyto!(
    dest::AbstractArray,
    src::AbstractArray;
    basesize::Integer = default_copyto_basesize(dest, src),
)
    if length(dest) <= basesize
        copyto!(dest, src)
    elseif IndexStyle(dest) isa IndexLinear && IndexStyle(src) isa IndexLinear
        linear_copyto!(dest, src, basesize)
    else
        cartesian_copyto!(dest, src, basesize)
    end
    return dest
end

function linear_copyto!(dest, src, basesize)
    # TODO: support size-compatible but index-incompatible arrays
    @sync for p in _partition(eachindex(dest, src), basesize)
        @spawn if p isa AbstractUnitRange
            copyto!(dest, first(p), src, first(p), length(p))
        else
            copyto!(view(dest, p), view(src, p))
        end
    end
end

function cartesian_copyto!(dest, src, basesize)
    ThreadsX.foreach(eachindex(dest, src); basesize = basesize) do i
        @inbounds dest[i] = src[i]
    end
end

# TODO: Take into account more properties like: sizeof(T), boxed?, union?,
# need conversion?
function default_copyto_basesize(dest::AbstractArray{T}, ::AbstractArray) where {T}
    # 2^19 for 64 bit T
    basesize = 4194304 ÷ elsizeof(T)
    return max(cld(length(dest), Threads.nthreads()), basesize)
end
