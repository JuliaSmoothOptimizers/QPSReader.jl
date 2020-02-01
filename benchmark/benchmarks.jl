using BenchmarkTools
const BT = BenchmarkTools

using QPSReader

const NETLIB_DIR = joinpath(@__DIR__, "netlib")
const MAROS_DIR = joinpath(@__DIR__, "maros")

const SUITE = BT.BenchmarkGroup()

SUITE["netlib"] = BT.BenchmarkGroup()
SUITE["maros"] = BT.BenchmarkGroup()

"""
    add_instances!(suite, dir)

Create a BenchmarkGroup comprising all instances listed in `dir`.

Each file is read first, and is excluded from the benchmark if an error is
    encountered during the reading. The list of all such files is displayed in a
    warning message before exiting the function, when applicable.
"""
function add_instances!(suite, dir)
    instances = readdir(dir)
    errored_instances = String[]

    for finst in instances
        fpath = joinpath(dir, finst)
        try
            readqps(fpath)
        catch err
            # Exclude file from benchmark
            push!(errored_instances, finst)
            continue
        end
        suite[finst] = @benchmarkable(readqps($fpath))
    end

    nerr = length(errored_instances)
    if nerr > 0
        @warn "Reader errored on the following $nerr files:\n$(errored_instances)"
    end

    return suite
end

add_instances!(SUITE["netlib"], NETLIB_DIR)
add_instances!(SUITE["maros"], MAROS_DIR)