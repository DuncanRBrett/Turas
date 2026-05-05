# ==============================================================================
# TABS MODULE - ALLOCATION PROCESSOR TESTS
# ==============================================================================
#
# Tests for Variable_Type = "Allocation" (constant-sum / budget allocation):
#   1. build_allocation_labels()         — label resolution
#   2. collect_allocation_values()       — per-banner value extraction
#   3. compute_allocation_weighted_mean() — weighted / unweighted mean
#   4. build_allocation_mean_row()       — row structure and known values
#   5. process_allocation_question()     — end-to-end processing
#   6. Validation helpers               — check_allocation_columns()
#
# KNOWN-ANSWER FIXTURE:
#   50 respondents, 3 options summing to 100 per respondent.
#   Seg A (rows 1-25): Brand A = 50, Brand B = 30, Brand C = 20
#   Seg B (rows 26-50): Brand A = 30, Brand B = 40, Brand C = 30
#   => Total means: Brand A = 40, Brand B = 35, Brand C = 25
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_allocation_processor.R")
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

# Pre-set script_dir in the global env so shared_functions.R resolves correctly
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign("script_dir", .tabs_lib_dir, envir = globalenv())

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(.tabs_lib_dir, "shared_functions.R"))
source(file.path(.tabs_lib_dir, "excel_utils.R"))   # format_output_value
source(file.path(.tabs_lib_dir, "allocation_processor.R"))

# ==============================================================================
# SHARED FIXTURES
# ==============================================================================

# Deterministic 50-respondent dataset with 3 allocation options summing to 100.
# Seg A (rows 1-25):  Q1_1 = 50, Q1_2 = 30, Q1_3 = 20
# Seg B (rows 26-50): Q1_1 = 30, Q1_2 = 40, Q1_3 = 30
make_alloc_data <- function() {
  data.frame(
    Q1_1 = c(rep(50, 25), rep(30, 25)),
    Q1_2 = c(rep(30, 25), rep(40, 25)),
    Q1_3 = c(rep(20, 25), rep(30, 25)),
    stringsAsFactors = FALSE
  )
}

make_alloc_question_info <- function(n_cols = 3L) {
  data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Allocation",
    Columns = as.integer(n_cols),
    stringsAsFactors = FALSE
  )
}

make_alloc_options <- function() {
  data.frame(
    QuestionCode = rep("Q1", 3),
    OptionText   = c("Brand A", "Brand B", "Brand C"),
    stringsAsFactors = FALSE
  )
}

# Simple two-segment banner with Total
make_alloc_banner_info <- function() {
  list(
    internal_keys = c("TOTAL::Total", "SEG::A", "SEG::B"),
    display_labels = c("Total", "Segment A", "Segment B")
  )
}

make_alloc_banner_indices <- function() {
  list(
    "TOTAL::Total" = 1:50,
    "SEG::A"       = 1:25,
    "SEG::B"       = 26:50
  )
}

make_alloc_banner_bases <- function() {
  list(
    "TOTAL::Total" = list(unweighted = 50, weighted = 50),
    "SEG::A"       = list(unweighted = 25, weighted = 25),
    "SEG::B"       = list(unweighted = 25, weighted = 25)
  )
}

make_alloc_config <- function() {
  list(
    decimal_places_numeric    = 1L,
    enable_significance_testing = FALSE,
    alpha                     = 0.05,
    alpha_secondary           = NULL,
    bonferroni_correction     = FALSE,
    significance_min_base     = 30L,
    verbose                   = FALSE
  )
}


# ==============================================================================
# 1. build_allocation_labels
# ==============================================================================

context("build_allocation_labels")

test_that("uses OptionText from question_options", {
  opts   <- make_alloc_options()
  labels <- build_allocation_labels(opts, "Q1", 3L)

  expect_equal(labels, c("Brand A", "Brand B", "Brand C"))
})

