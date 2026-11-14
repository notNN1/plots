#!/usr/bin/env Rscript
# Run from the repository root: Rscript st_options_imbalance.R
source("R/common.R")
source("R/performance_profile_plot.R")

data_dir <- normalizePath("data/st_options", mustWork = TRUE)
csv_files <- c(
    "Normal" = "do_nothing_ip.st_no.refinement_st.normal_st.recalculations.5_k32.csv",
    "Advanced" = "do_nothing_ip.st_no.refinement_st.advanced_st.recalculations.5_k32.csv",
    "Vine" = "do_nothing_ip.st_no.refinement_st.recalculations.5_st.vine_k32.csv"
)

datasets <- lapply(names(csv_files), function(name) {
    # This profile needs success rates, not KM1 or connectivity measurements.
    df <- read.csv(file.path(data_dir, csv_files[[name]]))
    required <- c("Graph", "K", "ImbalanceSuccessRate", "Failed")
    if (!all(required %in% names(df))) {
        stop("Missing required imbalance profile columns in ", csv_files[[name]])
    }
    if (!"Timeout" %in% names(df)) df$Timeout <- FALSE
    for (flag in c("Failed", "Timeout")) {
        if (anyNA(df[[flag]]) || !all(df[[flag]] %in% c(0, 1))) {
            stop(flag, " must contain nonmissing 0/1 flags in ", csv_files[[name]])
        }
        df[[flag]] <- as.logical(df[[flag]])
    }
    rate <- df$ImbalanceSuccessRate
    if (!is.numeric(rate) || anyNA(rate) || any(!is.finite(rate) | rate < 0 | rate > 1)) {
        stop("ImbalanceSuccessRate must contain finite values between 0 and 1 in ",
             csv_files[[name]])
    }
    df %>%
        dplyr::group_by(Graph, K) %>%
        dplyr::summarise(
            ImbalanceSuccessRate = mean(ImbalanceSuccessRate[!Failed & !Timeout]),
            Failed = all(Failed),
            Timeout = all(Timeout),
            .groups = "drop"
        ) %>%
        dplyr::mutate(Algorithm = name)
})

profile <- do.call(create_imbalance_success_profile_plot,
    c(datasets, list(
        levels = names(csv_files),
        plot.xlab = "Imbalance Threshold",
        plot.ylab = "Fraction of Instances Not Balanced",
        legend.title = NULL,
        tex = FALSE
    )))
for (dataset in datasets) {
    failed <- as.logical(dataset$Failed) | as.logical(dataset$Timeout)
    if (!any(failed)) {
        profile$data <- profile$data[!(
            as.character(profile$data$Algorithm) == dataset$Algorithm[[1]] &
                profile$data$Ratio > 1
        ), , drop = FALSE]
    }
}
profile$data$Fraction <- 1 - profile$data$Fraction
profile <- profile +
    ggplot2::labs(title = "Imbalance Threshold Profile") +
    default_theme +
    ggplot2::theme(
        legend.position = "bottom",
        axis.title.x = ggplot2::element_text(size = 14),
        axis.title.y = ggplot2::element_text(size = 14),
        axis.text.x = ggplot2::element_text(size = 12),
        axis.text.y = ggplot2::element_text(size = 12),
        legend.text = ggplot2::element_text(size = 20),
        plot.subtitle = ggplot2::element_text(size = 20, hjust = 0.5),
        plot.title = ggplot2::element_text(size = 16, hjust = 0.5)
    )

grDevices::pdf("st_options_imbalance.pdf", width = 11, height = 7)
tryCatch(print(profile), finally = grDevices::dev.off())
