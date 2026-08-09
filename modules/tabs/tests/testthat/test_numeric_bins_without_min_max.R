# ==============================================================================
# TABS - NUMERIC QUESTIONS WHOSE OPTIONS ARE NOT BINS
# ==============================================================================
# A Numeric question can carry Options rows without being binned: the rows are
# display labels and the Options sheet has no Min/Max columns at all. That is a
# question with no bins, not a question with broken bins.
#
# Bin validation was gated on the rows alone, so every such question went into
# the bin checks. check_bin_structure() logged a "Missing Bin Columns" Error per
# question, and check_bin_overlaps() read option_info$Min on an absent column —
# NULL, so as.numeric() gives numeric(0), is.na() gives logical(0), and
# `logical(0) || logical(0)` evaluates to NA. The `if` then failed with "missing
# value where TRUE/FALSE needed" and took the entire validation run down with a
# CFG_ENV_INTERNAL_ERROR that named nothing.
#
# Found on the VAS 2026 reporting structure: 374 Numeric questions, 207 of them
# with two or more label rows, and an Options sheet with no Min/Max.
# ==============================================================================

library(testthat)

turas_root <- local({
  p <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(p, "modules", "tabs", "lib"))) return(normalizePath(p))
    p <- dirname(p)
  }
  NULL
})

skip_if(is.null(turas_root), "Turas root not found")

if (!exists("create_error_log", mode = "function")) {
  create_error_log <- function() {
    data.frame(
      Timestamp = character(), Component = character(),
      Issue_Type = character(), Description = character(),
      QuestionCode = character(), Severity = character(),
      stringsAsFactors = FALSE
    )
  }
  assign("create_error_log", create_error_log, envir = globalenv())
}

source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/validation/data_validators.R"))


# Options as a reporting structure writes them: labels, no Min/Max.
label_options <- function(n = 3) {
  data.frame(
    QuestionCode = rep("Q_SPEND", n),
    OptionText = paste0("Label ", seq_len(n)),
    DisplayText = paste0("Label ", seq_len(n)),
    DisplayOrder = seq_len(n),
    stringsAsFactors = FALSE
  )
}

binned_options <- function(mins, maxs) {
  data.frame(
    QuestionCode = rep("Q_SPEND", length(mins)),
    OptionText = paste0("Bin ", seq_along(mins)),
    Min = mins,
    Max = maxs,
    stringsAsFactors = FALSE
  )
}

numeric_question <- function() {
  data.frame(
    QuestionCode = "Q_SPEND",
    QuestionText = "Monthly spend",
    Variable_Type = "Numeric",
    stringsAsFactors = FALSE
  )
}

spend_data <- function() {
  data.frame(Q_SPEND = c(10, 25, 40, 55, 70), stringsAsFactors = FALSE)
}


test_that("check_bin_overlaps survives an Options table with no Min/Max columns", {
  # This is the call that raised "missing value where TRUE/FALSE needed".
  el <- create_error_log()

  result <- check_bin_overlaps("Q_SPEND", label_options(3), el)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("a Numeric question with label options and no bins validates quietly", {
  el <- create_error_log()

  result <- validate_numeric_question(
    numeric_question(), label_options(3), spend_data(), el
  )

  expect_s3_class(result, "data.frame")
  # Nothing about bins — no "Missing Bin Columns" Error, which would have been
  # logged once per question across the whole structure.
  expect_false(any(grepl("Bin", result$Issue_Type, ignore.case = TRUE)))
  expect_equal(sum(result$Severity == "Error"), 0)
})

test_that("real bins are still checked — overlaps are still caught", {
  # The fix must not buy safety by switching bin validation off.
  el <- create_error_log()

  result <- check_bin_overlaps(
    "Q_SPEND", binned_options(c(0, 20), c(30, 50)), el
  )

  expect_equal(nrow(result), 1)
  expect_equal(result$Issue_Type[1], "Overlapping Bins")
})

test_that("non-overlapping bins pass", {
  el <- create_error_log()

  result <- check_bin_overlaps(
    "Q_SPEND", binned_options(c(0, 30), c(30, 60)), el
  )

  expect_equal(nrow(result), 0)
})

test_that("a bin row with a blank bound is skipped, not fatal", {
  # The columns exist but one row has no numbers in them.
  el <- create_error_log()

  result <- check_bin_overlaps(
    "Q_SPEND", binned_options(c(0, NA), c(30, NA)), el
  )

  expect_equal(nrow(result), 0)
})

test_that("a Numeric question with real bins still reports a bad range", {
  el <- create_error_log()

  result <- validate_numeric_question(
    numeric_question(), binned_options(c(0, 40), c(30, 20)), spend_data(), el
  )

  expect_true(any(result$Issue_Type == "Invalid Bin Range"))
})

test_that("has_bin_columns and is_usable_bound answer the edge cases", {
  expect_false(has_bin_columns(label_options(2)))
  expect_true(has_bin_columns(binned_options(0, 10)))
  expect_false(has_bin_columns(NULL))

  # numeric(0) is the shape that produced NA in the original `if`.
  expect_false(is_usable_bound(numeric(0)))
  expect_false(is_usable_bound(NA_real_))
  expect_false(is_usable_bound(c(1, 2)))
  expect_true(is_usable_bound(0))
})


# ==============================================================================
# The same premise in the processor, not just the validator
# ==============================================================================
# Validation was only half of it. categorize_numeric_bins() sorted the options by
# option_info$Min, which is NULL when the column does not exist — and order(NULL)
# raises "argument 1 is not a vector". That surfaced as
# DATA_NUMERIC_QUESTION_FAILED naming the question and not the cause, on the
# first Numeric question whose options were labels.

source(file.path(turas_root, "modules/tabs/lib/numeric_processor.R"))

test_that("categorize_numeric_bins returns no bins when there are no Min/Max columns", {
  # Options as a frequency cascade writes them: answer texts, no bounds.
  labels <- data.frame(
    QuestionCode = rep("Q_TXN", 4),
    OptionText = c("Once a week or more often", "A few times in a month",
                   "Once per month", "Less than once per month"),
    DisplayOrder = 1:4,
    stringsAsFactors = FALSE
  )

  result <- categorize_numeric_bins(c(1, 2, 4, 8, NA), labels)

  expect_equal(length(result), 5)
  expect_true(all(is.na(result)))
})

test_that("categorize_numeric_bins still bins when Min/Max are there", {
  bins <- data.frame(
    OptionText = c("Low", "High"),
    Min = c(0, 5), Max = c(4, 10),
    DisplayOrder = 1:2,
    stringsAsFactors = FALSE
  )

  expect_equal(categorize_numeric_bins(c(1, 7, 20), bins),
               c("Low", "High", NA))
})

test_that("categorize_numeric_bins handles no options at all", {
  empty <- data.frame(OptionText = character(0), Min = numeric(0),
                      Max = numeric(0), stringsAsFactors = FALSE)
  expect_true(all(is.na(categorize_numeric_bins(c(1, 2), empty))))
})
