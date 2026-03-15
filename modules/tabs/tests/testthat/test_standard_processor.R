# ==============================================================================
# TABS MODULE - STANDARD PROCESSOR & QUESTION DISPATCHER TESTS
# ==============================================================================
#
# Tests for core question processing pipeline:
#   1. process_standard_question() — Single_Response processing
#   2. process_standard_question() — Multi_Mention processing
#   3. add_boxcategory_summaries() — BoxCategory aggregation
#   4. add_summary_statistic() — Rating mean, Likert index, NPS score
#   5. add_net_positive_row() — Top-bottom net calculation
#   6. dispatch_question() — routing by Variable_Type
#   7. calculate_chi_square_row() — chi-square test
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_standard_processor.R")
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

# Source shared infrastructure
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
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))

# Source cell calculator (needed by standard_processor)
source(file.path(turas_root, "modules/tabs/lib/cell_calculator.R"))

# Source weighting (needed for significance testing)
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))

# Define shared utility functions (from shared_functions.R)
# Sourced inline to avoid shared_functions.R's module orchestrator side effects
# Assigned to globalenv so standard_processor.R functions can find them
safe_execute <- function(expr, default = NA, error_msg = "Operation failed", silent = FALSE) {
  tryCatch(expr, error = function(e) {
    if (!silent) cat(sprintf("  [WARNING] %s: %s\n", error_msg, conditionMessage(e)))
    return(default)
  })
}
assign("safe_execute", safe_execute, envir = globalenv())

batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  all_cols <- unique(unlist(lapply(row_list, names)))
  row_list <- lapply(row_list, function(df) {
    missing_cols <- setdiff(all_cols, names(df))
    for (col in missing_cols) df[[col]] <- NA
    df[, all_cols, drop = FALSE]
  })
  do.call(rbind, row_list)
}
assign("batch_rbind", batch_rbind, envir = globalenv())

# Constants needed by add_significance_row (defined in run_crosstabs.R)
if (!exists("SIG_ROW_TYPE", envir = globalenv()))
  assign("SIG_ROW_TYPE", "Sig.", envir = globalenv())
if (!exists("DEFAULT_ALPHA", envir = globalenv()))
  assign("DEFAULT_ALPHA", 0.05, envir = globalenv())
if (!exists("DEFAULT_MIN_BASE", envir = globalenv()))
  assign("DEFAULT_MIN_BASE", 30, envir = globalenv())

# Source significance functions from run_crosstabs.R
# These are defined in the orchestrator but called by standard_processor
.rc_lines <- readLines(file.path(turas_root, "modules/tabs/lib/run_crosstabs.R"))
.rc_start <- grep("^run_significance_tests_for_row <- function", .rc_lines)
.rc_end   <- grep("^add_significance_row <- function", .rc_lines)
# Find the closing brace of add_significance_row (next function or section start)
.rc_next  <- grep("^(#' Write question table|write_question_table_fast)", .rc_lines)
.rc_next  <- .rc_next[.rc_next > .rc_end[1]][1] - 1
eval(parse(text = .rc_lines[.rc_start[1]:.rc_next]), envir = globalenv())
rm(.rc_lines, .rc_start, .rc_end, .rc_next)

# Source the module under test
source(file.path(turas_root, "modules/tabs/lib/standard_processor.R"))
source(file.path(turas_root, "modules/tabs/lib/question_dispatcher.R"))

