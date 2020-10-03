module TestAqua

import Aqua
import ThreadsX
using Test

# Default `Aqua.test_all(ThreadsX)` does not work due to ambiguities
# in upstream packages.
Aqua.test_all(ThreadsX; ambiguities = false)

@testset "Method ambiguity" begin
    Aqua.test_ambiguities(ThreadsX)
end

end  # module
