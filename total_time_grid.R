#!/usr/bin/env Rscript
source("R/imbalance_success_grid_plot.R")

# Uses the same CSV-to-coordinate mapping as the imbalance grid.
layout_file <- "data/imbalance_success_grid_layout.csv"
plot <- create_total_time_grid_plot(layout_file)
ggplot2::ggsave("total_time_grid.pdf", plot, width = 8, height = 6)
print(plot)
