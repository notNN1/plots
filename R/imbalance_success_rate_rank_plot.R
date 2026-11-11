create_imbalance_success_rate_rank_plot <- function(
    data,
    title = "Imbalance Success Rate by Graph",
    subtitle = NULL,
    label_size = 8) {
    required <- c("Graph", "ImbalanceSuccessRate")
    missing <- setdiff(required, names(data))
    if (length(missing)) {
        stop("Missing required columns: ", paste(missing, collapse = ", "))
    }
    if (!nrow(data) || anyNA(data$Graph) || any(!nzchar(data$Graph)) ||
        anyDuplicated(data$Graph)) {
        stop("Graph names must be nonempty, unique, and the data must not be empty.")
    }
    rate <- data$ImbalanceSuccessRate
    if (!is.numeric(rate) || anyNA(rate) ||
        any(!is.finite(rate) | rate < 0 | rate > 1)) {
        stop("ImbalanceSuccessRate must contain finite values between 0 and 1.")
    }
    if (!is.numeric(label_size) || length(label_size) != 1L ||
        !is.finite(label_size) || label_size <= 0) {
        stop("label_size must be a positive finite number.")
    }

    ordering <- order(rate, data$Graph)
    ranked <- data.frame(
        Graph = factor(data$Graph, levels = rev(data$Graph[ordering])),
        ImbalanceSuccessRate = rate
    )

    ggplot2::ggplot(ranked,
        ggplot2::aes(x = ImbalanceSuccessRate, y = Graph)) +
        ggplot2::geom_col(fill = "#2C7FB8", width = .72) +
        ggplot2::geom_text(
            ggplot2::aes(label = sprintf("%.0f%%", 100 * ImbalanceSuccessRate)),
            hjust = -.18, size = label_size
        ) +
        ggplot2::scale_x_continuous(
            name = "Imbalance Success Rate",
            breaks = seq(0, 1, .1),
            labels = function(x) sprintf("%.0f%%", 100 * x),
            limits = c(0, 1.1),
            expand = ggplot2::expansion(mult = c(0, 0))
        ) +
        ggplot2::labs(title = title, subtitle = subtitle, y = "Graph") +
        ggplot2::theme_bw() +
        ggplot2::theme(
            axis.title = ggplot2::element_text(size = 14),
            axis.text.x = ggplot2::element_text(size = 10),
            axis.text.y = ggplot2::element_text(size = label_size),
            plot.title = ggplot2::element_text(size = 16, hjust = .5),
            plot.subtitle = ggplot2::element_text(size = 14, hjust = .5),
            panel.grid.major.y = ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank()
        )
}
