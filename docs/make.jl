using Documenter, QPSReader

makedocs(
  modules = [QPSReader],
  doctest = true,
  format = Documenter.HTML(
    assets = ["assets/style.css"],
    prettyurls = get(ENV, "CI", nothing) == "true",
  ),
  sitename = "QPSReader.jl",
  pages = Any["Home" => "index.md", "Tutorial" => "tutorial.md", "Reference" => "reference.md"],
)

deploydocs(
  repo = "github.com/JuliaSmoothOptimizers/QPSReader.jl.git",
  push_preview = true,
  devbranch = "main",
)
