default_basesize(n::Integer) = max(1, n ÷ (5 * Threads.nthreads()))
default_basesize(xs) = default_basesize(length(xs))
