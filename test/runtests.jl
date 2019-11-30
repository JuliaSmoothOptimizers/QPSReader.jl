using Test

using QPSReader

# this is the example on pages 3-5 of
# I. Maros and C. Meszaros, "A Repository of Convex Quadratic Programming Problems",
# Technical Report DOC 97/6, Department of Computing, Imperial College, London, UK, 1997
# http://www.doc.ic.ac.uk/rr2000/DTR97-6.pdf
qp = readqps("qp-example.qps")
@test qp.nvar == 2
@test qp.ncon == 2
@test qp.c0 == 4.0
@test all(qp.c .== [1.5, -2.0])
@test all(Matrix(qp.Q) .== [8.0 0.0 ; 2.0 10.0])
@test all(Matrix(qp.A) .== [2.0 1.0 ; -1.0 2.0])
@test all(qp.lcon .== [2.0, -Inf])
@test all(qp.ucon .== [Inf, 6.0])
@test all(qp.lvar .== [0.0, 0.0])
@test all(qp.uvar .== [20.0, Inf])
