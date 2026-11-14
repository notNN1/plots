# Keep standalone plot outputs organized by experiment, preserving filenames.
plot_output_path <- function(filename, root = "pdf") {
    name <- basename(filename)
    category_name <- sub("_(best|average)(?=\\.pdf$)", "", name, perl = TRUE)
    category <- if (startsWith(name, "metric_")) {
        if (grepl("_k[0-9]+\\.pdf$", category_name)) {
            file.path("metric", sub(".*_(k[0-9]+)\\.pdf$", "\\1", category_name))
        } else if (name == "metric_performance_profile.pdf") {
            "metric"
        } else {
            file.path("metric", "k32")
        }
    } else if (grepl("^st_(bfs|bs)_", name)) {
        "st_bfs"
    } else if (startsWith(name, "st_")) {
        "st"
    } else if (grepl("grid\\.pdf$", name)) {
        "grids"
    } else if (name %in% c("examples.pdf", "breakdown.pdf")) {
        "examples"
    } else if (name == "tests.pdf") {
        "tests"
    } else {
        "misc"
    }
    directory <- file.path(root, category)
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    file.path(directory, name)
}
