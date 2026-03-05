# Tests for end-to-end integration
# Part of Turas Segment Module v11.0 test suite

# =============================================================================
# INTEGRATION TEST HELPERS
# =============================================================================

# Prepare data for clustering without loading from file.
# Simulates the data prep pipeline steps manually.
prepare_test_data_for_clustering <- function(test_data, config) {
  data <- test_data$data
  clustering_vars <- config$clustering_vars

  # Handle missing data: listwise deletion for simplicity
  clustering_data <- data[, clustering_vars, drop = FALSE]
  complete_rows <- complete.cases(clustering_data)
  data <- data[complete_rows, ]
  clustering_data <- clustering_data[complete_rows, ]

  # Standardize
  scaled_matrix <- scale(clustering_data, center = TRUE, scale = TRUE)

  # Build data_list structure matching what the clustering functions expect
  data_list <- list(
    data = data,
    clustering_data = clustering_data,
    scaled_data = scaled_matrix,
    config = config,
    n_original = test_data$n,
    scale_params = list(
      center = attr(scaled_matrix, "scaled:center"),
      scale = attr(scaled_matrix, "scaled:scale")
    ),
    outlier_flags = rep(FALSE, nrow(data)),
    outlier_result = NULL,
    outlier_handling = list(handling = "none", n_outliers = 0),
    variable_selection_result = NULL
  )

  data_list
}


# =============================================================================
# TEST: Full K-means final pipeline (generate -> config -> cluster -> validate -> profile -> output)
# =============================================================================

test_that("full K-means final pipeline completes end-to-end", {
  # Step 1: Generate test data
  test_data <- generate_segment_test_data(n = 100, k_true = 3, n_vars = 5,
                                           missing_rate = 0.02, n_outliers = 0,
                                           seed = 42)

  # Step 2: Create config
  config <- generate_test_config(test_data, mode = "final", method = "kmeans",
                                  k_fixed = 3)
  config$clustering_vars <- test_data$clustering_vars[1:5]
  config$nstart <- 10
  config$standardize <- TRUE
  config$missing_data <- "listwise_deletion"

  # Step 3: Prepare data manually (bypasses file loading)
  data_list <- prepare_test_data_for_clustering(test_data, config)

  # Step 4: Run clustering
  guard <- segment_guard_init()
  set.seed(42)
  model <- kmeans(data_list$scaled_data, centers = 3, nstart = 10)

  clustering_result <- list(
    clusters = as.integer(model$cluster),
    k = 3,
    centers = model$centers,
    method = "kmeans",
    model = model,
    data_list = data_list,
    method_info = list(
      algorithm = "Hartigan-Wong",
      nstart = 10,
      totss = model$totss,
      withinss = model$withinss,
      tot_withinss = model$tot.withinss,
      betweenss = model$betweenss,
      size = model$size
    )
  )

  # Step 5: Validate
  validation <- calculate_validation_metrics(
    data = data_list$scaled_data,
    model = model,
    k = 3
  )

  expect_true(!is.null(validation$avg_silhouette))
  expect_true(validation$avg_silhouette > 0)

  # Step 6: Profile
  profile <- create_full_segment_profile(
    data = data_list$data,
    clusters = clustering_result$clusters,
    clustering_vars = config$clustering_vars,
    profile_vars = config$profile_vars
  )

  expect_true(!is.null(profile$clustering_profile))
  expect_true(!is.null(profile$segment_sizes))
  expect_equal(profile$k, 3)

  # Step 7: Output - segment assignments
  output_dir <- file.path(tempdir(), "test_integration_final")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  assignments_path <- file.path(output_dir, "test_assignments.xlsx")

  segment_names <- generate_segment_names(3, method = "simple")

  export_segment_assignments(
    data = data_list$data,
    clusters = clustering_result$clusters,
    segment_names = segment_names,
    id_var = config$id_variable,
    output_path = assignments_path
  )

  expect_true(file.exists(assignments_path))
})


# =============================================================================
# TEST: Full exploration pipeline (generate -> explore -> recommend)
# =============================================================================

