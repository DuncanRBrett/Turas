# Tests for cluster validation metrics
# Part of Turas Segment Module v11.0 test suite

# =============================================================================
# TEST SETUP
# =============================================================================

create_validation_test_data <- function() {
  set.seed(42)
  n <- 100
  p <- 5

  # 3 well-separated clusters
  cluster1 <- matrix(rnorm(34 * p, mean = 3, sd = 0.5), ncol = p)
  cluster2 <- matrix(rnorm(33 * p, mean = 0, sd = 0.5), ncol = p)
  cluster3 <- matrix(rnorm(33 * p, mean = -3, sd = 0.5), ncol = p)

  scaled_data <- rbind(cluster1, cluster2, cluster3)
  colnames(scaled_data) <- paste0("v", 1:p)

  # Run k-means to get a model
  set.seed(42)
  model <- kmeans(scaled_data, centers = 3, nstart = 25)

  list(
    scaled_data = scaled_data,
    model = model,
    k = 3,
    n = n,
    p = p
  )
}


# =============================================================================
# TEST: calculate_validation_metrics returns expected fields
# =============================================================================

test_that("calculate_validation_metrics returns avg_silhouette, tot_withinss, betweenss, betweenss_totss", {
  td <- create_validation_test_data()

  metrics <- calculate_validation_metrics(
    data = td$scaled_data,
    model = td$model,
    k = td$k
  )

  expect_true(!is.null(metrics$avg_silhouette))
  expect_true(!is.null(metrics$tot_withinss))
  expect_true(!is.null(metrics$betweenss))
  expect_true(!is.null(metrics$betweenss_totss))
})


# =============================================================================
# TEST: silhouette is between -1 and 1
# =============================================================================

test_that("average silhouette is between -1 and 1", {
  td <- create_validation_test_data()

  metrics <- calculate_validation_metrics(
    data = td$scaled_data,
    model = td$model,
    k = td$k
  )

  expect_true(is.numeric(metrics$avg_silhouette))
  expect_true(metrics$avg_silhouette >= -1)
  expect_true(metrics$avg_silhouette <= 1)

  # For well-separated data, silhouette should be positive
  expect_true(metrics$avg_silhouette > 0)
})


# =============================================================================
# TEST: betweenss_totss is between 0 and 1
# =============================================================================

test_that("betweenss_totss ratio is between 0 and 1", {
  td <- create_validation_test_data()

  metrics <- calculate_validation_metrics(
    data = td$scaled_data,
    model = td$model,
    k = td$k
  )

  expect_true(is.numeric(metrics$betweenss_totss))
  expect_true(metrics$betweenss_totss >= 0)
  expect_true(metrics$betweenss_totss <= 1)

  # For well-separated clusters, ratio should be high
  expect_true(metrics$betweenss_totss > 0.5)
})


# =============================================================================
# TEST: tot_withinss and betweenss are positive
# =============================================================================

test_that("tot_withinss and betweenss are positive numeric values", {
  td <- create_validation_test_data()

  metrics <- calculate_validation_metrics(
    data = td$scaled_data,
    model = td$model,
    k = td$k
  )

  expect_true(is.numeric(metrics$tot_withinss))
  expect_true(metrics$tot_withinss > 0)

  expect_true(is.numeric(metrics$betweenss))
  expect_true(metrics$betweenss > 0)
})


# =============================================================================
# TEST: calculate_exploration_metrics works with multiple k results
# =============================================================================

test_that("calculate_exploration_metrics works with multiple k values", {
  set.seed(42)
  n <- 100
  p <- 5

  cluster1 <- matrix(rnorm(34 * p, mean = 3, sd = 0.5), ncol = p)
  cluster2 <- matrix(rnorm(33 * p, mean = 0, sd = 0.5), ncol = p)
  cluster3 <- matrix(rnorm(33 * p, mean = -3, sd = 0.5), ncol = p)
  scaled_data <- rbind(cluster1, cluster2, cluster3)
  colnames(scaled_data) <- paste0("v", 1:p)

  # Build exploration result with models for k=2, 3, 4
  models <- list()
  for (k in 2:4) {
    set.seed(42)
    models[[as.character(k)]] <- kmeans(scaled_data, centers = k, nstart = 25)
  }

  config <- list(k_min = 2, k_max = 4, min_segment_size_pct = 5)

  exploration_result <- list(
    models = models,
    k_range = 2:4,
    data_list = list(
      scaled_data = scaled_data,
      config = config
    )
  )

  result <- calculate_exploration_metrics(exploration_result)

  # Should return a metrics_df
  expect_true(!is.null(result$metrics_df))
  expect_true(is.data.frame(result$metrics_df))
  expect_equal(nrow(result$metrics_df), 3)  # k=2,3,4

  # Check expected columns
  expect_true("k" %in% names(result$metrics_df))
  expect_true("avg_silhouette_width" %in% names(result$metrics_df))
  expect_true("betweenss_totss" %in% names(result$metrics_df))
  expect_true("tot.withinss" %in% names(result$metrics_df))
  expect_true("min_segment_pct" %in% names(result$metrics_df))

  # k values should match
  expect_equal(result$metrics_df$k, c(2, 3, 4))

  # All silhouette values should be between -1 and 1
  expect_true(all(result$metrics_df$avg_silhouette_width >= -1))
  expect_true(all(result$metrics_df$avg_silhouette_width <= 1))
})


# =============================================================================
# TEST: recommend_k returns a valid k within tested range
# =============================================================================

