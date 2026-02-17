# ==============================================================================
# TESTS: HTML REPORT DATA TRANSFORMER
# ==============================================================================
# Tests for transform_for_html() and transform_single_question()
# Validates data transformation from all_results to HTML-ready structures
# ==============================================================================

library(testthat)

# Source required modules
turas_root <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(turas_root)) {
  candidate <- getwd()
  for (i in 1:5) {
    if (file.exists(file.path(candidate, "modules", "tabs", "lib", "html_report", "00_html_guard.R"))) {
      turas_root <- candidate
      break
    }
    candidate <- dirname(candidate)
  }
  if (!nzchar(turas_root)) turas_root <- getwd()
}

source(file.path(turas_root, "modules/tabs/lib/html_report/00_html_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/html_report/01_data_transformer.R"))


# ==============================================================================
# FIXTURES: Minimal realistic data
# ==============================================================================

make_question_result <- function(
    q_code = "Q001",
    q_text = "How satisfied are you?",
    q_type = "Single_Choice",
    categories = c("Very Satisfied", "Satisfied", "Neutral", "Dissatisfied"),
    total_freqs = c(40, 30, 20, 10),
    col_pcts = c(40, 30, 20, 10),
    banner_freqs = list(Male = c(25, 15, 8, 2), Female = c(15, 15, 12, 8)),
    banner_pcts = list(Male = c(50, 30, 16, 4), Female = c(30, 30, 24, 16)),
    include_sig = FALSE,
    base_filter = NA
) {
  n_cats <- length(categories)

  # Build RowLabel and RowType vectors (interleaved Frequency, Column %)
  row_labels <- rep(categories, each = 2)
  row_types <- rep(c("Frequency", "Column %"), n_cats)

  # Build table data frame
  table <- data.frame(
    RowLabel = row_labels,
    RowType = row_types,
    stringsAsFactors = FALSE
  )

  # Interleave freq and pct for TOTAL
  total_vals <- as.numeric(rbind(total_freqs, col_pcts))
  table[["TOTAL::Total"]] <- total_vals

  # Interleave for each banner column
  for (name in names(banner_freqs)) {
    key <- paste0("Q01::", name)
    vals <- as.numeric(rbind(banner_freqs[[name]], banner_pcts[[name]]))
    table[[key]] <- vals
  }

  # Add significance rows if requested
  if (include_sig) {
    for (i in seq_along(categories)) {
      sig_row <- data.frame(
        RowLabel = categories[i],
        RowType = "Sig.",
        stringsAsFactors = FALSE
      )
      sig_row[["TOTAL::Total"]] <- "-"
      for (name in names(banner_freqs)) {
        key <- paste0("Q01::", name)
        sig_row[[key]] <- if (i == 1) "B" else "-"
      }
      table <- rbind(table, sig_row)
    }
  }

  # Build bases
  total_base <- sum(total_freqs)
  bases <- list(
    `TOTAL::Total` = list(unweighted = total_base, weighted = total_base)
  )
  for (name in names(banner_freqs)) {
    key <- paste0("Q01::", name)
    b <- sum(banner_freqs[[name]])
    bases[[key]] <- list(unweighted = b, weighted = b)
  }

  list(
    question_code = q_code,
    question_text = q_text,
    question_type = q_type,
    base_filter = base_filter,
    table = table,
    bases = bases
  )
}

make_banner_info <- function() {
  list(
    banner_info = list(
      Q01 = list(
        internal_keys = c("Q01::Male", "Q01::Female"),
        letters = c("A", "B"),
        columns = c("Male", "Female"),
        banner_code = "Q01"
      )
    ),
    banner_headers = data.frame(
      code = "Q01",
      label = "Gender",
      start_col = 2L,
      end_col = 3L,
      stringsAsFactors = FALSE
    ),
    internal_keys = c("TOTAL::Total", "Q01::Male", "Q01::Female"),
    columns = c("Total", "Male", "Female"),
    letters = c("-", "A", "B")
  )
}

make_config <- function(overrides = list()) {
  defaults <- list(
    html_report = TRUE,
    brand_colour = "#0d8a8a",
    project_title = "Test Project",
    embed_frequencies = TRUE,
    significance_min_base = 30,
    enable_significance_testing = TRUE,
    show_frequency = TRUE,
    show_percent_column = TRUE,
    show_percent_row = FALSE
  )
  modifyList(defaults, overrides)
}


# ==============================================================================
# TEST: transform_for_html — happy path
# ==============================================================================

test_that("transform_for_html returns valid structure with single question", {
  all_results <- list(Q001 = make_question_result())
  result <- transform_for_html(all_results, make_banner_info(), make_config())

  expect_true(!is.null(result$questions))
  expect_true("Q001" %in% names(result$questions))
  expect_true(!is.null(result$banner_groups))
  expect_equal(result$n_questions, 1)
})

