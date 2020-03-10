default_basesize(_, _, xs) = default_basesize(xs::AbstractArray)

# TODO: handle `Base.Fix2` etc.
# TODO: tune this; it's just copied from `findfirst`
default_basesize(::typeof(ThreadsX.any), _, xs) = 2^15

default_basesize(::typeof(ThreadsX.all), f, xs) =
    default_basesize(ThreadsX.any, f, xs)

default_basesize(::typeof(ThreadsX.findfirst), _, xs) = 2^15

default_basesize(::typeof(ThreadsX.findlast), f, xs) =
    default_basesize(ThreadsX.findfirst, f, xs)

# `@btime wait(Threads.@spawn nothing)` shows ~1 μs overhead of
# spawning a task.  So let's choose the basesize such that basecase
# takes much longer time than this (say 20 μs).

function default_basesize(
    ::typeof(ThreadsX.extrema),
    ::typeof(identity),
    xs::AbstractArray{T},
) where {T<:Integer}
    if isconcretetype(T)
        return 2^20 ÷ sizeof(T)
    end
    return default_basesize(xs)
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
