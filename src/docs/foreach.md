    ThreadsX.foreach(f, arrays...; basesize)

A parallel version of

``````julia
for args in zip(arrays...)
    f(args...)
end
``````

`ThreadsX.foreach` uses linear and Cartesian indexing of `arrays`
appropriately.  However, it is likely very slow for sparse arrays.

# Examples

```julia
julia> using ThreadsX

julia> xs = 1:10; ys = similar(xs);

julia> ThreadsX.foreach(eachindex(ys, xs)) do I
           @inbounds ys[I] = xs[I]
       end
```

As `foreach` can only be used for side-effects, it is likely that it
has to be used with `eachindex`.

To avoid cumbersome indexing, a powerful pattern is to use
[Referenceables.jl](https://github.com/tkf/Referenceables.jl) with
`foreach`:

```julia
julia> using Referenceables  # exports `referenceable`

julia> ThreadsX.foreach(referenceable(ys), xs) do y, x
           y[] = x
       end
```

Note that `y[]` does not have to be marked by `@inbounds` as it is
ensured to be the reference to the valid location in the array.

Above function can also be written using [`map!`](@ref).  `foreach` is
useful when, e.g., there are multiple outputs:

```julia
julia> A = randn(10, 10); sums = similar(A); muls = similar(A);

julia> ThreadsX.foreach(referenceable(sums), referenceable(muls), A, A') do s, m, x, y
           s[] = x + y
           m[] = x * y
       end
```

Above code _fuses_ the computation of `sums .= A .+ A'` and
`muls .= A .* A'` and runs it in parallel.

`foreach` can also be used when the array is both input and output:

```julia
julia> ThreadsX.foreach(referenceable(A)) do x
           x[] *= 2
       end
```
