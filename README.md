# QPSReader

A package to read linear optimization problems in MPS format and quadratic optimization problems in QPS format.

 **Linux and macOS** | **Windows** | **FreeBSD** |
|:----------------:|:------------:|:-----------------:|
[![Build Status](https://travis-ci.org/JuliaSmoothOptimizers/QPSReader.jl.svg?branch=master)](https://travis-ci.org/JuliaSmoothOptimizers/QPSReader.jl) | [![Build status](https://ci.appveyor.com/api/projects/status/mntnshay4xud7t8t?svg=true)](https://ci.appveyor.com/project/dpo/qpsreader-jl) | [![Build Status](https://api.cirrus-ci.com/github/JuliaSmoothOptimizers/QPSReader.jl.svg)](https://cirrus-ci.com/github/JuliaSmoothOptimizers/QPSReader.jl) |


[![Coverage Status](https://coveralls.io/repos/JuliaSmoothOptimizers/QPSReader.jl/badge.svg?branch=master)](https://coveralls.io/r/JuliaSmoothOptimizers/QPSReader.jl?branch=master) | [![codecov.io](https://codecov.io/github/JuliaSmoothOptimizers/QPSReader.jl/coverage.svg?branch=master)](https://codecov.io/github/JuliaSmoothOptimizers/QPSReader.jl?branch=master)
|:--:|:--:|

The problems represented by the QPS format have the form

<p align="center">
optimize &nbsp; c₀ + cᵀ x + ½ xᵀ Q x
&nbsp;&nbsp;
subject to &nbsp; L ≤ Ax ≤ U and ℓ ≤ x ≤ u,
</p>

where:
* "optimize" means either "minimize" or "maximize"
* `c₀` ∈ ℝ is a constant term, `c` ∈ ℝⁿ is the linear term, `Q = Qᵀ` is the *n×n* positive semi-definite quadratic term,
* `A` is the *m×n* constraint matrix, `L`, `U` are constraint lower and upper bounds, respectively
* `ℓ`, `u` are variable lower and upper bounds, respectively

Only continuous problems are supported at this time.
Integer and semi-continuous markers will be ignored.

## Quick start

### Installation
```julia
julia> ]
pkg> add QPSReader
```

### Reading a file

This package exports the `QPSData` data type and the `readqps()` function.
Because MPS is a subset of QPS, the `readqps()` function accepts both formats.
Because the SIF is a superset of QPS, QPS problems implemented as SIF files (such as those from the Maros-Meszaros collection) are also supported.

Both Fixed and Free format are supported (see below for format conventions).
To read a problem from a file:
```julia
julia> qps = readqps("Q25FV47.QPS")  # Free MPS is used by default
julia> qps = readqps("Q25FV47.QPS", mpsformat=:fixed)  # uses Fixed MPS format
julia> qps = readqps("Q25FV47.QPS", mpsformat=:free)   # uses Free MPS format
```

By default, a number of messages may be logged while reading.
Log output can be suppressed as follows:
```julia
using QPSReader
using Logging

qps = with_logger(Logging.NullLogger()) do
    readqps("Q25FV47.QPS")
end
```

## Problem representation

The `QPSData` data type is defined as follows:

```julia
mutable struct QPSData
    nvar::Int                        # number of variables
    ncon::Int                        # number of constraints
    objsense::Symbol                 # :min, :max or :notset
    c0::Float64                      # constant term in objective
    c::Vector{Float64}               # linear term in objective

    # Quadratic objective, in COO format
    qrows::Vector{Int}
    qcols::Vector{Int}
    qvals::Vector{Float64}

    # Constraint matrix, in COO format
    arows::Vector{Int}
    acols::Vector{Int}
    avals::Vector{Float64}
    
    lcon::Vector{Float64}            # constraints lower bounds
    ucon::Vector{Float64}            # constraints upper bounds
    lvar::Vector{Float64}            # variables lower bounds
    uvar::Vector{Float64}            # variables upper bounds
    name::Union{Nothing, String}     # problem name
    objname::Union{Nothing, String}  # objective function name
    rhsname::Union{Nothing, String}  # Name of RHS field
    bndname::Union{Nothing, String}  # Name of BOUNDS field
    rngname::Union{Nothing, String}  # Name of RANGES field
    varnames::Vector{String}         # variable names, aka column names
    connames::Vector{String}         # constraint names, aka row names

    # name => index mapping for variables
    # Variables are indexed from 1 and onwards
    varindices::Dict{String, Int}

    # name => index mapping for constraints
    # Constraints are indexed from 1 and onwards
    # Recorded objective function has index 0
    # Rim objective rows have index -1
    conindices::Dict{String, Int}

    # Indicates the sense of each row:
    #   0  <--> E
    #  -1  <--> L
    #   1  <--> G
    #   2  <--> N
    contypes::Vector{Int}
end
```
Rows and variables are indexed in the order in which they are read.
The matrix Q is zero when reading an MPS file.

## Conventions

The supported file format are described here:
* [MPS file format](http://lpsolve.sourceforge.net/5.5/mps-format.htm)
* [QPS extension](https://doi.org/10.1080/10556789908805768)

The following conventions are enforced:

* Multiple objective rows
    * The first `N`-type row encountered in the `ROWS` section is recorded as the objective function, and its name is stored in `objname`.
    * If an additional `N`-type row is present, a `warning`-level log is displayed. Subsequent `N`-type rows are ignored.
    * Each time a rim objective row is encountered in the `COLUMNS` or `RHS` section, the corresponding coefficients are skipped, and an `error`-level log is displayed.

* Multiple RHS / Range / Bound fields
    * The second field of the first card in the `RHS` section determines the name of the right-hand side, which is stored in `rhsname`. Same goes for the `RANGES` and `BOUNDS` sections, with the corresponding names being stored in `rngname` and `bndname`, respectively.
    * Any card whose second field does not match the expected name is then ignored.
    A `warning`-level log is displayed at the first such occurence.
    * In addition, any line or individual coefficient that is ignored triggers an `error`-level log.

* A row (resp. column) name that was not declared in the `ROWS` (resp. `COLUMNS`) section, appears elsewhere in the file.
The only case where an error is not thrown is if said un-declared row or column appears in a rim line that is skipped.
* An `N`-type row appears in the `RANGES` section


## Problem Collections


* The Netlib LPs: [original Netlib site](http://www.netlib.org/lp) | [in SIF format](http://www.numerical.rl.ac.uk/cute/netlib.html) | [as tar files](http://users.clas.ufl.edu/hager/coap/format.html) (incl. preprocessed versions)
* the Kennington LPs: [original Netlib site](http://www.netlib.org/lp/data/kennington)
* infeasible Netlib LPs: [original Netlib site](http://www.netlib.org/lp/infeas)
* the Maros-Meszaros QPs: [in QPS format](http://www.doc.ic.ac.uk/~im/#DATA) | [in SIF format](https://bitbucket.org/optrove/maros-meszaros/wiki/Home)

Both the Netlib LP and Maros-Meszaros QP collections are provided as Julia artifacts (requires Julia 1.3).
This package exports the `fetch_netlib` and `fetch_mm` functions that return the path to the Netlib and Maros-Meszaros collections, repectively
```julia
using QPSReader

netlib_path = fetch_netlib()
mm_path = fetch_mm()
```