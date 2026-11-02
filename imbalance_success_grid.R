#!/usr/bin/env Rscript
source("R/imbalance_success_grid_plot.R")

# Edit filename,x,y in this file to position each CSV. Larger y is higher.
layout_file <- "data/imbalance_success_grid_layout.csv"
threshold <- 0.75
plot <- create_imbalance_success_grid_plot(layout_file, threshold = threshold)
ggplot2::ggsave("imbalance_success_grid.pdf", plot, width = 8, height = 6)
print(plot)
