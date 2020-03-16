module TestSort

using Random: shuffle
using Test
using ThreadsX

@testset for basesize in 1:8
    @testset for alg in [ThreadsX.MergeSort, ThreadsX.QuickSort, ThreadsX.StableQuickSort]
        @test ThreadsX.sort!(shuffle([1:1000;]); alg = alg, basesize = basesize) == 1:1000
        @test ThreadsX.sort!(
            shuffle([1:1000;]);
            alg = alg,
            basesize = basesize,
            by = inv,
        ) == 1000:-1:1
        @test ThreadsX.sort!([1:1000;]; alg = alg, basesize = basesize) == 1:1000
    end
end

@testset "stable sort" begin
    @testset for alg in [ThreadsX.MergeSort, ThreadsX.StableQuickSort]
        @test ThreadsX.sort(1:45; alg = alg, basesize = 25, by = _ -> 1) == 1:45
        @test ThreadsX.sort(1:1000; alg = alg, basesize = 200, by = _ -> 1) == 1:1000
    end
end

@testset "inplace" begin
    @testset "default" begin
        xs = [1:10;]
        @test ThreadsX.sort!(xs) === xs
        @test issorted(xs)
    end
    @testset for alg in [
        ThreadsX.MergeSort,
        ThreadsX.QuickSort,
        ThreadsX.StableQuickSort,
        MergeSort,
        QuickSort,
    ]
        xs = [1:10;]
        @test ThreadsX.sort!(xs; alg = alg) === xs
        @test issorted(xs)
    end
    @testset for alg in [ThreadsX.MergeSort, ThreadsX.QuickSort, ThreadsX.StableQuickSort]
        xs = [1:10;]
        @test sort!(xs; alg = alg) === xs
        @test issorted(xs)
    end
end

randnans(n) = reinterpret(Float64, [rand(UInt64) | 0x7ff8000000000000 for i in 1:n])

function randn_with_nans(n, p)
    v = randn(n)
    x = findall(rand(n) .< p)
    v[x] = randnans(length(x))
    return v
end

# Taken from "advanced sorting" testset.  This was the only test that
# failed when `fpsort!` was replaced with plain `sort!`.
@testset "NaN" begin
    @testset for n in [0:10; 100; 101; 1000; 1001]
        v = randn_with_nans(n, 0.1)
        @testset for alg in [
                ThreadsX.MergeSort,
                ThreadsX.QuickSort,
                ThreadsX.StableQuickSort,
            ],
            rev in [false, true],
            basesize in 1:8
            # test float sorting with NaNs
            s = ThreadsX.sort(v, alg = alg, rev = rev, basesize = basesize)
            @test issorted(s, rev = rev)
            @test reinterpret(UInt64, v[isnan.(v)]) == reinterpret(UInt64, s[isnan.(s)])
        end
    end
end

@testset "UI" begin
    @test ThreadsX.sort(1:10) == 1:10
    @test ThreadsX.sort(1:10; alg = MergeSort) == 1:10
    @test ThreadsX.sort(1:10; alg = QuickSort) == 1:10
end

end  # module
