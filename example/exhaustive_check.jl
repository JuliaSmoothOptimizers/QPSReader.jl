# this exhaustive correctness check requires QuadraticModels and CUTEst

include("readqps.jl")
include("qpmodel.jl")

using CUTEst

using Printf
using Test

const mpsdir = "/Users/dpo/local/problems/netlib-lp/MPS"
const lpsifdir = "/Users/dpo/local/problems/netlib-lp/sif"

const qpsdir = "/Users/dpo/local/problems/QPDATA"
const qpsifdir = "/usr/local/opt/maros_meszaros/share/maros_meszaros"

const atol = 1.0e-8
const rtol = 1.0e-6

# skip the following problems for now, whose range constraints are transformed
# in a way seemingly inconsistent with the others
const toskip = ["BOEING1", "BOEING2", "NESM"]

function download_data_files()
    # download("http://clas.ufl.edu/users/hager/LPTest/MPS/MPS.tar.gz")
    download("ftp://ftp.numerical.rl.ac.uk/pub/cuter/netlib.tar.gz")
    download("https://bitbucket.org/optrove/maros-meszaros/get/9adfb5707b1e.zip")
end

function compare_with_cutest(qpmodel::QuadraticModel, model::CUTEstModel)
    x = ones(model.meta.nvar)
    x[1:2:end] .= -1.0
    f = obj(model, x)
    @test abs(f - obj(qpmodel, x)) ≤ atol + rtol * abs(f)

    g = grad(model, x)
    @test norm(g - grad(qpmodel, x)) ≤ atol + rtol * norm(g)

    H = hess(model, x)
    @test norm(H - hess(qpmodel, x)) ≤ atol + rtol * norm(H)

    J = jac(model, x)
    @test norm(J - jac(qpmodel, x)) ≤ atol + rtol * norm(J)

    # CUTEst rearranges constraint lower and upper bounds
    c_cutest = cons(model, x)
    c_qps = cons(qpmodel, x)

    # l ≤ Ax is transformed to 0 ≤ Ax - l
    c_qps[qpmodel.meta.jlow] -= qpmodel.meta.lcon[qpmodel.meta.jlow]

    # Ax ≤ u is transformed to Ax ≤ 0
    c_qps[qpmodel.meta.jupp] -= qpmodel.meta.ucon[qpmodel.meta.jupp]

    # Ax = b is transformed to Ax - b = 0
    c_qps[qpmodel.meta.jfix] -= qpmodel.meta.lcon[qpmodel.meta.jfix]

    # l ≤ Ax ≤ u is transformed to 0 ≤ Ax - l ≤ u - l
    c_qps[qpmodel.meta.jrng] -= qpmodel.meta.lcon[qpmodel.meta.jrng]

    @test norm(c_cutest - c_qps) ≤ atol + rtol * norm(c_cutest)

    finalize(model)
end

function scan_qps(qpsfolder, qpsiffolder)
    # check that we read all original QPS files
    problems = readdir(qpsfolder)
    @printf("%12s  %6s  %6s  %7s  %7s\n", "name", "nvar", "ncon", "nnzA", "nnzQ")
    for problem in problems
        qp = readqps(joinpath(qpsfolder, problem))
        @printf("%12s  %6d  %6d  %7d  %7d\n",
                qp.name, qp.nvar, qp.ncon, nnz(qp.A), nnz(qp.Q))

        # check that we can also read a SIF file
        # SIF files are the same as the QPS files but have blank lines and comments
        filename = split(basename(problem), ".")[1]
        siffile = joinpath(qpsiffolder, "$(filename).SIF")
        if uppercase(filename) in toskip
            @warn "skipping $filename"
            continue
        end
        if isfile(siffile)
            qpsif = readqps(joinpath(qpsiffolder, "$(filename).SIF"))
            @test qp.nvar == qpsif.nvar
            @test qp.ncon == qpsif.ncon
            @test qp.c0 == qpsif.c0
            @test all(qp.c .== qpsif.c)
            # @test all(qp.Q .== qpsif.Q)
            # @test all(qp.A .== qpsif.A)
            @test all(qp.lvar .== qpsif.lvar)
            @test all(qp.uvar .== qpsif.uvar)
            @test all(qp.lcon .== qpsif.lcon)
            @test all(qp.ucon .== qpsif.ucon)
            # @test qp.name == qpsif.name  # sometimes, the name differs
            @test all(qp.varnames .== qpsif.varnames)
            @test all(qp.connames .== qpsif.connames)

            # test that a QuadraticModel based on a QPS file matches the CUTEstModel
            qpmodel = QuadraticModel(qp)
            model = CUTEstModel(siffile, efirst=false, lfirst=false, lvfirst=false)
            compare_with_cutest(qpmodel, model)
        else
            @warn "$siffile not found"
        end
    end
end

scan_qps(qpsdir, qpsifdir)
scan_qps(mpsdir, lpsifdir)
