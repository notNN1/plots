# Choose one result type across every algorithm and instance in a plot.
result_value_mode <- function(datasets,
    flags = c("Failed", "Timeout", "FailedImbalance", "FailedConnectivity"),
    rates = c("ImbalanceSuccessRate", "ConnectivitySuccessRate")) {
    if (is.data.frame(datasets)) datasets <- list(datasets)
    failed <- vapply(datasets, function(df) {
        flags <- intersect(flags, names(df))
        rates <- intersect(rates, names(df))
        for (column in rates) {
            rate <- df[[column]]
            if (!is.numeric(rate) || any(!is.na(rate) & (!is.finite(rate) | rate < 0 | rate > 1))) {
                stop(column, " must contain success rates between 0 and 1.")
            }
        }
        any(vapply(flags, function(column) any(df[[column]] == 1, na.rm = TRUE), logical(1))) ||
            any(vapply(rates, function(column) any(df[[column]] < 1, na.rm = TRUE), logical(1)))
    }, logical(1))
    if (any(failed)) "best" else "average"
}

# No row-level fallback: missing values in the selected result type stay missing.
# CSVs without Average* columns retain their existing interpretation.
select_result_values <- function(df, mode = attr(df, "result_value_mode")) {
    if (is.null(mode)) mode <- "average"
    mode <- match.arg(mode, c("average", "best"))
    for (field in c("Km1", "Time", "Connectivity", "Imbalance")) {
        average_column <- paste0("Average", field)
        if (!average_column %in% names(df)) next
        best_column <- paste0("Best", field)
        if (!best_column %in% names(df)) {
            df[[best_column]] <- if (field %in% names(df)) df[[field]] else NA_real_
        }
        selected <- df[[if (mode == "average") average_column else best_column]]
        if (!is.numeric(selected) && !(is.logical(selected) && all(is.na(selected)))) {
            stop(field, " must contain numeric ", mode, " results.")
        }
        unavailable <- !is.finite(selected)
        if (any(unavailable)) {
            if (!"Failed" %in% names(df)) df$Failed <- FALSE
            if (!"ResultSelectionFailed" %in% names(df)) df$ResultSelectionFailed <- FALSE
            df$Failed[unavailable] <- TRUE
            df$ResultSelectionFailed[unavailable] <- TRUE
        }
        df[[field]] <- as.numeric(selected)
    }
    if (any(startsWith(names(df), "Average"))) attr(df, "result_value_mode") <- mode
    df
}
