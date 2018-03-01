export CSRMatrix, insertGlobalValues
#TODO export other CSRMatrix-specific symbols

using TypeStability

mutable struct CSRMatrix{Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer} <: RowMatrix{Data, GID, PID, LID}
    rowMap::BlockMap{GID, PID, LID}
    colMap::Nullable{BlockMap{GID, PID, LID}}

    importMV::Nullable{MultiVector{Data, GID, PID, LID}}
    exportMV::Nullable{MultiVector{Data, GID, PID, LID}}

    myGraph::CRSGraph{GID, PID, LID}

    localMatrix::LocalCSRMatrix{Data, LID}

    values2D::Array{Array{Data, 1}, 1}

    #pull storageStatus and fillComplete  from graph

    #Dict keys are row indices
    #first element of each tuple is a column index
    #second element of each tuple is the matching entry
    nonlocals::Dict{GID, Tuple{Array{Data, 1}, Array{GID, 1}}}

    plist::Dict{Symbol}

    function CSRMatrix{Data, GID, PID, LID}(rowMap::BlockMap{GID, PID, LID}, colMap::Nullable{BlockMap{GID, PID, LID}}, myGraph::CRSGraph{GID, PID, LID}, localMatrix::LocalCSRMatrix{Data, LID}, plist::Dict{Symbol}) where {Data, GID, PID, LID}

        #allocate values
        localNumRows = getLocalNumRows(myGraph)
        if getProfileType(myGraph) == STATIC_PROFILE
            ptrs = myGraph.rowOffsets
            localTotalNumEntries = ptrs[localNumRows+1]

            resize!(localMatrix.values, localTotalNumEntries)

            values2D = Array{Array{Data, 1}, 1}(0)
        else #DYNAMIC_PROFILE
            if isLocallyIndexed(myGraph)
                graphIndices = myGraph.localIndices
            else
                graphIndices = myGraph.globalIndices
            end
            values2D = Array{Array{Data, 1}, 1}(localNumRows)
            for r = 1:length(graphIndices)
                values2D[r] = Array{Array{Data, 1}, 1}(length(graphIndices[r]))
            end
        end

        new(rowMap,
            colMap,
            Nullable{MultiVector{Data, GID, PID, LID}}(),
            Nullable{MultiVector{Data, GID, PID, LID}}(),
            myGraph,
            localMatrix,
            values2D,
            Dict{GID, Tuple{Array{Data, 1}, Array{GID, 1}}}(),
            plist)
    end

end

#### Constructors ####
#TODO document Constructors

function CSRMatrix{Data}(rowMap::BlockMap{GID, PID, LID},
        maxNumEntriesPerRow::Union{Integer, Array{<:Integer, 1}},
        pftype::ProfileType; plist...) where {Data, GID, PID, LID}
    CSRMatrix{Data}(rowMap, maxNumEntriesPerRow, pftype, Dict(Array{Tuple{Symbol, Any}}(plist)))
end
function CSRMatrix{Data}(rowMap::BlockMap{GID, PID, LID},
        maxNumEntriesPerRow::Union{Integer, Array{<:Integer, 1}},
        pftype::ProfileType, plist::Dict{Symbol}) where {Data, GID, PID, LID}
    CSRMatrix{Data}(rowMap, Nullable{BlockMap{GID, PID, LID}}(),
        maxNumEntriesPerRow, pftype, plist)
end

function CSRMatrix{Data}(rowMap::BlockMap{GID, PID, LID},
        colMap::BlockMap{GID, PID, LID},
        maxNumEntriesPerRow::Union{Integer, Array{<:Integer, 1}},
        pftype::ProfileType; plist...) where {Data, GID, PID, LID}
    CSRMatrix{Data}(rowMap, colMap, maxNumEntriesPerRow, pftype, Dict(Array{Tuple{Symbol, Any}}(plist)))
end
function CSRMatrix{Data}(rowMap::BlockMap{GID, PID, LID},
        colMap::BlockMap{GID, PID, LID},
        maxNumEntriesPerRow::Union{Integer, Array{<:Integer, 1}},
        pftype::ProfileType, plist::Dict{Symbol}) where {Data, GID, PID, LID}
    CSRMatrix{Data}(rowMap, Nullable(colMap), maxNumEntriesPerRow,
        pftype, plist)
end

function CSRMatrix{Data}(rowMap::BlockMap{GID, PID, LID},
        colMap::Nullable{BlockMap{GID, PID, LID}},
        maxNumEntriesPerRow::Union{Integer, Array{<:Integer, 1}},
        pftype::ProfileType; plist...) where {Data, GID, PID, LID}
    CSRMatrix{Data}(rowMap, colMap, maxNumEntriesPerRow, pftype, Dict(Array{Tuple{Symbol, Any}}(plist)))
end
function CSRMatrix{Data}(rowMap::BlockMap{GID, PID, LID},
        colMap::Nullable{BlockMap{GID, PID, LID}},
        maxNumEntriesPerRow::Union{Integer, Array{<:Integer, 1}},
        pftype::ProfileType, plist::Dict{Symbol}) where {Data, GID, PID, LID}
    graph = CRSGraph(rowMap, maxNumEntriesPerRow, pftype, plist)

    matrix = CSRMatrix{Data, GID, PID, LID}(rowMap, colMap,
        graph, LocalCSRMatrix{Data, LID}(), plist)

    resumeFill(matrix, plist)

    matrix
end

function CSRMatrix{Data}(graph::CRSGraph{GID, PID, LID}; plist...
        ) where {Data, GID, PID, LID}
    CSRMatrix{Data}(graph, Dict(Array{Tuple{Symbol, Any}}(plist)))
