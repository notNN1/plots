source("R/common.R")
source("R/performance_profile_plot.R")
raw <- data.frame(Algorithm = "a", Graph = c("g", "g", "h"), K = 8,
    Epsilon = .03, Cores = 1, Cut = c(100, 100, 100), Km1 = c(10, 30, 40),
    Time = 1, Imbalance = .01, Connectivity = c(0, 1, 0), Failed = 0, Timeout = 0)
a <- default_km1_normalizer(raw)
stopifnot(a$AvgKM1[1] == 10, a$AvgKM1WithoutConnectivity[1] == 20)
b <- a; b$Algorithm <- "b"
b$AvgKM1 <- 2 * a$AvgKM1
b$AvgKM1WithoutConnectivity <- 2 * a$AvgKM1WithoutConnectivity
for (fun in list(create_imbalance_performance_profile_plot,
                 create_expanded_imbalance_performance_profile_plot)) {
    p <- fun(a, b, column.objective = "AvgKM1WithoutConnectivity")
    stopifnot(all(p$data$Ratio[p$data$Algorithm == "a"] == 0))
    invisible(ggplot2::ggplot_build(p))
}
invisible(ggplot2::ggplot_build(create_connectivity_performance_profile_plot(
    a, b, column.objective = "AvgKM1")))
raw$Km1 <- NULL
stopifnot(inherits(try(default_km1_normalizer(raw), silent = TRUE), "try-error"))
cat("KM1 profile checks passed\n")