test_that("falls back to {code}_{i} when options are NULL", {
  labels <- build_allocation_labels(NULL, "Q1", 3L)

  expect_equal(labels, c("Q1_1", "Q1_2", "Q1_3"))
})

test_that("falls back to {code}_{i} when fewer options than columns", {
  opts <- data.frame(
    QuestionCode = "Q1",
    OptionText   = c("Brand A"),
    stringsAsFactors = FALSE
  )
  labels <- build_allocation_labels(opts, "Q1", 3L)

  expect_equal(labels[1], "Brand A")
  expect_equal(labels[2], "Q1_2")
  expect_equal(labels[3], "Q1_3")
})

test_that("prefers DisplayText over OptionText when present", {
  opts <- data.frame(
    QuestionCode = rep("Q1", 2),
    OptionText   = c("Option A", "Option B"),
    DisplayText  = c("Display A", ""),
    stringsAsFactors = FALSE
  )
  labels <- build_allocation_labels(opts, "Q1", 2L)

  expect_equal(labels[1], "Display A")
  expect_equal(labels[2], "Option B")  # DisplayText blank → fall through to OptionText
})


# ==============================================================================
# 2. collect_allocation_values
# ==============================================================================

context("collect_allocation_values")

test_that("returns correct values for each banner segment", {
  data    <- make_alloc_data()
  indices <- make_alloc_banner_indices()
  vals    <- collect_allocation_values(data, "Q1_1", indices)

  expect_equal(length(vals[["TOTAL::Total"]]), 50)
  expect_true(all(vals[["SEG::A"]] == 50))
  expect_true(all(vals[["SEG::B"]] == 30))
})

test_that("returns empty numeric vector for missing column", {
  data    <- make_alloc_data()
  indices <- make_alloc_banner_indices()
  vals    <- collect_allocation_values(data, "Q1_99", indices)

  expect_equal(length(vals[["TOTAL::Total"]]), 0)
})

test_that("zeros are retained (not treated as missing)", {
  data    <- data.frame(Q1_1 = c(0, 0, 100), stringsAsFactors = FALSE)
  indices <- list("TOTAL::Total" = 1:3)
  vals    <- collect_allocation_values(data, "Q1_1", indices)

  expect_equal(vals[["TOTAL::Total"]], c(0, 0, 100))
  expect_equal(length(vals[["TOTAL::Total"]]), 3)
})

test_that("NAs are excluded from value vector", {
  data    <- data.frame(Q1_1 = c(50, NA, 30), stringsAsFactors = FALSE)
  indices <- list("TOTAL::Total" = 1:3)
  vals    <- collect_allocation_values(data, "Q1_1", indices)

  expect_equal(vals[["TOTAL::Total"]], c(50, 30))
})


# ==============================================================================
# 3. compute_allocation_weighted_mean
# ==============================================================================

context("compute_allocation_weighted_mean")

test_that("unweighted mean matches base R mean — known answer", {
  # mean(c(50, 50, 30, 30)) = 40
  vals <- c(50, 50, 30, 30)
  result <- compute_allocation_weighted_mean(vals, rep(1, 4), is_weighted = FALSE)

  expect_equal(result, 40)
})

test_that("weighted mean is correct — known answer", {
  # values 60 and 20 with weights 3 and 1: (60*3 + 20*1)/(3+1) = 200/4 = 50
  vals    <- c(60, 20)
  weights <- c(3,  1)
  result  <- compute_allocation_weighted_mean(vals, weights, is_weighted = TRUE)

  expect_equal(result, 50)
})

test_that("zero-only values return mean of 0, not NA", {
  vals   <- c(0, 0, 0)
  result <- compute_allocation_weighted_mean(vals, rep(1, 3), is_weighted = FALSE)

  expect_equal(result, 0)
})

test_that("empty vector returns NA", {
  result <- compute_allocation_weighted_mean(numeric(0), numeric(0), is_weighted = FALSE)

  expect_true(is.na(result))
})

