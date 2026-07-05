#!/bin/bash
#SBATCH --job-name=dgesv_icc
#SBATCH --output=results_icc_%j.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=06:00:00
#SBATCH --mem=8G
#SBATCH --partition=compute

set -euo pipefail

INTEL_MODULE="${INTEL_MODULE:-intel/2021.3.0}"
MKL_MODULE="${MKL_MODULE:-imkl/2021.3.0}"
CC_BIN="${ICC_BIN:-icc}"
COMPILER_TAG="${ICC_TAG:-ICC2021.3.0}"
JOB_TAG="${SLURM_JOB_ID:-$$}"
SIZES="${SIZES:-1024 2048 4096}"
REPEATS="${REPEATS:-3}"
RESULTS="${RESULTS:-dgesv_results_icc.csv}"
RAW_RESULTS="${RAW_RESULTS:-dgesv_results_icc_raw.csv}"
MKL_LIBS=("-lmkl_rt" "-lpthread" "-lm" "-ldl")
ICC_OPT_FLAGS="${ICC_OPT_FLAGS:-O2 O3 fast}"
RESET_RESULTS="${RESET_RESULTS:-1}"

read -r -a OPT_FLAGS <<< "$ICC_OPT_FLAGS"

if [[ "$REPEATS" != "3" ]]; then
    echo "This script expects REPEATS=3 so it can compute medians."
    exit 1
fi

module purge
module load "$INTEL_MODULE"
module load "$MKL_MODULE"

export LD_LIBRARY_PATH="$MKLROOT/lib/intel64:${LD_LIBRARY_PATH:-}"

echo "=== Running DGESV Benchmarks (${COMPILER_TAG}) ==="
"$CC_BIN" --version | head -n 1
echo ""

if [[ "$RESET_RESULTS" == "1" ]]; then
    echo "compiler,flag,size,my_dgesv_median_ms,ref_dgesv_median_ms" > "$RESULTS"
    echo "compiler,flag,size,run,my_dgesv_ms,ref_dgesv_ms" > "$RAW_RESULTS"
else
    if [[ ! -f "$RESULTS" ]]; then
        echo "compiler,flag,size,my_dgesv_median_ms,ref_dgesv_median_ms" > "$RESULTS"
    fi
    if [[ ! -f "$RAW_RESULTS" ]]; then
        echo "compiler,flag,size,run,my_dgesv_ms,ref_dgesv_ms" > "$RAW_RESULTS"
    fi
fi

median_of_three() {
    printf "%s\n" "$1" "$2" "$3" | sort -n | awk 'NR==2{print $1}'
}

for flag in "${OPT_FLAGS[@]}"; do
    echo "---- Building with $flag ----"
    bin="dgesv_bench_icc_${flag}_${JOB_TAG}"
    vec_file="vec_icc_${flag}.optrpt"

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
            cflags=("-O3" "-xHost" "-no-prec-div" "-fp-model" "fast=2" "-ansi-alias")
            linkflags=(
                "-Wl,--dynamic-linker,/lib64/ld-linux-x86-64.so.2"
                "-Wl,-rpath,$MKLROOT/lib/intel64"
                "-Wl,-Bdynamic"
                "$MKLROOT/lib/intel64/libmkl_rt.so"
                "-lpthread"
                "-lm"
                "-ldl"
            )
            ;;
        *)
            echo "Unsupported flag: $flag"
            exit 1
            ;;
    esac

    if ! "$CC_BIN" "${cflags[@]}" -qopt-report=5 -qopt-report-phase=vec \
        -qopt-report-file="$vec_file" \
        dgesv.c timer.c main.c -o "$bin" "${linkflags[@]}"; then
        echo "Build failed for $flag"
        for size in $SIZES; do
            echo "$COMPILER_TAG,$flag,$size,NA,NA" >> "$RESULTS"
            echo "$COMPILER_TAG,$flag,$size,0,BUILD_FAIL,BUILD_FAIL" >> "$RAW_RESULTS"
        done
        continue
    fi

    for size in $SIZES; do
        echo "Running size=$size ($flag)"
        my_t1=0
        my_t2=0
        my_t3=0
        ref_t1=0
        ref_t2=0
        ref_t3=0
        run_failed=0

        for run in $(seq 1 "$REPEATS"); do
            if ! output=$(./"$bin" "$size" 2>&1); then
                echo "$output"
                echo "$COMPILER_TAG,$flag,$size,$run,RUN_FAIL,RUN_FAIL" >> "$RAW_RESULTS"
                run_failed=1
                break
            fi

            echo "$output"

            my_time=$(echo "$output" | awk '/Time taken by my dgesv solver/ {print $(NF-1)}')
            if [[ -z "$my_time" ]]; then my_time=0; fi

            ref_time=$(echo "$output" | awk '/Time taken by Lapacke dgesv/ {print $(NF-1)}')
            if [[ -z "$ref_time" ]]; then ref_time=0; fi

            echo "$COMPILER_TAG,$flag,$size,$run,$my_time,$ref_time" >> "$RAW_RESULTS"

            if [[ "$run" == "1" ]]; then
                my_t1=$my_time
                ref_t1=$ref_time
            elif [[ "$run" == "2" ]]; then
                my_t2=$my_time
                ref_t2=$ref_time
            else
                my_t3=$my_time
                ref_t3=$ref_time
            fi
        done

        if [[ "$run_failed" == "1" ]]; then
            echo "$COMPILER_TAG,$flag,$size,NA,NA" >> "$RESULTS"
            continue
        fi

        my_median=$(median_of_three "$my_t1" "$my_t2" "$my_t3")
        ref_median=$(median_of_three "$ref_t1" "$ref_t2" "$ref_t3")
        echo "$COMPILER_TAG,$flag,$size,$my_median,$ref_median" >> "$RESULTS"
    done
done

rm -f dgesv_bench_icc_*_"$JOB_TAG"

echo ""
echo "All runs complete. Median data saved to $RESULTS"
echo "Run-level data saved to $RAW_RESULTS"