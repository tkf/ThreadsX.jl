baremodule ThreadsX

function collect end
function map end
function mapi end

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
function issorted end
function unique end
function Set end

function foreach end
function map! end

function sort end
function sort! end

module Implementations
import SplittablesBase
using ArgCheck: @argcheck, @check
using BangBang: SingletonVector, append!!, push!!, union!!
using Base:
    HasShape, IteratorSize, Ordering, add_sum, mapreduce_empty, mul_prod, reduce_empty
using ConstructionBase: setproperties
using InitialValues: asmonoid
using MicroCollections: EmptyVector
using Referenceables: referenceable
using Setfield: @set
using Transducers:
    Cat,
    Empty,
    Filter,
    Init,
    Map,
    MapSplat,
    NondeterministicThreading,
    OnInit,
    ReduceIf,
    Transducers,
    extract_transducer,
    foldxl,
    opcompose,
    reduced,
    right,
    tcollect,
    tcopy
using ..ThreadsX

if isdefined(Base.Experimental, :Tapir)
    using Base.Experimental.Tapir: @sync, @spawn
else
    using Base.Threads: @sync, @spawn
end

if isdefined(Transducers, :foldxt)
    using Transducers: foldxt
else
    foldxt(rf, xf, xs; kw...) = reduce(rf, xf, xs; kw...)
    foldxt(rf, xs; kw...) = reduce(rf, Map(identity), xs; kw...)
end

include("utils.jl")
include("basesizes.jl")
include("reduce.jl")
include("foreach.jl")
include("map.jl")
include("mergesort.jl")
include("quicksort.jl")
include("countingsort.jl")
end  # module Implementations

const MergeSort = Implementations.ParallelMergeSortAlg()
const QuickSort = Implementations.ParallelQuickSortAlg()
const StableQuickSort =
    Implementations.ParallelQuickSortAlg(smallsort = MergeSort.smallsort)

Implementations.define_docstrings()

end # baremodule ThreadX
