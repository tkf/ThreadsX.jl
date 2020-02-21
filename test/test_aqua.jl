module TestAqua

import Aqua
import ThreadsX
using Test

# Default `Aqua.test_all(ThreadsX)` does not work due to ambiguities
# in upstream packages.

@testset "Method ambiguity" begin
    Aqua.test_ambiguities(ThreadsX)
end

@testset "Unbound type parameters" begin
    Aqua.test_unbound_args(ThreadsX)
end

@testset "Undefined exports" begin
    Aqua.test_undefined_exports(ThreadsX)
end

@testset "Compare Project.toml and test/Project.toml" begin
    Aqua.test_project_extras(ThreadsX)
end

end  # module
