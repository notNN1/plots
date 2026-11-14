#!/usr/bin/env Rscript
# Run from the repository root: Rscript scripts/st_bfs/st_bs_options.R
source("R/plot_output_path.R")
source("R/common.R")
source("R/performance_profile_plot.R")

data_dir <- normalizePath("data/st_bs_options", mustWork = TRUE)
csv_files <- c(
    "Normal" = "do_nothing_ip.stbfs_no.refinement_stbfs.normal_stbfs.origins.2_stbfs.recalculations.2_k32.csv",
    "Advanced" = "do_nothing_ip.stbfs_no.refinement_stbfs.advanced_stbfs.origins.2_stbfs.recalculations.2_k32.csv",
    "Subtree" = "do_nothing_ip.stbfs_no.refinement_stbfs.origins.2_stbfs.recalculations.2_stbfs.subtree_k32.csv",
    "Subtree Recalculation" = "do_nothing_ip.stbfs_no.refinement_stbfs.origins.2_stbfs.recalculations.2_stbfs.subtree.recalculation_k32.csv"
)

datasets <- lapply(names(csv_files), function(name) {
    load_dataset(
        filename = file.path(data_dir, csv_files[[name]]),
        name = name,
        normalizer = default_km1_normalizer,
        cache = FALSE
    )
})

# Standard KM1-ratio profile with categorical C, I, T, and F markers.
profiles <- do.call(create_performance_profile_plot,
    c(datasets, list(
        column.objective = "AvgKM1",
        levels = names(csv_files),
        plot.xlab = "KM1 Ratio",
        plot.ylab = "Fraction of Instances",
        legend.title = NULL,
        tex = FALSE
    )))
if (inherits(profiles, "ggplot")) profiles <- list(profiles)
profiles <- lapply(profiles, function(plot) {
    plot + ggplot2::labs(title = "Performance Profile")
})

# Constraint-only profile: fraction of instances meeting each success-rate threshold.
imbalance_profiles <- do.call(create_imbalance_success_profile_plot,
    c(datasets, list(
        levels = names(csv_files),
        plot.xlab = "Imbalance Success Rate",
        plot.ylab = "Fraction of Instances",
        legend.title = NULL,
        tex = FALSE
    )))
if (inherits(imbalance_profiles, "ggplot")) imbalance_profiles <- list(imbalance_profiles)
imbalance_profiles <- lapply(imbalance_profiles, function(plot) {
    plot + ggplot2::labs(title = "Imbalance Success Rate Profile")
})

profiles <- lapply(c(profiles, imbalance_profiles), function(plot) {
    plot + default_theme +
        ggplot2::theme(
            legend.position = "bottom",
            axis.title = ggplot2::element_text(size = 14),
            plot.title = ggplot2::element_text(size = 18, hjust = 0.5)
        )
})

grDevices::pdf(plot_output_path("st_bs_options.pdf"), width = 11, height = 7)
tryCatch({
    for (plot in profiles) print(plot)
}, finally = grDevices::dev.off())
