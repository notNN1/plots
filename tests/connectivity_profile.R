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
stopifnot(abs(components$Ratio[1] - (c_start + 1 + 4 * .25 / 1.5)) < 1e-8,
          abs(components$Ratio[2] - (c_start + 1 + 4)) < 1e-8,
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
stopifnot(tail(axis$labels, 4)[1] == '2.0',
          tail(axis$breaks, 4)[1] == c_start + 1 + 4)
snapped_curve <- snapped_plot$data[snapped_plot$data$Algorithm == 'a', ]
stopifnot(any(abs(snapped_curve$Ratio - (c_start + 1 + 4 * 1.6 / 2)) < 1e-8))
# Keep I and F visible even if no instances populate either category.
only_valid <- third[1:2, ]; only_valid_b <- only_valid; only_valid_b$Algorithm <- 'b'
empty_categories <- create_imbalance_performance_profile_plot(only_valid, only_valid_b)
empty_axis <- ggplot2::ggplot_build(empty_categories)$layout$panel_params[[1]]$x
stopifnot(all(c('I', 'F') %in% empty_axis$get_labels()),
          identical(tail(empty_categories$scales$scales[[1]]$breaks, 2),
                    c(c_start + 1.5/4, c_start + 1.5/2)))
cat('Connectivity profile checks passed\n')
