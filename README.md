# Plotting scripts

`mkexp.R` is the single mkexp2 entry point for this submodule:

```sh
./mkexp.R plot [--list] [--json]
./mkexp.R plot [--plot <id>]... [--threads T|NxMxT] [--output plots.pdf] <source>...
./mkexp.R stats [--results results] [--json]
```

Reusable plotting and stats code lives in `R/`. The old mkexp2 stats backend is
now `R/stats.R`, centered on `create_stats_summary(..., results_dir = "results")`.

Place standalone example `*.csv` files in `data/` and load them in
`instances.R`. Result files should include at least `Graph`, `K`, `Cut`,
`Imbalance`, and `Time`; optional columns include `Seed`, `Epsilon`, `Threads`,
`Cores`, `Failed`, and `Timeout`. Run `make example-pdf` or `make example-tex`
to generate example plots.

Connectivity-aware CSVs can use this header:

```csv
Graph,K,Cut,Time,Imbalance,Connectivity,FailedImbalance,FailedConnectivity,Failed
```

`Connectivity` is a nonnegative number (including fractional averages) of unnecessary components in the
resulting partitioning: zero satisfies the constraint; any positive count violates
it. `FailedImbalance` and `FailedConnectivity` are optional 0/1 flags. They are
combined with violations derived from `Imbalance > Epsilon` and `Connectivity > 0`.
Keep `Failed` for execution failures and `Timeout` for timeouts. Old CSVs without
connectivity columns assume zero unnecessary components; existing data is not
rewritten because connectivity counts cannot be recovered from the old columns.

Constraint-violating runs are excluded from the feasible objective average. Across
repeated runs, an instance with a feasible run remains feasible. If all runs violate
connectivity, it belongs to C; otherwise an instance with no feasible objective
belongs to I (unless it is an execution failure or timeout). The normalized
`Connectivity` column stores the minimum count across runs; `AvgConnectivity`
stores the mean across completed runs (excluding execution failures and timeouts).

All plot functions accept `tex = FALSE` by default. With `tex = FALSE`, labels
are plain text such as `10^2`, `%`, and `(P)`. Pass `tex = TRUE` when rendering
through TikZ/LaTeX and you want labels such as `$10^2$`, `\\%`, or symbolic
timeout/imbalance/failure markers.

## Plot Function Reference

Most comparison plots take normalized matrix/result data frames through `...`.
The normal entry point for turning raw mkexp2 CSVs into those data frames is
`load_dataset()` from `R/common.R`.

All performance-profile plot functions split input datasets by the CSV's
`K` column. Each K is compared independently and needs at least two datasets;
undersupplied K values are skipped with a warning. If none qualify, plotting stops
with an error. Graph keys must still match within each K. A single qualifying K
returns one ggplot; multiple K values return a named list of ggplots, one per K.
`test.R` prints each qualifying K on its own PDF page. Datasets containing several
K values are supported too.

### `create_performance_profile_plot(...)`

Performance profile over at least two algorithms. Each curve shows the fraction
of common instances solved within a ratio of the best objective.
Set `column.reference` to compare against a fixed reference column instead.
The metric Connectivity profile uses `column.reference = "K"`, giving
`(K + AvgConnectivity) / K` against the best achievable component count.

Required columns default to `Algorithm`, `AvgCut`, `Timeout`, `Imbalanced`,
`Failed`, and primary key `Graph`, `K`. Optional `FailedConnectivity` defaults
to false for legacy normalized inputs. The normal profile adds connectivity
violations at **C**, then the remaining imbalance violations at **I**, followed
by **T** (timeout) and **F** (execution failure). Connectivity takes precedence
when both constraints are violated. Key arguments include `segments`,
`segment.errors.width`, `column.connectivity`, `label.connectivity`,
`label.timeout`, `label.imbalanced`, `label.failed`, `colors`, `levels`,
`axis.y.sparse_labels`, `plot.xlab`, `plot.ylab`, `legend.title`, and `tex`.

