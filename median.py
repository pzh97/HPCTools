import pandas as pd

df = pd.read_csv("dgesv_results_gcc11.csv")
my_median = df.groupby(['flag', 'size'])['my_dgesv_ms'].median().reset_index()
print("Median of my_dgesv_ms for each (flag, size) combination:")
print(my_median)
ref_median = df.groupby('size')['ref_dgesv_ms'].median().reset_index()
print("\nMedian of ref_dgesv_ms for each size (all flags combined):")
print(ref_median)
