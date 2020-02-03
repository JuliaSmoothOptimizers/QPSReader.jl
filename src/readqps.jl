# http://lpsolve.sourceforge.net/5.5/mps-format.htm
# https://doi.org/10.1080/10556789908805768

const OBJSENSE = ["MIN", "MAX"]
const sections = ["NAME", "OBJSENSE", "ROWS", "COLUMNS", "RHS", "BOUNDS", "RANGES", "QUADOBJ", "ENDATA"]
const row_types = ["N", "G", "L", "E"]
const bounds_types = ["FR", "MI", "PL", "BV", "LO", "UP", "FX", "LI", "UI", "SC"]

# extra sections found in some SIF files that we ignore but shouldn't cause an error
const sifsections = ["OBJECT BOUND"]

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
    name::String                     # problem name
    objname::String                  # objective function name
    rhsname::String                  # Name of RHS field
    bndname::String                  # Name of BOUNDS field
    rngname::String                  # Name of RANGES field
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
end

function is_section_header(line)
    # check if the first few characters of `line` are a section name
    # this is necessary because a section name could appear elsewhere
    # in the line (e.g., as a variable or constraint name)
    for section in sections ∪ sifsections
        if occursin(section, line)
            l = length(section)
            if section == line[1:l]
                return true
            end
        end
    end
    return false
end

function read_name_section(qps, rest)
    # @debug "reading name section"
    return rest  # simply return the problem name
end

function read_objsense_section(qps)
    objsense = :notset
    pos = position(qps)
    while true
        line = readline(qps)
        l = length(line)
        if length(strip(line)) == 0
            pos = position(qps)
            continue  # this line is blank
        end
        if line[1] == '*'
            pos = position(qps)
            continue  # this line is a comment
        end
        is_section_header(line) && break  # reached the end of this section

        line[1] in objsense || error("undefined objective sense $objsense")
        objsense = line[1] == "MIN" ? :min : :max

        pos = position(qps)
    end
    seek(qps, pos) # backtrack to beginning of line
    return objsense
end

function read_rows_section(qps)
    # @debug "reading rows section"
    objname = ""
    obj_name_read = false

    connames = String[]
    conindices = Dict{String,Int}()
    contypes = String[]
    ncon = 0
    rowtype = ""
    pos = position(qps)
    while true
        line = readline(qps)
        l = length(line)
        if length(strip(line)) == 0
            pos = position(qps)
            continue  # this line is blank
        end
        if line[1] == '*'
            pos = position(qps)
            continue  # this line is a comment
        end
        is_section_header(line) && break  # reached the end of this section
        rowtype = strip(line[2:3])
        rowtype in row_types || error("erroneous row type $rowtype")
        name = strip(line[5:min(l,12)])
        # TODO: check that row is not dupplicate
        # @debug "" rowtype name
        if rowtype == "N"
            if !obj_name_read
                # Record objective
                objname = name
                conindices[name] = 0
                obj_name_read = true
            else
                # Record name but ignore input
                conindices[name] = -1
            end
        else
            ncon += 1
            push!(contypes, rowtype)
            push!(connames, name)
            conindices[name] = ncon
        end
        pos = position(qps)
    end
    seek(qps, pos) # backtrack to beginning of line
    # @show contypes
    return ncon, objname, conindices, connames, contypes
end

