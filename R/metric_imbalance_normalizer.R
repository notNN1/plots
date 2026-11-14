# Connectivity measurements and success rates do not affect imbalance feasibility.
metric_imbalance_normalizer <- function(df, ..., value_mode = "average") {
    df$AverageConnectivity <- NULL
    df$Connectivity <- 0
    df$FailedConnectivity <- FALSE
    default_km1_normalizer(select_result_values(df, value_mode), ...)
}
