# ==============================================================================
# MAXDIFF MODULE - REGRESSION TEST (testthat wrapper)
# ==============================================================================
# Wraps MaxDiff unit tests in testthat format for unified test runner
# ==============================================================================

library(testthat)

# Get Turas root
find_test_turas_root <- function() {
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        dir.exists(file.path(current_dir, "modules", "shared"))) {
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }
  stop("Cannot locate Turas root directory")
}

turas_root <- find_test_turas_root()
maxdiff_dir <- file.path(turas_root, "modules", "maxdiff")

# Source MaxDiff module files
source(file.path(maxdiff_dir, "R", "utils.R"))
source(file.path(maxdiff_dir, "R", "02_validation.R"))  # Contains compute_pair_frequencies
source(file.path(maxdiff_dir, "R", "04_design.R"))
source(file.path(maxdiff_dir, "R", "05_counts.R"))

# ==============================================================================
# Utility Function Tests
# ==============================================================================

test_that("validate_option works correctly", {
  result <- validate_option("BALANCED", c("BALANCED", "RANDOM"), "test")
  expect_equal(result, "BALANCED")
})

test_that("validate_positive_integer works correctly", {
  result <- validate_positive_integer(5, "test")
  expect_equal(result, 5L)
  expect_true(is.integer(result))
})

test_that("parse_yes_no handles various inputs", {
  expect_true(parse_yes_no("Y"))
  expect_false(parse_yes_no("N"))
  expect_true(parse_yes_no("YES"))
  expect_false(parse_yes_no("NO"))
  expect_false(parse_yes_no(NA, FALSE))
})

test_that("safe_numeric converts values correctly", {
  expect_equal(safe_numeric("3.14"), 3.14)
  expect_true(is.na(safe_numeric("abc")))
  expect_equal(safe_numeric(NULL, 0), 0)
})

test_that("calculate_effective_n computes correctly", {
  # Equal weights should give n
  eff_n <- calculate_effective_n(rep(1, 100))
  expect_equal(eff_n, 100, tolerance = 0.01)

  # Varying weights should give less
  eff_n2 <- calculate_effective_n(c(rep(1, 90), rep(5, 10)))
  expect_lt(eff_n2, 100)
  expect_gt(eff_n2, 0)
})

test_that("rescale_utilities handles different scales", {
  utils <- c(-1, 0, 1)

  # 0-100 scale
  scaled <- rescale_utilities(utils, "0_100")
  expect_equal(min(scaled), 0)
  expect_equal(max(scaled), 100)
  expect_equal(scaled[2], 50)

  # RAW
  raw <- rescale_utilities(utils, "RAW")
  expect_equal(raw, utils)

  # PROBABILITY
  prob <- rescale_utilities(utils, "PROBABILITY")
  expect_equal(sum(prob), 100, tolerance = 0.01)
})

# ==============================================================================
# Design Generation Tests
# ==============================================================================

test_that("generate_random_design creates valid design", {
  item_ids <- paste0("I", 1:8)
  design <- generate_random_design(
    item_ids = item_ids,
    items_per_task = 4,
    tasks_per_respondent = 10,
    n_versions = 2,
    verbose = FALSE
  )

  expect_true(is.data.frame(design))
  expect_equal(nrow(design), 20)  # 2 versions x 10 tasks
  expect_true("Version" %in% names(design))
  expect_true("Task_Number" %in% names(design))
  expect_true("Item1_ID" %in% names(design))
})

test_that("compute_pair_frequencies counts correctly", {
  design <- data.frame(
    Version = 1,
    Task_Number = 1:3,
    Item1_ID = c("A", "A", "B"),
    Item2_ID = c("B", "C", "C"),
    stringsAsFactors = FALSE
  )

  pair_freq <- compute_pair_frequencies(design, c("Item1_ID", "Item2_ID"))

  expect_equal(length(pair_freq), 3)  # A_B, A_C, B_C
  expect_equal(unname(pair_freq["A_B"]), 1)
  expect_equal(unname(pair_freq["A_C"]), 1)
  expect_equal(unname(pair_freq["B_C"]), 1)
})

# ==============================================================================
# Count Scoring Tests
# ==============================================================================

test_that("count scoring calculates correctly", {
  # Create test long data
  long_data <- data.frame(
    resp_id = rep(1:5, each = 2),
    item_id = rep(c("A", "B"), 5),
    is_best = c(1,0, 1,0, 1,0, 0,1, 0,1),
    is_worst = c(0,1, 0,1, 0,1, 1,0, 1,0),
    weight = 1,
    obs_id = 1:10,
    stringsAsFactors = FALSE
  )

  items <- data.frame(
    Item_ID = c("A", "B"),
    Item_Label = c("Item A", "Item B"),
    Item_Group = "",
    Display_Order = 1:2,
    Include = 1,
    stringsAsFactors = FALSE
  )

  scores <- compute_maxdiff_counts(long_data, items, weighted = FALSE, verbose = FALSE)

  expect_true(is.data.frame(scores))
  expect_equal(nrow(scores), 2)
  expect_true("Best_Pct" %in% names(scores))
  expect_true("Net_Score" %in% names(scores))

  # Item A should have 60% best (3/5)
  score_a <- scores[scores$Item_ID == "A", "Best_Pct"]
  expect_equal(score_a, 60, tolerance = 0.1)
})

cat("\n=== MaxDiff Regression Tests Complete ===\n")
