# ==============================================================================
# SEGMENT MODULE - REPORT POLISH TESTS
# ==============================================================================
# Regression tests for fix/segment-report-polish (May 2026):
#   - Bug 1: Labels sheet inside main config workbook auto-loads with documented
#            precedence over question_labels_file.
#   - Bug 2: Chart builder accepts named-vector question_labels (was rejecting
#            them via is.list() guard).
#   - Bug 3: Executive summary "top differentiating variables" sentence resolves
#            friendly labels instead of emitting raw column names.
#   - Bug 4: text-transform: uppercase has been removed from all segment HTML CSS
#            and JS-emitted inline styles; .seg-th-num has wrap behaviour for
#            long segment names.
#
# Each test asserts the observable behaviour rather than the implementation.


# ==============================================================================
# Bug 1 — Labels sheet auto-loads from main config workbook
# ==============================================================================

# Helper: build a minimal valid config workbook on disk with a Labels sheet.
# Optionally creates a stub data file so validate_segment_config() can be run.
.make_config_workbook_with_labels <- function(labels_df = NULL,
                                              include_labels_file_setting = FALSE,
                                              labels_file_path = "",
                                              create_stub_data = FALSE) {
  stub_data_path <- ""
  if (create_stub_data) {
    stub_data_path <- tempfile(fileext = ".xlsx")
    stub_wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(stub_wb, "Data")
    openxlsx::writeData(stub_wb, "Data", data.frame(
      respondent_id = 1:10,
      v1 = rnorm(10),
      v2 = rnorm(10),
      v3 = rnorm(10),
      stringsAsFactors = FALSE
    ))
    openxlsx::saveWorkbook(stub_wb, stub_data_path, overwrite = TRUE)
  }

  wb <- openxlsx::createWorkbook()

  # Config sheet (shared loader requires "Setting" / "Value" columns)
  openxlsx::addWorksheet(wb, "Config")
  config_rows <- data.frame(
    Setting = c(
      "data_file", "id_variable", "clustering_vars",
      "k_fixed", "method"
    ),
    Value = c(
      if (nzchar(stub_data_path)) stub_data_path else "stub_data.xlsx",
      "respondent_id", "v1,v2,v3",
      "3", "kmeans"
    ),
    stringsAsFactors = FALSE
  )
  if (include_labels_file_setting) {
    config_rows <- rbind(
      config_rows,
      data.frame(
        Setting = "question_labels_file",
        Value = labels_file_path,
        stringsAsFactors = FALSE
      )
    )
  }
  openxlsx::writeData(wb, "Config", config_rows)

  # Labels sheet
  if (!is.null(labels_df)) {
    openxlsx::addWorksheet(wb, "Labels")
    openxlsx::writeData(wb, "Labels", labels_df)
  }

  path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  list(config = path, data = stub_data_path)
}

test_that("Labels sheet inside main config workbook auto-loads", {
  skip_if_not(exists("read_segment_config", mode = "function"),
              "Segment module not loaded")

  labels_df <- data.frame(
    Variable = c("ATT_PLAN", "ATT_ADVISOR", "ATT_DIGITAL"),
    Label = c("Long-horizon planning", "Advisor trust", "Digital fluency"),
    stringsAsFactors = FALSE
  )
  paths <- .make_config_workbook_with_labels(labels_df)
  on.exit(unlink(paths$config), add = TRUE)

  raw <- read_segment_config(paths$config)

  expect_true(!is.null(raw$.labels))
  expect_equal(length(raw$.labels), 3)
  expect_equal(unname(raw$.labels[["ATT_ADVISOR"]]), "Advisor trust")
})

test_that("Labels sheet takes precedence over question_labels_file", {
  skip_if_not(exists("validate_segment_config", mode = "function"),
              "Segment module not loaded")

  # In-workbook labels
  workbook_labels <- data.frame(
    Variable = c("v1", "v2", "v3"),
    Label = c("Workbook label 1", "Workbook label 2", "Workbook label 3"),
    stringsAsFactors = FALSE
  )

  # Separate file labels (should be ignored when Labels sheet present)
  file_labels <- data.frame(
    Variable = c("v1", "v2", "v3"),
    Label = c("File label 1", "File label 2", "File label 3"),
    stringsAsFactors = FALSE
  )
  external_path <- tempfile(fileext = ".xlsx")
  wb_ext <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb_ext, "Labels")
  openxlsx::writeData(wb_ext, "Labels", file_labels)
  openxlsx::saveWorkbook(wb_ext, external_path, overwrite = TRUE)

  paths <- .make_config_workbook_with_labels(
    labels_df = workbook_labels,
    include_labels_file_setting = TRUE,
    labels_file_path = external_path,
    create_stub_data = TRUE
  )
  on.exit({
    unlink(paths$config)
    unlink(paths$data)
    unlink(external_path)
  }, add = TRUE)

  raw <- read_segment_config(paths$config)
  validated <- validate_segment_config(raw)

  expect_true(!is.null(validated$question_labels))
  expect_equal(
    unname(validated$question_labels[["v1"]]),
    "Workbook label 1",
    info = "Labels sheet should win over question_labels_file"
  )
})

