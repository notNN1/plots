#!/usr/bin/env Rscript
# Run from the repository root: Rscript metric_connectivity_counts.R
source("R/common.R")

data_dir <- normalizePath("data/metric", mustWork = TRUE)
csv_files <- c(
    "Refinement + New Metric" = "do_nothing_ip.standard_k32.csv",
    "No Refinement + New Metric" = "ip.standard_no.refinement_k32.csv",
    "No Refinement + Old Metric" = "ip.standard_no.refinement_old.metric_k32.csv",
    "Refinement + Old Metric" = "do_nothing_ip.standard_old.metric_k32.csv"
)

counts <- lapply(names(csv_files), function(name) {
    filename <- file.path(data_dir, csv_files[[name]])
    if (!file.exists(filename)) stop("Missing metric CSV: ", filename)
    df <- read.csv(filename, stringsAsFactors = FALSE)
    if (!all(c("Graph", "Connectivity") %in% names(df)) || !nrow(df)) {
        stop("Expected nonempty Graph and Connectivity columns in ", filename)
    }
    if (!is.numeric(df$Connectivity) || anyNA(df$Connectivity) ||
        any(!is.finite(df$Connectivity) | df$Connectivity < 0)) {
        stop("Connectivity must contain finite nonnegative counts in ", filename)
    }
    data.frame(
        Variant = name,
        Status = c("Connected", "Disconnected"),
        Count = c(sum(df$Connectivity == 0), sum(df$Connectivity > 0))
    )
})
counts <- do.call(rbind, counts)
counts$Variant <- factor(counts$Variant, levels = rev(names(csv_files)))
counts$Status <- factor(counts$Status, levels = c("Connected", "Disconnected"))
max_count <- max(counts$Count)

plot <- ggplot2::ggplot(counts,
    ggplot2::aes(x = Count, y = Variant, fill = Status)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = .8), width = .72) +
    ggplot2::geom_text(
        ggplot2::aes(label = Count),
        position = ggplot2::position_dodge(width = .8),
        hjust = -.25, size = 5
    ) +
    ggplot2::scale_fill_manual(values = c("Connected" = "#2C7FB8", "Disconnected" = "#D95F0E")) +
    ggplot2::scale_x_continuous(
        breaks = seq(0, max_count, by = 10),
        limits = c(0, max_count * 1.18),
        expand = ggplot2::expansion(mult = c(0, 0))
    ) +
    ggplot2::labs(
        title = "Connected vs. Disconnected Graphs",
        x = "Number of Graphs",
        y = NULL,
        fill = NULL
    ) +
    default_theme +
    ggplot2::theme(
        aspect.ratio = NULL,
        legend.position = "bottom",
        axis.title.x = ggplot2::element_text(size = 14),
        axis.text = ggplot2::element_text(size = 12),
        legend.text = ggplot2::element_text(size = 16),
        plot.title = ggplot2::element_text(size = 16, hjust = .5)
    )

ggplot2::ggsave("metric_connectivity_counts.pdf", plot, width = 11, height = 7)