test_that("zero total weight returns NA", {
  vals    <- c(50, 30)
  weights <- c(0, 0)
  result  <- compute_allocation_weighted_mean(vals, weights, is_weighted = TRUE)

  expect_true(is.na(result))
})


# ==============================================================================
# 4. build_allocation_mean_row
# ==============================================================================

context("build_allocation_mean_row")

test_that("row has correct RowLabel and RowType", {
  data    <- make_alloc_data()
  indices <- make_alloc_banner_indices()
  weights <- make_alloc_banner_indices()  # dummy

  value_sets  <- collect_allocation_values(data, "Q1_1", indices)
  weight_sets <- collect_allocation_weights(rep(1, 50), indices)
  config      <- make_alloc_config()

  row <- build_allocation_mean_row(
    "Brand A", value_sets, weight_sets,
    c("TOTAL::Total", "SEG::A", "SEG::B"),
    config, is_weighted = FALSE
  )

  expect_equal(row$RowLabel, "Brand A")
  expect_equal(row$RowType,  "Average")
  expect_equal(row$RowSource, "individual")
})

test_that("Total mean is 40.0 for Brand A — known answer", {
  data        <- make_alloc_data()
  indices     <- make_alloc_banner_indices()
  value_sets  <- collect_allocation_values(data, "Q1_1", indices)
  weight_sets <- collect_allocation_weights(rep(1, 50), indices)
  config      <- make_alloc_config()

  row <- build_allocation_mean_row(
    "Brand A", value_sets, weight_sets,
    c("TOTAL::Total", "SEG::A", "SEG::B"),
    config, is_weighted = FALSE
  )

  # decimal_places_numeric = 1 → "40.0"
  expect_equal(as.numeric(row[["TOTAL::Total"]]), 40.0)
})

test_that("Segment means are 50.0 and 30.0 for Brand A — known answer", {
  data        <- make_alloc_data()
  indices     <- make_alloc_banner_indices()
  value_sets  <- collect_allocation_values(data, "Q1_1", indices)
  weight_sets <- collect_allocation_weights(rep(1, 50), indices)
  config      <- make_alloc_config()

  row <- build_allocation_mean_row(
    "Brand A", value_sets, weight_sets,
    c("TOTAL::Total", "SEG::A", "SEG::B"),
    config, is_weighted = FALSE
  )

  expect_equal(as.numeric(row[["SEG::A"]]), 50.0)
  expect_equal(as.numeric(row[["SEG::B"]]), 30.0)
})


# ==============================================================================
# 5. process_allocation_question — end to end
# ==============================================================================

context("process_allocation_question — happy path")

test_that("returns data frame with one row per option", {
  data        <- make_alloc_data()
  q_info      <- make_alloc_question_info()
  opts        <- make_alloc_options()
  banner_info <- make_alloc_banner_info()
  indices     <- make_alloc_banner_indices()
  bases       <- make_alloc_banner_bases()
  config      <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    rep(1, 50), bases, config, is_weighted = FALSE
  )

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 3)
})

test_that("row labels match option text", {
  data        <- make_alloc_data()
  q_info      <- make_alloc_question_info()
  opts        <- make_alloc_options()
  banner_info <- make_alloc_banner_info()
  indices     <- make_alloc_banner_indices()
  bases       <- make_alloc_banner_bases()
  config      <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    rep(1, 50), bases, config, is_weighted = FALSE
  )

  expect_equal(result$RowLabel, c("Brand A", "Brand B", "Brand C"))
})

test_that("total means are 40, 35, 25 — known answers", {
  data        <- make_alloc_data()
  q_info      <- make_alloc_question_info()
  opts        <- make_alloc_options()
  banner_info <- make_alloc_banner_info()
  indices     <- make_alloc_banner_indices()
  bases       <- make_alloc_banner_bases()
  config      <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    rep(1, 50), bases, config, is_weighted = FALSE
  )

  expect_equal(as.numeric(result[["TOTAL::Total"]]), c(40.0, 35.0, 25.0))
})