test_that("question_labels_file still works when no Labels sheet exists", {
  skip_if_not(exists("validate_segment_config", mode = "function"),
              "Segment module not loaded")

  file_labels <- data.frame(
    Variable = c("v1", "v2", "v3"),
    Label = c("File label 1", "File label 2", "File label 3"),
    stringsAsFactors = FALSE
  )
  external_path <- tempfile(fileext = ".xlsx")
  wb_ext <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb_ext, "Labels")
  openxlsx::writeData(wb_ext, "Labels", file_labels)
  openxlsx::saveWorkbook(wb_ext, external_path, overwrite = TRUE)

  paths <- .make_config_workbook_with_labels(
    labels_df = NULL,
    include_labels_file_setting = TRUE,
    labels_file_path = external_path,
    create_stub_data = TRUE
  )
  on.exit({
    unlink(paths$config)
    unlink(paths$data)
    unlink(external_path)
  }, add = TRUE)

  raw <- read_segment_config(paths$config)
  validated <- validate_segment_config(raw)

  expect_true(!is.null(validated$question_labels))
  expect_equal(unname(validated$question_labels[["v2"]]), "File label 2")
})


# ==============================================================================
# Bug 2 — Chart builder accepts named-vector question_labels
# ==============================================================================

test_that("importance chart renders friendly labels from named vector", {
  skip_if_not(exists("build_seg_importance_chart", mode = "function"),
              "Chart builder not loaded")

  vi <- data.frame(
    variable = c("ATT_PLAN", "ATT_ADVISOR", "ATT_DIGITAL"),
    importance_pct = c(70, 50, 30),
    stringsAsFactors = FALSE
  )

  ql_named_vec <- c(
    ATT_PLAN = "Long-horizon planning",
    ATT_ADVISOR = "Advisor trust",
    ATT_DIGITAL = "Digital fluency"
  )

  html_data <- list(
    variable_importance = vi,
    question_labels = ql_named_vec
  )

  svg <- as.character(build_seg_importance_chart(html_data))

  expect_true(grepl("Long-horizon planning", svg, fixed = TRUE),
              info = "Friendly label should appear in SVG output")
  expect_true(grepl("Advisor trust", svg, fixed = TRUE))
  expect_false(grepl("ATT_PLAN", svg, fixed = TRUE),
               info = "Raw variable name should be replaced by label")
})


# ==============================================================================
# Bug 3 — Exec summary differentiating-vars sentence uses friendly labels
# ==============================================================================

test_that(".summarize_differentiating_variables emits raw names without labels", {
  skip_if_not(exists(".summarize_differentiating_variables", mode = "function"),
              "Executive summary not loaded")

  profile_df <- data.frame(
    Variable = c("ATT_PLAN", "ATT_ADVISOR", "ATT_DIGITAL"),
    eta_sq = c(0.45, 0.30, 0.20),
    stringsAsFactors = FALSE
  )

  msg <- .summarize_differentiating_variables(profile_df, top_n = 3)

  expect_true(grepl("ATT_PLAN", msg, fixed = TRUE),
              info = "Without labels, raw column names should appear")
})

test_that(".summarize_differentiating_variables uses friendly labels when provided", {
  skip_if_not(exists(".summarize_differentiating_variables", mode = "function"),
              "Executive summary not loaded")

  profile_df <- data.frame(
    Variable = c("ATT_PLAN", "ATT_ADVISOR", "ATT_DIGITAL"),
    eta_sq = c(0.45, 0.30, 0.20),
    stringsAsFactors = FALSE
  )

  ql <- c(
    ATT_PLAN = "Long-horizon planning",
    ATT_ADVISOR = "Advisor trust",
    ATT_DIGITAL = "Digital fluency"
  )

  msg <- .summarize_differentiating_variables(
    profile_df, top_n = 3, question_labels = ql
  )

  expect_true(grepl("Long-horizon planning", msg, fixed = TRUE))
  expect_true(grepl("Advisor trust", msg, fixed = TRUE))
  expect_false(grepl("ATT_PLAN", msg, fixed = TRUE),
               info = "Raw variable name should not appear when label exists")
})

test_that(".summarize_differentiating_variables passes through vars with no label", {
  skip_if_not(exists(".summarize_differentiating_variables", mode = "function"),
              "Executive summary not loaded")

  profile_df <- data.frame(
    Variable = c("ATT_PLAN", "UNKNOWN_VAR"),
    eta_sq = c(0.45, 0.30),
    stringsAsFactors = FALSE
  )

  ql <- c(ATT_PLAN = "Long-horizon planning")

  msg <- .summarize_differentiating_variables(
    profile_df, top_n = 2, question_labels = ql
  )

  expect_true(grepl("Long-horizon planning", msg, fixed = TRUE))
  expect_true(grepl("UNKNOWN_VAR", msg, fixed = TRUE),
              info = "Vars with no label should pass through unchanged")
})


