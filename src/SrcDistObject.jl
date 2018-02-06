
"""
A base type for supporting flexible source distributed objects for import/export operations.

Subtypes must implement a map(::Impl{GID, PID, LID})::BlockMap{GID, PID, LID} method,
where Impl is the subtype
"""
abstract type SrcDistObject{GID <: Integer, PID <: Integer, LID <: Integer}
end

"""
Returns true if this object is a distributed global
"""
function distributedGlobal(obj::SrcDistObject)
    distributedGlobal(map(obj))
end


"""
Get's the Comm instance being used by this object
"""
function comm(obj::SrcDistObject)
    comm(map(obj))
end


#### required method documentation stubs ####

"""
    map(obj::SrcDistObject{GID, PID, LID})::BlockMap{GID, PID, LID}

Gets the `BlockMap` associated with the given SrcDistObject
"""
function map end