@testset "Integers" begin
  @testset "$format" for format in [:fixed, :free]
    milp = with_logger(Logging.NullLogger()) do
      readqps("dat/milp.mps", mpsformat = format)
    end

    @test milp.vartypes[1] == QPSReader.VTYPE_Continuous  # no marker
    @test milp.vartypes[2] == QPSReader.VTYPE_Integer  # marker + no bounds
    @test milp.vartypes[3] == QPSReader.VTYPE_Binary  # marker + binary bound
    @test milp.vartypes[4] == QPSReader.VTYPE_Integer  # marker + LI
    @test milp.vartypes[5] == QPSReader.VTYPE_Integer  # marker + UI (>0)
    @test milp.vartypes[6] == QPSReader.VTYPE_Integer  # marker + UI (<0)
    @test milp.vartypes[7] == QPSReader.VTYPE_Integer  # marker + LI + UI
    @test milp.vartypes[8] == QPSReader.VTYPE_Integer  # marker + LO
    @test milp.vartypes[9] == QPSReader.VTYPE_Integer  # marker + UP (>0)
    @test milp.vartypes[10] == QPSReader.VTYPE_Integer  # marker + UP (<0)
    @test milp.vartypes[11] == QPSReader.VTYPE_Integer  # marker + LO + UP
    @test milp.vartypes[12] == QPSReader.VTYPE_Binary  # no marker + BV
    @test milp.vartypes[13] == QPSReader.VTYPE_Integer  # no marker + LI
    @test milp.vartypes[14] == QPSReader.VTYPE_Integer  # no marker + UI (>0)
    @test milp.vartypes[15] == QPSReader.VTYPE_Integer  # no marker + UI (<0)
    @test milp.vartypes[16] == QPSReader.VTYPE_Integer  # no marker + LI + UI
    @test milp.vartypes[17] == QPSReader.VTYPE_Continuous  # no marker + UP (<0)

    # Test bounds values
    @test (milp.lvar[1], milp.uvar[1]) == (0.0, Inf)
    @test (milp.lvar[2], milp.uvar[2]) == (0.0, 1.0)
    @test (milp.lvar[3], milp.uvar[3]) == (0.0, 1.0)
    @test (milp.lvar[4], milp.uvar[4]) == (-4.0, Inf)
    @test (milp.lvar[5], milp.uvar[5]) == (0.0, 5.0)
    @test (milp.lvar[6], milp.uvar[6]) == (-Inf, -6.0)
    @test (milp.lvar[7], milp.uvar[7]) == (-7.0, 7.0)
    @test (milp.lvar[8], milp.uvar[8]) == (-8.0, Inf)
    @test (milp.lvar[9], milp.uvar[9]) == (0.0, 9.0)
    @test (milp.lvar[10], milp.uvar[10]) == (-Inf, -10.0)
    @test (milp.lvar[11], milp.uvar[11]) == (-11.0, 11.0)
    @test (milp.lvar[12], milp.uvar[12]) == (0.0, 1.0)
    @test (milp.lvar[13], milp.uvar[13]) == (-13.0, Inf)
    @test (milp.lvar[14], milp.uvar[14]) == (0.0, 14.0)
    @test (milp.lvar[15], milp.uvar[15]) == (-Inf, -15.0)
    @test (milp.lvar[16], milp.uvar[16]) == (-16.0, 16.0)
    @test (milp.lvar[17], milp.uvar[17]) == (-Inf, -17.0)
  end
end