test_that("all rows have RowType = 'Average'", {
  data        <- make_alloc_data()
  q_info      <- make_alloc_question_info()
  opts        <- make_alloc_options()
  banner_info <- make_alloc_banner_info()
  indices     <- make_alloc_banner_indices()
  bases       <- make_alloc_banner_bases()
  config      <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    rep(1, 50), bases, config, is_weighted = FALSE
  )

  expect_true(all(result$RowType == "Average"))
})


context("process_allocation_question — edge cases")

test_that("zero allocation in one segment yields mean of 0, not NA", {
  # Seg A allocates 0 to Brand C; Seg B allocates 60 to Brand C
  data <- data.frame(
    Q1_1 = c(rep(100, 25), rep(40, 25)),
    Q1_2 = c(rep(0,   25), rep(0,  25)),
    Q1_3 = c(rep(0,   25), rep(60, 25)),
    stringsAsFactors = FALSE
  )
  q_info      <- make_alloc_question_info(3L)
  opts        <- make_alloc_options()
  banner_info <- make_alloc_banner_info()
  indices     <- make_alloc_banner_indices()
  bases       <- make_alloc_banner_bases()
  config      <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    rep(1, 50), bases, config, is_weighted = FALSE
  )

  # Brand C Seg A = 0.0 (not NA)
  brand_c <- result[result$RowLabel == "Brand C", ]
  expect_equal(as.numeric(brand_c[["SEG::A"]]),  0.0)
  expect_equal(as.numeric(brand_c[["SEG::B"]]), 60.0)
})

test_that("total-only (no sub-segments) returns single-column table", {
  data    <- make_alloc_data()
  q_info  <- make_alloc_question_info()
  opts    <- make_alloc_options()
  indices <- list("TOTAL::Total" = 1:50)
  bases   <- list("TOTAL::Total" = list(unweighted = 50, weighted = 50))
  banner_info <- list(
    internal_keys  = c("TOTAL::Total"),
    display_labels = c("Total")
  )
  config <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    rep(1, 50), bases, config, is_weighted = FALSE
  )

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 3)
  expect_true("TOTAL::Total" %in% names(result))
})

test_that("invalid Columns returns NULL without error", {
  data    <- make_alloc_data()
  q_info  <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Allocation",
    Columns = NA_integer_,
    stringsAsFactors = FALSE
  )
  opts        <- make_alloc_options()
  banner_info <- make_alloc_banner_info()
  indices     <- make_alloc_banner_indices()
  bases       <- make_alloc_banner_bases()
  config      <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    rep(1, 50), bases, config, is_weighted = FALSE
  )

  expect_null(result)
})

test_that("missing data column returns NA mean for that segment", {
  data <- data.frame(
    Q1_1 = c(rep(50, 25), rep(30, 25)),
    Q1_2 = c(rep(30, 25), rep(40, 25)),
    # Q1_3 is intentionally absent
    stringsAsFactors = FALSE
  )
  q_info      <- make_alloc_question_info(3L)
  opts        <- make_alloc_options()
  banner_info <- make_alloc_banner_info()
  indices     <- make_alloc_banner_indices()
  bases       <- make_alloc_banner_bases()
  config      <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    rep(1, 50), bases, config, is_weighted = FALSE
  )

  # Brand C (Q1_3) row should exist with NA values
  brand_c_row <- result[result$RowLabel == "Brand C", ]
  expect_equal(nrow(brand_c_row), 1)
  expect_true(is.na(brand_c_row[["TOTAL::Total"]]))
})


context("process_allocation_question — weighted")

