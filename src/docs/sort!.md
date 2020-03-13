    ThreadsX.sort!(xs; [smallsort, smallsize, basesize, alg, lt, by, rev, order])

Sort a vector `xs` in parallel.

# Examples

```julia
julia> using ThreadsX

julia> ThreadsX.sort!([9, 5, 2, 0, 1])
5-element Array{Int64,1}:
 0
 1
 2
 5
 9

julia> ThreadsX.sort!([0:5;]; alg = ThreadsX.StableQuickSort, by = _ -> 1)
6-element Array{Int64,1}:
 0
 1
 2
 3
 4
 5
```

It is also possible to use `Base.sort!` directly by specifying `alg`
to be one of the parallel sort algorithms provided by ThreadsX:

```julia
julia> sort!([9, 5, 2, 0, 1]; alg = ThreadsX.MergeSort)
5-element Array{Int64,1}:
 0
 1
 2
 5
 9
```

This entry point may be slower than `ThreadsX.sort!` if the input is a
very array of integers with small range.  In this case, `ThreadsX.sort!`
uses parallel counting sort whereas `sort!` uses sequential counting
sort.

# Keyword Arguments
- `alg :: Base.Sort.Algorithm`: `ThreadsX.MergeSort`, `ThreadsX.QuickSort`,
  `ThreadsX.StableQuickSort` etc. `Base.MergeSort` and `Base.QuickSort` can
  be used as aliases of `ThreadsX.MergeSort` and `ThreadsX.QuickSort`.
- `smallsort :: Union{Nothing,Base.Sort.Algorithm}`:  The algorithm to use
  for sorting small chunk of the input array.
- `smallsize :: Union{Nothing,Integer}`: Size of array under which `smallsort`
  algorithm is used.  `nothing` (default) means to use `basesize`.
- `basesize :: Union{Nothing,Integer}`.  Granularity of parallelization.
  `nothing` (default) means to choose the default size.
- For keyword arguments, see `Base.sort!`.
