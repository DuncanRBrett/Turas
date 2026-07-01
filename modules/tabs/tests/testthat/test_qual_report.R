# ==============================================================================
# TABS MODULE — QUALITATIVE COMMENT REPORT TESTS (end-to-end wiring)
# ==============================================================================
#
# Drives build_qual_report_v2 end to end: a synthetic coded-comment .xlsx ->
# a self-contained *_qual_report.html. Asserts the DATA_QUAL island is present and
# that the verbatim-text confidentiality dial actually controls whether comment text
# reaches the HTML (HIDDEN ships no raw text; FULL ships it).
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_report.R")
# ==============================================================================

library(testthat)

# ---- Bootstrap the full pipeline chain (see test_qual_quant_layer.R) ----------

local({
  detect_root <- function() {
    for (c in c(getwd(), "../..", "../../..", "../../../..")) {
      r <- tryCatch(normalizePath(c, mustWork = FALSE), error = function(e) "")
      if (nzchar(r) && dir.exists(file.path(r, "modules/tabs/lib"))) return(r)
    }
    stop("Cannot locate Turas root for qual_report test")
  }
  repo <- detect_root()
  lib <- file.path(repo, "modules/tabs/lib")
  old <- getwd(); on.exit(setwd(old), add = TRUE); setwd(lib)
  assign(".tabs_lib_dir", lib, envir = globalenv())
  suppressWarnings(suppressMessages(library(jsonlite)))
  source(file.path(repo, "modules/shared/lib/trs_refusal.R"), local = FALSE)
  for (f in c("00_guard.R", "validation_utils.R", "path_utils.R", "type_utils.R",
              "logging_utils.R", "shared_functions.R", "config_utils.R", "excel_utils.R",
              "filter_utils.R", "data_loader.R", "banner.R", "banner_indices.R",
              "cell_calculator.R", "weighting.R", "score_utils.R")) source(f, local = FALSE)
  consts <- list(TOTAL_COLUMN = "Total", SIG_ROW_TYPE = "Sig.", SIG2_ROW_TYPE = "Sig.2",
                 BASE_ROW_LABEL = "Base (n=)", UNWEIGHTED_BASE_LABEL = "Base (unweighted)",
                 WEIGHTED_BASE_LABEL = "Base (weighted)", EFFECTIVE_BASE_LABEL = "Effective base",
                 FREQUENCY_ROW_TYPE = "Frequency", COLUMN_PCT_ROW_TYPE = "Column %",
                 ROW_PCT_ROW_TYPE = "Row %", AVERAGE_ROW_TYPE = "Average", INDEX_ROW_TYPE = "Index",
                 SCORE_ROW_TYPE = "Score", MINIMUM_BASE_SIZE = 30, VERY_SMALL_BASE_SIZE = 10,
                 DEFAULT_ALPHA = 0.05, DEFAULT_MIN_BASE = 30, CHECKPOINT_FREQUENCY = 10,
                 MAX_DECIMAL_PLACES = 6)
  for (nm in names(consts)) assign(nm, consts[[nm]], envir = globalenv())
  rc <- readLines("run_crosstabs.R")
  s <- grep("^run_significance_tests_for_row <- function", rc)
  e <- grep("^add_significance_row <- function", rc)
  nx <- grep("^(#' Write question table|write_question_table_fast)", rc); nx <- nx[nx > e[1]][1] - 1
  eval(parse(text = rc[s[1]:nx]), envir = globalenv())
  ws <- grep("^write_question_table_fast <- function", rc); me <- grep("^# MAIN EXECUTION", rc)
  eval(parse(text = rc[ws[1]:(me[1] - 2)]), envir = globalenv())
  for (f in c("config_loader.R", "validation.R", "standard_processor.R", "numeric_processor.R",
              "question_dispatcher.R", "question_orchestrator.R", "composite_processor.R",
              "crosstabs/crosstabs_config.R", "html_report/01_data_transformer.R",
              "data_layer_writer.R", "microdata_writer.R", "html_report_v2/build_report_v2.R",
              "qual_workbook_reader.R", "qual_workbook_io.R", "qual_assemble.R",
              "qual_island_builder.R", "qual_quant_layer.R", "qual_report.R")) source(f, local = FALSE)
})

# ---- Synthetic coded-comment workbook (one themed sheet with a Group cut) ------