`create_performance_profile_data(...)` returns sampled profile data with the
same category thresholds.

### `create_connectivity_performance_profile_plot(...)`

The expanded variant replaces C with a linear scale of average extra components.
The scale runs from 0 to 10 extra components. Larger values are counted at a
separate **> 10 C** marker, followed by I, T, and F.
At value x, the curve includes feasible instances plus connectivity violations
with `AvgConnectivity <= x`. Instances also violating imbalance are counted in
this section; the remaining imbalance violations are added at I.

It reserves `segment.errors.width = 3` for the overflow and error labels.
It accepts the normal profile options plus `segment.connectivity.width`
(default 4), `segment.connectivity.gap` (default 1, an unmeasured horizontal gap
before C: 0), and `column.components` (default `AvgConnectivity`). Connectivity
violations require finite nonnegative severity values. `test.R` writes the normal
profile, expanded profile, and imbalance-only profile as separate pages in the same PDF.

### `create_imbalance_performance_profile_plot(...)`

Ignores connectivity and compares cuts using imbalance-valid completed runs.
Only **I** (imbalance violation) and **F** (timeout OR execution failure) appear.
Instances violating both connectivity and imbalance still count at I. The loader
provides `AvgCutWithoutConnectivity` and `ImbalancedWithoutConnectivity` for this
version; other options match the normal profile.

### `create_expanded_imbalance_performance_profile_plot(...)`

Adds an expanded I scale to the imbalance-only profile, ignoring connectivity.
It uses `ImbalanceSuccessRate` (a fraction between 0 and 1), with descending
thresholds < 0.75, 0.50, 0.25, and 0.0. At threshold s the curve includes
completed instances whose success rate is at least s. Instances with success rate at least 0.75 remain in the KM1-ratio section
when otherwise feasible.
Instances that never satisfy imbalance enter at 0.0. Timeouts and execution
failures appear at F.

Options include `column.success.rate` (default `ImbalanceSuccessRate`),
`segment.imbalance.width` (4), and `segment.imbalance.gap` (1).
The loader retains both success-rate columns, averaging completed repeats.
When supplied, success rates below 0.75 determine imbalance violations for all
profiles, overriding average imbalance and explicit imbalance flags. Exactly 0.75
is accepted. Legacy CSVs without success rates retain their prior constraint rules.
Missing success rates are not inferred from average imbalance or failure flags.
`test.R` adds these profiles as separate PDF pages for each K.

### `create_imbalance_success_rate_rank_plot(data, ...)`

Creates a horizontal bar chart with one row per graph, sorted by
`ImbalanceSuccessRate` ascending (lowest rate at the top). The input must contain
unique graph names and finite success rates between 0 and 1. The
`st_hyperparameters_advanced_imbalance_rank.R` script applies it to the CSV with
recalculation budget 3.
`st_bfs_hyperparameters_subtree_imbalance_rank.R` creates the same chart for
ST_BFS Subtree with 2 origins and 2 spanning tree recalculations.

### `create_expanded_connectivity_performance_profile_plot(...)`

Uses `ConnectivitySuccessRate` on the same descending scale as the expanded
imbalance profile: C: < 0.75, 0.50, 0.25, 0.0, followed by I for imbalance and F for execution
failures and timeouts. Connectivity violations take precedence when both constraints fail. Exactly 0.75 remains in the objective-ratio section.
The success rate overrides connectivity flags; imbalance uses
`column.imbalanced` (default `ImbalancedWithoutConnectivity`).
The objective defaults to `AvgCutWithoutConnectivity`; use
`column.objective = "AvgKM1WithoutConnectivity"` for KM1 data, matching the
imbalance-success comparison. This objective still uses imbalance-valid runs.
Completed instances require finite success rates between 0 and 1.
Customize `column.success.rate`, `segment.connectivity.width` (4), and
`segment.connectivity.gap` (1). `test.R` includes a separate page for each K.

### `create_running_time_box_plot(...)`

