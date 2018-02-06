
export Import

"""
Communication plan for data redistribution from a uniquely-owned to a (possibly) multiply-owned distribution.
"""
struct Import{GID <: Integer, PID <:Integer, LID <: Integer}
    importData::ImportExportData{GID, PID, LID}

    #default constructor appeared to accept a pair of BlockMaps
    function Import{GID, PID, LID}(
            importData::ImportExportData{GID, PID, LID}) where {
                GID <: Integer, PID <: Integer, LID <: Integer}
        new(importData)
    end
end

## Constructors ##

function Import(source::BlockMap{GID, PID, LID}, target::BlockMap{GID, PID, LID},
        userRemotePIDs::AbstractArray{PID}, remoteGIDs::AbstractArray{GID},
        userExportLIDs::AbstractArray{LID}, userExportPIDs::AbstractArray{PID},
        useRemotePIDGID::Bool; plist...) where {
        GID <: Integer, PID <: Integer, LID <: Integer}
    Import{GID, PID, LID}(source, target, userRemotePIDs, remoteGIDs,
        userExportLIDs, userExportPIDs, useRemotePIDGID, Dict(plist))
end

function Import(source::BlockMap{GID, PID, LID}, target::BlockMap{GID, PID, LID},
        userRemotePIDs::AbstractArray{PID}, remoteGIDs::AbstractArray{GID},
        userExportLIDs::AbstractArray{LID}, userExportPIDs::AbstractArray{PID},
        useRemotePIDGID::Bool, plist::Dict{Symbol}
        ) where {GID <: Integer, PID <: Integer, LID <: Integer}

    importData = ImportExportData(source, target)

    if @debug
        info("$(myPid(comm(source))): Import ctor expert\n")
    end

    const remoteLIDs = JuliaPetra.remoteLIDs(importData)

    if !userRemotePIDGID
        empty!(remoteGIDs)
        empty!(remoteLIDs)
    end

    getIDSource(data, remoteGIDs, !userRemotePIDGID)

    if length(remoteGIDs) > 0 && !isDistributed(source)
        throw(InvalidArgumentError("Target has remote LIDs but source is not distributed globally"))
    end

    (remotePIDs, _) = remoteIDList(source, remoteGIDs)

    remoteProcIDs = (useRemotePIDGID) ? userRemotePIDs : remotePIDs

    if !(length(remoteProcIDs) == length(remoteGIDs) && length(remoteGIDs) == length(remoteLIDs))
        throw(InvalidArgumentError("Size miss match on remoteProcIDs, remoteGIDs and remoteLIDs"))
    end

    # ensure remoteProcIDs[i], remoteGIDs[i] and remoteLIDs[i] refer to the same thing
    order = sortperm(remoteProcIDs)
    permute!(remoteProcIDs, order)
    permute!(remoteGIDs, order)
    permute!(remoteLIDs, order)

    exportPIDs = Array{PID, 1}(length(userExportPIDs))
    exportLIDs = Array{PID, 1}(length(userExportPIDs))

    #need the funcitons with these names, not the variables
    JuliaPetra.remoteLIDs(importData, remoteLIDs)
    JuliaPetra.exportPIDs(importData, exportPIDs)
    JuliaPetra.exportLIDs(importData, exportLIDs)

    locallyComplete = true
    for i = 1:length(userExportPIDs)
        if userExportPIDs[i] == 0
            locallyComplete = false
        end

        exportPIDs[i] = userExportPIDs[i]
        exportLIDs[i] = userExportLIDs[i]
    end

    isLocallyComplete(importData, locallyComplete)
    #TODO create and upgrade to createFromSendsAndRecvs
    #createFromSendsAndRecvs(distributor(importData), exportPIDs, remoteProcIDs)
    createFromRecvs(distributor(importData), remoteGIDs, remotePIDs)

    Import(importData)
end

function Import(source::BlockMap{GID, PID, LID}, target::BlockMap{GID, PID, LID}, remotePIDs::Nullable{AbstractArray{PID}}=Nullable{AbstractArray{PID}}(); plist...) where {GID <: Integer, PID <: Integer, LID <: Integer}
    Import(source, target, remotePIDs,
        Dict(Array{Tuple{Symbol, Any}, 1}(plist)))
end

function Import(source::BlockMap{GID, PID, LID}, target::BlockMap{GID, PID, LID}, plist::Dict{Symbol}) where {GID <: Integer, PID <: Integer, LID <: Integer}
    Import(source, target, Nullable{AbstractArray{PID}}(), plist)