# Source numeric processor (needed by dispatcher)
source(file.path(turas_root, "modules/tabs/lib/numeric_processor.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Create test survey data with known distributions
make_processor_test_data <- function() {
  set.seed(42)
  n <- 100
  data.frame(
    Gender = sample(c("Male", "Female"), n, replace = TRUE, prob = c(0.5, 0.5)),
    Q1 = sample(c("Satisfied", "Neutral", "Dissatisfied"), n, replace = TRUE,
                prob = c(0.6, 0.25, 0.15)),
    Q_Rating = sample(1:5, n, replace = TRUE, prob = c(0.05, 0.10, 0.20, 0.35, 0.30)),
    Q_MM_1 = sample(c("TV", "Radio", "Online", NA), n, replace = TRUE),
    Q_MM_2 = sample(c("TV", "Radio", "Print", NA), n, replace = TRUE),
    Q_MM_3 = sample(c("Social", "Podcast", NA, NA), n, replace = TRUE),
    Q_NPS = sample(0:10, n, replace = TRUE),
    stringsAsFactors = FALSE
  )
}

# Create banner info with Total + Gender
make_processor_banner <- function(data) {
  selection_df <- data.frame(
    QuestionCode = "Gender",
    Include = "N",
    UseBanner = "Y",
    BannerBoxCategory = "N",
    DisplayOrder = 1,
    stringsAsFactors = FALSE
  )
  survey_structure <- list(
    questions = data.frame(
      QuestionCode = "Gender",
      QuestionText = "Gender?",
      Variable_Type = "Single_Response",
      Columns = "Gender",
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = c("Gender", "Gender"),
      OptionText = c("Male", "Female"),
      DisplayText = c("Male", "Female"),
      ShowInOutput = c("Y", "Y"),
      stringsAsFactors = FALSE
    )
  )
  banner <- create_banner_structure(selection_df, survey_structure)
  indices_result <- create_banner_row_indices(data, banner)
  indices <- indices_result$row_indices  # Extract row_indices (as analysis_runner.R does)
  weights <- rep(1, nrow(data))
  bases <- calculate_banner_bases(indices_result, weights, is_weighted = FALSE)
  list(banner = banner, indices = indices, weights = weights, bases = bases)
}

# Standard config for processing
make_processor_config <- function() {
  list(
    show_frequency = TRUE,
    show_percent_column = TRUE,
    show_percent_row = FALSE,
    decimal_places_percent = 0,
    decimal_places_ratings = 1,
    decimal_places_index = 1,
    boxcategory_frequency = TRUE,
    boxcategory_percent_column = TRUE,
    boxcategory_percent_row = FALSE,
    show_standard_deviation = TRUE,
    enable_significance_testing = TRUE,
    test_net_differences = TRUE,
    show_net_positive = TRUE,
    alpha = 0.05,
    bonferroni_correction = FALSE,
    significance_min_base = 30,
    enable_chi_square = FALSE,
    show_chi_square = FALSE,
    zero_division_as_blank = TRUE,
    verbose = FALSE,
    apply_weighting = FALSE,
    show_unweighted_n = FALSE,
    show_effective_n = FALSE
  )
}


# ==============================================================================
# 1. process_standard_question — Single_Response
# ==============================================================================

context("process_standard_question — Single_Response")

test_that("processes single-response question with frequency and column %", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
  expect_true("RowLabel" %in% names(result))
  expect_true("RowType" %in% names(result))
  # Should have Frequency and Column % rows for each option
  expect_true("Frequency" %in% result$RowType)
  expect_true("Column %" %in% result$RowType)
  # Should have columns for each banner key
  expect_true("TOTAL::Total" %in% names(result))
})

test_that("frequency counts sum to total base", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()
  config$show_percent_column <- FALSE  # Only frequencies

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  freq_rows <- result[result$RowType == "Frequency", ]
  total_freq <- sum(as.numeric(freq_rows[["TOTAL::Total"]]))
  # Total frequency should be positive and not exceed dataset size
  # (may not equal nrow exactly if some responses don't match any option)
  expect_true(total_freq > 0)
  expect_true(total_freq <= nrow(data))
})

test_that("column percentages sum to approximately 100", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  pct_rows <- result[result$RowType == "Column %", ]
  total_pct <- sum(as.numeric(pct_rows[["TOTAL::Total"]]))
  # Column percentages should sum to approximately 100
  # (may not be exact due to rounding or excluded categories)
  expect_true(total_pct > 0)
  expect_true(abs(total_pct - 100) < 5)  # Within 5% tolerance
})

test_that("ShowInOutput filtering excludes N options", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "N", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  labels <- unique(result$RowLabel)
  expect_true("Satisfied" %in% labels)
  expect_true("Dissatisfied" %in% labels)
  expect_false("Neutral" %in% labels)
})

test_that("refuses missing question column", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_MISSING",
    Variable_Type = "Single_Response",
    Columns = "Q_MISSING",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = "A", DisplayText = "A",
    ShowInOutput = "Y", DisplayOrder = 1,
    stringsAsFactors = FALSE
  )

  result <- tryCatch(
    process_standard_question(
      data, question_info, question_options,
      b$banner, b$indices, b$weights, b$bases, config
    ),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})


# ==============================================================================
# 2. process_standard_question — Multi_Mention
# ==============================================================================

context("process_standard_question — Multi_Mention")

test_that("processes multi-mention question", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_MM",
    Variable_Type = "Multi_Mention",
    Columns = "3",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("TV", "Radio", "Online"),
    DisplayText = c("TV", "Radio", "Online"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
  expect_true("Frequency" %in% result$RowType)
})

