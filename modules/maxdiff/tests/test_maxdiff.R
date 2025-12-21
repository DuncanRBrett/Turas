# ==============================================================================
# MAXDIFF MODULE - UNIT TESTS - TURAS V10.0
# ==============================================================================
# Unit tests for MaxDiff module
# Part of Turas MaxDiff Module
#
# USAGE:
# source("tests/test_maxdiff.R")
# run_maxdiff_tests()
# ==============================================================================

# ==============================================================================
# TEST RUNNER
# ==============================================================================

#' Run all MaxDiff unit tests
#'
#' @export
run_maxdiff_tests <- function() {

  cat("\n")
  cat("================================================================================\n")
  cat("MAXDIFF MODULE - UNIT TESTS\n")
  cat("================================================================================\n\n")

  # Track results
  tests_passed <- 0
  tests_failed <- 0
  test_results <- list()

  # Helper function
  run_test <- function(test_name, test_fn) {
    cat(sprintf("Testing: %s... ", test_name))

    result <- tryCatch({
      test_fn()
      cat("PASSED\n")
      list(name = test_name, passed = TRUE, error = NULL)
    }, error = function(e) {
      cat(sprintf("FAILED: %s\n", e$message))
      list(name = test_name, passed = FALSE, error = e$message)
    })

    return(result)
  }

  # ==========================================================================
  # UTILITY TESTS
  # ==========================================================================

  cat("--- Utility Functions ---\n")

  test_results[[length(test_results) + 1]] <- run_test(
    "validate_option",
    function() {
      result <- validate_option("BALANCED", c("BALANCED", "RANDOM"), "test")
      stopifnot(result == "BALANCED")
    }
  )

  test_results[[length(test_results) + 1]] <- run_test(
    "validate_positive_integer",
    function() {
      result <- validate_positive_integer(5, "test")
      stopifnot(result == 5L)
      stopifnot(is.integer(result))
    }
  )

  test_results[[length(test_results) + 1]] <- run_test(
    "parse_yes_no",
    function() {
      stopifnot(parse_yes_no("Y") == TRUE)
      stopifnot(parse_yes_no("N") == FALSE)
      stopifnot(parse_yes_no("YES") == TRUE)
      stopifnot(parse_yes_no("NO") == FALSE)
      stopifnot(parse_yes_no(NA, FALSE) == FALSE)
    }
  )

  test_results[[length(test_results) + 1]] <- run_test(
    "safe_numeric",
    function() {
      stopifnot(safe_numeric("3.14") == 3.14)
      stopifnot(is.na(safe_numeric("abc")))
      stopifnot(safe_numeric(NULL, 0) == 0)
    }
  )

  test_results[[length(test_results) + 1]] <- run_test(
    "calculate_effective_n",
    function() {
      # Equal weights should give n
      eff_n <- calculate_effective_n(rep(1, 100))
      stopifnot(abs(eff_n - 100) < 0.01)

      # Varying weights should give less
      eff_n2 <- calculate_effective_n(c(rep(1, 90), rep(5, 10)))
      stopifnot(eff_n2 < 100)
      stopifnot(eff_n2 > 0)
    }
  )

  test_results[[length(test_results) + 1]] <- run_test(
    "rescale_utilities",
    function() {
      utils <- c(-1, 0, 1)

      # 0-100 scale
      scaled <- rescale_utilities(utils, "0_100")
      stopifnot(min(scaled) == 0)
      stopifnot(max(scaled) == 100)
      stopifnot(scaled[2] == 50)

      # RAW
      raw <- rescale_utilities(utils, "RAW")
      stopifnot(all(raw == utils))

      # PROBABILITY
      prob <- rescale_utilities(utils, "PROBABILITY")
      stopifnot(abs(sum(prob) - 100) < 0.01)
    }
  )

  # ==========================================================================
  # DESIGN TESTS
  # ==========================================================================

  cat("\n--- Design Generation ---\n")

  test_results[[length(test_results) + 1]] <- run_test(
    "generate_random_design",
    function() {
      item_ids <- paste0("I", 1:8)
      design <- generate_random_design(
        item_ids = item_ids,
        items_per_task = 4,
        tasks_per_respondent = 10,
        n_versions = 2,
        verbose = FALSE
      )

      stopifnot(is.data.frame(design))
      stopifnot(nrow(design) == 20)  # 2 versions x 10 tasks
      stopifnot("Version" %in% names(design))
      stopifnot("Task_Number" %in% names(design))
      stopifnot("Item1_ID" %in% names(design))
    }
  )

  test_results[[length(test_results) + 1]] <- run_test(
    "compute_pair_frequencies",
    function() {
      # Create simple design
      design <- data.frame(
        Version = 1,
        Task_Number = 1:3,
        Item1_ID = c("A", "A", "B"),
        Item2_ID = c("B", "C", "C"),
        stringsAsFactors = FALSE
      )

      pair_freq <- compute_pair_frequencies(design, c("Item1_ID", "Item2_ID"))

      stopifnot(length(pair_freq) == 3)  # A_B, A_C, B_C
      stopifnot(pair_freq["A_B"] == 1)
      stopifnot(pair_freq["A_C"] == 1)
      stopifnot(pair_freq["B_C"] == 2)
    }
  )

  # ==========================================================================
  # COUNT SCORING TESTS
  # ==========================================================================

  cat("\n--- Count Scoring ---\n")

  test_results[[length(test_results) + 1]] <- run_test(
    "count_score_calculation",
    function() {
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

      stopifnot(is.data.frame(scores))
      stopifnot(nrow(scores) == 2)
      stopifnot("Best_Pct" %in% names(scores))
      stopifnot("Net_Score" %in% names(scores))

      # Item A should have 60% best (3/5), Item B should have 40% best (2/5)
      score_a <- scores[scores$Item_ID == "A", "Best_Pct"]
      stopifnot(abs(score_a - 60) < 0.1)
    }
  )

  # ==========================================================================
  # SUMMARY
  # ==========================================================================

  cat("\n")
  cat("================================================================================\n")
  cat("TEST SUMMARY\n")
  cat("================================================================================\n")

  for (result in test_results) {
    if (result$passed) {
      tests_passed <- tests_passed + 1
    } else {
      tests_failed <- tests_failed + 1
    }
  }

  cat(sprintf("Passed: %d\n", tests_passed))
  cat(sprintf("Failed: %d\n", tests_failed))
  cat(sprintf("Total:  %d\n", tests_passed + tests_failed))

  if (tests_failed > 0) {
    cat("\nFailed tests:\n")
    for (result in test_results) {
      if (!result$passed) {
        cat(sprintf("  - %s: %s\n", result$name, result$error))
      }
    }
  }

  cat("\n")

  return(list(
    passed = tests_passed,
    failed = tests_failed,
    results = test_results
  ))
}


# ==============================================================================
# AUTO-RUN
# ==============================================================================

# Source module files first
if (!exists("MAXDIFF_VERSION")) {
  # Try to source module - use tryCatch for robustness
  script_dir <- tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) {
    # When run through testthat, sys.frame(1)$ofile may not exist
    # Try to determine from current working directory
    if (file.exists("modules/maxdiff/tests/test_maxdiff.R")) {
      "modules/maxdiff/tests"
    } else if (basename(getwd()) == "tests") {
      getwd()
    } else {
      "."
    }
  })

  if (is.null(script_dir) || script_dir == "") script_dir <- "."

  module_dir <- file.path(dirname(script_dir), "R")
  if (dir.exists(module_dir)) {
    source(file.path(module_dir, "utils.R"))
    source(file.path(module_dir, "04_design.R"))
    source(file.path(module_dir, "05_counts.R"))
  }
}

# Run tests if executed directly
if (!interactive()) {
  results <- run_maxdiff_tests()
  quit(status = if (results$failed > 0) 1 else 0)
}
