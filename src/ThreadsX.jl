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
function unique end

function sort end
function sort! end

module Implementations
using BangBang: append!!, push!!, union!!
using Base: add_sum, mapreduce_empty, mul_prod, reduce_empty
using InitialValues: Init, asmonoid
using Transducers:
    Empty, Filter, Map, MapSplat, OnInit, ReduceIf, Transducers, reduced, right, tcollect
using ..ThreadsX

@static if VERSION >= v"1.3-alpha"
    using Base.Threads: @spawn
else
    # Mock `@spawn` using `@async`:
    @eval const $(Symbol("@spawn")) = $(Symbol("@async"))
end

include("reduce.jl")
include("map.jl")
include("sort.jl")
end  # module Implementations

end # baremodule ThreadX
