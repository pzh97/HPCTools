#include "dgesv.h"
#include <math.h>

static inline void swap_row(double *restrict left, double *restrict right, int len)
{
  #pragma GCC ivdep
  for (int idx = 0; idx < len; idx++) {
    double temp = left[idx];
    left[idx] = right[idx];
    right[idx] = temp;
  }
}

static inline void update_row(double *restrict target, const double *restrict pivot,
                              int len, double factor)
{
  #pragma GCC ivdep
  for (int idx = 0; idx < len; idx++) {
    target[idx] -= factor * pivot[idx];
  }
}

int my_dgesv(int n, int nrhs, double *a, double *b)
{
  double *restrict matrix_a = a;
  double *restrict matrix_b = b;

  for (int i = 0; i < n; i++) {
    int max_row = i;
    double max_val = fabs(matrix_a[i * n + i]);
    for (int k = i + 1; k < n; k++) {
      double val = fabs(matrix_a[k * n + i]);
      if (val > max_val) {
        max_val = val;
        max_row = k;
      }
    }

    if (max_row != i) {
      double *restrict row_i_a = matrix_a + i * n;
      double *restrict row_max_a = matrix_a + max_row * n;
      swap_row(row_i_a, row_max_a, n);

      double *restrict row_i_b = matrix_b + i * nrhs;
      double *restrict row_max_b = matrix_b + max_row * nrhs;
      swap_row(row_i_b, row_max_b, nrhs);
    }

    for (int k = i + 1; k < n; k++) {
      double *restrict target_row = matrix_a + k * n;
      const double *restrict pivot_row = matrix_a + i * n;
      double *restrict target_rhs = matrix_b + k * nrhs;
      const double *restrict pivot_rhs = matrix_b + i * nrhs;

      double factor = target_row[i] / pivot_row[i];
      target_row[i] = 0.0;
      update_row(target_row + i + 1, pivot_row + i + 1, n - i - 1, factor);

      update_row(target_rhs, pivot_rhs, nrhs, factor);
    }
  }

  for (int rhs = 0; rhs < nrhs; rhs++) {
    for (int i = n - 1; i >= 0; i--) {
      const double *restrict row_a = matrix_a + i * n;
      double sum = matrix_b[i * nrhs + rhs];
      for (int j = i + 1; j < n; j++) {
        sum -= row_a[j] * matrix_b[j * nrhs + rhs];
      }
      matrix_b[i * nrhs + rhs] = sum / row_a[i];
    }
  }

  return 0;
}