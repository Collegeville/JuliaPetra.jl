var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#JuliaPetra-1",
    "page": "Home",
    "title": "JuliaPetra",
    "category": "section",
    "text": "JuliaPetra is an implmentation of Trilinos\'s Petra Object Model in Julia. It is a basic framework for distributed sparse linear algebra. Note that JuliaPetra uses Single Program Multiple Data parallelism instead of the master/worker parallelism often used in Julia."
},

{
    "location": "#Organization-1",
    "page": "Home",
    "title": "Organization",
    "category": "section",
    "text": "JuliaPetra is organized into a series of layers.The Communications Layer contains an interface for Single Program Multiple Data parallel systems\nThe Problem Distribution Layer manages how the problem is distributed across the processes\nThe Linear Algebra Layer provides the interfaces and implementations for linear algebra objects"
},

{
    "location": "CommunicationLayer/#",
    "page": "Communcation Layer",
    "title": "Communcation Layer",
    "category": "page",
    "text": ""
},

{
    "location": "CommunicationLayer/#Communications-Layer-1",
    "page": "Communcation Layer",
    "title": "Communications Layer",
    "category": "section",
    "text": "CurrentModule = JuliaPetraJuliaPetra abstracts communication with the Comm and Distributor interfaces. There are two communication implementations with JuliaPetra SerialComm and MPIComm. Note that most objects dependent on inter-process communication support the getComm method."
},

{
    "location": "CommunicationLayer/#JuliaPetra.Comm",
    "page": "Communcation Layer",
    "title": "JuliaPetra.Comm",
    "category": "type",
    "text": "The base type for types that represent communication in parallel computing.\n\nAll subtypes must have the following methods, with CommImpl standing in for the subtype:\n\nbarrier(comm::CommImpl)\n\nEach processor must wait until all processors have arrived\n\nbroadcastAll(comm::CommImpl, myvals::AbstractArray{T}, Root::Integer)::Array{T} where T\n\nTakes a list of input values from the root processor and sends to all other processors.  The values are returned (including on the root process)\n\ngatherAll(comm::CommImpl, myVals::AbstractArray{T})::Array{T} where T\n\nTakes a list of input values from all processors and returns an ordered contiguous list of those values on each processor\n\nsumAll(comm::CommImpl, partialsums::AbstractArray{T})::Array{T} where T\n\nTake a list of input values from all processors and returns the sum on each processor.  The method +(::T, ::T)::T can be assumed to exist\n\nmaxAll(comm::CommImpl, partialmaxes::AbstractArray{T})::Array{T} where T\n\nTakes a list of input values from all processors and returns the max to all processors.  The method <(::T, ::T)::Bool can be assumed to exist\n\nminAll(comm::CommImpl, partialmins::AbstractArray{T})::Array{T} where T\n\nTakes a list of input values from all processors and returns the min to all processors.  The method <(::T, ::T)::Bool can be assumed to exist\n\nscanSum(comm::CommImpl, myvals::AbstractArray{T})::Array{T} where T\n\nTakes a list of input values from all processors, computes the scan sum and returns it to all processors such that processor i contains the sum of values from processor 1 up to and including processor i.  The method +(::T, ::T)::T is used for the addition.\n\nmyPid(comm::CommImpl{GID, PID, LID})::PID\n\nReturns the process rank\n\nnumProc(comm::CommImpl{GID, PID, LID})::PID\n\nReturns the total number of processes\n\ncreateDistributor(comm::CommImpl{GID, PID, LID})::Distributor{GID, PID, LID}\n\nCreate a distributor object\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.Distributor",
    "page": "Communcation Layer",
    "title": "JuliaPetra.Distributor",
    "category": "type",
    "text": "The base type for gather/scatter setup. All subtypes must have the following methods, with DistributorImpl standing in for the subtype:\n\ncreateFromSends(dist::DistributorImpl,exportPIDs::AbstractArray{PID})::Integer where PID <:Integer\n\nSets up the Distributor object using a list of process IDs to which we export.  Returns the number of IDs this processor will be receiving.\n\ncreateFromRecvs(dist::DistributorImpl, remoteGIDs::AbstractArray{GID}, remotePIDs::AbstractArray{PID})::Tuple{AbstractArray{GID}, AbstractArray{PID}} where GID <: Integer where PID <: Integer\n\nSets up the Distributor object using a list of remote global IDs and corresponding PIDs.  Returns a tuple with the global IDs and their respective processor IDs being sent by this processor.\n\nresolvePosts(dist::DistributorImpl, exportObjs::AbstractArray)\n\nPost buffer of export objects.  Other, local work can be done before resolving the waits.  Otherwise, as resolve.\n\nresolveWaits(dist::DistributorImpl)::AbstractArray\n\nWait on a set of posts\n\nresolveReversePosts(dist::DistributorImpl, exportObjs::AbstractArray)\n\nDo reverse post of buffer of export objects Other, local work can be done before resolving the waits.  Otherwise, as resolveReverse.\n\nresolveReverseWaits(dist::DistributorImpl)::AbstractArray\n\nWait on a set of reverse posts.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#Interface-1",
    "page": "Communcation Layer",
    "title": "Interface",
    "category": "section",
    "text": "Comm\nDistributor"
},

