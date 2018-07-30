#mainly just exercies the basic constructors

n = 8

serialComm = SerialComm{Int32, Bool, Int16}()
srcMap = BlockMap(n, n, serialComm)
desMap = BlockMap(n, n, serialComm)

function basicTest(impor)
    if isa(impor, Import)
        data = impor.importData
    else
        # basic exports are about the same anyways
        data = impor.exportData
    end
    @test srcMap == data.source
    @test desMap == data.target
    @test n == data.numSameIDs
    @test isa(data.distributor, Distributor{Int32, Bool, Int16})
    @test [] == data.permuteToLIDs
    @test [] == data.permuteFromLIDs
    @test [] == data.remoteLIDs
    @test [] == data.exportLIDs
    @test [] == data.exportPIDs
    @test true == data.isLocallyComplete
end

#for scoping purposes
impor = Array{Import, 1}(1)
expor = Array{Export, 1}(1)

#ensure at least a few lines, each starting with the PID
#Need to escape coloring:  .*
debugregex = Regex("^(?:.*INFO: .*$(myPid(serialComm)): .+\n){2,}.*\$")

# basic import
@test_warn debugregex impor[1] = Import(srcMap, desMap)
basicTest(impor[1])

@test_warn debugregex impor[1] = Import(srcMap, desMap, Nullable{AbstractArray{Bool}}())
basicTest(impor[1])


# basic export
@test_warn debugregex expor[1] = Export(srcMap, desMap)
basicTest(expor[1])
@test_warn debugregex expor[1] = Export(srcMap, desMap, Nullable{AbstractArray{Bool}}())
basicTest(expor[1])