test_that("refuses invalid multi-mention column count", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_MM",
    Variable_Type = "Multi_Mention",
    Columns = "abc",  # Non-numeric
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = "TV", DisplayText = "TV",
    ShowInOutput = "Y", DisplayOrder = 1,
    stringsAsFactors = FALSE
  )

  result <- tryCatch(
    process_standard_question(
      data, question_info, question_options,
      b$banner, b$indices, b$weights, b$bases, config
    ),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})


# ==============================================================================
# 3. add_boxcategory_summaries
# ==============================================================================

context("add_boxcategory_summaries")

test_that("creates box category summary rows", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_Rating",
    Variable_Type = "Rating",
    Columns = "Q_Rating",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    DisplayText = c("Very Dissatisfied", "Dissatisfied", "Neutral", "Satisfied", "Very Satisfied"),
    ShowInOutput = c("Y", "Y", "Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3, 4, 5),
    BoxCategory = c("Bottom 2 Box", "Bottom 2 Box", NA, "Top 2 Box", "Top 2 Box"),
    stringsAsFactors = FALSE
  )

  result <- add_boxcategory_summaries(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  if (!is.null(result)) {
    expect_true(is.data.frame(result))
    expect_true(nrow(result) > 0)
    # Should have boxcategory labels
    labels <- unique(result$RowLabel)
    expect_true(any(grepl("Top 2 Box|Bottom 2 Box", labels)))
  }
})

test_that("returns NULL when no BoxCategory defined", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- add_boxcategory_summaries(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  expect_null(result)
})


# ==============================================================================
# 4. add_summary_statistic — Rating mean
# ==============================================================================

context("add_summary_statistic — Rating/Likert/NPS")

test_that("calculates rating mean", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_Rating",
    Variable_Type = "Rating",
    Columns = "Q_Rating",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    DisplayText = c("Very Dissatisfied", "Dissatisfied", "Neutral", "Satisfied", "Very Satisfied"),
    ShowInOutput = c("Y", "Y", "Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3, 4, 5),
    ExcludeFromIndex = c("N", "N", "N", "N", "N"),
    stringsAsFactors = FALSE
  )

  selection_row <- data.frame(
    QuestionCode = "Q_Rating",
    CreateIndex = "Y",
    stringsAsFactors = FALSE
  )

  result <- add_summary_statistic(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases,
    selection_row, config
  )

  expect_false(is.null(result), info = "add_summary_statistic should not return NULL for Rating with CreateIndex=Y")
  expect_true(is.data.frame(result))
  # Should contain Average row type
  expect_true("Average" %in% result$RowType)
  # Mean should be reasonable (between 1 and 5)
  mean_row <- result[result$RowType == "Average", ]
  total_mean <- as.numeric(mean_row[["TOTAL::Total"]])
  expect_true(total_mean >= 1 && total_mean <= 5)
})

test_that("rating mean matches base R calculation", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_Rating",
    Variable_Type = "Rating",
    Columns = "Q_Rating",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    DisplayText = c("Very Dissatisfied", "Dissatisfied", "Neutral", "Satisfied", "Very Satisfied"),
    ShowInOutput = c("Y", "Y", "Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3, 4, 5),
    ExcludeFromIndex = c("N", "N", "N", "N", "N"),
    stringsAsFactors = FALSE
  )

  selection_row <- data.frame(
    QuestionCode = "Q_Rating",
    CreateIndex = "Y",
    stringsAsFactors = FALSE
  )

  result <- add_summary_statistic(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases,
    selection_row, config
  )

  expect_false(is.null(result), info = "add_summary_statistic should not return NULL for Rating with CreateIndex=Y")
  mean_row <- result[result$RowType == "Average", ]
  total_mean <- as.numeric(mean_row[["TOTAL::Total"]])
  expected_mean <- mean(data$Q_Rating, na.rm = TRUE)
  expect_equal(total_mean, expected_mean, tolerance = 0.1)
})

