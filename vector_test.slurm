#!/bin/bash
#SBATCH --job-name=vec_dgesv
#SBATCH --output=vec_dgesv_%j.out
#SBATCH --error=vec_dgesv_%j.err
#SBATCH --time=00:10:00
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=2G

# -----------------------------
# Load modules
# -----------------------------
module --force purge
module load cesga/2020
module load gcc/system
module load openblas

echo "=== Building vectorized version ==="
make clean
make vec_report

echo "=== Building non-vectorized version ==="
make dgesv_novec

echo "=== Running vectorized version ==="
time ./dgesv_vec 2048 1

echo "=== Running non-vectorized version ==="
time ./dgesv_novec 2048 1

echo "=== Vectorization reports ==="
echo "=== Optimized (vectorized) loops ==="
head -n 20 vec.txt || echo "No vec.txt found"

echo "=== Missed (non-vectorized) loops ==="
head -n 20 missed.txt || echo "No missed.txt found"

echo "=== Job complete ==="
