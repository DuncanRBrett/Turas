# ==============================================================================
# TABS MODULE — QUALITATIVE WORKBOOK READER TESTS
# ==============================================================================
#
# Known-answer tests for the pure column-classification + normalisation logic in
# qual_workbook_reader.R. Fixtures are synthetic but encode the real quirks seen in
# the four coded workbooks (SACS / SACAP Student / CCPB / Helderberg) — see
# modules/tabs/docs/QUALITATIVE_TAB_BUILD_NOTES.md §A.
#
# Every expected value below is hand-verifiable from the fixture rows.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_workbook_reader.R")
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
  stop("Could not locate Turas root for sourcing qual_workbook_reader.R")
}

turas_root <- detect_turas_root()
source(file.path(turas_root, "modules/tabs/lib/qual_workbook_reader.R"))

# ------------------------------------------------------------------------------
# Fixture helper: build a sheet as a list of normalised character rows.
# Each "..." vector is one row; ragged rows are padded to the widest row.
# ------------------------------------------------------------------------------

make_sheet <- function(...) {
  raw <- list(...)
  width <- max(vapply(raw, length, integer(1)))
  lapply(raw, function(r) {
    cells <- qual_norm_cells(r)
    length(cells) <- width            # pad short rows with NA -> ""
    cells[is.na(cells)] <- ""
    cells
  })
}

find_record <- function(question, id) {
  for (rec in question$records) if (identical(rec$id, id)) return(rec)
  NULL
}

# ==============================================================================
# HELPERS — direct unit tests
# ==============================================================================

test_that("qual_norm_cells trims, stringifies numbers, and blanks NA", {
  expect_equal(qual_norm_cells(c("  hi ", 2L, NA, "")), c("hi", "2", "", ""))
})

test_that("qual_find_header_row anchors on the ID cell, not a fixed offset", {
  rows <- make_sheet(c("preamble"), c("", ""), c("Response ID", "Comment"), c("1", "hi"))
  expect_equal(qual_find_header_row(rows), 3L)
  expect_equal(qual_find_header_row(make_sheet(c("no", "id", "here"))), 0L)
})

test_that("qual_code_purity and qual_density ignore blanks correctly", {
  expect_equal(qual_code_purity(c("1", "", "2", "11")), 2 / 3)   # blanks excluded
  expect_equal(qual_density(c("1", "", "2", "")), 0.5)
})

# ==============================================================================
# FIXTURE A — SACS-like: themed, no demographics, floating header, stray code
# ==============================================================================

sacs_sheet <- make_sheet(
  c("", "", "", "", "", ""),                                              # r1 blank
  c("", "", "Total Mentions", "10", "6", "4"),                            # r2 summary (ignored)
  c("", "1", "Positive skew", "5", "3", "2"),                             # r3 legend (ignored)
  c("", "2", "Mixed sentiment", "2", "1", "1"),                          # r4 legend
  c("", "3", "Negative skew", "3", "2", "1"),                            # r5 legend
  c("ID", "Noteworthy", " Please share your views ",                     # r6 HEADER (note whitespace)
    " Overall Sentiment ", " Leadership & Management ", " Values "),
  c("6", "Yes", "Supportive but lacking structure", "2", "", "2"),        # r7
  c("8", "", "Can be worked on", "3", "3", ""),                           # r8
  c("9", "", "Culture is unique", "1", "", "11"),                         # r9 stray "11"
  c("13", "Yes", "Gossiping happens", "3", "", "3"),                      # r10
  c("15", "", "Neutral team player", "2", "2", "1")                       # r11
)

test_that("SACS-like: header detection, themed type, title from verbatim header", {
  q <- qual_classify_sheet(sacs_sheet, "Culture")
  expect_false(q$skip)
  expect_equal(q$header_row, 6L)
  expect_equal(q$type, "themed")
  expect_equal(q$title, "Please share your views")   # col-1 preamble blank -> verbatim header
  expect_equal(q$code, "QUAL_CULTURE")
})

