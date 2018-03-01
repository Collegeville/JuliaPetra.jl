export CRSGraph

#TODO document the type and constructors

mutable struct CRSGraph{GID <: Integer, PID <: Integer, LID <: Integer} <: RowGraph{GID, PID, LID}
    rowMap::BlockMap{GID, PID, LID}
    colMap::Nullable{BlockMap{GID, PID, LID}}
    rangeMap::Nullable{BlockMap{GID, PID, LID}}
    domainMap::Nullable{BlockMap{GID, PID, LID}}

    #may be null if domainMap and colMap are the same
    importer::Nullable{Import{GID, PID, LID}}
    #may be null if rangeMap and rowMap are the same
    exporter::Nullable{Export{GID, PID, LID}}

    localGraph::LocalCRSGraph{LID, LID}

    #Local number of (populated) entries; must always be consistent
    nodeNumEntries::LID

    #Local number of (populated) diagonal entries.
    nodeNumDiags::LID

    #Local maximum of the number of entries in each row.
    nodeMaxNumRowEntries::LID

    #Global number of entries in the graph.
    globalNumEntries::GID

    #Global number of (populated) diagonal entries.
    globalNumDiags::GID

    #Global maximum of the number of entries in each row.
    globalMaxNumRowEntries::GID

    #Whether the graph was allocated with static or dynamic profile.
    pftype::ProfileType

    ## 1-D storage (Static profile) data structures ##
    localIndices1D::Array{LID, 1}
    globalIndices1D::Array{GID, 1}
    rowOffsets::Array{LID, 1}  #Tpetra: k_rowPts_

    ## 2-D storage (Dynamic profile) data structures ##
    localIndices2D::Array{Array{LID, 1}, 1}
    globalIndices2D::Array{Array{GID, 1}, 1}
    #may exist in 1-D storage if not packed
    numRowEntries::Array{LID, 1}

    storageStatus::StorageStatus

    indicesAllowed::Bool
    indicesType::IndexType
    fillComplete::Bool

    lowerTriangle::Bool
    upperTriangle::Bool
    indicesAreSorted::Bool
    noRedundancies::Bool
    haveLocalConstants::Bool
    haveGlobalConstants::Bool
    sortGhostsAssociatedWithEachProcessor::Bool

    plist::Dict{Symbol}

    nonLocals::Dict{GID, Array{GID, 1}}

    #Large ammounts of duplication between the constructors, so group it in an inner constructor
    function CRSGraph(
        rowMap::BlockMap{GID, PID, LID},
        colMap::Nullable{BlockMap{GID, PID, LID}},
        rangeMap::Nullable{BlockMap{GID, PID, LID}},
        domainMap::Nullable{BlockMap{GID, PID, LID}},

        localGraph::LocalCRSGraph,

        nodeNumEntries::LID,

        pftype::ProfileType,
        storageStatus::StorageStatus,

        indicesType::IndexType,
        plist::Dict{Symbol}
    ) where {GID <: Integer, PID <: Integer, LID <: Integer}

        graph = new{GID, PID, LID}(
            rowMap,
            colMap,
            rangeMap,
            domainMap,

            Nullable{Import{GID, PID, LID}}(),
            Nullable{Export{GID, PID, LID}}(),

            localGraph,

            #Local number of (populated) entries; must always be consistent
            nodeNumEntries,

            #using 0 to indicate uninitiallized, since -1 isn't gareenteed to work
            0, #nodeNumDiags
            0, #nodeMaxNumRowEntries
            0, #globalNumEntries
            0, #globalNumDiags
            0, #globalMaxNumRowEntries

            #Whether the graph was allocated with static or dynamic profile.
            pftype,


            ## 1-D storage (Static profile) data structures ##
            LID[],
            GID[],
            LID[],

            ## 2-D storage (Dynamic profile) data structures ##
            Array{Array{LID, 1}, 1}(0),
            Array{Array{GID, 1}, 1}(0),
            LID[],

            storageStatus,

            false,
            indicesType,
            false,

            false,
            false,
            true,
            true,
            false,
            false,
            true,

            plist,

            Dict{GID, Array{GID, 1}}()
        )

        ## staticAssertions()
        #skipping sizeof checks
        #skipping max value checks related to size_t

        @assert(indicesType != LOCAL_INDICES || !isnull(colMap),
            "Cannot have local indices with a null column Map")

        #ensure LID is a subset of GID (for positive numbers)
        if !(LID <: GID) && (GID != BigInt) && (GID != Integer)
            # all ints are assumed to be able to handle 1, up to their max
            if LID == BigInt || LID == Integer || typemax(LID) > typemax(GID)
                throw(InvalidArgumentError("The positive values of GID must "
                        * "be a superset of the positive values of LID"))
            end
        end

        graph
    end
