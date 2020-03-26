module TestForeach

using Test
using ThreadsX
using Referenceables

simdflags = [false, true, :ivdep]

function addavg!(c, a, b)
    c[] += (a + b) / 2
end

@testset for simd in [simdflags; Val.(simdflags)], n in [10, 100, 1000]
    basesize = n^2 ÷ 4

    @testset "linear" begin
        A = randn(n, n)
        B = randn(n, n)
        C0 = randn(n, n)
        C1 = copy(C0)
        foreach(addavg!, referenceable(C0), A, B)
        ThreadsX.foreach(addavg!, referenceable(C1), A, B; simd = simd, basesize = basesize)
        @test C0 == C1
    end

    @testset "cartesian" begin
        A = randn(n, n)
        C0 = randn(n, n)
        C1 = copy(C0)
        foreach(addavg!, referenceable(C0), A, A')
        ThreadsX.foreach(
            addavg!,
            referenceable(C1),
            A,
            A';
            simd = simd,
            basesize = basesize,
        )
        @test C0 == C1
    end
end

@testset begin
    @test_throws(
        ArgumentError("Invalid `simd` option: :invalid"),
        ThreadsX.foreach(identity, 1:0; simd = :invalid),
    )
    @test_throws(Exception, ThreadsX.foreach(identity, 1:0; simd = Val(:invalid)),)
end

end  # module
