using Logging

using BenchmarkTools
const BT = BenchmarkTools

using QPSReader

const NETLIB_DIR = fetch_netlib()
const MAROS_DIR = fetch_mm()

const SUITE = BT.BenchmarkGroup()

SUITE["netlib"] = BT.BenchmarkGroup()
SUITE["maros"] = BT.BenchmarkGroup()

"""
    readqps_silent

Silent wrapper of `readqps` for benchmark use.
"""
function readqps_silent(args...; kwargs...)
    with_logger(Logging.NullLogger()) do
        readqps(args...; kwargs...)
    end
end

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

        # All instance files should have .SIF extension
        finst[end-3:end] == ".SIF" || continue

        try
            # First try to read in free MPS format.
            # If fails, try with fixed MPS format
            # If fails again, discard instance
            try
                readqps_silent(fpath)
                suite[finst] = @benchmarkable(readqps_silent($fpath))
            catch err
                readqps_silent(fpath, mpsformat=:fixed)
                suite[finst] = @benchmarkable(readqps_silent($fpath, mpsformat=:fixed))
            end
        catch err
            # Exclude file from benchmark
            push!(errored_instances, finst)
            continue
        end
    end

    nerr = length(errored_instances)
    if nerr > 0
        @warn "Reader errored on the following $nerr files:\n$(errored_instances)"
    end

    return suite
end

add_instances!(SUITE["netlib"], NETLIB_DIR)
add_instances!(SUITE["maros"], MAROS_DIR)