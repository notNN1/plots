#!/usr/bin/env Rscript
default_performance_profile_segment_1 <- list(
    trans = "identity",
    to = 1.1,
    width = 3,
    breaks = seq(1.0, 1.1, by = 0.01),
    labels = c("1.0", "", "", "", "", "1.05", "", "", "", "", "1.1")
)

default_performance_profile_segment_2 <- list(
    trans = "identity",
    to = 2,
    width = 2,
    breaks = c(1.25, 1.5, 1.75, 2),
    labels = c("", "1.5", "", "2")
)

default_performance_profile_segment_3 <- list(
    trans = "log10",
    to = 100,
    width = 1,
    breaks = c(10, 100),
    labels = c("10^1", "10^2")
)

default_performance_profile_segments <- list(
    default_performance_profile_segment_1,
    default_performance_profile_segment_2,
    default_performance_profile_segment_3
)

performance_profile_segments_nolog <- list(
    default_performance_profile_segment_1,
    default_performance_profile_segment_2
)

PP_RATIO_FEASIBLE <- 100000
PP_RATIO_CONNECTIVITY <- 500000
PP_RATIO_COMPONENT_OVERFLOW <- 750000
PP_RATIO_IMBALANCED <- 1000000
PP_RATIO_TIMEOUT <- 2000000
PP_RATIO_FAILED <- 3000000

#' Compute performance-profile curve data.
#'
#' @param ... Normalized result data frames with identical primary keys.
#' @param fractions Ratios at which to sample the step curves.
#' @param column.objective,column.algorithm,column.timeout,column.imbalanced,column.failed,column.connectivity
#'   Source column names.
#' @param primary_key Columns that identify common instances.
#' @return A data frame suitable for performance-profile plotting.
create_performance_profile_data <- function(
    ...,
    fractions = c(
        1.0, 
        1.1, 
        PP_RATIO_FEASIBLE, 
        PP_RATIO_CONNECTIVITY,
        PP_RATIO_IMBALANCED, 
        PP_RATIO_TIMEOUT,
        PP_RATIO_FAILED
    ),
    column.objective = "AvgCut",
    column.algorithm = "Algorithm",
    column.timeout = "Timeout",
    column.imbalanced = "Imbalanced",
    column.failed = "Failed",
    column.connectivity = "FailedConnectivity",
    primary_key = c("Graph", "K")) {
    #
    all_dfs <- lapply(list(...), function(df) {
        if (!column.connectivity %in% names(df)) df[[column.connectivity]] <- FALSE
        df
    })

    num_rows <- nrow(all_dfs[[1]])
    best <- do.call(pmin, lapply(all_dfs, \(df) df[[column.objective]]))

    data <- purrr::map_dfr(all_dfs, function(df) {
        df <- df %>%
            dplyr::mutate(Ratio = df[[column.objective]] / best) %>%
            dplyr::mutate(Ratio = case_when(
                df[[column.timeout]] ~ PP_RATIO_TIMEOUT,
                df[[column.failed]] ~ PP_RATIO_FAILED,
                df[[column.connectivity]] ~ PP_RATIO_CONNECTIVITY,
                df[[column.imbalanced]] ~ PP_RATIO_IMBALANCED,
                TRUE ~ Ratio
            )) %>%
            dplyr::group_by(Ratio) %>%
            dplyr::summarise(N = dplyr::n()) %>%
            dplyr::arrange(Ratio) %>%
            dplyr::mutate(
                Fraction = cumsum(N) / num_rows,
                Algorithm = first(df[[column.algorithm]]),
                Transformed = 0
            )

        # If the first lowest Ratio in a data set is larger than 1, the curve would start at
        # Fraction = 1 / n > 0. That looks ugly, so add a fake point which forces the curve to
        # go down to Fraction = 0
        row <- df %>% dplyr::slice_min(Ratio, n = 1)
        if (first(row$Ratio) > 1) {
            row$Fraction <- 0
            df <- rbind(row, df)
        }

        purrr::map_dfr(fractions, function(frac) {
            df %>% dplyr::filter(Ratio <= frac) %>%
                dplyr::filter(Ratio == max(Ratio)) %>%
                dplyr::mutate(Matched = frac) %>%
                dplyr::select(Algorithm, Fraction, Ratio = Matched)
        })
    })

    return(data)
}


