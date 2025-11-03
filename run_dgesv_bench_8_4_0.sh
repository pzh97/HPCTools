#!/bin/bash
#SBATCH --job-name=dgesv_gcc8
#SBATCH --output=results_gcc8_%j.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=06:00:00
#SBATCH --mem=8G
#SBATCH --partition=compute

CC=/mnt/netapp1/Optcesga_FT2_RHEL7/2020/gentoo/22072020/usr/bin/gcc-8.4.0
CXX=/mnt/netapp1/Optcesga_FT2_RHEL7/2020/gentoo/22072020/usr/bin/g++-8.4.0

echo "=== Running DGESV Benchmarks (GCC 8.4.0) ==="
$CC --version | head -n 1
echo ""

module purge
module load cesga/2020
module load openblas/0.3.25

OPT_FLAGS=("O0" "O2-novec" "O3-vec" "Ofast-vec")
SIZES=(1024 2048 4096)
REPEATS=3

RESULTS="dgesv_results_gcc8.csv"
echo "compiler,flag,size,run,my_dgesv_ms,ref_dgesv_ms" > $RESULTS

for flag in "${OPT_FLAGS[@]}"; do
    echo "---- Building with $flag ----"

    make clean >/dev/null 2>&1

    case $flag in
        "O0")
            make CC=$CC CXX=$CXX CFLAGS="-O0" >/dev/null 2>&1
            ;;
        "O2-novec")
            make CC=$CC CXX=$CXX CFLAGS="-O2 -fno-tree-vectorize" >/dev/null 2>&1
            ;;
        "O3-vec")
            make CC=$CC CXX=$CXX CFLAGS="-O3 -march=native" >/dev/null 2>&1
            ;;
        "Ofast-vec")
            make CC=$CC CXX=$CXX CFLAGS="-Ofast -march=native" >/dev/null 2>&1
            ;;
    esac

    for size in "${SIZES[@]}"; do
        echo "Running size=$size ($flag)"
        for run in $(seq 1 $REPEATS); do
            output=$(./dgesv $size)
            echo "$output"
            my_time=$(echo "$output" | awk '/Time taken by my dgesv solver/ {print $(NF-1)}')
            if [ -z "$my_time" ]; then my_time=0; fi
            ref_time=$(echo "$output" | awk '/Time taken by Lapacke dgesv/ {print $(NF-1)}')
            if [ -z "$ref_time" ]; then ref_time=0; fi
            echo "GCC8.4.0,$flag,$size,$run,$my_time,$ref_time" >> $RESULTS
        done
    done
done

echo ""
echo "All runs complete. Raw data saved to $RESULTS"
