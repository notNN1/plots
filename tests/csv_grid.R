source("R/imbalance_success_grid_plot.R")

local({
    folder <- tempfile("csv-grid-")
    dir.create(folder)
    on.exit(unlink(folder, recursive = TRUE))
    dataset_file <- file.path(folder, "runs.csv")
    layout_file <- file.path(folder, "layout.csv")
    raw <- data.frame(Graph = c("a", "b", "c"), Time = c(1, 2, 5),
        ImbalanceSuccessRate = c(.74, .75, 0), Failed = c(0, 0, 1))
    write.csv(raw, dataset_file, row.names = FALSE)
    write.csv(data.frame(filename = "runs.csv", x = 2, y = 3), layout_file, row.names = FALSE)
    time <- create_total_time_grid_plot(layout_file)
    imbalance <- create_imbalance_success_grid_plot(layout_file)
    # Recorded time from a failed run contributes; threshold is strictly below .75.
    stopifnot(time$data$TotalTime == 8, time$data$Label == "8",
              imbalance$data$BelowThreshold == .5, imbalance$data$Label == "0.50",
              time$data$x == imbalance$data$x, time$data$y == imbalance$data$y)
    time_scale <- time$scales$get_scales("fill")
    stopifnot(identical(time_scale$limits, c(0, 100)),
              identical(time_scale$breaks, c(0, 25, 50, 75, 100)))
    invisible(ggplot2::ggplot_build(time))
    invisible(ggplot2::ggplot_build(imbalance))
    # Configurable thresholds preserve strict comparison and update the legend.
    lower <- create_imbalance_success_grid_plot(layout_file, threshold = .74)
    higher <- create_imbalance_success_grid_plot(layout_file, threshold = .76)
    stopifnot(lower$data$BelowThreshold == 0, higher$data$BelowThreshold == 1,
              higher$scales$get_scales("fill")$name == "Below Threshold (0.76)")
    for (invalid in list(NA_real_, Inf, -.1, 1.1, c(.5, .75), "0.75")) {
        stopifnot(inherits(try(create_imbalance_success_grid_plot(layout_file,
            threshold = invalid), silent = TRUE), "try-error"))
    }
    # A missing time must not silently produce an incomplete total.
    raw$Time[1] <- NA_real_
    write.csv(raw, dataset_file, row.names = FALSE)
    stopifnot(inherits(try(create_total_time_grid_plot(layout_file), silent = TRUE), "try-error"))
})
cat("CSV grid checks passed\n")