{
    "location": "CommunicationLayer/#JuliaPetra.getComm",
    "page": "Communcation Layer",
    "title": "JuliaPetra.getComm",
    "category": "function",
    "text": "getComm(obj)\n\nGets the Comm for the object, if applicable\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.barrier",
    "page": "Communcation Layer",
    "title": "JuliaPetra.barrier",
    "category": "function",
    "text": "barrier(::Comm)\n\nCauses the process to pause until all processes have called barrier.  Used to synchronize the processes\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.broadcastAll",
    "page": "Communcation Layer",
    "title": "JuliaPetra.broadcastAll",
    "category": "function",
    "text": "broadcastAll(::Comm, myVals::T, root::Integer)::T\nbroadcastAll(comm::Comm, myVals::AbstractArray{T, 1}, root::Integer)::Array{T, 1}\n\nTakes a list of input values from the root processor and sends it to each other processor.  The broadcasted values are then returned, including on the root process.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.gatherAll",
    "page": "Communcation Layer",
    "title": "JuliaPetra.gatherAll",
    "category": "function",
    "text": "gatherAll(::Comm, myVal::T)::Array{T, 1}\ngatherAll(comm::Comm, myVals::AbstractArray{T, 1})::Array{T, 1}\n\nTakes a list of input values from all processors and returns an ordered, contiguous list of those values.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.sumAll",
    "page": "Communcation Layer",
    "title": "JuliaPetra.sumAll",
    "category": "function",
    "text": "sumAll(::Comm, partialsum::T)::T\nsumAll(comm::Comm, partialsums::AbstractArray{T, 1})::Array{T, 1}\n\nTakes a list of input values from all processors and returns the sum on each processor.  The method +(::T, ::T)::T must exist.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.maxAll",
    "page": "Communcation Layer",
    "title": "JuliaPetra.maxAll",
    "category": "function",
    "text": "maxAll(::Comm, partialmax::T)::T\nmaxAll(comm::Comm, partialmaxes::AbstractArray{T, 1})::Array{T, 1}\n\nTakes a list of input values from all processors and returns the max to all processors.  The method <(::T, ::T)::Bool must exist.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.minAll",
    "page": "Communcation Layer",
    "title": "JuliaPetra.minAll",
    "category": "function",
    "text": "minAll(::Comm, partialmin::T)::T\nminAll(comm::Comm, partialmins::AbstractArray{T, 1})::Array{T, 1}\n\nTakes a list of input values from all processors and returns the min to all processors.  The method <(::T, ::T)::Bool must exist.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.scanSum",
    "page": "Communcation Layer",
    "title": "JuliaPetra.scanSum",
    "category": "function",
    "text": "scanSum(::Comm, myval::T)::T\nscanSum(comm::Comm, myvals::AbstractArray{T, 1})::Array{T, 1}\n\nTakes a list of input values from all processors, computes the scan sum and returns it to all processors such that processor i contains the sum of values from processor 1 up to, and including, processor i.  The method +(::T, ::T)::T must exist\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.myPid",
    "page": "Communcation Layer",
    "title": "JuliaPetra.myPid",
    "category": "function",
    "text": "myPid(::Comm{GID, PID, LID})::PID\n\nReturns the rank of the calling processor\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.numProc",
    "page": "Communcation Layer",
    "title": "JuliaPetra.numProc",
    "category": "function",
    "text": "numProc(::Comm{GID, PID, LID})::PID\n\nReturns the total number of processes\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.createDistributor",
    "page": "Communcation Layer",
    "title": "JuliaPetra.createDistributor",
    "category": "function",
    "text": "createDistributor(comm::Comm{GID, PID, LID})::Distributor{GID, PID, LID}\n\nCreates a distributor for the given Comm object\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.createFromSends",
    "page": "Communcation Layer",
    "title": "JuliaPetra.createFromSends",
    "category": "function",
    "text": "createFromSends(dist::Distributor, exportPIDs::AbstractArray{<:Integer})::Integer\n\nSets up the Distributor object using a list of process IDs to which we export and the number of IDs being exported.  Returns the number of IDs this processor will be receiving\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.createFromRecvs",
    "page": "Communcation Layer",
    "title": "JuliaPetra.createFromRecvs",
    "category": "function",
    "text": "createFromRecvs(dist::Distributor{GID, PID, LID}, remoteGIDs::AbstractArray{<:Integer}, remotePIDs::AbstractArray{<:Integer})::Tuple{AbstractArray{GID}, AbstractArray{PID}}\n\nSets up the Distributor object using a list of remote global IDs and corresponding PIDs.  Returns a tuple with the global IDs and their respective processor IDs being sent by me.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.resolve",
    "page": "Communcation Layer",
    "title": "JuliaPetra.resolve",
    "category": "function",
    "text": "resolve(dist::Distributor, exportObjs::AbstractArray{T})::AbstractArray{T}\n\nExecute the current plan on buffer of export objects and return the objects set to this processor\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.resolvePosts",
    "page": "Communcation Layer",
    "title": "JuliaPetra.resolvePosts",
    "category": "function",
    "text": "resolvePosts(dist::Distributor, exportObjs::AbstractArray)\n\nPost buffer of export objects.  Other, local work can be done before resolving the waits.  Otherwise, as resolve.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.resolveWaits",
    "page": "Communcation Layer",
    "title": "JuliaPetra.resolveWaits",
    "category": "function",
    "text": "resolveWaits(dist::Distributor)::AbstractArray\n\nWait on a set of posts.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.resolveReverse",
    "page": "Communcation Layer",
    "title": "JuliaPetra.resolveReverse",
    "category": "function",
    "text": "resolveReverse(dist::Distributor, exportObjs::AbstractArray{T})::AbstractArray{T}\n\nExecute the reverse of the current plan on buffer of export objects and return the objects set to this processor\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.resolveReversePosts",
    "page": "Communcation Layer",
    "title": "JuliaPetra.resolveReversePosts",
    "category": "function",
    "text": "resolveReversePosts(dist::Distributor, exportObjs::AbstractArray)\n\nDo reverse post of buffer of export objects Other, local work can be done before resolving the waits.  Otherwise, as resolveReverse.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.resolveReverseWaits",
    "page": "Communcation Layer",
    "title": "JuliaPetra.resolveReverseWaits",
    "category": "function",
    "text": "resolveReverseWaits(dist::Distributor)::AbstractArray\n\nWait on a set of reverse posts.\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#Functions-1",
    "page": "Communcation Layer",
    "title": "Functions",
    "category": "section",
    "text": "getComm\nbarrier\nbroadcastAll\ngatherAll\nsumAll\nmaxAll\nminAll\nscanSum\nmyPid\nnumProc\ncreateDistributor\ncreateFromSends\ncreateFromRecvs\nresolve\nresolvePosts\nresolveWaits\nresolveReverse\nresolveReversePosts\nresolveReverseWaits"
},

