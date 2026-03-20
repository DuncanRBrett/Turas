# ==============================================================================
# TEST SUITE: Executive Summary (08_executive_summary.R)
# ==============================================================================
# Tests for generate_executive_summary(), format_executive_summary(),
# summarize_top_drivers(), assess_method_agreement(), assess_model_quality(),
# detect_dominant_driver(), and check_vif_concerns().
# Part of Turas Key Driver Module Test Suite
# ==============================================================================

library(testthat)

context("Executive Summary")

# ==============================================================================
# SETUP
# ==============================================================================

# Null-coalescing operator (may not be loaded in test context)
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Locate module root robustly (works with test_file and test_dir)
.find_module_dir <- function() {
  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(ofile)) {
    return(normalizePath(file.path(dirname(ofile), "..", ".."), mustWork = FALSE))
  }
  tp <- tryCatch(testthat::test_path(), error = function(e) ".")
  normalizePath(file.path(tp, "..", ".."), mustWork = FALSE)
}
module_dir <- .find_module_dir()
project_root <- normalizePath(file.path(module_dir, "..", ".."), mustWork = FALSE)

# Source test data generators
source(file.path(module_dir, "tests", "fixtures", "generate_test_data.R"))

# Source TRS infrastructure
source(file.path(project_root, "modules", "shared", "lib", "trs_refusal.R"))

# Source guard layer
tryCatch(source(file.path(module_dir, "R", "00_guard.R")), error = function(e) NULL)

# Source output utilities (for calculate_vif)
tryCatch(source(file.path(module_dir, "R", "04_output.R")), error = function(e) NULL)

# Source the module under test
source(file.path(module_dir, "R", "08_executive_summary.R"))


# ==============================================================================
# HELPER: Build mock results with a real lm model for full integration
# ==============================================================================

build_mock_results_with_model <- function(n = 200, r2_target = "good", seed = 42) {
  set.seed(seed)

  drivers <- data.frame(
    driver_1 = rnorm(n),
    driver_2 = rnorm(n),
    driver_3 = rnorm(n),
    driver_4 = rnorm(n),
    driver_5 = rnorm(n)
  )

  # Vary noise to control R-squared
  noise_sd <- switch(r2_target,
    "good" = 0.5,
    "moderate" = 1.5,
    "low" = 4.0,
    "very_low" = 10.0,
    1.0
  )

  outcome <- 0.5 * drivers$driver_1 + 0.3 * drivers$driver_2 +
    0.15 * drivers$driver_3 + 0.05 * drivers$driver_4 +
    0.02 * drivers$driver_5 + rnorm(n, sd = noise_sd)

  df <- cbind(outcome = outcome, drivers)
  model <- lm(outcome ~ driver_1 + driver_2 + driver_3 + driver_4 + driver_5, data = df)

  # Build importance data.frame with the columns the module expects
  coefs <- abs(coef(model)[-1])
  pcts <- round(100 * coefs / sum(coefs), 1)
  ranks <- rank(-pcts)

  importance <- data.frame(
    Driver = names(coefs),
    Shapley_Value = pcts,
    Relative_Weight = pcts * runif(5, 0.9, 1.1),
    Beta_Weight = pcts * runif(5, 0.85, 1.15),
    Shapley_Rank = ranks,
    RelWeight_Rank = rank(-pcts * runif(5, 0.9, 1.1)),
    Beta_Rank = rank(-pcts * runif(5, 0.85, 1.15)),
    stringsAsFactors = FALSE
  )

  list(
    importance = importance,
    model = model,
    config = list(outcome_var = "outcome")
  )
}

build_importance_df <- function(drivers, pcts, rank_cols = TRUE) {
  n <- length(drivers)
  df <- data.frame(
    Driver = drivers,
    Shapley_Value = pcts,
    Relative_Weight = pcts * runif(n, 0.9, 1.1),
    stringsAsFactors = FALSE
  )
  if (rank_cols) {
    df$Shapley_Rank <- rank(-df$Shapley_Value)
    df$RelWeight_Rank <- rank(-df$Relative_Weight)
  }
  df
}