function read_columns_section(qps, objname, conindices)
    # @debug "reading columns section"
    pos = position(qps)

    nvar = 0
    varnames = String[]
    varindices = Dict{String,Int}()
    acols = Int[]
    arows = Int[]
    avals = Float64[]

    # make a first pass to record variable names
    while true
        line = readline(qps)
        if length(strip(line)) == 0
            continue  # this line is blank
        end
        if line[1] == '*'
            continue  # this line is a comment
        end
        is_section_header(line) && break  # reached the end of this section
        varname = strip(line[5:12])
        # @debug "" varname
        if !haskey(varindices, varname)
            nvar += 1
            varindices[varname] = nvar
            push!(varnames, varname)
        end
    end

    seek(qps, pos)  # rewind to beginning of section

    ncon = length(keys(conindices)) # TODO: not used
    c = zeros(nvar)

    while true
        line = readline(qps)
        l = length(line)
        if length(strip(line)) == 0
            pos = position(qps)
            continue  # this line is blank
        end
        if line[1] == '*'
            pos = position(qps)
            continue  # this line is a comment
        end
        is_section_header(line) && break  # reached the end of this section
        varname = strip(line[5:12])
        col = varindices[varname]
        fun = strip(line[15:22])
        val = parse(Float64, strip(line[25:min(l,36)]))
        # @info "" varname fun val
        row = get(conindices, fun, -2)
        if row == 0
            # Objective row
            c[col] = val
        elseif row == -1
            # Rim objective, ignore this input
        elseif row > 0
            push!(arows, row)
            push!(acols, col)
            push!(avals, val)
        else
            # This row was not declared
            error("Unknown row $fun.")
        end
        if l ≥ 50
            fun = strip(line[40:47])
            val = parse(Float64, strip(line[50:min(l,61)]))
            row = get(conindices, fun, -2)
            if row == 0
                # Objective row
                c[col] = val
            elseif row == -1
                # Rim objective, ignore this input
            elseif row > 0
                push!(arows, row)
                push!(acols, col)
                push!(avals, val)
            else
                # This row was not declared
                error("Unknown row $fun.")
            end
        end
        pos = position(qps)
    end
    seek(qps, pos)  # backtrack to beginning of line
    # @debug "" nvar ncon minimum(arows) maximum(arows) minimum(acols) maximum(acols)
    return nvar, varnames, varindices, c, arows, acols, avals
end

function read_rhs_section(qps, objname, conindices, contypes)
    # @debug "reading rhs section"

    rhsname = ""
    rhs_name_read = false

    ncon = length(contypes)
    lcon = Vector{Float64}(undef, ncon)  # zeros(ncon)  # lower bounds are zero unless specified
    fill!(lcon, -Inf)
    ucon = Vector{Float64}(undef, ncon)
    fill!(ucon, Inf)

    # insert default rhs of zero in case a row isn't mentioned
    for j = 1 : ncon
        if contypes[j] == "L" || contypes[j] == "E"
            ucon[j] = 0.0
        end
        if contypes[j] == "G" || contypes[j] == "E"
            lcon[j] = 0.0
        end
    end
    # @show lcon
    # @show ucon

    c0 = 0.0

    pos = position(qps)
    while true
        line = readline(qps)
        l = length(line)
        if length(strip(line)) == 0
            pos = position(qps)
            continue  # this line is blank
        end
        if line[1] == '*'
            pos = position(qps)
            continue  # this line is a comment
        end
        is_section_header(line) && break  # reached the end of this section

        rhs = strip(line[5:12])
        if !rhs_name_read
            # Record this as the RHS
            rhsname = rhs
            rhs_name_read = true
        elseif rhsname != rhs
            # Rim RHS, ignore this line
            pos = position(qps)
            continue
        end

        fun = strip(line[15:22])
        val = parse(Float64, strip(line[25:min(l,36)]))
        # @info "" fun val
        row = get(conindices, fun, -2)
        if row == 0
            # Objective row
            c0 = -val
        elseif row == -1
            # Rim objective, ignore this input
        elseif row > 0
            if contypes[row] == "L" || contypes[row] == "E"
                ucon[row] = val
            end
            if contypes[row] == "G" || contypes[row] == "E"
                lcon[row] = val
            end
        else
            # This row was not declared
            error("Unknown row $fun.")
        end
        if l ≥ 50
            fun = strip(line[40:47])
            val = parse(Float64, strip(line[50:min(l,61)]))
            row = get(conindices, fun, -2)
            if row == 0
                # Objective row
                c0 = -val
            elseif row == -1
                # Rim objective, ignore this input
            elseif row > 0
                if contypes[row] == "L" || contypes[row] == "E"
                    ucon[row] = val
                end
                if contypes[row] == "G" || contypes[row] == "E"
                    lcon[row] = val
                end
            else
                # This row was not declared
                error("Unknown row $fun.")
            end
        end

        pos = position(qps)
    end
    seek(qps, pos)  # backtrack to beginning of line
    return rhsname, c0, lcon, ucon
end

