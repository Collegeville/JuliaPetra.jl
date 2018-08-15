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

#ensure at least a one line, starting with the PID
debugregex = Regex("^$(myPid(serialComm)):.+")

# basic import
impor = (@test_logs (:info, debugregex) match_mode=:any Import(srcMap, desMap))
basicTest(impor)

impor = (@test_logs (:info, debugregex) match_mode=:any Import(srcMap, desMap, nothing))
basicTest(impor)


# basic export
expor = (@test_logs (:info, debugregex) match_mode=:any Export(srcMap, desMap))
basicTest(expor)

expor = (@test_logs (:info, debugregex) match_mode=:any Export(srcMap, desMap, nothing))
basicTest(expor)