end
function CSRMatrix{Data}(graph::CRSGraph{GID, PID, LID},plist::Dict{Symbol}
        ) where {Data, GID, PID, LID}
    numCols = numMyElements(getColMap(graph))
    localGraph = getLocalGraph(graph)
    val = Array{Data, 1}(length(localGraph.entries))
    localMatrix = LocalCSRMatrix(numCols, val, localGraph)

    CSRMatrix(graph.rowMap, graph.colMap, graph, localMatrix, plist)
end

function CSRMatrix(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        rowOffsets::AbstractArray{LID, 1}, colIndices::AbstractArray{LID, 1}, values::AbstractArray{Data, 1};
        plist...) where {Data, GID, PID, LID}
    CSRMatrix(rowMap, colMap, rowOffsets, colIndices, values, Dict(Array{Tuple{Symbol, Any}}(plist)))
end
function CSRMatrix(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        rowOffsets::AbstractArray{LID, 1}, colIndices::AbstractArray{LID, 1}, values::AbstractArray{Data, 1},
        plist::Dict{Symbol}) where {Data, GID, PID, LID}

    #check user's input.  Might throw on only some processes, causing deadlock
    if length(values) != length(colIndices)
        throw(InvalidArgumentError("values and columnIndices must "
                * "have the same length"))
    end

    graph = CRSGraph(rowMap, colMap, rowOffsets, columnIndices, plist)
    localGraph = getLocalGraph(graph)

    numCols = numMyElements(getColMap(graph))
    localMatrix = LocalCSRMatrix(numCols, values, localGraph)

    CSRMatrix(rowMap, Nullable(colMap), graph, localMatrix, plist)
end

function CSRMatrix(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        localMatrix::LocalCSRMatrix{Data, LID}; plist...
        ) where {Data, GID, PID, LID}
    CSRMatrix(rowMap, colMap, localMatrix, Dict(Array{Tuple{Symbol, Any}}(plist)))
end
function CSRMatrix(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        localMatrix::LocalCSRMatrix{Data, LID}, plist::Dict{Symbol}
        ) where {Data, GID, PID, LID}

    graph = CRSGraph(rowMap, colMap, localMatrix.graph, plist)

    matrix = CSRMatrix(rowMap, colMap, graph, localMatrix, plist)

    computeGlobalConstants(matrix)
    matrix
end

function CSRMatrix(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        localMatrix::AbstractArray{Data, 2}; plist...
        ) where {Data, GID, PID, LID}
    CSRMatrix(rowmap, colMap, localMatrix, Dict(Array{Tuple{Symbol, Any}}(plist)))
end
function CSRMatrix(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        localMatrix::AbstractArray{Data, 2}, plist::Dict{Symbol}
        ) where {Data, GID, PID, LID}
    linearIndices = find(x -> x!=0, localMatrix)
    rowIndicesIter, colIndicesIter, valuesIter = zip(
        sort!(collect(zip(ind2sub(size(localMatrix), linearIndices)...,
                          localMatrix[linearIndices])))...)
    rowIndices = collect(rowIndicesIter)
    rowOffsets = Array{LID, 1}(size(localMatrix, 1)+1)
    row = 1
    j = 1
    for i in 1:length(rowIndices)
        if rowIndices[i] > row
            row += 1
            rowOffsets[row] = i
        end
    end
    rowOffsets[length(rowOffsets)] = length(rowIndices)+1

    CSRMatrix(rowMap, colMap, rowOffsets,
        collect(colIndicesIter), collect(valuesIter), plist)
end


#### Internal methods ####
function combineGlobalValues(matrix::CSRMatrix{Data, GID, PID, LID},
        globalRow::GID, indices::AbstractArray{GID, 1},
        values::AbstractArray{Data, 1}, cm::CombineMode
        ) where {Data, GID, PID, LID}

    if cm == ADD || cm == INSERT
        insertGlobalValuesFiltered(globalRow, indices, values)
    else
        #TODO implement ABSMAX and REPLACE
        #not implmenented in TPetra, because its not a common use case and difficult (see FIXME on line 6225)
        throw(InvalidArgumentError("Not yet implemented for combine mode $cm"))
    end
end

"""
Returns a nullable object of the column map multivector
"""
function getColumnMapMultiVector(mat::CSRMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}, force = false) where {Data, GID, PID, LID}
    if !hasColMap(mat)
        throw(InvalidStateError("Can only call getColumnMapMultiVector with a matrix that has a column map"))
    end
    if !isFillComplete(mat)
        throw(InvalidStateError("Can only call getColumnMapMultiVector if the matrix is fill active"))
    end

    numVecs = numVectors(X)
    importer = getGraph(mat).importer
    colMap = getColMap(mat)

    #if import object is trivial, don't need a seperate column map multivector
    if !isnull(importer) || force
        if isnull(mat.importMV) || numVectors(get(mat.importMV)) != numVecs
            mat.importMV = Nullable(MultiVector{Data, GID, PID, LID}(colMap, numVecs))
        else
            mat.importMV
        end
    else
        Nullable{MultiVector{Data, GID, PID, LID}}()
    end
end

"""
Returns a nullable object of the row map multivector
"""
function getRowMapMultiVector(mat::CSRMatrix{Data, GID, PID, LID}, Y::MultiVector{Data, GID, PID, LID}, force = false) where {Data, GID, PID, LID}
    if !isFillComplete(mat)
        throw(InvalidStateError("Cannot call getRowMapMultiVector wif the matrix is fill active"))
    end

    numVecs = numVectors(Y)
    exporter = getGraph(mat).exporter
    rowMap = getRowMap(mat)

    if !isnull(exporter) || force
        if isnull(mat.exportMV) || getNumVectors(get(map.exportMV)) != numVecs
            mat.exportMV = Nullable(MultiVector(rowMap, numVecs))
        else
            mat.exportMV
        end
    else
        Nullable{MultiVector{Data, GID, PID, LID}}()
    end
