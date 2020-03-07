module TestSort

using Random: shuffle
using Test
using ThreadsX

@testset for basesize in 1:8
    @testset for alg in [ThreadsX.MergeSort, ThreadsX.QuickSort, ThreadsX.StableQuickSort]
        @test ThreadsX.sort!(shuffle([1:1000;]), basesize = basesize) == 1:1000
        @test ThreadsX.sort!(shuffle([1:1000;]), basesize = basesize, by = inv) == 1000:-1:1
        @test ThreadsX.sort!([1:1000;], basesize = basesize) == 1:1000
    end
end

@testset "stable sort" begin
    @testset for alg in [ThreadsX.MergeSort, ThreadsX.StableQuickSort]
        @test ThreadsX.sort(1:45; alg = alg, basesize = 25, by = _ -> 1) == 1:45
        @test ThreadsX.sort(1:1000; alg = alg, basesize = 200, by = _ -> 1) == 1:1000
    end
end

end  # module
