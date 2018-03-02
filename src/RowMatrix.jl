
export SrcDistRowMatrix, DistRowMatrix, RowMatrix
export isFillActive, isLocallyIndexed
export getGraph, getGlobalRowCopy, getLocalRowCopy, getGlobalRowView, getLocalRowView, getLocalDiagCopy, leftScale!, rightScale!

#DECISION are any other mathmatical operations needed?

"""
RowMatrix is the base type for all row oriented Petra matrices

All subtypes must have the following methods, with Impl standing in for the subtype:

    getGraph(mat::RowMatrix)
Returns the graph that represents the structure of the row matrix

    getGlobalRowCopy(matrix::RowMatrix{Data, GID, PID, LID}, globalRow::Integer)::Tuple{AbstractArray{GID, 1}, Array{Data, 1}}
Returns a copy of the given row using global indices

    getLocalRowCopy(matrix::RowMatrix{Data, GID, PID, LID},localRow::Integer)::Tuple{AbstractArray{LID, 1}, AbstractArray{Data, 1}}
Returns a copy of the given row using local indices

    getGlobalRowView(matrix::RowMatrix{Data, GID, PID, LID},globalRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}
Returns a view to the given row using global indices

    getLocalRowView(matrix::RowMatrix{Data, GID, PID, LID},localRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}
Returns a view to the given row using local indices

    getLocalNumDiags(mat::RowMatrix)
Returns the number of diagonal element on the calling processor

    getLocalDiagCopy(matrix::RowMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID}
Returns a copy of the diagonal elements on the calling processor

    leftScale!(matrix::Impl{Data, GID, PID, LID}, X::AbstractArray{Data, 1})
Scales matrix on the left with X

    rightScale!(matrix::Impl{Data, GID, PID, LID}, X::AbstractArray{Data, 1})
Scales matrix on the right with X

    pack(::RowGraph{GID, PID, LID}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID})::AbstractArray{AbstractArray{LID, 1}}
Packs this object's data for import or export


Additionally, the following method must be implemented to fufil the operator interface:

    apply!(matrix::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}, Y::MultiVector{Data, GID, PID, LID}, mode::TransposeMode, alpha::Data, beta::Data)

However, the following methods are implemented by redirecting the call to the matrix's graph by calling `getGraph(matrix)`.
    domainMap(operator::RowMatrix{Data, GID, PID, LID})::BlockMap{GID, PID, LID}

    rangeMap(operator::RowMatrix{Data, GID, PID, LID})::BlockMap{GID, PID, LID}

The required methods from DistObject must also be implemented.  `map(...)`, as required by SrcDistObject, is implemented to forward the call to `rowMap(...)`


The following methods are currently implemented by redirecting the call to the matrix's graph by calling `getGraph(matrix)`.  It is recommended that the implmenting class implements these more efficiently.

    isFillComplete(mat::RowMatrix)
Whether `fillComplete(...)` has been called
    getRowMap(mat::RowMatrix)
Returns the BlockMap associated with the rows of this matrix
    hasColMap(mat::RowMatrix)
Whether the matrix has a column map
    getColMap(mat::RowMatrix)
Returns the BlockMap associated with the columns of this matrix
    isGloballyIndexed(mat::RowMatrix)
Whether the matrix stores indices with global indexes
    getGlobalNumRows(mat::RowMatrix)
Returns the number of rows across all processors
    getGlobalNumCols(mat::RowMatrix)
Returns the number of columns across all processors
    getLocalNumRows(mat::RowMatrix)
Returns the number of rows on the calling processor
    getLocalNumCols(mat::RowMatrix)
Returns the number of columns on the calling processor
    getGlobalNumEntries(mat::RowMatrix)
Returns the number of entries across all processors
    getLocalNumEntries(mat::RowMatrix)
Returns the number of entries on the calling processor
    getNumEntriesInGlobalRow(mat::RowMatrix, globalRow)
Returns the number of entries on the local processor in the given row
    getNumEntriesInLocalRow(mat::RowMatrix, localRow)
Returns the number of entries on the local processor in the given row
    getGlobalNumDiags(mat::RowMatrix)
Returns the number of diagonal elements across all processors
    getGlobalMaxNumRowEntries(mat::RowMatrix)
Returns the maximum number of row entries across all processors
    getLocalMaxNumRowEntries(mat::RowMatrix)
Returns the maximum number of row entries on the calling processor
    isLowerTriangular(mat::RowMatrix)
Whether the matrix is lower triangular
    isUpperTriangular(mat::RowMatrix)
Whether the matrix is upper triangular
"""
abstract type RowMatrix{Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer} <: AbstractArray{Data, 2}
end



function leftScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}) where {
        Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    if numVectors(X) != 1
        throw(InvalidArgumentError("Can only scale CRS matrix with column vector, not multi vector"))
    end
    leftScale!(matrix, X.data)
end

function rightScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}) where {
        Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    if numVectors(X) != 1
        throw(InvalidArgumentError("Can only scale CRS matrix with column vector, not multi vector"))
    end
    rightScale!(matrix, X.data)
end

isFillActive(matrix::RowMatrix) = !isFillComplete(matrix)
isLocallyIndexed(matrix::RowMatrix) = !isGloballyIndexed(matrix)

#for SrcDistObject
function map(matrix::RowMatrix)
    getRowMap(matrix)
end


#TODO document
function getLocalDiagCopyWithoutOffsetsNotFillComplete(A::RowMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID} where {Data, GID, PID, LID}

    localRowMap = getLocalMap(getRowMap(A))
    localColMap = getLocalMap(getColMap(A))
    sorted = isSorted(A.myGraph)

    localNumRows = getLocalNumRows(A)
    diag = MultiVector{Data, GID, PID, LID}(getRowMap(A), 1)
    diagLocal1D = getVectorView(diag, 1)

    range = 1:localNumRows
    for localRowIndex in range
        diagLocal1D[localRowIndex] = 0
        globalIndex = gid(localRowMap, localRowIndex)
        localColIndex = lid(localColMap, globalIndex)
        if localColIndex != 0
            indices, values = getLocalRowView(A, localRowIndex)

            if !sorted
                offset = findfirst(indices, localColumnIndex)
            else
                offset = searchsorted(indices, localColumnIndex)
            end

            if offset <= length(indices)
                diagLocal1D[localRowIndex] = values[offset]
            end
        end
    end
    diag
end


#### default implementations using getGraph(...) ####
"""
    isFillComplete(mat::RowMatrix)

Whether `fillComplete(...)` has been called
"""
isFillComplete(mat::RowMatrix) = isFillComplete(getGraph(mat))

"""
    getRowMap(::RowMatrix{Data, GID, PID, LID})::BlockMap{GID, PID, LID}

Gets the row map for the container
"""
getRowMap(mat::RowMatrix) = getRowMap(getGraph(mat))

"""
    getColMap(::RowMatrix{Data, GID, PID, LID})::BlockMap{GID, PID, LID}

Gets the column map for the container
"""
getColMap(mat::RowMatrix) = getColMap(getGraph(mat))

"""
    hasColMap(::RowMatrix)::Bool

Whether the container has a well-defined column map
"""
hasColMap(mat::RowMatrix) = hasColMap(getGraph(mat))

"""
    isGloballyIndexed(mat::RowMatrix)

Whether the matrix stores indices with global indexes
"""
isGloballyIndexed(mat::RowMatrix) = isGloballyIndexed(getGraph(mat))

"""
    getGlobalNumRows(mat::RowMatrix)

Returns the number of rows across all processors
"""
getGlobalNumRows(mat::RowMatrix) = getGlobalNumRows(getGraph(mat))

"""
    getGlobalNumCols(mat::RowMatrix)

Returns the number of columns across all processors
"""
getGlobalNumCols(mat::RowMatrix) = getGlobalNumCols(getGraph(mat))

"""
    getLocalNumRows(mat::RowMatrix)

Returns the number of rows on the calling processor
"""
getLocalNumRows(mat::RowMatrix) = getLocalNumRows(getGraph(mat))

"""
    getLocalNumCols(mat::RowMatrix)

Returns the number of columns on the calling processor
"""
getLocalNumCols(mat::RowMatrix) = getLocalNumCols(getGraph(mat))

"""
    getGlobalNumEntries(mat::RowMatrix)

Returns the number of entries across all processors
"""
getGlobalNumEntries(mat::RowMatrix) =  getGlobalNumEntries(getGraph(mat))

"""
    getLocalNumEntries(mat::RowMatrix)

Returns the number of entries on the calling processor
"""
getLocalNumEntries(mat::RowMatrix) = getLocalNumEntries(getGraph(mat))

"""
    getNumEntriesInGlobalRow(mat::RowMatrix, globalRow)

Returns the number of entries on the local processor in the given row
"""
getNumEntriesInGlobalRow(mat::RowMatrix, globalRow) = getNumEntriesInGlobalRow(getGraph(mat), globalRow)

"""
    getNumEntriesInLocalRow(mat::RowMatrix, localRow)

Returns the number of entries on the local processor in the given row
"""
getNumEntriesInLocalRow(mat::RowMatrix, localRow) = getNumEntriesInLocalRow(getGraph(mat), localRow)

"""
    getGlobalNumDiags(mat::RowMatrix)

Returns the number of diagonal elements across all processors
"""
getGlobalNumDiags(mat::RowMatrix, gRow) = getGlobalNumDiags(getGraph(mat), gRow)

"""
    getLocalNumDiags(mat::RowMatrix)

Returns the number of diagonal element on the calling processor
"""
getLocalNumDiags(mat::RowMatrix, lRow) = getLocalNumDiags(getGraph(mat), lRow)

"""
    getGlobalMaxNumRowEntries(mat::RowMatrix)

Returns the maximum number of row entries across all processors
"""
getGlobalMaxNumRowEntries(mat::RowMatrix) = getGlobalMaxNumRowEntries(getGraph(mat))

"""
    getLocalMaxNumRowEntries(mat::RowMatrix)

Returns the maximum number of row entries on the calling processor
"""
getLocalMaxNumRowEntries(mat::RowMatrix) = getLocalMaxNumRowEntries(getGraph(mat))

"""
    isLowerTriangular(mat::RowMatrix)

Whether the matrix is lower triangular
"""
isLowerTriangular(mat::RowMatrix) = isLowerTriangular(getGraph(mat))

"""
    isUpperTriangular(mat::RowMatrix)

Whether the matrix is upper triangular
"""
isUpperTriangular(mat::RowMatrix) = isUpperTriangular(getGraph(mat))

"""
    pack(::RowMatrix{GID, PID, LID}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID})::AbstractArray{AbstractArray{GID, 1}, AbstractArray{Data, 1}}

Packs this object's data for import or export
"""
function pack(mat::RowMatrix{Data, GID, PID, LID}, exportLIDs::AbstractArray{LID, 1},
        distor::Distributor{GID, PID, LID}) where {Data, GID, PID, LID}
    throw(InvalidStateError("No pack implementation for objects of type $(typeof(mat))"))
end


getDomainMap(mat::RowMatrix) = getDomainMap(getGraph(mat))
getRangeMap(mat::RowMatrix) = getRangeMap(getGraph(mat))


#### required method documentation stubs ####

"""
    getGraph(mat::RowMatrix)

Returns the graph that represents the structure of the row matrix
"""
function getGraph end

"""
    getGlobalRowCopy(matrix::RowMatrix{Data, GID, PID, LID}, globalRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}

Returns a copy of the given row using global indices
"""
function getGlobalRowCopy end

"""
    getLocalRowCopy(matrix::RowMatrix{Data, GID, PID, LID},localRow::Integer)::Tuple{AbstractArray{LID, 1}, AbstractArray{Data, 1}}

Returns a copy of the given row using local indices
"""
function getLocalRowCopy end

"""
    getGlobalRowView(matrix::RowMatrix{Data, GID, PID, LID},globalRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}

Returns a view to the given row using global indices
"""
function getGlobalRowView end

"""
    getLocalRowView(matrix::RowMatrix{Data, GID, PID, LID},localRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}

Returns a view to the given row using local indices
"""
function getLocalRowView end

"""
    getLocalDiagCopy(matrix::RowMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID}

Returns a copy of the diagonal elements on the calling processor
"""
function getLocalDiagCopy end

"""
    leftScale!(matrix::Impl{Data, GID, PID, LID}, X::AbstractArray{Data})

Scales matrix on the left with X
"""
function leftScale! end

"""
    rightScale!(matrix::Impl{Data, GID, PID, LID}, X::AbstractArray{Data})

Scales matrix on the right with X
"""
function rightScale! end



### Julia Array functions ###
Base.size(mat::RowMatrix) = (getGlobalNumRows(mat), getGlobalNumCols(mat))

#TODO this might break for funky maps, however indices needs to return a unit range
Base.indices(A::RowMatrix{GID}) where GID = if hasColMap(A)
        (minMyGID(rowMap(A)):maxMyGID(rowMap(A)), minMyGID(getColMap(A)):maxMyGID(getColMap(A)))
    else
        (minMyGID(rowMap(A)):maxMyGID(rowMap(A)), GID(1):getGlobalNumCols(A))
    end

function Base.getindex(A::RowMatrix, I::Vararg{Int, 2})
    if isGloballyIndexed(A)
        @boundscheck begin
            (n, m) = size(A)
            if I[1] > n || I[1] < 1 || I[2] > m || I[2] < 1
                throw(BoundsError(A, I))
            end
        end
        (rowInds, rowVals) = getGlobalRowView(A, I[0])
        i = 1
        while i <= length(rowInds)
            if rowInds[i] == I[1]
                return rowVals[i]
            end
        end
    else
        lRow = lid(map(A), I[1])
        lCol = lid(map(A), I[2])
        (rowInds, rowVals) = getLocalRowView(A, lRow)
        i = 1
        while i <= length(rowInds)
            if rowInds[i] == lCol
                return rowVals[i]
            end
        end
    end
    return 0
end

#TODO look into setindex!
