# Tests for edge cases and boundary conditions
# Part of Turas Segment Module v11.0 test suite

test_that("k=2 produces valid results", {
  set.seed(42)
  n <- 80
  p <- 4
  data <- matrix(rnorm(n * p), nrow = n, ncol = p)
  colnames(data) <- paste0("v", 1:p)

  guard <- segment_guard_init()
  config <- list(k_fixed = 2, method = "kmeans", nstart = 5)
  data_list <- list(scaled_data = data, config = config)

  result <- run_clustering(data_list, config, guard)

  expect_equal(result$k, 2)
  expect_equal(length(unique(result$clusters)), 2)
  expect_equal(nrow(result$centers), 2)
})


test_that("2 variables produce valid clustering", {
  set.seed(42)
  n <- 100
  data <- matrix(rnorm(n * 2), nrow = n, ncol = 2)
  colnames(data) <- c("v1", "v2")

  guard <- segment_guard_init()
  config <- list(k_fixed = 3, method = "kmeans", nstart = 5)
  data_list <- list(scaled_data = data, config = config)

  result <- run_clustering(data_list, config, guard)

  expect_equal(result$k, 3)
  expect_equal(ncol(result$centers), 2)
})


test_that("single observation per cluster edge case", {
  set.seed(42)
  # Create data with k almost equal to n
  n <- 10
  p <- 3
  data <- matrix(rnorm(n * p), nrow = n, ncol = p)
  colnames(data) <- paste0("v", 1:p)

  guard <- segment_guard_init()
  config <- list(k_fixed = 5, method = "kmeans", nstart = 5)
  data_list <- list(scaled_data = data, config = config)

  result <- run_clustering(data_list, config, guard)

  expect_equal(result$k, 5)
  expect_equal(length(result$clusters), n)
})


test_that("calculate_cluster_centers handles single-row clusters", {
  data <- data.frame(
    v1 = c(1, 2, 3, 4, 5),
    v2 = c(10, 20, 30, 40, 50)
  )
  clusters <- c(1, 1, 2, 2, 3)  # cluster 3 has single row

  centers <- calculate_cluster_centers(data, clusters)

  expect_equal(nrow(centers), 3)
  expect_equal(ncol(centers), 2)
  # Single-row cluster center should be that row's values
  expect_equal(centers[3, 1], 5)
  expect_equal(centers[3, 2], 50)
})


test_that("guard handles empty warnings list", {
  guard <- segment_guard_init()
  summary <- segment_guard_summary(guard)

  expect_false(summary$has_issues)
  expect_equal(length(summary$dropped_variables), 0)
  expect_equal(length(summary$low_variance_variables), 0)
})


test_that("large k relative to n is handled by sample size guard", {
  # k=10 with n=25 should be refused
  expect_error(
    guard_require_sample_size(n = 25, k = 10, p = 5),
    class = "turas_refusal"
  )
})


test_that("hclust boundary at max size", {
  # Just under limit should pass
  expect_silent(guard_require_hclust_size(14999))

  # At limit should pass
  expect_silent(guard_require_hclust_size(15000))

  # Over limit should refuse
  expect_error(
    guard_require_hclust_size(15001),
    class = "turas_refusal"
  )
})


test_that("exploration with single k value works", {
  set.seed(42)
  n <- 60
  p <- 4
  data <- matrix(rnorm(n * p), nrow = n, ncol = p)
  colnames(data) <- paste0("v", 1:p)

  guard <- segment_guard_init()
  config <- list(
    method = "kmeans", k_min = 3, k_max = 3,
    nstart = 5, min_segment_size_pct = 5
  )
  data_list <- list(scaled_data = data, config = config)

  result <- run_clustering_exploration(data_list, config, guard)

  expect_equal(result$n_successful, 1)
  expect_equal(length(result$results), 1)
})


test_that("validate_clustering_result catches missing clusters field", {
  result <- list(k = 3, centers = matrix(1, 3, 2), method = "kmeans", model = list())

  expect_error(
    validate_clustering_result(result, "kmeans"),
    class = "turas_refusal"
  )
})


test_that("validate_clustering_result passes with all fields", {
  result <- list(
    clusters = c(1L, 2L, 3L),
    k = 3,
    centers = matrix(1, 3, 2),
    method = "kmeans",
    model = list()
  )

  expect_true(validate_clustering_result(result, "kmeans"))
})
