    ThreadsX.map!(f, dest, inputs...; basesize, simd)

Parallelized `map!`.  See also [`foreach`](@ref).

# Limitations

Note that the behavior is undefined when using `dest` whose distinct
indices refer to the same memory location.  In particular:

* `SubArray` with overlapping indices. For example, `view(zeros(2),
  [1, 1, 2, 2])` is unsupported but `view(zeros(10), [1, 5, 4, 7])` is
  safe to use.
* `BitArray` (currently unsupported)
