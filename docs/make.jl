using Documenter, JuliaPetra

makedocs(
    modules = [JuliaPetra],
    sitename="JuliaPetra",
    pages = [
        "Home" => "index.md",
        "Communcation Layer" => "CommunicationLayer.md",
        "Problem Distribution Layer" => "ProblemDistributionLayer.md",
        "Linear Algebra Layer" => "LinearAlgebraLayer.md"
    ])


deploydocs(
    repo = "github.com/collegeville/JuliaPetra.jl.git"
)
