# ==============================================================================
# TABS MODULE - READER-EXPERIENCE SOURCE FIELD TESTS (READER_EXPERIENCE_PLAN §E)
# ==============================================================================
#
# Tests the four ADDITIVE source-format extensions:
#   1. Questions sheet ShortLabel            -> question.short_label
#   2. Questions sheet Scale_Min / Scale_Max -> question.scale_min / scale_max
#   3. Questions sheet LinkedOpenQuestion    -> question.linked_open (validated,
#      console NOTE when the code does not exist in the run)
#   4. Comments sheet Headline               -> question.headline
#
# The contract: a config WITHOUT the new columns produces byte-identical
# output; blank / "NA" cells omit the key entirely.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_reader_source_fields.R")
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
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

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
source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))

# html_report module sources 01_data_transformer.R (the row helpers the writer reuses)
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))

# ==============================================================================
# FIXTURES
# ==============================================================================

make_rsf_banner_info <- function() {
  list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("-", "A", "B"),
    column_to_banner = c("TOTAL::Total" = "TOTAL",
                         "Gender::Male" = "Gender",
                         "Gender::Female" = "Gender"),
    key_to_display = c("TOTAL::Total" = "Total",
                       "Gender::Male" = "Male",
                       "Gender::Female" = "Female"),
    banner_headers = data.frame(
      label = c("Total", "Gender"), start_col = c(1, 2), end_col = c(1, 3),
      stringsAsFactors = FALSE),
    banner_info = list(
      Gender = list(
        internal_keys = c("Gender::Male", "Gender::Female"),
        columns = c("Male", "Female"), letters = c("A", "B"),
        question = data.frame(QuestionCode = "Gender", QuestionText = "Gender",
                              stringsAsFactors = FALSE)))
  )
}

# Single-choice question result
make_rsf_q_single <- function() {
  list(
    question_code = "Q1", question_text = "Are you aware of the brand?",
    question_type = "Single_Choice", category = "Awareness",
    table = data.frame(
      RowLabel  = c("Yes", "Yes", "No", "No"),
      RowType   = c("Frequency", "Column %", "Frequency", "Column %"),
      RowSource = rep("individual", 4),
      "TOTAL::Total"   = c("60", "60.0", "40", "40.0"),
      "Gender::Male"   = c("35", "70.0", "15", "30.0"),
      "Gender::Female" = c("25", "50.0", "25", "50.0"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100),
      "Gender::Male"   = list(unweighted = 50),
      "Gender::Female" = list(unweighted = 50))
  )
}

# Likert question result with an Index (mean) row -> inferred scale_max path
make_rsf_q_scale <- function() {
  list(
    question_code = "Q2", question_text = "How satisfied are you overall?",
    question_type = "Likert", category = "Satisfaction",
    table = data.frame(
      RowLabel  = c("Satisfied", "Satisfied", "Dissatisfied", "Dissatisfied", "Index"),
      RowType   = c("Frequency", "Column %", "Frequency", "Column %", "Index"),
      RowSource = c(rep("individual", 4), "summary"),
      "TOTAL::Total"   = c("70", "70.0", "30", "30.0", "3.9"),
      "Gender::Male"   = c("40", "80.0", "10", "20.0", "4.1"),
      "Gender::Female" = c("30", "60.0", "20", "40.0", "3.7"),
      check.names = FALSE, stringsAsFactors = FALSE),
    bases = list(
      "TOTAL::Total"   = list(unweighted = 100),
      "Gender::Male"   = list(unweighted = 50),
      "Gender::Female" = list(unweighted = 50))
  )
}

#' Survey structure with (or without) the optional §E Questions-sheet columns.
#' All cells are supplied as character, exactly as .read_table_sheet delivers
#' them (col_types = "text"); NA = blank cell, "NA" = stringified blank.
make_rsf_structure <- function(new_cols = NULL) {
  q <- data.frame(
    QuestionCode  = c("Q1", "Q2", "Q_OPEN"),
    QuestionText  = c("Are you aware of the brand?",
                      "How satisfied are you overall?",
                      "Why do you say that?"),
    Variable_Type = c("Single_Choice", "Likert", "Open_End"),
    Columns       = c("1", "1", "1"),
    stringsAsFactors = FALSE
  )
  if (!is.null(new_cols)) {
    for (nm in names(new_cols)) q[[nm]] <- new_cols[[nm]]
  }
  list(questions = q, options = NULL)
}

make_rsf_config <- function(comments = NULL) {
  cfg <- list(project_title = "Reader Fields Test")
  if (!is.null(comments)) cfg$comments <- comments
  cfg
}

rsf_results <- function() {
  r <- list(make_rsf_q_single(), make_rsf_q_scale())
  names(r) <- c("Q1", "Q2")
  r
}

