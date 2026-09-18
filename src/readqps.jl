# http://lpsolve.sourceforge.net/5.5/mps-format.htm
# https://doi.org/10.1080/10556789908805768

"""
    RowType

An Enum of possible row types.

* `RTYPE_Objective`: objective row (`'N'`)
* `RTYPE_EqualTo`: equality constraint (`'E'`)
* `RTYPE_LessThan`: less-than constraint (`'L'`)
* `RTYPE_GreaterThan`: greter-than constraint (`'G'`)
"""
@enum RowType begin
  RTYPE_Objective
  RTYPE_EqualTo
  RTYPE_LessThan
  RTYPE_GreaterThan
end

function row_type(rtype::String)
  if rtype == "E"
    return RTYPE_EqualTo
  elseif rtype == "L"
    return RTYPE_LessThan
  elseif rtype == "G"
    return RTYPE_GreaterThan
  elseif rtype == "N"
    return RTYPE_Objective
  else
    error("Unknown row type $rtype")
  end
end

"""
    VariableType

An Enum of possible variable types.

* `VTYPE_Marked`: marked integer (for internal use)
* `VTYPE_Continuous`: continuous variable
* `VTYPE_Binary`: binary variable
* `VTYPE_Integer`: integer variable
* `VTYPE_SemiContinuous`: semi-continuous variable
* `VTYPE_SemiInteger`: semi-integer variable
"""
@enum VariableType begin
  VTYPE_Marked
  VTYPE_Continuous
  VTYPE_Binary
  VTYPE_Integer
  VTYPE_SemiContinuous
  VTYPE_SemiInteger
end

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
  vartypes::Vector{VariableType}
  # Constraint types (senses)
  contypes::Vector{RowType}

  # Constructor
  QPSData() = new(
    0,
    0,
    :notset,
    0.0,
    Float64[],
    Int[],
    Int[],
    Float64[],
    Int[],
    Int[],
    Float64[],
    Dict{Int, Tuple{Vector{Int}, Vector{Int}, Vector{Float64}}}(), 
    Float64[],
    Float64[],
    Float64[],
    Float64[],
    nothing,
    nothing,
    nothing,
    nothing,
    nothing,
    String[],
    String[],
    Dict{String, Int}(),
    Dict{String, Int}(),
    VariableType[],
    RowType[],
  )
end

abstract type MPSFormat end
struct FixedMPS <: MPSFormat end
struct FreeMPS <: MPSFormat end

"""
    MPSCard{Format}

Data structure for parsing a single line of an MPS file.
"""
mutable struct MPSCard{Format <: MPSFormat}
  nline::Int       # Line number
  iscomment::Bool  # Is this line a comment/empty line?
  isheader::Bool   # Is this line a section header?

  nfields::Int  # Number of fields that were read

  # MPS fields
  f1::String
  f2::String
  f3::String
  f4::String
  f5::String
  f6::String
end

# Section headers
# Additional sections may be added
# By convention, all sections should correspond to non-negative integers
const ENDATA = 0
const NAME = 1
const OBJSENSE = 2
const ROWS = 3
const COLUMNS = 4
const RHS = 5
const BOUNDS = 6
const RANGES = 7
const QUADOBJ = 8
const OBJECT_BOUND = 10
const QCMATRIX = 11  

const SECTION_HEADERS = Dict{String, Int}(
  "ENDATA" => ENDATA,
  "NAME" => NAME,
  "OBJSENSE" => OBJSENSE,  # Free MPS only
  "ROWS" => ROWS,
  "COLUMNS" => COLUMNS,
  "RHS" => RHS,
  "BOUNDS" => BOUNDS,
  "RANGES" => RANGES,
  "QUADOBJ" => QUADOBJ,
  "QMATRIX" => QUADOBJ,
  "OBJECT BOUND" => OBJECT_BOUND,  # SIF only
  "QCMATRIX" => QCMATRIX,  # QPS only
)

"""
    section_header(s::String)

Return the section corresponding to `s`.

Throws an error if `s` is not a recognized section header.
"""
function section_header(s::String)
  sec = get(SECTION_HEADERS, s, -1)
  (sec >= 0) || error("Un-recognized section header: $s")

  return sec
end