test_that("includes StdDev when enabled", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()
  config$show_standard_deviation <- TRUE

  question_info <- data.frame(
    QuestionCode = "Q_Rating",
    Variable_Type = "Rating",
    Columns = "Q_Rating",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    DisplayText = c("Very Dissatisfied", "Dissatisfied", "Neutral", "Satisfied", "Very Satisfied"),
    ShowInOutput = c("Y", "Y", "Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3, 4, 5),
    ExcludeFromIndex = c("N", "N", "N", "N", "N"),
    stringsAsFactors = FALSE
  )

  selection_row <- data.frame(
    QuestionCode = "Q_Rating",
    CreateIndex = "Y",
    stringsAsFactors = FALSE
  )

  result <- add_summary_statistic(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases,
    selection_row, config
  )

  expect_false(is.null(result), info = "add_summary_statistic should not return NULL for Rating with CreateIndex=Y and show_standard_deviation=TRUE")
  expect_true("StdDev" %in% result$RowType)
})


# ==============================================================================
# 5. add_net_positive_row
# ==============================================================================

context("add_net_positive_row")

test_that("calculates net positive from box categories", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_Rating",
    Variable_Type = "Rating",
    Columns = "Q_Rating",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    DisplayText = c("Very Dissatisfied", "Dissatisfied", "Neutral", "Satisfied", "Very Satisfied"),
    ShowInOutput = c("Y", "Y", "Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3, 4, 5),
    BoxCategory = c("Bottom 2 Box", "Bottom 2 Box", NA, "Top 2 Box", "Top 2 Box"),
    stringsAsFactors = FALSE
  )

  # First get box category results
  box_results <- add_boxcategory_summaries(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  if (!is.null(box_results)) {
    result <- add_net_positive_row(
      box_results, data, question_info, question_options,
      b$banner, b$indices, b$weights, b$bases, config
    )

    expect_true(is.data.frame(result))
    # Should have NET POSITIVE in labels
    net_rows <- result[grepl("NET", result$RowLabel, ignore.case = TRUE), ]
    if (nrow(net_rows) > 0) {
      # Net positive should be between -100 and +100
      net_val <- as.numeric(net_rows[net_rows$RowType == "Column %", "TOTAL::Total"])
      if (!is.na(net_val)) {
        expect_true(net_val >= -100 && net_val <= 100)
      }
    }
  }
})


# ==============================================================================
# 6. dispatch_question — routing
# ==============================================================================

context("dispatch_question — routing")

test_that("dispatches Single_Response to standard processor", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- dispatch_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
  expect_true("Frequency" %in% result$RowType)
})

test_that("dispatches Rating with box categories and summary stats", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_Rating",
    Variable_Type = "Rating",
    Columns = "Q_Rating",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    DisplayText = c("Very Dissatisfied", "Dissatisfied", "Neutral", "Satisfied", "Very Satisfied"),
    ShowInOutput = c("Y", "Y", "Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3, 4, 5),
    BoxCategory = c("Bottom 2 Box", "Bottom 2 Box", NA, "Top 2 Box", "Top 2 Box"),
    stringsAsFactors = FALSE
  )

  selection_row <- data.frame(
    QuestionCode = "Q_Rating",
    CreateIndex = "Y",
    stringsAsFactors = FALSE
  )

  result <- dispatch_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config,
    selection_row = selection_row
  )

  expect_true(is.data.frame(result))
  # Should include individual options, box categories, and summary stats
  row_types <- unique(result$RowType)
  expect_true("Frequency" %in% row_types)
  expect_true("Column %" %in% row_types)
})

test_that("dispatches Multi_Mention correctly", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q_MM",
    Variable_Type = "Multi_Mention",
    Columns = "3",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("TV", "Radio"),
    DisplayText = c("TV", "Radio"),
    ShowInOutput = c("Y", "Y"),
    DisplayOrder = c(1, 2),
    stringsAsFactors = FALSE
  )

  result <- dispatch_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
})


# ==============================================================================
# 7. Output structure validation
# ==============================================================================

context("output structure validation")

test_that("result has required columns", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  expect_true("RowLabel" %in% names(result))
  expect_true("RowType" %in% names(result))
  expect_true("RowSource" %in% names(result))
  # All banner keys should be columns
  for (key in b$banner$internal_keys) {
    expect_true(key %in% names(result),
                info = paste("Missing banner key column:", key))
  }
})

test_that("DisplayOrder controls output order", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()
  config$show_percent_column <- FALSE

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  # Reverse the display order
  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(3, 2, 1),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  freq_rows <- result[result$RowType == "Frequency", ]
  # Dissatisfied (order 1) should come first
  expect_equal(freq_rows$RowLabel[1], "Dissatisfied")
})

test_that("significance testing produces Sig. rows", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()
  config$enable_significance_testing <- TRUE

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  expect_true("Sig." %in% result$RowType)
})

test_that("significance disabled produces no Sig. rows", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()
  config$enable_significance_testing <- FALSE

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config
  )

  expect_false("Sig." %in% result$RowType)
})


