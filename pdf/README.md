# Plot folders

| Folder | Contents |
| --- | --- |
| `metric/k32/` | K = 32 metric connectivity and imbalance profiles, component counts |
| `metric/k64/` | K = 64 metric connectivity and imbalance profiles |
| `metric/` | Earlier combined metric performance profile |
| `metric/archive/` | Earlier metric PDFs from before uniform best/average selection |
| `st/` | ST options, hyperparameter grids, and success rates by graph |
| `st_bfs/` | ST_BFS options, hyperparameter grids, and Subtree success rates by graph |
| `grids/` | Standalone imbalance and total time grids |
| `examples/` | Example plots |
| `tests/` | Combined test plots |
| `misc/` | Automatically generated R plots |

Run the plotting scripts from the repository root. They create these folders
automatically and keep the original PDF filenames.

Generate metric profiles with `Rscript scripts/metric/metric_performance_profile.R` for K = 32,
or `Rscript scripts/metric/metric_performance_profile.R 64` for K = 64.

Metric PDFs end in `_best.pdf` or `_average.pdf` to identify the result type
used throughout the plot. Every metric profile run generates both versions.
Metric imbalance profiles use only `I` and `F`.
