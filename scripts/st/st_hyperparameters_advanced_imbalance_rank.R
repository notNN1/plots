#!/usr/bin/env Rscript
# Run from the repository root: Rscript scripts/st/st_hyperparameters_advanced_imbalance_rank.R
source("R/plot_output_path.R")
source("R/imbalance_success_rate_rank_plot.R")

data_dir <- normalizePath("data/st_hyperparameters_advanced", mustWork = TRUE)
files <- sort(list.files(
    data_dir,
    pattern = "\\.recalculations\\.3_k[0-9]+\\.csv$",
    full.names = TRUE
))
if (length(files) != 1L) {
    stop("Expected exactly one CSV with recalculation budget 3 in ", data_dir,
         "; found ", length(files), ".")
}

data <- read.csv(files[[1]], stringsAsFactors = FALSE)
if (!"K" %in% names(data) || anyNA(data$K) || length(unique(data$K)) != 1L) {
    stop("The selected CSV must contain exactly one nonmissing K value.")
}
plot <- create_imbalance_success_rate_rank_plot(
    data,
    subtitle = paste("K =", unique(data$K), "| Recalculation budget = 3"),
    label_size = 8
)

grDevices::pdf(plot_output_path("st_hyperparameters_advanced_recalculation_3_imbalance_success_rank.pdf"),
    width = 16, height = max(12, .24 * nrow(data) + 2))
tryCatch(print(plot), finally = grDevices::dev.off())
