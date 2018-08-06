using TypeStability

module JuliaPetra

# Internal Utilities
include("Utils.jl")


# Communication interface
include("Comm.jl")
include("LocalComm.jl")
include("Distributor.jl")
include("Directory.jl")

include("BlockMapData.jl")
include("BlockMap.jl")

include("BasicDirectory.jl")
include("DirectoryMethods.jl")


# Communication implementations
include("SerialComm.jl")

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
include("DenseMultiVector.jl")


# Sparse Data types
include("Operator.jl")
include("RowGraph.jl")
include("RowMatrix.jl")


include("SparseRowView.jl")
include("LocalCSRGraph.jl")
include("LocalCSRMatrix.jl")

include("CSRGraphConstructors.jl")
include("CSRGraphInternalMethods.jl")
include("CSRGraphExternalMethods.jl")

include("CSRMatrix.jl")

end # module
