export SerialDistributor

"""
    SerialDistributor()

Creates a distributor to work with SerialComm
"""
type SerialDistributor{GID <: Integer, PID <:Integer, LID <: Integer} <: Distributor{GID, PID, LID}
    post::Nullable{AbstractArray}
    reversePost::Nullable{AbstractArray}
    
    function SerialDistributor{GID, PID, LID}() where GID <: Integer where PID <: Integer where LID <: Integer
        new(nothing, nothing)
    end
end


function createFromSends(dist::SerialDistributor{GID, PID, LID},
        exportPIDs::AbstractArray{PID})::Integer where GID <: Integer where PID <: Integer where LID <: Integer
    for id in exportPIDs
        if id != 1
            throw(InvalidArgumentError("SerialDistributor can only accept PID of 1"))
        end
    end
    length(exportPIDs)
end

function createFromRecvs(
        dist::SerialDistributor{GID, PID, LID}, remoteGIDs::AbstractArray{GID}, remotePIDs::AbstractArray{PID}
        )::Tuple{AbstractArray{GID}, AbstractArray{PID}} where GID <: Integer where PID <: Integer where LID <: Integer
    for id in remotePIDs
        if id != 1
            throw(InvalidArgumentError("SerialDistributor can only accept PID of 1"))
        end
    end
    remoteGIDs,remotePIDs
end

function resolve(dist::SerialDistributor, exportObjs::AbstractArray{T})::AbstractArray{T} where T
    exportObjs
end

function resolveReverse(dist::SerialDistributor, exportObjs::AbstractArray{T})::AbstractArray{T} where T
    exportObjs
end

function resolvePosts(dist::SerialDistributor, exportObjs::AbstractArray)
    dist.post = Nullable(exportObjs)
end

function resolveWaits(dist::SerialDistributor)::AbstractArray
    if isnull(dist.post)
        throw(InvalidStateError("Must post before waiting"))
    end
    
    result = get(dist.post)
    dist.post = Nullable{AbstractArray}()
    result
end

function resolveReversePosts(dist::SerialDistributor, exportObjs::AbstractArray) 
    dist.reversePost = Nullable(exportObjs)
end

function resolveReverseWaits(dist::SerialDistributor)::AbstractArray
     if isnull(dist.reversePost)
        throw(InvalidStateError("Must reverse post before reverse waiting"))
    end
    
    result = get(dist.reversePost)
    dist.reversePost = Nullable{AbstractArray}()
    result
end

