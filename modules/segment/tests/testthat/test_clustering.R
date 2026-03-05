# Tests for clustering dispatcher (03_clustering.R)
# Part of Turas Segment Module v11.0 test suite
#
# These tests create synthetic scaled_data and minimal config/guard objects
# to exercise the clustering dispatcher, validation, and center calculation.

# ==============================================================================
# Helper: create minimal data_list, config, and guard for clustering tests
# ==============================================================================

.make_clustering_fixtures <- function(n = 200, p = 5, k = 3, method = "kmeans") {
  set.seed(42)

  # Create well-separated clusters
  centers <- matrix(0, nrow = k, ncol = p)
  for (i in seq_len(k)) {
    centers[i, ] <- rnorm(p, mean = (i - 1) * 3, sd = 0.3)
  }

  cluster_sizes <- rep(floor(n / k), k)
  cluster_sizes[k] <- n - sum(cluster_sizes[-k])

  data_rows <- list()
  for (i in seq_len(k)) {
    data_rows[[i]] <- matrix(
      rnorm(cluster_sizes[i] * p, mean = rep(centers[i, ], each = cluster_sizes[i]), sd = 0.5),
      ncol = p
    )
  }
  scaled_data <- do.call(rbind, data_rows)
  colnames(scaled_data) <- paste0("v", seq_len(p))

  data_list <- list(
    scaled_data = scaled_data,
    complete_data = as.data.frame(scaled_data),
    n_complete = n,
    clustering_vars = paste0("v", seq_len(p))
  )

  config <- list(
    method = method,
    mode = "final",
    k_fixed = k,
    k_min = 2,
    k_max = 5,
    nstart = 10,
    linkage_method = "ward.D2",
    seed = 42
  )

  guard <- segment_guard_init()

  list(data_list = data_list, config = config, guard = guard)
}


# ==============================================================================
# run_clustering() - dispatch
# ==============================================================================

test_that("run_clustering() dispatches to kmeans correctly", {
  # Arrange
  fx <- .make_clustering_fixtures(n = 150, p = 4, k = 3, method = "kmeans")

  # Act
  result <- run_clustering(fx$data_list, fx$config, fx$guard)

  # Assert
  expect_equal(result$method, "kmeans")
  expect_equal(result$k, 3)
  expect_equal(length(result$clusters), 150)
  expect_true(all(result$clusters %in% 1:3))
  expect_true(is.matrix(result$centers))
  expect_equal(nrow(result$centers), 3)
  expect_equal(ncol(result$centers), 4)
  expect_false(is.null(result$model))
})

test_that("run_clustering() dispatches to hclust correctly", {
  # Arrange
  fx <- .make_clustering_fixtures(n = 100, p = 4, k = 3, method = "hclust")

  # Act
  result <- run_clustering(fx$data_list, fx$config, fx$guard)

  # Assert
  expect_equal(result$method, "hclust")
  expect_equal(result$k, 3)
  expect_equal(length(result$clusters), 100)
  expect_true(all(result$clusters %in% 1:3))
  expect_true(is.matrix(result$centers))
  expect_false(is.null(result$model))
})

test_that("run_clustering() refuses for invalid method", {
  # Arrange
  fx <- .make_clustering_fixtures(method = "spectral")

  # Act & Assert
  expect_error(
    run_clustering(fx$data_list, fx$config, fx$guard),
    class = "turas_refusal"
  )
})


# ==============================================================================
# validate_clustering_result()
# ==============================================================================

test_that("validate_clustering_result() checks required fields", {
  # Arrange - valid result
  result <- list(
    clusters = c(1L, 2L, 1L, 3L),
    k = 3,
    centers = matrix(1:12, nrow = 3),
    method = "kmeans",
    model = list()
  )

  # Act & Assert - should pass silently
  expect_invisible(validate_clustering_result(result, "kmeans"))
})

test_that("validate_clustering_result() refuses on missing 'clusters' field", {
  # Arrange - missing clusters
  result <- list(
    k = 3,
    centers = matrix(1:12, nrow = 3),
    method = "kmeans",
    model = list()
  )

  # Act & Assert
  expect_error(
    validate_clustering_result(result, "kmeans"),
    class = "turas_refusal"
  )
})