#' Plot a performance profile over multiple algorithms.
#'
#' @param ... Normalized result data frames with identical primary keys.
#' @param column.objective,column.algorithm,column.timeout,column.imbalanced,column.failed,column.connectivity
#'   Source column names.
#' @param primary_key Columns that identify common instances.
#' @param segments Axis segments defining the broken/log-scaled ratio axis.
#' @param column.components Column holding mean extra components for C violations.
#' @param segment.connectivity.width Width of the linear extra-components scale at C.
#' @param segment.connectivity.gap Unmeasured horizontal gap before C.
#' @param segment.errors.width Width reserved for connectivity, imbalance, timeout, and failure
#'   markers.
#' @param tex If `TRUE`, use TeX math and symbolic error labels.
#' @param label.timeout,label.imbalanced,label.failed,label.connectivity Labels for error markers.
#' @param colors Optional named algorithm colors.
#' @param levels Optional algorithm ordering.
#' @param axis.y.sparse_labels If `TRUE`, label every other y tick.
#' @param plot.xlab,plot.ylab Axis labels; set to `NA` to omit.
#' @param legend.title Legend title, `NULL`, or `ggplot2::waiver()`.
.create_performance_profile_plot <- \(
    ...,
    column.objective = "AvgCut",
    column.algorithm = "Algorithm",
    column.timeout = "Timeout",
    column.imbalanced = "Imbalanced",
    column.failed = "Failed",
    column.connectivity = "FailedConnectivity",
    connectivity.profile = FALSE,
    imbalance.profile = FALSE,
    column.imbalance = "AvgImbalance",
    column.epsilon = "Epsilon",
    merge.failures = FALSE,
    column.components = "AvgConnectivity",
    segment.connectivity.width = 4,
    segment.connectivity.gap = 1,
    primary_key = c("Graph", "K"),
    segments = default_performance_profile_segments,
    segment.errors.width = 1.5,
    tex = FALSE,
    label.timeout = plot_label(tex, TEX_LABEL_TIMEOUT, PDF_LABEL_TIMEOUT),
    label.imbalanced = plot_label(tex, TEX_LABEL_IMBALANCED, PDF_LABEL_IMBALANCED),
    label.connectivity = plot_label(tex, TEX_LABEL_CONNECTIVITY, PDF_LABEL_CONNECTIVITY),
    label.failed = plot_label(tex, TEX_LABEL_FAILED, PDF_LABEL_FAILED),
    colors = c(),
    levels = c(),
    axis.y.sparse_labels = TRUE,
    plot.xlab = NA,
    plot.ylab = NA,
    legend.title = ggplot2::waiver()
) {
    all_dfs <- lapply(list(...), function(df) {
        if (!column.connectivity %in% names(df)) df[[column.connectivity]] <- FALSE
        df
    })

    if (length(all_dfs) <= 1) {
        cli::cli_abort("Need at least two data frames for plotting a performance profile.")
    }

    if (imbalance.profile) {
        # Reuse the expanded severity axis from epsilon through three times epsilon.
        all_dfs <- lapply(all_dfs, function(df) {
            active <- df[[column.imbalanced]] & !df[[column.failed]] & !df[[column.timeout]]
            if (any(active)) {
                for (column in c(column.imbalance, column.epsilon)) {
                    if (!column %in% names(df) || !is.numeric(df[[column]]) ||
                        any(!is.finite(df[[column]][active]))) {
                        stop("Imbalance violations require finite numeric ", column, " values.")
                    }
                }
            }
            if (any(active) && any(df[[column.epsilon]][active] < 0)) {
                stop("Imbalance thresholds must be nonnegative.")
            }
            overflow <- rep(FALSE, nrow(df))
            overflow[active] <- df[[column.imbalance]][active] > 3 * df[[column.epsilon]][active]
            within <- active & !overflow
            df[[column.components]] <- 0
            positive <- if (any(within)) within & df[[column.epsilon]] > 0 else rep(FALSE, nrow(df))
            if (any(positive)) df[[column.components]][positive] <-
                pmin(2, pmax(0, df[[column.imbalance]][positive] / df[[column.epsilon]][positive] - 1))
            df[[column.connectivity]] <- within
            df[[column.imbalanced]] <- overflow
            df
        })
        label.connectivity <- label.imbalanced
    }

    # Expand C into an absolute scale of average extra components.
    component_max <- 1
    if (connectivity.profile) {
        component_values <- unlist(lapply(all_dfs, function(df) {
            if (!column.components %in% names(df)) {
                if (any(df[[column.connectivity]])) {
                    stop("Connectivity violations require the ", column.components, " column.")
                }
                return(numeric())
            }
            values <- df[[column.components]][df[[column.connectivity]] &
                !df[[column.timeout]] & !df[[column.failed]]]
            if (!is.numeric(values) || anyNA(values) || any(!is.finite(values) | values < 0)) {
                stop("Connectivity violations require finite nonnegative component values.")
            }
            values
        }))
        component_max <- if (imbalance.profile) 2 else 10
        component_breaks <- if (imbalance.profile) seq(0, 2, by = .5) else seq(0, 10, by = 2)
        for (i in seq_along(all_dfs)) {
            if (!column.components %in% names(all_dfs[[i]])) all_dfs[[i]][[column.components]] <- 0
        }

    }

    # Run some basic sanity checks against the data frames
    for (i in 1:length(all_dfs)) {
        # Sort the data; replace 0 by 1 to ensure that zero-cuts do not crash our code
        df <- all_dfs[[i]] %>%
            dplyr::arrange_at(primary_key) %>%
            dplyr::mutate(!!column.objective := ifelse(.data[[column.objective]] == 0, 1, .data[[column.objective]]))
        all_dfs[[i]] <- df

        if (!(column.algorithm %in% colnames(df))) {
            cli::cli_abort("Column {.field {column.algorithm}} missing from data frame no. {.val {i}}.")
        }

        algorithms <- df %>% dplyr::pull(rlang::sym(column.algorithm))
        algorithm <- algorithms[1]
        if (!all(algorithms == algorithm)) {
            cli::cli_abort("Rows for multiple algorithms in the same data frame no. {.val {i}}: {.val {unique(algorithms)}}")
        }

        if (!(column.objective %in% colnames(df))) {
            cli::cli_abort("Column {.field {column.objective}} missing from data frame no. {.val {i}} (algorithm {.val {algorithm}}).")
        }
        if (!(column.timeout %in% colnames(df))) {
            cli::cli_abort("Column {.field {column.timeout}} missing from data frame no. {.val {i}} (algorithm {.val {algorithm}}).")
        }
        if (!(column.imbalanced %in% colnames(df))) {
            cli::cli_abort("Column {.field {column.imbalanced}} missing from data frame no. {.val {i}} (algorithm {.val {algorithm}}).")
        }
        if (!column.failed %in% colnames(df)) {
            cli::cli_abort("Column {.field {column.failed}} missing from data frame no. {.val {i}} (algorithm {.val {algorithm}}).")
        }

        if (NA %in% df[[column.objective]]) {
            cli::cli_abort("Column {.field {column.objective}} of data frame no. {.val {i}} (algorithm {.val {algorithm}}) contains {.val NA} values.")
        }
        if (-Inf %in% df[[column.objective]]) {
            cli::cli_abort("Column {.field {column.objective}} of data frame no. {.val {i}} (algorithm {.val {algorithm}}) contains {.val -Inf} values.")
        }

        if (nrow(df[, primary_key]) != nrow(all_dfs[[1]][, primary_key])) {
            cli::cli_abort("Number of rows for the primary keys in data frame no. {.val {i}} (algorithm {.val {algorithm}}) does not match the number of rows for the primary keys in the first data frame.")
        }
        if (!all.equal(df[, primary_key], all_dfs[[1]][, primary_key])) {
            cli::cli_abort("Primary keys of data frame no. {.val {i}} (algorithm {.val {algorithm}}) does not match for all rows with the primary keys of the first data frame.")
        }
    }

    num_rows <- nrow(all_dfs[[1]])
    best <- do.call(pmin, lapply(all_dfs, \(df) df[[column.objective]]))

    data <- purrr::map_dfr(all_dfs, function(df) {
        df <- df %>%
            dplyr::mutate(Ratio = df[[column.objective]] / best) %>%
            dplyr::mutate(Ratio = case_when(
                df[[column.timeout]] ~ if (merge.failures) PP_RATIO_FAILED else PP_RATIO_TIMEOUT,
                df[[column.failed]] ~ PP_RATIO_FAILED,
                df[[column.connectivity]] ~ if (connectivity.profile) {
                    ifelse(df[[column.components]] > component_max,
                        PP_RATIO_COMPONENT_OVERFLOW,
                        PP_RATIO_CONNECTIVITY + df[[column.components]] / component_max)
                } else PP_RATIO_CONNECTIVITY,
                df[[column.imbalanced]] ~ PP_RATIO_IMBALANCED,
                TRUE ~ Ratio
            )) %>%
            dplyr::group_by(Ratio) %>%
            dplyr::summarise(N = dplyr::n()) %>%
            dplyr::arrange(Ratio) %>%
            dplyr::mutate(
                Fraction = cumsum(N) / num_rows,
                Algorithm = first(df[[column.algorithm]]),
                Transformed = 0
            )

        # If the first lowest Ratio in a data set is larger than 1, the curve would start at
        # Fraction = 1 / n > 0. That looks ugly, so add a fake point which forces the curve to
        # go down to Fraction = 0
        row <- df %>% dplyr::slice_min(Ratio, n = 1)
        if (first(row$Ratio) > 1) {
            row$Fraction <- 0
            df <- rbind(row, df)
        }

        df
    })

    # Scale ratios to respect the segments
    offset <- 0
    from <- 1
    for (segment in segments) {
        min_value <- do.call(segment$trans, list(from))
        max_value <- do.call(segment$trans, list(segment$to))
        span <- max_value - min_value

        data <- data %>%
            dplyr::mutate(Transformed = ifelse(Transformed == 0 & Ratio >= from & Ratio < segment$to, 1, Transformed)) %>%
            dplyr::mutate(Ratio = ifelse(Transformed == 1,
                offset + segment$width * (do.call(segment$trans, list(Ratio)) - min_value) / span,
                Ratio
            )) %>%
            dplyr::mutate(Transformed = ifelse(Transformed == 1, 2, Transformed))

        offset <- offset + segment$width
        from <- segment$to
    }

    # Map errors (connectivity, imbalance, timeout, failure)
    map_errors <- function(vals) {
        purrr::map_int(vals, ~ case_when(
            .x == PP_RATIO_COMPONENT_OVERFLOW ~ 1,
            .x == PP_RATIO_IMBALANCED ~ if (imbalance.profile) 1L else 2L,
            .x == PP_RATIO_TIMEOUT ~ if (imbalance.profile) 2L else 3L,
            .x == PP_RATIO_FAILED ~ if (imbalance.profile) 3L else 4L,
            .x == Inf ~ if (imbalance.profile) 3L else 4L,
            TRUE ~ 0
        ))
    }

    if (connectivity.profile) {
        data <- data %>%
            dplyr::mutate(Transformed = ifelse(Transformed == 0 & Ratio >= from, 1, Transformed)) %>%
            dplyr::mutate(Ratio = ifelse(Transformed == 1,
                offset + ifelse(
                    Ratio >= PP_RATIO_CONNECTIVITY & Ratio <= PP_RATIO_CONNECTIVITY + 1,
                    segment.connectivity.gap + segment.connectivity.width * (Ratio - PP_RATIO_CONNECTIVITY),
                    ifelse(map_errors(Ratio) > 0, segment.connectivity.gap + segment.connectivity.width +
                        segment.errors.width * (if (imbalance.profile) ifelse(Ratio == PP_RATIO_IMBALANCED, .5, 1) else map_errors(Ratio) / 4), 0)
                ),
                Ratio
            )) %>%
            dplyr::mutate(Transformed = ifelse(Transformed == 1, 2, Transformed))

        # Anchor both ends of the unmeasured gap at the same cumulative fraction.
        anchors <- purrr::map_dfr(unique(data$Algorithm), function(algorithm) {
            curve <- data[data$Algorithm == algorithm, ]
            fraction <- max(c(0, curve$Fraction[curve$Ratio <= offset]))
            data.frame(Algorithm = algorithm,
                       Ratio = c(offset, offset + segment.connectivity.gap),
                       Fraction = fraction, Transformed = 2)
        })
        data <- dplyr::bind_rows(data, anchors) %>%
            dplyr::arrange(Algorithm, Ratio, Fraction)

    } else if (merge.failures) {
        data <- data %>% dplyr::mutate(Ratio = ifelse(Transformed == 0 & Ratio >= from,
            offset + segment.errors.width * dplyr::case_when(
                Ratio == PP_RATIO_IMBALANCED ~ 1/4,
                Ratio == PP_RATIO_FAILED | Ratio == Inf ~ 2/4,
                TRUE ~ 0
            ), Ratio))
    } else {
        data <- data %>% dplyr::mutate(Ratio = ifelse(Transformed == 0 & Ratio >= from,
            offset + segment.errors.width * dplyr::case_when(
                Ratio == PP_RATIO_CONNECTIVITY ~ 1/4,
                Ratio == PP_RATIO_IMBALANCED ~ 2/4,
                Ratio == PP_RATIO_TIMEOUT ~ 3/4,
                Ratio == PP_RATIO_FAILED | Ratio == Inf ~ 1,
                TRUE ~ 0
            ), Ratio))
    }

    # Generate x axis breaks and labels
    x_breaks <- c()
    x_labels <- c()
    offset <- 0
    from <- 1.0
    for (segment in segments) {
        min_value <- do.call(segment$trans, list(from))
        max_value <- do.call(segment$trans, list(segment$to))
        span <- max_value - min_value

        x_breaks <- c(x_breaks, sapply(segment$breaks, \(v) offset + segment$width * (do.call(segment$trans, list(v)) - min_value) / span))
        x_labels <- c(x_labels, if (tex) plot_math_label(segment$labels, tex) else segment$labels)

        offset <- offset + segment$width
        from <- segment$to
    }
    if (connectivity.profile) {
        x_breaks <- c(x_breaks,
            offset + segment.connectivity.gap + segment.connectivity.width * component_breaks / component_max,
            offset + segment.connectivity.gap + segment.connectivity.width + segment.errors.width * (if (imbalance.profile) c(.5, 1) else c(1/4, 2/4, 3/4, 1)))
        component_labels <- format(signif(component_breaks, 3), trim = TRUE)
        if (imbalance.profile) {
            component_labels <- paste0(format(component_breaks + 1, trim = TRUE),
                if (tex) "$\\epsilon$" else "ε")
        }
        component_labels[1] <- paste0(label.connectivity, ": ", component_labels[1])
        x_labels <- c(x_labels, component_labels,
            if (imbalance.profile) c(if (tex) "$>3\\epsilon$" else "> 3", label.failed) else c("> 10 C", label.imbalanced, label.timeout, label.failed))

    } else if (merge.failures) {
        x_breaks <- c(x_breaks, offset + segment.errors.width * c(1/4, 2/4))
        x_labels <- c(x_labels, label.imbalanced, label.failed)
    } else {
        x_breaks <- c(x_breaks, offset + segment.errors.width * c(1/4, 2/4, 3/4, 1))
        x_labels <- c(x_labels, label.connectivity, label.imbalanced, label.timeout, label.failed)
    }

    if (imbalance.profile && !tex) {
        # Plotmath draws epsilon using the graphics device's symbol font.
        labels <- as.list(x_labels)
        start <- length(labels) - length(component_breaks) - 1L
        for (i in seq_along(component_breaks)) {
            value <- component_breaks[i] + 1
            labels[[start + i - 1L]] <- if (i == 1L) {
                bquote(.(paste0(label.imbalanced, ": ")) * .(value) * epsilon)
            } else {
                bquote(.(value) * epsilon)
            }
        }
        labels[[length(labels) - 1L]] <- quote(">" * 3 * epsilon)
        x_labels <- as.expression(labels)
    }

    # Draw plot
    y_labels <- if (axis.y.sparse_labels) {
        c("0.0", "", "0.2", "", "0.4", "", "0.6", "", "0.8", "", "1.0")
    } else {
        seq(0.0, 1.0, by = 0.1)
    }

    if (length(levels) > 0) {
        data$Algorithm <- factor(data$Algorithm, levels = levels)
    }

    plot <- ggplot2::ggplot(data, ggplot2::aes(x = Ratio, y = Fraction, color = Algorithm)) +
        ggplot2::scale_x_continuous(limits = c(0, max(x_breaks)),
                                    expand = c(0, 0.01), breaks = x_breaks, labels = x_labels) +
        ggplot2::scale_y_continuous(limits = c(0, 1), expand = c(0, 0.01), breaks = seq(0.0, 1.0, by = 0.1), labels = y_labels) +
        ggplot2::geom_step(linewidth = 1.5) +
        ggplot2::guides(color = ggplot2::guide_legend(title = legend.title))

    x <- 0
    for (segment in segments) {
        x <- x + segment$width
        plot <- plot + ggplot2::geom_vline(xintercept = x)
    }

    if (!is.na(plot.xlab)) {
        plot <- plot + ggplot2::xlab(plot.xlab)
    }
    if (!is.na(plot.ylab)) {
        plot <- plot + ggplot2::ylab(plot.ylab)
    }

    if (connectivity.profile) plot <- plot + ggplot2::geom_vline(xintercept = c(
        offset + segment.connectivity.gap,
        offset + segment.connectivity.gap + segment.connectivity.width))

    # Set colors
    if (length(colors) > 0) {
        plot <- plot + ggplot2::scale_color_manual(name = "Algorithm", values = colors)
    }

    return(plot)
}

