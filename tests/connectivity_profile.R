source('R/common.R')
source('R/performance_profile_plot.R')
raw <- data.frame(Algorithm='a', Graph=letters[1:6], K=8, Epsilon=.03,
    Cores=1, Cut=10, Time=1, Imbalance=c(.01,.01,.04,.04,.01,.01),
    Connectivity=c(0,0.25,0,1.5,0,0), Failed=c(0,0,0,0,0,1), Timeout=c(0,0,0,0,1,0))
a <- default_normalizer(raw)
stopifnot(identical(a$FailedConnectivity,c(FALSE,TRUE,FALSE,TRUE,FALSE,FALSE)),
    identical(a$Imbalanced,c(FALSE,FALSE,TRUE,FALSE,FALSE,FALSE)),
    identical(a$Feasible,c(TRUE,FALSE,FALSE,FALSE,FALSE,FALSE)))
b <- a; b$Algorithm <- 'b'
d <- create_performance_profile_data(a,b)
stopifnot(all(d$Fraction[d$Ratio == PP_RATIO_CONNECTIVITY] == 3/6),
          all(d$Fraction[d$Ratio == PP_RATIO_IMBALANCED] == 4/6))
standard <- create_performance_profile_plot(a,b)
standard_a <- standard$data[standard$data$Algorithm == 'a', ]
stopifnot(standard_a$Fraction[2] == 3/6,
          identical(tail(standard$scales$scales[[1]]$labels, 4), c('C','I','T','F')))
p <- create_connectivity_performance_profile_plot(a,b)
stopifnot(identical(tail(p$scales$scales[[1]]$labels,3), c('I','T','F')),
          any(startsWith(p$scales$scales[[1]]$labels, 'C: ')))
# Overlapping flags in normalized inputs still count only at C.
a$Imbalanced[2] <- TRUE
stopifnot(all(create_performance_profile_data(a,b)$Fraction[d$Ratio == PP_RATIO_CONNECTIVITY] == 3/6))
# Legacy CSVs and normalized data still work.
legacy <- raw; legacy$Connectivity <- NULL
stopifnot(!any(default_normalizer(legacy)$FailedConnectivity))
a$FailedConnectivity <- NULL; b$FailedConnectivity <- NULL
invisible(create_performance_profile_plot(a,b))
# Explicit flags work even when measured imbalance is below the threshold.
raw$FailedImbalance <- c(1,0,0,0,0,0)
stopifnot(default_normalizer(raw)$Imbalanced[1])
# A valid repeat restores feasibility; all disconnected repeats remain C.
repeats <- raw[c(2,2), ]; repeats$Connectivity <- c(1,0); repeats$Imbalance <- .01
stopifnot(default_normalizer(repeats)$Feasible)
repeats$Connectivity <- c(1,2)
stopifnot(default_normalizer(repeats)$FailedConnectivity)
raw$Connectivity[1] <- -1
stopifnot(inherits(try(default_normalizer(raw),silent=TRUE),'try-error'))
# Hypergraph normalization uses the same constraints.
hg <- raw; hg$Connectivity[1] <- 0
names(hg)[names(hg) == 'Graph'] <- 'Hypergraph'
hg$Objective <- 'km1'; hg$KM1 <- hg$Cut
stopifnot(default_hypergraph_normalizer(hg)$FailedConnectivity[2])
# Verify that ggplot can render the integrated scale.
built <- ggplot2::ggplot_build(p)
stopifnot(all(is.finite(built$data[[1]]$x)), all(is.finite(built$data[[1]]$y)))
# C expands into severity thresholds, while I is counted afterwards.
profile <- p$data[p$data$Algorithm == 'a', ]
c_start <- sum(vapply(default_performance_profile_segments, function(x) x$width, numeric(1)))
gap <- profile[profile$Ratio %in% c(c_start, c_start + 1), ]
stopifnot(nrow(gap) == 2, all(gap$Fraction == 1/6))
components <- profile[profile$Ratio > c_start + 1, ]
stopifnot(abs(components$Ratio[1] - (c_start + 1 + 4 * .25 / 10)) < 1e-8,
          abs(components$Ratio[2] - (c_start + 1 + 4 * 1.5 / 10)) < 1e-8,
          components$Fraction[1] == 2/6, components$Fraction[2] == 3/6,
          components$Fraction[3] == 4/6)
