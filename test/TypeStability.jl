
#export check_function, check_method
#export StabilityReport, is_stable

#TODO figure out IDE inter-op
#which(func, params).file gives Symbol containing the source file of the function
#which(func, params).line gives Int of line number of source of function


function check_function(func, param_types; unstable_vars=Dict{Symbol, Type}(), unstable_return::Bool=false)
    result = Tuple{Any, StabilityReport}[]
    for params in param_types
        push!(result, (params, check_method(func, params; unstable_vars=unstable_vars, unstable_return=unstable_return)))
    end
    result
end

#Based off julia's code_warntype
function check_method(func, param_types; unstable_vars=Dict{Symbol, Type}(), unstable_return::Bool=false)
    function slots_used(ci, slotnames)
        used = falses(length(slotnames))
        scan_exprs!(used, ci.code)
        return used
    end

    function scan_exprs!(used, exprs)
        for ex in exprs
            if isa(ex, Slot)
                used[ex.id] = true
            elseif isa(ex, Expr)
                scan_exprs!(used, ex.args)
            end
        end
    end

    #loop over possible methods for the given argument types
    code = code_typed(func, param_types)
    if length(code) != 1
        warn("mutliple methods for $func matching $param_types")
    end

    unstable_vars = Array{Tuple{Symbol, Type}, 1}(0)
    unstable_ret = Nullable{Type}()

    for (src, rettyp) in code
        #check variables
        slotnames = Base.sourceinfo_slotnames(src)
        used_slotids = slots_used(src, slotnames)

        if isa(src.slottypes, Array)
            for i = 1:length(slotnames)
                if used_slotids[i]
                    name = Symbol(slotnames[i])
                    typ = src.slottypes[i]
                    if (!isleaftype(typ) || typ == Core.Box) && !(typ <: get(unstable_vars, name, Int64))
                        push!(unstable_var, (name, typ))
                    end

                    #else likely optmized out
                end
            end
        else
            warn("Can't access slot types of CodeInfo")
        end

        if !unstable_return && (!isleaftype(rettyp) || rettyp == Core.Box)
            unstable_ret = Nullable(rettyp)
        end

        #TODO check body
    end

    return StabilityReport(unstable_vars, unstable_ret)
end

struct StabilityReport
    unstable_variables::Array{Tuple{Symbol, Type}, 1}
    unstable_return::Nullable{Type}
end

StabilityReport() = StabilityReport(Array{Tuple{Symbol, Type}, 1}(0), Nullable{Type}())

is_stable(report::StabilityReport) = length(report.unstable_variables) == 0 && isnull(report.unstable_return)
is_stable(reports::Array{Tuple{Any, StabilityReport}}) = all(@. is_stable(getindex(reports, 2)))


function parameter_cartesian(typ::Type, params)
    results = Type[]
    for p in Base.product(params...)
        push!(results, typ{p...})
    end

    results
end