end


#does nothing, exists only to be a parallel to CRSGraph
computeGlobalConstants(matrix::CSRMatrix) = nothing

#Tpetra's only clears forbNorm, exists only to be a parallel to CRSGraph
clearGlobalConstants(matrix::CSRMatrix) = nothing

function globalAssemble(matrix::CSRMatrix)
    comm = JuliaPetra.comm(matrix)
    if !isFillActive(matrix)
        throw(InvalidStateError("Fill must be active to call this method"))
    end

    myNumNonLocalRows = length(matrix.nonlocals)
    nooneHasNonLocalRows = maxAll(comm, myNumNonLocalRows == 0)
    if nooneHasNonLocalRows
        #no process has nonlocal rows, so nothing to do
        return
    end

    #nonlocalRowMap = BlockMap{GID, PID, LID}()

    numEntPerNonlocalRow = Array{Integer, 1}(numNonLocalRows)
    myNonlocalGlobalRows = Array{GID, 1}(numNonLocalRows)

    curPos = 1
    for (key, val) in matrix.nonlocal
        myNonlocalGlobalRows[curPos] = key

        values = val[1]
        globalColumns = val[2]

        order = sortperm(globalColumns)
        permute!(globalColumns, order)
        permute!(values, order)


        curPos += 1
    end

    #merge2
    if length(globalColumns) > 0
        setIndex = 1
        valuesSum = 0
        currentIndex = globalColumns[1]
        for i = 1:length(globalColumns)
            if currentIndex != globalColumns[i]
                values[setIndex] = valuesSum
                globalColumns[setIndex] = currentIndex
                setIndex += 1
                valuesSum = 0
            end
            valuesSum += values[i]
            i += 1
        end
        values[setIndex] = valuesSum
        globalColumns[setIndex] = currentIndex

        resize!(values, setIndex)
        resize!(globalColumns, setIndex)
    end

    numEntPerNonloalRow[curPose] = length(globalColumns)


    #don't need to worry about finding the indexBase
    nonlocalRowMap = BlockMap(0, myNonlocalGlobalRows, comm)

    nonlocalMatrix = CSRMatrix(nonlocalRowMap, numEntPernonlocalRow, STATIC_PROFILE)

    curPos = 1
    for (key, val) in matrix.nonlocals
        globalRow = key

        vals = val[1]
        globalCols = val[2]

        insertGlobalValues(nonlocalMatrix, globalRow, globalCols, vals)
    end

    origRowMap = rowMap(matrix)
    origRowMapIsOneToOne = isOneToOne(origRowMap)


    if origRowMapIsOneToOne
        exportToOrig = Export(nonlocalRowMap, origRowMap)
        isLocallyComplete = isLocallyComplete(exportToOrig)
        doExport(nonlocalMatrix, matrix, exportToOrig, ADD)
    else
        oneToOneRowMap = createOneToOne(origRowMap)
        exportToOneToOne = Export(nonlocalRowMap, oneToOneRowMap)

        isLocallyComplete = isLocallyComplete(exportToOneToOne)

        oneToOneMatrix = CSRMatrix{Data}(oneToOneRowMap, 0)

        doExport(nonlocalMatrix, onToOneMatrix, exportToOneToOne, ADD)

        #nonlocalMatrix = null

        importToOrig = Import(oneToOneRowMap, origRowMap)
        doImport(oneToOneMatrix, matrix, importToOrig, ADD)
    end

    empty!(matrix.nonlocals)

    globallyComplete = minAll(comm, isLocallyComplete)
    if !globallyComplete
        throw(InvalidArgumentError("On at least one process, insertGlobalValues "
                * "was called with a global row index which is not in the matrix's "
                * "row map on any process in its communicator."))
    end
end



function fillLocalGraphAndMatrix(matrix::CSRMatrix{Data, GID, PID, LID},
        plist::Dict{Symbol}) where {Data, GID, PID, LID}
    localNumRows = getLocalNumRows(matrix)

    myGraph = matrix.myGraph
    localMatrix = matrix.localMatrix

   matrix.localMatrix.graph.entries = myGraph.localIndices1D

    #most of the debug sections were taken out, they could be re-added wrapped with `if @debug`
    if getProfileType(matrix) == DYNAMIC_PROFILE
        numRowEntries = myGraph.numRowEntries

        ptrs = Array{LID, 1}(localNumRows+1)
        localTotalNumEntries = computeOffsets(ptrs, numRowEntries)

        inds = Array{LID, 1}(localTotalNumEntries)
        #work around type instability required by localMatrix.values
        vals_concrete = Array{Data, 1}(localTotalNumEntries)
        vals = vals_concrete

        localIndices2D = myGraph.localIndices2D
        for row = 1:localNumRows
            numEnt = numRowEnt[row]
            dest = range(ptrs[row], 1, numEnt)

            inds[dest] = localIndices2D[row][:]
            vals_concrete[dest] = matrix.values2D[row][:]
        end
    elseif getProfileType(matrix) == STATIC_PROFILE
        curRowOffsets = myGraph.rowOffsets

        if myGraph.storageStatus == STORAGE_1D_UNPACKED
            #pack row offsets into ptrs

            localTotalNumEntries = 0

            ptrs = Array{LID, 1}(localNumRows + 1)
            numRowEnt = myGraph.numRowEntries
            localTotalNumEntries = computeOffsets(ptrs, numRowEnt)

            inds = Array{LID, 1}(localTotalNumEntries)
            #work around type instability required by localMatrix.values
            vals_concrete = Array{Data, 1}(localTotalNumEntries)
            vals = vals_concrete

            #line 1234
            for row in 1:localNumRows
                srcPos = curRowOffsets[row]
                dstPos = ptrs[row]
                dstEnd = ptrs[row+1]-1
                dst = dstPos:dstEnd
                src = srcPos:srcPos+dstEnd-dstPos

                inds[dst] = myGraph.localIndices1D[src]
                vals_concrete[dst] = localMatrix.values[src]
            end
        else
            #dont have to pack, just set pointers
            ptrs = myGraph.rowOffsets
            inds = myGraph.localIndices1D
            vals = localMatrix.values
        end
    end

    if get(plist, :optimizeStorage, true)
        empty!(myGraph.localIndices2D)
        empty!(myGraph.numRowEntries)

        empty!(matrix.values2D)

        myGraph.rowOffsets = ptrs
        myGraph.localIndices1D = inds

        myGraph.pftype = STATIC_PROFILE
        myGraph.storageStatus = STORAGE_1D_PACKED
    end

    myGraph.localGraph = LocalCRSGraph(inds, ptrs)
    matrix.localMatrix = LocalCSRMatrix(myGraph.localGraph, vals, getLocalNumCols(matrix))