"""
    read_card!(card::MPSCard{FixedMPS}, ln::String)

Read the fields in `ln` into `card`.
"""
function read_card!(card::MPSCard{FixedMPS}, ln::String)
  l = length(ln)
  if l == 0 || ln[1] == '*' || ln[1] == '&'
    # This line is an empty line, or it is a comment
    card.iscomment = true
    card.isheader = false
    card.nfields = 0

    return card
  end

  if !isspace(ln[1])
    # This line is a section header
    card.iscomment = false
    card.isheader = true
    card.nfields = 1

    # This only works for fixed MPS; free format is not supported yet
    s = split(ln)
    card.f1 = String(s[1])
    # Read name, if applicable
    if card.f1 == "NAME"
      card.f2 = String(strip(ln[15:end]))
      card.nfields = 2
    elseif card.f1 == "OBJECT"
      # Check that this is a "OBJECT BOUND" line
      if s[2] == "BOUND"
        card.f1 = "OBJECT BOUND"
      else
        error("Unrecognized section header: $ln")
      end
    elseif card.f1 == "QCMATRIX"
        # QCMATRIX requires a row name as the second argument
        if length(s) >= 2
            card.f2 = String(s[2])
            card.nfields = 2
        end
    end
    return card
  end

  # Regular card
  card.iscomment = false
  card.isheader = false

  # Read fields
  # First field
  if l >= 3
    card.f1 = strip(String(ln[2:3]))
    card.nfields = 1
  else
    error("Short line\n$ln")
  end

  # Second field
  if 5 <= l <= 12
    card.f2 = strip(String(ln[5:end]))
    card.nfields = 2
  elseif l >= 13
    card.f2 = strip(String(ln[5:12]))
    card.nfields = 2
  end

  # Third field
  if 15 <= l <= 22
    card.f3 = strip(String(ln[15:end]))
    card.nfields = 3
  elseif l >= 23
    card.f3 = strip(String(ln[15:22]))
    card.nfields = 3
  end

  # Fourth field
  if 25 <= l <= 36
    card.f4 = strip(String(ln[25:end]))
    card.nfields = 4
  elseif l >= 37
    card.f4 = strip(String(ln[25:36]))
    card.nfields = 4
  end

  # Fifth field
  if 40 <= l <= 47
    card.f5 = strip(String(ln[40:end]))
    card.nfields = 5
  elseif l >= 48
    card.f5 = strip(String(ln[40:47]))
    card.nfields = 5
  end

  # Sixth field
  if 50 <= l <= 61
    card.f6 = strip(String(ln[50:end]))
    card.nfields = 6
  elseif l >= 62
    card.f6 = strip(String(ln[50:61]))
    card.nfields = 6
  end

  # If first field was empty, shift all fields to the left
  if length(card.f1) == 0
    card.f1 = card.f2
    card.f2 = card.f3
    card.f3 = card.f4
    card.f4 = card.f5
    card.f5 = card.f6
    card.nfields -= 1
  end

  return card
end

"""
    read_card!(card::MPSCard{FreeMPS}, ln::String)

Read the fields in `ln` into `card`.
"""
function read_card!(card::MPSCard{FreeMPS}, ln::String)
  l = length(ln)
  if l == 0 || ln[1] == '*' || ln[1] == '&'
    # This line is an empty line, or it is a comment
    card.iscomment = true
    card.isheader = false
    card.nfields = 0

  elseif !isspace(ln[1])
    # This line is a section header
    card.iscomment = false
    card.isheader = true
    card.nfields = 1

    # Read section header
    s = split(ln)
    card.f1 = String(s[1])
    # Read name, if applicable
    if card.f1 == "NAME"
      card.f2 = length(s) >= 2 ? s[2] : ""
      card.nfields = 2
    elseif card.f1 == "OBJECT"
      if s[2] == "BOUND"
        # OBJECT BOUND line
        card.f1 = "OBJECT BOUND"
      else
        error("Unrecognized section header: $ln")
      end
    elseif card.f1 == "QCMATRIX"
        # QCMATRIX requires a row name as the second argument
        if length(s) >= 2
            card.f2 = String(s[2])
            card.nfields = 2
        end
    end

  else
    # Regular card
    card.iscomment = false
    card.isheader = false

    # Read fields
    s = split(ln)
    l = length(s)  # Total number of fields
    if l == 0
      # Empty line
      card.iscomment = true
      card.isheader = false
      card.nfields = 0
      return card
    end

    l <= 6 || error("Too many fields in line.\n$ln")
    card.nfields = l

    if l >= 1
      card.f1 = s[1]
    end

    if l >= 2
      card.f2 = s[2]
    end

    if l >= 3
      card.f3 = s[3]
    end

    if l >= 4
      card.f4 = s[4]
    end

    if l >= 5
      card.f5 = s[5]
    end

    if l >= 6
      card.f6 = s[6]
    end
  end

  return card