{
    "location": "CommunicationLayer/#JuliaPetra.LocalComm",
    "page": "Communcation Layer",
    "title": "JuliaPetra.LocalComm",
    "category": "type",
    "text": "LocalComm(::Comm{GID, PID, LID})\n\nCreates a comm object that creates an error when inter-process communication is attempted, but still allows access to the correct process ID information\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.SerialComm",
    "page": "Communcation Layer",
    "title": "JuliaPetra.SerialComm",
    "category": "type",
    "text": "SerialComm()\n\nGets an serial communication instance. Serial communication results in mostly no-ops for the communication operations\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.SerialDistributor",
    "page": "Communcation Layer",
    "title": "JuliaPetra.SerialDistributor",
    "category": "type",
    "text": "SerialDistributor()\n\nCreates a distributor to work with SerialComm\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.MPIComm",
    "page": "Communcation Layer",
    "title": "JuliaPetra.MPIComm",
    "category": "type",
    "text": "MPIComm()\nMPIComm(comm::MPI.Comm)\n\nAn implementation of Comm using MPI The no argument constructor uses MPI.COMM_WORLD\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#JuliaPetra.MPIDistributor",
    "page": "Communcation Layer",
    "title": "JuliaPetra.MPIDistributor",
    "category": "type",
    "text": "MPIDistributor{GID, PID, LID}(comm::MPIComm{GID, PID, LID})\n\nCreates an Distributor to work with MPIComm.  Created by createDistributor(::MPIComm{GID, PID, LID})\n\n\n\n\n\n"
},

{
    "location": "CommunicationLayer/#Implementations-1",
    "page": "Communcation Layer",
    "title": "Implementations",
    "category": "section",
    "text": "LocalComm\nSerialComm\nSerialDistributor\nMPIComm\nMPIDistributor"
},