# ==============================================================================
# TESTS: generate_executive_summary()
# ==============================================================================

test_that("generate_executive_summary returns list with expected fields", {
  results <- build_mock_results_with_model(n = 200, r2_target = "good")

  summary <- generate_executive_summary(results)

  expect_true(is.list(summary))
  expected_fields <- c("headline", "key_findings", "method_agreement",
                        "model_quality", "warnings", "recommendations")
  for (field in expected_fields) {
    expect_true(field %in% names(summary),
                info = paste("Missing field:", field))
  }

  # headline should be a single character string
  expect_true(is.character(summary$headline))
  expect_equal(length(summary$headline), 1)

  # key_findings should be a character vector
  expect_true(is.character(summary$key_findings))
  expect_true(length(summary$key_findings) >= 1)

  # recommendations should be a character vector with 2-3 items
  expect_true(is.character(summary$recommendations))
  expect_true(length(summary$recommendations) >= 2)
  expect_true(length(summary$recommendations) <= 3)
})

test_that("generate_executive_summary refuses NULL results", {
  expect_error(
    generate_executive_summary(NULL),
    class = "turas_refusal"
  )
})

test_that("generate_executive_summary refuses results without importance", {
  results <- list(model = lm(1:10 ~ rnorm(10)))
  expect_error(
    generate_executive_summary(results),
    class = "turas_refusal"
  )
})

test_that("generate_executive_summary refuses results without model", {
  results <- list(
    importance = data.frame(Driver = "X", Shapley_Value = 100, stringsAsFactors = FALSE)
  )
  expect_error(
    generate_executive_summary(results),
    class = "turas_refusal"
  )
})


# ==============================================================================
# TESTS: format_executive_summary()
# ==============================================================================

test_that("format_executive_summary with format='text' returns character vector", {
  results <- build_mock_results_with_model(n = 200, r2_target = "good")
  summary <- generate_executive_summary(results)

  text_output <- format_executive_summary(summary, format = "text")

  expect_true(is.character(text_output))
  expect_true(length(text_output) > 1)  # Multiple lines

  # Should contain key sections
  full_text <- paste(text_output, collapse = "\n")
  expect_true(grepl("EXECUTIVE SUMMARY", full_text))
  expect_true(grepl("KEY FINDINGS", full_text))
  expect_true(grepl("RECOMMENDATIONS", full_text))
})

test_that("format_executive_summary with format='html' returns HTML string", {
  results <- build_mock_results_with_model(n = 200, r2_target = "good")
  summary <- generate_executive_summary(results)

  html_output <- format_executive_summary(summary, format = "html")

  expect_true(is.character(html_output))
  expect_equal(length(html_output), 1)  # Single string

  # Should contain HTML tags
  expect_true(grepl("<div", html_output))
  expect_true(grepl("<h2", html_output))
  expect_true(grepl("Executive Summary", html_output))
  expect_true(grepl("</div>", html_output))
})

test_that("format_executive_summary refuses NULL input", {
  expect_error(
    format_executive_summary(NULL),
    class = "turas_refusal"
  )
})


# ==============================================================================
# TESTS: summarize_top_drivers()
# ==============================================================================

test_that("summarize_top_drivers correctly identifies top drivers", {
  set.seed(100)
  imp_df <- build_importance_df(
    drivers = c("Price", "Quality", "Service", "Brand", "Speed"),
    pcts = c(35, 28, 20, 12, 5)
  )

  result <- summarize_top_drivers(imp_df, top_n = 3)

  expect_true(is.character(result))
  expect_equal(length(result), 1)
  expect_true(grepl("top 3 drivers", result, ignore.case = TRUE))

  # Should mention the top 3 drivers by name

  expect_true(grepl("Price", result))
  expect_true(grepl("Quality", result))
  expect_true(grepl("Service", result))

  # Should include percentages
  expect_true(grepl("35%", result))
})

