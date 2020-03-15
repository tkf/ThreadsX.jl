var documenterSearchIndex = {"docs":
[{"location":"#ThreadsX.jl-1","page":"Home","title":"ThreadsX.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"ThreadsX\nThreadsX.sort!\nThreadsX.sort\nThreadsX.MergeSort","category":"page"},{"location":"#ThreadsX","page":"Home","title":"ThreadsX","text":"Threads⨉: Parallelized Base functions\n\n(Image: Dev) (Image: GitHub Actions) (Image: Aqua QA)\n\ntl;dr\n\nAdd prefix ThreadsX. to functions from Base to get some speedup, if supported.  Example:\n\nusing ThreadsX\nThreadsX.sum(sin, 1:10_000)\n\nTo find out functions supported by ThreadsX.jl, just type ThreadsX. + <kbd>TAB</kbd> in the REPL:\n\njulia> using ThreadsX\n\njulia> ThreadsX.\nMergeSort       any             findlast        maximum         sort!\nQuickSort       count           foreach         minimum         sum\nSet             extrema         map             prod            unique\nStableQuickSort findall         map!            reduce\nall             findfirst       mapreduce       sort\n\nAPI\n\nThreadsX.jl is aiming at providing API compatible with Base functions to easily parallelize Julia programs.\n\nAll functions that exist directly under ThreadsX namespace are public API and they implement a subset of API provided by Base. Everything inside ThreadsX.Implementations is implementation detail. The public API functions of ThreadsX expect that the data structure and function(s) passed as argument are thread-safe.  For example, ThreadsX.sum(f, array) assumes that executing f(::eltype(array)) and accessing elements as in array[i] from multiple threads is safe.\n\nIn addition to the Base API, all functions accept keyword argument basesize::Integer to configure the number of elements processed by each thread.  A large value is useful for minimizing the overhead of using multiple threads.  A small value is useful for load balancing when the time to process single item varies a lot from item to item. The default value of basesize for each function is currently an implementation detail.\n\nLimitations\n\nKeyword argument dims is not supported yet.\n(There are probably more.)\n\nImplementations\n\nMost of reduce-based functions are implemented as a thin wrapper of Transducers.jl.\n\n\n\n\n\n","category":"module"},{"location":"#ThreadsX.sort!","page":"Home","title":"ThreadsX.sort!","text":"ThreadsX.sort!(xs; [smallsort, smallsize, basesize, alg, lt, by, rev, order])\n\nKeyword Arguments\n\nalg :: Base.Sort.Algorithm: ThreadsX.MergeSort, ThreadsX.QuickSort, ThreadsX.StableQuickSort etc. Base.MergeSort and Base.QuickSort can be used as aliases of ThreadsX.MergeSort and ThreadsX.QuickSort.\nsmallsort :: Union{Nothing,Base.Sort.Algorithm}:  The algorithm to use for sorting small chunk of the input array.\nsmallsize :: Union{Nothing,Integer}: Size of array under which smallsort algorithm is used.  nothing (default) means to use basesize.\nbasesize :: Union{Nothing,Integer}.  Granularity of parallelization. nothing (default) means to choose the default size.\nOther keyword arguments are passed to Base.sort!.\n\n\n\n\n\n","category":"function"},{"location":"#ThreadsX.sort","page":"Home","title":"ThreadsX.sort","text":"ThreadsX.sort(xs; [smallsort, smallsize, basesize, alg, lt, by, rev, order])\n\nSee also ThreadsX.sort!.\n\n\n\n\n\n","category":"function"},{"location":"#ThreadsX.MergeSort","page":"Home","title":"ThreadsX.MergeSort","text":"ThreadsX.MergeSort\n\nParallel merge sort algorithm.\n\nExamples\n\nThreadsX.sort!(x; alg = MergeSort)\n\nis more or less equivalent to\n\nsort!(x; alg = ThreadsX.MergeSort)\n\nalthough ThreadsX.sort! may be faster for very large integer arrays as it also parallelize counting sort.\n\nThreadsX.MergeSort is a Base.Sort.Algorithm, just like Base.MergeSort.  It has a few properties for configuring the algorithm.\n\njulia> using ThreadsX\n\njulia> ThreadsX.MergeSort isa Base.Sort.Algorithm\ntrue\n\njulia> ThreadsX.MergeSort.smallsort === Base.Sort.DEFAULT_STABLE\ntrue\n\nThe properties can be \"set\" by calling the algorithm object itself.  A new algorithm object with new properties given by the keyword arguments is returned:\n\njulia> alg = ThreadsX.MergeSort(smallsort = QuickSort) :: Base.Sort.Algorithm;\n\njulia> alg.smallsort == QuickSort\ntrue\n\njulia> alg2 = alg(basesize = 64, smallsort = InsertionSort);\n\njulia> alg2.basesize\n64\n\njulia> alg2.smallsort === InsertionSort\ntrue\n\nProperties\n\nsmallsort :: Base.Sort.Algorithm: Default to Base.Sort.DEFAULT_STABLE.\nsmallsize :: Union{Nothing,Integer}: Size of array under which smallsort algorithm is used.  nothing (default) means to use basesize.\nbasesize :: Union{Nothing,Integer}.  Base case size of parallel merge. nothing (default) means to choose the default size.\n\n\n\n\n\n\n\n","category":"constant"}]
}