end

function read_objsense_line!(qps::QPSData, card::MPSCard)
  if card.f1 == "MIN"
    qps.objsense = :min
  elseif card.f1 == "MAX"
    qps.objsense = :max
  else
    error("Unrecognized objective sense: $(card.f1)")
  end
  return nothing
end

"""
    read_rows_line
"""
function read_rows_line!(qps::QPSData, card::MPSCard)
  # Sanity check
  card.nfields >= 2 || error("Line $(card.nline) contains only $(card.nfields) fields")

  rtype = row_type(card.f1)
  rowname = card.f2

  if rtype == RTYPE_Objective
    # Objective row
    if qps.objname === nothing
      # Record objective
      qps.objname = rowname
      qps.conindices[rowname] = 0
      @info "Using '$rowname' as objective (l. $(card.nline))"
    else
      # Record name but ignore input
      @warn "Detected rim objective row $rowname at line $(card.nline)"
      qps.conindices[rowname] = -1
    end

    return nothing
  end

  # Regular row
  ncon = qps.ncon + 1
  ridx = get!(qps.conindices, rowname, ncon)
  ridx == ncon || error("Duplicate row name $rowname at line $(card.nline)")
  qps.ncon += 1

  # Record row sense
  push!(qps.contypes, rtype)
  push!(qps.connames, rowname)

  # Populate default values for right-hand sides
  # TODO: it would be more efficient to allocate memory only once
  if rtype == RTYPE_EqualTo
    push!(qps.lcon, 0.0)
    push!(qps.ucon, 0.0)
  elseif rtype == RTYPE_GreaterThan
    push!(qps.lcon, 0.0)
    push!(qps.ucon, Inf)
  elseif rtype == RTYPE_LessThan
    push!(qps.lcon, -Inf)
    push!(qps.ucon, 0.0)
  end

  return nothing
end

function read_columns_line!(qps::QPSData, card::MPSCard; integer_section::Bool = false)
  # Sanity check
  card.nfields >= 3 || error("Line $(card.nline) contains only $(card.nfields) fields")

  varname = card.f1
  nvar = qps.nvar + 1
  # Get column index
  col = get!(qps.varindices, varname, nvar)
  if col == nvar
    # new variable
    qps.nvar += 1
    push!(qps.varnames, varname)
    push!(qps.c, 0.0)

    # Record variable type
    push!(qps.vartypes, (integer_section ? VTYPE_Marked : VTYPE_Continuous))

    # Populate default variable bounds
    push!(qps.lvar, NaN)
    push!(qps.uvar, NaN)
  end

  fun = card.f2
  val = parse(Float64, card.f3)

  row = get(qps.conindices, fun, -2)
  if row == 0
    # Objective
    qps.c[col] = val
  elseif row == -1
    # Rim objective, ignore this input
    @error "Ignoring coefficient ($fun, $varname) with value $val at line $(card.nline)"
  elseif row > 0
    # Record coefficient
    push!(qps.arows, row)
    push!(qps.acols, col)
    push!(qps.avals, val)
  else
    # This row was not declared
    error("Unknown row $fun at line $(card.nline)")
  end

  card.nfields >= 5 || return nothing

  # Read second par of the fields
  fun = card.f4
  val = parse(Float64, card.f5)

  row = get(qps.conindices, fun, -2)
  if row == 0
    # Objective
    qps.c[col] = val
  elseif row == -1
    # Rim objective, ignore this input
    @error "Ignoring coefficient ($fun, $varname) with value $val at line $(card.nline)"
  elseif row > 0
    # Record coefficient
    push!(qps.arows, row)
    push!(qps.acols, col)
    push!(qps.avals, val)
  else
    # This row was not declared
    error("Unknown row $fun at line $(card.nline)")
  end

  return nothing
end

