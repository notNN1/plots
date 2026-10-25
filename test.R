#!/usr/bin/env Rscript
TEX <- FALSE

source("R/common.R")
source("R/performance_profile_plot.R")
source("R/running_time_box_plot.R")
source("R/speedup_plot.R")

source("instances.R")


# Read every CSV directly inside a folder, using filenames as algorithm names.
# Relative paths are relative to the working directory; absolute paths also work.
load_datasets_from_folder <- function(folder) {
    if (!dir.exists(folder)) {
        stop("Folder does not exist: ", folder)
    }

    folder <- normalizePath(folder, mustWork = TRUE)
    files <- sort(list.files(folder, pattern = "\\.csv$", full.names = TRUE,
                             ignore.case = TRUE))
    files <- files[!dir.exists(files)]
    if (length(files) == 0) {
        stop("No CSV files found in: ", folder)
    }

    names <- tools::file_path_sans_ext(basename(files))
    datasets <- lapply(seq_along(files), function(i) {
        load_dataset(filename = files[[i]], name = names[[i]], cache = FALSE,
                     normalizer = default_km1_normalizer)
    })
    setNames(datasets, names)
}

# Change this folder to load a different set of CSV files.
# set_tarjan      <- load_datasets_from_folder("data/tarjan vs non tarjan")
set_tarjan_obo  <- load_datasets_from_folder("data/tarjan one by one")
# set_st_bfs <- load_datasets_from_folder("data/st_bfs options")
# set_st     <- load_datasets_from_folder("data/st options")

test_set <- set_tarjan_obo

pp <- do.call(create_imbalance_performance_profile_plot,
    c(unname(test_set), list(column.objective = "AvgKM1WithoutConnectivity")))
pp_imbalance <- do.call(create_expanded_imbalance_performance_profile_plot,
    c(unname(test_set), list(column.objective = "AvgKM1WithoutConnectivity")))
pp_connectivity <- do.call(create_connectivity_performance_profile_plot,
    c(unname(test_set), list(column.objective = "AvgKM1")))

# normal pp
if (inherits(pp_imbalance, "ggplot")) pp_imbalance <- list(pp_imbalance)
pp_imbalance <- lapply(pp_imbalance, function(plot) {
    plot + ggplot2::labs(title = "Performance Profile with Imbalance Success Rate",
        x = "KM1 Ratio / Imbalance Success Rate",
        y = "Fraction of Instances") + ggplot2::theme_bw() + default_theme +
        ggplot2::theme(legend.position = "bottom")
})

# Imbalance pp
if (inherits(pp, "ggplot")) pp <- list(pp)
pp <- lapply(pp, function(plot) {
    plot +
        ggplot2::labs(title = "Performance Profile", x = "KM1 Ratio", y = "Fraction of Instances") +
        ggplot2::theme_bw() +
        default_theme +
        ggplot2::theme(legend.position = "bottom")
})

# Connectivity pp
if (inherits(pp_connectivity, "ggplot")) pp_connectivity <- list(pp_connectivity)
pp_connectivity <- lapply(pp_connectivity, function(plot) {
    plot + ggplot2::labs(title = "Performance Profile with Connectivity",
        x = "KM1 Ratio / Average Extra Components (C)", y = "Fraction of Instances") +
        ggplot2::theme_bw() + default_theme +
        ggplot2::theme(legend.position = "bottom")
})

open_pdf("tests", width = 11)
for (plot in pp) print(plot)
for (plot in pp_imbalance) print(plot)
for (plot in pp_connectivity) print(plot)
# print(pp_imbalance_tarjan)
dev_off()
