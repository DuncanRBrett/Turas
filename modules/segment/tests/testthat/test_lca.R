# ==============================================================================
# Tests for 11_lca.R
# Part of Turas Segment Module test suite
# ==============================================================================
# Covers: calculate_entropy_rsquared, interpret_entropy_rsquared,
#   create_lca_profiles, export_lca_exploration, calculate_posterior_probs
# ==============================================================================


# ==============================================================================
# calculate_entropy_rsquared()
# ==============================================================================

test_that("calculate_entropy_rsquared returns value in [0, 1] for valid input", {
  # Simulate a 3-class posterior probability matrix (100 respondents)
  set.seed(42)
  n <- 100
  k <- 3
  # Create posterior probs that sum to 1 per row
  raw <- matrix(runif(n * k), ncol = k)
  posterior <- raw / rowSums(raw)
  class_probs <- colMeans(posterior)

  result <- calculate_entropy_rsquared(posterior, class_probs)

  expect_type(result, "double")
  expect_true(result >= 0)
  expect_true(result <= 1)
})

test_that("calculate_entropy_rsquared returns high value for clear assignments", {
  # Each respondent clearly belongs to one class
  n <- 90
  k <- 3
  posterior <- matrix(0, nrow = n, ncol = k)
  for (i in 1:n) {
    assigned <- ((i - 1) %% k) + 1
    posterior[i, assigned] <- 0.98
    others <- setdiff(1:k, assigned)
    posterior[i, others] <- 0.01
  }
  class_probs <- colMeans(posterior)

  result <- calculate_entropy_rsquared(posterior, class_probs)

  expect_true(result > 0.8)
})

test_that("calculate_entropy_rsquared returns low value for fuzzy assignments", {
  # Respondents split roughly evenly across classes
  n <- 90
  k <- 3
  posterior <- matrix(1/k, nrow = n, ncol = k)
  # Add small random perturbation
  set.seed(42)
  noise <- matrix(rnorm(n * k, 0, 0.01), nrow = n, ncol = k)
  posterior <- posterior + noise
  posterior <- pmax(posterior, 0.001)
  posterior <- posterior / rowSums(posterior)
  class_probs <- rep(1/k, k)

  result <- calculate_entropy_rsquared(posterior, class_probs)

  expect_true(result < 0.3)
})

test_that("calculate_entropy_rsquared returns NA for NULL posterior", {
  result <- suppressWarnings(
    calculate_entropy_rsquared(NULL, c(0.5, 0.5))
  )
  expect_true(is.na(result))
})

test_that("calculate_entropy_rsquared returns NA for non-matrix input", {
  result <- suppressWarnings(
    calculate_entropy_rsquared(c(0.5, 0.5), c(0.5, 0.5))
  )
  expect_true(is.na(result))
})

test_that("calculate_entropy_rsquared returns 1.0 for single class", {
  posterior <- matrix(1, nrow = 50, ncol = 1)
  class_probs <- 1

  result <- calculate_entropy_rsquared(posterior, class_probs)
  expect_equal(result, 1.0)
})


# ==============================================================================
# interpret_entropy_rsquared()
# ==============================================================================

test_that("interpret_entropy_rsquared returns correct categories", {
  expect_true(grepl("Excellent", interpret_entropy_rsquared(0.85)))
  expect_true(grepl("Good", interpret_entropy_rsquared(0.70)))
  expect_true(grepl("Moderate", interpret_entropy_rsquared(0.50)))
  expect_true(grepl("Poor", interpret_entropy_rsquared(0.30)))
  expect_true(grepl("Unknown", interpret_entropy_rsquared(NA)))
})

test_that("interpret_entropy_rsquared handles boundary values", {
  expect_true(grepl("Excellent", interpret_entropy_rsquared(0.80)))
  expect_true(grepl("Good", interpret_entropy_rsquared(0.60)))
  expect_true(grepl("Moderate", interpret_entropy_rsquared(0.40)))
  expect_true(grepl("Poor", interpret_entropy_rsquared(0.39)))
})


# ==============================================================================
# calculate_posterior_probs()
# ==============================================================================

test_that("calculate_posterior_probs returns valid probabilities", {
  # Create a mock poLCA model object
  mock_model <- list(
    P = c(0.4, 0.6),
    probs = list(
      q1 = matrix(c(0.8, 0.2, 0.3, 0.7), nrow = 2, ncol = 2, byrow = TRUE),
      q2 = matrix(c(0.9, 0.1, 0.4, 0.6), nrow = 2, ncol = 2, byrow = TRUE)
    )
  )

  new_data <- data.frame(q1 = 1L, q2 = 1L)
  result <- calculate_posterior_probs(new_data, mock_model)

  expect_type(result, "double")
  expect_length(result, 2)
  # Probabilities should sum to 1
  expect_equal(sum(result), 1.0, tolerance = 1e-10)
  # All probabilities should be non-negative
  expect_true(all(result >= 0))
})