test_that("validate_clustering_result() refuses on missing 'centers' field", {
  # Arrange
  result <- list(
    clusters = c(1L, 2L, 3L),
    k = 3,
    method = "kmeans",
    model = list()
  )

  # Act & Assert
  expect_error(
    validate_clustering_result(result, "kmeans"),
    class = "turas_refusal"
  )
})

test_that("validate_clustering_result() refuses on missing 'model' field", {
  # Arrange
  result <- list(
    clusters = c(1L, 2L, 3L),
    k = 3,
    centers = matrix(1:9, nrow = 3),
    method = "kmeans"
  )

  # Act & Assert
  expect_error(
    validate_clustering_result(result, "kmeans"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# calculate_cluster_centers()
# ==============================================================================

test_that("calculate_cluster_centers() returns correct dimensions", {
  # Arrange
  set.seed(42)
  data <- data.frame(
    v1 = c(1, 2, 3, 10, 11, 12),
    v2 = c(5, 6, 7, 20, 21, 22)
  )
  clusters <- c(1, 1, 1, 2, 2, 2)

  # Act
  centers <- calculate_cluster_centers(data, clusters)

  # Assert
  expect_true(is.matrix(centers))
  expect_equal(nrow(centers), 2)   # k = 2 clusters
  expect_equal(ncol(centers), 2)   # p = 2 variables
  expect_equal(colnames(centers), c("v1", "v2"))
})

test_that("calculate_cluster_centers() computes correct means", {
  # Arrange
  data <- data.frame(
    v1 = c(2, 4, 6, 10, 20, 30),
    v2 = c(1, 1, 1, 5, 5, 5)
  )
  clusters <- c(1, 1, 1, 2, 2, 2)

  # Act
  centers <- calculate_cluster_centers(data, clusters)

  # Assert
  expect_equal(centers[1, "v1"], mean(c(2, 4, 6)))       # 4
  expect_equal(centers[1, "v2"], mean(c(1, 1, 1)))       # 1
  expect_equal(centers[2, "v1"], mean(c(10, 20, 30)))     # 20
  expect_equal(centers[2, "v2"], mean(c(5, 5, 5)))       # 5
})

test_that("calculate_cluster_centers() handles 3 clusters", {
  # Arrange
  data <- data.frame(
    v1 = c(1, 2, 10, 11, 50, 51),
    v2 = c(3, 4, 13, 14, 53, 54)
  )
  clusters <- c(1, 1, 2, 2, 3, 3)

  # Act
  centers <- calculate_cluster_centers(data, clusters)

  # Assert
  expect_equal(nrow(centers), 3)
  expect_equal(centers[1, "v1"], 1.5)
  expect_equal(centers[2, "v1"], 10.5)
  expect_equal(centers[3, "v1"], 50.5)
})


# ==============================================================================
# run_clustering_exploration()
# ==============================================================================

test_that("run_clustering_exploration() returns results for each k tested", {
  # Arrange
  fx <- .make_clustering_fixtures(n = 200, p = 4, k = 3, method = "kmeans")
  fx$config$mode <- "exploration"
  fx$config$k_min <- 2
  fx$config$k_max <- 4

  # Act
  result <- run_clustering_exploration(fx$data_list, fx$config, fx$guard)

  # Assert
  expect_equal(result$mode, "exploration")
  expect_equal(result$method, "kmeans")
  expect_equal(result$k_range, 2:4)
  expect_true(is.list(result$results))
  # Should have results for k=2, k=3, k=4
  expect_true(result$n_successful >= 1)
  expect_true(result$n_successful <= 3)

  # Each result should have standard fields
  for (k_str in names(result$results)) {
    r <- result$results[[k_str]]
    expect_true("clusters" %in% names(r))
    expect_true("k" %in% names(r))
    expect_true("centers" %in% names(r))
  }
})

test_that("run_clustering_exploration() works with hclust", {
  # Arrange
  fx <- .make_clustering_fixtures(n = 100, p = 3, k = 2, method = "hclust")
  fx$config$mode <- "exploration"
  fx$config$k_min <- 2
  fx$config$k_max <- 3

  # Act
  result <- run_clustering_exploration(fx$data_list, fx$config, fx$guard)

  # Assert
  expect_equal(result$method, "hclust")
  expect_true(result$n_successful >= 1)
})
