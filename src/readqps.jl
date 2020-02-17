# http://lpsolve.sourceforge.net/5.5/mps-format.htm
# https://doi.org/10.1080/10556789908805768

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
    contypes::Vector{Int}
end

"""
    MPSCard

Data structure for parsing a single line of an MPS file.
"""
mutable struct MPSCard
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
const OBJ_SENSE = 2
const ROWS = 3
const COLUMNS = 4
const RHS = 5
const BOUNDS = 6
const RANGES = 7
const QUADOBJ = 8
const OBJECT_BOUND = 10

const SECTION_HEADERS = Dict{String, Int}(
    "ENDATA" => ENDATA,
    "NAME" => NAME,
    "OBJ_SENSE" => OBJ_SENSE,  # Free MPS only
    "ROWS" => ROWS,
    "COLUMNS" => COLUMNS,
    "RHS" => RHS,
    "BOUNDS" => BOUNDS,
    "RANGES" => RANGES,
    "QUADOBJ" => QUADOBJ,
    "OBJECT BOUND" => OBJECT_BOUND,  # SIF only
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

# Row types
const RTYPE_E =  0  # equal-to
const RTYPE_L = -1  # less-than
const RTYPE_G =  1  # greater-than
const RTYPE_N =  2  # objective

function row_type(rtype::String)
    if rtype == "E"
        return RTYPE_E
    elseif rtype == "L"
        return RTYPE_L
    elseif rtype == "G"
        return RTYPE_G
    elseif rtype == "N"
        return RTYPE_N
    else
        error("Unknown row type $rtype")
    end
end

"""
    read_card!(card::MPSCard, ln::String)

Read the fields in `ln` into `card`.
"""
function read_card!(card::MPSCard, ln::String)
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
        end

    else
        # Regular card
        card.iscomment = false
        card.isheader = false

        # Read fields
        # First field
        if l < 3
            error("Short line\n$ln")
        else
            card.f1 = strip(String(ln[2:3]))
            card.nfields = 1
        end

        # Second field
        if l < 5
            return card
        elseif 5 <= l <= 12
            card.f2 = strip(String(ln[5:end]))
            card.nfields = 2
            return card
        else
            card.f2 = strip(String(ln[5:12]))
        end

        # Third field
        if l < 15
            card.nfields = 2
            return card
        elseif 15 <= l <= 22
            card.f3 = strip(String(ln[15:end]))
            card.nfields = 3
            return card
        else
            card.f3 = strip(String(ln[15:22]))
        end

        # Fourth field
        if l < 25
            card.nfields = 3
            return card
        elseif 25 <= l <= 36
            card.f4 = strip(String(ln[25:end]))
            card.nfields = 4
            return card
        else
            card.f4 = strip(String(ln[25:36]))
        end

        # Fifth field
        if l < 40
            card.nfields = 4
            return card
        elseif 40 <= l <= 47
            card.f5 = strip(String(ln[40:end]))
            card.nfields = 5
            return card
        else
            card.f5 = strip(String(ln[40:47]))
        end

        # Sixth field
        if l < 50
            card.nfields = 5
            return card
        elseif 50 <= l <= 61
            card.f6 = strip(String(ln[50:end]))
        else
            card.f6 = strip(String(ln[50:61]))
        end

        card.nfields = 6
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
    card.nfields >= 2 || error(
        "Line $(card.nline) contains only $(card.nfields) fields"
    )

    rtype = row_type(card.f1)
    rowname = card.f2

    if rtype == RTYPE_N
        # Objective row
        if isnothing(qps.objname)
            # Record objective
            qps.objname = rowname
            qps.conindices[rowname] = 0
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
    if rtype == RTYPE_E
        push!(qps.lcon, 0.0)
        push!(qps.ucon, 0.0)
    elseif rtype == RTYPE_G
        push!(qps.lcon, 0.0)
        push!(qps.ucon, Inf)
    elseif rtype == RTYPE_L
        push!(qps.lcon, -Inf)
        push!(qps.ucon, 0.0)
    end

    return nothing
end

function read_columns_line!(qps::QPSData, card::MPSCard)
    # Sanity check
    card.nfields >= 4 || error(
        "Line $(card.nline) contains only $(card.nfields) fields"
    )

    varname = card.f2
    nvar = qps.nvar + 1
    # Get column index
    col = get!(qps.varindices, varname, nvar)
    if col == nvar
        # new variable
        qps.nvar += 1
        push!(qps.varnames, varname)
        push!(qps.c, 0.0)

        # Populate default variable bounds
        # TODO: this should be done only once
        push!(qps.lvar, 0.0)
        push!(qps.uvar, Inf)
    end

    fun = card.f3
    val = parse(Float64, card.f4)

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

    card.nfields >= 6 || return nothing

    # Read second par of the fields
    fun = card.f5
    val = parse(Float64, card.f6)

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
    card.nfields >= 4 || error(
        "Line $(card.nline) contains only $(card.nfields) fields"
    )

    rhs = card.f2
    if isnothing(qps.rhsname)
        # Record this as the RHS
        qps.rhsname = rhs
    elseif qps.rhsname != rhs
        # Rim RHS, ignore this line
        @error "Skipping line $(card.nline) with rim RHS $rhs"
        return nothing
    end

    fun = card.f3
    val = parse(Float64, card.f4)
    row = get(qps.conindices, fun, -2)
    if row == 0
        # Objective row
        qps.c0 = -val
    elseif row == -1
        # Rim objective, ignore this input
        @error "Ignoring RHS for rim objective $fun at line $(card.nline)"
    elseif row > 0
        rtype = qps.contypes[row]
        if rtype == RTYPE_E
            qps.lcon[row] = val
            qps.ucon[row] = val
        elseif rtype == RTYPE_L
            qps.ucon[row] = val
        elseif rtype == RTYPE_G
            qps.lcon[row] = val
        end
    else
        # This row was not declared
        error("Unknown row $fun.")
    end

    card.nfields >= 6 || return nothing

    fun = card.f5
    val = parse(Float64, card.f6)
    row = get(qps.conindices, fun, -2)
    if row == 0
        # Objective row
        qps.c0 = -val
    elseif row == -1
        # Rim objective, ignore this input
        @error "Ignoring RHS for rim objective $fun at line $(card.nline)"
    elseif row > 0
        rtype = qps.contypes[row]
        if rtype == RTYPE_E
            qps.lcon[row] = val
            qps.ucon[row] = val
        elseif rtype == RTYPE_L
            qps.ucon[row] = val
        elseif rtype == RTYPE_G
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
    card.nfields >= 4 || error(
        "Line $(card.nline) contains only $(card.nfields) fields"
    )
    
    rng = card.f2
    if isnothing(qps.rngname)
        # Record this as the RANGES
        qps.rngname = rng
    elseif qps.rngname != rng
        # Rim RANGES, ignore this line
        @error "Skipping line $(card.nline) with rim RANGES $rng"
        return nothing
    end

    rowname = card.f3
    val = parse(Float64, card.f4)
    row = get(qps.conindices, rowname, -2)
    if row == 0 || row == -1
        # Objective row
        error("Encountered objective row $rowname in RANGES section")
    elseif row > 0
        rtype = qps.contypes[row]
        if rtype == RTYPE_E
            if val >= 0.0
                qps.ucon += val
            else
                qps.lcon[row] += val
            end
        elseif rtype == RTYPE_L
            qps.lcon[row] = qps.ucon[row] - abs(val)
        elseif rtype == RTYPE_G
            qps.ucon[row] = qps.lcon[row] + abs(val)
        end
    else
        # This row was not declared
        error("Unknown row $rowname.")
    end

    card.nfields >= 6 || return nothing

    rowname = card.f5
    val = parse(Float64, card.f6)
    row = get(qps.conindices, rowname, -2)
    if row == 0 || row == -1
        # Objective row
        error("Encountered objective row $rowname in RANGES section")
    elseif row > 0
        rtype = qps.contypes[row]
        if rtype == RTYPE_E
            if val >= 0.0
                qps.ucon += val
            else
                qps.lcon[row] += val
            end
        elseif rtype == RTYPE_L
            qps.lcon[row] = qps.ucon[row] - abs(val)
        elseif rtype == RTYPE_G
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
    card.nfields >= 3 || error(
        "Line $(card.nline) contains only $(card.nfields) fields"
    )

    bnd = card.f2
    if isnothing(qps.bndname)
        # Record this as the BOUNDS
        qps.bndname = bnd
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
        # TODO: error or just record bounds?
        error("Binary variables are currently not supported")
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
        # TODO: warning?
        @warn "recording bound but integer variables currently not supported"
        qps.lvar[col] = val
    elseif btype == "UI"
        # TODO: warning?
        @warn "recording bound but integer variables currently not supported"
        qps.uvar[col] = val
    end

    return nothing
end

function read_quadobj_line!(qps::QPSData, card::MPSCard)
    # Sanity check
    card.nfields >= 4 || error(
        "Line $(card.nline) contains only $(card.nfields) fields"
    )

    colname = card.f2
    rowname = card.f3
    val = parse(Float64, card.f4)

    col = get(qps.varindices, colname, 0)
    col > 0 || error("Unknown variable $colname")
    row = get(qps.varindices, rowname, 0)
    row > 0 || error("Unknown variable $rowname")

    push!(qps.qcols, col)
    push!(qps.qrows, row)
    push!(qps.qvals, val)

    return nothing
end

function readqps(filename::String)
    name_section_read = false
    objsense_section_read = false
    rows_section_read = false
    columns_section_read = false
    rhs_section_read = false
    bounds_section_read = false
    ranges_section_read = false
    quadobj_section_read = false
    endata_read = false

    sec = -1

    card = MPSCard(0, false, false, 0, "", "", "", "", "", "")

    qpsdat = QPSData(
        0, 0,
        :notset, 0.0, Float64[], Int64[], Int64[], Float64[],
        Int64[], Int64[], Float64[], Float64[], Float64[],
        Float64[], Float64[],
        nothing, nothing, nothing, nothing, nothing,
        String[], String[],
        Dict{String, Int}(), Dict{String, Int}(), Int[]
    )

    qps = open(filename, "r")
    seekstart(qps)
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
            elseif sec == OBJ_SENSE
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
        if sec == OBJ_SENSE
            # Parse objective sense
            read_objsense_line!(qpsdat, card)
        elseif sec == ROWS
            read_rows_line!(qpsdat, card)
        elseif sec == COLUMNS
            read_columns_line!(qpsdat, card)
        elseif sec == RHS
            read_rhs_line!(qpsdat, card)
        elseif sec == BOUNDS
            read_bounds_line!(qpsdat, card)
        elseif sec == RANGES
            read_ranges_line!(qpsdat, card)
        elseif sec == QUADOBJ
            read_quadobj_line!(qpsdat, card)
        else
            error("Unexpected section $sec in line\n$line")
        end
    end
    close(qps)

    endata_read || @error("reached end of file before ENDATA section")

    @info("Problem name     : $(qpsdat.name)")
    @info("Objective sense  : $(qpsdat.objsense)")
    @info("Objective name   : $(qpsdat.objname)")
    rhs_section_read && @info("RHS              : $(qpsdat.rhsname)")
    ranges_section_read && @info("RANGES           : $(qpsdat.rngname)")
    bounds_section_read && @info("BOUNDS           : $(qpsdat.bndname)")

    return qpsdat
end
