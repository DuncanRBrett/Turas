# ==============================================================================
# TABS MODULE - VALIDATION SYSTEM TESTS
# ==============================================================================
#
# Tests for the validation pipeline:
#   1. Structure validators — duplicates, orphans, missing options, variable types
#   2. Config validators — alpha, min_base, decimal places, output format
#   3. Weight validators — weight variable, values, distribution
#   4. Data validators — numeric questions, bin structure/overlaps/coverage
#   5. Preflight validators — cross-referential checks (selection/data/config)
#   6. Orchestrator — run_all_validations
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_validation.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

# Source shared + tabs utilities
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))

# Set .tabs_lib_dir (required by tabs_source() for subdirectory loading)
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())

# Define create_error_log (from shared_functions.R) — avoid sourcing the orchestrator
# Assign to globalenv so validation.R functions can find it
create_error_log <- function() {
  data.frame(
    Timestamp = character(), Component = character(),
    Issue_Type = character(), Description = character(),
    QuestionCode = character(), Severity = character(),
    stringsAsFactors = FALSE
  )
}
assign("create_error_log", create_error_log, envir = globalenv())

# Source logging_utils for log_issue()
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))

# Source validation system
source(file.path(turas_root, "modules/tabs/lib/validation.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Create a clean error log
new_error_log <- function() {
  create_error_log()
}

# Minimal valid questions data frame
make_test_questions <- function() {
  data.frame(
    QuestionCode = c("Q1", "Q2", "Q3"),
    QuestionText = c("Satisfaction", "Age group", "Media usage"),
    Variable_Type = c("Single_Response", "Single_Response", "Multi_Mention"),
    Columns = c("Q1", "Q2", "3"),
    stringsAsFactors = FALSE
  )
}

# Minimal valid options data frame
make_test_options <- function() {
  data.frame(
    QuestionCode = c("Q1", "Q1", "Q1", "Q2", "Q2",
                     "Q3", "Q3", "Q3"),
    OptionText = c("Satisfied", "Neutral", "Dissatisfied",
                   "18-34", "35+",
                   "TV", "Radio", "Online"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied",
                    "18-34", "35+",
                    "TV", "Radio", "Online"),
    ShowInOutput = rep("Y", 8),
    stringsAsFactors = FALSE
  )
}

# Minimal valid config
make_test_config <- function() {
  list(
    alpha = 0.05,
    significance_min_base = 30,
    decimal_places_percent = 0,
    decimal_places_ratings = 1,
    decimal_places_index = 1,
    decimal_places_mean = 1,
    decimal_places_numeric = 1,
    apply_weighting = FALSE,
    show_frequency = TRUE,
    show_percent_column = TRUE,
    show_percent_row = FALSE,
    output_format = "excel",
    enable_significance_testing = TRUE,
    show_numeric_median = FALSE,
    show_numeric_mode = FALSE,
    show_numeric_outliers = FALSE,
    outlier_method = "IQR",
    html_report = FALSE,
    bonferroni_correction = FALSE,
    verbose = FALSE
  )
}

# Minimal survey data
make_test_survey_data <- function() {
  set.seed(42)
  n <- 50
  data.frame(
    Q1 = sample(c("Satisfied", "Neutral", "Dissatisfied"), n, replace = TRUE),
    Q2 = sample(c("18-34", "35+"), n, replace = TRUE),
    Q3_1 = sample(c("TV", "Radio", NA), n, replace = TRUE),
    Q3_2 = sample(c("Online", "TV", NA), n, replace = TRUE),
    Q3_3 = sample(c("Radio", NA, NA), n, replace = TRUE),
    Weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}

# Selection data frame
make_test_selection <- function() {
  data.frame(
    QuestionCode = c("Q1", "Q2", "Q3"),
    Include = c("Y", "N", "Y"),
    UseBanner = c("N", "Y", "N"),
    BannerBoxCategory = c("N", "N", "N"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# 1. Structure Validators
# ==============================================================================

context("structure validators — check_duplicate_questions")

test_that("passes with unique question codes", {
  questions <- make_test_questions()
  log <- new_error_log()
  result <- check_duplicate_questions(questions, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("detects duplicate question codes", {
  questions <- make_test_questions()
  questions <- rbind(questions, data.frame(
    QuestionCode = "Q1", QuestionText = "Duplicate",
    Variable_Type = "Single_Response", Columns = "Q1",
    stringsAsFactors = FALSE
  ))
  log <- new_error_log()
  result <- check_duplicate_questions(questions, log)
  expect_true(nrow(result) > nrow(log))
})


context("structure validators — check_variable_types")

test_that("accepts valid variable types", {
  questions <- make_test_questions()
  log <- new_error_log()
  result <- check_variable_types(questions, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("rejects invalid variable type", {
  questions <- make_test_questions()
  questions$Variable_Type[1] <- "Invalid_Type"
  log <- new_error_log()
  result <- check_variable_types(questions, log)
  errors <- result[grepl("Invalid_Type|invalid|unrecognised", result$Description, ignore.case = TRUE), ]
  expect_true(nrow(errors) > 0)
})


context("structure validators — check_missing_options")

test_that("passes when all questions have options", {
  questions <- make_test_questions()
  options <- make_test_options()
  log <- new_error_log()
  result <- check_missing_options(questions, options, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("detects question with no options", {
  questions <- make_test_questions()
  # Add a question with no matching options
  questions <- rbind(questions, data.frame(
    QuestionCode = "Q_ORPHAN", QuestionText = "Orphan",
    Variable_Type = "Single_Response", Columns = "Q_ORPHAN",
    stringsAsFactors = FALSE
  ))
  options <- make_test_options()
  log <- new_error_log()
  result <- check_missing_options(questions, options, log)
  # Should flag Q_ORPHAN as having no options
  expect_true(nrow(result) > nrow(log))
})


context("structure validators — check_orphan_options")

test_that("passes when all options have parent questions", {
  questions <- make_test_questions()
  options <- make_test_options()
  log <- new_error_log()
  result <- check_orphan_options(questions, options, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("detects orphan options", {
  questions <- make_test_questions()
  options <- make_test_options()
  # Add option for non-existent question
  options <- rbind(options, data.frame(
    QuestionCode = "Q_NONEXISTENT", OptionText = "Orphan",
    DisplayText = "Orphan", ShowInOutput = "Y",
    stringsAsFactors = FALSE
  ))
  log <- new_error_log()
  result <- check_orphan_options(questions, options, log)
  expect_true(nrow(result) > nrow(log))
})


# ==============================================================================
# 2. Config Validators
# ==============================================================================

context("config validators — check_alpha_config")

test_that("accepts valid alpha", {
  config <- make_test_config()
  log <- new_error_log()
  result <- check_alpha_config(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("rejects alpha = 0", {
  config <- make_test_config()
  config$alpha <- 0
  log <- new_error_log()
  result <- check_alpha_config(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})

test_that("rejects alpha > 1", {
  config <- make_test_config()
  config$alpha <- 1.5
  log <- new_error_log()
  result <- check_alpha_config(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})

test_that("warns on high alpha", {
  config <- make_test_config()
  config$alpha <- 0.25
  log <- new_error_log()
  result <- check_alpha_config(config, log)
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


context("config validators — check_min_base")

test_that("accepts valid min_base", {
  config <- make_test_config()
  log <- new_error_log()
  result <- check_min_base(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("warns on very small min_base", {
  config <- make_test_config()
  config$significance_min_base <- 5
  log <- new_error_log()
  result <- check_min_base(config, log)
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


context("config validators — check_decimal_places")

test_that("accepts valid decimal places", {
  config <- make_test_config()
  log <- new_error_log()
  result <- check_decimal_places(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("rejects negative decimal places", {
  config <- make_test_config()
  config$decimal_places_percent <- -1
  log <- new_error_log()
  result <- check_decimal_places(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})


context("config validators — check_output_format")

test_that("accepts valid output format", {
  config <- make_test_config()
  log <- new_error_log()
  result <- check_output_format(config, log, verbose = FALSE)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("rejects invalid output format", {
  config <- make_test_config()
  config$output_format <- "pdf"
  log <- new_error_log()
  result <- check_output_format(config, log, verbose = FALSE)
  issues <- result[result$Severity %in% c("Error", "Warning"), ]
  expect_true(nrow(issues) > 0)
})


# ==============================================================================
# 3. Weight Validators
# ==============================================================================

context("weight validators — check_weight_values_valid")

test_that("accepts valid weight values", {
  weights <- c(1.0, 1.5, 0.8, 2.0, 1.2)
  log <- new_error_log()
  result <- check_weight_values_valid(weights, "Weight", log)
  errors <- result$error_log[result$error_log$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("rejects all-NA weights", {
  weights <- c(NA, NA, NA)
  log <- new_error_log()
  result <- check_weight_values_valid(weights, "Weight", log)
  errors <- result$error_log[result$error_log$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})

test_that("rejects negative weights", {
  weights <- c(1.0, -0.5, 1.2)
  log <- new_error_log()
  result <- check_weight_values_valid(weights, "Weight", log)
  errors <- result$error_log[result$error_log$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})

test_that("rejects infinite weights", {
  weights <- c(1.0, Inf, 1.2)
  log <- new_error_log()
  result <- check_weight_values_valid(weights, "Weight", log)
  errors <- result$error_log[result$error_log$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})


context("weight validators — check_weight_distribution")

test_that("passes with reasonable weight distribution", {
  set.seed(42)
  weights <- runif(100, 0.8, 1.2)
  log <- new_error_log()
  config <- make_test_config()
  result <- check_weight_distribution(weights, weights, "Weight", config, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("warns on high weight variability", {
  set.seed(42)
  # Extreme weight variation
  weights <- c(rep(0.01, 90), rep(10.0, 10))
  log <- new_error_log()
  config <- make_test_config()
  result <- check_weight_distribution(weights, weights, "Weight", config, log)
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


# ==============================================================================
# 4. Data Validators
# ==============================================================================

context("data validators — check_bin_structure")

test_that("passes with valid bin structure", {
  options <- data.frame(
    Min = c(18, 25, 35, 50),
    Max = c(24, 34, 49, 65),
    OptionText = c("18-24", "25-34", "35-49", "50-65"),
    stringsAsFactors = FALSE
  )
  log <- new_error_log()
  result <- check_bin_structure("Q_Age", options, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("rejects bins where Min > Max", {
  options <- data.frame(
    Min = c(18, 35),  # Second bin: Min > Max
    Max = c(24, 20),
    OptionText = c("18-24", "35-20"),
    stringsAsFactors = FALSE
  )
  log <- new_error_log()
  result <- check_bin_structure("Q_Age", options, log)
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})


context("data validators — check_bin_overlaps")

test_that("passes with non-overlapping bins", {
  options <- data.frame(
    Min = c(18, 25, 35),
    Max = c(24, 34, 49),
    OptionText = c("18-24", "25-34", "35-49"),
    stringsAsFactors = FALSE
  )
  log <- new_error_log()
  result <- check_bin_overlaps("Q_Age", options, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("detects overlapping bins", {
  options <- data.frame(
    Min = c(18, 20, 35),  # First two bins overlap
    Max = c(24, 34, 49),
    OptionText = c("18-24", "20-34", "35-49"),
    stringsAsFactors = FALSE
  )
  log <- new_error_log()
  result <- check_bin_overlaps("Q_Age", options, log)
  issues <- result[grepl("overlap", result$Description, ignore.case = TRUE), ]
  expect_true(nrow(issues) > 0)
})


# ==============================================================================
# 5. Preflight Validators
# ==============================================================================

context("preflight — check_conflicting_display")

test_that("passes when at least one display metric enabled", {
  config <- make_test_config()
  log <- new_error_log()
  result <- check_conflicting_display(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("warns when all display metrics disabled", {
  config <- make_test_config()
  config$show_frequency <- FALSE
  config$show_percent_column <- FALSE
  config$show_percent_row <- FALSE
  log <- new_error_log()
  result <- check_conflicting_display(config, log)
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


context("preflight — check_duplicate_options")

test_that("passes with unique options per question", {
  options <- make_test_options()
  log <- new_error_log()
  result <- check_duplicate_options(options, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


context("preflight — check_preflight_colour_codes")

test_that("passes with valid hex colours", {
  config <- make_test_config()
  config$html_report <- TRUE
  config$brand_colour <- "#323367"
  config$accent_colour <- "#CC9900"
  log <- new_error_log()
  result <- check_preflight_colour_codes(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("rejects invalid hex colour", {
  config <- make_test_config()
  config$html_report <- TRUE
  config$brand_colour <- "not-a-colour"
  log <- new_error_log()
  result <- check_preflight_colour_codes(config, log)
  issues <- result[grepl("colour|color|hex", result$Description, ignore.case = TRUE), ]
  expect_true(nrow(issues) > 0)
})

test_that("skips colour check when html_report disabled", {
  config <- make_test_config()
  config$html_report <- FALSE
  config$brand_colour <- "not-valid"
  log <- new_error_log()
  result <- check_preflight_colour_codes(config, log)
  # Should not produce colour-related errors
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


context("preflight — check_preflight_dashboard_scales")

test_that("passes with valid dashboard thresholds", {
  config <- make_test_config()
  config$include_summary <- TRUE
  config$dashboard_green_net <- 30
  config$dashboard_amber_net <- 0
  config$dashboard_green_mean <- 7
  config$dashboard_amber_mean <- 5
  config$dashboard_green_index <- 7
  config$dashboard_amber_index <- 5
  config$dashboard_green_custom <- 60
  config$dashboard_amber_custom <- 40
  log <- new_error_log()
  result <- check_preflight_dashboard_scales(config, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("warns on inverted thresholds", {
  config <- make_test_config()
  config$include_summary <- TRUE
  config$dashboard_green_net <- 0
  config$dashboard_amber_net <- 30  # Inverted: amber > green
  log <- new_error_log()
  result <- check_preflight_dashboard_scales(config, log)
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


context("preflight — check_selection_vs_questions")

test_that("passes when selected questions exist in structure", {
  selection <- make_test_selection()
  questions <- make_test_questions()
  log <- new_error_log()
  result <- check_selection_vs_questions(selection, questions, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("detects selected question not in structure", {
  selection <- make_test_selection()
  selection <- rbind(selection, data.frame(
    QuestionCode = "Q_MISSING", Include = "Y",
    UseBanner = "N", BannerBoxCategory = "N",
    DisplayOrder = 4, stringsAsFactors = FALSE
  ))
  questions <- make_test_questions()
  log <- new_error_log()
  result <- check_selection_vs_questions(selection, questions, log)
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})


context("preflight — check_data_column_coverage")

test_that("passes when data columns exist for selected questions", {
  selection <- make_test_selection()
  questions <- make_test_questions()
  data <- make_test_survey_data()
  log <- new_error_log()
  result <- check_data_column_coverage(selection, questions, data, log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("detects missing data column", {
  selection <- data.frame(
    QuestionCode = "Q_MISSING",
    Include = "Y", UseBanner = "N",
    BannerBoxCategory = "N", DisplayOrder = 1,
    stringsAsFactors = FALSE
  )
  questions <- data.frame(
    QuestionCode = "Q_MISSING", QuestionText = "Missing",
    Variable_Type = "Single_Response", Columns = "Q_MISSING",
    stringsAsFactors = FALSE
  )
  data <- make_test_survey_data()
  log <- new_error_log()
  result <- check_data_column_coverage(selection, questions, data, log)
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
})


# ==============================================================================
# 6. Orchestrator — run_all_validations
# ==============================================================================

context("run_all_validations — orchestrator")

test_that("runs full validation pipeline without errors on valid data", {
  config <- make_test_config()
  questions <- make_test_questions()
  options <- make_test_options()
  data <- make_test_survey_data()
  selection <- make_test_selection()

  survey_structure <- list(
    questions = questions,
    options = options,
    project = data.frame(
      Setting = "project_name",
      Value = "Test",
      stringsAsFactors = FALSE
    )
  )

  result <- run_all_validations(survey_structure, data, config, verbose = FALSE, selection_df = selection)

  expect_true(is.data.frame(result))
  errors <- result[result$Severity == "Error", ]
  # Valid data should produce zero errors
  expect_equal(nrow(errors), 0)
})

test_that("catches config errors in orchestrator", {
  config <- make_test_config()
  config$alpha <- -1  # Invalid

  questions <- make_test_questions()
  options <- make_test_options()
  data <- make_test_survey_data()

  survey_structure <- list(
    questions = questions,
    options = options,
    project = data.frame(
      Setting = "project_name",
      Value = "Test",
      stringsAsFactors = FALSE
    )
  )

  # Invalid alpha causes validation errors logged and then a TRS refusal if errors > 0
  # The orchestrator refuses when it finds validation errors
  expect_error(
    run_all_validations(survey_structure, data, config, verbose = FALSE),
    class = "turas_refusal"
  )
})

test_that("returns data frame even with no issues", {
  config <- make_test_config()
  questions <- make_test_questions()
  options <- make_test_options()
  data <- make_test_survey_data()

  survey_structure <- list(
    questions = questions,
    options = options,
    project = data.frame(
      Setting = "project_name",
      Value = "Test",
      stringsAsFactors = FALSE
    )
  )

  result <- run_all_validations(survey_structure, data, config, verbose = FALSE)

  expect_true(is.data.frame(result))
  expect_true("Severity" %in% names(result))
  expect_true("Description" %in% names(result))
})
