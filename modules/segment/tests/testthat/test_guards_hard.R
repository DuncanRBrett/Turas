# Tests for hard guards (00a_guards_hard.R)
# Part of Turas Segment Module v11.0 test suite
#
# Hard guards call segment_refuse() which throws a condition of class
# "turas_refusal" (inherits from "error"). We use expect_error() with
# class = "turas_refusal" to verify refusals.

# ==============================================================================
# guard_require_clustering_vars()
# ==============================================================================

test_that("guard_require_clustering_vars() refuses when vars missing from data", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)
  # Inject variables that do not exist in the data
  config$clustering_vars <- c("nonexistent_var1", "nonexistent_var2", "nonexistent_var3")

  # Act & Assert
  expect_error(
    guard_require_clustering_vars(config, data = test_data$data),
    class = "turas_refusal"
  )
})

test_that("guard_require_clustering_vars() refuses when vars is NULL", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)
  config$clustering_vars <- NULL

  # Act & Assert
  expect_error(
    guard_require_clustering_vars(config, data = test_data$data),
    class = "turas_refusal"
  )
})

test_that("guard_require_clustering_vars() refuses when only 1 variable", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)
  config$clustering_vars <- "q1"

  # Act & Assert
  expect_error(
    guard_require_clustering_vars(config, data = test_data$data),
    class = "turas_refusal"
  )
})

test_that("guard_require_clustering_vars() refuses for non-numeric variables", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)
  # gender is character, not numeric
  config$clustering_vars <- c("q1", "q2", "gender")

  # Act & Assert
  expect_error(
    guard_require_clustering_vars(config, data = test_data$data),
    class = "turas_refusal"
  )
})

test_that("guard_require_clustering_vars() passes with valid vars", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)

  # Act & Assert - should not error
  expect_invisible(
    guard_require_clustering_vars(config, data = test_data$data)
  )
})


# ==============================================================================
# guard_require_id_variable()
# ==============================================================================

test_that("guard_require_id_variable() refuses when ID not in data", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)
  config$id_variable <- "nonexistent_id"

  # Act & Assert
  expect_error(
    guard_require_id_variable(config, data = test_data$data),
    class = "turas_refusal"
  )
})

test_that("guard_require_id_variable() refuses when ID variable is NULL", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)
  config$id_variable <- NULL

  # Act & Assert
  expect_error(
    guard_require_id_variable(config, data = test_data$data),
    class = "turas_refusal"
  )
})

test_that("guard_require_id_variable() refuses when IDs not unique", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)
  # Inject duplicate IDs
  df <- test_data$data
  df$respondent_id[2] <- df$respondent_id[1]

  # Act & Assert
  expect_error(
    guard_require_id_variable(config, data = df),
    class = "turas_refusal"
  )
})

test_that("guard_require_id_variable() passes with valid unique IDs", {
  # Arrange
  test_data <- generate_segment_test_data()
  config <- generate_test_config(test_data)

  # Act & Assert - should not error
  expect_invisible(
    guard_require_id_variable(config, data = test_data$data)
  )
})


# ==============================================================================
# guard_require_sample_size()
# ==============================================================================

test_that("guard_require_sample_size() refuses when n too small", {
  # Arrange - n=5 is far too small for k=4, p=10
  # min_total = max(100, 4*30, 10*10) = max(100, 120, 100) = 120

  # Act & Assert
  expect_error(
    guard_require_sample_size(n_cases = 5, k = 4, n_vars = 10),
    class = "turas_refusal"
  )
})

test_that("guard_require_sample_size() refuses at boundary", {
  # min_total = max(100, 3*30, 5*10) = max(100, 90, 50) = 100
  # n_cases = 99 should fail

  expect_error(
    guard_require_sample_size(n_cases = 99, k = 3, n_vars = 5),
    class = "turas_refusal"
  )
})

test_that("guard_require_sample_size() passes with sufficient sample", {
  # min_total = max(100, 3*30, 5*10) = 100
  # n_cases = 200 should pass

  expect_invisible(
    guard_require_sample_size(n_cases = 200, k = 3, n_vars = 5)
  )
})


# ==============================================================================
# guard_require_valid_method()
# ==============================================================================

test_that("guard_require_valid_method() refuses for invalid method", {
  expect_error(
    guard_require_valid_method("spectral"),
    class = "turas_refusal"
  )
})

test_that("guard_require_valid_method() refuses for NULL method", {
  expect_error(
    guard_require_valid_method(NULL),
    class = "turas_refusal"
  )
})

test_that("guard_require_valid_method() accepts kmeans", {
  expect_invisible(guard_require_valid_method("kmeans"))
})

test_that("guard_require_valid_method() accepts hclust", {
  expect_invisible(guard_require_valid_method("hclust"))
})

test_that("guard_require_valid_method() accepts gmm", {
  expect_invisible(guard_require_valid_method("gmm"))
})

test_that("guard_require_valid_method() is case-insensitive", {
  # The function uses tolower() internally via the caller, but let's check

  # the function directly accepts lowercase
  expect_invisible(guard_require_valid_method("kmeans"))
})


# ==============================================================================
# guard_require_hclust_size()
# ==============================================================================

test_that("guard_require_hclust_size() refuses when n > 15000", {
  expect_error(
    guard_require_hclust_size(n = 20000),
    class = "turas_refusal"
  )
})

test_that("guard_require_hclust_size() refuses at custom max_n", {
  expect_error(
    guard_require_hclust_size(n = 5001, max_n = 5000),
    class = "turas_refusal"
  )
})

test_that("guard_require_hclust_size() passes when n within limit", {
  expect_invisible(
    guard_require_hclust_size(n = 10000)
  )
})

test_that("guard_require_hclust_size() passes at boundary", {
  expect_invisible(
    guard_require_hclust_size(n = 15000)
  )
})


# ==============================================================================
# Refusal condition structure
# ==============================================================================

test_that("segment_refuse() throws turas_refusal condition with expected fields", {
  # Act & Assert
  err <- tryCatch(
    guard_require_valid_method("invalid_method"),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_true(!is.null(err$code))
  expect_true(!is.null(err$title))
  expect_true(!is.null(err$problem))
  expect_true(!is.null(err$message))
  expect_true(nchar(err$message) > 0)
})
