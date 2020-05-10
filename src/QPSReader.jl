module QPSReader

export QPSData, readqps

include("readqps.jl")

if VERSION ≥ v"1.3"
  using Pkg.Artifacts

  export fetch_netlib, fetch_mm

  "Return the path to the Netlib linear optimization test set."
  function fetch_netlib()
    artifact_toml = joinpath(@__DIR__, "..", "Artifacts.toml")
    ensure_artifact_installed("netliblp", artifact_toml)
    netliblp_hash = artifact_hash("netliblp", artifact_toml)
    @assert artifact_exists(netliblp_hash)
    return joinpath(artifact_path(netliblp_hash), "optrove-netlib-lp-f83996fca937")
  end

  "Return the path to the Maros-Meszaros quadratic optimization test set."
  function fetch_mm()
    artifact_toml = joinpath(@__DIR__, "..", "Artifacts.toml")
    ensure_artifact_installed("marosmeszaros", artifact_toml)
    mm_hash = artifact_hash("marosmeszaros", artifact_toml)
    @assert artifact_exists(mm_hash)
    return joinpath(artifact_path(mm_hash), "optrove-maros-meszaros-9adfb5707b1e")
  end
end

end # module
