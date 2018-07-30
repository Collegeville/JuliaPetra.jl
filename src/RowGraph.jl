export RowGraph
#required methods
export getRowMap, getColMap, getDomainMap, getRangeMap, getImporter, getExporter
export getGlobalNumRows, getGlobalNumCols, getGlobalNumEntries, getGlobalNumDiags
export getLocalNumRows, getLocalNumCols, getLocalNumEntries, getLocalNumDiags
export getNumEntriesInGlobalRow, getNumEntriesInLocalRow
export getGlobalMaxNumRowEntries, getLocalMaxNumRowEntries
export hasColMap, isLowerTriangular, sUpperTriangular
export isLocallyIndexed, isGloballyIndexed, isFillComplete
export getGlobalRowCopy, getLocalRowCopy, pack
#implemented methods
export isFillActive


"""
RowGraph is the base "type" for all row oriented storage graphs

Instances of these types are required to implement the following submethods

    getRowMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}
Gets the row map for the graph

    getColMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}
Gets the column map for the graph

    getDomainMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}
Gets the domain map for the graph

    getRangeMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}
Gets the range map for the graph

    getImporter(::RowGraph{GID, PID, LID})::Nullable{Import{GID, PID, LID}}
Gets the graph's Import object

    getExporter(::RowGraph{GID, PID, LID})::Nullable{Export{GID, PID, LID}}
Gets the graph's Export object

    getGlobalNumEntries(::RowGraph{GID, PID, LID})::GID
Returns the global number of entries in the graph

    getLocalNumEntries(::RowGraph{GID, PID, LID})::LID
Returns the local number of entries in the graph

    getNumEntriesInGlobalRow(::RowGraph{GID, PID, LID}, row::GID)::LID
Returns the current number of local entries in the given row

    getNumEntriesInLocalRow(::RowGraph{GID, PID, LID}, row::LID)::LID
Returns the current number of local entries in the given row

    getGlobalNumDiags(::RowGraph{GID, PID, LID})::GID
Returns the global number of diagonal entries

    getLocalNumDiags(::RowGraph{GID, PID, LID})::LID
Returns the local number of diagonal entries

    getGlobalMaxNumRowEntries(::RowGraph{GID, PID, LID})::LID
Returns the maximum number of entries across all rows/columns on all processors

    getLocalMaxNumRowEntries(::RowGraph{GID, PID, LID})::LID
Returns the maximum number of entries across all rows/columns on this processor

    hasColMap(::RowGraph{GID, PID, LID})::Bool
Whether the graph has a well-defined column map

    isLowerTriangular(::RowGraph{GID, PID, LID})::Bool
Whether the graph is lower trianguluar

    isUpperTriangular(::RowGraph{GID, PID, LID})::Bool
Whether the graph is upper trianguluar

    isGloballyIndexed(::RowGraph)::Bool
Whether the graph is using global indices

    isFillComplete(::RowGraph)
If the graph is fully build.

    getGlobalRowCopy(::RowGraph{GID, PID, LID}, row::GID)::AbstractArray{GID, 1}
Extracts a copy of the given row of the graph

    getLocalRowCopy(::RowGraph{GID, PID, LID}, row::LID)::AbstractArray{LID, 1}
Extracts a copy of the given row of the graph

    pack(::RowGraph{GID, PID, LID}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID})::AbstractArray{AbstractArray{LID, 1}}
Packs this object's data for import or export
"""
abstract type RowGraph{GID <: Integer, PID <: Integer, LID <: Integer}
end

"""
    isFillActive(::RowGraph)

Whether the graph is being built
"""
isFillActive(graph::RowGraph) = !isFillComplete(graph)


"""
    getNumEntriesInGlobalRow(graph::RowGraph{GID, PID, LID}, row::Integer)::LID

Returns the current number of local entries in the given row
"""
function getNumEntriesInGlobalRow(graph::RowGraph{GID, PID, LID},
        row::Integer)::LID where{GID, PID, LID}
    getNumEntriesInGlobalRow(graph, GID(row))
end

"""
    getNumEntriesInLocalRow(::RowGraph{GID, PID, LID}, row::Integer)::LID

Returns the current number of local entries in the given row
"""
function getNumEntriesInLocalRow(graph::RowGraph{GID, PID, LID},
        row::Integer)::LID where{GID, PID, LID}
    getNumEntriesInLocalRow(graph, LID(row))
end

"""
    getGlobalRowCopy(::RowGraph{GID, PID, LID}, row::Integer)::AbstractArray{GID, 1}

Extracts a copy of the given row of the graph
"""
function getGlobalRowCopy(graph::RowGraph{GID, PID, LID},
        row::Integer)::AbstractArray{GID, 1} where{GID, PID, LID}
    getGlobalRowCopy(graph, GID(row))
end

