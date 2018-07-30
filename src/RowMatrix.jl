
export SrcDistRowMatrix, DistRowMatrix, RowMatrix
export isFillActive, isLocallyIndexed
export getGraph, getGlobalRowCopy, getLocalRowCopy, getGlobalRowView, getLocalRowView, getLocalDiagCopy, leftScale!, rightScale!

#DECISION are any other mathmatical operations needed?

"""
RowMatrix is the base type for all row oriented Petra matrices.
RowMatrix fufils both the Operator and DistObject interfaces.

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

    getLocalDiagCopy(matrix::RowMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID}
Returns a copy of the diagonal elements on the calling processor

    leftScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::AbstractArray{Data, 1})
Scales matrix on the left with X

    rightScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::AbstractArray{Data, 1})
Scales matrix on the right with X

    pack(::RowMatrix{GID, PID, LID}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID})::AbstractArray{AbstractArray{LID, 1}}
Packs this object's data for import or export



`getMap(...)`, as required by SrcDistObject, is implemented by calling `getRowMap(...)`

`apply!(...)`, as required by Operator, is implemented, but can be optimized by overrideing the following method
    localApply(Y::MultiVector, A::RowMatrix, X::MultiVector, ::TransposeMode, α::Data, β::Data)
Does the computations for `Y = β⋅Y + α⋅A⋅X`, `X` and `Y` match the row map and column map, depending on the transpose mode

The following methods are currently implemented as no-ops, but can be overridden to improve performance.

    setColumnMapMultiVector(::RowMatrix{Data, GID, PID, LID}, ::Nullable{MultiVector{Data, GID, PID, LID}})
Caches a `MultiVector` that uses the matrix's column map.

    getColumnMapMultiVector(::RowMatrix{Data, GID, PID, LID})::Nullable{MultiVector{Data, GID, PID, LID}}
Fetches any cached `MultiVector` that uses the matrix's column map.

    setRowMapMultiVector(::RowMatrix{Data, GID, PID, LID}, ::Nullable{MultiVector{Data, GID, PID, LID}})
Caches a `MultiVector` that uses the matrix's row map.

    getRowMapMultiVector(::RowMatrix{Data, GID, PID, LID})::Nullable{MultiVector{Data, GID, PID, LID}}
Fetches any cached `MultiVector` that uses the matrix's row map.


The following methods are currently implemented by redirecting the call to the matrix's graph by calling `getGraph(matrix)`.  It is recommended that the implmenting class implements these more efficiently if able.

    domainMap(operator::RowMatrix{Data, GID, PID, LID})::BlockMap{GID, PID, LID}
    rangeMap(operator::RowMatrix{Data, GID, PID, LID})::BlockMap{GID, PID, LID}
    getRowMap(mat::RowMatrix)
    getColMap(mat::RowMatrix)
Returns the BlockMap associated with varies sets of indices
    hasColMap(mat::RowMatrix)
Whether the matrix has a column map
    getImporter(mat::RowMatrix)
    getExporter(mat::RowMatrix)
Returns the `Import` and `Export` objects for the matrix
    isFillComplete(mat::RowMatrix)
Whether the matrix structure is fully build.
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
    getLocalNumDiags(mat::RowMatrix)
Returns the number of diagonal element on the calling processor
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

#REVIEW look into requiring A_mul_B! instead and having apply! call that


function leftScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}) where {
        Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    if numVectors(X) != 1
        throw(InvalidArgumentError("Can only scale CSR matrix with column vector, not multi vector"))
    end
    leftScale!(matrix, X.data)
end

function rightScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}) where {
        Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    if numVectors(X) != 1
        throw(InvalidArgumentError("Can only scale CSR matrix with column vector, not multi vector"))
    end
    rightScale!(matrix, X.data)
end

isFillActive(matrix::RowMatrix) = !isFillComplete(matrix)
isLocallyIndexed(matrix::RowMatrix) = !isGloballyIndexed(matrix)

#for SrcDistObject
getMap(matrix::RowMatrix) = getRowMap(matrix)


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


"""
    createColumnMapMultiVector(mat::RowMatrix, x::MultiVector; force=false)::Nullable{MultiVector}

