module TestSort

using Random: shuffle
using Test
using ThreadsX

@testset for basesize in 1:8
    @test ThreadsX.sort!(shuffle([1:1000;]), basesize = basesize) == 1:1000
    @test ThreadsX.sort!(shuffle([1:1000;]), basesize = basesize, by = inv) == 1000:-1:1
    @test ThreadsX.sort!([1:1000;], basesize = basesize) == 1:1000
    # Sorting stability:
    @test ThreadsX.sort!([1:1000;], basesize = basesize, by = _ -> 1) == 1:1000
end

@testset "stable sort" begin
    @test ThreadsX.sort(1:45; basesize = 25, by = _ -> 1) == 1:45
    @test ThreadsX.sort(1:1000; basesize = 200, by = _ -> 1) == 1:1000
end

end  # module