repeats$Connectivity <- c(.25, 1.5)
stopifnot(default_normalizer(repeats)$AvgConnectivity == .875)
normal <- create_performance_profile_plot(a,b)
stopifnot(identical(tail(normal$scales$scales[[1]]$labels, 4), c('C','I','T','F')))
# Standard profiles also work without severity measurements.
a$AvgConnectivity <- NULL; b$AvgConnectivity <- NULL
invisible(create_performance_profile_plot(a,b))
third_raw <- hg
names(third_raw)[names(third_raw) == 'Hypergraph'] <- 'Graph'
third_raw$FailedImbalance <- NULL
third <- default_normalizer(third_raw)
third_b <- third; third_b$Algorithm <- 'b'
third_plot <- create_imbalance_performance_profile_plot(third, third_b)
stopifnot(identical(tail(third_plot$scales$scales[[1]]$labels, 2), c('I','F')),
          identical(third$ImbalancedWithoutConnectivity, c(FALSE,FALSE,TRUE,TRUE,FALSE,FALSE)),
          third$AvgCutWithoutConnectivity[2] == 10)
third_curve <- third_plot$data[third_plot$data$Algorithm == 'a', ]
stopifnot(identical(third_curve$Fraction, c(2/6,4/6,1)),
          nrow(ggplot2::ggplot_build(third_plot)$data[[1]]) == 6)
# A balanced disconnected repeat contributes even if another repeat is imbalanced.
third_repeats <- third_raw[c(2,2), ]; third_repeats$Connectivity <- c(.25, 1.5)
third_repeats$Imbalance <- c(.01,.04); third_repeats$Cut <- c(10,20)
stopifnot(default_normalizer(third_repeats)$AvgCutWithoutConnectivity == 10)
# Round the C boundary up to the next regular tick and show its label.
snapped <- default_normalizer(third_raw)
snapped$AvgConnectivity[4] <- 1.6
snapped_b <- snapped; snapped_b$Algorithm <- 'b'
snapped_plot <- create_connectivity_performance_profile_plot(snapped, snapped_b)
axis <- snapped_plot$scales$scales[[1]]
stopifnot(tail(axis$labels, 5)[1] == '10',
          tail(axis$breaks, 5)[1] == c_start + 1 + 4)
snapped_curve <- snapped_plot$data[snapped_plot$data$Algorithm == 'a', ]
stopifnot(any(abs(snapped_curve$Ratio - (c_start + 1 + 4 * 1.6 / 10)) < 1e-8))
# Keep I and F visible even if no instances populate either category.
only_valid <- third[1:2, ]; only_valid_b <- only_valid; only_valid_b$Algorithm <- 'b'
empty_categories <- create_imbalance_performance_profile_plot(only_valid, only_valid_b)
empty_axis <- ggplot2::ggplot_build(empty_categories)$layout$panel_params[[1]]$x
stopifnot(all(c('I', 'F') %in% empty_axis$get_labels()),
          isTRUE(all.equal(tail(empty_categories$scales$scales[[1]]$breaks, 2),
                    c_start + (.04 * c_start / (1 - .04 * 2)) * c(1, 2))))
# Different K values have independent baselines and denominators.
k8a <- third[1:2, ]; k8b <- k8a; k8b$Algorithm <- 'b'
k32a <- k8a; k32a$K <- 32; k32a$AvgCutWithoutConnectivity <- 100
k32b <- k8b; k32b$K <- 32; k32b$AvgCutWithoutConnectivity <- 200
for (profile_function in list(create_performance_profile_plot,
    create_connectivity_performance_profile_plot, create_imbalance_performance_profile_plot)) {
    plots <- profile_function(k8a, k8b, k32a, k32b)
    stopifnot(identical(names(plots), c('8','32')),
              plots[['8']]$labels$subtitle == 'K = 8')
}
profiles <- create_imbalance_performance_profile_plot(rbind(k8a,k32a), rbind(k8b,k32b))
stopifnot(all(profiles[['8']]$data$Ratio == 0),
          all(profiles[['32']]$data$Ratio[profiles[['32']]$data$Algorithm == 'a'] == 0),
          all(profiles[['32']]$data$Ratio[profiles[['32']]$data$Algorithm == 'b'] > 0))
