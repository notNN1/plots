#!/usr/bin/env Rscript
# Run from the repository root: Rscript scripts/metric/metric_performance_profile.R
# For K = 64: Rscript scripts/metric/metric_performance_profile.R 64
source("R/plot_output_path.R")
source("R/common.R")
source("R/metric_imbalance_normalizer.R")
source("R/performance_profile_plot.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L || (length(args) == 1L && !grepl("^[1-9][0-9]*$", args[[1]]))) {
    stop("Usage: Rscript scripts/metric/metric_performance_profile.R [K]")
}
k <- if (length(args)) as.integer(args[[1]]) else 32L
output_suffix <- if (k == 32L) "" else paste0("_k", k)

data_dir <- normalizePath("data/metric", mustWork = TRUE)

csv_files <- c(
    "Refinement + New Metric" = "do_nothing_ip.standard_k32.csv",
    "No Refinement + New Metric" = "ip.standard_no.refinement_k32.csv",
    "No Refinement + Old Metric" = "ip.standard_no.refinement_old.metric_k32.csv",
    "Refinement + Old Metric" = "do_nothing_ip.standard_old.metric_k32.csv"
)
csv_files <- sub("_k32\\.csv$", paste0("_k", k, ".csv"), csv_files)

load_metric_datasets <- function(normalizer, mode) lapply(names(csv_files), function(name) {
    load_dataset(
        filename = file.path(data_dir, csv_files[[name]]),
        name = name,
        normalizer = function(df, ...) normalizer(df, value_mode = mode, ...),
        cache = FALSE
    )
})
write_profile_pdf <- function(filename, plots) {
    grDevices::pdf(plot_output_path(filename), width = 11, height = 7)
    tryCatch({
        for (plot in plots) print(plot)
    }, finally = grDevices::dev.off())
}

for (value_mode in c("best", "average")) {
    datasets <- load_metric_datasets(function(df, value_mode, ...) {
        default_km1_normalizer(select_result_values(df, value_mode), ...)
    }, value_mode)
    imbalance_datasets <- load_metric_datasets(metric_imbalance_normalizer, value_mode)

    imbalance_profiles <- do.call(create_imbalance_performance_profile_plot,
        c(imbalance_datasets, list(
            column.objective = "AvgKM1WithoutConnectivity",
            column.imbalanced = "ImbalancedWithoutConnectivity",
            levels = names(csv_files),
            plot.xlab = "Connectivity Ratio",
            plot.ylab = "Fraction of Instances",
            legend.title = NULL,
            tex = FALSE
        )))
    if (inherits(imbalance_profiles, "ggplot")) imbalance_profiles <- list(imbalance_profiles)
    imbalance_profiles <- lapply(imbalance_profiles, function(plot) {
        plot + ggplot2::labs(title = NULL, subtitle = NULL) +
            default_theme +
            ggplot2::theme(
                legend.position = "bottom",
                axis.title.x = ggplot2::element_text(size = 14),
                axis.title.y = ggplot2::element_text(size = 14),
                axis.text.x = ggplot2::element_text(size = 12),
                axis.text.y = ggplot2::element_text(size = 12),
                legend.text = ggplot2::element_text(size = 16),
                plot.subtitle = ggplot2::element_text(size = 16, hjust = 0.5),
                plot.title = ggplot2::element_text(size = 16, hjust = 0.5)
            ) +
            ggplot2::guides(color = ggplot2::guide_legend(title = NULL, nrow = 2, byrow = TRUE))
    })

    connectivity_datasets <- lapply(datasets, function(df) {
        component_count <- df$K + df$AvgConnectivity
        if (!is.numeric(component_count) || any(!is.finite(component_count) &
                                               !df$Failed & !df$Timeout)) {
            stop("Connectivity component counts must be finite for completed instances.")
        }
        component_count[df$Failed | df$Timeout] <- df$K[df$Failed | df$Timeout]
        df$ConnectivityComponentCount <- component_count
        df$ConnectivityProfileFailed <- as.logical(df$Failed) | as.logical(df$Timeout)
        df$ConnectivityProfileImbalanced <- df$ImbalanceSuccessRate < .75
        df
    })

    connectivity_profiles <- do.call(create_imbalance_performance_profile_plot,
        c(connectivity_datasets, list(
            column.objective = "ConnectivityComponentCount",
            column.reference = "K",
            column.failed = "ConnectivityProfileFailed",
            column.imbalanced = "ConnectivityProfileImbalanced",
            levels = names(csv_files),
            plot.xlab = "Component Ratio",
            plot.ylab = "Fraction of Instances",
            legend.title = NULL,
            tex = FALSE
        )))
    if (inherits(connectivity_profiles, "ggplot")) connectivity_profiles <- list(connectivity_profiles)
    connectivity_profiles <- lapply(connectivity_profiles, function(plot) {
        plot + ggplot2::labs(title = NULL, subtitle = NULL) +
            default_theme +
            ggplot2::theme(
                legend.position = "bottom",
                axis.title.x = ggplot2::element_text(size = 14),
                axis.title.y = ggplot2::element_text(size = 14),
                axis.text.x = ggplot2::element_text(size = 12),
                axis.text.y = ggplot2::element_text(size = 12),
                legend.text = ggplot2::element_text(size = 16),
                plot.subtitle = ggplot2::element_text(size = 16, hjust = 0.5),
                plot.title = ggplot2::element_text(size = 16, hjust = 0.5)
            ) +
            ggplot2::guides(color = ggplot2::guide_legend(title = NULL, nrow = 2, byrow = TRUE))
    })


    write_profile_pdf(paste0("metric_imbalance_profile", output_suffix, "_", value_mode, ".pdf"), imbalance_profiles)
    write_profile_pdf(paste0("metric_connectivity_profile", output_suffix, "_", value_mode, ".pdf"), connectivity_profiles)
}
