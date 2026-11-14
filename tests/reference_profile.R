source("R/common.R")
source("R/performance_profile_plot.R")

# Both algorithms exceed the achievable K components, so neither should score 1.
a <- data.frame(Algorithm = "a", Graph = "g", K = 8,
    Components = 16, Failed = FALSE, Timeout = FALSE, Imbalanced = FALSE)
b <- a
b$Algorithm <- "b"
b$Components <- 24
options <- list(column.objective = "Components", column.imbalanced = "Imbalanced",
    segments = list(list(trans = "identity", to = 4, width = 3,
                         breaks = 1:4, labels = as.character(1:4))))

fixed <- do.call(create_imbalance_performance_profile_plot,
    c(list(a, b), options, list(column.reference = "K")))
observed <- do.call(create_imbalance_performance_profile_plot, c(list(a, b), options))
# The axis transformation subtracts 1 on this identity segment.
stopifnot(all(fixed$data$Ratio[fixed$data$Algorithm == "a"] == 1),
          all(fixed$data$Ratio[fixed$data$Algorithm == "b"] == 2),
          all(observed$data$Ratio[observed$data$Algorithm == "a"] == 0),
          all(observed$data$Ratio[observed$data$Algorithm == "b"] == .5))
invisible(ggplot2::ggplot_build(fixed))

a$K <- b$K <- 0
stopifnot(inherits(try(do.call(create_imbalance_performance_profile_plot,
    c(list(a, b), options, list(column.reference = "K"))), silent = TRUE), "try-error"))
cat("Reference profile checks passed\n")
