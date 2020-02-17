using SparseArrays

# this is the example on pages 3-5 of
# I. Maros and C. Meszaros, "A Repository of Convex Quadratic Programming Problems",
# Technical Report DOC 97/6, Department of Computing, Imperial College, London, UK, 1997
# http://www.doc.ic.ac.uk/rr2000/DTR97-6.pdf

@testset "QP example" begin

    # Test logging
    # Note that logs won't display since they are captured by the test macro
    qp = @test_logs(
        # These logs must appear in exactly this order
        (:info, "Problem name     : QP example"),
        (:info, "Objective sense  : notset"),
        (:info, "Objective name   : obj"),
        (:info, "RHS              : rhs1"),
        (:info, "RANGES           : nothing"),
        (:info, "BOUNDS           : bnd1"),
        match_mode = :all,
        readqps("dat/qp-example.qps")
    )

    @test qp.name == "QP example"
    @test qp.objname == "obj"
    @test qp.rhsname == "rhs1"
    @test qp.bndname == "bnd1"
    @test isnothing(qp.rngname)

    @test qp.nvar == 2
    @test qp.ncon == 2
    @test qp.c0 == 4.0
    @test all(qp.c .== [1.5, -2.0])
    Q = sparse(qp.qrows, qp.qcols, qp.qvals, qp.nvar, qp.nvar)
    A = sparse(qp.arows, qp.acols, qp.avals, qp.ncon, qp.nvar)
    @test all(Matrix(Q) .== [8.0 0.0 ; 2.0 10.0])
    @test all(Matrix(A) .== [2.0 1.0 ; -1.0 2.0])
    @test all(qp.lcon .== [2.0, -Inf])
    @test all(qp.ucon .== [Inf, 6.0])
    @test all(qp.lvar .== [0.0, 0.0])
    @test all(qp.uvar .== [20.0, Inf])

    @test qp.connames == ["r1", "r2"]
    @test qp.varnames == ["c1", "c2"]
    @test qp.varindices["c1"] == 1
    @test qp.varindices["c2"] == 2
end