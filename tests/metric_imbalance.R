source("R/common.R")
source("R/metric_imbalance_normalizer.R")

raw <- data.frame(
    Graph = letters[1:5], K = 32, Algorithm = "a", Cores = 1, Epsilon = .03,
    Failed = c(0, 0, 0, 0, 1), Timeout = 0,
    Km1 = c(10, 20, 30, NA, 50), AverageKm1 = c(11, 21, 31, 41, 51),
    Time = 1, AverageTime = 2,
    Connectivity = c(0, 0, NA, NA, 0), AverageConnectivity = c(0, .5, 2, 2, 0),
    Imbalance = .01, AverageImbalance = .02,
    ImbalanceSuccessRate = 1, ConnectivitySuccessRate = c(1, .5, 0, 0, 1)
)
imbalance_mode <- function(datasets) result_value_mode(datasets,
    flags = character(), rates = "ImbalanceSuccessRate")
# Connectivity failures never switch the imbalance profile to best.
stopifnot(imbalance_mode(list(raw)) == "average")
average <- metric_imbalance_normalizer(raw, value_mode = imbalance_mode(list(raw)))
stopifnot(identical(average$AvgKM1WithoutConnectivity[1:4], c(11, 21, 31, 41)),
          identical(average$Failed, c(FALSE, FALSE, FALSE, FALSE, TRUE)))
# One partial imbalance success rate switches every algorithm and graph to best.
partial <- raw[1:2, ]
partial$Algorithm <- "b"
partial$ImbalanceSuccessRate[2] <- .9
baseline <- raw[1:2, ]
mode <- imbalance_mode(list(baseline, partial))
stopifnot(mode == "best")
a <- metric_imbalance_normalizer(baseline, value_mode = mode)
b <- metric_imbalance_normalizer(partial, value_mode = mode)
stopifnot(identical(a$AvgKM1WithoutConnectivity, c(10, 20)),
          identical(b$AvgKM1WithoutConnectivity, c(10, 20)))
source("R/performance_profile_plot.R")
plot <- create_imbalance_performance_profile_plot(a, b,
    column.objective = "AvgKM1WithoutConnectivity")
labels <- plot$scales$get_scales("x")$labels
stopifnot(all(c("I", "F") %in% labels), !"U" %in% labels)
invisible(ggplot2::ggplot_build(plot))
cat("Imbalance-only selection and I/F marker checks passed\n")
