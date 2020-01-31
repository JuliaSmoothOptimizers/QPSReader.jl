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

```bash
julia --project=. -e 'using Pkg; Pkg.dev(PackageSpec(path=".."))'
git checkout master
julia --project=. benchmark.jl --name master
git checkout dev
julia --project=. benchmark.jl --params par_master.json--name dev
```

## Comparing two benchmarks

Two benchmarks can be compared as follows:
```bash
julia --project=. compare.jl res_new.json res_old.json 
```

For instance, to compare the two benchmarks above, run
```bash
julia --project=. compare.jl res_dev.json res_stable.json 
```