# Build the data layer quietly and return the question entry for `code`
rsf_question <- function(code, survey_structure = NULL, config_obj = make_rsf_config()) {
  dl <- NULL
  capture.output(
    dl <- build_data_layer(rsf_results(), make_rsf_banner_info(), config_obj,
                           survey_structure = survey_structure)
  )
  for (q in dl$questions) if (identical(q$code, code)) return(q)
  NULL
}

# ==============================================================================
# 1. ShortLabel -> question.short_label
# ==============================================================================

test_that("ShortLabel is emitted as question.short_label when non-blank", {
  ss <- make_rsf_structure(list(ShortLabel = c("Brand awareness", NA, NA)))
  q1 <- rsf_question("Q1", ss)
  expect_identical(q1$short_label, "Brand awareness")
  # Q2's cell is blank -> key omitted entirely
  q2 <- rsf_question("Q2", ss)
  expect_false("short_label" %in% names(q2))
})

test_that("blank / 'NA' / absent ShortLabel omits the key entirely", {
  # Column absent
  q1 <- rsf_question("Q1", make_rsf_structure())
  expect_false("short_label" %in% names(q1))
  # Stringified-blank "NA" and whitespace-only cells
  ss <- make_rsf_structure(list(ShortLabel = c("NA", "   ", NA)))
  expect_false("short_label" %in% names(rsf_question("Q1", ss)))
  expect_false("short_label" %in% names(rsf_question("Q2", ss)))
  # No survey structure at all
  q_none <- rsf_question("Q1", NULL)
  expect_false("short_label" %in% names(q_none))
})

# ==============================================================================
# 2. Scale_Min / Scale_Max -> question.scale_min / scale_max
# ==============================================================================

test_that("valid Scale_Min < Scale_Max is emitted exactly", {
  ss <- make_rsf_structure(list(Scale_Min = c(NA, "1", NA),
                                Scale_Max = c(NA, "5", NA)))
  q2 <- rsf_question("Q2", ss)
  expect_identical(q2$scale_min, 1)
  expect_identical(q2$scale_max, 5)   # explicit declaration overrides inference
  # Q1 has neither -> no scale_min key, inferred scale_max untouched (NA for single)
  q1 <- rsf_question("Q1", ss)
  expect_false("scale_min" %in% names(q1))
  expect_true(is.na(q1$scale_max))
})

test_that("half-filled, inverted or non-numeric scale bounds are ignored", {
  base_max <- rsf_question("Q2", make_rsf_structure())$scale_max  # inferred value

  # Only one bound set
  ss <- make_rsf_structure(list(Scale_Min = c(NA, "1", NA),
                                Scale_Max = c(NA, NA, NA)))
  q2 <- rsf_question("Q2", ss)
  expect_false("scale_min" %in% names(q2))
  expect_identical(q2$scale_max, base_max)

  # min >= max
  ss <- make_rsf_structure(list(Scale_Min = c(NA, "5", NA),
                                Scale_Max = c(NA, "5", NA)))
  q2 <- rsf_question("Q2", ss)
  expect_false("scale_min" %in% names(q2))
  expect_identical(q2$scale_max, base_max)

  # Non-numeric text
  ss <- make_rsf_structure(list(Scale_Min = c(NA, "low", NA),
                                Scale_Max = c(NA, "high", NA)))
  q2 <- rsf_question("Q2", ss)
  expect_false("scale_min" %in% names(q2))
  expect_identical(q2$scale_max, base_max)

  # Stringified blanks
  ss <- make_rsf_structure(list(Scale_Min = c(NA, "NA", NA),
                                Scale_Max = c(NA, "NA", NA)))
  expect_false("scale_min" %in% names(rsf_question("Q2", ss)))
})

# ==============================================================================
# 3. LinkedOpenQuestion -> question.linked_open
# ==============================================================================

test_that("LinkedOpenQuestion naming a question in the run is emitted", {
  # Q_OPEN exists on the Questions sheet (not crosstabbed) -> valid target
  ss <- make_rsf_structure(list(LinkedOpenQuestion = c(NA, "Q_OPEN", NA)))
  q2 <- rsf_question("Q2", ss)
  expect_identical(q2$linked_open, "Q_OPEN")
  # A processed question is also a valid target
  ss <- make_rsf_structure(list(LinkedOpenQuestion = c("Q2", NA, NA)))
  expect_identical(rsf_question("Q1", ss)$linked_open, "Q2")
})

test_that("LinkedOpenQuestion to a missing code prints a NOTE and omits the key", {
  ss <- make_rsf_structure(list(LinkedOpenQuestion = c(NA, "Q_NOPE", NA)))
  out <- capture.output(
    dl <- build_data_layer(rsf_results(), make_rsf_banner_info(), make_rsf_config(),
                           survey_structure = ss)
  )
  expect_true(any(grepl("\\[NOTE\\]", out)))
  expect_true(any(grepl("Q_NOPE", out)))
  q2 <- Filter(function(q) identical(q$code, "Q2"), dl$questions)[[1]]
  expect_false("linked_open" %in% names(q2))
})