test_that("recommend_k returns a valid k within the tested range", {
  set.seed(42)
  n <- 100
  p <- 5

  cluster1 <- matrix(rnorm(34 * p, mean = 3, sd = 0.5), ncol = p)
  cluster2 <- matrix(rnorm(33 * p, mean = 0, sd = 0.5), ncol = p)
  cluster3 <- matrix(rnorm(33 * p, mean = -3, sd = 0.5), ncol = p)
  scaled_data <- rbind(cluster1, cluster2, cluster3)
  colnames(scaled_data) <- paste0("v", 1:p)

  # Build exploration result
  models <- list()
  for (k in 2:5) {
    set.seed(42)
    models[[as.character(k)]] <- kmeans(scaled_data, centers = k, nstart = 25)
  }

  exploration_result <- list(
    models = models,
    k_range = 2:5,
    data_list = list(
      scaled_data = scaled_data,
      config = list(k_min = 2, k_max = 5, min_segment_size_pct = 5)
    )
  )

  metrics_result <- calculate_exploration_metrics(exploration_result)
  recommendation <- recommend_k(metrics_result$metrics_df, min_segment_size_pct = 5)

  expect_true(!is.null(recommendation$recommended_k))
  expect_true(recommendation$recommended_k >= 2)
  expect_true(recommendation$recommended_k <= 5)
  expect_true(!is.null(recommendation$reason))
  expect_type(recommendation$reason, "character")
})


# =============================================================================
# TEST: recommend_k handles all k values below size threshold
# =============================================================================

test_that("recommend_k still returns a value even if no k meets size threshold", {
  # Create a metrics_df where all segments are small
  metrics_df <- data.frame(
    k = c(2, 3, 4),
    tot.withinss = c(100, 80, 60),
    betweenss = c(50, 70, 90),
    totss = c(150, 150, 150),
    betweenss_totss = c(0.33, 0.47, 0.60),
    avg_silhouette_width = c(0.5, 0.6, 0.4),
    min_segment_pct = c(3, 2, 1)  # All below threshold
  )

  # Should still return a recommendation (outputs cat message instead of warning)
  recommendation <- recommend_k(metrics_df, min_segment_size_pct = 10)

  expect_true(!is.null(recommendation$recommended_k))
  expect_true(recommendation$recommended_k %in% c(2, 3, 4))
})


# =============================================================================
# TEST: calculate_separation_metrics returns expected fields
# =============================================================================

test_that("calculate_separation_metrics returns calinski_harabasz and davies_bouldin", {
  td <- create_validation_test_data()

  # Create a data frame with clustering vars
  data_df <- as.data.frame(td$scaled_data)
  clustering_vars <- colnames(td$scaled_data)

  metrics <- calculate_separation_metrics(
    data = data_df,
    clusters = td$model$cluster,
    clustering_vars = clustering_vars
  )

  expect_true(!is.null(metrics$calinski_harabasz))
  expect_true(!is.null(metrics$davies_bouldin))
  expect_true(!is.null(metrics$between_ss))
  expect_true(!is.null(metrics$within_ss))
  expect_true(!is.null(metrics$variance_ratio))

  # CH index should be positive for well-separated clusters
  expect_true(metrics$calinski_harabasz > 0)

  # DB index should be positive
  expect_true(metrics$davies_bouldin > 0)
})


# =============================================================================
# TEST: totss equals betweenss + tot_withinss
# =============================================================================

test_that("totss approximately equals betweenss + tot_withinss", {
  td <- create_validation_test_data()

  metrics <- calculate_validation_metrics(
    data = td$scaled_data,
    model = td$model,
    k = td$k
  )

  # totss = betweenss + tot_withinss (from model)
  expected_totss <- metrics$betweenss + metrics$tot_withinss
  expect_equal(metrics$totss, expected_totss, tolerance = 1e-6)
})


# ==============================================================================
# M2 - the gap statistic flag was a no-op (V2 lift review 2026-07-11)
# ==============================================================================
# calculate_validation_metrics() takes `data`, and the gap branch inside it
# referenced `clustering_data`, which exists nowhere in that function. The call
# sits in a tryCatch, so asking for the gap statistic did not fail: it
# returned NA, quietly, under a metrics list that looked complete. Nothing
# noticed because all three production call sites pass calculate_gap = FALSE.

test_that("asking for the gap statistic returns a number, not a silent NA (M2)", {
  set.seed(4)
  k <- 3
  centres <- matrix(c(0, 0, 4, 4, -4, 4), nrow = k, byrow = TRUE)
  rows <- lapply(seq_len(k), function(i) {
    matrix(rnorm(40 * 2, mean = rep(centres[i, ], each = 40), sd = 0.6), ncol = 2)
  })
  d <- as.data.frame(do.call(rbind, rows))
  names(d) <- c("v1", "v2")
  km <- kmeans(scale(d), centers = k, nstart = 10)

  capture.output(
    metrics <- calculate_validation_metrics(
      data = scale(d), model = km, k = k, clusters = km$cluster,
      calculate_gap = TRUE
    )
  )

  expect_true("gap_statistic" %in% names(metrics))
  expect_false(is.na(metrics$gap_statistic))
  expect_true(is.finite(metrics$gap_statistic))
})

test_that("the gap statistic stays off unless it is asked for (M2)", {
  # The default is deliberately unchanged: the gap statistic is expensive and
  # the three production call sites do not want it.
  set.seed(5)
  d <- data.frame(v1 = rnorm(60), v2 = rnorm(60))
  km <- kmeans(scale(d), centers = 2, nstart = 10)

  capture.output(
    metrics <- calculate_validation_metrics(data = scale(d), model = km, k = 2,
                                            clusters = km$cluster)
  )

  expect_false("gap_statistic" %in% names(metrics))
})
