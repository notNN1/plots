#!/usr/bin/env Rscript
# Run from the repository root: Rscript st_bfs_hyperparameters.R
source("R/imbalance_success_grid_plot.R")

data_dirs <- c(
    "Normal" = "data/st_bfs_hyperparameters_normal",
    "Advanced" = "data/st_bfs_hyperparameters_advanced",
    "Subtree" = "data/st_bfs_hyperparameters_subtree",
    "Subtree Recalculation" = "data/st_bfs_hyperparameters_subtree_recalculation"
)
threshold <- 0.75

# Derive coordinates directly from filenames, including variants ending in _k32.
pattern <- "^.*stbfs\\.origins\\.([0-9]+)_stbfs\\.recalculations\\.([0-9]+)_.*k([0-9]+)\\.csv$"
load_layout <- function(data_dir) {
    data_dir <- normalizePath(data_dir, mustWork = TRUE)
    files <- sort(list.files(data_dir, pattern = "\\.csv$", full.names = TRUE))
    if (!length(files)) stop("No CSV files found in: ", data_dir)
    filenames <- basename(files)
    if (any(!grepl(pattern, filenames))) {
        stop("Cannot extract origins, recalculations, and K from: ",
             paste(filenames[!grepl(pattern, filenames)], collapse = ", "))
    }
    data.frame(
        filename = files,
        x = as.integer(sub(pattern, "\\2", filenames)),
        y = as.integer(sub(pattern, "\\1", filenames)),
        K = as.integer(sub(pattern, "\\3", filenames))
    )
}
layouts <- lapply(data_dirs, load_layout)

# Existing grid helpers read a layout CSV; absolute paths also work in Docker.
layout_file <- tempfile(fileext = ".csv")
plots <- tryCatch({
    grids <- list()
    for (variant in names(layouts)) {
        layout <- layouts[[variant]]
        for (k in sort(unique(layout$K))) {
            write.csv(layout[layout$K == k, c("filename", "x", "y")],
                      layout_file, row.names = FALSE)
            grids <- c(grids, list(
                create_total_time_grid_plot(layout_file) +
                    ggplot2::labs(subtitle = paste0("K = ", k, "\n", variant)),
                create_imbalance_success_grid_plot(layout_file, threshold = threshold) +
                    ggplot2::labs(subtitle = paste0("K = ", k, "\n", variant))
            ))
        }
    }
    grids
}, finally = unlink(layout_file))

grDevices::pdf("st_bfs_hyperparameters.pdf", width = 9, height = 8)
tryCatch({
    for (plot in plots) print(plot)
}, finally = grDevices::dev.off())
