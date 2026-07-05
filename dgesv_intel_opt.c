#include "dgesv.h"
#include <math.h>

static inline void swap_row_opt(double *restrict left, double *restrict right, int len)
{
  int idx = 0;

  #pragma ivdep
  #pragma vector always
  for (; idx + 3 < len; idx += 4) {
    double temp0 = left[idx];
    double temp1 = left[idx + 1];
    double temp2 = left[idx + 2];
    double temp3 = left[idx + 3];

    left[idx] = right[idx];
    left[idx + 1] = right[idx + 1];
    left[idx + 2] = right[idx + 2];
    left[idx + 3] = right[idx + 3];

    right[idx] = temp0;
    right[idx + 1] = temp1;
    right[idx + 2] = temp2;
    right[idx + 3] = temp3;
  }

  for (; idx < len; idx++) {
    double temp = left[idx];
    left[idx] = right[idx];
    right[idx] = temp;
  }
}

static inline void update_row_opt(double *restrict target,
                                  const double *restrict pivot,
                                  int len,
                                  double factor)
{
  int idx = 0;

  #pragma ivdep
  #pragma vector always
  for (; idx + 3 < len; idx += 4) {
    target[idx] -= factor * pivot[idx];
    target[idx + 1] -= factor * pivot[idx + 1];
    target[idx + 2] -= factor * pivot[idx + 2];
    target[idx + 3] -= factor * pivot[idx + 3];
  }

  for (; idx < len; idx++) {
    target[idx] -= factor * pivot[idx];
  }
}

static inline void scale_row_opt(double *restrict row, int len, double factor)
{
  int idx = 0;

  #pragma ivdep
  #pragma vector always
  for (; idx + 3 < len; idx += 4) {
    row[idx] *= factor;
    row[idx + 1] *= factor;
    row[idx + 2] *= factor;
    row[idx + 3] *= factor;
  }

  for (; idx < len; idx++) {
    row[idx] *= factor;
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
      double *restrict row_i_b = matrix_b + i * nrhs;
      double *restrict row_max_b = matrix_b + max_row * nrhs;

      swap_row_opt(row_i_a, row_max_a, n);
      swap_row_opt(row_i_b, row_max_b, nrhs);
    }

    const double *restrict pivot_row = matrix_a + i * n;
    const double *restrict pivot_rhs = matrix_b + i * nrhs;
    double pivot_value = pivot_row[i];
    double pivot_inverse = 1.0 / pivot_value;

    for (int k = i + 1; k < n; k++) {
      double *restrict target_row = matrix_a + k * n;
      double *restrict target_rhs = matrix_b + k * nrhs;
      double factor = target_row[i] * pivot_inverse;

      target_row[i] = 0.0;
      update_row_opt(target_row + i + 1, pivot_row + i + 1, n - i - 1, factor);
      update_row_opt(target_rhs, pivot_rhs, nrhs, factor);
    }
  }

  for (int i = n - 1; i >= 0; i--) {
    const double *restrict row_a = matrix_a + i * n;
    double *restrict row_b = matrix_b + i * nrhs;

    for (int j = i + 1; j < n; j++) {
      const double *restrict solved_rhs = matrix_b + j * nrhs;
      update_row_opt(row_b, solved_rhs, nrhs, row_a[j]);
    }

    scale_row_opt(row_b, nrhs, 1.0 / row_a[i]);
  }

  return 0;
}