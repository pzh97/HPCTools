#!/bin/bash
#SBATCH --job-name=dgesv_icx
#SBATCH --output=results_icx_%j.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=06:00:00
#SBATCH --mem=8G
#SBATCH --partition=compute

set -euo pipefail

INTEL_MODULE="${INTEL_MODULE:-intel/2021.3.0}"
MKL_MODULE="${MKL_MODULE:-imkl/2021.3.0}"
CC_BIN="${ICX_BIN:-icx}"
COMPILER_TAG="${ICX_TAG:-ICX2021.3.0}"
JOB_TAG="${SLURM_JOB_ID:-$$}"
SIZES="${SIZES:-1024 2048 4096}"
REPEATS="${REPEATS:-3}"
RESULTS="${RESULTS:-dgesv_results_icx.csv}"
RAW_RESULTS="${RAW_RESULTS:-dgesv_results_icx_raw.csv}"
MKL_LIBS=("-lmkl_rt" "-lpthread" "-lm" "-ldl")
OPT_FLAGS=("O2" "O3" "Ofast" "Ofast-ipo")

if [[ "$REPEATS" != "3" ]]; then
    echo "This script expects REPEATS=3 so it can compute medians."
    exit 1
fi

module purge
module load "$INTEL_MODULE"
module load "$MKL_MODULE"

echo "=== Running DGESV Benchmarks (${COMPILER_TAG}) ==="
"$CC_BIN" --version | head -n 3
echo ""

echo "compiler,flag,size,my_dgesv_median_ms,ref_dgesv_median_ms" > "$RESULTS"
echo "compiler,flag,size,run,my_dgesv_ms,ref_dgesv_ms" > "$RAW_RESULTS"

median_of_three() {
    printf "%s\n" "$1" "$2" "$3" | sort -n | awk 'NR==2{print $1}'
}

for flag in "${OPT_FLAGS[@]}"; do
    echo "---- Building with $flag ----"
    bin="dgesv_bench_icx_${flag}_${JOB_TAG}"
    vec_file="vec_icx_${flag}.txt"

    case "$flag" in
        O2)
            cflags=("-O2")
            ;;
        O3)
            cflags=("-O3")
            ;;
        Ofast)
            cflags=("-Ofast")
            ;;
        Ofast-ipo)
            cflags=("-Ofast" "-ipo")
            ;;
        *)
            echo "Unsupported flag: $flag"
            exit 1
            ;;
    esac

    "$CC_BIN" "${cflags[@]}" \
        -Rpass=loop-vectorize -Rpass-analysis=loop-vectorize -Rpass-missed=loop-vectorize \
        dgesv.c timer.c main.c -o "$bin" "${MKL_LIBS[@]}" 2> "$vec_file"

    if [[ ! -x "$bin" ]]; then
        echo "Build failed for $flag"
        exit 1
    fi

    for size in $SIZES; do
        echo "Running size=$size ($flag)"
        my_t1=0
        my_t2=0
        my_t3=0
        ref_t1=0
        ref_t2=0
        ref_t3=0

        for run in $(seq 1 "$REPEATS"); do
            output=$(./"$bin" "$size")
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

        my_median=$(median_of_three "$my_t1" "$my_t2" "$my_t3")
        ref_median=$(median_of_three "$ref_t1" "$ref_t2" "$ref_t3")
        echo "$COMPILER_TAG,$flag,$size,$my_median,$ref_median" >> "$RESULTS"
    done
done

rm -f dgesv_bench_icx_*_"$JOB_TAG"

echo ""
echo "All runs complete. Median data saved to $RESULTS"
echo "Run-level data saved to $RAW_RESULTS"