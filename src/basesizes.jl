default_basesize(_, _, xs) = default_basesize(xs::AbstractArray)

# `@btime wait(Threads.@spawn nothing)` shows ~1 μs overhead of
# spawning a task.  So let's choose the basesize such that basecase
# takes much longer time than this (say 20 μs).

function default_basesize(
    ::typeof(ThreadsX.extrema),
    ::typeof(identity),
    ::AbstractArray{T},
) where {T<:Integer}
    if isconcretetype(T)
        return 2^20 ÷ sizeof(T)
    end
    return default_basesize()
end

default_basesize(
    ::typeof(ThreadsX.extrema),
    ::typeof(identity),
    ::AbstractArray{<:Union{Float32,Float64}},
) = 8192

default_basesize(
    ::typeof(ThreadsX.extrema),
    ::typeof(identity),
    ::AbstractArray{Float16},  # slower?
) = 2048
