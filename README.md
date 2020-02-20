# ThreadsX: `$nthreads x` faster functions with `Base` API

## tl;dr

Add prefix `ThreadsX.` to functions from `Base` to get some speedup,
if supported.  Example:

```julia
using ThreadsX
ThreadsX.sum(sin, 1:10_000)
```

To find out functions supported by ThreadsX.jl, just type
`ThreadsX.` + <kbd>TAB</kbd> in the REPL:

```julia
julia> using ThreadsX

julia> ThreadsX.
all       count     findall   findlast  mapreduce minimum   reduce    sort!
any       extrema   findfirst map       maximum   prod      sort      sum
```

## API

ThreadsX.jl is aiming at providing API compatible with `Base`
functions to easily parallelize Julia programs.

All functions that exist directly under `ThreadsX` namespace are
public API and they implement a subset of API provided by `Base`.
Everything inside `ThreadsX.Implementations` is implementation detail.
The public API functions of `ThreadsX` expect that the data structure
and function(s) passed as argument are thread-safe.  For example,
`ThreadsX.sum(f, array)` assumes that executing `f(::eltype(array))`
and accessing elements as in `array[i]` from multiple threads is safe.

In addition to the `Base` API, all functions accept keyword argument
`basesize::Integer` to configure the number of elements processed by
each thread.  A large value is useful for minimizing the overhead of
using multiple threads.  A small value is useful for load balancing
when the time to process single item varies a lot from item to item.
The default value of `basesize` for each function is currently an
implementation detail.

## Limitations

* Keyword argument `dims` is not supported yet.
* Keyword argument `alg` for sort functions is not supported.
* (There are probably more.)

## Implementations

Most of `reduce`-based functions are implemented as a thin wrapper of
[`Transducers.jl`](https://github.com/tkf/Transducers.jl).
