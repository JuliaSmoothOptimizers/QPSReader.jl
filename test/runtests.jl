using Test

using QPSReader, NLPModels, NLPModelsIpopt, QuadraticModels, LinearOperators

# download qps files

for PROBLEM in ["GENHS28.SIF", "HS76.SIF", "QPTEST.SIF"]
  run(`wget https://bitbucket.org/optrove/maros-meszaros/raw/9adfb5707b1e0b83a2e0a26cc8310704ff01b7c1/$PROBLEM`)
end

problems = ["GENHS28.SIF"; "HS76.SIF"; "QPTEST.SIF"]
objectives = [9.2717369e-01; -4.6818182e+00; 4.3718750e+00]

@testset "qpsreader" begin
  for (k, p) in enumerate(problems)
    qps = readqps("../$p")
    qp = QuadraticModel(qps.c, qps.Q, opHermitian(qps.Q), qps.A, qps.lcon, qps.ucon, qps.lvar, qps.uvar, c0=qps.c0)

    output = ipopt(qp, print_level=0)

    @test output.dual_feas < 1e-6
    @test output.primal_feas < 1e-6
    @test abs(output.objective - objectives[k]) < 1e-6
  end
end # testset
