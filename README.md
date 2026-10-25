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
The scale runs from 1 to 3 times each instance's allowed imbalance (`Epsilon`).
For example, average imbalance 0.06 with epsilon 0.03 appears at 2 epsilon.
Violations above 3 epsilon appear at a separate **I>3 epsilon** marker after
this scale; timeouts and execution failures still appear at **F**.
Explicit violation flags below epsilon appear at the start of the I scale.

Like the extra-components profile, the scale has a gap before zero and ends at exactly
3 epsilon. Options include `column.imbalance`
(default `AvgImbalance`), `column.epsilon` (default `Epsilon`),
`segment.imbalance.width` (4), and `segment.imbalance.gap` (1).
Active imbalance violations require finite numeric measurements and thresholds.
`test.R` adds these profiles as separate PDF pages for each K.

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
