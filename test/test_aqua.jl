module TestAqua

import Aqua
import Setfield
import ThreadsX

Aqua.test_all(
    ThreadsX;
    # https://github.com/JuliaCollections/DataStructures.jl/pull/511
    ambiguities=(exclude=[Base.get, Setfield.set, Setfield.modify],),
)

end  # module