Returns a `Nullable` `MultiVector` that uses the matrix's column map
If `getImporter(mat)` is null (ie a trivial import), then the multivector will only be created if `force` is true.
"""
function createColumnMapMultiVector(mat::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}; force = false) where {Data, GID, PID, LID}
    if !isFillComplete(mat)
        throw(InvalidStateError("Can only call createColumnMapMultiVector if the matrix is fill active"))
    end
    if !hasColMap(mat)
        throw(InvalidStateError("Can only call createColumnMapMultiVector with a matrix that has a column map"))
    end

    numVecs = numVectors(X)
    importer = getImporter(mat)
    colMap = getColMap(mat)

    #if import object is trivial, don't need a seperate column map multivector
    if !isnull(importer) || force
        importMV = getColumnMapMultiVector(mat)
        if isnull(importMV) || numVectors(get(importMV)) != numVecs
            importMV = Nullable(MultiVector{Data}(colMap, numVecs))
            setColumnMapMultiVector(mat, importMV)
        end
        importMV
    else
        Nullable{MultiVector{Data, GID, PID, LID}}()
    end
end

"""
    createRowMapMultiVector(mat::RowMatrix, x::MultiVector; force=false)::Nullable{MultiVector}

Returns a `Nullable` `MultiVector` that uses the matrix's row map
If `getExporter(mat)` is null (ie a trivial export), then the multivector will only be created if `force` is true.
"""
function createRowMapMultiVector(mat::RowMatrix{Data, GID, PID, LID}, Y::MultiVector{Data, GID, PID, LID}; force = false) where {Data, GID, PID, LID}
    if !isFillComplete(mat)
        throw(InvalidStateError("Cannot call createRowMapMultiVector if the matrix is fill active"))
    end

    numVecs = numVectors(Y)
    exporter = getExporter(operator)
    rowMap = getRowMap(mat)

    if !isnull(exporter) || force
        exportMV = getRowMapMultiVector(mat)
        if isnull(exportMV) || getNumVectors(get(exportMV)) != numVecs
            exportMV = Nullable(MultiVector{Data}(rowMap, numVecs))
        end
        exportMV
    else
        Nullable{MultiVector{Data, GID, PID, LID}}()
    end
end


function apply!(Y::MultiVector{Data, GID, PID, LID},
        operator::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID},
        mode::TransposeMode, alpha::Data, beta::Data) where {Data, GID, PID, LID}

    const ZERO = Data(0)

    if isFillActive(operator)
        throw(InvalidStateError("Cannot call apply(...) until fillComplete(...)"))
    end

	if alpha == ZERO
        if beta == ZERO
            fill!(Y, ZERO)
        elseif beta != Data(1)
            scale!(Y, beta)
        end
        return Y
    end

    importer = getImporter(operator)
    exporter = getExporter(operator)

    YIsReplicated = !distributedGlobal(Y)
    YIsOverwritted = (beta == ZERO)
    if YIsReplicated && myPid(getComm(operator)) != 1
        beta = ZERO
    end

    if mode == NO_TRANS
        if isnull(importer)
            XColMap = X
        else
            #need to import source multivector
            XColMap = get(createColumnMapMultiVector(operator, X))
            doImport(X, XColMap, get(importer), INSERT)
        end

        if !isnull(exporter)
            YRowMap = createRowMapMultiVector(operator, Y)
            localApply(YRowMap, operator, XColMap, NO_TRANS, alpha, ZERO)

            if YIsOverwritten
                fill!(Y, ZERO)
            else
                scale!(Y, beta)
            end

            doExport(YRowMap, Y, get(exporter), ADD)
        else
            #don't do export row Map and range map are the same
            if XColMap === Y
                YRowMap = createRowMapMultiVector(operator, Y; force=true)

                if beta != 0
                    copy!(YRowMap, Y)
                end

                localApply(YRowMap, operator, XColmap, NO_TRANS, alpha, ZERO)
                copy!(Y, YRowMap)
            else
                localApply(Y, operator, XColMap, NO_TRANS, alpha, beta)
            end
        end
    else
        if isnull(exporter)
            XRowMap = X
        else
            rowMapMV = get(createRowMapMultiVector(mat, X))
            doImport(X, rowMapMV, get(exporter), INSERT)
            XRowMap = rowMapMV
        end

        if !isnull(importer)
            YColMap = createColumnMapMultiVector(mat, X)
            localApply(get(YColMap), operator, XRowMap, mode, alpha, ZERO)

            if YIsOverwritten
                fill!(Y, ZERO)
            else
                scale!(Y, beta)
            end
            doExport(get(YColMap), Y, get(importer), ADD)
        else
            if XRowMap === Y
                YCopy = copy(Y)
                localApply(YCopy, operator, XRowMap, mode, alpha, beta)
                copy!(Y, YCopy)
            else
                localApply(Y, operator, XRowMap, mode, alpha, beta)
            end
        end
    end
    if YIsReplicated
        commReduce(Y)
    end
    Y
end

function localApply(Y::MultiVector{Data, GID, PID, LID},
        A::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID},
        mode::TransposeMode, alpha::Data, beta::Data) where {Data, GID, PID, LID}

    const rawY = Y.data
    const rawX = X.data

    # can only get a view if the indices are stored locally
    if isLocallyIndexed(A)
        getLocalRow = getLocalRowView
    else
        getLocalRow = getLocalRowCopy
    end

    if !isTransposed(mode)
        numRows = getLocalNumRows(A)
        for vect = LID(1):numVectors(Y)
            for row = LID(1):numRows
                sum::Data = Data(0)
                @inbounds (indices, values) = getLocalRow(A, row)
                for i in LID(1):LID(length(indices))
                    ind::LID = indices[i]
                    val::Data = values[i]
                    @inbounds sum += val*rawX[ind, vect]
                end
                sum = applyConjugation(mode, sum*alpha)
                @inbounds rawY[row, vect] *= beta
                @inbounds rawY[row, vect] += sum
            end
        end
    else
        rawY[:, :] *= beta
        numRows = getLocalNumRows(A)
        for vect = LID(1):numVectors(Y)
            for mRow in LID(1):numRows
                @inbounds (indices, values) = getLocalRow(A, mRow)
                for i in LID(1):LID(length(indices))
                    ind::LID = indices[i]
                    val::Data = values[i]
                    @inbounds rawY[ind, vect] += applyConjugation(mode, alpha*rawX[mRow, vect]*val)
                end
            end
        end
    end

    Y
end



#### default implementations ####

"""
    setColumnMapMultiVector(::RowMatrix{Data, GID, PID, LID}, ::Nullable{MultiVector{Data, GID, PID, LID}})

