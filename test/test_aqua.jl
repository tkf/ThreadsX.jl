module TestAqua

import Aqua
import ThreadsX
using Test

# Default `Aqua.test_all(ThreadsX)` does not work due to ambiguities
# in upstream packages.
Aqua.test_all(
    ThreadsX;
    ambiguities = false,
    project_extras = true,
    stale_deps = true,
    deps_compat = true,
    project_toml_formatting = true,
)

@testset "Method ambiguity" begin
    Aqua.test_ambiguities(ThreadsX)
end

end  # module