end

function Import(source::BlockMap{GID, PID, LID}, target::BlockMap{GID, PID, LID}, remotePIDs::Nullable{AbstractArray{PID}}, plist::Dict{Symbol}) where {GID <: Integer, PID <: Integer, LID <: Integer}

    if @debug
        info("$(myPid(comm(source))): Import ctor\n")
    end

    const impor = Import{GID, PID, LID}(ImportExportData(source, target))

    const remoteGIDs = setupSamePermuteRemote(impor)

    if @debug
        info("$(myPid(comm(source))): Import ctor: setupSamePermuteRemote done\n")
    end
    if distributedGlobal(source)
        setupExport(impor, remoteGIDs, remotePIDs)
    end
    if @debug
        info("$(myPid(comm(source))): Import ctor: done\n")
    end

    impor
end

## internal construction methods ##

function setupSamePermuteRemote(impor::Import{GID, PID, LID}) where {GID <: Integer, PID <: Integer, LID <: Integer}

    data = impor.importData

    remoteGIDs = Array{GID, 1}(0)

    getIDSources(data, remoteGIDs)

    if length(remoteLIDs(data)) != 0 && !distributedGlobal(sourceMap(impor))
        isLocallyComplete(data, false)

        warn("Target has remote LIDs but source is not distributed globally.  " *
            "Importing a submap of the target map")
    end

    remoteGIDs
end


function getIDSources(data, remoteGIDs, useRemotes=true)
    const source = sourceMap(data)
    const target = targetMap(data)

    const sourceGIDs = myGlobalElements(source)
    const targetGIDs = myGlobalElements(target)

    const numSrcGIDs = length(sourceGIDs)
    const numTgtGIDs = length(targetGIDs)
    const numGIDs = min(numSrcGIDs, numTgtGIDs)

    numSameGIDs = 1
    while numSameGIDs <= numGIDs && sourceGIDs[numSameGIDs] == targetGIDs[numSameGIDs]
        numSameGIDs += 1
    end
    numSameGIDs -= 1
    numSameIDs(data, numSameGIDs)

    const permuteToLIDs = JuliaPetra.permuteToLIDs(data)
    const permuteFromLIDs = JuliaPetra.permuteFromLIDs(data)
    const remoteLIDs = JuliaPetra.remoteLIDs(data)


    for tgtLID = (numSameGIDs+1):numTgtGIDs
        const curTargetGID = targetGIDs[tgtLID]
        const srcLID = lid(source, curTargetGID)
        if srcLID != 0
            push!(permuteToLIDs, tgtLID)
            push!(permuteFromLIDs, srcLID)
        elseif useRemotes
            push!(remoteGIDs, curTargetGID)
            push!(remoteLIDs, tgtLID)
        end
    end
end

