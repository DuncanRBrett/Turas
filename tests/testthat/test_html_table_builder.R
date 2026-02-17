# ==============================================================================
# TESTS: HTML REPORT TABLE BUILDER
# ==============================================================================
# Tests for build_question_table() — verifies HTML table structure,
# heatmap data attributes, significance badges, low-base handling.
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
source(file.path(turas_root, "modules/tabs/lib/html_report/02_table_builder.R"))

# htmltools is required
if (!requireNamespace("htmltools", quietly = TRUE)) {
  skip("htmltools package not available")
}


# ==============================================================================
# FIXTURES
# ==============================================================================

#' Build a minimal question_data structure as returned by transform_single_question
make_table_question_data <- function(
    n_rows = 4,
    labels = c("Option A", "Option B", "Option C", "Option D"),
    total_pcts = c(40, 30, 20, 10),
    include_sig = FALSE,
    include_freq = FALSE,
    include_base = TRUE,
    total_base = 100,
    banner_base = 50
) {

  # Build table_data with dot-prefixed metadata columns
  td <- data.frame(
    .row_label = character(0),
    .row_type = character(0),
    .is_net = logical(0),
    .stat_type = character(0),
    stringsAsFactors = FALSE
  )

  # Base row
  if (include_base) {
    base_row <- data.frame(
      .row_label = "Base",
      .row_type = "base",
      .is_net = FALSE,
      .stat_type = "Base",
      stringsAsFactors = FALSE
    )
    base_row[["TOTAL::Total"]] <- total_base
    base_row[["Q01::Male"]] <- banner_base
    td <- rbind(td, base_row)
  }

  # Category rows (Column %)
  for (i in seq_along(labels)) {
    row <- data.frame(
      .row_label = labels[i],
      .row_type = "category",
      .is_net = FALSE,
      .stat_type = "Column %",
      stringsAsFactors = FALSE
    )
    row[["TOTAL::Total"]] <- total_pcts[i]
    row[["Q01::Male"]] <- total_pcts[i] + 5  # slightly different
    td <- rbind(td, row)
  }

  # Add base columns for low-base detection
  if (include_base) {
    td[[".base_TOTAL::Total"]] <- total_base
    td[[".base_Q01::Male"]] <- banner_base
  }

  # Add sig columns (table builder reads from .sig_ prefixed columns)
  if (include_sig) {
    td[[".sig_TOTAL::Total"]] <- rep("-", nrow(td))
    td[[".sig_Q01::Male"]] <- rep("-", nrow(td))
    # Set sig flag on first category row for Male column
    cat_rows <- which(td$.row_type == "category" & td$.stat_type == "Column %")
    if (length(cat_rows) > 0) {
      td[[".sig_Q01::Male"]][cat_rows[1]] <- "B"
    }
  }

  # Stats
  stats <- list(
    has_sig = include_sig,
    has_freq = include_freq,
    has_col_pct = TRUE,
    has_row_pct = FALSE
  )

  list(
    q_code = "Q001",
    question_text = "Test question",
    question_type = "Single_Choice",
    table_data = td,
    stats = stats,
    primary_stat = "Column %",
    base_filter = NA,
    index_description = NULL
  )
}

make_banner_groups <- function() {
  list(
    Q01 = list(
      banner_code = "Q01",
      internal_keys = c("Q01::Male"),
      display_labels = c("Male"),
      letters = c("A")
    )
  )
}

make_table_config <- function(overrides = list()) {
  defaults <- list(
    brand_colour = "#0d8a8a",
    significance_min_base = 30,
    embed_frequencies = FALSE,
    enable_significance_testing = FALSE
  )
  modifyList(defaults, overrides)
}


# ==============================================================================
# TEST: Basic table generation
# ==============================================================================

test_that("build_question_table returns htmltools::HTML object", {
  q_data <- make_table_question_data()
  result <- build_question_table(q_data, make_banner_groups(), make_table_config())

  expect_s3_class(result, "html")
  html_str <- as.character(result)
  expect_true(nchar(html_str) > 0)
})

test_that("build_question_table produces valid HTML table structure", {
  q_data <- make_table_question_data()
  result <- build_question_table(q_data, make_banner_groups(), make_table_config())
  html_str <- as.character(result)

  expect_true(grepl("<table", html_str))
  expect_true(grepl("<thead>", html_str))
  expect_true(grepl("<tbody>", html_str))
  expect_true(grepl("</table>", html_str))
})

