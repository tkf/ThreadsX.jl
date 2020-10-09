    ThreadsX.mapi(f, iterators...; basesize, ntasks)

Parallelized `map(f, iterators...)` that works with purely sequential
`iterators`.

Note that calls to `iterate` on `iterators` are *not* parallelized.
Only `f` may be called in parallel.  See also
`Transducers.NondeterministicThreading` for more information.

!!! note
    Currently, the default `basesize` is 1.  However, it may be
    changed in the future (e.g. it may be automatically tuned at
    run-time).

# Keyword Arguments
- `basesize::Integer`: The number of input elements to be accumulated
  in a buffer before sent to a task.
- `ntasks::Integer`: The number of tasks `@spawn`ed.  The default
  value is `Threads.nthreads()`.  A number larger than
  `Threads.nthreads()` may be useful if the inner reducing function
  contains I/O and does not consume too much resource (e.g., memory).