"""
    getLocalRowCopy(::RowGraph{GID, PID, LID}, row::Integer)::AbstractArray{LID, 1}

Extracts a copy of the given row of the graph.
"""
function getLocalRowCopy(graph::RowGraph{GID, PID, LID},
        row::Integer)::AbstractArray{LID, 1} where{GID, PID, LID}
    getLocalRowCopy(graph, LID(row))
end


"""
    isLocallyIndexed(::RowGraph)::Bool

Whether the graph is using local indices.

The default implementation uses the row graph
"""
isLocallyIndexed(graph::RowGraph) = !isGloballyIndexed(graph)


"""
    getGlobalNumRows(::RowGraph{GID})::GID

Returns the number of global rows in the graph

The default implementation uses the row graph
"""
getGlobalNumRows(graph::RowGraph) = numAllElements(getRowMap(graph))

"""
    getGlobalNumCols(::RowGraph{GID})::GID

Returns the number of global columns in the graph

The default implementation uses the row graph
"""
getGlobalNumCols(graph::RowGraph) = numAllElements(getColMap(graph))

"""
    getLocalNumRows(::RowGraph{GID, PID, LID})::LID

Returns the number of rows owned by the calling process

The default implementation uses the row graph
"""
getLocalNumRows(graph::RowGraph) = numMyElements(getRowMap(graph))

"""
    getLocalNumCols(::RowGraph{GID, PID, LID})::LID

Returns the number of columns owned by the calling process

The default implementation uses the row graph
"""
getLocalNumCols(graph::RowGraph) = nulMyElements(getColMap(graph))


#### SrcDistObject methods ####
getMap(graph::RowGraph) = getRowMap(graph)


#### documentation for required methods ####

"""
    isFillComplete(mat::RowGraph)

Whether `fillComplete(...)` has been called
"""
function isFillComplete end

"""
    getRowMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}

Gets the row map for the graph
"""
function getRowMap end

"""
    getColMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}

Gets the column map for the graph
"""
function getColMap end

"""
    hasColMap(::RowGraph{GID, PID, LID})::Bool

Whether the graph has a well-defined column map
"""
function hasColMap end

"""
    getDomainMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}

Gets the domain map for the graph
"""
function getDomainMap end

"""
    getRangeMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}

Gets the range map for the graph
"""
function getRangeMap end

"""
    getImporter(::RowGraph{GID, PID, LID})::Nullable{Import{GID, PID, LID}}

Gets the graph's Import object, or null if the import is trivial
"""
function getImporter end

"""
    getExporter(::RowGraph{GID, PID, LID})::Nullable{Export{GID, PID, LID}}

Gets the graph's Export object, or null if the export is trivial
"""
function getExporter end

"""
    getGlobalNumEntries(::RowGraph{GID, PID, LID})::GID

Returns the global number of entries in the graph
"""
function getGlobalNumEntries end

"""
    getLocalNumEntries(::RowGraph{GID, PID, LID})::LID

Returns the local number of entries in the graph
"""
function getLocalNumEntries end

"""
    getNumEntriesInGlobalRow(::RowGraph{GID, PID, LID}, row::GID)::LID

Returns the current number of local entries in the given row
"""
function getNumEntriesInGlobalRow end

"""
    getNumEntriesInLocalRow(::RowGraph{GID, PID, LID}, row::LID)::LID

Returns the current number of local entries in the given row
"""
function getNumEntriesInLocalRow end

"""
    getGlobalNumDiags(::RowGraph{GID, PID, LID})::GID

Returns the global number of diagonal entries
"""
function getGlobalNumDiags end

"""
    getLocalNumDiags(::RowGraph{GID, PID, LID})::LID

Returns the local number of diagonal entries
"""
function getLocalNumDiags end

"""
    getGlobalMaxNumRowEntries(::RowGraph{GID, PID, LID})::LID

Returns the maximum number of entries across all rows/columns on all processors
"""
function getGlobalMaxNumRowEntries end

"""
    getLocalMaxNumRowEntries(::RowGraph{GID, PID, LID})::LID

Returns the maximum number of entries across all rows/columns on the calling processor
"""
function getLocalMaxNumRowEntries end

"""
    isLowerTriangular(::RowGraph{GID, PID, LID})::Bool

Whether the graph is lower trianguluar
"""
function isLowerTriangular end

"""
    isUpperTriangular(::RowGraph{GID, PID, LID})::Bool

Whether the graph is upper trianguluar
"""
function isUpperTriangular end

"""
    isGloballyIndexed(::RowGraph)::Bool

Whether the graph is using global indices
"""
function isGloballyIndexed end

"""
    pack(::RowGraph{GID, PID, LID}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID})::AbstractArray{AbstractArray{LID, 1}}

Packs this object's data for import or export
"""
function pack end
