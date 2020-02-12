baremodule ThreadsX

function map end

function mapreduce end
function reduce end

# Functions derived from `reduce`
function sum end
function prod end
function count end
function maximum end
function minimum end

# Functions implemented directly in terms of transducers
function any end
function all end
function findfirst end
function findlast end
function findall end
# function findmax end
# function findmin end
# function argmax end
# function argmin end
function extrema end

module Implementations
using Base: add_sum, mul_prod
using InitialValues: asmonoid
using Transducers: Filter, Map, MapSplat, ReduceIf, reduced, right, tcollect
using ..ThreadsX
include("reduce.jl")
include("map.jl")
end  # module Implementations

end # baremodule ThreadX
