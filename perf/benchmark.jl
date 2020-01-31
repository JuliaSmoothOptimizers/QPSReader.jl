using ArgParse
using BenchmarkTools

using QPSReader

const NETLIB_DIR = joinpath(@__DIR__, "netlib")
const MAROS_DIR = joinpath(@__DIR__, "maros")

function parse_commandline(cl_args)

    s = ArgParseSettings()

    @add_arg_table s begin
        "--params"
            help = "Location of parameter file."
            arg_type = String
            default = ""
        "--name"
            help = "prefix"
            arg_type = String
            default = ""
        "--time"
            help = "Maximum time spent per instance"
            arg_type = Float64
            default = 1.0
        "--verbose", "-v"
            help = "Verbose flag"
            action = :store_true
    end

    return parse_args(cl_args, s)
end

"""
    benchmark_suite(dir)

Create a BenchmarkGroup comprising all instances listed in `dir`.

Each file is read first, and is excluded from the benchmark if an error is
    encountered during the reading. The list of all such files is displayed in a
    warning message before exiting the function, when applicable.
"""
function benchmark_suite(dir; seconds=1.0)
    suite = BenchmarkGroup()
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
        suite[finst] = @benchmarkable(readqps($fpath), seconds=seconds, evals=1, samples=3)
    end

    nerr = length(errored_instances)
    if nerr > 0
        @warn "Reader errored on the following $nerr files:\n$(errored_instances)"
    end

    return suite
end

function main(cl_args::Vector{String})
    args = parse_commandline(cl_args)

    # Create benchmark suite
    tsec = args["time"]
    bsuite = BenchmarkGroup(
        "netlib" => benchmark_suite(NETLIB_DIR, seconds=tsec),
        "maros"  => benchmark_suite(MAROS_DIR,  seconds=tsec)
    )

    # Parameters
    fpar = args["params"]
    if fpar != ""
        # Load parameters
        @info "Reading parameters from $fpar"
        loadparams!(bsuite, BenchmarkTools.load(fpar)[1])
    else
        @info "Tuning.\nBenchmark parameters will be saved in params_$(args["name"]).json"
        tune!(bsuite)
        BenchmarkTools.save("params_$(args["name"]).json", params(bsuite))
    end

    # Run benchmark
    fres = "res_$(args["name"]).json"
    @info "Running.\nBenchmark results will be saved in $fres"
    vflag = args["verbose"]
    res = run(bsuite, verbose=vflag)

    # save results
    BenchmarkTools.save(fres, res)

    # Done
    return nothing
end

main(ARGS)