test_that("full exploration pipeline completes end-to-end", {
  # Step 1: Generate test data
  test_data <- generate_segment_test_data(n = 100, k_true = 3, n_vars = 5,
                                           missing_rate = 0.02, n_outliers = 0,
                                           seed = 42)

  # Step 2: Create exploration config
  config <- generate_test_config(test_data, mode = "exploration", method = "kmeans")
  config$clustering_vars <- test_data$clustering_vars[1:5]
  config$k_min <- 2
  config$k_max <- 4
  config$nstart <- 10
  config$standardize <- TRUE
  config$missing_data <- "listwise_deletion"
  config$min_segment_size_pct <- 5

  # Step 3: Prepare data
  data_list <- prepare_test_data_for_clustering(test_data, config)

  # Step 4: Run exploration (multiple k values)
  models <- list()
  for (k in config$k_min:config$k_max) {
    set.seed(42)
    models[[as.character(k)]] <- kmeans(data_list$scaled_data, centers = k, nstart = 10)
  }

  exploration_result <- list(
    models = models,
    k_range = config$k_min:config$k_max,
    data_list = data_list
  )

  # Step 5: Calculate exploration metrics
  metrics_result <- calculate_exploration_metrics(exploration_result)

  expect_true(is.data.frame(metrics_result$metrics_df))
  expect_equal(nrow(metrics_result$metrics_df), 3)  # k=2,3,4

  # Step 6: Get recommendation
  recommendation <- recommend_k(metrics_result$metrics_df,
                                 min_segment_size_pct = config$min_segment_size_pct)

  expect_true(!is.null(recommendation$recommended_k))
  expect_true(recommendation$recommended_k >= config$k_min)
  expect_true(recommendation$recommended_k <= config$k_max)
})


# =============================================================================
# TEST: Result structure has all expected fields for final mode
# =============================================================================

test_that("final mode result has all expected fields", {
  test_data <- generate_segment_test_data(n = 100, k_true = 3, n_vars = 5,
                                           missing_rate = 0, n_outliers = 0,
                                           seed = 42)

  config <- generate_test_config(test_data, mode = "final", method = "kmeans",
                                  k_fixed = 3)
  config$clustering_vars <- test_data$clustering_vars[1:5]
  config$nstart <- 10
  config$standardize <- TRUE

  data_list <- prepare_test_data_for_clustering(test_data, config)

  set.seed(42)
  model <- kmeans(data_list$scaled_data, centers = 3, nstart = 10)

  # Build standard result
  final_result <- list(
    clusters = as.integer(model$cluster),
    k = 3,
    centers = model$centers,
    method = "kmeans",
    model = model,
    data_list = data_list
  )

  # Validate all standard fields exist
  expect_true(!is.null(final_result$clusters))
  expect_true(!is.null(final_result$k))
  expect_true(!is.null(final_result$centers))
  expect_true(!is.null(final_result$method))
  expect_true(!is.null(final_result$model))

  # Check types
  expect_type(final_result$clusters, "integer")
  expect_equal(final_result$k, 3)
  expect_true(is.matrix(final_result$centers))
  expect_equal(final_result$method, "kmeans")
  expect_true(inherits(final_result$model, "kmeans"))

  # Check dimensions
  expect_equal(length(final_result$clusters), nrow(data_list$data))
  expect_equal(nrow(final_result$centers), 3)
  expect_equal(ncol(final_result$centers), 5)
})


# =============================================================================
# TEST: Result structure has all expected fields for exploration mode
# =============================================================================

test_that("exploration mode result has all expected fields", {
  test_data <- generate_segment_test_data(n = 100, k_true = 3, n_vars = 5,
                                           missing_rate = 0, n_outliers = 0,
                                           seed = 42)

  config <- generate_test_config(test_data, mode = "exploration", method = "kmeans")
  config$clustering_vars <- test_data$clustering_vars[1:5]
  config$k_min <- 2
  config$k_max <- 4
  config$nstart <- 10
  config$standardize <- TRUE
  config$min_segment_size_pct <- 5

  data_list <- prepare_test_data_for_clustering(test_data, config)

  models <- list()
  for (k in 2:4) {
    set.seed(42)
    models[[as.character(k)]] <- kmeans(data_list$scaled_data, centers = k, nstart = 10)
  }

  exploration_result <- list(
    models = models,
    k_range = 2:4,
    data_list = data_list
  )

  # Validate exploration result structure
  expect_true(!is.null(exploration_result$models))
  expect_true(!is.null(exploration_result$k_range))
  expect_true(!is.null(exploration_result$data_list))

  expect_true(is.list(exploration_result$models))
  expect_equal(length(exploration_result$models), 3)  # k=2,3,4

  # Each model should be a valid kmeans object
  for (k_str in names(exploration_result$models)) {
    m <- exploration_result$models[[k_str]]
    expect_true(inherits(m, "kmeans"),
                info = sprintf("Model for k=%s is not a kmeans object", k_str))
    expect_true(!is.null(m$cluster))
    expect_true(!is.null(m$centers))
    expect_true(!is.null(m$tot.withinss))
  }

  # Validate metrics
  metrics_result <- calculate_exploration_metrics(exploration_result)
  expect_true(is.data.frame(metrics_result$metrics_df))
  expect_equal(nrow(metrics_result$metrics_df), 3)
})