test_that("build_question_table includes all category labels", {
  labels <- c("Excellent", "Good", "Average", "Poor")
  q_data <- make_table_question_data(labels = labels)
  result <- build_question_table(q_data, make_banner_groups(), make_table_config())
  html_str <- as.character(result)

  for (label in labels) {
    expect_true(grepl(label, html_str), info = paste("Missing label:", label))
  }
})


# ==============================================================================
# TEST: Banner group CSS classes
# ==============================================================================

test_that("build_question_table applies banner group CSS classes", {
  q_data <- make_table_question_data()
  result <- build_question_table(q_data, make_banner_groups(), make_table_config())
  html_str <- as.character(result)

  # Total column should have bg-total class
  expect_true(grepl("bg-total", html_str))
  # Banner column should have bg-Q01 class
  expect_true(grepl("bg-Q01", html_str))
})

test_that("build_question_table includes data-col-key attributes", {
  q_data <- make_table_question_data()
  result <- build_question_table(q_data, make_banner_groups(), make_table_config())
  html_str <- as.character(result)

  expect_true(grepl('data-col-key="TOTAL::Total"', html_str))
  expect_true(grepl('data-col-key="Q01::Male"', html_str))
})


# ==============================================================================
# TEST: Heatmap data attributes
# ==============================================================================

test_that("build_question_table adds heatmap data attributes for percentage cells", {
  q_data <- make_table_question_data()
  result <- build_question_table(q_data, make_banner_groups(), make_table_config())
  html_str <- as.character(result)

  # Percentage cells should have data-heatmap attribute
  expect_true(grepl("data-heatmap", html_str))
  expect_true(grepl("ct-heatmap-cell", html_str))
})


# ==============================================================================
# TEST: Low base handling
# ==============================================================================

test_that("build_question_table dims cells with low base", {
  # Set banner base below min_base threshold
  q_data <- make_table_question_data(banner_base = 20)
  config <- make_table_config(list(significance_min_base = 30))
  result <- build_question_table(q_data, make_banner_groups(), config)
  html_str <- as.character(result)

  expect_true(grepl("ct-low-base-dim", html_str))
})

test_that("build_question_table shows warning icon for low base count", {
  q_data <- make_table_question_data(total_base = 15)
  config <- make_table_config(list(significance_min_base = 30))
  result <- build_question_table(q_data, make_banner_groups(), config)
  html_str <- as.character(result)

  expect_true(grepl("ct-low-base", html_str))
})


# ==============================================================================
# TEST: Significance badges
# ==============================================================================

test_that("build_question_table includes sig badges when sig data present", {
  q_data <- make_table_question_data(include_sig = TRUE)
  config <- make_table_config(list(enable_significance_testing = TRUE))

  result <- build_question_table(q_data, make_banner_groups(), config)
  html_str <- as.character(result)

  expect_true(grepl("ct-sig", html_str))
})


# ==============================================================================
# TEST: Table ID
# ==============================================================================

test_that("build_question_table applies custom table_id", {
  q_data <- make_table_question_data()
  result <- build_question_table(
    q_data, make_banner_groups(), make_table_config(),
    table_id = "my-custom-table"
  )
  html_str <- as.character(result)

  expect_true(grepl('id="my-custom-table"', html_str))
})


# ==============================================================================
# TEST: Percentage formatting
# ==============================================================================

test_that("build_question_table adds % suffix to percentage values", {
  q_data <- make_table_question_data(total_pcts = c(55, 25, 15, 5))
  result <- build_question_table(q_data, make_banner_groups(), make_table_config())
  html_str <- as.character(result)

  # Values should appear with % suffix
  expect_true(grepl("55%", html_str))
  expect_true(grepl("25%", html_str))
})


# ==============================================================================
# TEST: Sort data attributes
# ==============================================================================

test_that("build_question_table adds sort data attributes on category rows", {
  q_data <- make_table_question_data(total_pcts = c(40, 30, 20, 10))
  result <- build_question_table(q_data, make_banner_groups(), make_table_config())
  html_str <- as.character(result)

  expect_true(grepl("data-sort-val", html_str))
})


# ==============================================================================
# TEST: Missing values
# ==============================================================================

test_that("build_question_table handles NA values gracefully", {
  q_data <- make_table_question_data()
  # Inject an NA value
  q_data$table_data[["TOTAL::Total"]][2] <- NA

  result <- build_question_table(q_data, make_banner_groups(), make_table_config())
  html_str <- as.character(result)

  # Should show em-dash for missing values
  expect_true(grepl("ct-na", html_str))
  expect_true(grepl("&mdash;", html_str))
})