end


#### Constructors #####

function CRSGraph(rowMap::BlockMap{GID, PID, LID}, maxNumEntriesPerRow::Integer,
        pftype::ProfileType; plist...) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, LID(maxNumEntriesPerRow),  pftype, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end
function CRSGraph(rowMap::BlockMap{GID, PID, LID}, maxNumEntriesPerRow::Integer,
        pftype::ProfileType, plist::Dict{Symbol}) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, Nullable{BlockMap{GID, PID, LID}}(), LID(maxNumEntriesPerRow), pftype, plist)
end

function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        maxNumEntriesPerRow::Integer, pftype::ProfileType; plist...) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, colMap, LID(maxNumEntriesPerRow), pftype, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end
function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        maxNumEntriesPerRow::Integer, pftype::ProfileType, plist::Dict{Symbol}) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, Nullable(colMap), LID(maxNumEntriesPerRow), pftype, plist)
end

function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::Nullable{BlockMap{GID, PID, LID}},
        maxNumEntriesPerRow::LID, pftype::ProfileType; plist...) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, colMap, maxNumEntriesPerRow, pftype, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end
function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::Nullable{BlockMap{GID, PID, LID}},
        maxNumEntriesPerRow::LID, pftype::ProfileType, plist::Dict{Symbol}) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    graph = CRSGraph(
        rowMap,
        colMap,
        Nullable{BlockMap{GID, PID, LID}}(),
        Nullable{BlockMap{GID, PID, LID}}(),

        LocalCRSGraph{LID, LID}(), #localGraph

        LID(0), #nodeNumEntries

        pftype,

        (pftype == STATIC_PROFILE ?
              STORAGE_1D_UNPACKED
            : STORAGE_2D),

        isnull(colMap)?GLOBAL_INDICES:LOCAL_INDICES,
        plist
    )

    allocateIndices(graph, graph.indicesType, maxNumEntriesPerRow)

    resumeFill(graph, plist)
    checkInternalState(graph)

    graph
end

function CRSGraph(rowMap::BlockMap{GID, PID, LID}, numEntPerRow::AbstractArray{<:Integer, 1},
        pftype::ProfileType; plist...)  where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, numEntPerRow, pftype, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end
function CRSGraph(rowMap::BlockMap{GID, PID, LID}, numEntPerRow::AbstractArray{<:Integer, 1},
        pftype::ProfileType, plist::Dict{Symbol})  where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, Nullable{BlockMap{GID, PID, LID}}(), numEntPerRow, pftype, plist)
end

function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        numEntPerRow::AbstractArray{<:Integer, 1}, pftype::ProfileType;
        plist...)  where {GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, colMap, numEntPerRow, pftype, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end
function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        numEntPerRow::AbstractArray{<:Integer, 1}, pftype::ProfileType,
        plist::Dict{Symbol})  where {GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, Nullable(colMap), numEntPerRow, pftype, plist)
end

function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::Nullable{BlockMap{GID, PID, LID}},
        numEntPerRow::AbstractArray{<:Integer, 1}, pftype::ProfileType;
        plist...)  where {GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, colMap, numEntPerRow, pftype, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end
function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::Nullable{BlockMap{GID, PID, LID}},
        numEntPerRow::AbstractArray{<:Integer, 1}, pftype::ProfileType,
        plist::Dict{Symbol})  where {GID <: Integer, PID <: Integer, LID <: Integer}
    graph = CRSGraph(
        rowMap,
        colMap,
        Nullable{BlockMap{GID, PID, LID}}(),
        Nullable{BlockMap{GID, PID, LID}}(),

        LocalCRSGraph{LID, LID}(), #localGraph

        LID(0), #nodeNumEntries

        #Whether the graph was allocated with static or dynamic profile.
        pftype,

        (pftype == STATIC_PROFILE ?
              STORAGE_1D_UNPACKED
            : STORAGE_2D),

        isnull(colMap)?GLOBAL_INDICES:LOCAL_INDICES,
        plist
    )

    localNumRows = numMyElements(rowMap)
    if length(numEntPerRow) != localNumRows
        throw(InvalidArgumentError("numEntPerRows has length $(length(numEntPerRow)) " *
                "!= the local number of rows $lclNumRows as spcified by the input row Map"))
    end

    if @debug
        for curRowCount in numEntPerRow
            if curRowCount <= 0
                throw(InvalidArgumentError("numEntPerRow[$r] = $curRowCount is not valid"))
            end
        end
    end

    allocateIndices(graph, graph.indicesType, Array{LID, 1}(numEntPerRow))

    resumeFill(graph, plist)
    checkInternalState(graph)

    graph
