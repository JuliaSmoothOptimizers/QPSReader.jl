using Test
using Logging

using QPSReader

if VERSION ≥ v"1.3"
  netlib_path = fetch_netlib()
  @test ispath(netlib_path)
  @test isfile(joinpath(netlib_path, "AFIRO.SIF"))
  mm_path = fetch_mm()
  @test ispath(mm_path)
  @test isfile(joinpath(mm_path, "AUG3D.SIF"))
end

include("parser.jl")
include("qp-example.jl")
include("rimdata.jl")
include("integers.jl")