end

function insertNonownedGlobalValues(matrix::CSRMatrix{Data, GID, PID, LID},
        globalRow::GID, indices::AbstractArray{GID, 1}, values::AbstractArray{Data, 1}
        ) where {Data, GID, PID, LID}

    curRow = matrix.nonlocals[globalRow]
    curRowVals = curRow[1]
    curRowInds = curRow[2]

    newCapacity = length(curRowInds) + length(indices)

    append!(curRowVals, values)
    append!(curRowInds, indices)
end

function getView(matrix::CSRMatrix{Data, GID, PID, LID}, rowInfo::RowInfo{LID})::AbstractArray{Data, 1} where {Data, GID, PID, LID}
    if getProfileType(matrix) == STATIC_PROFILE && rowInfo.allocSize > 0
        range = rowInfo.offset1D:rowInfo.offset1D+rowInfo.allocSize-LID(1)
        baseArray = matrix.localMatrix.values
        if baseArray isa Vector{Data}
            view(matrix.localMatrix.values, range)
        else
            view(matrix.localMatrix.values, range)
        end
    elseif getProfileType(matrix) == DYNAMIC_PROFILE
        baseArray = matrix.values2D[rowInfo.localRow]
        view(baseArray, LID(1):LID(length(baseArray)))
    else
        Data[]
    end
end

function getDiagCopyWithoutOffsets(rowMap, colMap, A::CSRMatrix{Data}) where {Data}
    errCount = 0

    D = Array{Data, 1}(getNumLocalRows(A))

    for localRowIndex = 1:length(D)
        D[localRowIndex] = 0
        globalIndex = gid(rowMap, localRowIndex)
        localColIndex = lid(colMap, globalIndex)
        if localColIndex != 0
            colInds, vals = getLocalRowView(A, localRowIndex)

            offset = 1
            numEnt = length(curRow)
            while offset <= numEnt
                if colInds[offset] == localColIndex
                    break;
                end
                offset += 1
            end

            if offset > numEnt
                errCount += 1
            else
                D[localRowIndex] = vals[offset]
            end
        end
    end
    D
end


function sortAndMergeIndicesAndValues(matrix::CSRMatrix{Data, GID, PID, LID},
        sorted, merged) where {Data, GID, PID, LID}
    graph = getGraph(matrix)
    localNumRows = getLocalNumRows(graph)
    totalNumDups = 0

    for localRow in LID(1):localNumRows
        rowInfo = getRowInfo(graph, localRow)
        if !sorted
            inds, vals = getLocalRowView(matrix, rowInfo)

            order = sortperm(inds)
            permute!(inds, order)
            permute!(vals, order)
        end
        if !merged
            totalNumDups += mergeRowIndicesAndValues(matrix, rowInfo)
        end

        recycleRowInfo(rowInfo)
    end

    if !sorted
        graph.indicesAreSorted = true
    end
    if !merged
        graph.nodeNumEntries -= totalNumDups
        graph.noRedundancies = true
    end
end

function mergeRowIndicesAndValues(matrix::CSRMatrix{Data, GID, PID, LID},
        rowInfo::RowInfo{LID})::LID where {Data, GID, PID, LID}

    graph = getGraph(matrix)
    indsView, valsView = getLocalRowView(matrix, rowInfo)

    if rowInfo.numEntries != 0
        newend = 1
        for cur in 2:rowInfo.numEntries
            if indsView[newend]::LID != indsView[cur]::LID
                #new entry, save it
                newend += 1
                indsView[newend] = indsView[cur]::LID
                valsView[newend] = valsView[cur]::Data
            else
                #old entry, merge it
                valsView[newend] += valsView[cur]::Data
            end
        end
    else
        newend = 0
    end

    graph.numRowEntries[rowInfo.localRow] = newend

    rowInfo.numEntries - newend
end



#### External methods ####
#TODO document external methods

