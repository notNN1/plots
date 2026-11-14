source("R/result_values.R")

# Balance the legend around the bar itself, including the title on its left.
.imbalance_grid_colorbar <- function() {
    guide <- ggplot2::guide_colorbar(
        barwidth = grid::unit(10, "cm"), direction = "horizontal",
        title.position = "left",
        title.theme = ggplot2::element_text(vjust = .5))
    draw <- guide$draw
    guide$draw <- function(...) {
        legend <- draw(...)
        bar <- legend$layout[legend$layout$name == "bar", , drop = FALSE]
        title <- which(legend$layout$name == "title")
        if (nrow(bar) != 1L || length(title) != 1L) return(legend)
        # Align the title to the bar row, excluding the tick-label row below it.
        legend$layout$t[title] <- bar$t
        legend$layout$b[title] <- bar$b
        zero <- grid::unit(0, "pt")
        before <- which(seq_along(legend$widths) < bar$l)
        after <- which(seq_along(legend$widths) > bar$r)
        left <- if (length(before)) sum(legend$widths[before]) else zero
        right <- if (length(after)) sum(legend$widths[after]) else zero
        legend <- gtable::gtable_add_cols(legend, grid::unit.pmax(right - left, zero), pos = 0)
        gtable::gtable_add_cols(legend, grid::unit.pmax(left - right, zero), pos = -1)
    }
    guide
}

# Layout paths are relative to the layout CSV, so coordinates persist across runs.
create_imbalance_success_grid_plot <- function(layout_file, threshold = .75) {
    if (!is.numeric(threshold) || length(threshold) != 1L ||
        !is.finite(threshold) || threshold < 0 || threshold > 1) {
        stop("threshold must be a single finite number between 0 and 1.")
    }
    .create_csv_grid_plot(layout_file, metric = "imbalance", threshold = threshold)
}

# Sum recorded time across every row, including failed and timed-out runs.
create_total_time_grid_plot <- function(layout_file) {
    .create_csv_grid_plot(layout_file, metric = "total_time")
}