single <- suppressWarnings(create_performance_profile_plot(k8a,k8b,k32a))
stopifnot(inherits(single,'ggplot'), single$labels$subtitle == 'K = 8')
stopifnot(inherits(try(suppressWarnings(create_performance_profile_plot(k8a,k32a)),
                     silent=TRUE), 'try-error'))
cat('Connectivity profile checks passed\n')

# Expanded imbalance uses descending success rates, including partial successes.
severity <- third
severity$ImbalanceSuccessRate <- c(1, .7, .375, 0, NA, NA)
severity_b <- severity; severity_b$Algorithm <- 'b'
expanded <- create_expanded_imbalance_performance_profile_plot(severity, severity_b)
axis <- expanded$scales$scales[[1]]
stopifnot(identical(tail(axis$labels, 5), c('I: < 0.75','0.50','0.25','0.0','F')))
stopifnot(abs(diff(tail(axis$breaks, 2)) - .04 * max(axis$breaks)) < 1e-8,
          axis$limits[2] == max(axis$breaks))
curve <- expanded$data[expanded$data$Algorithm == 'a', ]
stopifnot(any(abs(curve$Ratio - (c_start + 1 + 4 * (.75 - .7) / .75)) < 1e-7 & curve$Fraction == 2/6),
          any(abs(curve$Ratio - (c_start + 1 + 2)) < 1e-7 & curve$Fraction == 3/6),
          any(abs(curve$Ratio - (c_start + 1 + 4)) < 1e-7 & curve$Fraction == 4/6),
          tail(curve$Fraction, 1) == 1)
invisible(ggplot2::ggplot_build(expanded))
severity$ImbalanceSuccessRate[3] <- 1.1
stopifnot(inherits(try(create_expanded_imbalance_performance_profile_plot(severity, severity_b),
                      silent=TRUE), 'try-error'))

# Extra-component severity stops at ten; larger counts use a separate marker.
cap <- third
cap$AvgConnectivity[2:4] <- c(10, 0, 11)
cap_b <- cap; cap_b$Algorithm <- 'b'
capped <- create_connectivity_performance_profile_plot(cap, cap_b)
stopifnot(identical(tail(capped$scales$scales[[1]]$labels, 4), c('> 10 C','I','T','F')))
cap_curve <- capped$data[capped$data$Algorithm == 'a', ]
stopifnot(any(abs(cap_curve$Ratio - (c_start + 1 + 4)) < 1e-7 & cap_curve$Fraction == 2/6),
          any(abs(cap_curve$Ratio - (c_start + 1 + 4 + .04 * (c_start + 1 + 4) / (1 - .04 * 4))) < 1e-7 & cap_curve$Fraction == 3/6))

# Every profile reserves space after its final failure tick.
for (padded in list(standard, p, third_plot, expanded)) {
    x_axis <- padded$scales$scales[[1]]
    panel <- ggplot2::ggplot_build(padded)$layout$panel_params[[1]]
    right_fraction <- (panel$x.range[2] - max(x_axis$breaks)) / diff(panel$x.range)
    stopifnot(abs(right_fraction - .04/1.04) < 1e-8)
}

# Category markers are evenly spaced from their divider through the right margin.
for (item in list(list(standard, 4L, c_start), list(p, 4L, c_start + 5),
                  list(third_plot, 2L, c_start), list(expanded, 1L, c_start + 5))) {
    plot <- item[[1]]
    ticks <- tail(plot$scales$scales[[1]]$breaks, item[[2]])
    right <- ggplot2::ggplot_build(plot)$layout$panel_params[[1]]$x.range[2]
    gaps <- diff(c(item[[3]], ticks, right))
    stopifnot(max(gaps) - min(gaps) < 1e-8)
}

# Success rates override average imbalance and explicit flags at the strict boundary.
threshold_raw <- raw
threshold_raw$ImbalanceSuccessRate <- c(.75, .749, 1, 0, 1, 1)
threshold_raw$Imbalance <- .1
threshold_raw$FailedImbalance <- 1
threshold_raw$Connectivity <- 0
threshold_raw$FailedConnectivity <- 0
threshold <- default_normalizer(threshold_raw)
stopifnot(identical(threshold$ImbalancedWithoutConnectivity,
                    c(FALSE, TRUE, FALSE, TRUE, FALSE, FALSE)))
