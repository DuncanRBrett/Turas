# ==============================================================================
# TABS MODULE - COMPOSITE PROCESSOR TESTS
# ==============================================================================
#
# Tests for composite metric processing:
#   1. validate_composite_definitions() — input validation
#   2. calculate_composite_values() — Mean, Sum, WeightedMean
#   3. process_composite_question() — single composite processing
#   4. process_all_composites() — batch composite processing
#   5. test_composite_significance() — significance testing
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_composite_processor.R")
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
source(file.path(turas_root, "modules/tabs/lib/cell_calculator.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))
# score_utils supplies option_numeric_value(), the canonical OptionValue-else-
# OptionText lookup that composite_source_score_map() reuses for Rating/NPS.
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
# report_shared supplies resolve_column_populations() + build_fpc_multipliers(),
# which the composite significance path uses to correct its bases on a census
# project (review 2026-08, I5).
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))
source(file.path(turas_root, "modules/tabs/lib/crosstabs/data_setup.R"))  # normalise_flag_column
source(file.path(turas_root, "modules/tabs/lib/composite_processor.R"))
# analysis_runner supplies selection_declared_provenance() + the composite path
# that decides between an analyst's declaration and the generated wording.
source(file.path(turas_root, "modules/tabs/lib/crosstabs/analysis_runner.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Create test data with Rating-style questions
make_composite_test_data <- function() {
  set.seed(42)
  n <- 100
  data.frame(
    Gender = sample(c("Male", "Female"), n, replace = TRUE),
    Q_Sat1 = sample(1:5, n, replace = TRUE, prob = c(0.05, 0.10, 0.20, 0.35, 0.30)),
    Q_Sat2 = sample(1:5, n, replace = TRUE, prob = c(0.10, 0.15, 0.25, 0.30, 0.20)),
    Q_Sat3 = sample(1:5, n, replace = TRUE, prob = c(0.08, 0.12, 0.20, 0.30, 0.30)),
    Weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}

# Create questions data frame for composites
make_composite_questions <- function() {
  data.frame(
    QuestionCode = c("Q_Sat1", "Q_Sat2", "Q_Sat3"),
    QuestionText = c("Satisfaction 1", "Satisfaction 2", "Satisfaction 3"),
    Variable_Type = c("Rating", "Rating", "Rating"),
    Columns = c("Q_Sat1", "Q_Sat2", "Q_Sat3"),
    stringsAsFactors = FALSE
  )
}

# Valid composite definitions
make_composite_defs <- function() {
  data.frame(
    CompositeCode = c("OVERALL_SAT", "WEIGHTED_SAT"),
    CompositeLabel = c("Overall Satisfaction", "Weighted Satisfaction"),
    CalculationType = c("Mean", "WeightedMean"),
    SourceQuestions = c("Q_Sat1,Q_Sat2,Q_Sat3", "Q_Sat1,Q_Sat2,Q_Sat3"),
    Weights = c(NA, "0.5,0.3,0.2"),
    stringsAsFactors = FALSE
  )
}

# Banner info for testing
make_composite_banner <- function(data) {
  selection_df <- data.frame(
    QuestionCode = "Gender",
    Include = "N", UseBanner = "Y",
    BannerBoxCategory = "N", DisplayOrder = 1,
    stringsAsFactors = FALSE
  )
  survey_structure <- list(
    questions = data.frame(
      QuestionCode = "Gender", QuestionText = "Gender?",
      Variable_Type = "Single_Response", Columns = "Gender",
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
  indices <- create_banner_row_indices(data, banner)
  list(banner = banner, indices = indices)
}

# Config for composites
make_composite_config <- function() {
  list(
    apply_weighting = FALSE,
    weight_variable = "Weight",
    decimal_separator = ".",
    decimal_places_ratings = 1,
    enable_significance_testing = TRUE,
    alpha = 0.05,
    bonferroni_correction = FALSE,
    significance_min_base = 30,
    verbose = FALSE
  )
}


# ==============================================================================
# 1. validate_composite_definitions
# ==============================================================================

context("validate_composite_definitions")

test_that("validates correct composite definitions", {
  defs <- make_composite_defs()
  questions <- make_composite_questions()
  data <- make_composite_test_data()

  result <- validate_composite_definitions(defs, questions, data)

  expect_true(result$is_valid)
  expect_equal(length(result$errors), 0)
})

test_that("rejects duplicate CompositeCode", {
  defs <- make_composite_defs()
  defs$CompositeCode[2] <- "OVERALL_SAT"  # Duplicate
  questions <- make_composite_questions()
  data <- make_composite_test_data()

  result <- validate_composite_definitions(defs, questions, data)

  expect_false(result$is_valid)
  expect_true(any(grepl("uplicate", result$errors, ignore.case = TRUE)))
})

test_that("rejects non-existent source questions", {
  defs <- make_composite_defs()
  defs$SourceQuestions[1] <- "Q_Sat1,Q_MISSING,Q_Sat3"
  questions <- make_composite_questions()
  data <- make_composite_test_data()

  result <- validate_composite_definitions(defs, questions, data)

  expect_false(result$is_valid)
  expect_true(any(grepl("Q_MISSING|non-existent|not found", result$errors, ignore.case = TRUE)))
})

test_that("rejects invalid calculation type", {
  defs <- make_composite_defs()
  defs$CalculationType[1] <- "Divide"
  questions <- make_composite_questions()
  data <- make_composite_test_data()

  result <- validate_composite_definitions(defs, questions, data)

  expect_false(result$is_valid)
  expect_true(any(grepl("Divide|invalid|CalculationType", result$errors, ignore.case = TRUE)))
})

test_that("rejects WeightedMean without weights", {
  defs <- make_composite_defs()
  defs$Weights[2] <- NA  # WeightedMean needs weights
  questions <- make_composite_questions()
  data <- make_composite_test_data()

  result <- validate_composite_definitions(defs, questions, data)

  expect_false(result$is_valid)
  expect_true(any(grepl("eight|missing", result$errors, ignore.case = TRUE)))
})

test_that("rejects mismatched weight count", {
  defs <- make_composite_defs()
  defs$Weights[2] <- "0.5,0.5"  # Only 2 weights for 3 questions
  questions <- make_composite_questions()
  data <- make_composite_test_data()

  result <- validate_composite_definitions(defs, questions, data)

  expect_false(result$is_valid)
})

test_that("rejects mixed variable types", {
  defs <- make_composite_defs()
  questions <- make_composite_questions()
  questions$Variable_Type[2] <- "Single_Response"  # Mix Rating + Single_Response
  data <- make_composite_test_data()

  result <- validate_composite_definitions(defs, questions, data)

  expect_false(result$is_valid)
  expect_true(any(grepl("mix|type", result$errors, ignore.case = TRUE)))
})

test_that("warns on single source question", {
  defs <- data.frame(
    CompositeCode = "SINGLE_Q",
    CompositeLabel = "Single Question",
    CalculationType = "Mean",
    SourceQuestions = "Q_Sat1",
    Weights = NA,
    stringsAsFactors = FALSE
  )
  questions <- make_composite_questions()
  data <- make_composite_test_data()

  result <- validate_composite_definitions(defs, questions, data)

  # Should warn but still be valid
  expect_true(length(result$warnings) > 0)
})


# ==============================================================================
# 2. calculate_composite_values
# ==============================================================================

context("calculate_composite_values")

test_that("calculates Mean composite correctly", {
  data <- data.frame(Q1 = c(1, 2, 3, 4, 5), Q2 = c(5, 4, 3, 2, 1))
  source_questions <- c("Q1", "Q2")

  result <- calculate_composite_values(data, source_questions, "Mean")

  # Mean of each row: (1+5)/2=3, (2+4)/2=3, (3+3)/2=3, (4+2)/2=3, (5+1)/2=3
  expect_equal(result, rep(3, 5))
})

test_that("calculates Sum composite correctly", {
  data <- data.frame(Q1 = c(1, 2, 3), Q2 = c(10, 20, 30))
  source_questions <- c("Q1", "Q2")

  result <- calculate_composite_values(data, source_questions, "Sum")

  expect_equal(result, c(11, 22, 33))
})

test_that("calculates WeightedMean composite correctly", {
  data <- data.frame(Q1 = c(10, 10, 10), Q2 = c(20, 20, 20))
  source_questions <- c("Q1", "Q2")

  result <- calculate_composite_values(
    data, source_questions, "WeightedMean",
    weights = c(0.75, 0.25)
  )

  # WeightedMean: 10*0.75 + 20*0.25 = 7.5 + 5 = 12.5
  expect_equal(result, rep(12.5, 3))
})

test_that("handles NA values with na.rm", {
  data <- data.frame(Q1 = c(1, NA, 3), Q2 = c(5, 4, NA))
  source_questions <- c("Q1", "Q2")

  result <- calculate_composite_values(data, source_questions, "Mean")

  # Row 1: (1+5)/2 = 3, Row 2: 4 (only Q2), Row 3: 3 (only Q1)
  expect_equal(result[1], 3)
  expect_false(is.na(result[2]))
  expect_false(is.na(result[3]))
})

test_that("returns NA when all source values are NA", {
  data <- data.frame(Q1 = c(NA, 2), Q2 = c(NA, 4))
  source_questions <- c("Q1", "Q2")

  result <- calculate_composite_values(data, source_questions, "Mean")

  expect_true(is.na(result[1]))
  expect_equal(result[2], 3)
})


# ==============================================================================
# 3. process_composite_question
# ==============================================================================

context("process_composite_question")

test_that("processes single composite question", {
  data <- make_composite_test_data()
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()

  composite_def <- data.frame(
    CompositeCode = "OVERALL_SAT",
    CompositeLabel = "Overall Satisfaction",
    CalculationType = "Mean",
    SourceQuestions = "Q_Sat1,Q_Sat2,Q_Sat3",
    Weights = NA,
    stringsAsFactors = FALSE
  )

  result <- process_composite_question(
    composite_def, data, questions, b$banner, config
  )

  expect_true(is.list(result))
  expect_true("question_table" %in% names(result))
  expect_true(is.data.frame(result$question_table))
  expect_true("Average" %in% result$question_table$RowType)

  # Mean should be in reasonable range (1-5)
  avg_row <- result$question_table[result$question_table$RowType == "Average", ]
  total_val <- as.numeric(avg_row[["TOTAL::Total"]])
  expect_true(total_val >= 1 && total_val <= 5)
})

test_that("composite result has metadata", {
  data <- make_composite_test_data()
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()

  composite_def <- data.frame(
    CompositeCode = "OVERALL_SAT",
    CompositeLabel = "Overall Satisfaction",
    CalculationType = "Mean",
    SourceQuestions = "Q_Sat1,Q_Sat2,Q_Sat3",
    Weights = NA,
    stringsAsFactors = FALSE
  )

  result <- process_composite_question(
    composite_def, data, questions, b$banner, config
  )

  expect_true("metadata" %in% names(result))
  expect_equal(result$metadata$composite_code, "OVERALL_SAT")
  expect_equal(result$metadata$calculation_type, "Mean")
  expect_equal(length(result$metadata$source_questions), 3)
})

test_that("includes significance row when enabled", {
  data <- make_composite_test_data()
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()
  config$enable_significance_testing <- TRUE

  composite_def <- data.frame(
    CompositeCode = "OVERALL_SAT",
    CompositeLabel = "Overall Satisfaction",
    CalculationType = "Mean",
    SourceQuestions = "Q_Sat1,Q_Sat2,Q_Sat3",
    Weights = NA,
    stringsAsFactors = FALSE
  )

  result <- process_composite_question(
    composite_def, data, questions, b$banner, config
  )

  expect_true("Sig." %in% result$question_table$RowType)
})


# ==============================================================================
# 4. process_all_composites
# ==============================================================================

context("process_all_composites")

test_that("processes multiple composites", {
  data <- make_composite_test_data()
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()
  defs <- make_composite_defs()

  result <- process_all_composites(defs, data, questions, b$banner, config)

  expect_true(is.list(result))
  expect_true(length(result) >= 1)
  # Should have keys matching composite codes
  expect_true("OVERALL_SAT" %in% names(result))
})

test_that("returns empty list for NULL composite_defs", {
  data <- make_composite_test_data()
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()

  result <- process_all_composites(NULL, data, questions, b$banner, config)

  expect_true(is.list(result))
  expect_equal(length(result), 0)
})

test_that("returns empty list for zero-row composite_defs", {
  data <- make_composite_test_data()
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()

  empty_defs <- data.frame(
    CompositeCode = character(0),
    CompositeLabel = character(0),
    CalculationType = character(0),
    SourceQuestions = character(0),
    Weights = character(0),
    stringsAsFactors = FALSE
  )

  result <- process_all_composites(empty_defs, data, questions, b$banner, config)

  expect_true(is.list(result))
  expect_equal(length(result), 0)
})


# ==============================================================================
# 5. Composite value accuracy
# ==============================================================================

context("composite value accuracy")

test_that("Mean composite matches manual rowMeans calculation", {
  data <- make_composite_test_data()
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()
  config$enable_significance_testing <- FALSE

  composite_def <- data.frame(
    CompositeCode = "OVERALL_SAT",
    CompositeLabel = "Overall Satisfaction",
    CalculationType = "Mean",
    SourceQuestions = "Q_Sat1,Q_Sat2,Q_Sat3",
    Weights = NA,
    stringsAsFactors = FALSE
  )

  result <- process_composite_question(
    composite_def, data, questions, b$banner, config
  )

  avg_row <- result$question_table[result$question_table$RowType == "Average", ]
  total_val <- as.numeric(avg_row[["TOTAL::Total"]])

  # Calculate expected: mean of row means
  expected <- mean(rowMeans(data[, c("Q_Sat1", "Q_Sat2", "Q_Sat3")], na.rm = TRUE), na.rm = TRUE)

  expect_equal(total_val, expected, tolerance = 0.1)
})

test_that("WeightedMean composite uses correct weights", {
  # Simple data where we can verify manually
  data <- data.frame(
    Gender = rep("Male", 10),
    Q_Sat1 = rep(2, 10),
    Q_Sat2 = rep(4, 10),
    Q_Sat3 = rep(6, 10),
    Weight = rep(1, 10),
    stringsAsFactors = FALSE
  )
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()
  config$enable_significance_testing <- FALSE

  composite_def <- data.frame(
    CompositeCode = "WEIGHTED_SAT",
    CompositeLabel = "Weighted Satisfaction",
    CalculationType = "WeightedMean",
    SourceQuestions = "Q_Sat1,Q_Sat2,Q_Sat3",
    Weights = "0.5,0.3,0.2",
    stringsAsFactors = FALSE
  )

  result <- process_composite_question(
    composite_def, data, questions, b$banner, config
  )

  avg_row <- result$question_table[result$question_table$RowType == "Average", ]
  total_val <- as.numeric(avg_row[["TOTAL::Total"]])

  # Expected: 2*0.5 + 4*0.3 + 6*0.2 = 1.0 + 1.2 + 1.2 = 3.4
  expect_equal(total_val, 3.4, tolerance = 0.1)
})

test_that("banner subgroup means differ from total", {
  set.seed(99)
  n <- 200
  gender <- sample(c("Male", "Female"), n, replace = TRUE)
  # Males score higher
  data <- data.frame(
    Gender = gender,
    Q_Sat1 = ifelse(gender == "Male", sample(4:5, n, replace = TRUE), sample(1:3, n, replace = TRUE)),
    Q_Sat2 = ifelse(gender == "Male", sample(3:5, n, replace = TRUE), sample(1:4, n, replace = TRUE)),
    Q_Sat3 = sample(1:5, n, replace = TRUE),
    Weight = rep(1, n),
    stringsAsFactors = FALSE
  )
  questions <- make_composite_questions()
  b <- make_composite_banner(data)
  config <- make_composite_config()
  config$enable_significance_testing <- FALSE

  composite_def <- data.frame(
    CompositeCode = "OVERALL_SAT",
    CompositeLabel = "Overall Satisfaction",
    CalculationType = "Mean",
    SourceQuestions = "Q_Sat1,Q_Sat2,Q_Sat3",
    Weights = NA,
    stringsAsFactors = FALSE
  )

  result <- process_composite_question(
    composite_def, data, questions, b$banner, config
  )

  avg_row <- result$question_table[result$question_table$RowType == "Average", ]
  male_val <- as.numeric(avg_row[["Gender::Male"]])
  female_val <- as.numeric(avg_row[["Gender::Female"]])

  # Males should score higher than females
  expect_true(male_val > female_val)
})


# ==============================================================================
# 6. Label-valued sources (regression: ASSA 2026-08)
# ==============================================================================
#
# calculate_composite_values() used to coerce the raw data column with
# as.numeric(). A composite over a Likert battery whose answers are words
# ("TRUE"/"FALSE"/"Not sure") therefore averaged NA, the run logged
# "✓ Completed", and the Index_Summary cell shipped BLANK with no warning.
# Sources are now scored through their Options, and a source that scores
# nothing says so.

context("composite sources scored through Options")

# Two Q21-style true/false statements with opposite answer keys, scored
# 100 for the correct answer and 0 otherwise.
make_tf_structure <- function() {
  list(
    questions = data.frame(
      QuestionCode  = c("Q21a", "Q21b"),
      Variable_Type = c("Likert", "Likert"),
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = rep(c("Q21a", "Q21b"), each = 3),
      OptionText   = rep(c("TRUE", "FALSE", "Not sure"), 2),
      DisplayText  = rep(c("TRUE", "FALSE", "Not sure"), 2),
      Index_Weight = c(100, 0, 0,    # Q21a: True is correct
                       0, 100, 0),   # Q21b: False is correct
      stringsAsFactors = FALSE
    )
  )
}

make_tf_data <- function() {
  data.frame(
    Q21a = c("TRUE", "FALSE", "Not sure", "TRUE"),
    Q21b = c("TRUE", "TRUE",  "FALSE",    "Not sure"),
    stringsAsFactors = FALSE
  )
}

test_that("a Likert composite scores from Index_Weight instead of going blank", {
  st <- make_tf_structure()

  result <- calculate_composite_values(
    make_tf_data(), c("Q21a", "Q21b"), "Mean",
    questions_df = st$questions, options_df = st$options
  )

  # Per respondent: (100+0)/2, (0+0)/2, (0+100)/2, (100+0)/2
  expect_equal(result, c(50, 0, 50, 50))
  expect_false(any(is.na(result)))
})

test_that("without the structure a worded source is reported, not silently NA", {
  output <- capture.output(
    result <- calculate_composite_values(make_tf_data(), c("Q21a", "Q21b"), "Mean"),
    type = "output"
  )

  expect_true(all(is.na(result)))
  expect_true(any(grepl("scored nothing", output, fixed = TRUE)))
  expect_true(any(grepl("Q21a", output, fixed = TRUE)))
  expect_true(any(grepl("Q21b", output, fixed = TRUE)))
})

test_that("a Rating source maps its text answers through OptionValue", {
  questions <- data.frame(QuestionCode = c("QA", "QB"),
                          Variable_Type = c("Rating", "Rating"),
                          stringsAsFactors = FALSE)
  options <- data.frame(QuestionCode = rep(c("QA", "QB"), each = 3),
                        OptionText  = rep(c("0", "5", "10"), 2),
                        OptionValue = rep(c(0, 5, 10), 2),
                        stringsAsFactors = FALSE)
  data <- data.frame(QA = c("0", "10"), QB = c("10", "10"), stringsAsFactors = FALSE)

  result <- calculate_composite_values(data, c("QA", "QB"), "Mean",
                                       questions_df = questions, options_df = options)

  expect_equal(result, c(5, 10))
})

test_that("ExcludeFromIndex options score NA rather than dragging the mean down", {
  questions <- data.frame(QuestionCode = "QX", Variable_Type = "Likert",
                          stringsAsFactors = FALSE)
  options <- data.frame(
    QuestionCode = rep("QX", 3),
    OptionText   = c("Low", "High", "Do not know"),
    Index_Weight = c(-100, 100, 0),
    ExcludeFromIndex = c(NA, NA, "Y"),
    stringsAsFactors = FALSE
  )
  data <- data.frame(QX = c("High", "Do not know"), stringsAsFactors = FALSE)

  result <- calculate_composite_values(data, "QX", "Mean",
                                       questions_df = questions, options_df = options)

  expect_equal(result[1], 100)
  expect_true(is.na(result[2]))   # excluded, not scored as 0
})

test_that("numeric sources are unaffected when no structure is supplied", {
  data <- data.frame(Q1 = c(1, 2, 3), Q2 = c(5, 4, 3))

  expect_equal(calculate_composite_values(data, c("Q1", "Q2"), "Mean"), c(3, 3, 3))
  expect_silent(calculate_composite_values(data, c("Q1", "Q2"), "Mean"))
})

test_that("numeric sources are unaffected when a structure IS supplied", {
  # Numeric questions carry no options; the raw column must still be used.
  questions <- data.frame(QuestionCode = c("Q1", "Q2"),
                          Variable_Type = c("Numeric", "Numeric"),
                          stringsAsFactors = FALSE)
  options <- data.frame(QuestionCode = character(), OptionText = character(),
                        stringsAsFactors = FALSE)
  data <- data.frame(Q1 = c(1, 2, 3), Q2 = c(5, 4, 3))

  expect_equal(
    calculate_composite_values(data, c("Q1", "Q2"), "Mean",
                               questions_df = questions, options_df = options),
    c(3, 3, 3)
  )
})

test_that("composite_source_score_map returns NULL when it cannot score", {
  questions <- data.frame(QuestionCode = "QZ", Variable_Type = "Likert",
                          stringsAsFactors = FALSE)
  # Likert with no Index_Weight column at all -> nothing to score from.
  options <- data.frame(QuestionCode = rep("QZ", 2), OptionText = c("Yes", "No"),
                        stringsAsFactors = FALSE)

  expect_null(composite_source_score_map("QZ", questions, options))
  expect_null(composite_source_score_map("QZ", NULL, options))
  expect_null(composite_source_score_map("NOT_A_QUESTION", questions, options))
})

test_that("process_composite_question fills the Total column for a Likert battery", {
  st <- make_tf_structure()
  data <- cbind(make_tf_data(),
                data.frame(Gender = c("Male", "Female", "Male", "Female"),
                           stringsAsFactors = FALSE))

  b <- make_composite_banner(data)
  config <- make_composite_config()

  composite_def <- data.frame(
    CompositeCode = "COMP_KNOWLEDGE",
    CompositeLabel = "Knowledge score",
    CalculationType = "Mean",
    SourceQuestions = "Q21a,Q21b",
    Weights = NA,
    stringsAsFactors = FALSE
  )

  result <- process_composite_question(
    composite_def, data, st$questions, b$banner, config, options_df = st$options
  )

  metric <- result$question_table[result$question_table$RowType %in% c("Index", "Average"), ]
  expect_true(nrow(metric) > 0)
  total <- suppressWarnings(as.numeric(metric[["TOTAL::Total"]][1]))
  # Mean of 50, 0, 50, 50
  expect_equal(total, 37.5)
})

# ==============================================================================
# ExcludeFromSummary is a Y/N gate, normalised at its single load site
# ==============================================================================
#
# Production review 2026-08, I12b. The Composites sheet was not among C3's six
# gate columns, so ExcludeFromSummary reached summary_builder.R as a raw cell and
# was read there with a bare toupper(trimws(x)) == "Y". "Yes" therefore meant NO,
# and a composite the operator had asked to hide shipped to the client anyway
# without a word. It is now canonicalised to exactly "Y"/"N" in
# load_composite_definitions, on the same vocabulary as every other gate column.

context("composite_processor: ExcludeFromSummary vocabulary (I12b)")

.write_composite_structure <- function(exclude) {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Composite_Metrics")
  openxlsx::writeData(wb, "Composite_Metrics", data.frame(
    CompositeCode = "COMP_SAT", CompositeLabel = "Satisfaction",
    CalculationType = "Mean", SourceQuestions = "Q1,Q2",
    ExcludeFromSummary = exclude, stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

test_that("every yes token loads as the canonical Y", {
  for (token in c("Y", "y", "Yes", "YES", "TRUE", "T", "1", " yes ")) {
    path <- .write_composite_structure(token)
    defs <- load_composite_definitions(path)
    expect_equal(defs$ExcludeFromSummary[1], "Y", info = token)
    unlink(path)
  }
})

test_that("every no token — and a blank cell — loads as the canonical N", {
  for (token in c("N", "n", "No", "FALSE", "F", "0", "", NA_character_)) {
    path <- .write_composite_structure(token)
    defs <- load_composite_definitions(path)
    expect_equal(defs$ExcludeFromSummary[1], "N",
                 info = if (is.na(token)) "NA" else token)
    unlink(path)
  }
})

test_that("an unreadable token refuses at load rather than publishing in silence", {
  path <- .write_composite_structure("maybe")
  expect_error(load_composite_definitions(path), class = "turas_refusal")
  unlink(path)
})

test_that("a sheet with no ExcludeFromSummary column is unaffected", {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Composite_Metrics")
  openxlsx::writeData(wb, "Composite_Metrics", data.frame(
    CompositeCode = "COMP_SAT", CompositeLabel = "Satisfaction",
    CalculationType = "Mean", SourceQuestions = "Q1,Q2", stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  defs <- load_composite_definitions(path)
  expect_true(all(is.na(defs$ExcludeFromSummary)))
  unlink(path)
})

# ==============================================================================
# The composite carries its OWN per-column bases (M-K)
# ==============================================================================
#
# Production review 2026-08, M-K. The Index_Summary's disclosure gate used to
# borrow the FIRST source question's bases, which is a different set of people
# whenever the sources are routed differently. The composite now publishes the
# base its own significance path already computed — respondents in the column
# with a scoreable composite value — so the gate and the finite population
# correction read one definition.

context("composite_processor: the composite's own bases (M-K)")

test_that("the result carries a base for every banner column", {
  data <- make_composite_test_data()
  b <- make_composite_banner(data)
  result <- process_composite_question(
    make_composite_defs()[1, ], data, make_composite_questions(), b$banner,
    make_composite_config())

  expect_true("bases" %in% names(result))
  expect_setequal(names(result$bases), b$banner$internal_keys)
  for (k in b$banner$internal_keys) {
    expect_true(is.numeric(result$bases[[k]]$unweighted), info = k)
    expect_false(is.na(result$bases[[k]]$unweighted), info = k)
  }
})

test_that("the base counts respondents with a scoreable composite value", {
  data <- make_composite_test_data()
  b <- make_composite_banner(data)
  result <- process_composite_question(
    make_composite_defs()[1, ], data, make_composite_questions(), b$banner,
    make_composite_config())

  total <- result$bases[["TOTAL::Total"]]$unweighted
  expect_true(total > 0)
  expect_true(total <= nrow(data))          # never more people than were asked
  # The banner columns partition the sample, so they cannot exceed the Total.
  for (k in setdiff(names(result$bases), "TOTAL::Total")) {
    expect_true(result$bases[[k]]$unweighted <= total, info = k)
  }
})

test_that("a respondent with no scoreable source does not count toward the base", {
  # Blank every source for the first two respondents: the composite cannot be
  # computed for them, so they leave its base — which is exactly the difference
  # between the composite's own base and a source question's.
  data <- make_composite_test_data()
  srcs <- c("Q_Sat1", "Q_Sat2", "Q_Sat3")
  for (s in srcs) data[[s]][1:2] <- NA
  b <- make_composite_banner(data)
  result <- process_composite_question(
    make_composite_defs()[1, ], data, make_composite_questions(), b$banner,
    make_composite_config())

  expect_equal(result$bases[["TOTAL::Total"]]$unweighted, nrow(data) - 2L)
})

# ==============================================================================
# PROVENANCE — a composite states its own, and the Selection sheet overrides it
# ==============================================================================

test_that("composite_provenance reads the definition Turas already has", {
  defs <- make_composite_defs()

  m <- composite_provenance(defs[1, , drop = FALSE])
  expect_identical(m$source, "Q_Sat1, Q_Sat2, Q_Sat3")
  expect_identical(m$formula, "mean of the 3 source questions")

  # The weights join the sentence only when there is one per source question.
  w <- composite_provenance(defs[2, , drop = FALSE])
  expect_identical(w$source, "Q_Sat1, Q_Sat2, Q_Sat3")
  expect_identical(w$formula,
                   "weighted mean of the 3 source questions (weights 0.5, 0.3, 0.2)")

  s <- defs[1, , drop = FALSE]
  s$CalculationType <- "Sum"
  expect_identical(composite_provenance(s)$formula, "sum of the 3 source questions")

  one <- defs[1, , drop = FALSE]
  one$SourceQuestions <- "Q_Sat1"
  expect_identical(composite_provenance(one)$formula, "mean of the 1 source question")
})

test_that("composite_provenance never describes a calculation it cannot verify", {
  defs <- make_composite_defs()

  # A weight list that does not match the source questions is not reported —
  # naming weights the engine did not use would be worse than naming none.
  bad <- defs[2, , drop = FALSE]
  bad$Weights <- "0.5,0.3"
  expect_identical(composite_provenance(bad)$formula,
                   "weighted mean of the 3 source questions")

  # An unrecognised type is the analyst's own word, not a guess.
  odd <- defs[1, , drop = FALSE]
  odd$CalculationType <- "Median"
  expect_identical(composite_provenance(odd)$formula, "Median of the 3 source questions")

  # Nothing to go on -> nothing said.
  expect_identical(composite_provenance(NULL), list(source = "", formula = ""))
  none <- defs[1, , drop = FALSE]
  none$SourceQuestions <- NA_character_
  expect_identical(composite_provenance(none), list(source = "", formula = ""))
})

test_that("the Selection sheet overrides the generated provenance, per field", {
  # Only Formula is declared: the analyst's wording wins there, and the
  # generated Source still stands. All-or-nothing would make an analyst retype
  # the source list just to reword the calculation.
  sel <- data.frame(
    QuestionCode = c("OVERALL_SAT", "Q_Sat1"),
    Source = c("", "survey question"),
    Formula = c("the satisfaction index, as agreed with the client", ""),
    stringsAsFactors = FALSE
  )
  got <- selection_declared_provenance(sel, "OVERALL_SAT")
  expect_identical(got$source, "")
  expect_identical(got$formula, "the satisfaction index, as agreed with the client")

  # A code the sheet does not carry, and a sheet without the columns at all.
  expect_identical(selection_declared_provenance(sel, "NOT_THERE"),
                   list(source = "", formula = ""))
  expect_identical(selection_declared_provenance(data.frame(QuestionCode = "X"), "X"),
                   list(source = "", formula = ""))
  expect_identical(selection_declared_provenance(NULL, "OVERALL_SAT"),
                   list(source = "", formula = ""))
})

test_that("a composite reaches the results list carrying its provenance", {
  # The seam that matters: whatever add_composites_to_results() puts on the
  # result is what build_dl_question() reads onto the report card.
  defs <- make_composite_defs()
  comp <- list(OVERALL_SAT = list(
    question_table = data.frame(RowLabel = "Overall Satisfaction", Total = 4.2,
                                stringsAsFactors = FALSE),
    metadata = list(composite_code = "OVERALL_SAT")))

  auto <- add_composites_to_results(list(), comp, NULL, defs, NULL)
  expect_identical(auto$OVERALL_SAT$source, "Q_Sat1, Q_Sat2, Q_Sat3")
  expect_identical(auto$OVERALL_SAT$formula, "mean of the 3 source questions")

  sel <- data.frame(QuestionCode = "OVERALL_SAT", Source = "",
                    Formula = "the client's agreed satisfaction index",
                    stringsAsFactors = FALSE)
  over <- add_composites_to_results(list(), comp, NULL, defs, sel)
  expect_identical(over$OVERALL_SAT$source, "Q_Sat1, Q_Sat2, Q_Sat3")
  expect_identical(over$OVERALL_SAT$formula, "the client's agreed satisfaction index")

  # No definitions and no Selection sheet: NA, not "", so the data layer omits
  # the keys and a report with nothing to say stays byte-identical.
  bare <- add_composites_to_results(list(), comp, NULL, NULL, NULL)
  expect_true(is.na(bare$OVERALL_SAT$source))
  expect_true(is.na(bare$OVERALL_SAT$formula))
})
