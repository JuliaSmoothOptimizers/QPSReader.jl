module QPSReader

export QPSData, readqps
using LazyArtifacts

include("readqps.jl")

export fetch_netlib, fetch_mm

"Return the path to the Netlib linear optimization test set."
function fetch_netlib()
  return joinpath(artifact"netliblp", "optrove-netlib-lp-f83996fca937")
end

"Return the path to the Maros-Meszaros quadratic optimization test set."
function fetch_mm()
  return joinpath(artifact"marosmeszaros", "optrove-maros-meszaros-9adfb5707b1e")
end

end # module
