# ==============================================================================
# TESTS: Preflight Validators (preflight_validators.R)
# ==============================================================================
# Tests for the cross-referential checks that validate config vs structure vs
# data before crosstab analysis begins.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_preflight_validators.R")
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

# Set .tabs_lib_dir (required by tabs_source() for subdirectory loading)
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())

# Define create_error_log
create_error_log <- function() {
  data.frame(
    Timestamp = character(), Component = character(),
    Issue_Type = character(), Description = character(),
    QuestionCode = character(), Severity = character(),
    stringsAsFactors = FALSE
  )
}
assign("create_error_log", create_error_log, envir = globalenv())

# Source log_issue
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))

# Source preflight validators directly
preflight_path <- file.path(turas_root, "modules/tabs/lib/validation/preflight_validators.R")
if (file.exists(preflight_path)) {
  source(preflight_path)
} else {
  stop("Cannot find preflight_validators.R at: ", preflight_path)
}


# ==============================================================================
# HELPERS
# ==============================================================================

new_error_log <- function() {
  create_error_log()
}

make_selection_df <- function(codes = c("Q1", "Q2"), include = "Y",
                               use_banner = "N", create_index = "N") {
  data.frame(
    QuestionCode = codes,
    Include = rep(include, length(codes)),
    UseBanner = rep(use_banner, length(codes)),
    CreateIndex = rep(create_index, length(codes)),
    stringsAsFactors = FALSE
  )
}

make_questions_df <- function(codes = c("Q1", "Q2"),
                               types = c("Single", "Multi_Mention"),
                               columns = c(1, 3)) {
  data.frame(
    QuestionCode = codes,
    Variable_Type = types,
    Columns = columns,
    stringsAsFactors = FALSE
  )
}

make_options_df <- function(codes = c("Q1", "Q1"), opt_codes = c("1", "2"),
                             opt_labels = c("Yes", "No")) {
  data.frame(
    QuestionCode = codes,
    OptionCode = opt_codes,
    OptionLabel = opt_labels,
    stringsAsFactors = FALSE
  )
}

