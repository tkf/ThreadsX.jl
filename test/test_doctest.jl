module TestDoctest

import ThreadsX
using Documenter: doctest
using Test

@testset "doctest" begin
    doctest(ThreadsX)
end

end  # module
