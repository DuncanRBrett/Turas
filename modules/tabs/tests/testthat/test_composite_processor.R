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
source(file.path(turas_root, "modules/tabs/lib/composite_processor.R"))


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