function insertGlobalValues(matrix::CSRMatrix{Data, GID, PID, LID}, globalRow::Integer,
        indices::AbstractArray{LID, 1}, values::AbstractArray{Data, 1}
        ) where {Data, GID, PID, LID}
    myGraph = matrix.myGraph

    localRow = lid(getRowMap(matrix), globalRow)

    if localRow == 0
        insertNonownedGlobalValues(matrix, globalRow, indices, values)
    else
        numEntriesToInsert = length(indices)
        if hasColMap(matrix)
            colMap = getColMap(matrix)

            for k = 1:numEntriesToInsert
                if !myGID(colMap, indices[k])
                    throw(InvalidArgumentError("Attempted to insert entries into "
                            * "owned row $globalRow, at the following column indices "
                            * "$indices.  At least one of those indices ($(indices[k])"
                            * ") is not in the column map on this process"))
                end
            end
        end

        rowInfo = getRowInfo(myGraph, localRow)
        curNumEntries = rowInfo.numEntries
        newNumEntries = curNumEntries + length(numEntriesToInsert)
        if newNumEntries > rowInfo.allocSize
            if(getProfileType(matrix) == STATIC_PROFILE
                    && newNumEntries > rowInfo.allocSize)
                throw(InvalidArgumentError("number of new indices exceed "
                        * "statically allocated graph structure"))
            end

            updateGlobalAllocAndValues(myGraph, rowInfo, newNumEntries,
                            matrix.values2D[localRow])

            recycleRowInfo(rowInfo)
            rowInfo = getRowInfo(myGraph, localRow);
        end

        insertIndicesAndValues(myGraph, rowInfo, indices, getView(matrix, rowInfo),
                values, GLOBAL_INDICES)

        recycleRowInfo(rowInfo)
    end
    nothing
end


function resumeFill(matrix::CSRMatrix, plist::Dict{Symbol})
    resumeFill(matrix.myGraph, plist)

    clearGlobalConstants(matrix)
    #graph handles fillComplete variable
end

fillComplete(matrix::CSRMatrix; plist...) = fillComplete(matrix, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))

function fillComplete(matrix::CSRMatrix, plist::Dict{Symbol})
    #TODO figure out if the second arg should be getColMap(matrix)
    fillComplete(matrix, getRowMap(matrix), getRowMap(matrix), plist)
end

function fillComplete(matrix::CSRMatrix{Data, GID, PID, LID},
        domainMap::BlockMap{GID, PID, LID}, rangeMap::BlockMap{GID, PID, LID};
        plist...) where {Data, GID, PID, LID}
    fillComplete(matrix, domainMap, rangeMap, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end

function fillComplete(matrix::CSRMatrix{Data, GID, PID, LID},
        domainMap::BlockMap{GID, PID, LID}, rangeMap::BlockMap{GID, PID, LID},
        plist::Dict{Symbol}) where {Data, GID, PID, LID}
    if isFillComplete(matrix)
        throw(InvalidStateError(
                "Matrix cannot be fill complete when fillComplete(...) is called"))
    end

    const myGraph = matrix.myGraph

    assertNoNonlocalInserts = get(plist, :noNonlocalChanges, false)
    #skipping sort ghosts stuff

    numProcs = numProc(comm(matrix))

    needGlobalAssemble = !assertNoNonlocalInserts && numProcs > 1
    if needGlobalAssemble
        globalAssemble(matrix)
    else
        if numProcs == 1 && length(matrix.nonlocals) != 0
            throw(InvalidStateError("Cannot have nonlocal entries on a serial run.  An invalid entry is present."))
        end
    end

    setDomainRangeMaps(myGraph, domainMap, rangeMap)
    if !hasColMap(myGraph)
        makeColMap(myGraph)
        matrix.colMap = myGraph.colMap
    end

    makeIndicesLocal(myGraph)

    sortAndMergeIndicesAndValues(matrix, isSorted(myGraph), isMerged(myGraph))

    makeImportExport(myGraph)
    computeGlobalConstants(myGraph)

    myGraph.fillComplete = true
    checkInternalState(myGraph)

    fillLocalGraphAndMatrix(matrix, plist)
end


getProfileType(mat::CSRMatrix) = getProfileType(mat.myGraph)
isStorageOptimized(mat::CSRMatrix) = isStorageOptimized(mat.myGraph)


function getLocalDiagOffsets(matrix::CSRMatrix{Data, GID, PID, LID})::AbstractArray{LID, 1} where {Data, GID, PID, LID}
    graph = matrix.myGraph
    localNumRows = getLocalNumRows(graph)
    getLocalDiagOffsets(graph)
end


#### Row Matrix functions ####

isFillActive(mat::CSRMatrix) = isFillActive(mat.myGraph)
isFillComplete(mat::CSRMatrix) = isFillComplete(mat.myGraph)
getRowMap(mat::CSRMatrix) = mat.rowMap
hasColMap(mat::CSRMatrix) = !isnull(mat.colMap)
getColMap(mat::CSRMatrix) = get(mat.colMap)
isGloballyIndexed(mat::CSRMatrix) = isGloballyIndexed(mat.myGraph)
isLocallyIndexed(mat::CSRMatrix)  = isLocallyIndexed(mat.myGraph)
getGraph(mat::CSRMatrix) = mat.myGraph

getGlobalNumRows(mat::CSRMatrix) = getGlobalNumRows(mat.myGraph)
getGlobalNumCols(mat::CSRMatrix) = getGlobalNumCols(mat.myGraph)
getLocalNumRows(mat::CSRMatrix) = getLocalNumRows(mat.myGraph)
getLocalNumCols(mat::CSRMatrix) = numCols(mat.localMatrix)
getGlobalNumEntries(mat::CSRMatrix) = getGlobalNumEntries(mat.myGraph)
getLocalNumEntries(mat::CSRMatrix) = getLocalNumEntries(mat.myGraph)
getNumEntriesInGlobalRow(mat::CSRMatrix, grow) = getNumEntriesInGlobalRow(mat.myGraph, grow)
getNumEntriesInLocalRow(mat::CSRMatrix, lrow) = getNumEntriesInLocalRow(mat.myGraph, lrow)
getGlobalNumDiags(mat::CSRMatrix) = getGlobalNumDiags(mat.myGraph)
getLocalNumDiags(mat::CSRMatrix) = getLocalNumDiags(mat.myGraph)
getGlobalMaxNumRowEntries(mat::CSRMatrix) = getGlobalMaxNumRowEntries(mat.myGraph)
getLocalMaxNumRowEntries(mat::CSRMatrix) = getLocalMaxNumRowEntries(mat.myGraph)

isLowerTriangular(mat::CSRMatrix) = isLowerTriangular(mat.myGraph)
isUpperTriangular(mat::CSRMatrix) = isUpperTriangular(mat.myGraph)

function getGlobalRowCopy(matrix::CSRMatrix{Data, GID, PID, LID},
        globalRow::Integer
        )::Tuple{Array{GID, 1}, Array{Data, 1}} where {Data, GID, PID, LID}
    myGraph = matrix.myGraph

    rowInfo = getRowInfoFromGlobalRow(myGraph, GID(globalRow))
    viewRange = 1:rowInfo.numEntries


    retVal = if rowInfo.localRow != 0
        if isLocallyIndexed(myGraph)
            colMap = getColMap(myGraph)
            curLocalIndices = getLocalView(myGraph, rowInfo)[viewRange]
            curGlobalIndices = @. gid(colMap, curLocalIndices)
        else
            curGlobalIndices = getGlobalView(myGraph, rowInfo)[viewRange]
        end
        curValues = getView(matrix, rowInfo)[viewRange]

        (curGlobalIndices, curValues)
    else
        (GID[], Data[])
    end

    recycleRowInfo(rowInfo)

    retVal
end


function getLocalRowCopy(matrix::CSRMatrix{Data, GID, PID, LID},
        localRow::Integer
        )::Tuple{AbstractArray{LID, 1}, AbstractArray{Data, 1}} where {
        Data, GID, PID, LID}
    myGraph = matrix.myGraph

    rowInfo = getRowInfo(myGraph, LID(localRow))
    viewRange = 1:rowInfo.numEntries

    retVal = if rowInfo.localRow != 0
        if isLocallyIndexed(myGraph)
            curLocalIndices = Array{LID}(getLocalView(myGraph, rowInfo)[viewRange])
        else
            colMap = getColMap(myGraph)
            curGlobalIndices = getGlobalView(myGraph, rowInfo)[viewRange]
            curLocalIndices = @. lid(colMap, curLocalIndices)
        end
        curValues = Array{Data}(getView(matrix, rowInfo)[viewRange])

        (curLocalIndices, curValues)
    else
        (LID[], Data[])
    end

    recycleRowInfo(rowInfo)

    retVal
end


function getGlobalRowView(matrix::CSRMatrix{Data, GID, PID, LID},
        globalRow::Integer
        )::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}} where {
        Data, GID, PID, LID}
    if isLocallyIndexed(matrix)
        throw(InvalidStateError("The matrix is locally indexed, so cannot return a "
                * "view of the row with global column indices.  Use "
                * "getGlobalRowCopy(...) instead."))
    end
    myGraph = matrix.myGraph

    rowInfo = getRowInfoFromGlobalRow(myGraph, globalRow)
    if rowInfo.localRow != 0 && rowInfo.numEntries > 0
        viewRange = 1:rowInfo.numEntries
        indices = getGlobalView(myGraph, rowInfo)[viewRange]
        values = getView(matrix, rowInfo)[viewRange]
    else
        indices = GID[]
        values = Data[]
    end
    recycleRowInfo(rowInfo)
    (indices, values)
