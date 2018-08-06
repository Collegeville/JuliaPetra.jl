
export SrcDistRowMatrix, DistRowMatrix, RowMatrix
export isFillActive, isLocallyIndexed
export getGraph, getGlobalRowCopy, getLocalRowCopy, getGlobalRowView, getLocalRowView, getLocalDiagCopy, leftScale!, rightScale!

"""
RowMatrix is the base type for all row oriented Petra matrices.
RowMatrix fufils both the Operator and DistObject interfaces.

    getGraph(mat::RowMatrix)::RowGraph
Returns the graph that represents the structure of the row matrix

    getLocalRowCopy!(copy::Tuple{<:AbstractVector{<:Integer}, <:AbstractVector{Data}}, matrix::RowMatrix{Data, GID, PID, LID}, localRow::LID)::Integer
Copies the given row into the provided arrays and returns the number of elements in that row using local indices

    getGlobalRowCopy!(copy::Tuple{<:AbstractVector{<:Integer}, <:AbstractVector{Data}}, matrix::RowMatrix{Data, GID, PID, LID}, globalRow::GID)::Integer
Copies the given row into the provided arrays and returns the number of elements in that row using global indices

    getGlobalRowView(matrix::RowMatrix{Data, GID, PID, LID}, globalRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}
Returns a view to the given row using global indices

    getLocalRowView(matrix::RowMatrix{Data, GID, PID, LID},localRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}
Returns a view to the given row using local indices

    getLocalDiagCopy!(copy::MultiVector{Data, GID, PID, LID}, matrix::RowMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID}
Copies the local diagonal into the given `MultiVector` then returns the `MultiVector`

    leftScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::AbstractArray{Data, 1})
Scales matrix on the left with X

    rightScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::AbstractArray{Data, 1})
Scales matrix on the right with X


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


Some pre-implemented methods can be optimized by providing specialized implementations
`apply!`, as mentioned above
All `RowMatrix` methods that are also implemented by `RowGraph` are implemented using `getGraph`.
`pack` is implemented using `getLocalRowCopy`
`getGlobalRowCopy!` is implemented by calling `getLocalRowCopy!` and remapping the values using `gid(::BlockMap, ::Integer)`
"""
abstract type RowMatrix{Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer} <: AbstractArray{Data, 2}
end

#REVIEW look into requiring A_mul_B! instead and having apply! call that

isFillActive(matrix::RowMatrix) = !isFillComplete(matrix)
isLocallyIndexed(matrix::RowMatrix) = !isGloballyIndexed(matrix)

function leftScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}) where {
        Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    if numVectors(X) != 1
        throw(InvalidArgumentError("Can only scale row matrix with column vector, not multi vector"))
    end
    leftScale!(matrix, getLocalArray(X))
end

function rightScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}) where {
        Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    if numVectors(X) != 1
        throw(InvalidArgumentError("Can only scale row matrix with column vector, not multi vector"))
    end
    rightScale!(matrix, getLocalArray(X))
end

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
    getGlobalRowCopy(matrix::RowMatrix{Data, GID, PID, LID}, globalRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}

Returns a copy of the given row using global indices
"""
Base.@propagate_inbounds function getGlobalRowCopy(matrix::RowMatrix{Data, GID, PID, LID}, globalRow::Integer) where {Data, GID, PID, LID}
    numEntries = getNumEntriesInGlobalRow(matrix, globalRow)
    copy = (Vector{GID}(numEntries), Vector{Data}(numEntries))
    getGlobalRowCopy!(copy, matrix, globalRow)
    copy
end

"""
    getLocalRowCopy(matrix::RowMatrix{Data, GID, PID, LID}, localRow::Integer)::Tuple{AbstractArray{LID, 1}, AbstractArray{Data, 1}}

Returns a copy of the given row using local indices
"""
Base.@propagate_inbounds function getLocalRowCopy(matrix::RowMatrix{Data, GID, PID, LID}, localRow::Integer
        )::Tuple{AbstractArray{LID, 1}, AbstractArray{Data, 1}} where {Data, GID, PID, LID}
    numEntries = getNumEntriesInGlobalRow(matrix, localRow)
    copy = (Vector{LID}(numEntries), Vector{Data}(numEntries))
    getLocalRowCopy!(copy, matrix, localRow)
    copy
end

"""
    getGlobalRowCopy!(copy::Tuple{<:AbstractVector{<:Integer}, <:AbstractVector{Data}}, matrix::RowMatrix{Data, GID, PID, LID}, globalRow::Integer)::Integer

Copies the given row into the provided arrays and returns the number of elements in that row using global indices
"""
Base.@propagate_inbounds function getGlobalRowCopy!(copy::Tuple{<:AbstractVector{<:Integer}, <:AbstractVector{Data}},
            matrix::RowMatrix{Data, GID}, globalRow::Integer) where {Data, GID}
    getGlobalRowCopy!(copy, matrix, GID(globalRow))
end

Base.@propagate_inbounds function getGlobalRowCopy!(copy::Tuple{<:AbstractVector{<:Integer}, <:AbstractVector{Data}},
            matrix::RowMatrix{Data, GID}, globalRow::GID) where {Data, GID}
    rowMap = getRowMap(matrix)
    numElts = getLocalRowCopy!(copy, matrix, lid(rowMap, globalRow))
    inds = copy[1]
    @. inds = gid(rowMap, inds)
    numElts
end

"""
    getLocalRowCopy!(copy::Tuple{<:AbstractVector{LID}, <:AbstractVector{Data}}, matrix::RowMatrix{Data, GID, PID, LID}, localRow::Integer)::Integer

Copies the given row into the provided arrays and returns the number of elements in that row using local indices
"""
Base.@propagate_inbounds function getLocalRowCopy!(copy::Tuple{<:AbstractVector{LID}, <:AbstractVector{Data}},
            matrix::RowMatrix{Data, GID, PID, LID}, localRow::Integer) where {Data, GID, PID, LID}
    getLocalRowCopy!(copy, matrix, LID(localRow))
end

"""
    getLocalDiagCopy(matrix::RowMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID}

Returns a copy of the diagonal elements on the calling processor
"""
Base.@propagate_inbounds function getLocalDiagCopy(matrix::RowMatrix{Data, GID, PID, LID}) where {Data, GID, PID, LID}
    copy = DenseMultiVector{Data}(getRowMap(matrix), 1, false)
    getLocalDiagCopy!(copy, matrix)
    copy
end

function packAndPrepare(source::RowMatrix{Data, GID, PID, LID},
        target::RowMatrix{Data, GID, PID, LID}, exportLIDs::AbstractArray{LID, 1},
        distor::Distributor{GID, PID, LID})::AbstractArray where {Data, GID, PID, LID}
    pack(source, exportLIDs, distor)
end

"""
    pack(::RowMatrix{Data, GID, PID, LID}, exportLIDs::AbstractVector{LID}, distor::Distributor{GID, PID, LID})::AbstractArray{Tuple{AbstractVector{GID}, AbstractVector{Data}}}
Packs this object's data for import or export
"""
function pack(source::RowMatrix{Data, GID, PID, LID}, exportLIDs::AbstractVector{LID},
        distor::Distributor{GID, PID, LID})::AbstractArray{Tuple{AbstractVector{GID}, AbstractVector{Data}}} where{Data, GID, PID, LID}
    srcMap = getMap(source)
    map(lid->getGlobalRowCopy(source, gid(srcMap, lid)), exportLIDs)
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
            importMV = Nullable{MultiVector{Data, GID, PID, LID}}(DenseMultiVector{Data}(colMap, numVecs))
            setColumnMapMultiVector(mat, importMV)
        end
        importMV
    else
        Nullable{MultiVector{Data, GID, PID,D}}()
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
            exportMV = Nullable{MultiVector{Data, GID, PID, LID}}(DenseMultiVector{Data}(rowMap, numVecs))
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

    const rawY = getLocalArray(Y)
    const rawX = getLocalArray(Y)

    maxElts = getLocalMaxNumRowEntries(A)
    indices = Vector{LID}(maxElts)
    values = Vector{LID}(maxElts)

    if !isTransposed(mode)
        numRows = getLocalNumRows(A)
        for vect = LID(1):numVectors(Y)
            @inbounds for row = LID(1):numRows
                sum::Data = Data(0)
                numElts = getLocalRowCopy!((indices, values), A, row)
                for i in LID(1):numElts
                    ind::LID = indices[i]
                    val::Data = values[i]
                    sum += val*rawX[ind, vect]
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
            @inbounds for mRow in LID(1):numRows
                numElts = getLocalRowCopy!((indices, values), A, row)
                for i in LID(1):numElts
                    ind::LID = indices[i]
                    val::Data = values[i]
                    rawY[ind, vect] += applyConjugation(mode, alpha*rawX[mRow, vect]*val)
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
Base.@propagate_inbounds getNumEntriesInGlobalRow(mat::RowMatrix, globalRow) = getNumEntriesInGlobalRow(getGraph(mat), globalRow)

"""
    getNumEntriesInLocalRow(mat::RowMatrix, localRow)

Returns the number of entries on the local processor in the given row
"""
Base.@propagate_inbounds getNumEntriesInLocalRow(mat::RowMatrix, localRow) = getNumEntriesInLocalRow(getGraph(mat), localRow)

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


getDomainMap(mat::RowMatrix) = getDomainMap(getGraph(mat))
getRangeMap(mat::RowMatrix) = getRangeMap(getGraph(mat))


#### required method documentation stubs ####

"""
    getGraph(mat::RowMatrix)

Returns the graph that represents the structure of the row matrix
"""
function getGraph end

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
    getLocalDiagCopy!(copy::MultiVector{Data, GID, PID, LID}, matrix::RowMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID}

Copies the local diagonal into the given `MultiVector` then returns the `MultiVector`
"""
function getLocalDiagCopy! end

"""
    leftScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::AbstractArray{Data})

Scales matrix on the left with X
"""
function leftScale! end

"""
    rightScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::AbstractArray{Data})

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