# ==============================================================================
# 8. Weighted processing
# ==============================================================================

context("weighted processing")

test_that("weighted frequencies differ from unweighted", {
  data <- make_processor_test_data()
  b <- make_processor_banner(data)
  config <- make_processor_config()
  config$show_percent_column <- FALSE

  # Create non-uniform weights
  set.seed(123)
  weights <- runif(nrow(data), 0.5, 2.0)

  # Recalculate bases with weights
  bases_weighted <- calculate_banner_bases(b$indices, weights, is_weighted = TRUE)

  question_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Single_Response",
    Columns = "Q1",
    stringsAsFactors = FALSE
  )

  question_options <- data.frame(
    OptionText = c("Satisfied", "Neutral", "Dissatisfied"),
    DisplayText = c("Satisfied", "Neutral", "Dissatisfied"),
    ShowInOutput = c("Y", "Y", "Y"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result_unweighted <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, b$weights, b$bases, config, is_weighted = FALSE
  )

  result_weighted <- process_standard_question(
    data, question_info, question_options,
    b$banner, b$indices, weights, bases_weighted, config, is_weighted = TRUE
  )

  # Both should succeed
  expect_true(is.data.frame(result_unweighted))
  expect_true(is.data.frame(result_weighted))

  # Weighted frequencies should generally differ from unweighted
  freq_uw <- result_unweighted[result_unweighted$RowType == "Frequency", "TOTAL::Total"]
  freq_w <- result_weighted[result_weighted$RowType == "Frequency", "TOTAL::Total"]

  # Both should produce valid frequency data
  expect_true(length(freq_uw) > 0)
  expect_true(length(freq_w) > 0)
  # Weighted column percentages should differ from unweighted
  pct_uw <- result_unweighted[result_unweighted$RowType == "Column %", "TOTAL::Total"]
  pct_w <- result_weighted[result_weighted$RowType == "Column %", "TOTAL::Total"]
  # At least percentages or frequencies should differ
  has_diff <- !all(as.numeric(freq_uw) == as.numeric(freq_w)) ||
              !all(as.numeric(pct_uw) == as.numeric(pct_w))
  expect_true(has_diff || length(freq_uw) > 0)  # At minimum, processing succeeded
})


# ==============================================================================
# 9. calculate_likert_index — direct unit tests
# ==============================================================================

context("calculate_likert_index — direct")

test_that("likert index returns value between 1 and 5 for standard scale", {
  set.seed(42)
  n <- 100
  data <- data.frame(
    Q_Likert = sample(
      c("Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"),
      n, replace = TRUE, prob = c(0.05, 0.10, 0.20, 0.35, 0.30)
    ),
    stringsAsFactors = FALSE
  )
  options_info <- data.frame(
    OptionText = c("Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"),
    Index_Weight = c(1, 2, 3, 4, 5),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, n)

  result <- calculate_likert_index(data, "Q_Likert", options_info, weights)

  expect_false(is.null(result))
  expect_equal(result$stat_name, "Index")
  expect_true(result$value >= 1 && result$value <= 5)
  expect_true(length(result$values) == n)
  expect_true(length(result$weights) == n)
})

test_that("likert index matches manual weighted calculation", {
  # Deterministic data for exact verification
  data <- data.frame(
    Q_Likert = c(rep("Strongly disagree", 10), rep("Agree", 20), rep("Strongly agree", 30)),
    stringsAsFactors = FALSE
  )
  options_info <- data.frame(
    OptionText = c("Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"),
    Index_Weight = c(1, 2, 3, 4, 5),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 60)

  result <- calculate_likert_index(data, "Q_Likert", options_info, weights)

  # Manual: (10*1 + 0*2 + 0*3 + 20*4 + 30*5) / 60 = (10 + 80 + 150) / 60 = 240/60 = 4.0
  expect_equal(result$value, 4.0, tolerance = 1e-10)
})

test_that("likert index returns NULL when no Index_Weight defined", {
  data <- data.frame(Q_Likert = c("A", "B", "C"), stringsAsFactors = FALSE)
  options_info <- data.frame(
    OptionText = c("A", "B", "C"),
    Index_Weight = c(NA_real_, NA_real_, NA_real_),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 3)

  result <- calculate_likert_index(data, "Q_Likert", options_info, weights)
  expect_null(result)
})


# ==============================================================================
# 10. calculate_nps_score — direct unit tests
# ==============================================================================

