source("R/common.R")
source("R/imbalance_success_grid_plot.R")
raw <- data.frame(Graph = letters[1:3], K = 32, Algorithm = "a", Cores = 1,
    Epsilon = .03, Failed = 0, Timeout = 0,
    Km1 = c(10, 20, NA), AverageKm1 = c(11, 21, 31),
    Time = c(1, 2, NA), AverageTime = c(1.5, 2.5, 3.5),
    Connectivity = c(0, 0, NA), AverageConnectivity = c(0, .5, 2),
    Imbalance = c(.01, .01, NA), AverageImbalance = c(.02, .02, .05),
    ImbalanceSuccessRate = c(1, 1, 0), ConnectivitySuccessRate = c(1, .5, 0))
average <- select_result_values(raw, "average")
best <- select_result_values(raw, "best")
for (field in c("Km1", "Time", "Connectivity", "Imbalance")) {
    stopifnot(identical(average[[field]], raw[[paste0("Average", field)]]),
              identical(best[[field]], raw[[field]]))
}
stopifnot(identical(best, select_result_values(best)), as.logical(best$Failed[3]),
          !any(as.logical(average$Failed)), result_value_mode(list(raw)) == "best")
# A failure in one algorithm selects best even for all-success algorithms.
success <- raw[1, ]
stopifnot(result_value_mode(list(success, raw)) == "best",
          result_value_mode(list(success, success)) == "average")
selected <- lapply(list(success, raw), select_result_values,
                   mode = result_value_mode(list(success, raw)))
stopifnot(selected[[1]]$Km1 == 10, selected[[2]]$Km1[1] == 10,
          is.na(selected[[2]]$Km1[3]))
legacy <- success[, !startsWith(names(success), "Average")]
stopifnot(identical(legacy, select_result_values(legacy)))
local({
    directory <- tempfile()
    dir.create(directory)
    on.exit(unlink(directory, recursive = TRUE))
    write.csv(success, file.path(directory, "success.csv"), row.names = FALSE)
    write.csv(raw, file.path(directory, "partial.csv"), row.names = FALSE)
    layout <- file.path(directory, "layout.csv")
    write.csv(data.frame(filename = c("success.csv", "partial.csv"),
                         x = 1:2, y = 1), layout, row.names = FALSE)
    grid <- create_total_time_grid_plot(layout)
    stopifnot(grid$data$TotalTime[1] == 1, is.na(grid$data$TotalTime[2]),
              attr(grid, "result_value_mode") == "best")
    invisible(ggplot2::ggplot_build(grid))
})
cat("Uniform average/best result selection checks passed\n")
