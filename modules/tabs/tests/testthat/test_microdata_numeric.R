# ==============================================================================
# TABS MODULE - NUMERIC QUESTIONS IN THE MICRODATA ISLAND (2026-08)
# ==============================================================================
#
# A numeric question's rows are RANGES ("R100 - R249") and its stored values are
# NUMBERS, so the island's value-to-row lookup matched nothing: every respondent
# landed on NA. Under an audience filter the whole distribution then vanished —
# five bins reading 0% on a base of 0, with a live mean still moving above them.
# Found on the Electrum VAS report, 2026-08-14, by driving the real report.
#
# Binned numerics now carry their BIN's row index; unbinned ones carry the
# answered-but-unshown sentinel so at least their base is right.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_microdata_numeric.R")
# ==============================================================================

library(testthat)

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
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/report_shared.R"))
source(file.path(turas_root, "modules/tabs/lib/score_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_layer_writer.R"))
source(file.path(turas_root, "modules/tabs/lib/microdata_writer.R"))
source(file.path(turas_root, "modules/tabs/lib/numeric_processor.R"))

# ------------------------------------------------------------------------------
# Two spend bands and one unbinned count, over six respondents.
#   SPEND: 50, 150, 400, NA, 99.99, 1e6   -> Under R100 / R100+ / (unbinned)
# The last value sits above every band on purpose: an out-of-range value must
# land nowhere rather than in the nearest bin.
# ------------------------------------------------------------------------------
mn_structure <- function(top_max = 999) {
  list(
    questions = data.frame(
      QuestionCode = c("SPEND", "COUNT"),
      QuestionText = c("Monthly spend", "Times a month"),
      Variable_Type = c("Numeric", "Numeric"),
      Columns = c(1, 1), stringsAsFactors = FALSE),
    options = data.frame(
      QuestionCode = c("SPEND", "SPEND"),
      OptionText = c("Under R100", "R100+"),
      DisplayText = c("Under R100", "R100+"),
      DisplayOrder = c(1, 2),
      Min = c(0, 100), Max = c(99.99, top_max),
      stringsAsFactors = FALSE))
}

mn_data <- function() {
  data.frame(SPEND = c(50, 150, 400, NA, 99.99, 1e6),
             COUNT = c(1, 2, NA, 4, 5, 6),
             G = c("M", "M", "F", "F", "M", "F"),
             stringsAsFactors = FALSE)
}

# A data-layer question shaped like the numeric processor's output: the bins as
# category rows, then the summary rows.
mn_dl_q <- function(code, labels) {
  rows <- lapply(labels, function(l) list(kind = "category", label = l))
  rows <- c(rows, list(list(kind = "mean", label = "Mean", mstat = "mean")))
  list(code = code, type = "numeric", rows = rows)
}

# ==============================================================================
# BINNED NUMERICS
# ==============================================================================

test_that("a binned numeric carries its bin's row index, not NA", {
  answers <- micro_answers_for_question(
    mn_dl_q("SPEND", c("Under R100", "R100+")), mn_data(), mn_structure(), 6)

  # 50 -> bin 0, 150 -> bin 1, 400 -> bin 1, NA -> NA, 99.99 -> bin 0
  expect_equal(as.integer(answers)[1:5], c(0L, 1L, 1L, NA_integer_, 0L))
})

test_that("a value above every band lands nowhere, rather than in the last bin", {
  answers <- micro_answers_for_question(
    mn_dl_q("SPEND", c("Under R100", "R100+")), mn_data(), mn_structure(), 6)

  # 1e6 is outside the R100-999 band. Putting it in would overstate that bin
  # under a filter while the published table (same binner) left it out.
  expect_true(is.na(as.integer(answers)[6]))
})

test_that("an open-ended top band takes the big value in", {
  answers <- micro_answers_for_question(
    mn_dl_q("SPEND", c("Under R100", "R100+")), mn_data(),
    mn_structure(top_max = 1e9), 6)

  expect_equal(as.integer(answers)[6], 1L)
})

test_that("the island bins with the engine's own binner, so the two agree", {
  struct <- mn_structure(top_max = 1e9)
  bins <- struct$options[struct$options$QuestionCode == "SPEND", ]
  published <- categorize_numeric_bins(mn_data()$SPEND, bins)

  answers <- as.integer(micro_answers_for_question(
    mn_dl_q("SPEND", c("Under R100", "R100+")), mn_data(), struct, 6))
  labels <- c("Under R100", "R100+")
  from_island <- ifelse(is.na(answers), NA_character_, labels[answers + 1L])

  expect_equal(from_island, as.character(published))
})

test_that("a bin the table does not publish maps to nothing, not to a neighbour", {
  # the structure declares two bands; the question publishes only the first
  answers <- micro_answers_for_question(
    mn_dl_q("SPEND", "Under R100"), mn_data(), mn_structure(), 6)
  a <- as.integer(answers)

  expect_equal(a[1], 0L)          # 50 is in the published band
  expect_true(is.na(a[2]))        # 150 is in a band with no row of its own
})

# ==============================================================================
# UNBINNED NUMERICS — no rows to land on, but a base to get right
# ==============================================================================

test_that("an unbinned numeric records who answered, so the base is not zero", {
  answers <- micro_answers_for_question(
    list(code = "COUNT", type = "numeric",
         rows = list(list(kind = "mean", label = "Mean"))),
    mn_data(), mn_structure(), 6)
  a <- as.integer(answers)

  # -2 is "answered, category not displayed": counted in the base, in no row
  expect_equal(a, c(-2L, -2L, NA_integer_, -2L, -2L, -2L))
})

test_that("a numeric column absent from the data carries no answers at all", {
  answers <- micro_answers_for_question(
    list(code = "MISSING", type = "numeric",
         rows = list(list(kind = "mean", label = "Mean"))),
    mn_data(), mn_structure(), 6)

  expect_true(all(is.na(as.integer(answers))))
})

test_that("non-numeric questions keep the label-matching path", {
  struct <- mn_structure()
  struct$questions <- rbind(struct$questions, data.frame(
    QuestionCode = "G", QuestionText = "Gender", Variable_Type = "Single_Choice",
    Columns = 1, stringsAsFactors = FALSE))
  struct$options <- rbind(struct$options, data.frame(
    QuestionCode = c("G", "G"), OptionText = c("M", "F"),
    DisplayText = c("Male", "Female"), DisplayOrder = c(1, 2),
    Min = c(NA, NA), Max = c(NA, NA), stringsAsFactors = FALSE))

  answers <- micro_answers_for_question(
    list(code = "G", type = "single",
         rows = list(list(kind = "category", label = "Male"),
                     list(kind = "category", label = "Female"))),
    mn_data(), struct, 6)

  expect_equal(as.integer(answers), c(0L, 0L, 1L, 1L, 0L, 1L))
})
