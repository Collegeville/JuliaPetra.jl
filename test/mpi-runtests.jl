#have debug enabled while running tests
globalDebug = true

using TypeStability
#check stability while running tests
enable_inline_stability_checks(true)

using JuliaPetra
using Test


include("TestUtil.jl")

# function based tests
include("DenseMultiVectorTests.jl")
include("BasicDirectoryTests.jl")
include("LocalCommTests.jl")

#need access to MPI comm to ensure that tests only run on the root process
#use distinct types
mpiGID = UInt64
mpiPID = UInt16
mpiLID = UInt32
mpiComm = MPIComm(mpiGID, mpiPID, mpiLID)

if myPid(mpiComm) == 1
    @testset "Serial tests" begin

        #a generic serial comm for the tests that need to be called with a comm object
        comm = SerialComm{UInt64, UInt16, UInt32}()

        @testset "Util Tests" begin
            include("UtilsTests.jl")
        end

        @testset "Comm Tests" begin
            include("SerialCommTests.jl")
            include("Import-Export Tests.jl")
            include("BlockMapTests.jl")

            runLocalCommTests(serialComm)

            basicDirectoryTests(serialComm)
        end

        @testset "Data Structure Tests" begin
            denseMultiVectorTests(serialComm)

            include("SparseRowViewTests.jl")
            include("LocalCSRGraphTests.jl")
            include("LocalCSRMatrixTests.jl")

            include("CSRGraphTests.jl")
            include("CSRMatrixTests.jl")
        end
    end
end

GID = mpiGID
PID = mpiPID
LID = mpiLID
comm = mpiComm

pid = myPid(comm)
nProcs = numProc(comm)

#only print errors from one process
if pid != 1
    #redirect_stdout()
    #redirect_stderr()
end


#tries are to allow barriers to work correctly, even under erronious situtations
try
    @testset "MPI Tests" begin
        try
            @testset "Comm MPI Tests" begin
                include("MPICommTests.jl")
                include("MPIBlockMapTests.jl")
                include("MPIimport-export Tests.jl")

                include("LocalCommTests.jl")
                runLocalCommTests(comm)

                include("BasicDirectoryTests.jl")
                basicDirectoryTests(comm)
            end

            @testset "Data MPI Tests" begin
                denseMultiVectorTests(comm)

                include("CSRMatrixMPITests.jl")
            end

        finally
            #print results sequentially
            for i in 1:pid
                barrier(comm)
            end
        end
        @info "process $pid test results:"
    end

finally
    #print results sequentially
    for i in pid:nProcs
        barrier(comm)
    end
end
