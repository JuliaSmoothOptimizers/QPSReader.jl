@testset "Integers" begin
@testset "$format" for format in [:fixed, :free]

    milp = with_logger(Logging.NullLogger()) do
        readqps("dat/milp.mps", mpsformat=format)
    end

    @test milp.vartypes[1]  == QPSReader.VTYPE_C  # no marker
    @test milp.vartypes[2]  == QPSReader.VTYPE_I  # marker + no bounds
    @test milp.vartypes[3]  == QPSReader.VTYPE_B  # marker + binary bound
    @test milp.vartypes[4]  == QPSReader.VTYPE_I  # marker + LI
    @test milp.vartypes[5]  == QPSReader.VTYPE_I  # marker + UI
    @test milp.vartypes[6]  == QPSReader.VTYPE_I  # marker + LI + UI
    @test milp.vartypes[7]  == QPSReader.VTYPE_B  # no marker + BV
    @test milp.vartypes[8]  == QPSReader.VTYPE_I  # no marker + LI
    @test milp.vartypes[9]  == QPSReader.VTYPE_I  # no marker + UI
    @test milp.vartypes[10] == QPSReader.VTYPE_C  # no marker

    # Test bounds values
    @test (milp.lvar[1],  milp.uvar[1])  == (0.0,  Inf)
    @test (milp.lvar[2],  milp.uvar[2])  == (0.0,  1.0)
    @test (milp.lvar[3],  milp.uvar[3])  == (0.0,  1.0)
    @test (milp.lvar[4],  milp.uvar[4])  == (-4.0, Inf)
    @test (milp.lvar[5],  milp.uvar[5])  == (0.0,  5.0)
    @test (milp.lvar[6],  milp.uvar[6])  == (-6.0, 6.0)
    @test (milp.lvar[7],  milp.uvar[7])  == (0.0,  1.0)
    @test (milp.lvar[8],  milp.uvar[8])  == (-8.0, Inf)
    @test (milp.lvar[9],  milp.uvar[9])  == (0.0,  9.0)
    @test (milp.lvar[10], milp.uvar[10]) == (0.0,  Inf)

end
end