{
    "location": "ProblemDistributionLayer/#",
    "page": "Problem Distribution Layer",
    "title": "Problem Distribution Layer",
    "category": "page",
    "text": ""
},

{
    "location": "ProblemDistributionLayer/#Problem-Distribution-Layer-1",
    "page": "Problem Distribution Layer",
    "title": "Problem Distribution Layer",
    "category": "section",
    "text": "CurrentModule = JuliaPetraThe Problem Distribution Layer managers how the problem is distributed across processes. The main type is BlockMap which represents a problem distribution."
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.BlockMap",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.BlockMap",
    "category": "type",
    "text": "A type for partitioning block element vectors and matrices\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.lid",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.lid",
    "category": "function",
    "text": "lid(map::BlockMap{GID, PID, LID}, gid::Integer)::LID\n\nReturn local ID of global ID, or 0 if not found on this processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.gid",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.gid",
    "category": "function",
    "text": "gid(map::BlockMap{GID, PID, LID}, lid::Integer)::GID\n\nReturn global ID of local ID, or 0 if not found on this processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.myLID",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.myLID",
    "category": "function",
    "text": "myLID(map::BlockMap, lidVal::Integer)\n\nReturn true if the LID passed in belongs to the calling processor in this map, otherwise returns false.\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.myGID",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.myGID",
    "category": "function",
    "text": "myGID(map::BlockMap, gidVal::Integer)\n\nReturn true if the GID passed in belongs to the calling processor in this map, otherwise returns false.\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.remoteIDList",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.remoteIDList",
    "category": "function",
    "text": "remoteIDList(map::BlockMap{GID, PID, LID}, gidList::AbstractArray{<: Integer}::Tuple{AbstractArray{PID}, AbstractArray{LID}}\n\nReturn the processor ID and local index value for a given list of global indices. The returned value is a tuple containing\n\nan Array of processors owning the global ID\'s in question\nan Array of local IDs of the global on the owning processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.minAllGID",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.minAllGID",
    "category": "function",
    "text": "minAllGID(map::BlockMap{GID, PID, LID})::GID\n\nReturn the minimum global ID across the entire map\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.maxAllGID",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.maxAllGID",
    "category": "function",
    "text": "maxAllGID(map::BlockMap{GID, PID, LID})::GID\n\nReturn the maximum global ID across the entire map\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.minMyGID",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.minMyGID",
    "category": "function",
    "text": "minMyGID(map::BlockMap{GID, PID, LID})::GID\n\nReturn the minimum global ID owned by this processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.maxMyGID",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.maxMyGID",
    "category": "function",
    "text": "maxMyGID(map::BlockMap{GID, PID, LID})::GID\n\nReturn the maximum global ID owned by this processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.minLID",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.minLID",
    "category": "function",
    "text": "minLID(map::BlockMap{GID, PID, LID})::LID\n\nReturn the mimimum local index value on the calling processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.maxLID",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.maxLID",
    "category": "function",
    "text": "maxLID(map::BlockMap{GID, PID, LID})::LID\n\nReturn the maximum local index value on the calling processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.numGlobalElements",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.numGlobalElements",
    "category": "function",
    "text": "numGlobalElements(map::BlockMap{GID, PID, LID})::GID\n\nReturn the number of elements across all processors\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.numMyElements",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.numMyElements",
    "category": "function",
    "text": "numMyElements(map::BlockMap{GID, PID, LID})::LID\n\nReturn the number of elements across the calling processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.myGlobalElements",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.myGlobalElements",
    "category": "function",
    "text": "myGlobalElements(map::BlockMap{GID, PID, LID})::AbstractArray{GID}\n\nReturn a list of global elements on this processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.myGlobalElementIDs",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.myGlobalElementIDs",
    "category": "function",
    "text": "myGlobalElementsIDs map::BlockMap{GID, PID, LID})::AbstractArray{GID}\n\nReturn list of global IDs assigned to the calling processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.uniqueGIDs",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.uniqueGIDs",
    "category": "function",
    "text": "uniqueGIDs(map::BlockMap)::Bool\n\nReturn true if each map GID exists on at most 1 processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.sameBlockMapDataAs",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.sameBlockMapDataAs",
    "category": "function",
    "text": "sameBlockMapDataAs(this::BlockMap, other::BlockMap)::Bool\n\nReturn true if the maps have the same data\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.sameAs",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.sameAs",
    "category": "function",
    "text": "sameAs(this::BlockMap, other::BlockMap)::Bool\n\nReturn true if this and other are identical maps\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.globalIndicesType",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.globalIndicesType",
    "category": "function",
    "text": "globalIndicesType(map::BlockMap{GID, PID, LID})::Type{GID}\n\nReturn the type used for global indices in the map\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.linearMap",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.linearMap",
    "category": "function",
    "text": "linearMap(map::BlockMap)::Bool\n\nReturn true if the global ID space is contiguously divided (but not necessarily uniformly) across all processors\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.distributedGlobal",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.distributedGlobal",
    "category": "function",
    "text": "distributedGlobal(map::BlockMap)\n\nReturn true if map is defined across more than one processor\n\n\n\n\n\nReturns true if this object is a distributed global\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#BlockMap-1",
    "page": "Problem Distribution Layer",
    "title": "BlockMap",
    "category": "section",
    "text": "BlockMap\nlid\ngid\nmyLID\nmyGID\nremoteIDList\nminAllGID\nmaxAllGID\nminMyGID\nmaxMyGID\nminLID\nmaxLID\nnumGlobalElements\nnumMyElements\nmyGlobalElements\nmyGlobalElementIDs\nuniqueGIDs\nsameBlockMapDataAs\nsameAs\nglobalIndicesType\nlinearMap\ndistributedGlobal"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.Directory",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.Directory",
    "category": "type",
    "text": "A base type as an interface to allow BlockMap objects to reference non-local elements.\n\nAll subtypes must have the following methods, with DirectoryImpl standing in for the subtype:\n\ngetDirectoryEntries(directory::DirectoryImpl, map::BlockMap, globalEntries::AbstractArray{GID},         highranksharing_procs::Bool)::Tuple{AbstractArray{PID}, AbstractArray{LID}}         where GID <: Integer where PID <: Integer where LID <:Integer     - Returns processor and local id infor for non-local map entries.  Returns a tuple         containing             1 - an Array of processors owning the global ID\'s in question             2 - an Array of local IDs of the global on the owning processor\n\ngidsAllUniquelyOwned(directory::DirectoryImpl)     - Returns true if all GIDs appear on just one processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.BasicDirectory",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.BasicDirectory",
    "category": "type",
    "text": "BasicDirectory(map::BlockMap)\n\nCreates a BasicDirectory, which implements the methods of Directory with basic implmentations\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.getDirectoryEntries",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.getDirectoryEntries",
    "category": "function",
    "text": "getDirectoryEntries(directory, map::BlockMap{GID, PID, LID}, globalEntries::AbstractArray{GID}, high_rank_sharing_procs::Bool)::Tuple{AbstractArray{PID}, AbstractArray{LID}}\n\nReturns processor and local id information for non-local map entries.  Returns a tuple containing\n\nan Array of processors owning the global ID\'s in question\nan Array of local IDs of the global on the owning processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.gidsAllUniquelyOwned",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.gidsAllUniquelyOwned",
    "category": "function",
    "text": "gidsAllUniquelyOwned(directory)\n\nReturns true if all GIDs appear on just one processor\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.createDirectory",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.createDirectory",
    "category": "function",
    "text": "createDirectory(comm::Comm, map::BlockMap)\n\nCreate a directory object for the given Map\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#Directory-1",
    "page": "Problem Distribution Layer",
    "title": "Directory",
    "category": "section",
    "text": "Directory\nBasicDirectory\ngetDirectoryEntries\ngidsAllUniquelyOwned\ncreateDirectory"
},