end

function getLocalRowView(matrix::CSRMatrix{Data, GID, PID, LID},
        localRow::Integer
        )::Tuple{AbstractArray{LID, 1}, AbstractArray{Data, 1}} where {
        Data, GID, PID, LID}
    rowInfo = getRowInfo(matrix.myGraph, LID(localRow))
    retVal = getLocalRowView(matrix, rowInfo)
    recycleRowInfo(rowInfo)

    retVal
end

function getLocalRowView(matrix::CSRMatrix{Data, GID, PID, LID},
        rowInfo::RowInfo{LID}
        )::Tuple{AbstractArray{LID, 1}, AbstractArray{Data, 1}} where {
        Data, GID, PID, LID}

    if isGloballyIndexed(matrix)
        throw(InvalidStateError("The matrix is globally indexed, so cannot return a "
                * "view of the row with local column indices.  Use "
                * "getLocalalRowCopy(...) instead."))
    end

    const myGraph = matrix.myGraph

    if rowInfo.localRow != 0 && rowInfo.numEntries > 0
        viewRange = LID(1):rowInfo.numEntries
		indices = view(getLocalView(myGraph, rowInfo), viewRange)
        values = view(getView(matrix, rowInfo), viewRange)
    else
        indices = LID[]
        values = Data[]
    end
    (indices, values)
end


TypeStability.@stable_function [(CSRMatrix{D, G, P, L}, L)
                    for (D, G, P, L) in Base.Iterators.product(
                        [Float64, Complex64], #Data
                        [UInt64, Int64, UInt32], #GID
                        [UInt8, Int8, UInt32], #PID
                        [UInt32, Int32]) #LID
] RegexDict((r"rowValues", Any)) begin

function getLocalRowViewPtr end

