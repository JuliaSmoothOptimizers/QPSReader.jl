# Benchmark

## Benchmark testsets

Benchmarks are run on the [Netlib LP collection](http://www.numerical.rl.ac.uk/cute/netlib.html) and [Maros-Meszaros QP collection](http://www.doc.ic.ac.uk/~im/#DATA).
They consist of 114 LPs and 138 QPs, respectively.
Both collections are automatically downloaded through Julia's artifact system.

## Running the benchmark

Ensure that your current `Manifest.toml` points to the correct version of `QPSReader`. Otherwise, the most recent version will be installed.
```julia
Pkg.develop(PackageSpec(path=".."))
```

Then, run the benchmark as follows:
```julia
using PkgBenchmark
import QPSReader
res = benchmarkpkg(pathof(QPSReader));
export_markdown("results.md", res)
```

## Comparing two commits

To compare against the `master` branch
```julia
using PkgBenchmark

judgement = judge("..", "master")
export_markdown("judgement.md", judgement)
```