module TestWithBase

using Test
using ThreadsX

inc(x) = x + 1

raw_testdata = """
map(inc, 1:10)
map(inc, Float64[])
map(inc, ones(3, 3))
map(inc, ones(3, 0))
map(inc, ones(0, 3))
map(*, 1:10, 11:20)
map(*, ones(3, 3), ones(3, 3))
map(*, ones(3, 0), ones(3, 0))
map(*, ones(0, 3), ones(0, 3))
reduce(+, 1:10)
reduce(+, 1:0)
reduce(+, Bool[])
mapreduce(inc, +, 1:10)
mapreduce(*, +, 1:10, 11:20)
mapreduce(*, +, 1:0, 11:10)
sum(1:10)
sum(1:0)
sum(x -> x^2, 1:10)
prod(1:10)
prod(1:0)
prod(x -> x + 1, 1:10)
count(isodd.(1:10))
count(isodd, 1:10)
count(Bool[])
count(isodd, 1:0)
maximum(1:10)
maximum(inc, 1:10)
minimum(1:10)
minimum(inc, 1:10)
any(fill(false, 10))
any([fill(false, 10); true])
any([])
all(fill(true, 10))
all([fill(true, 10); false])
all([])
findfirst([fill(false, 10); true])
findfirst(iseven, 1:10)
findfirst(reshape([fill(false, 10); true; true], 3, 4))
findfirst(==(5), reshape(1:12, 3, 4))
findfirst([])
findfirst(identity, [])
findlast([fill(true, 10); false])
findlast(isodd, 1:10)
findlast(reshape([fill(true, 10); false; false], 3, 4))
findlast(isodd, reshape(1:12, 3, 4))
findlast([])
findlast(identity, [])
findall([fill(false, 10); true])
findall(iseven, 1:10)
findall(reshape([fill(false, 10); true; true], 3, 4))
findall(==(5), reshape(1:12, 3, 4))
findall([])
findall(identity, [])
extrema(1:10)
extrema(sin, 1:10)
unique([1, 2, 6, 2])
unique(Real[1, 1.0, 2])
unique(x -> x^2, [1, -1, -3, 4, 3])
Set([1, -1, -3, 4, 3])
Set(x^2 for x in [1, -1, -3, 4, 3])
"""

# An array of `(label, (f, args))`
testdata = map(split(raw_testdata, "\n", keepempty = false)) do x
    @debug "Parsing: $x"
    m = match(r"([^(]+)\((.*),? *\)$", x)
    f = m[1]
    args = m[2]
    code = "$f, tuple($args)"
    @debug "Evaling: $code"
    ex = Meta.parse(code)
    (x, @eval($ex))
end

@testset "$label" for (label, (f, args)) in testdata
    g = getproperty(ThreadsX, nameof(f))
    @testset "default basesize" begin
        @test g(args...) == f(args...)
    end
    @testset for basesize in 1:3
        @test g(args...; basesize = basesize) == f(args...)
    end
end

function test_all_implementations(test, name)
    @testset "Base" begin
        test(getproperty(Base, name))
    end
    @testset "ThreadsX" begin
        f = getproperty(ThreadsX, name)
        @testset "default basesize" begin
            test(f)
        end
        @testset for basesize in 1:3
            test((args...) -> f(args...; basesize = basesize))
        end
    end
end

@testset "foreach(x -> ys[x] = x^2, 1:5)" begin
    test_all_implementations(:foreach) do foreach
        xs = 1:5
        ys = zero(xs)
        foreach(xs) do x
            ys[x] = x^2
        end
        @test ys == xs .^ 2
    end
end

@testset "foreach((i, x) -> ys[i] = x^2, eachindex(ys, xs), xs)" begin
    test_all_implementations(:foreach) do foreach
        xs = 11:15
        ys = zero(xs)
        foreach(eachindex(ys, xs), xs) do i, x
            ys[i] = x^2
        end
        @test ys == xs .^ 2
    end
end

@testset "map!(x -> x^2, ys, xs)" begin
    test_all_implementations(:map!) do map!
        xs = 11:15
        ys = zero(xs)
        map!(x -> x^2, ys, xs)
        @test ys == xs .^ 2
    end
end

@testset "map!(+, ys, xs1, xs2)" begin
    test_all_implementations(:map!) do map!
        xs1 = 1:5
        xs2 = xs1 .* 10
        ys = zero(xs1)
        map!(+, ys, xs1, xs2)
        @test ys == xs1 .+ xs2
    end
end

end  # module