test_that("calculate_posterior_probs assigns higher prob to matching class", {
  # Class 1: prefers response=1 for both variables
  # Class 2: prefers response=2 for both variables
  mock_model <- list(
    P = c(0.5, 0.5),
    probs = list(
      q1 = matrix(c(0.9, 0.1, 0.1, 0.9), nrow = 2, ncol = 2, byrow = TRUE),
      q2 = matrix(c(0.9, 0.1, 0.1, 0.9), nrow = 2, ncol = 2, byrow = TRUE)
    )
  )

  # Respondent with all 1s should be classified to class 1
  new_data <- data.frame(q1 = 1L, q2 = 1L)
  result <- calculate_posterior_probs(new_data, mock_model)

  expect_true(result[1] > result[2])

  # Respondent with all 2s should be classified to class 2
  new_data2 <- data.frame(q1 = 2L, q2 = 2L)
  result2 <- calculate_posterior_probs(new_data2, mock_model)

  expect_true(result2[2] > result2[1])
})

test_that("calculate_posterior_probs handles 3 classes", {
  mock_model <- list(
    P = c(0.3, 0.3, 0.4),
    probs = list(
      q1 = matrix(c(0.7, 0.2, 0.1,
                     0.2, 0.6, 0.2,
                     0.1, 0.2, 0.7), nrow = 3, ncol = 3, byrow = TRUE)
    )
  )

  new_data <- data.frame(q1 = 1L)
  result <- calculate_posterior_probs(new_data, mock_model)

  expect_length(result, 3)
  expect_equal(sum(result), 1.0, tolerance = 1e-10)
  # Class 1 should have highest probability for response=1
  expect_equal(which.max(result), 1)
})


# ==============================================================================
# create_lca_profiles()
# ==============================================================================

test_that("create_lca_profiles returns list with expected sheets", {
  # Create a mock poLCA model
  mock_model <- list(
    P = c(0.4, 0.6),
    probs = list(
      q1 = matrix(c(0.7, 0.3, 0.2, 0.8), nrow = 2, ncol = 2, byrow = TRUE),
      q2 = matrix(c(0.6, 0.4, 0.3, 0.7), nrow = 2, ncol = 2, byrow = TRUE)
    )
  )

  result <- create_lca_profiles(mock_model, c("q1", "q2"))

  expect_true(is.list(result))
  expect_true("Summary" %in% names(result))
  expect_true("Class_Sizes" %in% names(result))
  expect_true(is.data.frame(result$Summary))
  expect_true(is.data.frame(result$Class_Sizes))
})

test_that("create_lca_profiles summary has correct dimensions", {
  mock_model <- list(
    P = c(0.3, 0.3, 0.4),
    probs = list(
      q1 = matrix(c(0.5, 0.3, 0.2,
                     0.2, 0.5, 0.3,
                     0.3, 0.2, 0.5), nrow = 3, ncol = 3, byrow = TRUE),
      q2 = matrix(c(0.6, 0.4, 0.0,
                     0.3, 0.4, 0.3,
                     0.1, 0.3, 0.6), nrow = 3, ncol = 3, byrow = TRUE)
    )
  )

  result <- create_lca_profiles(mock_model, c("q1", "q2"))

  # Summary should have 2 rows (one per variable)
  expect_equal(nrow(result$Summary), 2)
  # Should have Variable + 3 class columns
  expect_true("Variable" %in% names(result$Summary))
  expect_true("Class_1" %in% names(result$Summary))
  expect_true("Class_3" %in% names(result$Summary))
})

test_that("create_lca_profiles handles question_labels", {
  mock_model <- list(
    P = c(0.5, 0.5),
    probs = list(
      q1 = matrix(c(0.8, 0.2, 0.3, 0.7), nrow = 2, ncol = 2, byrow = TRUE)
    )
  )

  labels <- c(q1 = "Satisfaction Score")
  result <- create_lca_profiles(mock_model, c("q1"), question_labels = labels)

  expect_true("Label" %in% names(result$Summary))
  expect_equal(result$Summary$Label[1], "Satisfaction Score")
})

test_that("create_lca_profiles class_sizes has correct percentages", {
  mock_model <- list(
    P = c(0.4, 0.6),
    probs = list(
      q1 = matrix(c(0.5, 0.5, 0.5, 0.5), nrow = 2, ncol = 2, byrow = TRUE)
    )
  )

  result <- create_lca_profiles(mock_model, c("q1"))

  expect_equal(nrow(result$Class_Sizes), 2)
  expect_true(grepl("40", result$Class_Sizes$Proportion[1]))
  expect_true(grepl("60", result$Class_Sizes$Proportion[2]))
})


# ==============================================================================
# export_lca_exploration()
# ==============================================================================

test_that("export_lca_exploration writes Excel file with fit stats", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE))

  fit_stats <- data.frame(
    n_classes = c(2, 3, 4),
    llik = c(-500, -450, -420),
    AIC = c(1020, 930, 880),
    BIC = c(1050, 970, 930),
    Gsq = c(100, 80, 60),
    df = c(50, 45, 40),
    stringsAsFactors = FALSE
  )

  # Create mock models with P field
  models <- list(
    "2" = list(P = c(0.5, 0.5)),
    "3" = list(P = c(0.33, 0.33, 0.34)),
    "4" = list(P = c(0.25, 0.25, 0.25, 0.25))
  )

  output_path <- file.path(tempdir(), "test_lca_exploration.xlsx")

  output <- capture.output(
    export_lca_exploration(fit_stats, models, output_path)
  )

  expect_true(file.exists(output_path))

  # Clean up
  unlink(output_path)
})
