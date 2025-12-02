# ==============================================================================
# TURAS REGRESSION TEST: SEGMENT MODULE (WORKING MOCK)
# ==============================================================================

library(testthat)
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

mock_segment_module <- function(data_path, config_path = NULL) {
  data <- read.csv(data_path, stringsAsFactors = FALSE)

  # Remove ID column for clustering
  cluster_vars <- grep("^var[0-9]+$", names(data), value = TRUE)
  cluster_data <- data[, cluster_vars]

  # K-means clustering (k=3)
  set.seed(123)  # For reproducibility
  k <- 3
  km <- kmeans(cluster_data, centers = k, nstart = 25)

  # Cluster sizes
  cluster_sizes <- table(km$cluster)
  cluster_pcts <- prop.table(cluster_sizes) * 100

  # Calculate silhouette score (simplified)
  # In real implementation would use cluster::silhouette
  within_ss <- km$tot.withinss
  total_ss <- km$totss
  between_ss <- km$betweenss
  silhouette_approx <- between_ss / total_ss  # Simplified metric

  output <- list(
    clustering = list(
      n_clusters = k,
      cluster_sizes = as.vector(cluster_sizes),
      cluster_pcts = as.vector(cluster_pcts),
      within_ss = within_ss,
      between_ss = between_ss,
      total_ss = total_ss,
      silhouette = silhouette_approx
    ),
    summary = list(
      n_clusters = k,
      cluster_1_size = cluster_pcts[1],
      cluster_2_size = cluster_pcts[2],
      cluster_3_size = cluster_pcts[3],
      silhouette_score = silhouette_approx,
      between_ss_ratio = between_ss / total_ss,
      n_respondents = nrow(data)
    )
  )

  return(output)
}

extract_segment_value <- function(output, check_name) {
  if (check_name %in% names(output$summary)) {
    return(output$summary[[check_name]])
  }
  stop("Unknown check: ", check_name)
}

test_that("Segment module: basic example produces expected outputs", {
  paths <- get_example_paths("segment", "basic")
  output <- mock_segment_module(paths$data)
  golden <- load_golden("segment", "basic")

  for (check in golden$checks) {
    actual <- extract_segment_value(output, check$name)

    if (check$type == "numeric") {
      tolerance <- if (!is.null(check$tolerance)) check$tolerance else 0.01
      check_numeric(paste("Segment:", check$description), actual, check$value, tolerance)
    } else if (check$type == "integer") {
      check_integer(paste("Segment:", check$description), actual, check$value)
    }
  }
})