Base.@propagate_inbounds @inline function getLocalRowViewPtr(
        matrix::CSRMatrix{Data, GID, PID, LID}, localRow::LID
        )::Tuple{Ptr{LID}, Ptr{Data}, LID} where {Data, GID, PID, LID}
    row = LID(localRow)
    const graph = matrix.myGraph

    if getProfileType(graph) == STATIC_PROFILE
        if (@debug) && !hasRowInfo(graph)
            error("Row Info was deleted, but is still needed")
        end
        offset1D = graph.rowOffsets[row]
        numEntries = (length(graph.numRowEntries) == 0 ?
                    graph.rowOffsets[row+1] - offset1D
                    : graph.numRowEntries[row])
        if numEntries > 0
            indicesPtr = pointer(graph.localIndices1D, offset1D)
            rowValues = matrix.localMatrix.values
            if rowValues isa SubArray{Data, 1, Vector{Data}, Tuple{UnitRange{LID}}, true}
                valuesPtr = pointer(rowValues.parent, offset1D + rowValues.indexes[1].start)
            elseif rowValues isa Vector{Data}
                #else should be Vector, but assert anyways
                valuesPtr = pointer(rowValues, offset1D)
            else
                error("localMatrix.values is of unsupported type $(typeof(rowValues)).")
            end

            return (indicesPtr, valuesPtr, numEntries)
        else
            return (C_NULL, C_NULL, 0)
        end
    else #dynamic profile
        indices = graph.localIndices2D[row]
        values = matrix.values2D[row]

        return (pointer(indices, 0), pointer(values, 0), length(indices))
    end
end
end



function getLocalDiagCopy(matrix::CSRMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID} where {Data, GID, PID, LID}
    if !hasColMap(matrix)
        throw(InvalidStateError("This method requires a column map"))
    end

    rowMap = getRowMap(matrix)
    colMap = getColMap(matrix)

    numLocalRows = getLocalNumRows(matrix)

    if isFillComplete(matrix)
        diag = MultiVector{Data, GID, PID, LID}(rowMap, 1, false)


        diag1D = getVectorView(diag, 1)
        localRowMap = getLocalMap(rowMap)
        localColMap = getLocalMap(colMap)
        localMatrix = matrix.localMatrix

        diag1D[:] = getDiagCopyWithoutOffsets(matrix, localRowMap, localColMap, localMatrix)

        diag
    else
        getLocalDiagCopyWithoutOffsetsNotFillComplete(matrix)
    end
end

function leftScale!(matrix::CSRMatrix{Data}, X::AbstractArray{Data, 1}) where {Data <: Number}
    for row in 1:getLocalNumRows(matrix)
        _, vals = getLocalRowView(matrix, row)
        LinAlg.scale!(vals, X[row])
    end
end

function rightScale!(matrix::CSRMatrix{Data}, X::AbstractArray{Data, 1}) where {Data <: Number}
    for row in 1:getLocalNumRows(matrix)
        inds, vals = getLocalRowView(matrix, row)
        for entry in 1:length(inds)
            vals[entry] *= X[inds[entry]]
        end
    end
end


#### DistObject methods ####
function checkSizes(source::RowMatrix{Data, GID, PID, LID},
        target::CSRMatrix{Data, GID, PID, LID})::Bool where {Data, GID, PID, LID}
    true
end


function copyAndPermute(source::RowMatrix{Data, GID, PID, LID},
        target::CSRMatrix{Data, GID, PID, LID}, numSameIDs::LID,
        permuteToLIDs::AbstractArray{LID, 1}, permuteFromLIDs::AbstractArray{LID, 1}
        ) where {Data, GID, PID, LID}
    sourceIsLocallyIndexed = isLocallyIndexed(source)

    srcRowMap = getRowMap(source)
    tgtRowMap = getRowMap(target)

    sameGIDs = @. gid(srcRowMap, collect(1:numSameIDs))
    permuteFromGIDs = @. gid(srcRowMap, permuteFromLIDs)
    permuteToGIDs   = @. gid(srcRowMap, permuteToLIDs)

    for (sourceGID, targetGID) in zip(vcat(sameGIDs, permuteFromGIDs), vcat(sameGIDs, permuteToGIDs))
        if sourceIsLocallyIndexed
            rowInds, rowVals = getGlobalRowCopy(source, sourceGID)
        else
            rowInds, rowVals = getGlobalRowView(source, sourceGID)
        end
        combineGlobalValues(target, targetGID, rowInds, rowVals, INSERT)
    end
end

#TODO move this to RowMatrix.
#DECSION make a packable trait to encompassRowMatrix and RowGraph? as sources, checkSizes handles matching pairs of objects
function packAndPrepare(source::RowMatrix{Data, GID, PID, LID},
        target::CSRMatrix{Data, GID, PID, LID}, exportLIDs::AbstractArray{LID, 1},
        distor::Distributor{GID, PID, LID})::AbstractArray where {Data, GID, PID, LID}
    pack(source, exportLIDs, distor)
end

function pack(source::CSRMatrix{Data, GID, PID, LID}, exportLIDs::AbstractArray{LID, 1},
        distor::Distributor{GID, PID, LID})::AbstractArray where {Data, GID, PID, LID}
    numExportLIDs = length(exportLIDs)

    localMatrix = source.localMatrix
    localGraph = localMatrix.graph

    packed = Array{Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}}(numExportLIDs)
    result = 0
    for i in 1:numExportLIDs
        exportLID = exportLIDs[i]
        start = localGraph.rowOffsets[exportLID]
        last = localGraph.rowOffsets[exportLIDs+1]-1
        numEnt = last - start +1
        if numEnt == 0
            packed[i] = GID[], Data[]
        else
            values = view(localMatrix.values, start:last)
            lids = view(localGraph.entries, start:last)
            gids = @. gid(getColMap(source), lids)
            packed[i] = gids, values
        end
    end
    packed
end

function unpackAndCombine(target::CSRMatrix{Data, GID, PID, LID},
        importLIDs::AbstractArray{LID, 1}, imports::AbstractArray, distor::Distributor{GID, PID, LID},
        cm::CombineMode) where{Data, GID, PID, LID}

    numImportLIDs = length(importLIDs)

    for i = 1:numImportLIDs
        if length(imports[i] > 0) #ensure theres acutually something in the row
            combineGlobalValues(target, importLIDs[i], imports[i][1], imports[i][2], cm)
        end
    end
