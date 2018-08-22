#due to compile time settings, all the tests need to be run with compiled-modules=no


code = """
    $(Base.load_path_setup_code(false))
    cd("$(pwd())")
    include("mpi-runtests.jl")
"""

run(```
    mpiexec -n 4
        $(Base.julia_cmd())
        --code-coverage=$(Bool(Base.JLOptions().code_coverage) ? "user" : "none")
        --color=$(Base.have_color ? "yes" : "no")
        --compiled-modules=no
        --check-bounds=yes
        --startup-file=$(Base.JLOptions().startupfile == 1 ? "yes" : "no")
        --track-allocation=$(("none", "user", "all")[Base.JLOptions().malloc_log + 1])
        --eval $code
```)
