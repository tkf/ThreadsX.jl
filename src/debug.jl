"""
    @DBG expression_to_run_only_when_debugging
"""
macro DBG(ex)
    quote
        isdebugging() && $(esc(ex))
        nothing
    end
end

isdebugging() = false
enable_debug() = (@eval isdebugging() = true; nothing)
disable_debug() = (@eval isdebugging() = false; nothing)
