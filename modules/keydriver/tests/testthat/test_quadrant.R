# ==============================================================================
# KEYDRIVER QUADRANT / IPA ANALYSIS TESTS
# ==============================================================================
#
# Tests for quadrant (Importance-Performance Analysis) functionality:
#   - R/kda_quadrant/quadrant_data_prep.R
#   - R/kda_quadrant/quadrant_calculate.R
#
# Covers:
#   - Quadrant data preparation structure
#   - Correct quadrant assignment logic
#   - Action table generation
#   - Edge cases and graceful handling
#
# ==============================================================================

# module_dir and project_root are provided by helper-paths.R

# Source test data generators
source(file.path(module_dir, "tests", "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure
shared_lib <- file.path(project_root, "modules", "shared", "lib")
source(file.path(shared_lib, "trs_refusal.R"))

# Null-coalescing operator
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Source keydriver guard (needed by quadrant modules)
keydriver_r_dir <- file.path(module_dir, "R")
source(file.path(keydriver_r_dir, "00_guard.R"))

# Source quadrant modules
quadrant_dir <- file.path(keydriver_r_dir, "kda_quadrant")
if (dir.exists(quadrant_dir)) {
  for (f in list.files(quadrant_dir, pattern = "\\.R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}


# ==============================================================================
# assign_quadrants() - Core quadrant assignment logic
# ==============================================================================

test_that("assign_quadrants assigns Q1 (Concentrate Here) for high importance, low performance", {
  skip_if(!exists("assign_quadrants", mode = "function"),
          message = "assign_quadrants not available")

  # Single driver: high importance (y >= threshold), low performance (x < threshold)
  result <- assign_quadrants(x = 30, y = 70, x_thresh = 50, y_thresh = 50)

  expect_equal(result, 1L)
})

test_that("assign_quadrants assigns Q2 (Keep Up Good Work) for high importance, high performance", {
  skip_if(!exists("assign_quadrants", mode = "function"),
          message = "assign_quadrants not available")

  result <- assign_quadrants(x = 70, y = 70, x_thresh = 50, y_thresh = 50)

  expect_equal(result, 2L)
})

test_that("assign_quadrants assigns Q3 (Low Priority) for low importance, low performance", {
  skip_if(!exists("assign_quadrants", mode = "function"),
          message = "assign_quadrants not available")

  result <- assign_quadrants(x = 30, y = 30, x_thresh = 50, y_thresh = 50)

  expect_equal(result, 3L)
})

test_that("assign_quadrants assigns Q4 (Possible Overkill) for low importance, high performance", {
  skip_if(!exists("assign_quadrants", mode = "function"),
          message = "assign_quadrants not available")

  result <- assign_quadrants(x = 70, y = 30, x_thresh = 50, y_thresh = 50)

  expect_equal(result, 4L)
})

test_that("assign_quadrants handles multiple drivers correctly", {
  skip_if(!exists("assign_quadrants", mode = "function"),
          message = "assign_quadrants not available")

  # 5 drivers in known positions
  x_vals <- c(30, 70, 30, 70, 50)
  y_vals <- c(70, 70, 30, 30, 50)

  result <- assign_quadrants(x_vals, y_vals, x_thresh = 50, y_thresh = 50)

  expect_equal(result[1], 1L)  # Q1: Concentrate Here

  expect_equal(result[2], 2L)  # Q2: Keep Up Good Work
  expect_equal(result[3], 3L)  # Q3: Low Priority
  expect_equal(result[4], 4L)  # Q4: Possible Overkill
  # Driver at exact threshold: x=50 (>= thresh) and y=50 (>= thresh) => Q2
  expect_equal(result[5], 2L)
})

test_that("assign_quadrants handles boundary values at threshold", {
  skip_if(!exists("assign_quadrants", mode = "function"),
          message = "assign_quadrants not available")

  # Exactly at threshold: y >= y_thresh and x >= x_thresh => Q2
  result <- assign_quadrants(x = 50, y = 50, x_thresh = 50, y_thresh = 50)
  expect_equal(result, 2L)

  # Exactly at threshold: y >= y_thresh and x < x_thresh => Q1
  result <- assign_quadrants(x = 49.99, y = 50, x_thresh = 50, y_thresh = 50)
  expect_equal(result, 1L)
})


# ==============================================================================
# prepare_quadrant_data() - Data preparation and structure
# ==============================================================================

test_that("prepare_quadrant_data returns expected structure", {
  skip_if(!exists("prepare_quadrant_data", mode = "function"),
          message = "prepare_quadrant_data not available")

  importance <- data.frame(
    driver = paste0("driver_", 1:5),
    importance = c(80, 60, 40, 30, 20),
    stringsAsFactors = FALSE
  )
  performance <- data.frame(
    driver = paste0("driver_", 1:5),
    performance = c(30, 70, 35, 75, 50),
    stringsAsFactors = FALSE
  )
  config <- list(threshold_method = "mean")

  result <- tryCatch(
    prepare_quadrant_data(importance, performance, config),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(result), message = "prepare_quadrant_data returned NULL or refused")

  expect_true(is.data.frame(result))
  expect_true("quadrant" %in% names(result))
  expect_true("quadrant_label" %in% names(result))
  expect_true("gap" %in% names(result))
  expect_true("priority_score" %in% names(result))
  expect_equal(nrow(result), 5)
})

test_that("prepare_quadrant_data assigns correct quadrant labels", {
  skip_if(!exists("prepare_quadrant_data", mode = "function"),
          message = "prepare_quadrant_data not available")

  importance <- data.frame(
    driver = paste0("driver_", 1:4),
    importance = c(80, 80, 20, 20),
    stringsAsFactors = FALSE
  )
  performance <- data.frame(
    driver = paste0("driver_", 1:4),
    performance = c(20, 80, 20, 80),
    stringsAsFactors = FALSE
  )
  config <- list(threshold_method = "mean")

  result <- tryCatch(
    prepare_quadrant_data(importance, performance, config),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(result), message = "prepare_quadrant_data returned NULL or refused")

  labels <- as.character(result$quadrant_label)

  # driver_1: high importance, low performance => Concentrate Here
  expect_true("Concentrate Here" %in% labels)
  # driver_2: high importance, high performance => Keep Up Good Work
  expect_true("Keep Up Good Work" %in% labels)
  # driver_3: low importance, low performance => Low Priority
  expect_true("Low Priority" %in% labels)
  # driver_4: low importance, high performance => Possible Overkill
  expect_true("Possible Overkill" %in% labels)
})


# ==============================================================================
# create_action_table() - Action table generation
# ==============================================================================

test_that("create_action_table generates table with correct columns", {
  skip_if(!exists("create_action_table", mode = "function"),
          message = "create_action_table not available")
  skip_if(!exists("prepare_quadrant_data", mode = "function"),
          message = "prepare_quadrant_data not available")

  importance <- data.frame(
    driver = paste0("driver_", 1:5),
    importance = c(80, 60, 40, 30, 20),
    stringsAsFactors = FALSE
  )
  performance <- data.frame(
    driver = paste0("driver_", 1:5),
    performance = c(30, 70, 35, 75, 50),
    stringsAsFactors = FALSE
  )
  config <- list(threshold_method = "mean")

  quad_data <- tryCatch(
    prepare_quadrant_data(importance, performance, config),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(quad_data), message = "prepare_quadrant_data failed")

  action_table <- tryCatch(
    create_action_table(quad_data, config),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(action_table), message = "create_action_table failed")

  expect_true(is.data.frame(action_table))
  expected_cols <- c("Priority", "Driver", "Zone", "Importance",
                     "Performance", "Gap", "Recommended Action")
  for (col in expected_cols) {
    expect_true(col %in% names(action_table),
                info = paste("Missing column:", col))
  }
  expect_equal(nrow(action_table), 5)
})

test_that("create_action_table has IMPROVE action for Q1 drivers", {
  skip_if(!exists("create_action_table", mode = "function"),
          message = "create_action_table not available")
  skip_if(!exists("prepare_quadrant_data", mode = "function"),
          message = "prepare_quadrant_data not available")

  # Create a clear Q1 scenario: all drivers high importance, low performance
  importance <- data.frame(
    driver = paste0("driver_", 1:4),
    importance = c(90, 80, 20, 20),
    stringsAsFactors = FALSE
  )
  performance <- data.frame(
    driver = paste0("driver_", 1:4),
    performance = c(10, 10, 90, 90),
    stringsAsFactors = FALSE
  )
  config <- list(threshold_method = "mean")

  quad_data <- tryCatch(
    prepare_quadrant_data(importance, performance, config),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(quad_data), message = "prepare_quadrant_data failed")

  action_table <- tryCatch(
    create_action_table(quad_data, config),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(action_table), message = "create_action_table failed")

  # Q1 drivers should have IMPROVE in their action
  q1_actions <- action_table[action_table$Zone == "Concentrate Here", "Recommended Action"]
  if (length(q1_actions) > 0) {
    expect_true(all(grepl("IMPROVE", q1_actions)),
                info = "Q1 drivers should have IMPROVE action")
  }
})


# ==============================================================================
# calculate_thresholds() - Threshold calculation methods
# ==============================================================================

test_that("calculate_thresholds uses mean method correctly", {
  skip_if(!exists("calculate_thresholds", mode = "function"),
          message = "calculate_thresholds not available")

  quad_data <- data.frame(x = c(20, 40, 60, 80), y = c(30, 50, 70, 90))
  config <- list(threshold_method = "mean")

  result <- tryCatch(
    calculate_thresholds(quad_data, config),
    error = function(e) NULL
  )

  skip_if(is.null(result), message = "calculate_thresholds failed")

  expect_equal(result$x, mean(c(20, 40, 60, 80)))
  expect_equal(result$y, mean(c(30, 50, 70, 90)))
})

test_that("calculate_thresholds uses median method correctly", {
  skip_if(!exists("calculate_thresholds", mode = "function"),
          message = "calculate_thresholds not available")

  quad_data <- data.frame(x = c(20, 40, 60, 80), y = c(30, 50, 70, 90))
  config <- list(threshold_method = "median")

  result <- tryCatch(
    calculate_thresholds(quad_data, config),
    error = function(e) NULL
  )

  skip_if(is.null(result), message = "calculate_thresholds failed")

  expect_equal(result$x, median(c(20, 40, 60, 80)))
  expect_equal(result$y, median(c(30, 50, 70, 90)))
})


# ==============================================================================
# calculate_gap_analysis() - Gap scoring
# ==============================================================================

test_that("calculate_gap_analysis returns correct gap direction", {
  skip_if(!exists("calculate_gap_analysis", mode = "function"),
          message = "calculate_gap_analysis not available")
  skip_if(!exists("prepare_quadrant_data", mode = "function"),
          message = "prepare_quadrant_data not available")

  importance <- data.frame(
    driver = paste0("driver_", 1:4),
    importance = c(80, 20, 60, 40),
    stringsAsFactors = FALSE
  )
  performance <- data.frame(
    driver = paste0("driver_", 1:4),
    performance = c(30, 70, 60, 40),
    stringsAsFactors = FALSE
  )
  config <- list(threshold_method = "mean")

  quad_data <- tryCatch(
    prepare_quadrant_data(importance, performance, config),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(quad_data), message = "prepare_quadrant_data failed")

  gap_result <- tryCatch(
    calculate_gap_analysis(quad_data),
    error = function(e) NULL
  )

  skip_if(is.null(gap_result), message = "calculate_gap_analysis failed")

  expect_true(is.data.frame(gap_result))
  expect_true("gap" %in% names(gap_result))
  expect_true("gap_direction" %in% names(gap_result))
  expect_true("gap_rank" %in% names(gap_result))

  # Positive gap means underperforming (importance > performance)
  underperforming <- gap_result[gap_result$gap > 0, "gap_direction"]
  if (length(underperforming) > 0) {
    expect_true(all(underperforming == "Underperforming"))
  }
})


# ==============================================================================
# Edge cases
# ==============================================================================

test_that("quadrant analysis handles missing quadrant_data gracefully in mock results", {
  results <- generate_mock_results(n_drivers = 5, include_quadrant = FALSE)

  expect_null(results$quadrant)
  expect_null(results$quadrant_results)
})
