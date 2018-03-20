using TypeStability

module JuliaPetra

# Internal Utilities
include("Enums.jl")
include("Error.jl")
include("Macros.jl")

include("ComputeOffsets.jl")


# Communication interface
include("Distributor.jl")
include("Directory.jl")
include("Comm.jl")
include("LocalComm.jl")

include("BlockMapData.jl")
include("BlockMap.jl")

include("DirectoryMethods.jl")
include("BasicDirectory.jl")


# Serial Communication
include("SerialDistributor.jl")
#include("SerialDirectory.jl")
include("SerialComm.jl")


# MPI Communication
include("MPIUtil.jl")
include("MPIComm.jl")
include("MPIDistributor.jl")


# Data interface
include("ImportExportData.jl")
include("Import.jl")
include("Export.jl")

include("DistObject.jl")


# Dense Data types
include("MultiVector.jl")


# Sparse Data types
include("Operator.jl")

include("SparseRowView.jl")
include("LocalCSRGraph.jl")
include("LocalCSRMatrix.jl")

include("RowGraph.jl")
include("CSRGraphConstructors.jl")
include("CSRGraphInternalMethods.jl")
include("CSRGraphExternalMethods.jl")

include("RowMatrix.jl")
include("CSRMatrix.jl")

end # module