Per-instance running-time box plot per algorithm, with optional failure,
timeout, and imbalance ticks above the log-scaled timing range.

Required columns default to `Algorithm`, `AvgTime`, `Timeout`, `Imbalanced`,
`Failed`, and primary key `Graph`, `K`. Key arguments: `exclude.imbalanced`,
`tick.timeout`, `tick.imbalanced`, `tick.failed`, `tick.errors.space_below`,
`tick.errors.space_between`, `label.timeout`, `label.imbalanced`,
`label.failed`, `colors`, `levels`, `annotate`, `annotate.position`,
`position.y`, `plot.xlab`, `plot.ylab`, `tex`.

### `create_running_time_by_core_box_plot(...)`

Running-time distributions grouped by core count and algorithm.

Required columns default to `Algorithm`, `Cores`, `AvgTime`, `Timeout`,
`Imbalanced`, `Failed`, and primary key `Graph`, `K`, `Epsilon`, `Cores`. Key
arguments: `exclude.imbalanced`, `colors`, `levels`, `annotate`,
`annotate.position`, `plot.xlab`, `plot.ylab`, `tex`.

### `create_relative_by_graph_grid_plot(...)`

Per-graph bar grid for relative cut or running time against a baseline.

Pass `baseline = <df>` and compared data frames through `...`. Required columns
default to `Algorithm`, `Graph`, `Cores`, `AvgCut` or `AvgTime`, and primary key
`Graph`, `K`, `Epsilon`, `Cores`. Key arguments: `metric = c("cut", "time")`,
`colors`, `levels`, `plot.xlab`, `plot.ylab`, `y.breaks`, `tex`.

### `create_speedup_plot(...)`

Speedup or slowdown profile against a baseline algorithm.

Pass `baseline = <df>` and compared data frames through `...`. Required columns
default to `Algorithm`, `AvgTime`, `Timeout`, `Failed`, and primary key `Graph`,
`K`. Key arguments: `fails.show`, `y.cap`, `colors`, `levels`,
`mode = c("speedup", "slowdown")`, `x.by`, `tex`.

### `create_core_speedup_plot(df)`

Single-algorithm speedup over larger core counts, using the smallest available
core count as the baseline.

Required columns default to `Algorithm`, `Cores`, `AvgTime`, and primary key
`Graph`, `K`, `Epsilon`. Key arguments: `colors`, `tex`.

### `create_imbalance_plot(...)`

Jitter plot of rows whose `MinImbalance` exceeds `Epsilon`.

Required columns are `Algorithm`, `MinImbalance`, and `Epsilon`. Key arguments:
`colors`, `levels`, `annotation`, `annotate.counts`, `tex`.

### `create_per_k_relcut_plot(...)`

Geometric-mean relative cut by `K` against a baseline.

Pass `baseline = <df>` and compared data frames through `...`. Required columns
include `Algorithm`, `Graph`, `K`, `AvgRealCut`, and `Failed`. Key arguments:
`partial`, `colors`, `levels`, `ks`, `tex`.

### `create_per_k_reltime_plot(...)`

Geometric-mean relative speedup or slowdown by `K` against a baseline.

Pass `baseline = <df>` and compared data frames through `...`. Required columns
include `Algorithm`, `Graph`, `K`, `AvgTime`, `Failed`, and `Timeout`. Key
arguments: `relation`, `partial`, `colors`, `levels`, `ks`, `tex`.

### `create_scalability_plot(data)`

Strong-scaling speedup curves over sequential running time for one algorithm.

Required columns include `Graph`, `K`, `Cores`, and `AvgTime` by default. Key
arguments: `column.time`, `colors`, `mean = c("Gmean", "Hmean")`, `scale_x`,
`scale_y`, `tex`.

### `create_time_per_edge_plot(...)`

Rolling time per edge over graph size.

Required columns default to `Algorithm`, `AvgTime`, `Timeout`, `Failed`, `M`,
and primary key `Graph`, `K`. Key arguments: `window_size`, `points`, `colors`,
`levels`, `tex`.