write_comment_workbook <- function(path = tempfile(fileext = ".xlsx")) {
  rows <- list(c("Why did you rate us that way?", NA, NA, NA, NA),       # preamble
               c("ID", "Group", "Comment", "Noteworthy", "Price"))        # header
  for (i in 1:12) {                                                       # 12 respondents
    grp <- if (i <= 6) "A" else "B"
    price <- if ((grp == "A" && i <= 5) || (grp == "B" && i == 7)) "1" else NA  # Price mentions
    note <- if (i %% 4 == 0) "x" else NA
    rows[[length(rows) + 1L]] <- c(as.character(i), grp,
                                   sprintf("Comment number %d about service", i), note, price)
  }
  grid <- do.call(rbind, lapply(rows, function(r) { length(r) <- 5; r }))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Overall")
  openxlsx::writeData(wb, "Overall", as.data.frame(grid), colNames = FALSE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

build_report <- function(mode) {
  wb <- write_comment_workbook()
  out <- tempfile(fileext = ".html")
  cfg <- build_config_object(list(project_name = "CommentTest",
                                  qual_confidentiality_mode = mode,
                                  significance_min_base = 5))
  res <- build_qual_report_v2(wb, out, cfg)
  list(result = res, html = paste(readLines(out, warn = FALSE), collapse = "\n"), wb = wb, out = out)
}

# ==============================================================================
# END-TO-END: a comment report is written with a populated DATA_QUAL island
# ==============================================================================

test_that("build_qual_report_v2 writes a report carrying a non-null DATA_QUAL island", {
  r <- build_report("full")
  on.exit(unlink(c(r$wb, r$out)), add = TRUE)
  expect_equal(r$result$status, "PASS")
  expect_true(file.exists(r$out))
  # The data-qual island exists and is not the null placeholder
  expect_match(r$html, '<script type="application/json" id="data-qual">', fixed = TRUE)
  expect_match(r$html, '"textMode":"full"')
  expect_match(r$html, "Price")                     # the theme made it into the islands
})

# ==============================================================================
# CONFIDENTIALITY: the text dial controls whether verbatims reach the HTML
# ==============================================================================

test_that("FULL mode ships verbatim text; HIDDEN mode ships none", {
  full <- build_report("full")
  on.exit(unlink(c(full$wb, full$out)), add = TRUE)
  expect_match(full$html, "Comment number 1 about service", fixed = TRUE)
  expect_match(full$html, '"textMode":"full"')

  hidden <- build_report("hidden")
  on.exit(unlink(c(hidden$wb, hidden$out)), add = TRUE)
  expect_false(grepl("Comment number 1 about service", hidden$html, fixed = TRUE))  # no raw text
  expect_match(hidden$html, '"textMode":"hidden"')
})

# ==============================================================================
# REFUSAL: a verbatim-only workbook is refused (Phase-1 needs themes)
# ==============================================================================

test_that("a project-relative qual_workbook resolves against the config folder", {
  proj <- file.path(tempdir(), paste0("qproj_", as.integer(Sys.time()) %% 100000))
  dir.create(proj, showWarnings = FALSE)
  on.exit(unlink(proj, recursive = TRUE), add = TRUE)
  write_comment_workbook(file.path(proj, "comments.xlsx"))        # workbook in the project folder
  cfg <- build_config_object(list(project_name = "RelPath", qual_confidentiality_mode = "hidden"))
  cfg$config_file_path <- file.path(proj, "MyConfig.xlsx")        # dirname() = the project folder
  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  res <- build_qual_report_v2("comments.xlsx", out, cfg)          # RELATIVE path
  expect_equal(res$status, "PASS")                                # resolved against config folder
})

test_that("a workbook with no themed questions is refused with a typed code", {
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path), add = TRUE)
  grid <- rbind(c("ID", "Group", "Comment", "Noteworthy"),
                c("1", "A", "just a comment", NA),
                c("2", "B", "another comment", "x"))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Suggestions")
  openxlsx::writeData(wb, "Suggestions", as.data.frame(grid), colNames = FALSE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  cfg <- build_config_object(list(project_name = "RawOnly"))
  err <- tryCatch(build_qual_report_v2(path, tempfile(fileext = ".html"), cfg),
                  turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_QUAL_NO_THEMES")
})

# ==============================================================================
# DISCLOSURE CONFIG SANITY WARNING (source-side footgun)
# ==============================================================================

test_that("qual_warn_source_disclosure warns on a leaky protected config, quiet otherwise", {
  # Threshold set but tags + full text left in the source -> loud warning.
  out <- capture.output(qual_warn_source_disclosure(list(
    min_reporting_base = 10, qual_demographic_cuts = "allow", qual_confidentiality_mode = "full")))
  expect_true(any(grepl("DISCLOSURE WARNING", out)))
  expect_true(any(grepl("demographic tags", out)))
  expect_true(any(grepl("raw verbatims", out)))

  # Source-safe protected config (block + non-full text) -> silent.
  out2 <- capture.output(qual_warn_source_disclosure(list(
    min_reporting_base = 10, qual_demographic_cuts = "block", qual_confidentiality_mode = "redacted")))
  expect_equal(length(out2), 0L)

  # Disclosure off (k = 1) -> silent regardless of the other dials.
  out3 <- capture.output(qual_warn_source_disclosure(list(
    min_reporting_base = 1, qual_demographic_cuts = "allow", qual_confidentiality_mode = "full")))
  expect_equal(length(out3), 0L)

  # "safe" (k-anonymised tags) + a non-full text mode is source-safe -> silent.
  out4 <- capture.output(qual_warn_source_disclosure(list(
    min_reporting_base = 10, qual_demographic_cuts = "safe", qual_confidentiality_mode = "redacted")))
  expect_equal(length(out4), 0L)

  # "safe" + full text warns about the TEXT only, not the tags.
  out5 <- capture.output(qual_warn_source_disclosure(list(
    min_reporting_base = 10, qual_demographic_cuts = "safe", qual_confidentiality_mode = "full")))
  expect_true(any(grepl("raw verbatims", out5)))
  expect_false(any(grepl("demographic tags", out5)))
})
