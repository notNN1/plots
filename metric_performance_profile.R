#!/usr/bin/env Rscript
# Run from the repository root: Rscript metric_performance_profile.R
source("R/common.R")
source("R/performance_profile_plot.R")

data_dir <- normalizePath("data/metric", mustWork = TRUE)
validate_connectivity_counts <- function(filename) {
    raw <- read.csv(filename, stringsAsFactors = FALSE)
    if (!"Connectivity" %in% names(raw) || !is.numeric(raw$Connectivity)) {
        stop("Connectivity must be numeric in ", filename)
    }
    missing <- is.na(raw$Connectivity)
    if (any(missing)) {
        stop("Missing Connectivity component counts in ", filename, " for graph(s): ",
             paste(raw$Graph[missing], collapse = ", "))
    }
    if (any(!is.finite(raw$Connectivity) | raw$Connectivity < 0)) {
        stop("Connectivity component counts must be finite and nonnegative in ", filename)
    }
}

csv_files <- c(
    "Refinement + New Metric" = "do_nothing_ip.standard_k32.csv",
    "No Refinement + New Metric" = "ip.standard_no.refinement_k32.csv",
    "No Refinement + Old Metric" = "ip.standard_no.refinement_old.metric_k32.csv",
    "Refinement + Old Metric" = "do_nothing_ip.standard_old.metric_k32.csv"
)

datasets <- lapply(names(csv_files), function(name) {
    filename <- file.path(data_dir, csv_files[[name]])
    validate_connectivity_counts(filename)
    load_dataset(
        filename = filename,
        name = name,
        normalizer = default_km1_normalizer,
        cache = FALSE
    )
})

imbalance_profiles <- do.call(create_imbalance_performance_profile_plot,
    c(datasets, list(
        column.objective = "AvgKM1WithoutConnectivity",
        column.imbalanced = "ImbalancedWithoutConnectivity",
        levels = names(csv_files),
        plot.xlab = "KM1 Ratio",
        plot.ylab = "Fraction of Instances",
        legend.title = NULL,
        tex = FALSE
    )))
if (inherits(imbalance_profiles, "ggplot")) imbalance_profiles <- list(imbalance_profiles)
imbalance_profiles <- lapply(imbalance_profiles, function(plot) {
    plot + ggplot2::labs(title = "KM1 Performance Profile (Imbalance and Failed)") +
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
        column.failed = "ConnectivityProfileFailed",
        column.imbalanced = "ConnectivityProfileImbalanced",
        levels = names(csv_files),
        plot.xlab = "Connectivity Component Count Ratio (Current / Best)",
        plot.ylab = "Fraction of Instances",
        legend.title = NULL,
        tex = FALSE
    )))
if (inherits(connectivity_profiles, "ggplot")) connectivity_profiles <- list(connectivity_profiles)
connectivity_profiles <- lapply(connectivity_profiles, function(plot) {
    plot + ggplot2::labs(title = "Connectivity Component Count Profile") +
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
write_profile_pdf <- function(filename, plots) {
    grDevices::pdf(filename, width = 11, height = 7)
    tryCatch({
        for (plot in plots) print(plot)
    }, finally = grDevices::dev.off())
}

write_profile_pdf("metric_imbalance_profile.pdf", imbalance_profiles)
write_profile_pdf("metric_connectivity_profile.pdf", connectivity_profiles)
