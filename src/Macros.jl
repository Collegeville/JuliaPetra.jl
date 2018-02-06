#contains random utility macros

"""
Returns the global debug value

Has an optional ignored argument
"""
macro debug()
    if isdefined(Main, :globalDebug)
        Main.globalDebug::Bool
    else
        false
    end
end
