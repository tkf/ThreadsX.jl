module TestCopy

using Test
using ThreadsX

@testset "copy vector" begin
    @testset for basesize in [[nothing]; 1:8], n in 0:10, T in [Int, Any]
        ys = Vector{T}(undef, n)
        if basesize === nothing
            @test ThreadsX.copyto!(ys, 1:n) == 1:n
            @test ThreadsX.copy!(ys, 1:n) == 1:n
        else
            @test ThreadsX.copyto!(ys, 1:n; basesize = basesize) == 1:n
            @test ThreadsX.copy!(ys, 1:n; basesize = basesize) == 1:n
        end
    end
end

@testset "copy matrix" begin
    @testset for basesize in [[nothing]; 1:8], n in 0:10, m in 1:5, T in [Int, Any]
        A = Matrix{T}(undef, n, m)
        B = reshape(1:n*m, n, m)
        if basesize === nothing
            @test ThreadsX.copyto!(A, B) == B
        else
            @test ThreadsX.copyto!(A, B; basesize = basesize) == B
        end

        Bt = transpose(reshape(1:n*m, m, n))
        if basesize === nothing
            @test ThreadsX.copyto!(A, Bt) == Bt
        else
            @test ThreadsX.copyto!(A, Bt; basesize = basesize) == Bt
        end
    end
end

end  # module
