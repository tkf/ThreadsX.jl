default_basesize(n::Integer) = max(1, cld(n, (8 * Threads.nthreads())))
default_basesize(xs) = default_basesize(length(xs))

function adhoc_partition(xs, n)
    @check firstindex(xs) == 1
    m = cld(length(xs), n)
    return (view(xs, i*n+1:min((i+1)*n, length(xs))) for i in 0:m-1)
end

if VERSION >= v"1.4"
    const _partition = Iterators.partition
else
    const _partition = adhoc_partition
end

@inline _asval(x::Val) = x
@inline _asval(x) = Val(x)

const SIMDValFlag = Union{Val{true}, Val{false}, Val{:ivdep}}
const SIMDFlag = Union{Bool, Symbol, SIMDValFlag}

__verify_simd_flag(simd::SIMDValFlag, _) = simd
__verify_simd_flag(_, simd) =
    throw(ArgumentError("Invalid `simd` option: $(repr(simd))"))

verify_simd_flag(simd) = __verify_simd_flag(_asval(simd), simd)

function _median(order, (a, b, c)::NTuple{3,Any})
    # Sort `(a, b, c)`:
    if Base.lt(order, b, a)
        a, b = b, a
    end
    if Base.lt(order, c, a)
        a, c = c, a
    end
    if Base.lt(order, c, b)
        b, c = c, b
    end
    return b
end

_median(order, (a, b, c, d, e, f, g, h, i)::NTuple{9,Any}) = _median(
    order,
    (_median(order, (a, b, c)), _median(order, (d, e, f)), _median(order, (g, h, i))),
)

function maptasks(f, xs)
    tasks = Task[]
    @sync for x in xs
        push!(tasks, @spawn f(x))
    end
    return map(fetch, tasks)
end

function exclusive_cumsum!(xs, acc = zero(eltype(xs)))
    @inbounds for i in eachindex(xs)
        xs[i], x = acc, xs[i]
        acc += x
    end
    return acc
end

struct Unroll{N,A}
    xs::A
end

Unroll{N}(xs::A) where {N,A} = Unroll{N,A}(xs)

@inline _foldlargs(op, acc) = acc
@inline _foldlargs(op, acc, x, xs...) = _foldlargs(op, op(acc, x), xs...)

@inline function _foldl(op::F, acc, itr::Unroll{N}) where {N,F}
    i = firstindex(itr.xs)
    n = lastindex(itr.xs) - N
    while i <= n
        acc = let i = i
            _foldlargs(acc, ntuple(identity, Val{N}())...) do acc, k
                op(acc, @inbounds itr.xs[i + (k - 1)])
            end
        end
        i += N
    end
    while i <= lastindex(itr.xs)
        acc = op(acc, @inbounds itr.xs[i])
        i += 1
    end
    return acc
end

function define_docstrings()
    docstrings = [:ThreadsX => joinpath(dirname(@__DIR__), "README.md")]
    docsdir = joinpath(@__DIR__, "docs")
    for filename in readdir(docsdir)
        stem, ext = splitext(filename)
        ext == ".md" || continue
        name = Symbol(stem)
        name in names(ThreadsX, all=true) || continue
        push!(docstrings, name => joinpath(docsdir, filename))
    end
    for (name, path) in docstrings
        include_dependency(path)
        doc = read(path, String)
        doc = replace(doc, r"^```julia"m => "```jldoctest $name")
        doc = replace(doc, "<kbd>TAB</kbd>" => "_TAB_")
        @eval ThreadsX $Base.@doc $doc $name
    end
end
