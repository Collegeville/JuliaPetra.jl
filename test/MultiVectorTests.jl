#these tests are used for test MultiVector under both serial and MPI comms

function multiVectorTests(comm::Comm{UInt64, UInt16, UInt32})
    #number of elements in vectors
    n = 8

    pid = myPid(comm)
    nProcs = numProc(comm)

    curMap = BlockMap(nProcs*n, n, comm)

    # test basic construction with setting data to zeros
    vect = MultiVector{Float64, UInt64, UInt16, UInt32}(curMap, 3, true)
    @test n == localLength(vect)
    @test nProcs*n == globalLength(vect)
    @test 3 == numVectors(vect)
    @test curMap == getMap(vect)
    @test zeros(Float64, (n, 3)) == vect.data

    # test basic construction without setting data to zeros
    vect = MultiVector{Float64, UInt64, UInt16, UInt32}(curMap, 3, false)
    @test n == localLength(vect)
    @test nProcs*n == globalLength(vect)
    @test 3 == numVectors(vect)
    @test curMap == getMap(vect)

    # test wrapper constructor
    arr = Array{Float64, 2}(n, 3)
    vect = MultiVector(curMap, arr)
    @test n == localLength(vect)
    @test nProcs*n == globalLength(vect)
    @test 3 == numVectors(vect)
    @test curMap == getMap(vect)
    @test arr === vect.data

    # test copy
    vect2 = copy(vect)
    @test n == localLength(vect)
    @test nProcs*n == globalLength(vect)
    @test 3 == numVectors(vect)
    @test curMap == getMap(vect)
    @test vect.data == vect2.data
    @test vect.data !== vect2.data #ensure same contents, but different address

    vect2 = MultiVector{Float64, UInt64, UInt16, UInt32}(curMap, 3, false)
    @test vect2 === copy!(vect2, vect)
    @test localLength(vect) == localLength(vect2)
    @test globalLength(vect) == globalLength(vect2)
    @test numVectors(vect) == numVectors(vect2)
    @test getMap(vect) == getMap(vect2)
    @test vect.data == vect2.data
    @test vect.data !== vect2.data


    # test scale and scale!
    vect = MultiVector(curMap, ones(Float64, n, 3))
    @test vect === scale!(vect, pid*5.0)
    @test pid*5*ones(Float64, (n, 3)) == vect.data

    vect = MultiVector(curMap, ones(Float64, n, 3))
    vect2 = scale(vect, pid*5.0)
    @test vect !== vect2
    @test pid*5*ones(Float64, (n, 3)) == vect2.data

    increase = pid*nProcs

    vect = MultiVector(curMap, ones(Float64, n, 3))
    @test vect isa MultiVector
    @test vect === scale!(vect, increase+[2.0, 3.0, 4.0])
    @test hcat( (increase+2)*ones(Float64, n),
                (increase+3)*ones(Float64, n),
                (increase+4)*ones(Float64, n))  == vect.data

    for i = 1:3
        act = i+1+repeat(Float64[increase], inner=n)
        @test act == getVectorView(vect, i)
        @test act == getVectorCopy(vect, i)
    end

    vect = MultiVector(curMap, ones(Float64, n, 3))
    vect2 = scale(vect, pid*nProcs+[2.0, 3.0, 4.0])
    @test vect !== vect2
    @test hcat( (pid*nProcs+2)*ones(Float64, n),
                (pid*nProcs+3)*ones(Float64, n),
                (pid*nProcs+4)*ones(Float64, n))  == vect2.data

    #test dot
    vect = MultiVector(curMap, ones(Float64, n, 3))
    @test fill(n*nProcs, 3) == dot(vect, vect)

    #test fill!
    fill!(vect, 8)
    @test 8*ones(Float64, (n, 3)) == vect.data


    #test reduce
    arr = (10^pid)*ones(Float64, n, 3)
    vect = MultiVector(BlockMap(n, n, comm), arr)
    commReduce(vect)
    @test sum(10^i for i in 1:nProcs)*ones(Float64, n, 3) == vect.data


    #test norm2
    arr = ones(Float64, n, 3)
    vect = MultiVector(curMap, arr)
    @test [sqrt(n*nProcs), sqrt(n*nProcs), sqrt(n*nProcs)] == norm2(vect)

    arr = 2*ones(Float64, n, 3)
    vect = MultiVector(curMap, arr)
    @test [sqrt(4*n*nProcs), sqrt(4*n*nProcs), sqrt(4*n*nProcs)] == norm2(vect)



    #test imports/exports
    source = MultiVector(curMap,
        Array{Float64, 2}(reshape(collect(1:(3*n)), (n, 3))))
    target = MultiVector{Float64, UInt64, UInt16, UInt32}(curMap, 3, false)
    impor = Import(curMap, curMap)
    doImport(source, target, impor, REPLACE)
    @test reshape(Array{Float64, 1}(collect(1:(3*n))), (n, 3)) == target.data


    source = MultiVector(curMap,
        Array{Float64, 2}(reshape(collect(1:(3*n)), (n, 3))))
    target = MultiVector{Float64, UInt64, UInt16, UInt32}(curMap, 3, false)
    expor = Export(curMap, curMap)
    doExport(source, target, expor, REPLACE)
    @test reshape(Array{Float64, 1}(collect(1:(3*n))), (n, 3)) == target.data

    source = MultiVector(curMap,
        Array{Float64, 2}(reshape(collect(1:(3*n)), (n, 3))))
    target = MultiVector{Float64, UInt64, UInt16, UInt32}(curMap, 3, false)
    impor = Import(curMap, curMap)
    doExport(source, target, impor, REPLACE)
    @test reshape(Array{Float64, 1}(collect(1:(3*n))), (n, 3)) == target.data


    source = MultiVector(curMap,
        Array{Float64, 2}(reshape(collect(1:(3*n)), (n, 3))))
    target = MultiVector{Float64, UInt64, UInt16, UInt32}(curMap, 3, false)
    expor = Export(curMap, curMap)
    doImport(source, target, expor, REPLACE)
    @test reshape(Array{Float64, 1}(collect(1:(3*n))), (n, 3)) == target.data

    #TODO create import expor tests to test non trivial case

end
