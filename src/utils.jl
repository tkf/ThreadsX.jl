default_basesize(xs) = max(1, length(xs) ÷ (5 * Threads.nthreads()))