# Split each input by K before comparing algorithms. Keep the single-K API.
.create_profiles_by_k <- function(...) {
    args <- list(...)
    is_dataset <- vapply(args, is.data.frame, logical(1))
    datasets <- args[is_dataset]
    options <- args[!is_dataset]
    if (!length(datasets)) stop("Supply at least two datasets.")
    for (df in datasets) {
        if (!"K" %in% names(df) || anyNA(df$K) || !nrow(df)) {
            stop("Each dataset must contain nonempty, nonmissing K values.")
        }
    }
    ks <- sort(unique(unlist(lapply(datasets, function(df) df$K))))
    plots <- list()
    for (k in ks) {
        group <- lapply(datasets, function(df) df[df$K == k, , drop = FALSE])
        group <- group[vapply(group, nrow, integer(1)) > 0]
        if (length(group) < 2) {
            warning("Skipping K = ", k, ": need at least two datasets for comparison.", call. = FALSE)
            next
        }
        plot <- do.call(.create_performance_profile_plot, c(unname(group), options)) +
            ggplot2::labs(subtitle = paste("K =", k))
        plots[[as.character(k)]] <- plot
    }
    if (!length(plots)) stop("No K has at least two datasets for comparison.")
    if (length(plots) == 1) return(plots[[1]])
    plots
}