test_that("summarize_top_drivers handles empty data", {
  result <- summarize_top_drivers(NULL)
  expect_true(is.character(result))
  expect_true(grepl("No importance data", result, ignore.case = TRUE))

  result2 <- summarize_top_drivers(data.frame())
  expect_true(grepl("No importance data", result2, ignore.case = TRUE))
})

test_that("summarize_top_drivers handles fewer drivers than top_n", {
  set.seed(101)
  imp_df <- build_importance_df(
    drivers = c("Price", "Quality"),
    pcts = c(60, 40)
  )

  result <- summarize_top_drivers(imp_df, top_n = 5)

  # Should still work with only 2 drivers
  expect_true(is.character(result))
  expect_true(grepl("top 2 drivers", result, ignore.case = TRUE))
})


# ==============================================================================
# TESTS: assess_method_agreement()
# ==============================================================================

test_that("assess_method_agreement detects agreement when ranks correlate highly", {
  # All methods agree on the same ranking
  imp_df <- data.frame(
    Driver = c("A", "B", "C", "D", "E"),
    Shapley_Rank = c(1, 2, 3, 4, 5),
    RelWeight_Rank = c(1, 2, 3, 4, 5),
    Beta_Rank = c(1, 2, 3, 4, 5),
    stringsAsFactors = FALSE
  )

  result <- assess_method_agreement(imp_df)

  expect_true(is.character(result))
  expect_true(grepl("Strong agreement", result, ignore.case = TRUE))
})

test_that("assess_method_agreement detects disagreement when ranks diverge", {
  # Methods disagree completely
  imp_df <- data.frame(
    Driver = c("A", "B", "C", "D", "E"),
    Shapley_Rank = c(1, 2, 3, 4, 5),
    RelWeight_Rank = c(5, 4, 3, 2, 1),
    Beta_Rank = c(3, 1, 5, 2, 4),
    stringsAsFactors = FALSE
  )

  result <- assess_method_agreement(imp_df)

  expect_true(is.character(result))
  # Should not say "Strong agreement" with reversed rankings
  expect_false(grepl("Strong agreement", result))
})

