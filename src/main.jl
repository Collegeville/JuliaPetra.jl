include("SerialComm.jl")
include("Distributor.jl")
# A place to test out constructing objects (DenseMultiVector, etc.) and some of their methods.

"""try fill! given a multivector and what to fill it with"""
function tryFill!(comm::Comm)
    comm = SerialComm{Int, Int, Int}()
    nProc = numProc(comm)
    n = 2

    curMap = BlockMap(nProc*n, n, comm)

    v = DenseMultiVector(curMap, ones(Float64, n, 2))

    println(fill!(v, 5))
end

"""try scale! with a multivector and one scalar"""
function tryScale1!(comm::Comm)
    nProc = numProc(comm)
    n = 2

    curMap = BlockMap(nProc*n, n, comm)

    v = DenseMultiVector(curMap, ones(Float64, n, 2))

    return scale!(v, 2.5)

end

"""try scale! with a multivector and array  of values"""
function tryScale2!(comm::Comm)
    nProc = numProc(comm)
    n = 2

    curMap = BlockMap(nProc*n, n, comm)

    v = DenseMultiVector(curMap, ones(Float64, n, 2))

    return scale!(v, [2.5, 1.6])

end

"""try dot product of two multivectors"""
function tryDot(comm::Comm)
    nProc = numProc(comm)
    n = 2

    curMap = BlockMap(nProc*n, n, comm)

    v1 = DenseMultiVector(curMap, ones(Float64, n, 2))
    v1 = scale!(v1, [2.5, 1.6])
    println(v1)
    v2 = DenseMultiVector(curMap, ones(Float64, n, 2))
    v2 = scale!(v2, [1, 2])
    println(v2)

    return dot(v1, v2)
end

"""try the norm of a multivector"""
function tryNorm(comm::Comm)
    nProc = numProc(comm)
    n = 4

    curMap = BlockMap(nProc*n, n, comm)

    v = DenseMultiVector(curMap, ones(Float64, n, 3))
    v = scale!(v, [1,2])

    return norm(v, 1)
end

myComm = SerialComm{Int, Int, Int}()


#tryFill!(myComm)
tryScale1!(myComm)
#tryScale2!(myComm)
#tryDot(myComm)
#tryNorm(myComm)

#=
#Start here with trying out CSR matrices
n = 3
max = 5
csrComm = SerialComm{UInt16, Bool, UInt8}()

rowMap = BlockMap(n, n, csrComm)
myCSRMatrix = CSRMatrix(rowMap, max, STATIC_PROFILE)
println(myCSRMatrix)
=#