{
    "location": "ProblemDistributionLayer/#Converting-IDs-Between-Maps-1",
    "page": "Problem Distribution Layer",
    "title": "Converting IDs Between Maps",
    "category": "section",
    "text": "Export\nImport\nsourceMap\ntargetMap\ndistributor\nisLocallyComplete\npermuteToLIDs\npermuteFromLIDs\nexportLIDs\nremoteLIDs\nremotePIDs\nnumSameIDs"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.DistObject",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.DistObject",
    "category": "type",
    "text": "An interface for providing a target when constructing and using multi-vectors, and matrices in parallel.\n\nTo support transfers the following methods must be implemented for the combination of source type and the target type\n\ngetMap(::DistObject)\n\nGets the map of the indices of the object\n\ncheckSizes(source::<:SrcDistObject{GID, PID, LID}, target::<:DistObject{GID, PID, LID})::Bool\n\nWhether the source and target are compatible for a transfer\n\ncopyAndPermute(source::<:SrcDistObject{GID, PID, LID}, target::<:DistObject{GID, PID, LID}, numSameIDs::LID, permuteToLIDs::AbstractArray{LID, 1}, permuteFromLIDs::AbstractArray{LID, 1})\n\nPerform copies and permutations that are local to this process.\n\npackAndPrepare(source::<:SrcDistObject{GID, PID, LID}, target::<:DistObjectGID, PID, LID}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID})::AbstractArray\n\nPerform any packing or preparation required for communications.  The method returns the array of objects to export\n\nunpackAndCombine(target::<:DistObject{GID, PID, LID}, importLIDs::AbstractArray{LID, 1}, imports::AAbstractrray, distor::Distributor{GID, PID, LID}, cm::CombineMode)\n\nPerform any unpacking and combining after communication\n\nSee SrcDistObject\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.SrcDistObject",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.SrcDistObject",
    "category": "type",
    "text": "An interface for providing a source when constructing and using multi-vectors and matrices in parallel.\n\ngetMap(::SrcDistObject)\n\nGets the map of the indices of the object\n\nSee DistObject\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.CombineMode",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.CombineMode",
    "category": "type",
    "text": "Tells JuliaPetra how to combine data received from other processes with existing data on the calling process for specific import or export options.\n\nHere is the list of combine modes:\n\nADD: Sum new values into existing values\nINSERT: Insert new values that don\'t currently exist\nREPLACE: REplace existing values with new values\nABSMAX: If x_old is the old value and x_new the incoming new value, replace x_old with max(x_old x_new)\nZERO: Replace old values with zero\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.getMap",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.getMap",
    "category": "function",
    "text": "getMap(::SrcDistObject)\ngetMap(::DistObject)\n\nGets the map of the indices of the object\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.checkSizes",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.checkSizes",
    "category": "function",
    "text": "checkSizes(source, target)::Bool\n\nCompare the source and target objects for compatiblity.  By default, returns false.  Override this to allow transfering to/from subtypes\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.copyAndPermute",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.copyAndPermute",
    "category": "function",
    "text": "copyAndPermute(source::<:SrcDistObject{GID, PID, LID}, target::<:DistObject{GID, PID, LID}, numSameIDs::LID, permuteToLIDs::AbstractArray{LID, 1}, permuteFromLIDs::AbstractArray{LID, 1})\n\nPerform copies and permutations that are local to this process.\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.packAndPrepare",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.packAndPrepare",
    "category": "function",
    "text": "packAndPrepare(source::<:SrcDistObject{GID, PID, LID}, target::<:DistObjectGID, PID, LID}, exportLIDs::AbstractArray{LID, 1}, distor::Distributor{GID, PID, LID})::AbstractArray\n\nPerform any packing or preparation required for communications.  The method returns the array of objects to export\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#JuliaPetra.unpackAndCombine",
    "page": "Problem Distribution Layer",
    "title": "JuliaPetra.unpackAndCombine",
    "category": "function",
    "text": "unpackAndCombine(target::<:DistObject{GID, PID, LID}, importLIDs::AbstractArray{LID, 1}, imports::AAbstractrray, distor::Distributor{GID, PID, LID}, cm::CombineMode)\n\nPerform any unpacking and combining after communication\n\n\n\n\n\n"
},

