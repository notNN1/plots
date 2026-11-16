#!/usr/bin/env Rscript
# Run from the repository root: Rscript scripts/refinement/refinement_imbalance.R
source("R/plot_output_path.R")
source("R/common.R")
source("R/metric_imbalance_normalizer.R")
source("R/performance_profile_plot.R")

data_dir <- normalizePath("data/refinement", mustWork = TRUE)
csv_files <- c(
    "Standard" = "do_nothing_ip.standard_new.metric_k32.csv",
    "FM Disabled" = "do_nothing_ip.standard_new.metric_no.fm_k32.csv",
    "ST" = "ip.standard_new.metric_no.fm_st_k32.csv",
    "ST UBR" = "ip.standard_new.metric_no.fm_st_ubr_k32.csv"
)

for (value_mode in c("best", "average")) {
    imbalance_datasets <- lapply(names(csv_files), function(name) {
        load_dataset(
            filename = file.path(data_dir, csv_files[[name]]),
            name = name,
            normalizer = function(df, ...) {
                metric_imbalance_normalizer(df, value_mode = value_mode, ...)
            },
            cache = FALSE
        )
    })
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

    filename <- paste0("refinement_imbalance_profile_", value_mode, ".pdf")
    grDevices::pdf(plot_output_path(filename), width = 11, height = 7)
    tryCatch({
        for (plot in imbalance_profiles) print(plot)
    }, finally = grDevices::dev.off())
}
