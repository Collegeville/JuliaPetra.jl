#Contains MPI related things that the library is missing
import MPI

#TODO document

function MPI_Rsend{T}(buf::MPI.MPIBuffertype{T}, count::Integer,
                dest::Integer, tag::Integer, comm::MPI.Comm)
    ccall(MPI.MPI_RSEND, Void,
        (Ptr{T}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint},
           Ptr{Cint}),
        buf, &count, &MPI.mpitype(T), &dest, &tag, &comm.val, &0)
end

function MPI_Rsend{T}(buf::AbstractArray{T}, dest::Integer, tag::Integer, comm::MPI.Comm)
    MPI_Rsend(buf, length(buf), dest, tag, comm)
end

function MPI_Rsend{T}(obj::T, dest::Integer, tag::Integer, comm::MPI.Comm)
    MPI_Rsend([obj], dest, tag, comm)
end