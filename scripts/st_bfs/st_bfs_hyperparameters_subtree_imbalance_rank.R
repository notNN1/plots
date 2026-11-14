#!/usr/bin/env Rscript
# Run from the repository root: Rscript scripts/st_bfs/st_bfs_hyperparameters_subtree_imbalance_rank.R
source("R/plot_output_path.R")
source("R/imbalance_success_rate_rank_plot.R")

data_dir <- normalizePath("data/st_bfs_hyperparameters_subtree", mustWork = TRUE)
files <- sort(list.files(
    data_dir,
    pattern = "\\.origins\\.2_stbfs\\.recalculations\\.2_stbfs\\.subtree_k[0-9]+\\.csv$",
    full.names = TRUE
))
if (length(files) != 1L) {
    stop("Expected exactly one Subtree CSV with 2 origins and 2 recalculations in ",
         data_dir, "; found ", length(files), ".")
}

data <- read.csv(files[[1]], stringsAsFactors = FALSE)
if (!"K" %in% names(data) || anyNA(data$K) || length(unique(data$K)) != 1L) {
    stop("The selected CSV must contain exactly one nonmissing K value.")
}
plot <- create_imbalance_success_rate_rank_plot(
    data,
    subtitle = paste("ST_BFS Subtree | K =", unique(data$K),
                     "| Origins = 2 | Spanning tree recalculations = 2"),
    label_size = 8
)

grDevices::pdf(plot_output_path("st_bfs_subtree_origins_2_recalculations_2_imbalance_success_rank.pdf"),
    width = 16, height = max(12, .24 * nrow(data) + 2))
tryCatch(print(plot), finally = grDevices::dev.off())
