
export SerialComm

"""
    SerialComm()

Gets an serial communication instance.
Serial communication results in mostly no-ops for the communication operations
"""
struct SerialComm{GID <: Integer, PID <:Integer, LID <: Integer} <: Comm{GID, PID, LID}
end


# most of these functions are no-ops or identify functions since there is only
# one processor

function barrier(comm::SerialComm)
end


function broadcastAll(comm::SerialComm, myVals::AbstractArray{T}, root::Integer)::Array{T} where T
    if root != 1 
        throw(InvalidArgumentError("SerialComm can only accept PID of 1"))
    end
    myVals
end

function gatherAll(comm::SerialComm, myVals::AbstractArray{T})::Array{T} where T
    myVals
end

function sumAll(comm::SerialComm, partialsums::AbstractArray{T})::Array{T} where T
    partialsums
end

function maxAll(comm::SerialComm, partialmaxes::AbstractArray{T})::Array{T} where T
    partialmaxes
end

function minAll(comm::SerialComm, partialmins::AbstractArray{T})::Array{T} where T
    partialmins
end

function scanSum(comm::SerialComm, myvals::AbstractArray{T})::Array{T} where T
    myvals
end

function myPid(comm::SerialComm{GID, PID})::PID where GID <: Integer where PID <: Integer
    1
end

function numProc(comm::SerialComm{GID, PID})::PID where GID <: Integer where PID <: Integer
    1
end

function createDistributor(comm::SerialComm{GID, PID, LID})::SerialDistributor{GID, PID, LID} where GID <: Integer where PID <: Integer where LID <: Integer
    SerialDistributor{GID, PID, LID}()
end
