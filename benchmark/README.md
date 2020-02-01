# Benchmark

## Benchmark testsets

### Netlib

The netlib testset contains 114 small LP instances.
It is available [here](http://www.numerical.rl.ac.uk/cute/netlib.html) (in `.SIF` format)

To download and extract (on Linux systems) the netlib LPs:
```bash
# Download dataset
wget ftp://ftp.numerical.rl.ac.uk/pub/cuter/netlib.tar.gz
# Extract instances
tar -xvf netlib.tar.gz
# Delete files that are not instances
find netlib -type f ! -name "*.SIF" -delete
```

### Maros-Meszaros QPs

The Maros-Meszaros QPs can be found [here](http://www.doc.ic.ac.uk/~im/#DATA).
The three datasets total 138 QPs.

To download the datasets (on Linux systems):
```bash
# Download datasets
wget http://www.doc.ic.ac.uk/%7Eim/QPDATA1.ZIP
wget http://www.doc.ic.ac.uk/%7Eim/QPDATA2.ZIP
wget http://www.doc.ic.ac.uk/%7Eim/QPDATA3.ZIP
# Extract datasets
mkdir maros
unzip -q QPDATA1.ZIP -d maros
unzip -q QPDATA2.ZIP -d maros
unzip -q QPDATA3.ZIP -d maros
```

## Running the benchmark

Ensure that your current `Manifest.toml` points to the correct version of `QPSReader`. Otherwise, the most recent version will be installed.
```bash
Pkg.develop(PackageSpec(path=".."))
```

Then, run the benchmark as follows:
```julia
julia> using PkgBenchmark
julia> import QPSReader
julia> res = benchmarkpkg(pathof(QPSReader));
julia> export_markdown("results.md", res)
```

## Comparing two commits

To compare against the `master` branch
```julia
using PkgBenchmark
judgement = judge("..", "master")
export_markdown("judgement.md", judgement)
```