### `create_strong_scaling_time_per_edge_plot(...)`

Strong-scaling time per edge over compute nodes.

Required columns include `Algorithm`, `Nodes`, `AvgM`, `MinTime`, `AvgTime`,
`MaxTime`, `Failed`, `Timeout`, and `Imbalanced`. Key arguments: `colors`,
`levels`, `plot.title`, `plot.xlab`, `plot.ylab`, `y_labels`, `max_nodes`,
`mark_feasibility`, `tex`.

### `create_multinode_time_per_edge_plot(...)`

Time per edge over graph size for multinode experiments.

Required columns include `Algorithm`, `Graph`, `AvgM`, `MinTime`, `AvgTime`,
`MaxTime`, `Failed`, `Timeout`, and `Imbalanced`. Key arguments: `colors`,
`levels`, `plot.title`, `debug`, `y_labels`, `plot.xlab`, `plot.ylab`, `tex`.

### `create_smallk_throughput_plot(...)`

Small-k throughput over compute nodes, grouped by average degree.

Required columns include `Algorithm`, `Nodes`, `AvgN`, `AvgM`, `MinTime`,
`AvgTime`, `MaxTime`, `Failed`, `Timeout`, and `Imbalanced`. Key arguments:
`colors`, `levels`, `plot.title`, `debug`, `plot.xlab`, `plot.ylab`, `tex`.

### `create_smallk_multigraph_throughput_plot(...)`

Small-k throughput over compute nodes with graph-specific line types.

Required columns are the same as `create_smallk_throughput_plot()`, plus `Graph`.
Key arguments: `colors`, `levels`, `plot.title`, `debug`, `plot.xlab`,
`plot.ylab`, `mark_feasibility`, `tex`.

### `create_largek_throughput_plot(...)`

Large-k throughput over compute nodes, grouped by vertices per block.

Required columns include `Algorithm`, `Graph`, `Nodes`, `AvgN`, `AvgM`,
`MinTime`, `AvgTime`, `MaxTime`, `K`, `Failed`, `Timeout`, and `Imbalanced`.
Key arguments: `colors`, `levels`, `plot.xlab`, `plot.ylab`, `plot.title`,
`tex`.

### `create_memory_bar_plot(...)`

Grouped peak-memory bars per graph.

Required columns default to `Name`, `Algorithm`, and `AvgMaxHeap`; rows are
aligned by primary key `Graph`, `K`. Key arguments: `column.graph`,
`column.memory`, `column.algorithm`, `column.failed`, `colors`, `namer`,
`levels`, `plot.xlab`, `plot.ylab`, `tex`.

### `create_relative_running_time_bar_plot(...)`

Grouped per-graph running-time bars relative to a baseline.

Pass `baseline = <df>` and compared data frames through `...`. Required columns
default to `Name`, `Algorithm`, `AvgTime`, `Timeout`, `Failed`, and primary key
`Graph`, `K`. Key arguments: `namer`, `colors`, `levels`, `plot.xlab`,
`plot.ylab`, `tex`.

### `create_relative_memory_plot(baseline, via_heap, via_rss)`

Relative peak-memory curves against a baseline.

Pass comparison data frames through `via_heap` and/or `via_rss` lists. Required
columns default to `Algorithm`, `AvgMaxHeap`, `AvgMaxRSS`, `Failed`, `M`, and
`PlotPerInstance`; rows are aligned by primary key `Graph`, `K`. Key arguments:
`window_size`, `namer`, `colors`, `levels`, `plot.xlab`, `plot.ylab`, `tex`.

### `create_running_time_breakdown_plot(data, cols)`

Stacked bar chart for timing-component breakdowns.

Required columns are the graph column, the timing component columns in `cols`,
and optionally a total-time column. Key arguments: `column.graph`,
`column.total_time`, `column.remaining_time`, `normalize`, `tex`.

