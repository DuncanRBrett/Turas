# ==============================================================================
# TEST SUITE: Preflight Validators
# ==============================================================================
# Tests for the 14 cross-referential preflight checks in
# modules/keydriver/lib/validation/preflight_validators.R
# ==============================================================================

library(testthat)

context("Preflight Validators")

# ==============================================================================
# SETUP - same .find_module_dir() pattern used in test_v104_features.R
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

test_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."))
module_dir <- dirname(test_dir)
project_root <- normalizePath(file.path(module_dir, "..", ".."))

validators_path <- file.path(module_dir, "lib", "validation", "preflight_validators.R")

skip_if_not(file.exists(validators_path),
            "preflight_validators.R not found")

tryCatch(
  source(validators_path),
  error = function(e) skip(paste("Cannot source preflight_validators.R:", conditionMessage(e)))
)


# ==============================================================================
# HELPERS: Synthetic test data builders
# ==============================================================================

#' Build a minimal Variables sheet data frame
make_variables_df <- function(outcome = "satisfaction",
                              drivers = c("quality", "price", "service"),
                              weight = NULL,
                              driver_types = NULL,
                              agg_methods = NULL,
                              ref_levels = NULL) {
  rows <- list()

  # Outcome row
  rows[[length(rows) + 1]] <- data.frame(
    VariableName = outcome,
    Type = "Outcome",
    DriverType = NA_character_,
    AggregationMethod = NA_character_,
    ReferenceLevel = NA_character_,
    stringsAsFactors = FALSE
  )

  # Driver rows
  for (i in seq_along(drivers)) {
    dt <- if (!is.null(driver_types) && i <= length(driver_types)) driver_types[i] else "continuous"
    am <- if (!is.null(agg_methods) && i <= length(agg_methods)) agg_methods[i] else NA_character_
    rl <- if (!is.null(ref_levels) && i <= length(ref_levels)) ref_levels[i] else NA_character_

    rows[[length(rows) + 1]] <- data.frame(
      VariableName = drivers[i],
      Type = "Driver",
      DriverType = dt,
      AggregationMethod = am,
      ReferenceLevel = rl,
      stringsAsFactors = FALSE
    )
  }

  # Weight row
  if (!is.null(weight)) {
    rows[[length(rows) + 1]] <- data.frame(
      VariableName = weight,
      Type = "Weight",
      DriverType = NA_character_,
      AggregationMethod = NA_character_,
      ReferenceLevel = NA_character_,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, rows)
}

#' Build a minimal survey data frame
make_survey_data <- function(n = 100, seed = 42) {
  set.seed(seed)
  data.frame(
    satisfaction = sample(1:10, n, replace = TRUE),
    quality      = sample(1:7, n, replace = TRUE),
    price        = sample(1:7, n, replace = TRUE),
    service      = sample(1:7, n, replace = TRUE),
    brand        = sample(c("A", "B", "C"), n, replace = TRUE),
    wt           = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# CHECK 1: check_outcome_in_data
# ==============================================================================

test_that("Check 1 - outcome passes when present and numeric", {
  vars_df <- make_variables_df()
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_outcome_in_data(vars_df, data, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 1 - outcome fails when missing from data", {
  vars_df <- make_variables_df(outcome = "nonexistent_col")
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_outcome_in_data(vars_df, data, log)
  expect_true(nrow(result) > 0)
  expect_equal(result$Severity[1], "Error")
  expect_true(grepl("not found", result$Message[1]))
})

test_that("Check 1 - outcome fails when no Outcome type in variables", {
  vars_df <- make_variables_df()
  vars_df$Type[vars_df$Type == "Outcome"] <- "Driver"
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_outcome_in_data(vars_df, data, log)
  expect_true(nrow(result) > 0)
  expect_true(grepl("No variable with Type='Outcome'", result$Message[1]))
})


# ==============================================================================
# CHECK 2: check_drivers_in_data
# ==============================================================================

test_that("Check 2 - drivers pass when all present in data", {
  vars_df <- make_variables_df(drivers = c("quality", "price", "service"))
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_drivers_in_data(vars_df, data, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 2 - drivers fail when some are missing from data", {
  vars_df <- make_variables_df(drivers = c("quality", "phantom_var"))
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_drivers_in_data(vars_df, data, log)
  expect_true(nrow(result) > 0)
  expect_true(grepl("phantom_var", result$Message[1]))
})


# ==============================================================================
# CHECK 3: check_weight_in_data
# ==============================================================================

test_that("Check 3 - weight passes with valid positive numeric weights", {
  vars_df <- make_variables_df(weight = "wt")
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_weight_in_data(vars_df, data, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 3 - weight skips validation when no weight defined", {
  vars_df <- make_variables_df(weight = NULL)
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_weight_in_data(vars_df, data, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 3 - weight fails when column missing from data", {
  vars_df <- make_variables_df(weight = "missing_weight")
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_weight_in_data(vars_df, data, log)
  expect_true(nrow(result) > 0)
  expect_equal(result$Severity[1], "Error")
})


# ==============================================================================
# CHECK 4: check_driver_type_specified
# ==============================================================================

test_that("Check 4 - driver types pass when all specified and valid", {
  vars_df <- make_variables_df(driver_types = c("continuous", "ordinal", "categorical"))
  log <- init_preflight_log()

  result <- check_driver_type_specified(vars_df, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 4 - driver type fails with invalid type", {
  vars_df <- make_variables_df(driver_types = c("continuous", "banana", "categorical"))
  log <- init_preflight_log()

  result <- check_driver_type_specified(vars_df, log)
  expect_true(nrow(result) > 0)
  expect_true(grepl("banana", result$Message[1]))
})

test_that("Check 4 - driver type fails when DriverType column missing", {
  vars_df <- make_variables_df()
  vars_df$DriverType <- NULL
  log <- init_preflight_log()

  result <- check_driver_type_specified(vars_df, log)
  expect_true(nrow(result) > 0)
  expect_true(grepl("DriverType column is missing", result$Message[1]))
})


# ==============================================================================
# CHECK 5: check_categorical_aggregation
# ==============================================================================

test_that("Check 5 - categorical with valid aggregation passes", {
  vars_df <- make_variables_df(
    drivers = c("brand"),
    driver_types = c("categorical"),
    agg_methods = c("partial_r2")
  )
  log <- init_preflight_log()

  result <- check_categorical_aggregation(vars_df, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 5 - categorical with missing aggregation warns", {
  vars_df <- make_variables_df(
    drivers = c("brand"),
    driver_types = c("categorical"),
    agg_methods = c(NA_character_)
  )
  log <- init_preflight_log()

  result <- check_categorical_aggregation(vars_df, log)
  expect_true(nrow(result) > 0)
  expect_equal(result$Severity[1], "Warning")
})


# ==============================================================================
# CHECK 6: check_reference_levels_valid
# ==============================================================================

test_that("Check 6 - valid reference level passes", {
  vars_df <- make_variables_df(
    drivers = c("brand"),
    driver_types = c("categorical"),
    ref_levels = c("A")
  )
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_reference_levels_valid(vars_df, data, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 6 - invalid reference level errors", {
  vars_df <- make_variables_df(
    drivers = c("brand"),
    driver_types = c("categorical"),
    ref_levels = c("Z")
  )
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_reference_levels_valid(vars_df, data, log)
  expect_true(nrow(result) > 0)
  expect_equal(result$Severity[1], "Error")
  expect_true(grepl("does not exist", result$Message[1]))
})


# ==============================================================================
# CHECK 7: check_sample_size_rule
# ==============================================================================

test_that("Check 7 - adequate sample size passes", {
  vars_df <- make_variables_df(drivers = c("quality", "price"))
  data <- make_survey_data(n = 100)
  log <- init_preflight_log()

  result <- check_sample_size_rule(vars_df, data, log)
  # 100 >= max(30, 10*2=20) so should pass with no errors
  errors_only <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors_only), 0)
})

test_that("Check 7 - insufficient sample size errors", {
  vars_df <- make_variables_df(drivers = paste0("d", 1:5))
  # Need max(30, 50) = 50 complete cases, provide only 10
  set.seed(1)
  data <- data.frame(
    satisfaction = 1:10,
    d1 = 1:10, d2 = 1:10, d3 = 1:10, d4 = 1:10, d5 = 1:10
  )
  log <- init_preflight_log()

  result <- check_sample_size_rule(vars_df, data, log)
  expect_true(nrow(result) > 0)
  expect_equal(result$Severity[1], "Error")
  expect_true(grepl("Insufficient sample size", result$Message[1]))
})


# ==============================================================================
# CHECK 8: check_zero_variance_drivers
# ==============================================================================

test_that("Check 8 - zero variance driver errors", {
  vars_df <- make_variables_df(drivers = c("quality", "price"))
  data <- make_survey_data(n = 50)
  data$quality <- rep(5, 50)  # zero variance
  log <- init_preflight_log()

  result <- check_zero_variance_drivers(vars_df, data, log)
  expect_true(nrow(result) > 0)
  expect_true(grepl("zero variance", result$Message[1]))
})


# ==============================================================================
# CHECK 9: check_collinearity_warning
# ==============================================================================

test_that("Check 9 - high collinearity warns", {
  vars_df <- make_variables_df(drivers = c("quality", "price"))
  set.seed(99)
  data <- data.frame(
    satisfaction = rnorm(100),
    quality = rnorm(100)
  )
  data$price <- data$quality + rnorm(100, sd = 0.01)  # nearly identical
  log <- init_preflight_log()

  result <- check_collinearity_warning(vars_df, data, log)
  expect_true(nrow(result) > 0)
  expect_equal(result$Severity[1], "Warning")
  expect_true(grepl("collinearity", tolower(result$Message[1])))
})


# ==============================================================================
# CHECK 10: check_segment_variables
# ==============================================================================

test_that("Check 10 - valid segments pass", {
  segments_df <- data.frame(
    segment_name = "By Brand",
    segment_variable = "brand",
    segment_values = "A,B",
    stringsAsFactors = FALSE
  )
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_segment_variables(segments_df, data, log)
  errors_only <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors_only), 0)
})

test_that("Check 10 - missing segment variable errors", {
  segments_df <- data.frame(
    segment_name = "By Region",
    segment_variable = "region",
    segment_values = "North,South",
    stringsAsFactors = FALSE
  )
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_segment_variables(segments_df, data, log)
  expect_true(nrow(result) > 0)
  expect_equal(result$Severity[1], "Error")
})

test_that("Check 10 - NULL segments_df skips gracefully", {
  data <- make_survey_data()
  log <- init_preflight_log()

  result <- check_segment_variables(NULL, data, log)
  expect_equal(nrow(result), 0)
})


# ==============================================================================
# CHECK 11: check_stated_importance_drivers
# ==============================================================================

test_that("Check 11 - stated importance matching drivers passes", {
  vars_df <- make_variables_df(drivers = c("quality", "price"))
  stated_df <- data.frame(
    driver = c("quality", "price"),
    importance = c(8.5, 7.2),
    stringsAsFactors = FALSE
  )
  log <- init_preflight_log()

  result <- check_stated_importance_drivers(stated_df, vars_df, log)
  errors_only <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors_only), 0)
})

test_that("Check 11 - stated importance referencing unknown driver errors", {
  vars_df <- make_variables_df(drivers = c("quality", "price"))
  stated_df <- data.frame(
    driver = c("quality", "phantom_driver"),
    importance = c(8.5, 7.2),
    stringsAsFactors = FALSE
  )
  log <- init_preflight_log()

  result <- check_stated_importance_drivers(stated_df, vars_df, log)
  errors_only <- result[result$Severity == "Error", ]
  expect_true(nrow(errors_only) > 0)
  expect_true(grepl("phantom_driver", errors_only$Message[1]))
})


# ==============================================================================
# CHECK 12: check_shap_dependencies
# ==============================================================================

test_that("Check 12 - SHAP disabled skips check", {
  config <- list(enable_shap = FALSE)
  log <- init_preflight_log()

  result <- check_shap_dependencies(config, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 12 - SHAP NULL skips check", {
  config <- list(enable_shap = NULL)
  log <- init_preflight_log()

  result <- check_shap_dependencies(config, log)
  expect_equal(nrow(result), 0)
})


# ==============================================================================
# CHECK 13: check_quadrant_requirements
# ==============================================================================

test_that("Check 13 - quadrant disabled skips check", {
  config <- list(enable_quadrant = FALSE)
  log <- init_preflight_log()

  result <- check_quadrant_requirements(config, NULL, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 13 - quadrant auto without stated importance errors", {
  config <- list(enable_quadrant = TRUE, importance_source = "auto")
  log <- init_preflight_log()

  result <- check_quadrant_requirements(config, NULL, log)
  expect_true(nrow(result) > 0)
  expect_equal(result$Severity[1], "Error")
  expect_true(grepl("StatedImportance", result$Message[1]))
})

test_that("Check 13 - quadrant with derived importance_source passes without stated", {
  config <- list(enable_quadrant = TRUE, importance_source = "shapley")
  log <- init_preflight_log()

  result <- check_quadrant_requirements(config, NULL, log)
  expect_equal(nrow(result), 0)
})


# ==============================================================================
# CHECK 14: check_feature_policies_valid
# ==============================================================================

test_that("Check 14 - valid policies pass", {
  config <- list(shap_on_fail = "refuse", quadrant_on_fail = "continue_with_flag")
  log <- init_preflight_log()

  result <- check_feature_policies_valid(config, log)
  expect_equal(nrow(result), 0)
})

test_that("Check 14 - invalid policy errors", {
  config <- list(shap_on_fail = "explode", quadrant_on_fail = "refuse")
  log <- init_preflight_log()

  result <- check_feature_policies_valid(config, log)
  expect_true(nrow(result) > 0)
  expect_true(grepl("explode", result$Message[1]))
})


# ==============================================================================
# ORCHESTRATOR: validate_keydriver_preflight
# ==============================================================================

test_that("Orchestrator returns clean log for valid inputs", {
  vars_df <- make_variables_df(
    outcome = "satisfaction",
    drivers = c("quality", "price"),
    weight = "wt",
    driver_types = c("continuous", "continuous")
  )
  data <- make_survey_data(n = 100)
  config <- list(
    enable_shap = FALSE,
    enable_quadrant = FALSE
  )

  result <- validate_keydriver_preflight(
    config, data, vars_df,
    segments_df = NULL, stated_df = NULL,
    verbose = FALSE
  )

  errors_only <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors_only), 0)
})

test_that("Orchestrator accumulates multiple errors", {
  # Deliberately broken: missing outcome, missing driver, bad policy
  vars_df <- make_variables_df(
    outcome = "nonexistent_outcome",
    drivers = c("ghost_driver"),
    driver_types = c("continuous")
  )
  data <- make_survey_data(n = 10)
  config <- list(
    enable_shap = FALSE,
    enable_quadrant = FALSE,
    shap_on_fail = "invalid_policy"
  )

  result <- validate_keydriver_preflight(
    config, data, vars_df,
    segments_df = NULL, stated_df = NULL,
    verbose = FALSE
  )

  errors_only <- result[result$Severity == "Error", ]
  # Should have at least 3 errors: outcome not found, driver not found, bad policy
  expect_true(nrow(errors_only) >= 3)
})

test_that("Orchestrator returns a data frame with standard columns", {
  vars_df <- make_variables_df()
  data <- make_survey_data()
  config <- list()

  result <- validate_keydriver_preflight(
    config, data, vars_df,
    verbose = FALSE
  )

  expect_true(is.data.frame(result))
  expect_true(all(c("Component", "Check", "Field", "Message", "Severity") %in% names(result)))
})