make_survey_data <- function(n = 50) {
  data.frame(
    Q1 = sample(c("1", "2"), n, replace = TRUE),
    Q2_1 = sample(0:1, n, replace = TRUE),
    Q2_2 = sample(0:1, n, replace = TRUE),
    Q2_3 = sample(0:1, n, replace = TRUE),
    Weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# TESTS
# ==============================================================================

# --- 1. check_selection_vs_questions ---

test_that("check_selection_vs_questions detects missing questions in structure", {
  skip_if(!exists("check_selection_vs_questions", mode = "function"),
          "check_selection_vs_questions not available")

  selection_df <- make_selection_df(codes = c("Q1", "Q2", "Q99"))
  questions_df <- make_questions_df(codes = c("Q1", "Q2"))

  result <- check_selection_vs_questions(selection_df, questions_df, new_error_log())

  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Q99", errors$Description)))
})

test_that("check_selection_vs_questions warns about unselected questions", {
  skip_if(!exists("check_selection_vs_questions", mode = "function"),
          "check_selection_vs_questions not available")

  selection_df <- make_selection_df(codes = c("Q1"))
  questions_df <- make_questions_df(codes = c("Q1", "Q2"))

  result <- check_selection_vs_questions(selection_df, questions_df, new_error_log())

  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
  expect_true(any(grepl("Q2", warnings$Description)))
})

test_that("check_selection_vs_questions passes with matching sets", {
  skip_if(!exists("check_selection_vs_questions", mode = "function"),
          "check_selection_vs_questions not available")

  codes <- c("Q1", "Q2")
  selection_df <- make_selection_df(codes = codes)
  questions_df <- make_questions_df(codes = codes)

  result <- check_selection_vs_questions(selection_df, questions_df, new_error_log())

  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 2. check_option_values_vs_data ---

test_that("check_option_values_vs_data warns about undefined data values", {
  skip_if(!exists("check_option_values_vs_data", mode = "function"),
          "check_option_values_vs_data not available")

  questions_df <- make_questions_df(codes = "Q1", types = "Single", columns = 1)
  options_df <- make_options_df(codes = c("Q1", "Q1"), opt_codes = c("1", "2"))
  selection_df <- make_selection_df(codes = "Q1")
  survey_data <- data.frame(Q1 = c("1", "2", "3"), stringsAsFactors = FALSE)

  result <- check_option_values_vs_data(
    questions_df, options_df, survey_data, selection_df, new_error_log()
  )
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("3", result$Description)))
})


# --- 3. check_preflight_multi_mention ---

test_that("check_preflight_multi_mention detects missing binary columns", {
  skip_if(!exists("check_preflight_multi_mention", mode = "function"),
          "check_preflight_multi_mention not available")

  questions_df <- make_questions_df(codes = "Q5", types = "Multi_Mention", columns = 4)
  selection_df <- make_selection_df(codes = "Q5")
  # Only Q5_1 and Q5_2 exist, missing Q5_3 and Q5_4
  survey_data <- data.frame(Q5_1 = c(0, 1), Q5_2 = c(1, 0), stringsAsFactors = FALSE)

  result <- check_preflight_multi_mention(
    questions_df, survey_data, selection_df, new_error_log()
  )
  expect_true(nrow(result) > 0)
})

test_that("check_preflight_multi_mention passes with all columns present", {
  skip_if(!exists("check_preflight_multi_mention", mode = "function"),
          "check_preflight_multi_mention not available")

  questions_df <- make_questions_df(codes = "Q2", types = "Multi_Mention", columns = 3)
  selection_df <- make_selection_df(codes = "Q2")
  survey_data <- data.frame(Q2_1 = c(0, 1), Q2_2 = c(1, 0), Q2_3 = c(1, 1),
                            stringsAsFactors = FALSE)

  result <- check_preflight_multi_mention(
    questions_df, survey_data, selection_df, new_error_log()
  )
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 4. check_conflicting_display ---

test_that("check_conflicting_display warns when all metrics disabled", {
  skip_if(!exists("check_conflicting_display", mode = "function"),
          "check_conflicting_display not available")

  config <- list(
    show_frequency = FALSE,
    show_percent_column = FALSE,
    show_percent_row = FALSE
  )
  result <- check_conflicting_display(config, new_error_log())
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("No Display Metrics", result$Issue_Type)))
})

test_that("check_conflicting_display warns about significance without percentages", {
  skip_if(!exists("check_conflicting_display", mode = "function"),
          "check_conflicting_display not available")

  config <- list(
    show_frequency = TRUE,
    show_percent_column = FALSE,
    show_percent_row = FALSE,
    enable_significance_testing = TRUE
  )
  result <- check_conflicting_display(config, new_error_log())
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("Significance", result$Issue_Type)))
})


# --- 5. check_preflight_weight_variable ---

test_that("check_preflight_weight_variable detects missing weight column", {
  skip_if(!exists("check_preflight_weight_variable", mode = "function"),
          "check_preflight_weight_variable not available")

  config <- list(apply_weighting = TRUE, weight_variable = "NonExistent")
  survey_data <- data.frame(Q1 = 1:5, stringsAsFactors = FALSE)

  result <- check_preflight_weight_variable(config, survey_data, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("NonExistent", errors$Description)))
})

test_that("check_preflight_weight_variable detects negative weights", {
  skip_if(!exists("check_preflight_weight_variable", mode = "function"),
          "check_preflight_weight_variable not available")

  config <- list(apply_weighting = TRUE, weight_variable = "wt")
  survey_data <- data.frame(Q1 = 1:5, wt = c(1.0, 0.5, -0.3, 2.0, 1.0),
                            stringsAsFactors = FALSE)

  result <- check_preflight_weight_variable(config, survey_data, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("negative", errors$Description, ignore.case = TRUE)))
})

test_that("check_preflight_weight_variable skips when weighting disabled", {
  skip_if(!exists("check_preflight_weight_variable", mode = "function"),
          "check_preflight_weight_variable not available")

  config <- list(apply_weighting = FALSE, weight_variable = "wt")
  survey_data <- data.frame(Q1 = 1:5, stringsAsFactors = FALSE)

  result <- check_preflight_weight_variable(config, survey_data, new_error_log())
  expect_equal(nrow(result), 0)
})


# --- 6. check_duplicate_options ---

