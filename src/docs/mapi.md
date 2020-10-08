    ThreadsX.mapi(f, iterators...; basesize, ntasks)

Parallelized `map(f, iterators...)` that works with purely sequential
`iterators`.

Note that calls to `iterate` on `iterators` are *not* parallelized.
Only `f` may be called in parallel.