test_that("SACS-like: roles — verbatim by length, sentiment by name+density, no demos", {
  q <- qual_classify_sheet(sacs_sheet, "Culture")
  expect_equal(q$roles$id, 1L)
  expect_equal(q$roles$noteworthy, 2L)
  expect_equal(q$roles$verbatim, 3L)
  expect_equal(q$roles$sentiment, 4L)
  expect_equal(length(q$roles$demos), 0L)
  expect_equal(vapply(q$roles$themes, function(t) t$label, character(1)),
               c("Leadership & Management", "Values"))   # headers trimmed
})

test_that("SACS-like: stray code quarantined, not coerced; records honest", {
  q <- qual_classify_sheet(sacs_sheet, "Culture")
  expect_equal(q$meta$n_records, 5L)
  expect_equal(q$meta$dropped_codes, 1L)               # the rogue "11"
  r9 <- find_record(q, "9")
  expect_equal(r9$sentiment, 1L)
  expect_length(r9$themeVals, 0L)                       # "11" dropped, not stored
  r7 <- find_record(q, "6")
  expect_true(r7$noteworthy)                            # "Yes" marker
  expect_equal(r7$themeVals[["Values"]], 2L)
  r8 <- find_record(q, "8")
  expect_false(r8$noteworthy)                           # blank marker
  expect_equal(r8$themeVals[["Leadership & Management"]], 3L)
})

# ==============================================================================
# FIXTURE B — SACAP Student NPS-like: demographics, "Theme"=sentiment drift, "x" marker
# ==============================================================================

student_sheet <- make_sheet(
  c("How likely to recommend?", "", "", "", "", "", ""),     # r1 rated-Q text
  c("Why did you give that score?", "", "", "", "", "", ""), # r2 open prompt
  c("", "", "", "", "", "", ""),                             # r3 blank
  c("Response ID", "Campus", "Course", "Comment",            # r4 HEADER
    "Noteworthy", "Theme", "Online"),                        #  "Theme" col holds sentiment
  c("12", "Johannesburg", "Diploma", "Overly expensive", "", "3", ""),
  c("13", "Online", "BAppSocSci", "Material is excellent", "x", "2", "1"),
  c("14", "Johannesburg", "Higher Cert", "Good lectures", "", "2", "")
)

test_that("Student-like: title is the open prompt; mislabelled 'Theme' read as sentiment", {
  q <- qual_classify_sheet(student_sheet, "NPS")
  expect_equal(q$title, "Why did you give that score?")   # nearest non-blank preamble line
  expect_equal(q$roles$verbatim, 4L)                       # "Comment" by name
  expect_equal(q$roles$noteworthy, 5L)
  expect_equal(q$roles$sentiment, 6L)                      # "Theme" -> sentiment (dense {1,2,3})
  expect_equal(vapply(q$roles$themes, function(t) t$label, character(1)), "Online")
  expect_equal(vapply(q$roles$demos, function(t) t$label, character(1)), c("Campus", "Course"))
  expect_equal(q$type, "themed")
})

test_that("Student-like: 'x' marker counts as noteworthy; demographics captured", {
  q <- qual_classify_sheet(student_sheet, "NPS")
  r13 <- find_record(q, "13")
  expect_true(r13$noteworthy)                              # "x"
  expect_equal(r13$sentiment, 2L)
  expect_equal(r13$themeVals[["Online"]], 1L)
  expect_equal(r13$demos[["Campus"]], "Online")
  expect_equal(q$meta$dropped_codes, 0L)
})

# ==============================================================================
# FIXTURE C — CCPB-themed-like: NO overall-sentiment column, themes after noteworthy
# ==============================================================================

ccpb_sheet <- make_sheet(
  c("How likely to recommend?", "", "", "", "", "", ""),
  c("What makes you recommend?", "", "", "", "", "", ""),
  c("", "", "", "", "", "", ""),
  c("Response ID", "Centre", "Channel", "Comment", "Noteworthy", "Gen pos", "Service Excellence"),
  c("29", "MNO", "12", "Good supplier", "", "", "1"),
  c("31", "MSO", "12", "Products popular", "", "1", ""),
  c("33", "MNO", "03", "Happy with delivery", "x", "", "1")
)

