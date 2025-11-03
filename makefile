# -----------------------------
# Compiler and flags
# -----------------------------
CC = gcc

# Common flags
CFLAGS = -O3 -fopenmp -ftree-vectorize -march=native -funroll-loops

# Vectorization report flags
VECFLAGS = -fopt-info-vec-optimized=vec.txt -fopt-info-vec-missed=missed.txt -fverbose-asm -ftree-vectorize -O3 -march=native

# Libraries
LDLIBS = -lopenblas

# Source files
SRC = dgesv.c timer.c main.c
OBJ = dgesv.o timer.o main.o

# -----------------------------
# Targets
# -----------------------------

# Default: build vectorized version
all: dgesv_vec

# -----------------------------
# Vectorized version
# -----------------------------
dgesv_vec: $(OBJ)
	$(CC) $(OBJ) -o $@ $(LDLIBS)

# Compile object files with vectorization report
dgesv.o: dgesv.c
	$(CC) $(CFLAGS) $(VECFLAGS) -c $< -o $@

timer.o: timer.c
	$(CC) $(CFLAGS) -c $< -o $@

main.o: main.c
	$(CC) $(CFLAGS) -c $< -o $@

# -----------------------------
# Non-vectorized version
# -----------------------------
dgesv_novec: CFLAGS_NO_VEC = -O3 -fopenmp -march=native -funroll-loops
dgesv_novec: clean_obj
	$(CC) $(CFLAGS_NO_VEC) dgesv.c timer.c main.c -o $@ $(LDLIBS)

# -----------------------------
# Clean
# -----------------------------
clean:
	$(RM) *.o dgesv_vec dgesv_novec *~ vec.txt missed.txt
	touch dgesv.c timer.c main.c  
clean_obj:
	$(RM) *.o

# -----------------------------
# Vectorization report only
# -----------------------------
vec_report: clean
	$(MAKE) dgesv_vec
	@echo "=== Vectorization report generated: vec.txt / missed.txt ==="

.PHONY: all clean clean_obj vec_report