test_that("assess_method_agreement handles single ranking method", {
  imp_df <- data.frame(
    Driver = c("A", "B", "C"),
    Shapley_Rank = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- assess_method_agreement(imp_df)
  expect_true(is.character(result))
  expect_true(grepl("one ranking method|Only one", result, ignore.case = TRUE))
})

test_that("assess_method_agreement handles too few drivers", {
  imp_df <- data.frame(
    Driver = c("A", "B"),
    Shapley_Rank = c(1, 2),
    RelWeight_Rank = c(1, 2),
    stringsAsFactors = FALSE
  )

  result <- assess_method_agreement(imp_df)
  expect_true(is.character(result))
  expect_true(grepl("Too few drivers", result, ignore.case = TRUE))
})


# ==============================================================================
# TESTS: assess_model_quality()
# ==============================================================================

test_that("assess_model_quality interprets R-squared values correctly", {
  # Good model
  result_good <- assess_model_quality(0.65, n_obs = 200, n_drivers = 5)
  expect_true(grepl("good", result_good, ignore.case = TRUE))
  expect_true(grepl("65%", result_good))

  # Moderate model
  result_mod <- assess_model_quality(0.35, n_obs = 200, n_drivers = 5)
  expect_true(grepl("moderate", result_mod, ignore.case = TRUE))

  # Low model
  result_low <- assess_model_quality(0.15, n_obs = 200, n_drivers = 5)
  expect_true(grepl("low", result_low, ignore.case = TRUE))
  # Should not match "very low"
  expect_false(grepl("very low", result_low, ignore.case = TRUE))

  # Very low model
  result_vlow <- assess_model_quality(0.05, n_obs = 200, n_drivers = 5)
  expect_true(grepl("very low", result_vlow, ignore.case = TRUE))
})

test_that("assess_model_quality includes sample size and driver count", {
  result <- assess_model_quality(0.50, n_obs = 450, n_drivers = 8)

  expect_true(grepl("n=450", result))
  expect_true(grepl("8 drivers", result))
})

test_that("assess_model_quality handles NULL R-squared", {
  result <- assess_model_quality(NULL, n_obs = 200, n_drivers = 5)
  expect_true(grepl("not available", result, ignore.case = TRUE))

  result_na <- assess_model_quality(NA, n_obs = 200, n_drivers = 5)
  expect_true(grepl("not available", result_na, ignore.case = TRUE))
})

test_that("assess_model_quality respects custom thresholds", {
  # With custom thresholds, 0.35 should be "good" if good threshold is 0.30
  result <- assess_model_quality(0.35, n_obs = 200, n_drivers = 5,
                                  thresholds = list(low = 0.05, moderate = 0.15, good = 0.30))
  expect_true(grepl("good", result, ignore.case = TRUE))
})


# ==============================================================================
# TESTS: detect_dominant_driver()
# ==============================================================================

test_that("detect_dominant_driver identifies drivers with >40% importance", {
  set.seed(200)
  imp_df <- build_importance_df(
    drivers = c("Price", "Quality", "Service"),
    pcts = c(55, 30, 15),
    rank_cols = FALSE
  )

  result <- detect_dominant_driver(imp_df, threshold = 40)

  expect_true(is.character(result))
  expect_true(grepl("Price", result))
  expect_true(grepl("55%", result))
  expect_true(grepl("dominant", result, ignore.case = TRUE))
})

test_that("detect_dominant_driver returns NULL when no driver exceeds threshold", {
  set.seed(201)
  imp_df <- build_importance_df(
    drivers = c("Price", "Quality", "Service"),
    pcts = c(35, 35, 30),
    rank_cols = FALSE
  )

  result <- detect_dominant_driver(imp_df, threshold = 40)
  expect_null(result)
})

test_that("detect_dominant_driver handles empty data", {
  result <- detect_dominant_driver(NULL)
  expect_null(result)

  result2 <- detect_dominant_driver(data.frame())
  expect_null(result2)
})

test_that("detect_dominant_driver respects custom threshold", {
  set.seed(202)
  imp_df <- build_importance_df(
    drivers = c("Price", "Quality"),
    pcts = c(30, 70),
    rank_cols = FALSE
  )

  # At default 40%, Quality should be flagged
  result_default <- detect_dominant_driver(imp_df, threshold = 40)
  expect_true(is.character(result_default))
  expect_true(grepl("Quality", result_default))

  # At 80% threshold, nothing should be flagged
  result_high <- detect_dominant_driver(imp_df, threshold = 80)
  expect_null(result_high)
})


# ==============================================================================
# TESTS: check_vif_concerns()
# ==============================================================================

test_that("check_vif_concerns flags high VIF values", {
  vif_vals <- c(driver_1 = 1.2, driver_2 = 7.5, driver_3 = 2.1, driver_4 = 6.3)

  result <- check_vif_concerns(vif_vals, threshold = 5)

  expect_true(is.character(result))
  expect_true(grepl("Multicollinearity", result))
  expect_true(grepl("driver_2", result))
  expect_true(grepl("driver_4", result))
  expect_true(grepl("VIF", result))
})

test_that("check_vif_concerns returns NULL when all VIF values are below threshold", {
  vif_vals <- c(driver_1 = 1.2, driver_2 = 2.5, driver_3 = 3.1)

  result <- check_vif_concerns(vif_vals, threshold = 5)
  expect_null(result)
})

test_that("check_vif_concerns returns NULL for NULL input", {
  result <- check_vif_concerns(NULL)
  expect_null(result)

  result2 <- check_vif_concerns(numeric(0))
  expect_null(result2)
})

test_that("check_vif_concerns uses singular/plural grammar correctly", {
  # Single high VIF
  vif_single <- c(driver_1 = 8.0, driver_2 = 2.0)
  result_single <- check_vif_concerns(vif_single, threshold = 5)
  expect_true(grepl("has VIF", result_single))

  # Multiple high VIF
  vif_multi <- c(driver_1 = 8.0, driver_2 = 6.0)
  result_multi <- check_vif_concerns(vif_multi, threshold = 5)
  expect_true(grepl("have VIF", result_multi))
})
