
export DistObject
export doImport, doExport
export copyAndPermute, packAndPrepare, unpackAndCombine, checkSize
export releaseViews, createViews, createViewsNonConst

# Note that all packet size information was removed due to the use of julia's
# built in serialization/objects

"""
A base type for constructing and using dense multi-vectors, vectors and matrices in parallel.


To support transfers the following methods must be implemented for the source type and the target type

    checkSizes(source::<:SrcDistObject{GID, PID, LID}, target::<:DistObject{GID, PID, LID})::Bool
Whether the source and target are compatible for a transfer

    copyAndPermute(source::<:SrcDistObject{GID, PID, LID}, target::<:DistObject{GID, PID, LID}, numSameIDs::LID, permuteToLIDs::AbstractArray{LID, 1}, permuteFromLIDs::AbstractArray{LID, 1})
Perform copies and permutations that are local to this process.

    packAndPrepare(source::<:SrcDistObject{GID, PID, LID}, target::<:DistObjectGID, PID, LID}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID})::AbstractArray
Perform any packing or preparation required for communications.  The
method returns the array of objects to export

    unpackAndCombine(target::<:DistObject{GID, PID, LID},importLIDs::AbstractArray{LID, 1}, imports::AAbstractrray, distor::Distributor{GID, PID, LID}, cm::CombineMode)
Perform any unpacking and combining after communication
"""
abstract type DistObject{GID <:Integer, PID <: Integer, LID <: Integer} <: SrcDistObject{GID, PID, LID}
end


## import/export interface ##

"""
    doImport(target::Impl{GID, PID, LID}, source::SrcDistObject{GID, PID, LID}, importer::Import{GID, PID, LID}, cm::CombineMode)

Import data into this object using an Import object ("forward mode")
"""
function doImport(source::SrcDistObject{GID, PID, LID},
        target::DistObject{GID, PID, LID}, importer::Import{GID, PID, LID},
        cm::CombineMode) where {GID <:Integer, PID <: Integer, LID <: Integer}
    doTransfer(source, target, cm, numSameIDs(importer), permuteToLIDs(importer),
        permuteFromLIDs(importer), remoteLIDs(importer), exportLIDs(importer),
        distributor(importer), false)
end

"""
    doExport(target::Impl{GID, PID, LID}, source::SrcDistObject{GID, PID, LID}, exporter::Export{GID, PID, LID}, cm::CombineMode)

Export data into this object using an Export object ("forward mode")
"""
function doExport(source::SrcDistObject{GID, PID, LID}, target::DistObject{GID, PID, LID},
        exporter::Export{GID, PID, LID}, cm::CombineMode) where {
        GID <:Integer, PID <: Integer, LID <: Integer}
    doTransfer(source, target, cm, numSameIDs(exporter), permuteToLIDs(exporter),
        permuteFromLIDs(exporter), remoteLIDs(exporter), exportLIDs(exporter),
        distributor(exporter), false)
end

"""
    doImport(source::SrcDistObject{GID, PID, LID}, target::DistObject{GID, PID, LID}, exporter::Export{GID, PID, LID}, cm::CombineMode)

Import data into this object using an Export object ("reverse mode")
"""
function doImport(source::SrcDistObject{GID, PID, LID}, target::DistObject{GID, PID, LID},
        exporter::Export{GID, PID, LID}, cm::CombineMode) where {
            GID <:Integer, PID <: Integer, LID <: Integer}
    doTransfer(source, target, cm, numSameIDs(exporter), permuteToLIDs(exporter),
        permuteFromLIDs(exporter), remoteLIDs(exporter), exportLIDs(exporter),
        distributor(exporter), true)
end

"""
    doExport(source::SrcDistObject{GID, PID, LID}, target::DistObject{GID, PID, LID}, importer::Import{GID, PID, LID}, cm::CombineMode)

Export data into this object using an Import object ("reverse mode")
"""
function doExport(source::SrcDistObject{GID, PID, LID}, target::DistObject{GID, PID, LID},
        importer::Import{GID, PID, LID}, cm::CombineMode) where {
            GID <:Integer, PID <: Integer, LID <: Integer}
    doTransfer(source, target, cm, numSameIDs(importer), permuteToLIDs(importer),
        permuteFromLIDs(importer), remoteLIDs(importer), exportLIDs(importer),
        distributor(importer), true)
