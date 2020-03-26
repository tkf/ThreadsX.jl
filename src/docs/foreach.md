    ThreadsX.foreach(f, collections...; basesize, simd)

A parallel version of

``````julia
for args in zip(collections...)
    f(args...)
end
``````

`ThreadsX.foreach` uses linear and Cartesian indexing of `arrays`
appropriately.  However, it is likely very slow for sparse arrays.

Although `ThreadsX.foreach` can be nested, it is highly recommended to
use `CartesianIndices` or `Iterators.product` whenever applicable so
that `ThreadsX.foreach` can load-balance across multiple levels of
loops.  Otherwise (when nesting `ThreadsX.foreach`) it is important to
set `basesize` for outer loops to small values (e.g., `basesize = 1`).

# Keyword Arguments
- `basesize`: The size of base case.
- `simd`: `false`, `true`, `:ivdep`, or `Val` of one of them.  If
  `true`/`:ivdep`, the inner-most loop of each base case is annotated
  by `@simd`/`@simd ivdep`.  This does not occur if `false` (default).

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

Nested loops can be written using `Iterators.product`:

```julia
julia> A = 1:3
       B = 1:2
       C = zeros(3, 2);

julia> ThreadsX.foreach(referenceable(C), Iterators.product(A, B)) do c, (a, b)
           c[] = a * b
       end
       @assert C == A .* reshape(B, 1, :)
```

This is equivalent to the following sequential code

```julia
julia> for j in eachindex(B), i in eachindex(A)
           @inbounds C[i, j] = A[i] * B[j]
       end
       @assert C == A .* reshape(B, 1, :)
```

This loop can be expressed also with explicit indexing (which is
closer to the sequential code):

```julia
julia> ThreadsX.foreach(Iterators.product(eachindex(A), eachindex(B))) do (i, j)
           @inbounds C[i, j] = A[i] * B[j]
       end
       @assert C == A .* reshape(B, 1, :)

julia> ThreadsX.foreach(CartesianIndices(C)) do I
           @inbounds C[I] = A[I[1]] * B[I[2]]
       end
       @assert C == A .* reshape(B, 1, :)
```

Note the difference in the ordering in the syntax; i.e., `for j in
eachindex(B), i in eachindex(A)` and `Iterators.product(eachindex(A),
eachindex(B))`.  These are equivalent in the sense `eachindex(A)` is
the inner most loop in both cases.
