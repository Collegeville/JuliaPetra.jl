#have debug enabled while running tests
globalDebug = true

using TypeStability
#check stability while running tests
enable_inline_stability_checks(true)

using JuliaPetra
using Base.Test

@. ARGS = lowercase(ARGS)
# check for command line arguments requesting parts to not be tested
const noMPI = in("--mpi", ARGS) #don't run multi-process tests
const noComm = in("--comm", ARGS) #don't run comm framework tests
const noDataStructs = in("--data", ARGS) #don't run tests on data structures
const noUtil = in("--util", ARGS) #don't run tests on Misc Utils

include("TestUtil.jl")


@testset "Serial tests" begin

    #a generic serial comm for the tests that need to be called with a comm object
    const serialComm = SerialComm{UInt64, UInt16, UInt32}()

    if !noUtil
        @testset "Util Tests" begin
            include("MacroTests.jl")
            include("ComputeOffsetsTests.jl")
        end
    end

    if !noComm
        @testset "Comm Tests" begin
            include("SerialCommTests.jl")
            include("Import-Export Tests.jl")
            include("BlockMapTests.jl")

            include("LocalCommTests.jl")
            runLocalCommTests(serialComm)

            include("BasicDirectoryTests.jl")
            basicDirectoryTests(serialComm)
        end
    end

    if !noDataStructs
        @testset "Data Structure Tests" begin
            include("MultiVectorTests.jl")
            multiVectorTests(serialComm)

            include("SparseRowViewTests.jl")
            include("LocalCSRGraphTests.jl")
            include("LocalCSRMatrixTests.jl")

            include("CSRGraphTests.jl")
            include("CSRMatrixTests.jl")
        end
    end
end

# do MPI tests at the end so that other errors are found faster since the MPI tests take the longest
if !noMPI
    include("MPITestsStarter.jl")
end
