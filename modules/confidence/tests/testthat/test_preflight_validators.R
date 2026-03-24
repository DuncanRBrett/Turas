# ==============================================================================
# TESTS: Preflight Validators (preflight_validators.R)
# ==============================================================================
# Tests for the 13 cross-referential checks that validate config, question
# definitions, and data before confidence interval analysis begins.
#
# Run with:
#   testthat::test_file("modules/confidence/tests/testthat/test_preflight_validators.R")
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

find_turas_root <- function() {
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "shared"))) {
      return(path)
    }
    path <- dirname(path)
  }
  test_dir <- testthat::test_path()
  path <- test_dir
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "shared"))) {
      return(path)
    }
    path <- dirname(path)
  }
  stop("Cannot find Turas root directory")
}

TURAS_ROOT <- find_turas_root()
MODULE_DIR <- file.path(TURAS_ROOT, "modules", "confidence")

# Source shared utilities
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
for (f in c("trs_refusal.R", "logging_utils.R", "config_utils.R")) {
  fp <- file.path(shared_lib, f)
  if (file.exists(fp)) {
    tryCatch(source(fp, local = FALSE), error = function(e) {
      message("Note: Could not source ", f, ": ", conditionMessage(e))
    })
  }
}

# Source preflight validators
preflight_path <- file.path(MODULE_DIR, "lib", "validation", "preflight_validators.R")
if (file.exists(preflight_path)) {
  source(preflight_path)
} else {
  stop("Cannot find preflight_validators.R at: ", preflight_path)
}


# ==============================================================================
# HELPERS
# ==============================================================================

new_error_log <- function() {
  data.frame(
    Check = character(0), Issue = character(0),
    Detail = character(0), Context = character(0),
    Severity = character(0), stringsAsFactors = FALSE
  )
}

make_questions_df <- function(ids = c("Q1", "Q2"),
                               stat_types = c("proportion", "mean"),
                               categories = c("1,2", NA),
                               run_moe = c("Y", "Y")) {
  df <- data.frame(
    Question_ID = ids,
    Statistic_Type = stat_types,
    Run_MOE = run_moe,
    stringsAsFactors = FALSE
  )
  if (!is.null(categories)) {
    df$Categories <- categories
  }
  df
}