function read_rhs_line!(qps::QPSData, card::MPSCard)
  # Sanity check
  card.nfields >= 3 || error("Line $(card.nline) contains only $(card.nfields) fields")

  rhs = card.f1
  if qps.rhsname === nothing
    # Record this as the RHS
    qps.rhsname = rhs
    @info "Using '$rhs' as RHS (l. $(card.nline))"
  elseif qps.rhsname != rhs
    # Rim RHS, ignore this line
    @error "Skipping line $(card.nline) with rim RHS $rhs"
    return nothing
  end

  fun = card.f2
  val = parse(Float64, card.f3)
  row = get(qps.conindices, fun, -2)
  if row == 0
    # Objective row
    qps.c0 = -val
  elseif row == -1
    # Rim objective, ignore this input
    @error "Ignoring RHS for rim objective $fun at line $(card.nline)"
  elseif row > 0
    rtype = qps.contypes[row]
    if rtype == RTYPE_EqualTo
      qps.lcon[row] = val
      qps.ucon[row] = val
    elseif rtype == RTYPE_LessThan
      qps.ucon[row] = val
    elseif rtype == RTYPE_GreaterThan
      qps.lcon[row] = val
    end
  else
    # This row was not declared
    error("Unknown row $fun.")
  end

  card.nfields >= 5 || return nothing

  fun = card.f4
  val = parse(Float64, card.f5)
  row = get(qps.conindices, fun, -2)
  if row == 0
    # Objective row
    qps.c0 = -val
  elseif row == -1
    # Rim objective, ignore this input
    @error "Ignoring RHS for rim objective $fun at line $(card.nline)"
  elseif row > 0
    rtype = qps.contypes[row]
    if rtype == RTYPE_EqualTo
      qps.lcon[row] = val
      qps.ucon[row] = val
    elseif rtype == RTYPE_LessThan
      qps.ucon[row] = val
    elseif rtype == RTYPE_GreaterThan
      qps.lcon[row] = val
    end
  else
    # This row was not declared
    error("Unknown row $fun")
  end

  return nothing
end

"""


```
row type       sign of r       h          u
----------------------------------------------
    G            + or -         b        b + |r|
    L            + or -       b - |r|      b
    E              +            b        b + |r|
    E              -          b - |r|      b
```
"""
function read_ranges_line!(qps::QPSData, card::MPSCard)
  # Sanity check
  card.nfields >= 3 || error("Line $(card.nline) contains only $(card.nfields) fields")

  rng = card.f1
  if qps.rngname === nothing
    # Record this as the RANGES
    qps.rngname = rng
    @info "Using '$rng' as RANGES (l. $(card.nline))"
  elseif qps.rngname != rng
    # Rim RANGES, ignore this line
    @error "Skipping line $(card.nline) with rim RANGES $rng"
    return nothing
  end

  rowname = card.f2
  val = parse(Float64, card.f3)
  row = get(qps.conindices, rowname, -2)
  if row == 0 || row == -1
    # Objective row
    error("Encountered objective row $rowname in RANGES section")
  elseif row > 0
    rtype = qps.contypes[row]
    if rtype == RTYPE_EqualTo
      if val >= 0.0
        qps.ucon[row] += val
      else
        qps.lcon[row] += val
      end
    elseif rtype == RTYPE_LessThan
      qps.lcon[row] = qps.ucon[row] - abs(val)
    elseif rtype == RTYPE_GreaterThan
      qps.ucon[row] = qps.lcon[row] + abs(val)
    end
  else
    # This row was not declared
    error("Unknown row $rowname.")
  end

  card.nfields >= 5 || return nothing

  rowname = card.f4
  val = parse(Float64, card.f5)
  row = get(qps.conindices, rowname, -2)
  if row == 0 || row == -1
    # Objective row
    error("Encountered objective row $rowname in RANGES section")
  elseif row > 0
    rtype = qps.contypes[row]
    if rtype == RTYPE_EqualTo
      if val >= 0.0
        qps.ucon[row] += val
      else
        qps.lcon[row] += val
      end
    elseif rtype == RTYPE_LessThan
      qps.lcon[row] = qps.ucon[row] - abs(val)
    elseif rtype == RTYPE_GreaterThan
      qps.ucon[row] = qps.lcon[row] + abs(val)
    end
  else
    # This row was not declared
    error("Unknown row $rowname.")
  end

  return nothing
end

