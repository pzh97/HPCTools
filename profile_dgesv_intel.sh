#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: $0 <icc|icx> <O2|O3|fast|Ofast|Ofast-ipo> <size> <perf|callgrind|cachegrind|massif|advisor|vtune>"
    exit 1
}

if [[ $# -ne 4 ]]; then
    usage
fi

compiler="$1"
flag="$2"
size="$3"
profiler="$4"
bin="dgesv_profile_${compiler}_${flag}_${size}"
INTEL_MODULE="${INTEL_MODULE:-intel/2021.3.0}"
MKL_MODULE="${MKL_MODULE:-imkl/2021.3.0}"
MKL_LIBS=("-lmkl_rt" "-lpthread" "-lm" "-ldl")
FAST_LINK_FLAGS=(
    "-Wl,--dynamic-linker,/lib64/ld-linux-x86-64.so.2"
    "-Wl,-rpath,$MKLROOT/lib/intel64"
    "-Wl,-Bdynamic"
    "$MKLROOT/lib/intel64/libmkl_rt.so"
    "-lpthread"
    "-lm"
    "-ldl"
)

case "$compiler" in
    icc)
        cc_bin="${ICC_BIN:-icc}"
        ;;
    icx)
        cc_bin="${ICX_BIN:-icx}"
        ;;
    *)
        usage
        ;;
esac

case "$flag" in
    O2)
        cflags=("-O2")
        linkflags=("${MKL_LIBS[@]}")
        ;;
    O3)
        cflags=("-O3")
        linkflags=("${MKL_LIBS[@]}")
        ;;
    fast)
        if [[ "$compiler" != "icc" ]]; then
            echo "The fast flag is intended for icc."
            exit 1
        fi
        cflags=("-O3" "-xHost" "-no-prec-div" "-fp-model" "fast=2" "-ansi-alias")
        linkflags=("${FAST_LINK_FLAGS[@]}")
        ;;
    Ofast)
        cflags=("-Ofast")
        linkflags=("${MKL_LIBS[@]}")
        ;;
    Ofast-ipo)
        cflags=("-Ofast" "-ipo")
        linkflags=("${MKL_LIBS[@]}")
        ;;
    *)
        usage
        ;;
esac

module purge
module load "$INTEL_MODULE"
module load "$MKL_MODULE"

if [[ "$flag" == "fast" ]]; then
    export LD_LIBRARY_PATH="$MKLROOT/lib/intel64:${LD_LIBRARY_PATH:-}"
fi

"$cc_bin" "${cflags[@]}" -g dgesv.c timer.c main.c -o "$bin" "${linkflags[@]}"

case "$profiler" in
    perf)
        perf stat -d ./"$bin" "$size" 2>&1 | tee "profile_${compiler}_${flag}_${size}_perf.txt"
        ;;
    callgrind)
        valgrind --tool=callgrind --callgrind-out-file="callgrind.out.${compiler}.${flag}.${size}" ./"$bin" "$size" \
            2>&1 | tee "profile_${compiler}_${flag}_${size}_callgrind.txt"
        ;;
    cachegrind)
        valgrind --tool=cachegrind --cachegrind-out-file="cachegrind.out.${compiler}.${flag}.${size}" ./"$bin" "$size" \
            2>&1 | tee "profile_${compiler}_${flag}_${size}_cachegrind.txt"
        ;;
    massif)
        valgrind --tool=massif --massif-out-file="massif.out.${compiler}.${flag}.${size}" ./"$bin" "$size" \
            2>&1 | tee "profile_${compiler}_${flag}_${size}_massif.txt"
        ;;
    advisor)
        module load advisor/2021.4.0
        advisor --collect=survey --project-dir "advisor_${compiler}_${flag}_${size}" -- ./"$bin" "$size"
        ;;
    vtune)
        module load vtune/2022.1.0
        vtune -collect hotspots -result-dir "vtune_${compiler}_${flag}_${size}" -- ./"$bin" "$size"
        ;;
    *)
        usage
        ;;
esac