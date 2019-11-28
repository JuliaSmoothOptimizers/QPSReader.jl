# QPSReader

Linux and macOS: [![Build Status](https://travis-ci.org/JuliaSmoothOptimizers/QPSReader.jl.svg?branch=master)](https://travis-ci.org/JuliaSmoothOptimizers/QPSReader.jl)
Windows: [![Build status](https://ci.appveyor.com/api/projects/status/mntnshay4xud7t8t?svg=true)](https://ci.appveyor.com/project/dpo/qpsreader-jl)
FreeBSD: [![Build Status](https://api.cirrus-ci.com/github/JuliaSmoothOptimizers/QPSReader.jl.svg)](https://cirrus-ci.com/github/JuliaSmoothOptimizers/QPSReader.jl)
[![Coverage Status](https://coveralls.io/repos/JuliaSmoothOptimizers/QPSReader.jl/badge.svg?branch=master)](https://coveralls.io/r/JuliaSmoothOptimizers/QPSReader.jl?branch=master)
[![codecov.io](http://codecov.io/github/JuliaSmoothOptimizers/QPSReader.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaSmoothOptimizers/QPSReader.jl?branch=master)

A package to read linear optimization problems in fixed MPS format and quadratic optimization problems in QPS format.

The problems represented by the QPS format have the form

<p align="center">
optimize &nbsp; c₀ + cᵀ x + ½ xᵀ Q x
&nbsp;&nbsp;
subject to &nbsp; L ≤ Ax ≤ U and ℓ ≤ x ≤ u,
</p>

where "optimize" means either "minimize" or "maximize", c₀ ∈ ℝ is a constant term, c ∈ ℝⁿ is the linear term, Q = Qᵀ is the *n×n* positive semi-definite quadratic term, L is the vector of lower constraint bounds, A is the constraint matrix, U is the vector of upper constraint bounds, ℓ is the vector of lower bounds, and u is the vector of upper bounds.

Only continuous problems are supported at this time.
Problems with binary, integer or semi-continuous variables are not supported.

This package exports the `QPSData` data type and the `readqps()` function.
Because MPS is a subset of QPS, the `readqps()` function accepts both formats.
Because the SIF is a superset of QPS, QPS problems implemented as SIF files (such as those from the Maros-Meszaros collection) are also supported.

### Usage

```julia
julia> qp = readqps("Q25FV47.QPS")
```

The `QPSData` data type is defined as follows:

```julia
mutable struct QPSData
    nvar::Int                        # number of variables
    ncon::Int                        # number of constraints
    objsense::Symbol                 # :min, :max or :notset
    c0::Float64                      # constant term in objective
    c::Vector{Float64}               # linear term in objective
    Q::SparseMatrixCSC{Float64,Int}  # quadratic term in objective
    A::SparseMatrixCSC{Float64,Int}  # constraint matrix
    lcon::Vector{Float64}            # constraints lower bounds
    ucon::Vector{Float64}            # constraints upper bounds
    lvar::Vector{Float64}            # variables lower bounds
    uvar::Vector{Float64}            # variables upper bounds
    name::String                     # problem name
    objname::String                  # objective function name
    varnames::Vector{String}         # variable names, aka column names
    connames::Vector{String}         # constraint names, aka row names
end
```

The matrix Q is zero when reading an MPS file.

### Problem Collections

* The Netlib LPs: [original Netlib site](http://www.netlib.org/lp) | [in SIF format](http://www.numerical.rl.ac.uk/cute/netlib.html) | [as tar files](http://users.clas.ufl.edu/hager/coap/format.html) (incl. preprocessed versions)
* the Kennington LPs: [original Netlib site](http://www.netlib.org/lp/data/kennington)
* infeasible Netlib LPs: [original Netlib site](http://www.netlib.org/lp/infeas)
* the Maros-Meszaros QPs: [in QPS format](http://www.doc.ic.ac.uk/~im/#DATA) | [in SIF format](https://bitbucket.org/optrove/maros-meszaros/wiki/Home)

### References

* the MPS file format is described at http://lpsolve.sourceforge.net/5.5/mps-format.htm
* the QPS extension is described in https://doi.org/10.1080/10556789908805768