test_that("blank / 'NA' LinkedOpenQuestion omits the key with no NOTE", {
  ss <- make_rsf_structure(list(LinkedOpenQuestion = c(NA, "NA", "")))
  out <- capture.output(
    dl <- build_data_layer(rsf_results(), make_rsf_banner_info(), make_rsf_config(),
                           survey_structure = ss)
  )
  expect_false(any(grepl("\\[NOTE\\]", out)))
  for (q in dl$questions) expect_false("linked_open" %in% names(q))
})

# ==============================================================================
# 4. Comments sheet Headline -> question.headline
# ==============================================================================

make_rsf_comments <- function(headlines = NULL) {
  cm <- list(Q1 = list(list(banner = NA_character_, text = "An analyst comment.")))
  if (!is.null(headlines)) attr(cm, "headlines") <- headlines
  cm
}

test_that("Headline is emitted as question.headline when configured", {
  cfg <- make_rsf_config(make_rsf_comments(list(Q2 = "Satisfaction is strong")))
  q2 <- rsf_question("Q2", NULL, cfg)
  expect_identical(q2$headline, "Satisfaction is strong")
  # Q1 has a comment but no headline -> key omitted
  q1 <- rsf_question("Q1", NULL, cfg)
  expect_false("headline" %in% names(q1))
})

test_that("no headlines attribute (or no comments) omits question.headline", {
  q2 <- rsf_question("Q2", NULL, make_rsf_config(make_rsf_comments()))
  expect_false("headline" %in% names(q2))
  q2 <- rsf_question("Q2", NULL, make_rsf_config())
  expect_false("headline" %in% names(q2))
})

test_that("load_comments_sheet reads the optional Headline column", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("readxl")
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Comments")
  openxlsx::writeData(wb, "Comments", data.frame(
    QuestionCode = c("Q1", "Q2", "Q3", "Q4"),
    Comment      = c("A comment.", NA, "Another comment.", NA),
    Headline     = c("Q1 headline", "Q2 headline (standalone)", NA, "NA"),
    stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  cm <- NULL
  capture.output(cm <- load_comments_sheet(tmp))
  expect_false(is.null(cm))
  # Comments only for rows with a usable Comment cell
  expect_identical(sort(names(cm)), c("Q1", "Q3"))
  # Headlines: present -> carried; standalone (blank Comment) row still counts;
  # blank and literal-"NA" cells are omitted
  hl <- attr(cm, "headlines", exact = TRUE)
  expect_identical(hl$Q1, "Q1 headline")
  expect_identical(hl$Q2, "Q2 headline (standalone)")
  expect_false("Q3" %in% names(hl))
  expect_false("Q4" %in% names(hl))
})

test_that("load_comments_sheet without a Headline column has no headlines attribute", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("readxl")
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Comments")
  openxlsx::writeData(wb, "Comments", data.frame(
    QuestionCode = "Q1", Comment = "A comment.", stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  cm <- NULL
  capture.output(cm <- load_comments_sheet(tmp))
  expect_false(is.null(cm))
  expect_identical(names(cm), "Q1")
  expect_null(attr(cm, "headlines", exact = TRUE))
})

# ==============================================================================
# BYTE-IDENTICAL GUARANTEE — no new columns == columns present but all blank
# ==============================================================================

test_that("a config without the new columns is byte-identical to all-blank columns", {
  results <- rsf_results()
  bi <- make_rsf_banner_info()
  cfg <- make_rsf_config(make_rsf_comments())   # comments, but no headlines

  ss_plain <- make_rsf_structure()
  ss_blank <- make_rsf_structure(list(
    ShortLabel         = c(NA, "NA", ""),
    Scale_Min          = c(NA, "NA", NA),
    Scale_Max          = c("", NA, "NA"),
    LinkedOpenQuestion = c(NA, "", "NA")
  ))

  dl_plain <- dl_blank <- NULL
  capture.output({
    dl_plain <- build_data_layer(results, bi, cfg, survey_structure = ss_plain)
    dl_blank <- build_data_layer(results, bi, cfg, survey_structure = ss_blank)
  })
  expect_identical(as.character(serialize_data_layer(dl_plain)),
                   as.character(serialize_data_layer(dl_blank)))
})

test_that("all four fields co-exist on one question", {
  ss <- make_rsf_structure(list(
    ShortLabel         = c(NA, "Overall satisfaction", NA),
    Scale_Min          = c(NA, "1", NA),
    Scale_Max          = c(NA, "5", NA),
    LinkedOpenQuestion = c(NA, "Q_OPEN", NA)
  ))
  cfg <- make_rsf_config(make_rsf_comments(list(Q2 = "Satisfaction is strong")))
  q2 <- rsf_question("Q2", ss, cfg)
  expect_identical(q2$short_label, "Overall satisfaction")
  expect_identical(q2$scale_min, 1)
  expect_identical(q2$scale_max, 5)
  expect_identical(q2$linked_open, "Q_OPEN")
  expect_identical(q2$headline, "Satisfaction is strong")
})