test_that("check_duplicate_options detects duplicate OptionCodes", {
  skip_if(!exists("check_duplicate_options", mode = "function"),
          "check_duplicate_options not available")

  options_df <- data.frame(
    QuestionCode = c("Q1", "Q1", "Q1"),
    OptionCode = c("1", "2", "1"),
    OptionLabel = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  result <- check_duplicate_options(options_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Duplicate", errors$Issue_Type)))
})


# --- 7. check_open_end_selection ---

test_that("check_open_end_selection warns about Open_End questions", {
  skip_if(!exists("check_open_end_selection", mode = "function"),
          "check_open_end_selection not available")

  selection_df <- make_selection_df(codes = c("Q1", "QOpen"))
  questions_df <- data.frame(
    QuestionCode = c("Q1", "QOpen"),
    Variable_Type = c("Single", "Open_End"),
    Columns = c(1, 1),
    stringsAsFactors = FALSE
  )

  result <- check_open_end_selection(selection_df, questions_df, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
  expect_true(any(grepl("Open_End", warnings$Issue_Type)))
})


# --- 8. check_data_column_coverage ---

test_that("check_data_column_coverage detects missing data columns", {
  skip_if(!exists("check_data_column_coverage", mode = "function"),
          "check_data_column_coverage not available")

  selection_df <- make_selection_df(codes = c("Q1", "Q_missing"))
  questions_df <- data.frame(
    QuestionCode = c("Q1", "Q_missing"),
    Variable_Type = c("Single", "Single"),
    Columns = c(1, 1),
    stringsAsFactors = FALSE
  )
  survey_data <- data.frame(Q1 = 1:5, stringsAsFactors = FALSE)

  result <- check_data_column_coverage(
    selection_df, questions_df, survey_data, new_error_log()
  )
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Q_missing", errors$Description)))
})


# --- 9. validate_preflight orchestrator ---

test_that("validate_preflight runs without error on valid inputs", {
  skip_if(!exists("validate_preflight", mode = "function"),
          "validate_preflight not available")

  questions_df <- make_questions_df(codes = c("Q1"), types = c("Single"), columns = 1)
  options_df <- make_options_df(codes = c("Q1", "Q1"), opt_codes = c("1", "2"))
  selection_df <- make_selection_df(codes = "Q1")
  survey_data <- data.frame(Q1 = c("1", "2", "1"), stringsAsFactors = FALSE)

  config <- list(
    show_frequency = TRUE,
    show_percent_column = TRUE,
    show_percent_row = FALSE,
    apply_weighting = FALSE
  )
  survey_structure <- list(questions = questions_df, options = options_df)

  result <- validate_preflight(
    survey_structure, survey_data, config,
    selection_df = selection_df, error_log = new_error_log(), verbose = FALSE
  )
  expect_true(is.data.frame(result))
})

test_that("validate_preflight detects issues with invalid config", {
  skip_if(!exists("validate_preflight", mode = "function"),
          "validate_preflight not available")

  questions_df <- make_questions_df(codes = c("Q1"), types = c("Single"), columns = 1)
  options_df <- make_options_df(codes = c("Q1", "Q1"), opt_codes = c("1", "2"))
  selection_df <- make_selection_df(codes = c("Q1", "Q_BAD"))
  survey_data <- data.frame(Q1 = c("1", "2", "1"), stringsAsFactors = FALSE)

  config <- list(
    show_frequency = FALSE,
    show_percent_column = FALSE,
    show_percent_row = FALSE,
    apply_weighting = TRUE,
    weight_variable = "missing_weight"
  )
  survey_structure <- list(questions = questions_df, options = options_df)

  result <- validate_preflight(
    survey_structure, survey_data, config,
    selection_df = selection_df, error_log = new_error_log(), verbose = FALSE
  )
  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
})


# --- 10. check_preflight_colour_codes ---

test_that("check_preflight_colour_codes detects invalid hex colour", {
  skip_if(!exists("check_preflight_colour_codes", mode = "function"),
          "check_preflight_colour_codes not available")

  config <- list(html_report = TRUE, brand_colour = "not-hex", accent_colour = "#323367")
  result <- check_preflight_colour_codes(config, new_error_log())
  expect_true(nrow(result) > 0)
})

test_that("check_preflight_colour_codes skips when html_report is FALSE", {
  skip_if(!exists("check_preflight_colour_codes", mode = "function"),
          "check_preflight_colour_codes not available")

  config <- list(html_report = FALSE, brand_colour = "not-hex")
  result <- check_preflight_colour_codes(config, new_error_log())
  expect_equal(nrow(result), 0)
})
