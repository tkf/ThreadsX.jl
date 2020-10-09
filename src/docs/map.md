    ThreadsX.mapi(f, iterators...; basesize)

Parallelized `map(f, iterators...)`.  Input collections `iterators`
must support `SplittablesBase.halve`
