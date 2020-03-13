    ThreadsX.MergeSort

Parallel merge sort algorithm.

# Examples
    ThreadsX.sort!(x; alg = MergeSort)

is more or less equivalent to

    sort!(x; alg = ThreadsX.MergeSort)

although `ThreadsX.sort!` may be faster for very large integer arrays
as it also parallelize counting sort.

`ThreadsX.MergeSort` is a `Base.Sort.Algorithm`, just like
`Base.MergeSort`.  It has a few properties for configuring the
algorithm.

```julia
julia> using ThreadsX

julia> ThreadsX.MergeSort isa Base.Sort.Algorithm
true

julia> ThreadsX.MergeSort.smallsort === Base.Sort.DEFAULT_STABLE
true
```

The properties can be "set" by calling the algorithm object itself.  A
new algorithm object with new properties given by the keyword
arguments is returned:

```julia
julia> alg = ThreadsX.MergeSort(smallsort = QuickSort) :: Base.Sort.Algorithm;

julia> alg.smallsort == QuickSort
true

julia> alg2 = alg(basesize = 64, smallsort = InsertionSort);

julia> alg2.basesize
64

julia> alg2.smallsort === InsertionSort
true
```

# Properties
- `smallsort :: Base.Sort.Algorithm`: Default to `Base.Sort.DEFAULT_STABLE`.
- `smallsize :: Union{Nothing,Integer}`: Size of array under which `smallsort`
  algorithm is used.  `nothing` (default) means to use `basesize`.
- `basesize :: Union{Nothing,Integer}`.  Base case size of parallel merge.
  `nothing` (default) means to choose the default size.
