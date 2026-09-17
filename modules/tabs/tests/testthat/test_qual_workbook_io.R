# ==============================================================================
# TABS MODULE. QUALITATIVE WORKBOOK I/O TESTS
# ==============================================================================
#
# Integration tests for qual_workbook_io.R: writes a known workbook to a temp
# file, reads it back through qual_read_workbook(), and checks the TRS refusals.
# Deterministic. The fixture workbook is built from literal cells in tempdir().
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_workbook_io.R")
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
  stop("Could not locate Turas root for sourcing qual workbook I/O")
}

turas_root <- detect_turas_root()
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/qual_workbook_reader.R"))
source(file.path(turas_root, "modules/tabs/lib/qual_workbook_io.R"))

# ------------------------------------------------------------------------------
# Fixture builder: write a known coded-comment workbook to a temp .xlsx.
#   - "Culture"     themed (preamble blank row, header row 2, a stray "11")
#   - "Suggestions" raw (header row 1, one demographic)
#   - "Contents"    metadata (skipped)
# ------------------------------------------------------------------------------

write_fixture_workbook <- function() {
  path <- tempfile(fileext = ".xlsx")
  culture <- rbind(
    c("Please share your views on culture", NA, NA, NA, NA, NA),          # preamble (question text)
    c("ID", "Noteworthy", "Comment", "Overall Sentiment", "Service", "Price"),
    c("1", "Yes", "Great service", "1", "1", NA),
    c("2", NA, "Too expensive", "3", NA, "3"),
    c("3", NA, "Mixed bag", "2", "2", "11")                              # stray "11" in Price
  )
  suggestions <- rbind(
    c("Response ID", "Region", "Comment", "Noteworthy"),
    c("1", "North", "Please improve delivery", "x"),
    c("2", "South", "All good", NA)
  )
  contents <- rbind(c(NA, "All Comments", "Themed"), c("Culture", "3", "Y"))
  wb <- openxlsx::createWorkbook()
  for (nm in c("Culture", "Suggestions", "Contents")) openxlsx::addWorksheet(wb, nm)
  openxlsx::writeData(wb, "Culture", as.data.frame(culture), colNames = FALSE)
  openxlsx::writeData(wb, "Suggestions", as.data.frame(suggestions), colNames = FALSE)
  openxlsx::writeData(wb, "Contents", as.data.frame(contents), colNames = FALSE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

get_question <- function(res, code) {
  for (q in res$questions) if (identical(q$code, code)) return(q)
  NULL
}

# ==============================================================================
# HAPPY PATH. Reads a real .xlsx end to end
# ==============================================================================

test_that("qual_read_workbook reads themed + raw, skips Contents, through openxlsx", {
  path <- write_fixture_workbook()
  on.exit(unlink(path), add = TRUE)

  res <- qual_read_workbook(path)
  expect_equal(res$status, "PASS")
  expect_equal(length(res$questions), 2L)             # Culture + Suggestions
  expect_true(any(vapply(res$skipped, function(s) s$reason == "contents", logical(1))))

  culture <- get_question(res, "QUAL_CULTURE")
  expect_equal(culture$type, "themed")
  expect_equal(culture$header_row, 2L)                 # found below the preamble row
  expect_equal(culture$title, "Please share your views on culture")  # title from preamble
  expect_equal(vapply(culture$roles$themes, function(t) t$label, character(1)),
               c("Service", "Price"))
  expect_false(is.na(culture$roles$sentiment))
  expect_equal(culture$meta$n_records, 3L)
  expect_equal(culture$meta$dropped_codes, 1L)         # the rogue "11" survived round-trip + quarantine

  suggestions <- get_question(res, "QUAL_SUGGESTIONS")
  expect_equal(suggestions$type, "raw")
  expect_equal(vapply(suggestions$roles$demos, function(t) t$label, character(1)), "Region")
  expect_equal(suggestions$meta$n_records, 2L)
})

# ==============================================================================
# TRS REFUSALS. Every hard failure stops loudly with a typed code
# ==============================================================================

test_that("missing file raises IO_QUAL_FILE_MISSING", {
  err <- tryCatch(qual_read_workbook(file.path(tempdir(), "does-not-exist.xlsx")),
                  turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "IO_QUAL_FILE_MISSING")
})

test_that("a workbook with no question sheets raises DATA_QUAL_NO_QUESTIONS", {
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path), add = TRUE)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Contents")
  openxlsx::writeData(wb, "Contents",
                      as.data.frame(rbind(c("Question", "Base"), c("Q1", "100"))),
                      colNames = FALSE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  err <- tryCatch(qual_read_workbook(path), turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_QUAL_NO_QUESTIONS")
})


# ==============================================================================
# Production review 2026-08. I17/I18 integrity refusals at the I/O boundary
# ==============================================================================

write_one_sheet_workbook <- function(rows) {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Open")
  openxlsx::writeData(wb, "Open", as.data.frame(rows), colNames = FALSE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

test_that("a duplicated ResponseID in one sheet refuses (I17)", {
  path <- write_one_sheet_workbook(rbind(
    c("ID", "Noteworthy", "Comment"),
    c("7", NA, "First"),
    c("7", NA, "Second under the same ID")
  ))
  on.exit(unlink(path), add = TRUE)
  expect_error(qual_read_workbook(path), class = "turas_refusal")
})

test_that("a comment row with text but no ResponseID refuses (I17)", {
  path <- write_one_sheet_workbook(rbind(
    c("ID", "Noteworthy", "Comment"),
    c("1", NA, "Fine"),
    c(NA, "p", "A priority comment that would have vanished silently")
  ))
  on.exit(unlink(path), add = TRUE)
  expect_error(qual_read_workbook(path), class = "turas_refusal")
})

test_that("a hide-like marker that is not exactly hide/hidden refuses (I18)", {
  path <- write_one_sheet_workbook(rbind(
    c("ID", "Noteworthy", "Comment"),
    c("1", "hide!", "The analyst meant to withhold this")
  ))
  on.exit(unlink(path), add = TRUE)
  expect_error(qual_read_workbook(path), class = "turas_refusal")
})

test_that("an ambiguous verbatim column refuses naming the candidates (I17)", {
  path <- write_one_sheet_workbook(rbind(
    c("ID", "Noteworthy", "How was the programme for you?", "Analyst working notes"),
    c("1", NA, "The sessions were engaging and well paced overall",
      "Private long note that must never ship as a respondent quote anywhere"),
    c("2", NA, "Too much admin at the start of every module",
      "Second long private working note about this respondent's context")
  ))
  on.exit(unlink(path), add = TRUE)
  err <- tryCatch({ qual_read_workbook(path); NULL }, error = function(e) e)
  expect_false(is.null(err))
  expect_match(conditionMessage(err), "AMBIGUOUS|ambiguous")
})

test_that("unrecognised tier-1 markers and hide counts are reported, not refused (I18)", {
  path <- write_one_sheet_workbook(rbind(
    c("ID", "Noteworthy", "Comment"),
    c("1", "x", "Legacy mark - promoted to tier 1, reported"),
    c("2", "hide", "Withheld properly"),
    c("3", NA, "Plain")
  ))
  on.exit(unlink(path), add = TRUE)
  out <- capture.output(res <- qual_read_workbook(path))
  expect_equal(res$status, "PASS")
  expect_true(any(grepl("unrecognised noteworthy", out)))
  expect_true(any(grepl("hide-marked", out)))
})


test_that("ALL integrity problems across ALL sheets report in ONE refusal", {
  # Refusing at the first offending sheet made the operator fix one sheet per
  # re-run (CCPB 2026-08-05: Q08, then Q13, then Q25). One pass must name all.
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  for (nm in c("Q08Comment", "Q13Comment", "Q25Comment")) openxlsx::addWorksheet(wb, nm)
  openxlsx::writeData(wb, "Q08Comment", as.data.frame(rbind(
    c("ID", "Noteworthy", "Comment"),
    c("9", NA, "First"),
    c("9", NA, "Duplicate of nine")
  )), colNames = FALSE)
  openxlsx::writeData(wb, "Q13Comment", as.data.frame(rbind(
    c("ID", "Noteworthy", "Comment"),
    c("540", NA, "Fine"),
    c("607", "hide!", "Hide-like typo"),
    c(NA, "p", "Text with no ID")
  )), colNames = FALSE)
  openxlsx::writeData(wb, "Q25Comment", as.data.frame(rbind(
    c("ID", "Noteworthy", "Comment"),
    c("3", NA, "Fine"),
    c("3", NA, "Another duplicate")
  )), colNames = FALSE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  on.exit(unlink(path), add = TRUE)

  err <- tryCatch({ qual_read_workbook(path); NULL }, error = function(e) e)
  expect_false(is.null(err))
  msg <- conditionMessage(err)
  # every sheet and every issue type, in the one message
  expect_match(msg, "Q08Comment", fixed = TRUE)
  expect_match(msg, "Q13Comment", fixed = TRUE)
  expect_match(msg, "Q25Comment", fixed = TRUE)
  expect_match(msg, "duplicated ResponseID")
  expect_match(msg, "no ResponseID")
  expect_match(msg, "hide-LIKE", fixed = TRUE)
  expect_match(msg, "4 issue\\(s\\) across 3 sheet\\(s\\)")
})

# ==============================================================================
# EXTRACTS. Routed by sheet name, validated against the coded row
# ==============================================================================

# Fixture: one themed question plus an extracts sheet for it. The coded row for
# ID 1 is coded on two themes, which is the shape that produced the bug.
write_extracts_workbook <- function(sheets) {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  for (nm in names(sheets)) {
    openxlsx::addWorksheet(wb, nm)
    openxlsx::writeData(wb, nm, as.data.frame(sheets[[nm]]), colNames = FALSE)
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

coded_culture <- rbind(
  c("ID", "Noteworthy", "Comment", "Overall Sentiment", "Service", "Price"),
  c("1", NA, "a long comment about service and about price", "2", "2", "3"),
  c("2", NA, "only about service", "1", "1", NA)
)

test_that("an extracts sheet attaches its fragments and is never read as a question", {
  path <- write_extracts_workbook(list(
    Culture = coded_culture,
    `Culture Extracts` = rbind(
      c("ID", "Theme", "Extract", "Lead"),
      c("1", "Service", "the service half", "x"),
      c("1", "Price", "the price half", NA)
    )))
  on.exit(unlink(path), add = TRUE)
  res <- qual_read_workbook(path)

  # Routed away: one question, and the extracts sheet is not in the skipped log
  # either (it was handled, not ignored).
  expect_length(res$questions, 1L)
  expect_equal(res$questions[[1]]$sheet, "Culture")
  expect_false(any(vapply(res$skipped, function(s) grepl("Extracts", s$sheet), logical(1))))

  rec <- res$questions[[1]]$records[[1]]
  expect_equal(rec$extracts, list(Service = "the service half", Price = "the price half"))
  expect_equal(rec$extract_lead, "the service half")
  expect_true(rec$has_extracts)
  # The coding is untouched, so every base and distribution is unchanged.
  expect_equal(rec$themeVals, list(Service = 2L, Price = 3L))
  # A comment with no extract carries no extract fields at all.
  expect_null(res$questions[[1]]$records[[2]]$has_extracts)
})

test_that("several fragments of ONE comment do not trip the duplicated-ID refusal", {
  # The routing exists for this: an extracts sheet is ID-anchored, so the question
  # classifier would read it as a question and refuse three rows for ID 1 as
  # duplicated ResponseIDs before the extracts parser ever saw them.
  path <- write_extracts_workbook(list(
    Culture = coded_culture,
    `Culture Extracts` = rbind(
      c("ID", "Theme", "Extract"),
      c("1", "Service", "one"),
      c("1", "Price", "two"),
      c("1", "all", NA)
    )))
  on.exit(unlink(path), add = TRUE)
  res <- qual_read_workbook(path)
  expect_equal(res$status, "PASS")
  rec <- res$questions[[1]]$records[[1]]
  expect_equal(rec$extracts, list(Service = "one", Price = "two"))
  # The blank-text "all" row is skipped, so it claims nothing.
  expect_null(rec$extract_all)
})

test_that("an extracts sheet naming no question in the workbook refuses", {
  path <- write_extracts_workbook(list(
    Culture = coded_culture,
    `Values Extracts` = rbind(c("ID", "Theme", "Extract"), c("1", "Service", "orphan"))
  ))
  on.exit(unlink(path), add = TRUE)
  err <- tryCatch(qual_read_workbook(path), turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_match(paste(unlist(err), collapse = " "), "no question sheet named 'Values'")
})

test_that("a bare 'Extracts' sheet refuses and says what to rename it to", {
  path <- write_extracts_workbook(list(
    Culture = coded_culture,
    Extracts = rbind(c("ID", "Theme", "Extract"), c("1", "Service", "unattributable"))
  ))
  on.exit(unlink(path), add = TRUE)
  err <- tryCatch(qual_read_workbook(path), turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_match(paste(unlist(err), collapse = " "), "names no question sheet")
})

test_that("an extracts sheet missing the Extract column refuses, naming the column", {
  path <- write_extracts_workbook(list(
    Culture = coded_culture,
    `Culture Extracts` = rbind(c("ID", "Theme", "Quote"), c("1", "Service", "wrong header"))
  ))
  on.exit(unlink(path), add = TRUE)
  err <- tryCatch(qual_read_workbook(path), turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_match(paste(unlist(err), collapse = " "), "missing the Extract column")
})

test_that("an extracts tab created but not yet filled is reported, not refused", {
  path <- write_extracts_workbook(list(
    Culture = coded_culture,
    `Culture Extracts` = rbind(c(NA, NA, NA))
  ))
  on.exit(unlink(path), add = TRUE)
  out <- capture.output(res <- qual_read_workbook(path))
  expect_length(res$questions, 1L)
  expect_true(any(grepl("empty, no extracts read", out)))
})

test_that("EVERY extracts problem across the workbook reports in ONE refusal", {
  path <- write_extracts_workbook(list(
    Culture = coded_culture,
    `Culture Extracts` = rbind(
      c("ID", "Theme", "Extract"),
      c("99", "Service", "bad id"),
      c("2", "Price", "not coded on that row"),
      c("1", "Comfort", "not a theme column")
    )))
  on.exit(unlink(path), add = TRUE)
  err <- tryCatch(qual_read_workbook(path), turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
  msg <- paste(unlist(err), collapse = " ")
  expect_match(msg, "3 issue")
  expect_match(msg, "no comment with that ID")
  expect_match(msg, "not coded 'Price'")
  expect_match(msg, "not a theme column")
})

test_that("a workbook with no extracts sheet reads exactly as it did before", {
  path <- write_extracts_workbook(list(Culture = coded_culture))
  on.exit(unlink(path), add = TRUE)
  res <- qual_read_workbook(path)
  for (rec in res$questions[[1]]$records) {
    expect_null(rec$has_extracts)
    expect_null(rec$extracts)
    expect_null(rec$extract_general)
  }
})
