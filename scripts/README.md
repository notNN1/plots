# R scripts

Run scripts from the repository root so that data and shared-function paths resolve.

| Folder | Purpose |
| --- | --- |
| `metric/` | Metric comparisons: connectivity, imbalance, and component counts |
| `st/` | ST options, hyperparameter grids, and success rates by graph |
| `st_bfs/` | ST_BFS options, hyperparameter grids, and Subtree success rates by graph |
| `grids/` | Standalone imbalance success and total time grids |
| `examples/` | Example plots and their dataset configuration (`instances.R`) |
| `setup/` | R dependency installation |

Shared plotting functions stay in `R/`. Plot and regression checks live in `tests/`.
The `mkexp.R` command entry point stays at the repository root.
Generated PDFs are organized under `pdf/`.

Examples:

```sh
docker-compose run --rm -T r Rscript scripts/metric/metric_performance_profile.R
docker-compose run --rm -T r Rscript scripts/metric/metric_performance_profile.R 64
docker-compose run --rm -T r Rscript scripts/st/st_options_imbalance.R
```

Each metric profile command generates both best and average versions of the
imbalance and connectivity profiles.