make_survey_data <- function(n = 50) {
  data.frame(
    Q1 = sample(c("1", "2", "3"), n, replace = TRUE),
    Q2 = rnorm(n, 5, 2),
    Weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# TESTS
# ==============================================================================

# --- 1. check_question_columns_in_data ---

test_that("check_question_columns_in_data detects missing columns", {
  skip_if(!exists("check_question_columns_in_data", mode = "function"),
          "check_question_columns_in_data not available")

  questions_df <- make_questions_df(ids = c("Q1", "Q_MISSING"))
  data <- data.frame(Q1 = 1:5, stringsAsFactors = FALSE)

  result <- check_question_columns_in_data(questions_df, data, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Q_MISSING", errors$Detail)))
})

test_that("check_question_columns_in_data passes with all columns present", {
  skip_if(!exists("check_question_columns_in_data", mode = "function"),
          "check_question_columns_in_data not available")

  questions_df <- make_questions_df(ids = c("Q1", "Q2"))
  data <- make_survey_data()

  result <- check_question_columns_in_data(questions_df, data, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 2. check_statistic_type_validity ---

test_that("check_statistic_type_validity detects invalid type", {
  skip_if(!exists("check_statistic_type_validity", mode = "function"),
          "check_statistic_type_validity not available")

  questions_df <- make_questions_df(
    ids = c("Q1"), stat_types = c("invalid_type"), categories = NULL, run_moe = "Y"
  )

  result <- check_statistic_type_validity(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("invalid_type", errors$Detail)))
})

test_that("check_statistic_type_validity detects missing type", {
  skip_if(!exists("check_statistic_type_validity", mode = "function"),
          "check_statistic_type_validity not available")

  questions_df <- data.frame(
    Question_ID = "Q1", Statistic_Type = NA_character_,
    Run_MOE = "Y", stringsAsFactors = FALSE
  )

  result <- check_statistic_type_validity(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})


# --- 3. check_method_selection ---

test_that("check_method_selection detects no CI method selected", {
  skip_if(!exists("check_method_selection", mode = "function"),
          "check_method_selection not available")

  questions_df <- data.frame(
    Question_ID = "Q1", Statistic_Type = "proportion",
    Run_MOE = "N", Run_Wilson = "N", Run_Bootstrap = "N", Run_Credible = "N",
    stringsAsFactors = FALSE
  )

  result <- check_method_selection(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("No CI Method", errors$Issue)))
})

test_that("check_method_selection passes when at least one method selected", {
  skip_if(!exists("check_method_selection", mode = "function"),
          "check_method_selection not available")

  questions_df <- data.frame(
    Question_ID = "Q1", Statistic_Type = "proportion",
    Run_MOE = "N", Run_Wilson = "Y", Run_Bootstrap = "N", Run_Credible = "N",
    stringsAsFactors = FALSE
  )

  result <- check_method_selection(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 4. check_proportion_categories ---

test_that("check_proportion_categories detects missing categories", {
  skip_if(!exists("check_proportion_categories", mode = "function"),
          "check_proportion_categories not available")

  questions_df <- data.frame(
    Question_ID = "Q1", Statistic_Type = "proportion",
    Categories = NA_character_, Run_MOE = "Y",
    stringsAsFactors = FALSE
  )

  result <- check_proportion_categories(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Missing Categories", errors$Issue)))
})


# --- 5. check_nps_codes ---

test_that("check_nps_codes detects missing Promoter_Codes for NPS question", {
  skip_if(!exists("check_nps_codes", mode = "function"),
          "check_nps_codes not available")

  questions_df <- data.frame(
    Question_ID = "QNPS", Statistic_Type = "nps",
    Promoter_Codes = NA_character_, Detractor_Codes = "0,1,2,3,4,5,6",
    Run_MOE = "Y", stringsAsFactors = FALSE
  )

  result <- check_nps_codes(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Promoter", errors$Issue)))
})


# --- 6. check_nps_code_overlap ---

test_that("check_nps_code_overlap detects overlapping codes", {
  skip_if(!exists("check_nps_code_overlap", mode = "function"),
          "check_nps_code_overlap not available")

  questions_df <- data.frame(
    Question_ID = "QNPS", Statistic_Type = "nps",
    Promoter_Codes = "9,10,7", Detractor_Codes = "0,1,2,7",
    Run_MOE = "Y", stringsAsFactors = FALSE
  )

  result <- check_nps_code_overlap(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("7", errors$Detail)))
})

test_that("check_nps_code_overlap passes with non-overlapping codes", {
  skip_if(!exists("check_nps_code_overlap", mode = "function"),
          "check_nps_code_overlap not available")

  questions_df <- data.frame(
    Question_ID = "QNPS", Statistic_Type = "nps",
    Promoter_Codes = "9,10", Detractor_Codes = "0,1,2,3,4,5,6",
    Run_MOE = "Y", stringsAsFactors = FALSE
  )

  result <- check_nps_code_overlap(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 7. check_prior_specs ---

test_that("check_prior_specs detects invalid Prior_Mean for proportion", {
  skip_if(!exists("check_prior_specs", mode = "function"),
          "check_prior_specs not available")

  questions_df <- data.frame(
    Question_ID = "Q1", Statistic_Type = "proportion",
    Prior_Mean = 1.5, Prior_SD = 0.1, Prior_N = NA_real_,
    Run_MOE = "Y", stringsAsFactors = FALSE
  )

  result <- check_prior_specs(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Prior_Mean", errors$Issue)))
})

test_that("check_prior_specs detects negative Prior_SD", {
  skip_if(!exists("check_prior_specs", mode = "function"),
          "check_prior_specs not available")

  questions_df <- data.frame(
    Question_ID = "Q1", Statistic_Type = "mean",
    Prior_Mean = 5.0, Prior_SD = -1.0, Prior_N = NA_real_,
    Run_MOE = "Y", stringsAsFactors = FALSE
  )

  result <- check_prior_specs(questions_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Prior_SD", errors$Issue)))
})


# --- 8. check_weight_variable_in_data ---

test_that("check_weight_variable_in_data detects missing weight column", {
  skip_if(!exists("check_weight_variable_in_data", mode = "function"),
          "check_weight_variable_in_data not available")

  config <- list(Weight_Variable = "NonExistent")
  data <- data.frame(Q1 = 1:5, stringsAsFactors = FALSE)

  result <- check_weight_variable_in_data(config, data, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})

test_that("check_weight_variable_in_data skips when no weight variable", {
  skip_if(!exists("check_weight_variable_in_data", mode = "function"),
          "check_weight_variable_in_data not available")

  config <- list(Weight_Variable = NA_character_)
  data <- data.frame(Q1 = 1:5, stringsAsFactors = FALSE)

  result <- check_weight_variable_in_data(config, data, new_error_log())
  expect_equal(nrow(result), 0)
})


# --- 9. check_confidence_level_valid ---

test_that("check_confidence_level_valid detects invalid level", {
  skip_if(!exists("check_confidence_level_valid", mode = "function"),
          "check_confidence_level_valid not available")

  config <- list(Confidence_Level = 0.80)
  result <- check_confidence_level_valid(config, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})

test_that("check_confidence_level_valid passes with 0.95", {
  skip_if(!exists("check_confidence_level_valid", mode = "function"),
          "check_confidence_level_valid not available")

  config <- list(Confidence_Level = 0.95)
  result <- check_confidence_level_valid(config, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 10. check_bootstrap_iterations ---

test_that("check_bootstrap_iterations detects out-of-range value", {
  skip_if(!exists("check_bootstrap_iterations", mode = "function"),
          "check_bootstrap_iterations not available")

  config <- list(Bootstrap_Iterations = 500)
  result <- check_bootstrap_iterations(config, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})

test_that("check_bootstrap_iterations passes with valid value", {
  skip_if(!exists("check_bootstrap_iterations", mode = "function"),
          "check_bootstrap_iterations not available")

  config <- list(Bootstrap_Iterations = 5000)
  result <- check_bootstrap_iterations(config, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 11. check_population_margins_sum ---

test_that("check_population_margins_sum detects incorrect sum", {
  skip_if(!exists("check_population_margins_sum", mode = "function"),
          "check_population_margins_sum not available")

  margins_df <- data.frame(
    Variable = c("Gender", "Gender"),
    Category = c("Male", "Female"),
    Target_Prop = c(0.4, 0.4),
    stringsAsFactors = FALSE
  )
  result <- check_population_margins_sum(margins_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})


# --- 12. validate_confidence_preflight orchestrator ---

test_that("validate_confidence_preflight runs on valid inputs", {
  skip_if(!exists("validate_confidence_preflight", mode = "function"),
          "validate_confidence_preflight not available")

  questions_df <- data.frame(
    Question_ID = c("Q1", "Q2"),
    Statistic_Type = c("proportion", "mean"),
    Categories = c("1,2", NA),
    Run_MOE = c("Y", "Y"),
    stringsAsFactors = FALSE
  )
  data <- make_survey_data()
  config <- list(Confidence_Level = 0.95, Weight_Variable = NA_character_)

  result <- validate_confidence_preflight(config, data, questions_df)
  expect_true(is.data.frame(result))
})

test_that("validate_confidence_preflight detects multiple issues", {
  skip_if(!exists("validate_confidence_preflight", mode = "function"),
          "validate_confidence_preflight not available")

  questions_df <- data.frame(
    Question_ID = c("Q_MISS"),
    Statistic_Type = c("invalid"),
    Run_MOE = c("N"),
    stringsAsFactors = FALSE
  )
  data <- data.frame(Q1 = 1:5, stringsAsFactors = FALSE)
  config <- list(
    Confidence_Level = 0.80,
    Weight_Variable = "no_such_wt",
    Bootstrap_Iterations = 100
  )

  result <- validate_confidence_preflight(config, data, questions_df)
  expect_true(is.data.frame(result))
  expect_true(nrow(result) >= 3)
})