end


function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        rowPointers::AbstractArray{LID, 1}, columnIndices::Array{LID, 1};
        plist...) where {GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, colMap, rowPointers, columnIndices, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end
function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        rowPointers::AbstractArray{LID, 1}, columnIndices::Array{LID, 1},
        plist::Dict{Symbol}) where {GID <: Integer, PID <: Integer, LID <: Integer}
    graph = CRSGraph(
        rowMap,
        Nullable(colMap),
        Nullable{BlockMap{GID, PID, LID}}(),
        Nullable{BlockMap{GID, PID, LID}}(),

        LocalCRSGraph{LID, LID}(), #localGraph

        LID(0), #nodeNumEntries

        STATIC_PROFILE,

        STORAGE_1D_PACKED,

        LOCAL_INDICES,
        plist
    )
    #seems to be already taken care of
    #allocateIndices(graph, LOCAL_INDICES, numEntPerRow)

    setAllIndicies(graph, rowPointers, columnIndicies)
    checkInternalState(graph)

    graph
end

function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        localGraph::LocalCRSGraph{LID, LID}; plist...) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    CRSGraph(rowMap, colMap, localGraph, Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end
function CRSGraph(rowMap::BlockMap{GID, PID, LID}, colMap::BlockMap{GID, PID, LID},
        localGraph::LocalCRSGraph{LID, LID}, plist::Dict{Symbol}) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    mapRowCount = numMyElements(rowMap)
    graph = CRSGraph(
        rowMap,
        Nullable(colMap),
        Nullable{}(rowMap),
        Nullable{}(colMap),

        localGraph,

        localGraph.rowMap[mapRowCount+1], #nodeNumEntries

        STATIC_PROFILE,

        STORAGE_1D_PACKED,

        LOCAL_INDICES,
        plist
    )

    if numRows(localGraph) != numMyElements(rowMap)
        throw(InvalidArgumentError("input row map and input local "
                * "graph need to have the same number of rows.  The "
                * "row map claims $(numMyElements(rowMap)) row(s), "
                * "but the local graph claims $(numRows(localGraph)) "
                * "row(s)."))
    end

    #seems to be already taken care of
    #allocateIndices(graph, LOCAL_INDICES, numEntPerRow)

    makeImportExport(graph)

    d_inds = localGraph.entries
    graph.localIndices1D = d_inds

    d_ptrs = localGraph.rowMap
    graph.rowOffsets = d_ptrs

    #reset local properties
    graph.upperTriangle = true
    graph.lowerTriangle = true
    graph.nodeMaxNumRowEntries = 0
    graph.nodeNumDiags

    for localRow = 1:mapRowCount
        globalRow = gid(rowMap, localRow)
        rowLID = lid(colMap, globalRow)

        #possible that the local matrix has no entries in the column
        #corrisponding to the current row, in that case, the column map
        #might not contain that GID.  Hence, the index validity check
        if rowLID != 0
            if rowLID +1 > length(d_ptrs)
                throw(InvalidArgumentError("The given row Map and/or column Map "
                        * "is/are not compatible with the provided local graphs."))
            end
            if d_ptrs[rowLID] != d_ptr[rowLID+1]
                const smallestCol = d_inds[d_ptrs[rowLID]]
                const largestCol  = d_inds[d_ptrs[rowLID+1]-1]

                if smallestCol < localRow
                    graph.upperTriangle = false
                end
                if localRow < largestCol
                    graph.lowerTriangle = false
                end

                if rowLID in d_inds[d_ptrs[rowLID]:d_ptrs[rowLID]-1]
                    graph.nodeNumDiags += 1
                end
            end

            graph.nodeMaxNumRowEntries = max((d_ptrs[rowLID + 1] - d_ptrs[rowLID]),
                                            graph.nodeMaxNumRowEntries)
        end
    end

    graph.hasLocalConstants = true
    computeGlobalConstants(graph)

    graph.fillComplete = true
    checkInternalState(graph)

    graph
end
