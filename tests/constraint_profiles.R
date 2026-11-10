source("R/common.R")
source("R/performance_profile_plot.R")
a <- data.frame(Algorithm = "a", Graph = letters[1:7], K = 8,
    Failed = c(rep(FALSE, 6), TRUE), Timeout = c(rep(FALSE, 5), TRUE, FALSE),
    ImbalanceSuccessRate = c(1, .9, .75, .25, 0, NA, NA),
    ConnectivitySuccessRate = c(1, .9, .75, .25, 0, NA, NA),
    AvgConnectivity = c(0, 0, 2, 10, 11, NA, NA),
    ImbalancedWithoutConnectivity = c(FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))
b <- a; b$Algorithm <- "b"
# Inputs deliberately contain no objective/quality columns.
for (fun in list(create_imbalance_success_profile_plot, create_connectivity_success_profile_plot)) {
    p <- fun(a, b)
    stopifnot(identical(p$scales$scales[[1]]$labels, c("100%", "75%", "50%", "25%", "0%", "F")))
    curve <- subset(p$data, Algorithm == "a")
    stopifnot(sum(curve$Ratio == 0) == 1, curve$Fraction[1] == 1/7,
        any(abs(curve$Ratio - .1) < 1e-8 & curve$Fraction == 2/7),
        any(curve$Ratio == 1 & curve$Fraction == 5/7), tail(curve$Fraction, 1) == 1)
    invisible(ggplot2::ggplot_build(p))
    no_perfect <- a
    no_perfect$ImbalanceSuccessRate[1] <- .9
    no_perfect$ConnectivitySuccessRate[1] <- .9
    no_perfect_curve <- subset(fun(no_perfect, b)$data, Algorithm == "a")
    stopifnot(no_perfect_curve$Ratio[1] == 0, no_perfect_curve$Fraction[1] == 0)
    changed <- a; changed$AvgCut <- NA; changed$AvgKM1 <- Inf
    stopifnot(identical(p$data, fun(changed, b)$data))
    mixed <- a; mixed$K <- 32
    mixed_b <- b; mixed_b$K <- 32
    stopifnot(identical(names(fun(rbind(a, mixed), rbind(b, mixed_b))), c("8", "32")))
    bad <- a; bad$ImbalanceSuccessRate[1] <- 2; bad$ConnectivitySuccessRate[1] <- 2
    stopifnot(inherits(try(fun(bad, b), silent = TRUE), "try-error"))
}
p <- create_extra_components_profile_plot(a, b)
axis <- p$scales$scales[[1]]
curve <- subset(p$data, Algorithm == "a")
stopifnot(identical(tail(axis$labels, 3), c("> 10 C", "I", "F")),
    any(curve$Ratio == 0 & curve$Fraction == 1/7),
    any(curve$Ratio == 2 & curve$Fraction == 2/7),
    any(curve$Ratio == 10 & curve$Fraction == 3/7),
    any(curve$Ratio == tail(axis$breaks, 3)[1] & curve$Fraction == 4/7),
    any(curve$Ratio == tail(axis$breaks, 2)[1] & curve$Fraction == 5/7))
invisible(ggplot2::ggplot_build(p))
cat("Constraint-only profile checks passed\n")