{
    "location": "ProblemDistributionLayer/#Converting-Data-Structures-Between-Maps-1",
    "page": "Problem Distribution Layer",
    "title": "Converting Data Structures Between Maps",
    "category": "section",
    "text": "Converting data structures between maps is built on the DistObject and SrcDistObject interfaces.DistObject\nSrcDistObject\nCombineMode\ngetMap\ncheckSizes\ncopyAndPermute\npackAndPrepare\nunpackAndCombine"
},

{
    "location": "LinearAlgebraLayer/#",
    "page": "Linear Algebra Layer",
    "title": "Linear Algebra Layer",
    "category": "page",
    "text": ""
},

{
    "location": "LinearAlgebraLayer/#Linear-Algebra-Layer-1",
    "page": "Linear Algebra Layer",
    "title": "Linear Algebra Layer",
    "category": "section",
    "text": "CurrentModule = JuliaPetraThe Linear Algebra layer provides the main abstractions for linear algebra codes. The two top level interfaces are MultiVector, for groups of vectors, and Operator, for operations on MultiVectors."
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.MultiVector",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.MultiVector",
    "category": "type",
    "text": "MultiVectors represent a group of vectors to be processed together. They are a subtype of [AbstractArray{Data, 2}] and support the [DistObject], and [SrcDistObject] for transfering between any two MultiVectors. Required methods:\n\ngetMap(::MultiVector)\nnumVectors(::MultiVector)\ngetLocalArray(::MultiVector{Data})::AbstractMatrix{Data}\nsimilar(::MultiVector{Data})\n\ncommReduce(::MultiVector) may need to be overridden if getLocallArray(multiVector) doesn\'t return a type useable by sumAll.\n\nSee [DenseMultiVector] for a concrete implementation.\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.DenseMultiVector",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.DenseMultiVector",
    "category": "type",
    "text": "DenseMultiVector represents a dense multi-vector.  Note that all the vectors in a single DenseMultiVector are the same size\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.localLength",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.localLength",
    "category": "function",
    "text": "localLength(::MultiVector{Data, GID, PID, LID})::LID\n\nReturns the local length of the vectors in the MultiVector\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.globalLength",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.globalLength",
    "category": "function",
    "text": "globalLength(::MultiVector{Data, GID, PID, LID})::GID\n\nReturns the global length of the vectors in the mutlivector\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.numVectors",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.numVectors",
    "category": "function",
    "text": "numVectors(::MultiVector{Data, GID, PID, LID})::LID\n\nReturns the number of vectors in this MultiVector\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.getVectorView",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.getVectorView",
    "category": "function",
    "text": "getVectorView(::DenseMultiVector{Data}, columns)::AbstractArray{Data}\n\nGets a view of the requested column vector(s) in this DenseMultiVector\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.getVectorCopy",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.getVectorCopy",
    "category": "function",
    "text": "getVectorCopy(::MultiVector{Data}, columns)::Array{Data}\n\nGets a copy of the requested column vector(s) in this MultiVector\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.getLocalArray",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.getLocalArray",
    "category": "function",
    "text": "getLocalArray(::MultiVector{Data})::AbstractMatrix{Data}\n\nReturns the array holding the MultiVector\'s local elements. Changes to the array content are be reflected in the MultiVector\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.commReduce",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.commReduce",
    "category": "function",
    "text": "commReduce(::MultiVector)\n\nElementwise reduces the content of the MultiVector across all processes. Note that the MultiVector cannot be distributed globally.\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#MultiVectors-1",
    "page": "Linear Algebra Layer",
    "title": "MultiVectors",
    "category": "section",
    "text": "MutliVectors support many basic array functions, including broadcasting. Additionally, [dot] and [norm] are supported, however they return arrays since [MultiVector]s may have multiple dot products and norms.MultiVector\nDenseMultiVector\nlocalLength\nglobalLength\nnumVectors\ngetVectorView\ngetVectorCopy\ngetLocalArray\ncommReduce"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.Operator",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.Operator",
    "category": "type",
    "text": "Operator is a description of all types that have a specific set of methods.\n\nAll Operator types must implement the following methods (with Op standing in for the Operator):\n\napply!(Y::MultiVector{Data, GID, PID, LID}, operator::Op{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}, mode::TransposeMode, alpha::Data, beta::Data)\n\nComputes Y = αcdot A^modecdot X + βcdot Y, with the following exceptions\n\nIf beta == 0, apply MUST overwrite Y, so that any values in Y (including NaNs) are ignored.\nIf alpha == 0, apply MAY short-circuit the operator, so that any values in X (including NaNs) are ignored\n\ngetDomainMap(operator::Op{Data, GID, PID, LID})::BlockMap{GID, PID, LID}\n\nReturns the BlockMap associated with the domain of this operation\n\ngetRangeMap(operator::Op{Data, GID, PID, LID})::BlockMap{GID, PID, LID}\n\nReturns the BlockMap associated with the range of this operation\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.getRangeMap",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.getRangeMap",
    "category": "function",
    "text": "getRangeMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}\n\nGets the range map for the graph\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.getDomainMap",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.getDomainMap",
    "category": "function",
    "text": "getDomainMap(::RowGraph{GID, PID, LID})::BlockMap{GID, PID, LID}\n\nGets the domain map for the graph\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.apply!",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.apply!",
    "category": "function",
    "text": "apply!(Y::MultiVector, operator, X::MultiVector, mode::TransposeMode=NO_TRANS, alpha=1, beta=0)\napply!(Y::MultiVector, operator, X::MultiVector, alpha=1, beta=0)\n\nComputes Y = αcdot A^modecdot X + βcdot Y, with the following exceptions:\n\nIf beta == 0, apply MUST overwrite Y, so that any values in Y (including NaNs) are ignored.\nIf alpha == 0, apply MAY short-circuit the operator, so that any values in X (including NaNs) are ignored\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.apply",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.apply",
    "category": "function",
    "text": "apply(Y::MultiVector,operator, X::MultiVector,  mode::TransposeMode=NO_TRANS, alpha=1, beta=0)\napply(Y::MultiVector, operator, X::MultiVector, alpha=1, beta=0)\n\nAs apply! except returns a new array for the results\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.TransposeMode",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.TransposeMode",
    "category": "type",
    "text": "Tells JuliaPetra to use the transpose or conjugate transpose of the matrix\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.isTransposed",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.isTransposed",
    "category": "function",
    "text": "isTransposed(mode::TransposeMode)::Bool\n\nChecks whether the given TransposeMode is transposed\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.applyConjugation",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.applyConjugation",
    "category": "function",
    "text": "applyConjugation(mode::TraseposeMode, val)\n\nIf mode is CONJ_TRANS, the take the conjugate. Otherwise, just return the value.\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#Operators-1",
    "page": "Linear Algebra Layer",
    "title": "Operators",
    "category": "section",
    "text": "Operators represent an operation on a MultiVector, such as a matrix which applies a matrix-vector product.Operator\ngetRangeMap\ngetDomainMap\napply!\napply\nTransposeMode\nisTransposed\napplyConjugation"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.RowMatrix",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.RowMatrix",
    "category": "type",
    "text": "RowMatrix is the base type for all row oriented Petra matrices. RowMatrix fufils both the Operator and DistObject interfaces.\n\ngetGraph(mat::RowMatrix)::RowGraph\n\nReturns the graph that represents the structure of the row matrix\n\ngetLocalRowCopy!(copy::Tuple{<:AbstractVector{<:Integer}, <:AbstractVector{Data}}, matrix::RowMatrix{Data, GID, PID, LID}, localRow::LID)::Integer\n\nCopies the given row into the provided arrays and returns the number of elements in that row using local indices\n\ngetGlobalRowCopy!(copy::Tuple{<:AbstractVector{<:Integer}, <:AbstractVector{Data}}, matrix::RowMatrix{Data, GID, PID, LID}, globalRow::GID)::Integer\n\nCopies the given row into the provided arrays and returns the number of elements in that row using global indices\n\ngetGlobalRowView(matrix::RowMatrix{Data, GID, PID, LID}, globalRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}\n\nReturns a view to the given row using global indices\n\ngetLocalRowView(matrix::RowMatrix{Data, GID, PID, LID},localRow::Integer)::Tuple{AbstractArray{GID, 1}, AbstractArray{Data, 1}}\n\nReturns a view to the given row using local indices\n\ngetLocalDiagCopy!(copy::MultiVector{Data, GID, PID, LID}, matrix::RowMatrix{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID}\n\nCopies the local diagonal into the given MultiVector then returns the MultiVector\n\nleftScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::AbstractArray{Data, 1})\n\nScales matrix on the left with X\n\nrightScale!(matrix::RowMatrix{Data, GID, PID, LID}, X::AbstractArray{Data, 1})\n\nScales matrix on the right with X\n\ngetMap(...), as required by SrcDistObject, is implemented by calling getRowMap(...)\n\napply!(...), as required by Operator, is implemented, but can be optimized by overrideing the following method     localApply(Y::MultiVector, A::RowMatrix, X::MultiVector, ::TransposeMode, α::Data, β::Data) Does the computations for Y = β⋅Y + α⋅A⋅X, X and Y match the row map and column map, depending on the transpose mode\n\nThe following methods are currently implemented as no-ops, but can be overridden to improve performance.\n\nsetColumnMapMultiVector(::RowMatrix{Data, GID, PID, LID}, ::Union{MultiVector{Data, GID, PID, LID}, Nothing})\n\nCaches a MultiVector that uses the matrix\'s column map.\n\ngetColumnMapMultiVector(::RowMatrix{Data, GID, PID, LID})::Union{MultiVector{Data, GID, PID, LID}, Nothing}\n\nFetches any cached MultiVector that uses the matrix\'s column map.\n\nsetRowMapMultiVector(::RowMatrix{Data, GID, PID, LID}, ::Union{MultiVector{Data, GID, PID, LID}, Nothing})\n\nCaches a MultiVector that uses the matrix\'s row map.\n\ngetRowMapMultiVector(::RowMatrix{Data, GID, PID, LID})::Union{MultiVector{Data, GID, PID, LID}, Nothing}\n\nFetches any cached MultiVector that uses the matrix\'s row map.\n\nSome pre-implemented methods can be optimized by providing specialized implementations apply!, as mentioned above All RowMatrix methods that are also implemented by RowGraph are implemented using getGraph. pack is implemented using getLocalRowCopy getGlobalRowCopy! is implemented by calling getLocalRowCopy! and remapping the values using gid(::BlockMap, ::Integer)\n\nAdditionally, Julia\'s mul! and * functions are implemented for RowMatrix-MultiVector products\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#JuliaPetra.CSRMatrix",
    "page": "Linear Algebra Layer",
    "title": "JuliaPetra.CSRMatrix",
    "category": "type",
    "text": "An implementation of RowMatrix that uses CSR format\n\n\n\n\n\n"
},

{
    "location": "LinearAlgebraLayer/#Matrices-1",
    "page": "Linear Algebra Layer",
    "title": "Matrices",
    "category": "section",
    "text": "Sparse matrices are the primary Operator in JuliaPetra.RowMatrix\nCSRMatrix"
},

]}