Caches a `MultiVector` that uses the matrix's column map.
"""
function setColumnMapMultiVector(::RowMatrix{Data, GID, PID, LID}, ::Nullable{MultiVector{Data, GID, PID, LID}}) where{Data, GID, PID, LID}
    Nullable{MultiVector{Data, GID, PID, LID}}()
end

"""
    getColumnMapMultiVector(::RowMatrix{Data, GID, PID, LID})::Nullable{MultiVector{Data, GID, PID, LID}}

Fetches any cached `MultiVector` that uses the matrix's column map.
"""
function getColumnMapMultiVector(::RowMatrix{Data, GID, PID, LID}) where{Data, GID, PID, LID}
    Nullable{MultiVector{Data, GID, PID, LID}}()
end

"""
    setRowMapMultiVector(::RowMatrix{Data, GID, PID, LID}, ::Nullable{MultiVector{Data, GID, PID, LID}})

Caches a `MultiVector` that uses the matrix's row map.
"""
function setRowMapMultiVector(::RowMatrix{Data, GID, PID, LID}, ::Nullable{MultiVector{Data, GID, PID, LID}}) where{Data, GID, PID, LID}
    Nullable{MultiVector{Data, GID, PID, LID}}()
end

"""
    getRowMapMultiVector(::RowMatrix{Data, GID, PID, LID})::Nullable{MultiVector{Data, GID, PID, LID}}

Fetches any cached `MultiVector` that uses the matrix's row map.
"""
function getRowMapMultiVector(::RowMatrix{Data, GID, PID, LID}) where{Data, GID, PID, LID}
    Nullable{MultiVector{Data, GID, PID, LID}}()
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
    getImporter(::RowMatrix{Data, GID, PID, LID})::Nullable{Import{GID, PID, LID}}

Gets the `Import` object for the matrix
"""
getImporter(mat::RowMatrix) = getImporter(getGraph(mat))

"""
    getExporter(::RowMatrix{Data, GID, PID, LID})::Nullable{Export{GID, PID, LID}}

Gets the `Export` object for the matrix
"""
getExporter(mat::RowMatrix) = getExporter(getGraph(mat))

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
getGlobalNumDiags(mat::RowMatrix) = getGlobalNumDiags(getGraph(mat))

"""
    getLocalNumDiags(mat::RowMatrix)

Returns the number of diagonal element on the calling processor
"""
getLocalNumDiags(mat::RowMatrix) = getLocalNumDiags(getGraph(mat))

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
        (minMyGID(getRowMap(A)):maxMyGID(getRowMap(A)), minMyGID(getColMap(A)):maxMyGID(getColMap(A)))
    else
        (minMyGID(getRowMap(A)):maxMyGID(getRowMap(A)), GID(1):getGlobalNumCols(A))
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
        lRow = lid(getMap(A), I[1])
        lCol = lid(getMap(A), I[2])
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