# Standard performance profile with categorical C, I, T, F markers.
create_performance_profile_plot <- function(...) {
    .create_profiles_by_k(..., connectivity.profile = FALSE)
}

# Performance profile with a scale of average extra components in the C section.
create_connectivity_performance_profile_plot <- function(..., segment.errors.width = 3) {
    .create_profiles_by_k(..., connectivity.profile = TRUE,
        segment.errors.width = segment.errors.width)
}

# Ignore connectivity; use I for imbalance and F for execution failure or timeout.
create_imbalance_performance_profile_plot <- function(
    ...,
    column.objective = "AvgCutWithoutConnectivity",
    column.imbalanced = "ImbalancedWithoutConnectivity"
) {
    .create_profiles_by_k(
        ..., column.objective = column.objective, column.imbalanced = column.imbalanced,
        column.connectivity = ".IgnoredConnectivity", merge.failures = TRUE)
}

# Ignore connectivity and expand I from epsilon to three times epsilon.
create_expanded_imbalance_performance_profile_plot <- function(
    ...,
    column.objective = "AvgCutWithoutConnectivity",
    column.imbalanced = "ImbalancedWithoutConnectivity",
    column.imbalance = "AvgImbalance",
    column.epsilon = "Epsilon",
    segment.imbalance.width = 4,
    segment.imbalance.gap = 1
) {
    .create_profiles_by_k(
        ..., column.objective = column.objective, column.imbalanced = column.imbalanced,
        column.imbalance = column.imbalance, column.epsilon = column.epsilon,
        column.connectivity = ".ImbalanceSeverity", column.components = ".ExcessImbalance",
        connectivity.profile = TRUE, imbalance.profile = TRUE, merge.failures = TRUE,
        segment.connectivity.width = segment.imbalance.width,
        segment.connectivity.gap = segment.imbalance.gap)
}