# ==============================================================================
# Bug 4 — No uppercase rules in segment HTML CSS or JS; .seg-th-num wraps
# ==============================================================================

test_that("page styling CSS has no text-transform: uppercase rules", {
  turas_root <- Sys.getenv("TURAS_ROOT")
  skip_if(nchar(turas_root) == 0, "TURAS_ROOT not set")

  css_path <- file.path(turas_root, "modules", "segment", "lib", "html_report",
                        "03a_page_styling.R")
  skip_if_not(file.exists(css_path), "Page styling source not found")

  contents <- paste(readLines(css_path, warn = FALSE), collapse = "\n")

  expect_false(grepl("text-transform:\\s*uppercase", contents),
               info = "No uppercase declarations in page styling CSS")
})

test_that("combined builders CSS has no text-transform: uppercase rules", {
  turas_root <- Sys.getenv("TURAS_ROOT")
  skip_if(nchar(turas_root) == 0, "TURAS_ROOT not set")

  path <- file.path(turas_root, "modules", "segment", "lib", "html_report",
                    "07a_combined_builders.R")
  skip_if_not(file.exists(path), "Combined builders source not found")

  contents <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_false(grepl("text-transform:\\s*uppercase", contents),
               info = "No uppercase declarations in combined builders CSS")
})

test_that("seg_pins_extras.js has no inline text-transform: uppercase", {
  turas_root <- Sys.getenv("TURAS_ROOT")
  skip_if(nchar(turas_root) == 0, "TURAS_ROOT not set")

  path <- file.path(turas_root, "modules", "segment", "lib", "html_report",
                    "js", "seg_pins_extras.js")
  skip_if_not(file.exists(path), "seg_pins_extras.js not found")

  contents <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_false(grepl("text-transform:\\s*uppercase", contents),
               info = "No uppercase declarations in pinned-pins JS")
})

test_that("shared design-system table header rule has no uppercase or nowrap", {
  turas_root <- Sys.getenv("TURAS_ROOT")
  skip_if(nchar(turas_root) == 0, "TURAS_ROOT not set")

  path <- file.path(turas_root, "modules", "shared", "lib", "design_system",
                    "base_css.R")
  skip_if_not(file.exists(path), "Shared base_css.R not found")

  contents <- paste(readLines(path, warn = FALSE), collapse = "\n")

  # Extract the shared th[class*="-th"] header block (it's a single CSS rule).
  th_block_match <- regmatches(
    contents,
    regexpr('th\\[class\\*="-th"\\]\\s*\\{[^}]*\\}', contents)
  )
  skip_if(length(th_block_match) == 0,
          "Could not isolate shared th[class*=-th] CSS block")

  th_block <- th_block_match[1]
  expect_false(grepl("text-transform:\\s*uppercase", th_block),
               info = "Shared header rule must not force uppercase")
  expect_false(grepl("white-space:\\s*nowrap", th_block),
               info = "Shared header rule must allow wrapping (white-space: normal)")
})

test_that("executive summary inline H3 styles have no text-transform: uppercase", {
  turas_root <- Sys.getenv("TURAS_ROOT")
  skip_if(nchar(turas_root) == 0, "TURAS_ROOT not set")

  path <- file.path(turas_root, "modules", "segment", "R",
                    "12_executive_summary.R")
  skip_if_not(file.exists(path), "Executive summary source not found")

  contents <- paste(readLines(path, warn = FALSE), collapse = "\n")

  expect_false(grepl("text-transform:\\s*uppercase", contents),
               info = "No uppercase declarations in exec summary inline styles")
})

test_that(".seg-th-num has wrap rules for long segment names", {
  turas_root <- Sys.getenv("TURAS_ROOT")
  skip_if(nchar(turas_root) == 0, "TURAS_ROOT not set")

  css_path <- file.path(turas_root, "modules", "segment", "lib", "html_report",
                        "03a_page_styling.R")
  skip_if_not(file.exists(css_path), "Page styling source not found")

  contents <- paste(readLines(css_path, warn = FALSE), collapse = "\n")

  # Locate the .seg-th-num block
  expect_true(grepl("\\.seg-th-num\\s*\\{[^}]*max-width", contents),
              info = ".seg-th-num must declare a max-width to enable wrap")
  expect_true(grepl("\\.seg-th-num\\s*\\{[^}]*word-wrap", contents) ||
              grepl("\\.seg-th-num\\s*\\{[^}]*overflow-wrap", contents),
              info = ".seg-th-num must declare wrap behaviour")
})