function read_ranges_section!(qps, conindices, contypes, lcon, ucon)
    # @debug "reading ranges section"
    rngname = ""
    range_name_read = false

    pos = position(qps)
    while true
        line = readline(qps)
        l = length(line)
        if length(strip(line)) == 0
            pos = position(qps)
            continue  # this line is blank
        end
        if line[1] == '*'
            pos = position(qps)
            continue  # this line is a comment
        end
        is_section_header(line) && break  # reached the end of this section

        rng = strip(line[5:12])
        if !range_name_read
            # Record name
            rngname = rng
            range_name_read = true
        elseif rng != rngname
            # Rim RHS, ignore this line
            pos = position(qps)
            continue
        end

        fun = strip(line[15:22])
        val = parse(Float64, strip(line[25:min(l,36)]))
        # @info "" fun val
        j = conindices[fun]
        j >= 1 || error("Encountered objective row $fun in RANGES section")
        if contypes[j] == "E"
            @warn "not sure what a range is for an equality constraint! Skipping."
            continue
        end
        if contypes[j] == "G"
            ucon[j] = lcon[j] + abs(val)
        end
        if contypes[j] == "L"
            lcon[j] = ucon[j] - abs(val)
        end

        if l ≥ 50
            fun = strip(line[40:47])
            val = parse(Float64, strip(line[50:min(l,61)]))
            j = conindices[fun]
            j >= 1 || error("Encountered objective row $fun in RANGES section")
            if contypes[j] == "E"
                @warn "not sure what a range is for an equality constraint! Skipping."
                continue
            end
            if contypes[j] == "G"
                ucon[j] = lcon[j] + abs(val)
            end
            if contypes[j] == "L"
                lcon[j] = ucon[j] - abs(val)
            end
        end

        pos = position(qps)
    end
    seek(qps, pos)  # backtrack to beginning of line
    return rngname
end

function read_bounds_section(qps, nvar, varindices)
    # @debug "reading bounds section"

    bndname = ""
    bound_name_read = false

    lvar = zeros(nvar)  # lower bounds are zero unless specified
    uvar = Vector{Float64}(undef, nvar)
    fill!(uvar, Inf)

    pos = position(qps)
    while true
        line = readline(qps)
        l = length(line)
        if length(strip(line)) == 0
            pos = position(qps)
            continue  # this line is blank
        end
        if line[1] == '*'
            pos = position(qps)
            continue  # this line is a comment
        end
        is_section_header(line) && break  # reached the end of this section

        bndtype = line[2:3]
        bndtype in bounds_types || error("erroneous bound type $bndtype")
        bnd = strip(line[5:12])  # when present, is the bound name

        if !bound_name_read
            # Record
            bndname = bnd
            bound_name_read = true
        elseif bnd != bndname
            # Rim bound field. Ignore this line
            pos = position(qps)
            continue
        end

        varname = strip(line[15:min(l,22)])
        # @debug "" bndtype varname
        i = varindices[varname]
        if bndtype == "FR"
            lvar[i] = -Inf
            pos = position(qps)
            continue
        end
        if bndtype == "MI"
            lvar[i] = -Inf
            uvar[i] = 0.0
            pos = position(qps)
            continue
        end
        if bndtype == "PL"
            lvar[i] = 0.0
            uvar[i] = Inf
            pos = position(qps)
            continue
        end
        if bndtype == "BV"
            @warn "binary variables currently not supported"
            pos = position(qps)
            continue
        end
        if bndtype == "SC"
            @warn "semi-continuous variables currently not supported"
            pos = position(qps)
            continue
        end

        val = parse(Float64, strip(line[25:min(l,36)]))
        # @debug "" val
        if bndtype == "LO"
            lvar[i] = val
        end
        if bndtype == "UP"
            uvar[i] = val
        end
        if bndtype == "FX"
            lvar[i] = val
            uvar[i] = val
        end
        if bndtype == "LI"
            @warn "recording bound but integer variables currently not supported"
            lvar[i] = val
            uvar[i] = Inf
        end
        if bndtype == "UI"
            @warn "recording bound but integer variables currently not supported"
            lvar[i] = 0.0
            uvar[i] = val
        end

        pos = position(qps)
    end
    seek(qps, pos)  # backtrack to beginning of line
    return bndname, lvar, uvar
end

