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
        load_dataset(filename = files[[i]], name = names[[i]], cache = FALSE)
    })
    setNames(datasets, names)
}

# Change this folder to load a different set of CSV files.
set_tarjan <- load_datasets_from_folder("data/tarjan vs non tarjan")
# set_st_bfs <- load_datasets_from_folder("data/st_bfs options")
# set_st     <- load_datasets_from_folder("data/st options")

pp_tarjan <- do.call(create_imbalance_performance_profile_plot, unname(set_tarjan)) +
    ggplot2::labs(title = "Performance Profile") +
    ggplot2::theme_bw() +
    default_theme +
    ggplot2::xlab("Ratio") +
    ggplot2::ylab("Fraction of Instances") +
    ggplot2::theme(legend.position = "bottom")

#pp_st_bfs <- do.call(create_performance_profile_plot, unname(set_st_bfs)) +
#    ggplot2::labs(title = "Performance Profile") +
#    ggplot2::theme_bw() +
#    default_theme +
#    ggplot2::xlab("Ratio") +
#    ggplot2::ylab("Fraction of Instances") +
#    ggplot2::theme(legend.position = "bottom")

#pp_connectivity_st_bfs <- do.call(create_connectivity_performance_profile_plot, unname(set_st_bfs)) +
#    ggplot2::labs(title = "Performance Profile with Connectivity",
#                  x = "Cut Ratio / Average Extra Components (C)", y = "Fraction of Instances") +
#    ggplot2::theme_bw() +
#    default_theme +
#    ggplot2::theme(legend.position = "bottom")

#pp_imbalance_st_bfs <- do.call(create_imbalance_performance_profile_plot, unname(set_st_bfs)) +
#    ggplot2::labs(title = "Performance Profile Ignoring Connectivity",
#                  x = "Ratio", y = "Fraction of Instances") +
#    ggplot2::theme_bw() +
#    default_theme +
#    ggplot2::theme(legend.position = "bottom")

open_pdf("tests", width = 11)
print(pp_tarjan)
# print(pp_connectivity_tarjan)
# print(pp_imbalance_tarjan)
dev_off()
