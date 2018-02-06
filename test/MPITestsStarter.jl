
test_path = test_path = abspath(Pkg.dir(), "JuliaPetra", "test", "runMPITests.jl")
color = Base.have_color? "--color=yes" : "--color=no"
codecov = (Bool(Base.JLOptions().code_coverage)? ["--code-coverage=user"] : ["--code-coverage=none"])
compilecache = "--compilecache=" * (Bool(Base.JLOptions().use_compilecache) ? "yes" : "no")
julia_exe = Base.julia_cmd()
run(`mpirun -np 4 $julia_exe --check-bounds=yes $codecov $color $compilecache $test_path`)