function read_quadobj_section(qps, varindices)
    # @debug "reading quadobj section"

    qrows = Int[]
    qcols = Int[]
    qvals = Float64[]

    pos = position(qps)
    while true
        line = readline(qps)
        l = length(line)
        if length(strip(line)) == 0
            pos = position(qps)
            continue  # this line is blank
        end
        if line[1] == '*'
            pos = position(qps)
            continue  # this line is a comment
        end
        is_section_header(line) && break  # reached the end of this section

        # read lower triangle, i.e., row ≥ col
        col = varindices[strip(line[5:12])]
        row = varindices[strip(line[15:22])]
        val = parse(Float64, strip(line[25:min(l,36)]))
        push!(qrows, row)
        push!(qcols, col)
        push!(qvals, val)

        pos = position(qps)
    end
    seek(qps, pos)  # backtrack to beginning of line
    return qrows, qcols, qvals
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

    name = ""
    objname = ""
    rhsname = ""
    bndname = ""
    rngname = ""

    varnames = String[]
    connames = String[]
    varindices = Dict{String,Int}()
    conindices = Dict{String,Int}()
    contypes = String[]

    objsense = :notset
    c0 = 0.0
    c = Float64[]
    arows, acols, avals = Int[], Int[], Float64[]
    qrows, qcols, qvals = Int[], Int[], Float64[]
    nvar = 0
    ncon = 0
    lcon = Float64[]
    ucon = Float64[]
    lvar = Float64[]
    uvar = Float64[]

    qps = open(filename, "r")
    seekstart(qps)
    while !eof(qps)
        line = readline(qps)
        strip(line) in sifsections && continue
        line = strip.(split(line))
        length(line) == 0 && continue  # this line is blank
        (line[1][1] == '*' || line[1][1] == '&') && continue  # this line is a comment
        section = line[1]
        rest = length(line) == 1 ? "" : join(line[2:end], " ")
        # @debug "" section rest
        section in sections || error("erroneous section $section")
        if section == "ENDATA"
            # @debug "found ENDATA"
            endata_read = true
            break
        end
        if section == "NAME"
            name_section_read && error("more than one NAME section specified")
            name = read_name_section(qps, rest)
            name_section_read = true
        end
        if section == "OBJSENSE"
            objsense_section_read && error("more than one OBJSENSE section specified")
            objsense = read_objsense_section(qps)
            objsense_section_read = true
        end
        if section == "ROWS"
            rows_section_read && error("more than one ROWS section specified")
            ncon, objname, conindices, connames, contypes = read_rows_section(qps)
            rows_section_read = true
        end
        if section == "COLUMNS"
            columns_section_read && error("more than one COLUMNS section specified")
            rows_section_read || error("ROWS section must come before COLUMNS section")
            nvar, varnames, varindices, c, arows, acols, avals = read_columns_section(qps, objname, conindices)
            columns_section_read = true
            # @show c
            # @show A
        end
        if section == "RHS"
            rhs_section_read && error("more than one RHS section specified")
            name_section_read || error("NAME section must come before RHS section")
            columns_section_read || error("COLUMNS section must come before RHS section")
            rhsname, c0, lcon, ucon = read_rhs_section(qps, objname, conindices, contypes)
            rhs_section_read = true
            # @show c0
            # @show lcon
            # @show ucon
        end
        if section == "RANGES"
            ranges_section_read && error("more than one RANGES section specified")
            rhs_section_read || error("RHS section must come before RANGES section")
            rngname = read_ranges_section!(qps, conindices, contypes, lcon, ucon)
            ranges_section_read = true
            # @show lcon
            # @show ucon
        end
        if section == "BOUNDS"
            bounds_section_read && error("more than one BOUNDS section specified")
            columns_section_read || error("COLUMNS section must come before BOUNDS section")
            bndname, lvar, uvar = read_bounds_section(qps, nvar, varindices)
            bounds_section_read = true
            # @show lvar
            # @show uvar
        end
        if section == "QUADOBJ"
            columns_section_read || error("COLUMNS section must come before QUADOBJ section")
            qrows, qcols, qvals = read_quadobj_section(qps, varindices)
            quadobj_section_read = true
        end
    end
    close(qps)

    endata_read || @error("reached end of file before ENDATA section")

    nvar = length(contypes)
    ncon = length(c)

    # check if optional sections were missing
    if !bounds_section_read
        lvar = zeros(nvar)
        uvar = Vector{Float64}(undef, nvar)
        fill!(uvar, Inf)
    end

    return QPSData(
        nvar, ncon,
        objsense, c0, c, qrows, qcols, qvals,
        arows, acols, avals, lcon, ucon,
        lvar, uvar,
        name, objname, rhsname, bndname, rngname,
        varnames, connames,
        varindices, conindices
    )
end
