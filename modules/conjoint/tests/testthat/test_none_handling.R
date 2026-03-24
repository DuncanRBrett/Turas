# ==============================================================================
# TEST SUITE: Conjoint None Option Handling (09_none_handling.R)
# ==============================================================================

library(testthat)

context("Conjoint None Option Handling")

# ==============================================================================
# HELPERS: Mock Data Builders
# ==============================================================================

make_mock_cbc_data <- function(n_resp = 5, n_sets = 3, n_alts = 3, include_none = FALSE) {
  rows <- list()
  for (r in seq_len(n_resp)) {
    for (s in seq_len(n_sets)) {
      chosen_alt <- sample(seq_len(n_alts), 1)
      for (a in seq_len(n_alts)) {
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = r,
          choice_set_id = paste0(r, "_", s),
          alternative_id = a,
          Brand = sample(c("Alpha", "Beta", "Gamma"), 1),
          Price = sample(c("Low", "Mid", "High"), 1),
          chosen = ifelse(a == chosen_alt, 1L, 0L),
          stringsAsFactors = FALSE
        )
      }
      if (include_none) {
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = r,
          choice_set_id = paste0(r, "_", s),
          alternative_id = n_alts + 1L,
          Brand = "None of these",
          Price = "None of these",
          chosen = 0L,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

make_mock_config <- function(include_none_cols = FALSE) {
  config <- list(
    attributes = data.frame(
      AttributeName = c("Brand", "Price"),
      stringsAsFactors = FALSE
    ),
    chosen_column = "chosen",
    choice_set_column = "choice_set_id",
    respondent_id_column = "resp_id",
    alternative_id_column = "alternative_id",
    none_label = "None"
  )
  config
}


# ==============================================================================
# TESTS: detect_none_option()
# ==============================================================================

test_that("detect_none_option returns FALSE when no none present", {
  data <- make_mock_cbc_data(n_resp = 5, n_sets = 3)
  config <- make_mock_config()

  result <- detect_none_option(data, config)

  expect_false(result$has_none)
  expect_equal(result$method, "no_none_detected")
})

test_that("detect_none_option detects none in attribute values", {
  data <- make_mock_cbc_data(n_resp = 5, n_sets = 3, include_none = TRUE)
  config <- make_mock_config()

  result <- detect_none_option(data, config)

  expect_true(result$has_none)
  expect_equal(result$method, "none_in_attributes")
  expect_true(!is.null(result$none_attribute))
})

test_that("detect_none_option detects none via alternative_id column", {
  data <- make_mock_cbc_data(n_resp = 3, n_sets = 2)
  config <- make_mock_config()

  # Add rows with "none" in alternative_id
  none_rows <- data.frame(
    resp_id = rep(1:3, each = 2),
    choice_set_id = paste0(rep(1:3, each = 2), "_", rep(1:2, 3)),
    alternative_id = rep(99L, 6),
    Brand = "Regular",
    Price = "Regular",
    chosen = 0L,
    stringsAsFactors = FALSE
  )
  # Overwrite alternative_id to text "none"
  data_with_none <- rbind(data, none_rows)
  data_with_none$alternative_id <- as.character(data_with_none$alternative_id)
  data_with_none$alternative_id[data_with_none$alternative_id == "99"] <- "none"

  result <- detect_none_option(data_with_none, config)

  expect_true(result$has_none)
  expect_equal(result$method, "none_alternative_id")
})

test_that("detect_none_option detects implicit none (all unchosen sets)", {
  data <- make_mock_cbc_data(n_resp = 3, n_sets = 3)
  config <- make_mock_config()

  # Create an all-unchosen choice set by zeroing out all chosen values
  target_set <- paste0("1_1")
  data$chosen[data$choice_set_id == target_set] <- 0L

  result <- detect_none_option(data, config)

  expect_true(result$has_none)
  expect_equal(result$method, "all_unchosen_sets")
  expect_true(result$none_count > 0)
})

test_that("detect_none_option detects various none patterns", {
  data <- make_mock_cbc_data(n_resp = 2, n_sets = 1)
  config <- make_mock_config()

  # Test different none patterns
  none_variants <- c("None of the above", "opt out", "neither", "no choice")

  for (variant in none_variants) {
    test_data <- data
    # Add a row with this none variant in Brand
    none_row <- data.frame(
      resp_id = 1L,
      choice_set_id = "1_1",
      alternative_id = 99L,
      Brand = variant,
      Price = "N/A",
      chosen = 0L,
      stringsAsFactors = FALSE
    )
    test_data <- rbind(test_data, none_row)

    result <- detect_none_option(test_data, config)
    expect_true(result$has_none,
                info = paste("Should detect none pattern:", variant))
  }
})


# ==============================================================================
# TESTS: identify_none_rows()
# ==============================================================================

test_that("identify_none_rows correctly identifies rows with none values", {
  data <- make_mock_cbc_data(n_resp = 2, n_sets = 2, include_none = TRUE)
  config <- make_mock_config()

  none_info <- detect_none_option(data, config)
  none_indices <- identify_none_rows(data, config, none_info)

  expect_true(length(none_indices) > 0)

  # Verify all identified rows actually have none-like values
  for (idx in none_indices) {
    row_values <- tolower(as.character(data[idx, c("Brand", "Price")]))
    has_none_pattern <- any(grepl("none", row_values))
    expect_true(has_none_pattern,
                info = paste("Row", idx, "should have none pattern"))
  }
})


# ==============================================================================
# TESTS: validate_none_choices()
# ==============================================================================

test_that("validate_none_choices passes for valid data with one choice per set", {
  data <- make_mock_cbc_data(n_resp = 3, n_sets = 2)
  config <- make_mock_config()

  # Should not error
  result <- validate_none_choices(data, config)
  expect_true(result)
})

test_that("validate_none_choices refuses when multiple choices per set", {
  data <- make_mock_cbc_data(n_resp = 3, n_sets = 2)
  config <- make_mock_config()

  # Make two alternatives chosen in same set
  target_set <- unique(data$choice_set_id)[1]
  set_rows <- which(data$choice_set_id == target_set)
  data$chosen[set_rows[1]] <- 1L
  data$chosen[set_rows[2]] <- 1L

  expect_error(
    validate_none_choices(data, config),
    regexp = "REFUSED|invalid|choice",
    ignore.case = TRUE
  )
})


# ==============================================================================
# TESTS: calculate_none_diagnostics()
# ==============================================================================

test_that("calculate_none_diagnostics returns NULL when no none alternative column", {
  data <- make_mock_cbc_data(n_resp = 3, n_sets = 2)
  config <- make_mock_config()
  model <- list()

  result <- calculate_none_diagnostics(model, data, config)
  expect_null(result)
})

test_that("calculate_none_diagnostics calculates selection rate", {
  data <- make_mock_cbc_data(n_resp = 3, n_sets = 2, include_none = TRUE)
  config <- make_mock_config()
  data$is_none_alternative <- grepl("none", tolower(data$Brand))

  # Make some none rows chosen
  none_idx <- which(data$is_none_alternative)
  if (length(none_idx) > 0) {
    # First unchose the regular one in same set, then choose none
    first_none <- none_idx[1]
    set_id <- data$choice_set_id[first_none]
    data$chosen[data$choice_set_id == set_id] <- 0L
    data$chosen[first_none] <- 1L
  }

  model <- list()
  result <- calculate_none_diagnostics(model, data, config)

  expect_false(is.null(result))
  expect_true("none_selection_count" %in% names(result))
  expect_true("none_selection_rate" %in% names(result))
  expect_true(result$none_selection_rate >= 0 && result$none_selection_rate <= 1)
})