### `create_dummy_plot(...)` and `create_standalone_legend(...)`

Legend utilities. `create_dummy_plot()` builds a plot that only carries an
algorithm legend. `create_standalone_legend()` renders that legend to TikZ. Key
arguments: `colors`, `levels`, `title`, `basename`, `nrow`, `position`,
`suffix`, `tex`.

`test.R` uses numeric `Km1` from each CSV for all three profiles.
Its loader uses `default_km1_normalizer()`, exposing `AvgKM1` for the
connectivity profile and `AvgKM1WithoutConnectivity` for profiles ignoring
connectivity. The existing feasibility and repeated-run averaging rules apply.
Every CSV in the loaded folders must include `Km1`; there is no cut fallback.

### Imbalance success-rate grid

Run `source("imbalance_success_grid.R")` to create `imbalance_success_grid.pdf`.
Edit `data/imbalance_success_grid_layout.csv` to associate each CSV with integer
`x,y` coordinates. Paths are relative to the layout file; larger y appears higher.
Each filename and coordinate pair must be unique. The layout uses the CSVs in `data/st_bfs options`, with x set to the number
of spanning tree recalculations and y set to the number of BFS origins.
Each square shows the fraction of completed graph rows with
`ImbalanceSuccessRate < threshold` (excluding failures and timeouts), rounded to two
decimal places. The default threshold is 0.75; equality is not counted.
Set `imbalance_grid_threshold` in `test.R`, or pass it directly:

```r
create_imbalance_success_grid_plot("data/imbalance_success_grid_layout.csv", threshold = 0.9)
```

The standalone `imbalance_success_grid.R` script exposes a `threshold` variable.
Thresholds must be between 0 and 1; the legend shows the configured value.
A file without completed rows displays NA. Unassigned positions remain empty.

The x axis is labeled "Number of Spanning Tree Recalculations per BFS" and the
y axis "Number of BFS Origins".
Tile colors range from blue (0) to white (0.5) to red (1).
The title is "Imbalance Grid". The legend is labeled "Below Threshold (0.75)"
and appears below the grid.

Grid lines stay at integer boundaries; cells and axis numbers are centered between them.

### Total-time grid

`create_total_time_grid_plot(layout_file)` uses the same coordinates and styling
as the imbalance grid. Each square shows `sum(Time)` for the corresponding CSV,
in seconds, rounded to integers for display. All recorded rows contribute, including failed
runs and timeouts. Missing, negative, or nonfinite times are rejected to avoid
reporting an incomplete total. Colors run from blue (shorter) to red (longer).
The legend uses five evenly spaced labels and rounds its upper limit up to a multiple of 100.
The plot sums the recorded values; if CSV times are averages of repeats, it sums
those averages.

`test.R` adds this grid after the imbalance grid. Run `source("total_time_grid.R")`
to save it separately as `total_time_grid.pdf`.

### Constraint-only profiles (no quality comparison)

`create_imbalance_success_profile_plot(...)` and
`create_connectivity_success_profile_plot(...)` show the cumulative fraction of
instances with success rate at least the x-axis threshold, from **100% to 0%**.
Each uses its own success-rate column and ignores the other constraint. Completed
instances require rates between 0 and 1. Timeouts and execution failures enter
at **F**, regardless of their recorded rates.

`create_extra_components_profile_plot(...)` shows average extra components from
**0 to 10**, followed by **> 10 C**, **I**, and **F**. As in the expanded
connectivity performance profile, positive component counts take precedence over
imbalance; completed zero-component instances violating imbalance enter at I.
It uses `AvgConnectivity` and `ImbalancedWithoutConnectivity` by default.
Timeouts and execution failures both enter at F.

These functions require no objective columns and retain the per-K comparison,
matching graph keys, colors, levels, and plain-text/TeX label support. Customize
`column.success.rate`, `column.components`, or `column.imbalanced` as appropriate.
`test.R` appends all three variants as separate pages for each qualifying K.
