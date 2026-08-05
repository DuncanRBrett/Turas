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

test_that("qual_noteworthy_tier maps markers to tiers (0 other / 1 note / 2 must-read / 3 priority)", {
  expect_equal(qual_noteworthy_tier(""), 0L)
  expect_equal(qual_noteworthy_tier("x"), 1L)        # any non-blank -> noteworthy
  expect_equal(qual_noteworthy_tier("Yes"), 1L)
  expect_equal(qual_noteworthy_tier("y"), 1L)        # legacy binary mark still counts
  expect_equal(qual_noteworthy_tier("n"), 1L)        # explicit noteworthy code
  expect_equal(qual_noteworthy_tier("N"), 1L)
  expect_equal(qual_noteworthy_tier("Must read"), 2L)
  expect_equal(qual_noteworthy_tier("  CRITICAL "), 2L)   # case/space-insensitive
  expect_equal(qual_noteworthy_tier("m"), 2L)        # must-read code
  expect_equal(qual_noteworthy_tier("M"), 2L)
  expect_equal(qual_noteworthy_tier("p"), 3L)        # priority code (lead-with)
  expect_equal(qual_noteworthy_tier("P"), 3L)
  expect_equal(qual_noteworthy_tier(" Priority "), 3L)   # word alias, case/space-insensitive
  # A hide marker is a suppression, never noteworthy — tier 0, not tier 1.
  expect_equal(qual_noteworthy_tier("hide"), 0L)
  expect_equal(qual_noteworthy_tier("Hidden"), 0L)
  expect_equal(qual_noteworthy_tier(" HIDE "), 0L)
})

test_that("qual_verbatim_hidden detects hide/hidden markers, case- and space-insensitive", {
  expect_true(qual_verbatim_hidden("hide"))
  expect_true(qual_verbatim_hidden("Hidden"))
  expect_true(qual_verbatim_hidden("  HIDE  "))
  expect_false(qual_verbatim_hidden(""))              # blank is shown, not hidden
  expect_false(qual_verbatim_hidden("x"))             # a tier-1 mark is not a hide
  expect_false(qual_verbatim_hidden("p"))             # priority is not a hide
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
  expect_equal(r7$noteworthy_tier, 1L)                  # binary marker -> tier 1
  expect_equal(r7$themeVals[["Values"]], 2L)
  r8 <- find_record(q, "8")
  expect_false(r8$noteworthy)                           # blank marker
  expect_equal(r8$noteworthy_tier, 0L)
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


# ==============================================================================
# Production review 2026-08 — I17/I18/I19 hardening
# ==============================================================================

test_that("verbatim fallback refuses to guess between two prose columns (I17)", {
  amb_sheet <- make_sheet(
    c("ID", "Noteworthy", "What did you think of the programme?", "Analyst working notes"),
    c("1", "", "The sessions were engaging and well paced overall",
      "Check this one against the LMS export before publishing; wording may identify the campus"),
    c("2", "", "Too much admin at the start of every module",
      "Second long private note that must never ship as a respondent quote in any report")
  )
  q <- qual_classify_sheet(amb_sheet, "Open")
  expect_true(q$skip)
  expect_equal(q$reason, "verbatim_ambiguous")
  expect_gte(length(q$ambiguous_columns), 2)
})

test_that("a named Comment column beats the length fallback — notes column is a cut, not the verbatim", {
  named_sheet <- make_sheet(
    c("ID", "Noteworthy", "Comment", "Analyst working notes"),
    c("1", "", "Engaging sessions", "A much longer analyst-only note that would win on mean length"),
    c("2", "", "Too much admin", "Another long analyst-only working note about this respondent")
  )
  q <- qual_classify_sheet(named_sheet, "Open")
  expect_false(q$skip)
  expect_equal(q$records[[1]]$text, "Engaging sessions")
})

test_that("a single prose column still resolves via the fallback (SACS shape unchanged)", {
  q <- qual_classify_sheet(sacs_sheet, "Culture")
  expect_false(q$skip)
})

test_that("integrity: blank IDs on rows with text are collected (I17)", {
  s <- make_sheet(
    c("ID", "Noteworthy", "Comment"),
    c("1", "", "First comment"),
    c("",  "p", "Priority comment with no ID"),
    c("3", "", "Third comment")
  )
  q <- qual_classify_sheet(s, "Open")
  expect_false(q$skip)
  expect_equal(length(q$integrity$blank_id_rows), 1L)
})

test_that("integrity: duplicated IDs within one sheet are collected (I17)", {
  s <- make_sheet(
    c("ID", "Noteworthy", "Comment"),
    c("7", "", "First"),
    c("7", "", "Second under the same ID"),
    c("8", "", "Third")
  )
  q <- qual_classify_sheet(s, "Open")
  expect_equal(q$integrity$dup_ids, "7")
})

test_that("integrity: hide-like markers are flagged, exact hide counts as hidden (I18)", {
  s <- make_sheet(
    c("ID", "Noteworthy", "Comment"),
    c("1", "hide",          "Withheld properly"),
    c("2", "hide!",         "Meant to be withheld - the old reader made this MORE visible"),
    c("3", "hide this one", "Also meant to be withheld"),
    c("4", "x",             "Legacy tier-1 mark"),
    c("5", "p",             "Priority")
  )
  q <- qual_classify_sheet(s, "Open")
  expect_equal(q$integrity$n_hidden, 1L)
  expect_setequal(q$integrity$hide_like_markers, c("hide!", "hide this one"))
  expect_true("x" %in% names(q$integrity$unrecognised_markers))
  # recognised marks are not reported as unrecognised
  expect_false("p" %in% names(q$integrity$unrecognised_markers))
})

test_that("qual_hide_like_invalid: exact markers pass, hide-like typos flag", {
  expect_false(qual_hide_like_invalid("hide"))
  expect_false(qual_hide_like_invalid(" HIDDEN "))
  expect_true(qual_hide_like_invalid("hide!"))
  expect_true(qual_hide_like_invalid("hid"))
  expect_true(qual_hide_like_invalid("hide this one"))
  expect_false(qual_hide_like_invalid(""))
  expect_false(qual_hide_like_invalid("p"))
})

test_that("qual_id_norm expands scientific notation so the join key matches (I19)", {
  expect_equal(qual_id_norm("1e+05"), "100000")
  expect_equal(qual_id_norm("2.5e+05"), "250000")
  expect_equal(qual_id_norm("100000"), "100000")
  expect_equal(qual_id_norm(" R-42 "), "R-42")
  expect_equal(qual_id_norm("e5"), "e5")   # not a number - untouched
})