end


## import/export functionality ##

"""
    checkSizes(source, target)::Bool

Compare the source and target objects for compatiblity.  By default, returns false.  Override this to allow transfering to/from subtypes
"""
function checkSizes(source::SrcDistObject{GID, PID, LID},
        target::SrcDistObject{GID, PID, LID})::Bool where {
            GID <: Integer, PID <: Integer, LID <: Integer}
    false
end

"""
    doTransfer(src::SrcDistObject{GID, PID, LID}, target::Impl{GID, PID, LID}, cm::CombineMode, numSameIDs::LID, permuteToLIDs::AbstractArray{LID, 1}, permuteFromLIDs::AbstractArray{LID, 1}, remoteLIDs::AbstractArray{LID, 1}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID}, reversed::Bool)

Perform actual redistribution of data across memory images
"""
function doTransfer(source::SrcDistObject{GID, PID, LID},
        target::DistObject{GID, PID, LID}, cm::CombineMode,
        numSameIDs::LID, permuteToLIDs::AbstractArray{LID, 1},
        permuteFromLIDs::AbstractArray{LID, 1}, remoteLIDs::AbstractArray{LID, 1},
        exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID},
        reversed::Bool) where {GID <: Integer, PID <: Integer, LID <: Integer}

    if !checkSizes(source, target)
        throw(InvalidArgumentError("checkSize() indicates that the destination " *
                "object is not a legal target for redistribution from the " *
                "source object.  This probably means that they do not have " *
                "the same dimensions.  For example, MultiVectors must have " *
                "the same number of rows and columns."))
    end

    readAlso = true #from TPetras rwo
    if cm == INSERT || cm == REPLACE
        numIDsToWrite = numSameIDs + length(permuteToLIDs) + length(remoteLIDs)
        if numIDsToWrite == numMyElements(map(target))
            # overwriting all local data in the destination, so write-only suffices

            #TODO look at FIXME on line 503
            readAlso = false
        end
    end

    #TODO look at FIXME on line 514
    createViews(source)

    #tell target to create a view of its data
    #TODO look at FIXME on line 531
    createViewsNonConst(target, readAlso)


    if numSameIDs + length(permuteToLIDs) != 0
        copyAndPermute(source, target, numSameIDs, permuteToLIDs, permuteFromLIDs)
    end

    # only need to pack & send comm buffers if combine mode is not ZERO
    # ZERO combine mode indicates results are the same as if all zeros were recieved
    if cm != ZERO
        exports = packAndPrepare(source, target, exportLIDs, distor)

        if ((reversed && distributedGlobal(target))
                || (!reversed && distributedGlobal(source)))
            if reversed
                #do exchange of remote data
                imports = resolveReverse(distor, exports)
            else
                imports = resolve(distor, exports)
            end

            unpackAndCombine(target, remoteLIDs, imports, distor, cm)
        end
    end

    releaseViews(source)
    releaseViews(target)
end

"""
    createViews(obj::SrcDistObject)

doTransfer calls this on the source object.  By default it does nothing, but the source object can use this as a hint to fetch data from a compute buffer on an off-CPU decice (such as GPU) into host memory
"""
function createViews(obj::SrcDistObject)
end

"""
    createViewsNonConst(obj::SrcDistObject, readAlso::Bool)

doTransfer calls this on the target object.  By default it does nothing, but the target object can use this as a hint to fetch data from a compute buffer on an off-CPU decice (such as GPU) into host memory
readAlso indicates whether the doTransfer might read from the original buffer
"""
function createViewsNonConst(obj::SrcDistObject, readAlso::Bool)
end


"""
    releaseViews(obj::SrcDistObject)

doTransfer calls this on the target and source as it completes to allow any releasing of buffers or views.  By default it does nothing
"""
function releaseViews(obj::SrcDistObject)
end
