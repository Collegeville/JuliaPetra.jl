n = 4

srcMap = BlockMap(4*n, comm)
desMap = BlockMap(n*numProc(comm), collect((1:n) .+ n*(pid%4)), comm)

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

#ensure at least a few lines, each starting with the PID
#Need to escape coloring:  .*
#"^(?:.*INFO: .*$pid: .+\n){2,}.*\$"
debugregex = Regex("^$pid: .+")

# basic import
impor = (@test_logs (:info, debugregex) match_mode=:any Import(srcMap, desMap))
basicMPITest(impor)
impor = (@test_logs (:info, debugregex) match_mode=:any Import(srcMap, desMap, nothing))
basicMPITest(impor)

# basic export
expor = (@test_logs (:info, debugregex) match_mode=:any Export(srcMap, desMap))
basicMPITest(expor)
expor = (@test_logs (:info, debugregex) match_mode=:any Export(srcMap, desMap, nothing))
basicMPITest(expor)
