#!/usr/bin/env Rscript
# Run from the repository root: Rscript st_hyperparameters_advanced.R
source("R/imbalance_success_grid_plot.R")

data_dir <- normalizePath("data/st_hyperparameters_advanced", mustWork = TRUE)
threshold <- 0.75
files <- sort(list.files(data_dir, pattern = "\\.csv$", full.names = TRUE))
if (!length(files)) stop("No CSV files found in: ", data_dir)
pattern <- "^.*_st\\.recalculations\\.([0-9]+)_k([0-9]+)\\.csv$"
filenames <- basename(files)
if (any(!grepl(pattern, filenames))) {
    stop("Cannot extract recalculations and K from: ",
         paste(filenames[!grepl(pattern, filenames)], collapse = ", "))
}
layout <- data.frame(
    filename = files,
    x = as.integer(sub(pattern, "\\1", filenames)),
    y = 1,
    K = as.integer(sub(pattern, "\\2", filenames))
)

# These experiments vary only the number of spanning trees, so use a single row.
style_grid <- function(plot, k) {
    for (layer in plot$layers) {
        if (inherits(layer$geom, "GeomText")) layer$aes_params$size <- 7.5
    }
    plot + ggplot2::labs(x = "Number of Spanning Trees", y = NULL,
        subtitle = paste("K =", k)) +
        ggplot2::theme(
            plot.title = ggplot2::element_text(size = 30, hjust = .5),
            plot.subtitle = ggplot2::element_text(size = 24, hjust = .5),
            axis.title.x = ggplot2::element_text(size = 22),
            axis.text.x = ggplot2::element_text(size = 24),
            axis.text.y = ggplot2::element_blank(),
            axis.ticks.y = ggplot2::element_blank(),
            axis.line.y = ggplot2::element_blank(),
            legend.text = ggplot2::element_text(size = 22),
            plot.margin = ggplot2::margin(18, 24, 18, 24)
        ) +
        ggplot2::guides(fill = ggplot2::guide_colorbar(
            barwidth = grid::unit(20, "cm"), barheight = grid::unit(1, "cm"),
            direction = "horizontal", title.position = "top",
            title.theme = ggplot2::element_text(size = 22, hjust = .5)))
}

layout_file <- tempfile(fileext = ".csv")
plots <- tryCatch({
    grids <- list()
    for (k in sort(unique(layout$K))) {
        write.csv(layout[layout$K == k, c("filename", "x", "y")],
                  layout_file, row.names = FALSE)
        grids <- c(grids, list(
            style_grid(create_imbalance_success_grid_plot(layout_file, threshold), k),
            style_grid(create_total_time_grid_plot(layout_file), k)
        ))
    }
    grids
}, finally = unlink(layout_file))

output_files <- c(
    "st_hyperparameters_advanced_imbalance.pdf",
    "st_hyperparameters_advanced_total_time.pdf"
)
for (group in seq_along(output_files)) {
    grDevices::pdf(output_files[[group]], width = 16, height = 6)
    tryCatch({
        for (i in seq.int(group, length(plots), by = 2)) print(plots[[i]])
    }, finally = grDevices::dev.off())
}
