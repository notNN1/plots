#!/usr/bin/env Rscript
# Run from the repository root: Rscript scripts/st_bfs/st_bfs_hyperparameters.R
source("R/plot_output_path.R")
source("R/imbalance_success_grid_plot.R")

data_dirs <- c(
    "Original" = "data/st_bfs_hyperparameters_normal",
    "Advanced" = "data/st_bfs_hyperparameters_advanced",
    "Subtree" = "data/st_bfs_hyperparameters_subtree",
    "Subtree + Updates" = "data/st_bfs_hyperparameters_subtree_recalculation"
)
threshold <- 0.75

# Derive coordinates directly from filenames, including variants ending in _k32.
pattern <- "^.*stbfs\\.origins\\.([0-9]+)_stbfs\\.recalculations\\.([0-9]+)_.*k([0-9]+)\\.csv$"
load_layout <- function(data_dir) {
    data_dir <- normalizePath(data_dir, mustWork = TRUE)
    files <- sort(list.files(data_dir, pattern = "\\.csv$", full.names = TRUE))
    if (!length(files)) stop("No CSV files found in: ", data_dir)
    filenames <- basename(files)
    if (any(!grepl(pattern, filenames))) {
        stop("Cannot extract origins, recalculations, and K from: ",
             paste(filenames[!grepl(pattern, filenames)], collapse = ", "))
    }
    data.frame(
        filename = files,
        x = as.integer(sub(pattern, "\\2", filenames)),
        y = as.integer(sub(pattern, "\\1", filenames)),
        K = as.integer(sub(pattern, "\\3", filenames))
    )
}
layouts <- lapply(data_dirs, load_layout)

# Keep one legend below the group and one title above it.
assemble_group <- function(grids, title, k) {
    grids <- lapply(grids, function(plot) {
        for (layer in plot$layers) {
            if (inherits(layer$geom, "GeomText")) layer$aes_params$size <- 7.5
        }
        plot + ggplot2::labs(x = "Number of Spanning Trees", y = "Number of BFS") +
            ggplot2::theme(
                plot.subtitle = ggplot2::element_text(size = 26,
                    margin = ggplot2::margin(b = 14)),
                axis.title.x = ggplot2::element_text(size = 22,
                    margin = ggplot2::margin(t = 14)),
                axis.title.y = ggplot2::element_text(size = 22,
                    margin = ggplot2::margin(r = 14)),
                axis.text = ggplot2::element_text(size = 24),
                legend.text = ggplot2::element_text(size = 24),
                legend.title = ggplot2::element_text(size = 24),
                legend.margin = ggplot2::margin(t = 12, b = 12),
                plot.margin = ggplot2::margin(16, 6, 16, 6)
            ) +
            ggplot2::guides(fill = ggplot2::guide_colorbar(
                barwidth = grid::unit(20, "cm"),
                barheight = grid::unit(1, "cm"),
                direction = "horizontal", title.position = "top",
                title.theme = ggplot2::element_text(size = 24, hjust = .5)))
    })
    legend_plot <- ggplot2::ggplotGrob(grids[[1]])
    legend_indices <- which(grepl("^guide-box", legend_plot$layout$name))
    legend_indices <- legend_indices[vapply(legend_plot$grobs[legend_indices],
        function(grob) inherits(grob, "gtable"), logical(1))]
    if (length(legend_indices) != 1L) stop("Expected one shared fill legend.")
    legend <- legend_plot$grobs[[legend_indices]]
    panels <- lapply(grids, function(plot) {
        ggplot2::ggplotGrob(plot + ggplot2::labs(title = NULL) +
            ggplot2::theme(legend.position = "none"))
    })
    # Move the columns inward without resizing the grids or their text.
    # Fixed-aspect plots otherwise retain whitespace inside equal-width cells.
    panels <- lapply(seq_along(panels), function(i) {
        shift <- if (i %% 2 == 1) 1 else -1
        grid::grobTree(panels[[i]], vp = grid::viewport(
            x = grid::unit(.5, "npc") + grid::unit(shift, "in")))
    })
    gridExtra::arrangeGrob(grobs = panels, ncol = 2,
        top = gridExtra::arrangeGrob(
            grid::textGrob(title, gp = grid::gpar(fontsize = 34)),
            grid::textGrob(paste("K =", k), gp = grid::gpar(fontsize = 26)),
            ncol = 1, heights = grid::unit(c(44, 36), "pt")),
        bottom = legend)
}

# Existing grid helpers read a layout CSV; absolute paths also work in Docker.
layout_file <- tempfile(fileext = ".csv")
plots <- tryCatch({
    grids <- list()
    for (k in sort(unique(unlist(lapply(layouts, function(layout) layout$K))))) {
        time_grids <- list()
        imbalance_grids <- list()
        for (variant in names(layouts)) {
            layout <- layouts[[variant]]
            if (!any(layout$K == k)) stop("Missing K = ", k, " for ", variant)
            write.csv(layout[layout$K == k, c("filename", "x", "y")],
                      layout_file, row.names = FALSE)
            time_grids[[variant]] <- create_total_time_grid_plot(layout_file) +
                ggplot2::labs(subtitle = variant)
            imbalance_grids[[variant]] <-
                create_imbalance_success_grid_plot(layout_file, threshold = threshold) +
                    ggplot2::labs(subtitle = variant)
        }
        # A shared time legend requires identical color limits and breaks.
        time_max <- max(100, ceiling(max(vapply(time_grids,
            function(plot) max(plot$data$Value), numeric(1))) / 100) * 100)
        time_grids <- lapply(time_grids, function(plot) {
            scale <- plot$scales$get_scales("fill")
            scale$limits <- c(0, time_max)
            scale$breaks <- seq(0, time_max, length.out = 5)
            plot
        })
        grids <- c(grids, list(
            assemble_group(imbalance_grids, "Imbalance Grid", k),
            assemble_group(time_grids, "Total Time Grid", k)
        ))
    }
    grids
}, finally = unlink(layout_file))

# Each group gets its own PDF, with one page per K.
output_files <- c(
    "st_bfs_hyperparameters_imbalance.pdf",
    "st_bfs_hyperparameters_total_time.pdf"
)
for (group in seq_along(output_files)) {
    grDevices::pdf(plot_output_path(output_files[[group]]), width = 16, height = 16)
    tryCatch({
        for (i in seq.int(group, length(plots), by = 2)) {
            grid::grid.newpage()
            grid::grid.draw(plots[[i]])
        }
    }, finally = grDevices::dev.off())
}
