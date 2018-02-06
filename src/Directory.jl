export Directory

# methods and docs based straight off Epetra_Directory to match Comm

"""
A base type as an interface to allow Map and BlockMap objects to reference non-local
elements.

All subtypes must have the following methods, with DirectoryImpl standing in for
the subtype:

getDirectoryEntries(directory::DirectoryImpl, map::BlockMap, globalEntries::AbstractArray{GID},
        high_rank_sharing_procs::Bool)::Tuple{AbstractArray{PID}, AbstractArray{LID}}
        where GID <: Integer where PID <: Integer where LID <:Integer
    - Returns processor and local id infor for non-local map entries.  Returns a tuple
        containing
            1 - an Array of processors owning the global ID's in question
            2 - an Array of local IDs of the global on the owning processor

gidsAllUniquelyOwned(directory::DirectoryImpl)
    - Returns true if all GIDs appear on just one processor
"""
abstract type Directory{GID <: Integer, PID <:Integer, LID <: Integer}
end