    ThreadsX.QuickSort
    ThreadsX.StableQuickSort

Parallel quick sort algorithms.

See also [`ThreadsX.MergeSort`](@ref).

# Properties
- `smallsort :: Base.Sort.Algorithm`: Default to `Base.Sort.DEFAULT_UNSTABLE`.
- `smallsize :: Union{Nothing,Integer}`: Size of array under which `smallsort`
  algorithm is used.  `nothing` (default) means to use `basesize`.
- `basesize :: Union{Nothing,Integer}`.  Granularity of parallelization.
  `nothing` (default) means to choose the default size.
