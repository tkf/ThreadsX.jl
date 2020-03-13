    ThreadsX.sort!(xs; [smallsort, smallsize, basesize, alg, lt, by, rev, order])

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
- Other keyword arguments are passed to `Base.sort!`.