test_that("CCPB-like: no sentiment column; valence rides theme cells", {
  q <- qual_classify_sheet(ccpb_sheet, "NPS Promoter")
  expect_true(is.na(q$roles$sentiment))                   # nothing name-matches sentiment
  expect_equal(vapply(q$roles$themes, function(t) t$label, character(1)),
               c("Gen pos", "Service Excellence"))
  expect_equal(vapply(q$roles$demos, function(t) t$label, character(1)), c("Centre", "Channel"))
  expect_equal(q$title, "What makes you recommend?")
  expect_equal(q$type, "themed")
  r33 <- find_record(q, "33")
  expect_true(r33$noteworthy)
  expect_equal(r33$themeVals[["Service Excellence"]], 1L)
  expect_true(is.na(r33$sentiment))
})

# ==============================================================================
# FIXTURE D — Helderberg-raw-like: no Noteworthy column, "-" missing, numeric Rating
# ==============================================================================

helderberg_sheet <- make_sheet(
  c("Accounts query question?", "", "", "", ""),
  c("Response ID", "Segment", "NPS category", "Rating", "Comment"),
  c("24", "Pragmatic Positives", "Promoter", "0", "Seeking more info"),
  c("19", "-", "Detractor", "10", "Expensive levy"),       # "-" missing demographic
  c("35", "Proud Advocates", "Promoter", "4", "Window replacement")
)

test_that("Helderberg-like: all-raw type, absent noteworthy, '-' -> NA, numeric Rating", {
  q <- qual_classify_sheet(helderberg_sheet, "Accounts")
  expect_equal(q$type, "raw")                              # no theme columns
  expect_equal(length(q$roles$themes), 0L)
  expect_true(is.na(q$roles$noteworthy))                   # no Noteworthy column at all
  expect_equal(q$roles$rating, 4L)                         # numeric Rating
  expect_equal(q$roles$verbatim, 5L)
  expect_equal(vapply(q$roles$demos, function(t) t$label, character(1)),
               c("Segment", "NPS category"))
  expect_equal(q$title, "Accounts query question?")
  r19 <- find_record(q, "19")
  expect_true(is.na(r19$demos[["Segment"]]))               # "-" -> NA
  expect_equal(r19$demos[["NPS category"]], "Detractor")
  expect_equal(r19$rating, 10)
  expect_false(r19$noteworthy)                             # no marker column -> always FALSE
})

# ==============================================================================
# SKIP MARKERS — metadata sheets and headerless sheets are skipped, never crash
# ==============================================================================

test_that("Contents and headerless sheets are skipped with a typed reason", {
  contents <- qual_classify_sheet(make_sheet(c("", "All Comments", "Themed")), "Contents")
  expect_true(contents$skip)
  expect_equal(contents$reason, "contents")

  headerless <- qual_classify_sheet(make_sheet(c("just", "some", "text"), c("a", "b", "c")), "Stray")
  expect_true(headerless$skip)
  expect_equal(headerless$reason, "no_header")
})

# ==============================================================================
# REPEATED HEADER — some sheets (CCPB "Fountains") stack sub-tables; a repeated
# header row inside the data must not be read as a respondent.
# ==============================================================================

test_that("a repeated header row inside the data is skipped, not read as a respondent", {
  stacked <- make_sheet(
    c("Response ID", "Region", "Comment", "Noteworthy"),
    c("1", "North", "first block", ""),
    c("Response ID", "Region", "Comment", "Noteworthy"),    # repeated header (stacked sub-table)
    c("2", "South", "second block", "x")
  )
  q <- qual_classify_sheet(stacked, "Fountains")
  expect_equal(q$meta$n_records, 2L)                         # only the two real respondents
  expect_equal(vapply(q$records, function(r) r$id, character(1)), c("1", "2"))
  expect_false(any(vapply(q$records,                          # no leaked header label as a value
                          function(r) identical(r$demos[["Region"]], "Region"), logical(1))))
})
