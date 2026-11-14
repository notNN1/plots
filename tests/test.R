#!/usr/bin/env Rscript
TEX <- FALSE

source("R/common.R")
source("R/performance_profile_plot.R")
source("R/imbalance_success_grid_plot.R")
source("R/running_time_box_plot.R")
source("R/speedup_plot.R")

source("scripts/examples/instances.R")


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
# set_tarjan_obo  <- load_datasets_from_folder("data/tarjan one by one")
set_st_bfs <- load_datasets_from_folder("data/st_bfs options")
set_st     <- load_datasets_from_folder("data/st options")

test_set <- set_st_bfs

pp <- do.call(create_imbalance_performance_profile_plot,
    c(unname(set_st), list(column.objective = "AvgKM1WithoutConnectivity")))
pp_imbalance <- do.call(create_expanded_imbalance_performance_profile_plot,
    c(unname(set_st), list(column.objective = "AvgKM1WithoutConnectivity")))
pp_connectivity <- do.call(create_connectivity_performance_profile_plot,
    c(unname(set_st), list(column.objective = "AvgKM1")))

pp_connectivity_success <- do.call(create_expanded_connectivity_performance_profile_plot,
    c(unname(set_st), list(column.objective = "AvgKM1WithoutConnectivity")))

# normal pp
if (inherits(pp_imbalance, "ggplot")) pp_imbalance <- list(pp_imbalance)
pp_imbalance <- lapply(pp_imbalance, function(plot) {
    plot + ggplot2::labs(title = "Performance Profile with Imbalance Success Rate",
        x = "KM1 Ratio / Imbalance Success Rate",
        y = "Fraction of Instances") + ggplot2::theme_bw() + default_theme +
        ggplot2::theme(legend.position = "bottom",
            axis.title.x = ggplot2::element_text(size = 14,
                margin = ggplot2::margin(t = 10)),
            axis.title.y = ggplot2::element_text(size = 14),
            plot.title = ggplot2::element_text(size = 18, hjust = .5,
                margin = ggplot2::margin(t = 16, b = 8)))
})

if (inherits(pp_connectivity_success, "ggplot")) pp_connectivity_success <- list(pp_connectivity_success)
pp_connectivity_success <- lapply(pp_connectivity_success, function(plot) {
    plot + ggplot2::labs(title = "Performance Profile with Connectivity Success Rate",
        x = "KM1 Ratio / Connectivity Success Rate",
        y = "Fraction of Instances") + ggplot2::theme_bw() + default_theme +
        ggplot2::theme(legend.position = "bottom",
            axis.title.x = ggplot2::element_text(size = 14,
                margin = ggplot2::margin(t = 10)),
            axis.title.y = ggplot2::element_text(size = 14),
            plot.title = ggplot2::element_text(size = 18, hjust = .5,
                margin = ggplot2::margin(t = 16, b = 8)))
})

# Imbalance pp
if (inherits(pp, "ggplot")) pp <- list(pp)
pp <- lapply(pp, function(plot) {
    plot +
        ggplot2::labs(title = "Performance Profile", x = "KM1 Ratio", y = "Fraction of Instances") +
        ggplot2::theme_bw() +
        default_theme +
        ggplot2::theme(legend.position = "bottom",
            axis.title.x = ggplot2::element_text(size = 14,
                margin = ggplot2::margin(t = 10)),
            axis.title.y = ggplot2::element_text(size = 14),
            plot.title = ggplot2::element_text(size = 18, hjust = .5,
                margin = ggplot2::margin(t = 16, b = 8)))
})

# Connectivity pp
if (inherits(pp_connectivity, "ggplot")) pp_connectivity <- list(pp_connectivity)
pp_connectivity <- lapply(pp_connectivity, function(plot) {
    plot + ggplot2::labs(title = "Performance Profile with Connectivity",
        x = "KM1 Ratio / Average Extra Components (C)", y = "Fraction of Instances") +
        ggplot2::theme_bw() + default_theme +
        ggplot2::theme(legend.position = "bottom",
            axis.title.x = ggplot2::element_text(size = 14,
                margin = ggplot2::margin(t = 10)),
            axis.title.y = ggplot2::element_text(size = 14),
            plot.title = ggplot2::element_text(size = 18, hjust = .5,
                margin = ggplot2::margin(t = 16, b = 8)))
})

# Constraint-only profiles, without a quality-ratio section.
constraint_profiles <- list(
    list(create_imbalance_success_profile_plot, "Imbalance Success Rate Profile", "Imbalance Success Rate"),
    list(create_connectivity_success_profile_plot, "Connectivity Success Rate Profile", "Connectivity Success Rate"),
    list(create_extra_components_profile_plot, "Extra Components Profile", "Average Extra Components (C)"))
pp_constraints <- lapply(constraint_profiles, function(spec) {
    plots <- do.call(spec[[1]], unname(set_st))
    if (inherits(plots, "ggplot")) plots <- list(plots)
    lapply(plots, function(plot) plot +
        ggplot2::labs(title = spec[[2]], x = spec[[3]], y = "Fraction of Instances") +
        ggplot2::theme_bw() + default_theme +
        ggplot2::theme(legend.position = "bottom",
            axis.title = ggplot2::element_text(size = 14),
            plot.title = ggplot2::element_text(size = 18, hjust = .5)))
})

# Only graph success rates strictly below this value count in the imbalance grid.
imbalance_grid_threshold <- 1
imbalance_grid <- create_imbalance_success_grid_plot(
    "data/imbalance_success_grid_layout.csv", threshold = imbalance_grid_threshold)
total_time_grid <- create_total_time_grid_plot("data/imbalance_success_grid_layout.csv")

open_pdf("tests", width = 11)
for (plot in pp) print(plot)
for (plot in pp_imbalance) print(plot)
for (plot in pp_connectivity) print(plot)
for (plot in pp_connectivity_success) print(plot)
for (profiles in pp_constraints) for (plot in profiles) print(plot)
print(imbalance_grid)
print(total_time_grid)
# print(pp_imbalance_tarjan)
dev_off()