.create_csv_grid_plot <- function(layout_file, metric, threshold = .75) {
    layout <- read.csv(layout_file, stringsAsFactors = FALSE)
    if (!all(c("filename", "x", "y") %in% names(layout)) || !nrow(layout)) {
        stop("Layout must contain filename,x,y columns and at least one row.")
    }
    if (anyNA(layout$filename) || anyDuplicated(layout$filename) ||
        !is.numeric(layout$x) || !is.numeric(layout$y) ||
        any(!is.finite(layout$x)) || any(!is.finite(layout$y)) ||
        any(layout$x != round(layout$x)) || any(layout$y != round(layout$y)) ||
        anyDuplicated(layout[c("x", "y")])) {
        stop("Each CSV needs a unique filename and a unique pair of integer coordinates.")
    }
    paths <- vapply(layout$filename, function(filename) {
        if (startsWith(filename, "/")) filename else file.path(dirname(layout_file), filename)
    }, character(1))
    raw_datasets <- lapply(paths, read.csv)
    value_mode <- result_value_mode(raw_datasets)
    layout$Value <- vapply(seq_along(raw_datasets), function(i) {
        path <- paths[[i]]
        df <- select_result_values(raw_datasets[[i]], value_mode)
        if (metric == "total_time") {
            if (!"Time" %in% names(df) || !is.numeric(df$Time) ||
                !nrow(df) || any(!is.na(df$Time) & (!is.finite(df$Time) | df$Time < 0))) {
                stop("Total-time grids require finite nonnegative Time values in ", path)
            }
            if (anyNA(df$Time)) {
                if (value_mode == "best" && "AverageTime" %in% names(df)) return(NA_real_)
                stop("Total-time grids require finite nonnegative Time values in ", path)
            }
            return(sum(df$Time))
        }
        if (!"ImbalanceSuccessRate" %in% names(df)) {
            stop("Missing ImbalanceSuccessRate in ", path)
        }
        completed <- rep(TRUE, nrow(df))
        for (flag in c("Failed", "Timeout")) {
            if (flag %in% names(df)) completed <- completed & !is.na(df[[flag]]) & df[[flag]] == 0
        }
        rate <- df$ImbalanceSuccessRate[completed]
        if (!length(rate)) return(NA_real_)
        if (!is.numeric(rate) || anyNA(rate) || any(!is.finite(rate) | rate < 0 | rate > 1)) {
            stop("Invalid ImbalanceSuccessRate in ", path)
        }
        mean(rate < threshold)
    }, numeric(1))
    if (metric == "total_time") layout$TotalTime <- layout$Value else layout$BelowThreshold <- layout$Value
    label_format <- if (metric == "total_time") "%.0f" else "%.2f"
    layout$Label <- ifelse(is.na(layout$Value), "NA", sprintf(label_format, layout$Value))
    fill_scale <- if (metric == "total_time") {
        legend_max <- max(100, ceiling(max(c(0, layout$Value), na.rm = TRUE) / 100) * 100)
        ggplot2::scale_fill_gradientn(colors = c("#2166AC", "#FFFFFF", "#D73027"),
            limits = c(0, legend_max), breaks = seq(0, legend_max, length.out = 5),
            labels = function(x) sprintf("%.0f", x),
            na.value = "grey90", name = "Total Time (s)")
    } else {
        ggplot2::scale_fill_gradientn(colors = c("#2166AC", "#FFFFFF", "#D73027"),
            values = c(0, .5, 1), limits = c(0, 1),
            breaks = c(0, .25, .5, .75, 1),
            labels = function(x) sprintf("%.2f", x),
            na.value = "grey90", name = paste0("Below Threshold (", format(threshold, trim = TRUE), ")"))
    }
    value_text_size_mm <- 4.05
    # Integer coordinates name cells; their centers lie between integer grid lines.
    x_labels <- seq(min(layout$x), max(layout$x))
    y_labels <- seq(min(layout$y), max(layout$y))
    plot <- ggplot2::ggplot(layout, ggplot2::aes(x = x - .5, y = y - .5)) +
        ggplot2::geom_vline(xintercept = seq(min(0, min(layout$x) - 1), max(0, layout$x)),
            color = "grey90", linewidth = .3) +
        ggplot2::geom_hline(yintercept = seq(min(0, min(layout$y) - 1), max(0, layout$y)),
            color = "grey90", linewidth = .3) +
        ggplot2::geom_tile(ggplot2::aes(fill = Value), color = "black", width = .9, height = .9) +
        fill_scale +
        ggplot2::guides(fill = .imbalance_grid_colorbar()) +
        ggplot2::geom_text(ggplot2::aes(label = Label), size = value_text_size_mm) +
        ggplot2::coord_fixed(clip = "off") +
        ggplot2::scale_x_continuous(
            breaks = x_labels - .5, labels = x_labels,
            limits = c(min(0, min(layout$x) - 1), max(0, max(layout$x)) + .75),
            expand = ggplot2::expansion(mult = 0)) +
        ggplot2::scale_y_continuous(
            breaks = y_labels - .5, labels = y_labels,
            limits = c(min(0, min(layout$y) - 1), max(0, max(layout$y)) + .75),
            expand = ggplot2::expansion(mult = 0)) +
        ggplot2::labs(title = if (metric == "total_time") "Total Time Grid" else "Imbalance Grid",
            x = "Number of Spanning Tree Recalculations per BFS",
            y = "Number of BFS Origins") +
        ggplot2::theme_minimal() +
        ggplot2::theme(
            plot.title = ggplot2::element_text(size = 18, hjust = .5,
                margin = ggplot2::margin(t = 16, b = 8)),
            panel.grid.major = ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank(),
            axis.line = ggplot2::element_line(color = "black", linewidth = .6,
                arrow = grid::arrow(length = grid::unit(2, "mm"), type = "closed")),
            axis.ticks = ggplot2::element_line(color = "black"),
            axis.ticks.length = grid::unit(2, "mm"),
            axis.title.x = ggplot2::element_text(size = 14,
                margin = ggplot2::margin(t = 10)),
            axis.title.y = ggplot2::element_text(size = 14),
            axis.text = ggplot2::element_text(size = 15, color = "black"),
            legend.text = ggplot2::element_text(size = value_text_size_mm * 72.27 / 25.4),
            legend.position = "bottom")
    attr(plot, "result_value_mode") <- value_mode
    plot
}