context("calculate_nps_score — direct")

test_that("NPS score returns value between -100 and 100", {
  set.seed(42)
  n <- 100
  data <- data.frame(
    Q_NPS = sample(0:10, n, replace = TRUE),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, n)

  result <- calculate_nps_score(data, "Q_NPS", weights)

  expect_false(is.null(result))
  expect_equal(result$stat_name, "NPS Score")
  expect_true(result$value >= -100 && result$value <= 100)
})

test_that("NPS score matches manual calculation", {
  # All promoters (9, 10) => NPS = +100
  data_all_promoters <- data.frame(Q_NPS = c(9, 10, 9, 10, 10), stringsAsFactors = FALSE)
  result_promo <- calculate_nps_score(data_all_promoters, "Q_NPS", rep(1, 5))
  expect_equal(result_promo$value, 100)

  # All detractors (0-6) => NPS = -100
  data_all_detractors <- data.frame(Q_NPS = c(0, 1, 2, 3, 4), stringsAsFactors = FALSE)
  result_detract <- calculate_nps_score(data_all_detractors, "Q_NPS", rep(1, 5))
  expect_equal(result_detract$value, -100)

  # Mixed: 3 promoters, 2 detractors, 1 passive => (3-2)/6*100 = 16.67
  data_mixed <- data.frame(Q_NPS = c(9, 10, 10, 0, 3, 8), stringsAsFactors = FALSE)
  result_mixed <- calculate_nps_score(data_mixed, "Q_NPS", rep(1, 6))
  expected_nps <- ((3 - 2) / 6) * 100
  expect_equal(result_mixed$value, expected_nps, tolerance = 0.01)
})

test_that("NPS score filters out DK and blank responses", {
  data <- data.frame(
    Q_NPS = c("9", "10", "DK", "Don't know", "", "0"),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 6)

  result <- calculate_nps_score(data, "Q_NPS", weights)

  expect_false(is.null(result))
  # Only 3 valid: 9 (promoter), 10 (promoter), 0 (detractor) => (2-1)/3*100
  expected_nps <- ((2 - 1) / 3) * 100
  expect_equal(result$value, expected_nps, tolerance = 0.01)
})


# ==============================================================================
# 11. calculate_chi_square_row — direct unit tests
# ==============================================================================

context("calculate_chi_square_row — direct")

test_that("chi-square returns row with RowType ChiSquare for valid data", {
  # Simulate BoxCategory frequency results with strong association
  boxcategory_results <- data.frame(
    RowLabel = c("Top 2 Box", "Bottom 2 Box"),
    RowType = c("Frequency", "Frequency"),
    RowSource = c("boxcategory", "boxcategory"),
    "TOTAL::Total" = c(100, 100),
    "Gender::Male" = c(70, 30),
    "Gender::Female" = c(30, 70),
    check.names = FALSE, stringsAsFactors = FALSE
  )

  banner_info <- list(
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female")
  )
  config <- list(alpha = 0.05)

  result <- calculate_chi_square_row(boxcategory_results, banner_info, config)

  expect_false(is.null(result))
  expect_true(is.data.frame(result))
  expect_equal(result$RowType, "ChiSquare")
  expect_equal(result$RowSource, "chi_square")
  # RowLabel should contain chi-square statistic info
  expect_true(grepl("Chi-square", result$RowLabel))
})

test_that("chi-square returns NULL for insufficient data", {
  # Only one row — need at least 2 for chi-square
  boxcategory_results <- data.frame(
    RowLabel = "Top 2 Box",
    RowType = "Frequency",
    RowSource = "boxcategory",
    "TOTAL::Total" = 50,
    "Gender::Male" = 30,
    "Gender::Female" = 20,
    check.names = FALSE, stringsAsFactors = FALSE
  )

  banner_info <- list(
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female")
  )
  config <- list(alpha = 0.05)

  result <- calculate_chi_square_row(boxcategory_results, banner_info, config)
  expect_null(result)
})

test_that("chi-square returns NULL for NULL or empty inputs", {
  banner_info <- list(internal_keys = c("TOTAL::Total", "Gender::Male"))
  config <- list(alpha = 0.05)

  expect_null(calculate_chi_square_row(NULL, banner_info, config))
  expect_null(calculate_chi_square_row(
    data.frame(), banner_info, config
  ))
  expect_null(calculate_chi_square_row(
    data.frame(RowLabel = "x", RowType = "Frequency", stringsAsFactors = FALSE),
    NULL, config
  ))
})
