#have debug enabled while running tests
globalDebug = true

using JuliaPetra
using Base.Test

include("TypeStability.jl")
include("TestUtil.jl")

const GID = UInt64
const PID = UInt16
const LID = UInt32

#use distinct types
const comm = MPIComm(UInt64, UInt16, UInt32)

const pid = myPid(comm)

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
                include("MultiVectorTests.jl")
                multiVectorTests(comm)

                include("CSRMatrixMPITests.jl")
            end

        finally
            #print results sequentially
            for i in 1:pid
                barrier(comm)
            end
        end
        info("process $pid test results:")
    end

finally
    #print results sequentially
    for i in pid:4
        barrier(comm)
    end
end

#catch err
#    sleep(10)
#    throw(err)
#end