# =============================================================================
# TEST: Segment assignments file is created and readable
# =============================================================================

test_that("segment assignments file is created and contains correct data", {
  skip_if_not_installed("readxl")

  test_data <- generate_segment_test_data(n = 100, k_true = 3, n_vars = 5,
                                           missing_rate = 0, n_outliers = 0,
                                           seed = 42)

  config <- generate_test_config(test_data, mode = "final", method = "kmeans",
                                  k_fixed = 3)
  config$clustering_vars <- test_data$clustering_vars[1:5]
  config$nstart <- 10
  config$standardize <- TRUE

  data_list <- prepare_test_data_for_clustering(test_data, config)

  set.seed(42)
  model <- kmeans(data_list$scaled_data, centers = 3, nstart = 10)
  clusters <- as.integer(model$cluster)
  segment_names <- generate_segment_names(3, method = "simple")

  output_dir <- file.path(tempdir(), "test_integration_assignments")
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  assignments_path <- file.path(output_dir, "segment_assignments.xlsx")

  export_segment_assignments(
    data = data_list$data,
    clusters = clusters,
    segment_names = segment_names,
    id_var = config$id_variable,
    output_path = assignments_path
  )

  # Verify file exists and is readable
  expect_true(file.exists(assignments_path))

  result_df <- readxl::read_xlsx(assignments_path)

  # Verify content
  expect_equal(nrow(result_df), nrow(data_list$data))
  expect_true(config$id_variable %in% names(result_df))
  expect_true("segment_id" %in% names(result_df))
  expect_true("segment_name" %in% names(result_df))

  # All respondent IDs should be present
  expect_equal(
    sort(result_df[[config$id_variable]]),
    sort(data_list$data[[config$id_variable]])
  )

  # Segment IDs should match the clusters
  expect_equal(result_df$segment_id, clusters)

  # All segment names should be valid
  expect_true(all(result_df$segment_name %in% segment_names))
})


# =============================================================================
# TEST: Pipeline with k=2 completes successfully (minimal case)
# =============================================================================

test_that("pipeline with minimal k=2 completes successfully", {
  test_data <- generate_segment_test_data(n = 100, k_true = 2, n_vars = 5,
                                           missing_rate = 0, n_outliers = 0,
                                           seed = 99)

  config <- generate_test_config(test_data, mode = "final", method = "kmeans",
                                  k_fixed = 2)
  config$clustering_vars <- test_data$clustering_vars[1:5]
  config$nstart <- 10
  config$standardize <- TRUE

  data_list <- prepare_test_data_for_clustering(test_data, config)

  set.seed(99)
  model <- kmeans(data_list$scaled_data, centers = 2, nstart = 10)

  # Validate
  validation <- calculate_validation_metrics(
    data = data_list$scaled_data,
    model = model,
    k = 2
  )

  expect_true(validation$avg_silhouette > 0)
  expect_true(validation$betweenss_totss > 0)
  expect_true(validation$betweenss_totss < 1)

  # Profile
  profile <- create_full_segment_profile(
    data = data_list$data,
    clusters = as.integer(model$cluster),
    clustering_vars = config$clustering_vars
  )

  expect_equal(profile$k, 2)
  expect_equal(nrow(profile$segment_sizes), 2)
  expect_equal(sum(profile$segment_sizes$Count), nrow(data_list$data))
})