test_that("weighted means are correct — known answer", {
  # 4 respondents: 2 in Seg A (w=2), 2 in Seg B (w=1)
  # Q1_1: A=80,80, B=20,20
  # Seg A weighted mean: (80*2 + 80*2)/(2+2) = 80
  # Seg B weighted mean: (20*1 + 20*1)/(1+1) = 20
  # Total weighted mean: (80*2 + 80*2 + 20*1 + 20*1)/(2+2+1+1) = 360/6 = 60
  data <- data.frame(
    Q1_1 = c(80, 80, 20, 20),
    Q1_2 = c(20, 20, 80, 80),
    stringsAsFactors = FALSE
  )
  q_info <- data.frame(
    QuestionCode = "Q1",
    Variable_Type = "Allocation",
    Columns = 2L,
    stringsAsFactors = FALSE
  )
  opts <- data.frame(
    QuestionCode = rep("Q1", 2),
    OptionText   = c("Brand A", "Brand B"),
    stringsAsFactors = FALSE
  )
  banner_info <- list(
    internal_keys  = c("TOTAL::Total", "SEG::A", "SEG::B"),
    display_labels = c("Total", "Seg A", "Seg B")
  )
  indices <- list(
    "TOTAL::Total" = 1:4,
    "SEG::A"       = 1:2,
    "SEG::B"       = 3:4
  )
  bases <- list(
    "TOTAL::Total" = list(weighted = 6, unweighted = 4),
    "SEG::A"       = list(weighted = 4, unweighted = 2),
    "SEG::B"       = list(weighted = 2, unweighted = 2)
  )
  weights <- c(2, 2, 1, 1)
  config  <- make_alloc_config()

  result <- process_allocation_question(
    data, q_info, opts, banner_info, indices,
    weights, bases, config, is_weighted = TRUE
  )

  brand_a <- result[result$RowLabel == "Brand A", ]
  expect_equal(as.numeric(brand_a[["TOTAL::Total"]]), 60.0)
  expect_equal(as.numeric(brand_a[["SEG::A"]]),       80.0)
  expect_equal(as.numeric(brand_a[["SEG::B"]]),       20.0)
})


# ==============================================================================
# 6. Validation helpers
# ==============================================================================

context("check_allocation_columns")

# Validation dependencies are already loaded via shared_functions.R above

# Inline minimal implementations for isolated validator tests
if (!exists("log_issue", mode = "function")) {
  log_issue <- function(error_log, ...) error_log
}
if (!exists("create_error_log", mode = "function")) {
  create_error_log <- function() {
    data.frame(
      Severity = character(0), Issue_Type = character(0),
      Description = character(0), QuestionCode = character(0),
      stringsAsFactors = FALSE
    )
  }
}

# Source the validator directly
source(file.path(turas_root, "modules/tabs/lib/validation/data_validators.R"))

test_that("returns no issues when all columns present and numeric", {
  data  <- make_alloc_data()
  q_row <- data.frame(
    QuestionCode = "Q1", Columns = 3L, stringsAsFactors = FALSE
  )
  log   <- create_error_log()
  result <- check_allocation_columns(q_row, data, "numeric", log)

  expect_equal(nrow(result), 0)
})

test_that("warns when an expected column is absent", {
  data  <- make_alloc_data()
  q_row <- data.frame(
    QuestionCode = "Q1", Columns = 4L, stringsAsFactors = FALSE  # Q1_4 absent
  )
  log    <- create_error_log()
  result <- check_allocation_columns(q_row, data, "numeric", log)

  expect_true(nrow(result) >= 1)
  expect_true(any(grepl("Q1_4", result$Description)))
})

test_that("errors on non-numeric Columns value", {
  data  <- make_alloc_data()
  q_row <- data.frame(
    QuestionCode = "Q1", Columns = NA_integer_, stringsAsFactors = FALSE
  )
  log    <- create_error_log()
  result <- check_allocation_columns(q_row, data, "numeric", log)

  expect_true(nrow(result) >= 1)
  expect_true(any(result$Severity == "Error"))
})

# ==============================================================================
# END OF TEST FILE
# ==============================================================================
