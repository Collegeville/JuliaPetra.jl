export LocalCRSGraph, numRows, maxEntry, minEntry

"""
    LocalCRSGraph{EntriesType, IndexType}()
    LocalCRSGraph(entries::AbstractArray{EntriesType, 1}, rowMap::AbstractArray{IndexType, 1})

A compressed row storage array.  Used by CRSGraph to store local structure.
`EntriesType` is the type of the data being held
`IndexType` is the type used to represent the indices
"""
mutable struct LocalCRSGraph{EntriesType, IndexType <: Integer}
    entries::AbstractArray{EntriesType, 1}
    rowMap::AbstractArray{IndexType, 1}
end

function LocalCRSGraph{EntriesType, IndexType}() where{EntriesType, IndexType <: Integer}
    LocalCRSGraph(Array{EntriesType, 1}(0), Array{IndexType, 1}(0))
end


"""
    numRows(::LocalCRSGraph{EntriesType, IndexType})::IndexType

Gets the number of rows in the storage
"""
function numRows(graph::LocalCRSGraph{EntriesType, IndexType})::IndexType where {
        EntriesType, IndexType <: Integer}
    len = length(graph.rowMap) 
    if len != 0
        len - 1
    else
        0
    end
end

"""
    maxEntry(::LocalCRSGraph{EntriesType})::EntriesType

Finds the entry with the maximum value.
"""
function maxEntry(graph::LocalCRSGraph{EntriesType})::EntriesType where {
        EntriesType}
    if length(graph.entries) != 0
        maximum(graph.entries)
    else
        throw(InvalidArgumentError("Cannot find the maximum of an empty graph"))
    end
end

"""
    minEntry(::LocalCRSGraph{EntriesType})::EntriesType

Finds the entry with the minimum value.
"""
function minEntry(graph::LocalCRSGraph{EntriesType})::EntriesType where {
        EntriesType}
    if length(graph.entries) != 0
        minimum(graph.entries)
    else
        throw(InvalidArgumentError("Cannot find the minimum of an empty graph"))
    end
end