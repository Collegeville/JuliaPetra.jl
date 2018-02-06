export getDirectoryEntries, gidsAllUniquelyOwned
export createDirectory

# has to be split from the declaration of Directory due to dependancy on files that require Directory

function getDirectoryEntries(directory::Directory{GID, PID, LID}, map::BlockMap{GID, PID, LID},
        globalEntries::AbstractArray{Number}, high_rank_sharing_procs::Bool=false)::Tuple{AbstractArray{PID}, AbstractArray{LID}} where GID <: Integer where PID <: Integer where LID <: Integer
    getDirectoryEntries(directory, map, Array{GID, 1}(globalEntries), high_rank_sharing_procs)
end

function getDirectoryEntries(directory::Directory{GID, PID, LID}, map::BlockMap{GID, PID, LID},
        globalEntries::AbstractArray{GID})::Tuple{AbstractArray{PID}, AbstractArray{LID}} where GID <: Integer where PID <: Integer where LID <: Integer
    getDirectoryEntries(directory, map, globalEntries, false)
end


"""
    createDirectory(comm::Comm, map::BlockMap)
Create a directory object for the given Map
"""
function createDirectory(comm::Comm{GID, PID, LID}, map::BlockMap{GID, PID, LID})::BasicDirectory{GID, PID, LID} where GID <: Integer where PID <: Integer where LID <: Integer
    BasicDirectory{GID, PID, LID}(map)
end

#### required methods documentation stubs ####

"""
    getDirectoryEntries(directory, map::BlockMap{GID, PID, LID}, globalEntries::AbstractArray{GID}, high_rank_sharing_procs::Bool)::Tuple{AbstractArray{PID}, AbstractArray{LID}}

Returns processor and local id information for non-local map entries.  Returns a tuple containing
1. an Array of processors owning the global ID's in question
2. an Array of local IDs of the global on the owning processor
"""
function getDirectoryEntries end

"""
    gidsAllUniquelyOwned(directory)

Returns true if all GIDs appear on just one processor
"""
function gidsAllUniquelyOwned end