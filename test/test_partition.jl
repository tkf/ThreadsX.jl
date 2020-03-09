module TestPartition

using Test
using ThreadsX.Implementations: adhoc_partition

@testset for input_length in 1:100, partition_size in 1:100
    @test collect(adhoc_partition(1:input_length, partition_size)) ==
        collect(Iterators.partition(1:input_length, partition_size))
end

end  # module
