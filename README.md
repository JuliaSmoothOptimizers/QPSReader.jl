# QPSReader

A package to read linear optimization problems in MPS format and quadratic optimization problems in QPS format.

[![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.3996203-blue.svg)](https://doi.org/10.5281/zenodo.3996203)
![CI](https://github.com/JuliaSmoothOptimizers/QPSReader.jl/workflows/CI/badge.svg?branch=main)
[![Build Status](https://api.cirrus-ci.com/github/JuliaSmoothOptimizers/QPSReader.jl.svg)](https://cirrus-ci.com/github/JuliaSmoothOptimizers/QPSReader.jl)
[![codecov.io](https://codecov.io/github/JuliaSmoothOptimizers/QPSReader.jl/coverage.svg?branch=main)](https://codecov.io/github/JuliaSmoothOptimizers/QPSReader.jl?branch=main)
[![Documentation/stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaSmoothOptimizers.github.io/QPSReader.jl/stable)
[![Documentation/dev](https://img.shields.io/badge/docs-latest-blue.svg)](https://JuliaSmoothOptimizers.github.io/QPSReader.jl/dev)

## How to Cite

If you use QPSReader.jl in your work, please cite using the format given in [CITATION.bib](https://github.com/JuliaSmoothOptimizers/QPSReader.jl/blob/main/CITATION.bib).

The problems represented by the `.QPS`/`.mps` format have the form

<p align="center">
optimize &nbsp; c₀ + cᵀ x + ½ xᵀ Q₀ x
&nbsp;&nbsp;
subject to &nbsp; Lᵢ ≤ aᵢᵀ x + xᵀ Qᵢ x ≤ Uᵢ &nbsp; and &nbsp; ℓ ≤ x ≤ u,
</p>

where:
* "optimize" means either "minimize" or "maximize"
* `c₀` ∈ ℝ is a constant term, `c` ∈ ℝⁿ is the linear term, `Q₀ = Q₀ᵀ` is the *n×n* objective quadratic term,
* `aᵢ` is the *i*-th row of the constraint matrix, `Qᵢ = Qᵢᵀ` is the *n×n* quadratic term for constraint *i*,
* `L`, `U` ∈ ℝᵐ are constraint lower and upper bounds, respectively
* `ℓ`, `u` ∈ ℝⁿ are variable lower and upper bounds, respectively

Mixed-integer problems are supported, but semi-continuous and semi-integer variables are not.

Mixed-integer problems are supported, but semi-continuous and semi-integer variables are not.

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

Both fixed and free format are supported (see below for format conventions).
To read a problem from a file:
```julia
julia> qps = readqps("Q25FV47.QPS")  # Free MPS is used by default
julia> qps = readqps("Q25FV47.QPS", mpsformat=:fixed)  # uses fixed MPS format
julia> qps = readqps("Q25FV47.QPS", mpsformat=:free)   # uses free MPS format
```

`readqps` also accepts an `IO` object as the first argument.

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

    # Quadratic Constraints Data
    qcdata::Dict{Int, Tuple{Vector{Int}, Vector{Int}, Vector{Float64}}}

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

    # Variable types
    #  `VTYPE_Continuous`      <--> continuous
    #  `VTYPE_Integer`         <--> integer
    #  `VTYPE_Binary`          <--> binary
    #  `VTYPE_SemiContinuous`  <--> semi-continuous (not supported)
    #  `VTYPE_SemiInteger`     <--> semi-integer (not supported)
    vartypes::Vector{VariableType}

    # Indicates the sense of each row:
    # `RTYPE_Objective`    <--> objective row (`'N'`)
    # `RTYPE_EqualTo`      <--> equality constraint (`'E'`)
    # `RTYPE_LessThan`     <--> less-than constraint (`'L'`)
    # `RTYPE_GreaterThan`  <--> greater-than constraint (`'G'`)
    contypes::Vector{RowType}
end
```
Rows and variables are indexed in the order in which they are read.
The matrix Q is zero when reading an MPS file.

## Conventions

The file formats supported by `QPSReader` are described here:
* [MPS file format](http://lpsolve.sourceforge.net/5.5/mps-format.htm)
* [QPS extension](https://doi.org/10.1080/10556789908805768)

The following conventions are enforced:

### Rim data

* Multiple objective rows
    * The first `N`-type row encountered in the `ROWS` section is recorded as the objective function, and its name is stored in `objname`.
    * If an additional `N`-type row is present, a `warning`-level log is displayed. Subsequent `N`-type rows are ignored.
    * Each time a rim objective row is encountered in the `COLUMNS` or `RHS` section, the corresponding coefficients are skipped, and an `error`-level log is displayed.

* Multiple RHS / Range / Bound fields
    * The second field of the first card in the `RHS` section determines the name of the right-hand side, which is stored in `rhsname`. Same goes for the `RANGES` and `BOUNDS` sections, with the corresponding names being stored in `rngname` and `bndname`, respectively.
    * Any card whose second field does not match the expected name is then ignored.
    A `warning`-level log is displayed at the first such occurence.
    * In addition, any line or individual coefficient that is ignored triggers an `error`-level log.

### Variable bounds

* Default bounds for variables are `[0, Inf)`, to exception of integer variables (see below).
* If multiple bounds are specified for a given variable, only the most recent bound is recorded.

### Integer variables

There are two ways of declaring integer variables:

* Through markers in the `COLUMNS` section.
* By specifying `BV`, `LI` or `UI` bounds in the `BOUNDS` section
* The convention for integer variable bounds in as follows:
    | Marker? | `BOUNDS` fields | Type | Bounds reported |
    |:--:|:--:|:--:|:--:|
    | Yes | - | Integer | `[0, 1]`
    | Yes | `BV` | Binary | `[0, 1]`
    | Yes | (`LI`, `l`) | Integer | `[l, Inf]`
    | Yes | (`UI`, `u`) with `u≥0` | Integer | `[0, u]`
    | Yes | (`UI`, `u`) with `u<0` | Integer | `[-Inf, u]`
    | Yes | (`LI`, `l`) + (`UI`, `u`) | Integer | `[l, u]`
    | No | `BV` | Binary | `[0, 1]`
    | No | (`LI`, `l`) | Integer | `[l, Inf]`
    | No | (`UI`, `u`) with `u≥0` | Integer | `[0, u]`
    | No | (`UI`, `u`) with `u<0` | Integer | `[-Inf, u]`
    | No | (`LI`, `l`) + (`UI`, `u`) | Integer | `[l, u]`

    The `LI`/`UI` can be replaced by `LO`/`UP` in the table above, with no impact on bounds. Only the integrality of variables are affected.
    For continuous variables, follow the second half of the table, and replace `LI`/`UI` by `LO`/`UP`.

### Errors

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