function read_bounds_line!(qps::QPSData, card::MPSCard)
  # Sanity check
  card.nfields >= 3 || error("Line $(card.nline) contains only $(card.nfields) fields")

  bnd = card.f2
  if qps.bndname === nothing
    # Record this as the BOUNDS
    qps.bndname = bnd
    @info "Using '$bnd' as BOUNDS (l. $(card.nline))"
  elseif qps.bndname != bnd
    # Rim BOUNDS, ignore this line
    @error "Skipping line $(card.nline) with rim bound $bnd"
    return nothing
  end

  varname = card.f3
  col = get(qps.varindices, varname, 0)
  col > 0 || error("Unknown column $varname")

  btype = card.f1

  if btype == "FR"
    qps.lvar[col] = -Inf
    qps.uvar[col] = Inf
    return nothing
  elseif btype == "MI"
    qps.lvar[col] = -Inf
    return nothing
  elseif btype == "PL"
    qps.uvar[col] = Inf
    return nothing
  elseif btype == "BV"
    qps.vartypes[col] = VTYPE_Binary
    qps.lvar[col] = 0
    qps.uvar[col] = 1
    return nothing
  elseif btype == "SC"
    # TODO: warning?
    error("Semi-continuous variables are currently not supported")
    return nothing
  end

  card.nfields >= 4 || error("At least 4 fields are required for $btype bounds")
  val = parse(Float64, card.f4)

  if btype == "LO"
    qps.lvar[col] = val
  elseif btype == "UP"
    qps.uvar[col] = val
  elseif btype == "FX"
    qps.lvar[col] = val
    qps.uvar[col] = val
  elseif btype == "LI"
    # Integer variable
    qps.vartypes[col] = VTYPE_Integer
    qps.lvar[col] = val
  elseif btype == "UI"
    # Integer variable
    qps.vartypes[col] = VTYPE_Integer
    qps.uvar[col] = val
  end

  return nothing
end

function read_quadobj_line!(qps::QPSData, card::MPSCard)
  # Sanity check
  card.nfields >= 3 || error("Line $(card.nline) contains only $(card.nfields) fields")

  colname = card.f1
  rowname = card.f2
  val = parse(Float64, card.f3)

  col = get(qps.varindices, colname, 0)
  col > 0 || error("Unknown variable $colname")
  row = get(qps.varindices, rowname, 0)
  row > 0 || error("Unknown variable $rowname")

  push!(qps.qcols, col)
  push!(qps.qrows, row)
  push!(qps.qvals, val)

  return nothing
end

"""
    read_qcmatrix_line!

Reads a line from the QCMATRIX section.
"""
function read_qcmatrix_line!(qps::QPSData, card::MPSCard, row_idx::Int)
  # Sanity check
  card.nfields >= 3 || error("Line $(card.nline) contains only $(card.nfields) fields")

  colname = card.f1
  rowname = card.f2 # Note: In MPS matrix format, f2 is the second variable
  val = parse(Float64, card.f3)

  col = get(qps.varindices, colname, 0)
  col > 0 || error("Unknown variable $colname in QCMATRIX")
  row = get(qps.varindices, rowname, 0)
  row > 0 || error("Unknown variable $rowname in QCMATRIX")

  # Retrieve or initialize the storage vectors for this specific constraint
  # qcdata stores (row_indices, col_indices, values)
  (qr, qc, qv) = qps.qcdata[row_idx]
  
  push!(qr, row) # Variable index 1
  push!(qc, col) # Variable index 2
  push!(qv, val) # Value

  return nothing
end

function readqps(filename::String; mpsformat::Symbol = :free)
  open(filename, "r") do qps
    return readqps(qps; mpsformat = mpsformat)
  end
end

