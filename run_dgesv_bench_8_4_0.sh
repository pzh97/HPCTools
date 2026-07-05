#!/bin/bash
#SBATCH --job-name=dgesv_gcc8
#SBATCH --output=results_gcc8_%j.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=06:00:00
#SBATCH --mem=8G
#SBATCH --partition=compute

# ------------------------------------------------------------
# Use GCC 8.4.0 via full path
# ------------------------------------------------------------
CC=/mnt/netapp1/Optcesga_FT2_RHEL7/2020/gentoo/22072020/usr/bin/gcc-8.4.0
CXX=/mnt/netapp1/Optcesga_FT2_RHEL7/2020/gentoo/22072020/usr/bin/g++-8.4.0
COMPILER_TAG="GCC8.4.0"
JOB_TAG="${SLURM_JOB_ID:-$$}"

echo "=== Running DGESV Benchmarks (GCC 8.4.0) ==="
$CC --version | head -n 1
echo ""

# ------------------------------------------------------------
# Load only required libraries
# ------------------------------------------------------------
module purge
module load cesga/2020
module load openblas/0.3.25

# ------------------------------------------------------------
# Benchmark parameters
# ------------------------------------------------------------
OPT_FLAGS=("O0" "O2-novec" "O3-vec" "Ofast-vec")
SIZES=(1024 2048 4096)
REPEATS=3

RESULTS="dgesv_results_gcc8.csv"
RAW_RESULTS="dgesv_results_gcc8_raw.csv"
echo "compiler,flag,size,my_dgesv_median_ms,ref_dgesv_median_ms" > "$RESULTS"
echo "compiler,flag,size,run,my_dgesv_ms,ref_dgesv_ms" > "$RAW_RESULTS"

median_of_three() {
    printf "%s\n" "$1" "$2" "$3" | sort -n | awk 'NR==2{print $1}'
}

# ------------------------------------------------------------
# Run benchmarks
# ------------------------------------------------------------
for flag in "${OPT_FLAGS[@]}"; do
    echo "---- Building with $flag ----"

    bin="dgesv_bench_gcc8_${flag}_${JOB_TAG}"

    case $flag in
        "O0")
            "$CC" -O0 dgesv.c timer.c main.c -o "$bin" -lopenblas -lm
            ;;
        "O2-novec")
            "$CC" -O2 -fno-tree-vectorize dgesv.c timer.c main.c -o "$bin" -lopenblas -lm
            ;;
        "O3-vec")
            "$CC" -O3 -march=native -ftree-vectorize \
                -fopt-info-vec-optimized="vec_gcc8_O3.txt" \
                -fopt-info-vec-missed="missed_gcc8_O3.txt" \
                dgesv.c timer.c main.c -o "$bin" -lopenblas -lm
            ;;
        "Ofast-vec")
            "$CC" -Ofast -march=native -ftree-vectorize \
                -fopt-info-vec-optimized="vec_gcc8_Ofast.txt" \
                -fopt-info-vec-missed="missed_gcc8_Ofast.txt" \
                dgesv.c timer.c main.c -o "$bin" -lopenblas -lm
            ;;
    esac

    if [[ ! -x "$bin" ]]; then
        echo "Build failed for $flag"
        exit 1
    fi

    for size in "${SIZES[@]}"; do
        echo "Running size=$size ($flag)"
        my_t1=0
        my_t2=0
        my_t3=0
        ref_t1=0
        ref_t2=0
        ref_t3=0

        for run in $(seq 1 $REPEATS); do
            # Run program and capture output
            output=$(./"$bin" "$size")
            echo "$output"

            # Extract my_dgesv solver time
            my_time=$(echo "$output" | awk '/Time taken by my dgesv solver/ {print $(NF-1)}')
            if [ -z "$my_time" ]; then my_time=0; fi

            # Extract LAPACKE solver time (Ref)
            ref_time=$(echo "$output" | awk '/Time taken by Lapacke dgesv/ {print $(NF-1)}')
            if [ -z "$ref_time" ]; then ref_time=0; fi

            # Append run-level data
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

rm -f dgesv_bench_gcc8_*_"$JOB_TAG"

# ------------------------------------------------------------
# Print completion info
# ------------------------------------------------------------
echo ""
echo "All runs complete. Median data saved to $RESULTS"
echo "Run-level data saved to $RAW_RESULTS"
