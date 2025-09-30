#include "dgesv.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define check_fabs(a) (((a) < 0) ? -(a) : (a))

int my_dgesv(int n, int nrhs, double *a, double *b)
{
  for (int i = 0; i < n; i++) {
    int max_row = i;
    double max_val = check_fabs(a[i * n + i]);
    for (int k = i + 1; k < n; k++) {
      double val = check_fabs(a[k * n + i]);
      if (val > max_val) {
        max_val = val;
        max_row = k;
      }
    }

    if (max_row != i) {
      for (int j = 0; j < n; j++) {
        double temp = a[i * n + j];
        a[i * n + j] = a[max_row * n + j];
        a[max_row * n + j] = temp;
      }

      for (int rhs = 0; rhs < nrhs; rhs++) {
        double temp = b[i * nrhs + rhs];
        b[i * nrhs + rhs] = b[max_row * nrhs + rhs];
        b[max_row * nrhs + rhs] = temp;
      }
    }

    for (int k = i + 1; k < n; k++) {
      double factor = a[k * n + i] / a[i * n + i];
      a[k * n + i] = 0.0; 

      for (int j = i + 1; j < n; j++) {
        a[k * n + j] -= factor * a[i * n + j];
      }

      for (int rhs = 0; rhs < nrhs; rhs++) {
        b[k * nrhs + rhs] -= factor * b[i * nrhs + rhs];
      }
    }
  }

  for (int rhs = 0; rhs < nrhs; rhs++) {
    for (int i = n - 1; i >= 0; i--) {
      double sum = b[i * nrhs + rhs];
      for (int j = i + 1; j < n; j++) {
        sum -= a[i * n + j] * b[j * nrhs + rhs];
      }
      b[i * nrhs + rhs] = sum / a[i * n + i];
    }
  }

  return 0;
}