function setupExport(impor::Import{GID, PID, LID}, remoteGIDs::AbstractArray{GID}, userRemotePIDs::Nullable{AbstractArray{PID}}) where {GID <: Integer, PID <: Integer, LID <: Integer}
    data = impor.importData
    const source = sourceMap(impor)

    useRemotePIDs = !isnull(userRemotePIDs)

    # Sanity Checks
    if useRemotePIDs && length(get(userRemotePIDs)) != length(remoteGIDs)
        throw(InvalidArgumentError("remotePIDs must either be null " *
                "or match the size of remoteGIDs."))
    end


    missingGID = 0

    if !useRemotePIDs
        newRemotePIDs = Array{PID, 1}(length(remoteGIDs))
        if @debug
            info("$(myPid(comm(source))): setupExport(Import): about to call " *
                "getRemoteIndexList on sourceMap\n")
        end
        (remoteProcIDs, remoteLIDs) = remoteIDList(source, remoteGIDs)
        for e in remoteLIDs
            if e == 0
                missingGID += 1
            end
        end
    else
        remoteProcIDs = get(userRemotePIDs)
    end

    #line 688

    if missingGID != 0
        isLocallyComplete(data, false)

        warn("Source map was un-able to figure out which process owns one " *
            "or more of the GIDs in the list of remote GIDs.  This probably " *
            "means that there is at least one GID owned by some process in " *
            "the target map which is not owned by any process in the source " *
            "Map.  (That is, the source and target maps do not contain the " *
            "same set of GIDs globally")

        #ignore remote GIDs that aren't owned by any process in the source Map
        numInvalidRemote = missingGID
        totalNumRemote = length(remoteGIDs)
        if numInvalidRemote == totalNumRemote
            #if all remotes are invalid, can delete them all
            empty!(remoteProcIDs)
            empty!(remoteGIDs)
            empty!(JuliaPetra.remoteLIDs(data))
        else
            numValidRemote = 1

            remoteLIDs = JuliaPetra.remoteLIDs(data)

            for r = 1:totalNumRemote
                if remoteProcIds[r] != 0
                    remoteProcIds[numValidRemote] = remoteProcIDs[r]
                    remoteGIDs[numValidRemote] = remoteGIDs[r]
                    remoteLIDs[numValidRemote] = remoteLIDs[r]
                    numValidRemote += 1
                end
            end
            numValidRemote -= 1

            if numValidRemote != totalNumRemote - numInvalidRemote
                throw(InvalidStateError("numValidRemote = $numValidRemote " *
                        "!= totalNumRemote - numInvalidRemote " *
                        "= $(totalNumRemote - numInvalidRemote)"))
            end

            resize!(remoteProcIDs, numValidRemote)
            resize!(remoteGIDs, numValidRemote)
            resize!(remoteLIDs, numValidRemote)
        end
    end

    order = sortperm(remoteProcIDs)
    permute!(remoteProcIDs, order)
    permute!(remoteGIDs, order)
    permute!(remoteLIDs, order)

    (exportGIDs, exportPIDs) = createFromRecvs(distributor(data), remoteGIDs, remoteProcIDs)

    JuliaPetra.exportPIDs(data, exportPIDs)

    numExportIDs = length(exportGIDs)

    if numExportIDs > 0
        exportLIDs = JuliaPetra.exportLIDs(data)
        resize!(exportLIDs, numExportIDs)
        for k in 1:numExportIDs
            exportLIDs[k] = lid(source, exportGIDs[k])
        end
    end

    if @debug
        info("$(myPid(comm(source))): setupExport: done\n")
    end
end

## Getters ##

"""
Get the source map for the given ImportExportData
"""
function sourceMap(impor::Import{GID, PID, LID})::BlockMap{GID, PID, LID} where GID <: Integer where PID <:Integer where LID <: Integer
    impor.importData.source
end

"""
Get the target map for the given ImportExportData
"""
function targetMap(impor::Import{GID, PID, LID})::BlockMap{GID, PID, LID} where GID <: Integer where PID <:Integer where LID <: Integer
    impor.importData.target
end

"""
List of elements in the target map that are permuted.
"""
function permuteToLIDs(impor::Import{GID, PID, LID})::Array{LID} where GID <: Integer where PID <:Integer where LID <: Integer
    impor.importData.permuteToLIDs
end

"""
List of elements in the source map that are permuted.
"""
function permuteFromLIDs(impor::Import{GID, PID, LID})::Array{LID} where GID <: Integer where PID <:Integer where LID <: Integer
    impor.importData.permuteFromLIDs
end

"""
List of elements in the target map that are coming from other processors
"""
function remoteLIDs(impor::Import{GID, PID, LID})::Array{LID} where GID <: Integer where PID <: Integer where LID <: Integer
    impor.importData.remoteLIDs
end

"""
List of elements that will be sent to other processors
"""
function exportLIDs(impor::Import{GID, PID, LID})::Array{LID} where GID <: Integer where PID <: Integer where LID <: Integer
    impor.importData.exportLIDs
end

"""
List of processors to which elements will be sent `exportLID[i]` will be sent to processor `exportPIDs[i]`
"""
function exportPIDs(impor::Import{GID, PID, LID})::Array{PID} where GID <: Integer where PID <: Integer where LID <: Integer
    impor.importData.exportPIDs
end

"""
Returns the number of elements that are identical between the source and target maps, up to the first different ID
"""
function numSameIDs(impor::Import{GID, PID, LID})::LID where GID <: Integer where PID <: Integer where LID <: Integer
    impor.importData.numSameIDs
end


"""
Returns the distributor being used
"""
function distributor(impor::Import{GID, PID, LID})::Distributor{GID, PID, LID} where GID <: Integer where PID <: Integer where LID <: Integer
    impor.importData.distributor
end

"""
Returns whether the import or export is locally complete
"""
function isLocallyComplete(impor::Import{GID, PID, LID})::Bool where GID <: Integer where PID <: Integer where LID <: Integer
    impor.importData.isLocallyComplete
end