end


#### Operator methods ####
function apply!(Y::MultiVector{Data, GID, PID, LID},
        operator::CSRMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID},
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

    if mode == NO_TRANS
        applyNonTranspose!(Y, operator, X, alpha, beta)
    else
        applyTranspose!(Y, operator, X, mode, alpha, beta)
    end
end

function applyNonTranspose!(Y::MultiVector{Data, GID, PID, LID}, operator::CSRMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}, alpha::Data, beta::Data) where {Data, GID, PID, LID}
    const ZERO = Data(0)

    #These are nullable
    importer = getGraph(operator).importer
    exporter = getGraph(operator).exporter

    #assumed to be shared by all data structures
    resultComm = comm(Y)

    YIsOverwritten = (beta == ZERO)
    YIsReplicated = !distributedGlobal(Y) && numProc(resultComm) != 0

    #part of special case for replicated MV output
    if YIsReplicated && myPid(resultComm) != 1
        beta = ZERO
    end

    if isnull(importer)
        XColMap = X
    else
        #need to import source multivector

        XColMap = get(getColumnMapMultiVector(operator, X))

        doImport(X, XColMap, get(importer), INSERT)
    end

    YRowMap = getRowMapMultiVector(operator, Y)
    if !isnull(exporter)
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

            YRowMap = getRowMapMultiVector(operator, Y, true)

            if beta != 0
                copy!(YRowMap, Y)
            end

            localApply(YRowMap, operator, XColmap, NO_TRANS, alpha, ZERO)
            copy!(Y, YRowMap)
        else
            localApply(Y, operator, XColMap, NO_TRANS, alpha, beta)
        end
    end

    if YIsReplicated
        commReduce(Y)
    end
    Y
end

function applyTranspose!(Yin::MultiVector{Data, GID, PID, LID}, operator::CSRMatrix{Data, GID, PID, LID}, Xin::MultiVector{Data, GID, PID, LID}, mode::TransposeMode, alpha::Data, beta::Data) where {Data, GID, PID, LID}
    const ZERO = Data(0)

    nVects = numVectors(Xin)
    importer = getGraph(operator).importer
    exporter = getGraph(operator).exporter

    YIsReplicated = distributedGlobal(Yin)
    YIsOverwritted = (beta == ZERO)
    if YIsReplicated && myPID(comm(operator)) != 1
        beta = ZERO
    end

    if isnull(importer)
        X = copy(Xin)
    else
        X
    end

    if !isnull(importer)
        if !isnull(operator.importMV) && getNumVectors(get(operator.importMV)) != nVects
            operator.importMV = Nullable{MultiVector{Data, GID, PID, LID}}()
        end
        if isnull(operator.importMV)
            operator.importMV = Nullable(MultiVector(getColMap(operator), nVects))
        end
    end

    if !isnull(exporter)
        if !isnull(operator.exportMV) && getNumVectors(get(operator.exportMV)) != nVects
            operator.exportMV = Nullable{MultiVector{Data, GID, PID, LID}}()
        end
        if isnull(operator.exportMV)
            operator.exportMV = Nullable(MultiVector(getRowMap(operator), nVects))
        end
    end

    if !isnull(exporter)
        doImport(Xin, get(operator.exportMV), get(exporter), INSERT)
        X = operator.exportMV
    end

    if !isnull(importer)
        localApply(get(operator.importMV), operator, X, mode, alpha, ZERO)

        if YIsOverwritten
            fill!(Yin, ZERO)
        else
            scale!(Yin, beta)
        end
        doExport(get(operator.importMV), Yin, get(importer), ADD)
    else
        if X === Yin
            Y = copy(Yin)
            localApply(Y, operator, X, mode, alpha, beta)
            copy!(Yin, Y)
        else
            localApply(Yin, operator, X, mode, alpha, beta)
        end
    end
    if YIsReplicated
        commReduce(Yin)
    end
    Yin
end

TypeStability.@stable_function [(MultiVector{D, G, P, L}, CSRMatrix{D, G, P, L},
                        MultiVector{D, G, P, L}, TransposeMode, D, D)
                    for (D, G, P, L) in Base.Iterators.product(
                        [Float64, Complex64], #Data
                        [UInt64, Int64, UInt32], #GID
                        [UInt8, Int8, UInt32], #PID
                        [UInt32, Int32]) #LID
# createRowInfo has a nessaccery Union variable
] RegexDict((r"rowValues", Any)) begin
function localApply(Y::MultiVector{Data, GID, PID, LID},
        A::CSRMatrix{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID},
        mode::TransposeMode, alpha::Data, beta::Data) where {Data, GID, PID, LID}

    const rawY = Y.data
    const rawX = X.data


    #TODO implement this better, can BLAS be used?
    if !isTransposed(mode)
        #TODO look at best way to order the loops to avoid cache misses
        # I think this is the better order, since MultiVector is column oriented
        numRows = getLocalNumRows(A)
        for vect = LID(1):numVectors(Y)
            for row = LID(1):numRows
                sum::Data = Data(0)
                @inbounds (indices, values, len) = getLocalRowViewPtr(A, row)
                for i in LID(1):LID(len)
                    ind::LID = unsafe_load(indices, i)
                    val::Data = unsafe_load(values, i)
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
                @inbounds (indices, values, len) = getLocalRowViewPtr(A, mRow)
                for i in LID(1):LID(len)
                    ind::LID = unsafe_load(indices, i)
                    val::Data = unsafe_load(values, i)
                    @inbounds rawY[ind, vect] += applyConjugation(mode, alpha*rawX[mRow, vect]*val)
                end
            end
        end
    end

    Y
end
end
