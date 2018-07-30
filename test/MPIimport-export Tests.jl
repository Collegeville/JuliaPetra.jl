n = 4

srcMap = BlockMap(4*n, comm)
desMap = BlockMap(n*numProc(comm), collect((1:n) + n*(pid%4)), comm)

function basicMPITest(impor)
    if isa(impor, Import)
        data = impor.importData
    else
        data = impor.exportData
    end
    @test srcMap == data.source
    @test desMap == data.target
    @test 0 == data.numSameIDs
    @test isa(data.distributor, Distributor{UInt64, UInt16, UInt32})
    @test [] == data.permuteToLIDs
    @test [] == data.permuteFromLIDs
    #TODO test remoteLIDs, exportLIDs, exportPIDs
    @test true == data.isLocallyComplete
end

#for scoping purposes
impor = Array{Import, 1}(1)
expor = Array{Export, 1}(1)

#ensure at least a few lines, each starting with the PID
#Need to escape coloring:  .*
#"^(?:.*INFO: .*$pid: .+\n){2,}.*\$"
debugregex = Regex("^(?:.*INFO: .*$pid: .+\n){2,}.*\$")

# basic import
@test_warn debugregex impor[1] = Import(srcMap, desMap)
basicMPITest(impor[1])
@test_warn debugregex impor[1] = Import(srcMap, desMap, Nullable{AbstractArray{UInt16}}())
basicMPITest(impor[1])

# basic export
@test_warn debugregex expor[1] = Export(srcMap, desMap)
basicMPITest(expor[1])
@test_warn debugregex expor[1] = Export(srcMap, desMap, Nullable{AbstractArray{UInt16}}())
basicMPITest(expor[1])