test_that("transform_for_html handles multiple questions", {
  all_results <- list(
    Q001 = make_question_result(q_code = "Q001"),
    Q002 = make_question_result(q_code = "Q002", q_text = "Another question")
  )
  result <- transform_for_html(all_results, make_banner_info(), make_config())

  expect_equal(length(result$questions), 2)
  expect_equal(result$n_questions, 2)
})


# ==============================================================================
# TEST: transform_for_html — edge cases
# ==============================================================================
# Note: NULL/empty all_results are caught by the guard layer (00_html_guard.R)
# before transform_for_html is called. The transformer handles gracefully
# when questions are present but have invalid/skippable data.

test_that("transform_for_html skips questions with no table", {
  all_results <- list(
    Q001 = list(question_code = "Q001", table = NULL),
    Q002 = make_question_result(q_code = "Q002")
  )
  result <- transform_for_html(all_results, make_banner_info(), make_config())

  # Should include Q002 but skip Q001
  expect_equal(length(result$questions), 1)
  expect_true("Q002" %in% names(result$questions))
})

test_that("transform_for_html skips questions missing required columns", {
  bad_result <- list(
    question_code = "Q001",
    question_text = "Bad question",
    question_type = "Single_Choice",
    table = data.frame(SomeCol = "a", OtherCol = 1),
    bases = list()
  )
  all_results <- list(
    Q001 = bad_result,
    Q002 = make_question_result(q_code = "Q002")
  )
  result <- transform_for_html(all_results, make_banner_info(), make_config())

  expect_equal(length(result$questions), 1)
  expect_true("Q002" %in% names(result$questions))
})


# ==============================================================================
# TEST: transform_single_question — data structure
# ==============================================================================

test_that("transform_single_question returns correct structure", {
  q_result <- make_question_result()
  transformed <- transform_single_question(q_result, make_banner_info(), make_config())

  expect_equal(transformed$q_code, "Q001")
  expect_equal(transformed$question_text, "How satisfied are you?")
  expect_true(!is.null(transformed$table_data))
  expect_true(!is.null(transformed$stats))
  expect_true(is.data.frame(transformed$table_data))
})

test_that("transform_single_question preserves all internal keys as columns", {
  q_result <- make_question_result()
  transformed <- transform_single_question(q_result, make_banner_info(), make_config())

  # Should have TOTAL::Total and banner columns
  col_names <- names(transformed$table_data)
  expect_true("TOTAL::Total" %in% col_names)
  expect_true("Q01::Male" %in% col_names)
  expect_true("Q01::Female" %in% col_names)
})

test_that("transform_single_question detects available stats", {
  q_result <- make_question_result()
  transformed <- transform_single_question(q_result, make_banner_info(), make_config())

  expect_true(is.list(transformed$stats))
  # Should detect column % is available
  expect_true(transformed$stats$has_col_pct)
})


# ==============================================================================
# TEST: transform_single_question — row classification
# ==============================================================================

test_that("transform_single_question classifies category rows correctly", {
  q_result <- make_question_result()
  transformed <- transform_single_question(q_result, make_banner_info(), make_config())

  td <- transformed$table_data
  # Should have category-type rows
  expect_true("category" %in% td$.row_type)
})

test_that("transform_single_question handles base rows", {
  q_result <- make_question_result()
  # Add a base row to the table
  base_row <- data.frame(
    RowLabel = "Base",
    RowType = "Base",
    stringsAsFactors = FALSE
  )
  base_row[["TOTAL::Total"]] <- 100
  base_row[["Q01::Male"]] <- 50
  base_row[["Q01::Female"]] <- 50
  q_result$table <- rbind(base_row, q_result$table)

  transformed <- transform_single_question(q_result, make_banner_info(), make_config())
  td <- transformed$table_data

  expect_true("base" %in% td$.row_type)
})


# ==============================================================================
# TEST: transform_single_question — significance data
# ==============================================================================

test_that("transform_single_question includes sig data when present", {
  q_result <- make_question_result(include_sig = TRUE)
  config <- make_config(list(enable_significance_testing = TRUE))
  transformed <- transform_single_question(q_result, make_banner_info(), config)

  expect_true(transformed$stats$has_sig)
})


# ==============================================================================
# TEST: transform_single_question — base filter
# ==============================================================================

test_that("transform_single_question passes through base_filter", {
  q_result <- make_question_result(base_filter = "Age >= 18")
  transformed <- transform_single_question(q_result, make_banner_info(), make_config())

  expect_equal(transformed$base_filter, "Age >= 18")
})

test_that("transform_single_question handles NA base_filter", {
  q_result <- make_question_result(base_filter = NA)
  transformed <- transform_single_question(q_result, make_banner_info(), make_config())

  expect_true(is.na(transformed$base_filter))
})