function readqps(qps::IO; mpsformat::Symbol = :free)
  name_section_read = false
  objsense_section_read = false
  rows_section_read = false
  columns_section_read = false
  rhs_section_read = false
  bounds_section_read = false
  ranges_section_read = false
  quadobj_section_read = false
  endata_read = false

  integer_section = false

  sec = -1

  if mpsformat == :fixed
    Tf = FixedMPS
  elseif mpsformat == :free
    Tf = FreeMPS
  else
    error("Unsupported format: $mpsformat")
  end

  card = MPSCard{Tf}(0, false, false, 0, "", "", "", "", "", "")

  qpsdat = QPSData()

  seekstart(qps)
  current_qc_row_idx = -1  # To track which constraint we are reading in QCMATRIX
  while !eof(qps)
    line = readline(qps)
    read_card!(card, line)

    card.nline += 1

    card.iscomment && continue
  
    if card.isheader
      sec = section_header(card.f1)
      if sec == NAME
        name_section_read && error("more than one NAME section specified")
        qpsdat.name = card.f2
        name_section_read = true
        @info "Using '$(qpsdat.name)' as NAME (l. $(card.nline))"
      elseif sec == OBJSENSE
        objsense_section_read && error("more than one OBJSENSE section specified")
        objsense_section_read = true
      elseif sec == ROWS
        rows_section_read && error("more than one ROWS section specified")
        rows_section_read = true
      elseif sec == COLUMNS
        columns_section_read && error("more than one COLUMNS section specified")
        rows_section_read || error("ROWS section must come before COLUMNS section")
        columns_section_read = true
      elseif sec == RHS
        rhs_section_read && error("more than one RHS section specified")
        rows_section_read || error("ROWS section must come before RHS section")
        columns_section_read || error("COLUMNS section must come before RHS section")
        ranges_section_read && error("RHS section must come before RANGES section")
        rhs_section_read = true
      elseif sec == BOUNDS
        bounds_section_read && error("more than one BOUNDS section specified")
        columns_section_read || error("COLUMNS section must come before BOUNDS section")
        bounds_section_read = true
      elseif sec == RANGES
        rows_section_read || error("ROWS section must come before RHS section")
        columns_section_read || error("COLUMNS section must come before RHS section")
        ranges_section_read && error("more than one RANGES section specified")
        ranges_section_read = true
      elseif sec == QUADOBJ
        quadobj_section_read && error("more than one QUADOBJ section specified")
        columns_section_read || error("COLUMNS section must come before QUADOBJ section")
        quadobj_section_read = true
      elseif sec == QCMATRIX
        # QCMATRIX section handling
        columns_section_read || error("COLUMNS section must come before QCMATRIX section")
        
        # Extract row name from card.f2
        rowname = card.f2
        if isempty(rowname)
             error("QCMATRIX section header missing constraint name at line $(card.nline)")
        end
        
        idx = get(qpsdat.conindices, rowname, -2)
        if idx <= 0
            error("Unknown constraint '$rowname' in QCMATRIX at line $(card.nline)")
        end
        
        current_qc_row_idx = idx
        
        # Initialize the storage tuple for this constraint if it doesn't exist
        if !haskey(qpsdat.qcdata, idx)
            qpsdat.qcdata[idx] = (Int[], Int[], Float64[])
        else 
            @warn "Duplicate QCMATRIX section for $rowname, appending data."
        end
        
      elseif sec == ENDATA
        endata_read && error("more than one ENDATA section specified")
        endata_read = true
        break
      elseif sec == OBJECT_BOUND
        # Do nothing
      end
      continue
    end

    # Line is not a comment/empty line, nor a section header
    if sec == OBJSENSE
      # Parse objective sense
      read_objsense_line!(qpsdat, card)
    elseif sec == ROWS
      read_rows_line!(qpsdat, card)
    elseif sec == COLUMNS
      # Check if card is marker
      if card.f2 == "'MARKER'"
        if card.f3 == "'INTORG'"
          integer_section = true
        elseif card.f3 == "'INTEND'"
          integer_section = false
        else
          @error "Ignoring marker $(card.f3) at line $(card.nline)"
        end
        continue
      end
      read_columns_line!(qpsdat, card; integer_section = integer_section)
    elseif sec == RHS
      read_rhs_line!(qpsdat, card)
    elseif sec == BOUNDS
      read_bounds_line!(qpsdat, card)
    elseif sec == RANGES
      read_ranges_line!(qpsdat, card)
    elseif sec == QUADOBJ
      read_quadobj_line!(qpsdat, card)
    elseif sec == QCMATRIX
      read_qcmatrix_line!(qpsdat, card, current_qc_row_idx)
    else
      error("Unexpected section $sec in line\n$line")
    end
  end

  endata_read || @error("reached end of file before ENDATA section")

  # Finalize variable bounds
  # All marked integer variables with no explicit bounds
  # are converted to Integer variables with bounds [0, 1]
  for (j, (vt, l, u)) in enumerate(zip(qpsdat.vartypes, qpsdat.lvar, qpsdat.uvar))
    if isnan(l) && isnan(u)
      # Set default bounds
      qpsdat.lvar[j] = 0.0
      qpsdat.uvar[j] = (vt == VTYPE_Marked) ? 1.0 : Inf
    elseif isnan(l) && !isnan(u)
      # Only an upper bound was specified
      # Set lower bound to zero, unless upper bound is negative
      if u < 0
        qpsdat.lvar[j] = -Inf
      else
        qpsdat.lvar[j] = 0.0
      end
    elseif !isnan(l) && isnan(u)
      # Only a lower bound was specified
      # Set default upper bound
      qpsdat.uvar[j] = Inf
    end

    # Set correct variable type
    if vt == VTYPE_Marked
      qpsdat.vartypes[j] = VTYPE_Integer
    end
  end

  return qpsdat
end