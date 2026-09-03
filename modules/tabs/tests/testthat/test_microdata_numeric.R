# ==============================================================================
# TABS MODULE - NUMERIC QUESTIONS IN THE MICRODATA ISLAND (2026-08)
# ==============================================================================
#
# A numeric question's rows are RANGES ("R100 - R249") and its stored values are
# NUMBERS, so the island's value-to-row lookup matched nothing: every respondent
# landed on NA. Under an audience filter the whole distribution then vanished,
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
source(file.path(turas_root, "modules/tabs/lib/allocation_processor.R"))

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
# UNBINNED NUMERICS. No rows to land on, but a base to get right
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

# ==============================================================================
# ALLOCATION QUESTIONS
# ==============================================================================
# An Allocation (constant-sum) question is {code}_1..{code}_N of numbers with no
# bare column and no category rows. There is nowhere in this island to put N
# numbers per respondent, so it carries none - and the entry must still be a
# full-length column of NA. VAS 2026: without it the single-response path
# indexed a column that does not exist, returned a zero-length vector, and the
# whole report refused to open with "DATA_MICRO_Q microdata missing/short".

alloc_structure <- function() {
  list(
    questions = data.frame(
      QuestionCode = c("WALLETLOC", "SPEND"),
      Variable_Type = c("Allocation", "Numeric"),
      Columns = c(3, 1), stringsAsFactors = FALSE),
    options = data.frame(
      QuestionCode = rep("WALLETLOC", 3),
      OptionText = c("Bank", "Retailer", "Other"),
      DisplayText = c("Bank", "Retailer", "Other"),
      DisplayOrder = 1:3, Min = NA_real_, Max = NA_real_,
      stringsAsFactors = FALSE))
}

# Respondent 3 allocated zero to every item: zero is an ANSWER, so they are in
# the base. Respondent 5 has no slot filled at all and is not.
alloc_data <- function() {
  data.frame(WALLETLOC_1 = c(50, 30, 0, 10, NA),
             WALLETLOC_2 = c(30, 40, 0, 20, NA),
             WALLETLOC_3 = c(20, 30, 0, 70, NA),
             SPEND = c(1, 2, 3, 4, 5), stringsAsFactors = FALSE)
}

# Two shapes, because the row CLASS is what decides which path the island
# takes. "mean" is what the data layer builds now that the processor tags its
# rows RowSource = "summary". "category" is what it built before that - and it
# is the shape that broke: a value-index map exists, so the single-response
# path indexes the question's bare column, which an allocation question has
# not got. The guard has to hold for both.
alloc_dl_q <- function(kind = "mean") {
  list(code = "WALLETLOC", type = "single",
       rows = lapply(c("Bank", "Retailer", "Other"), function(l) {
         if (identical(kind, "mean")) list(kind = "mean", label = l, mstat = "mean")
         else list(kind = "category", label = l)
       }))
}

# This test used to assert a full column of NA for BOTH shapes. The "mean"
# shape now marks the base instead (the series carries the values), which is
# what makes an Allocation recomputable under a filter. The "category" shape is
# the pre-fce6cbc1 one that broke the report and still has to hold.
test_that("an allocation question marks who is in the base", {
  answers <- micro_answers_for_question(alloc_dl_q("mean"), alloc_data(),
                                        alloc_structure(), 5)
  expect_equal(length(answers), 5L)
  # -2 for anyone with at least one non-NA numeric slot, which is
  # calculate_allocation_base() restated per respondent. Zero counts.
  expect_equal(as.integer(answers), c(-2L, -2L, -2L, -2L, NA_integer_))
})

test_that("the old category shape still carries a full-length column of NA", {
  # No mean rows, so no row can be paired with a column: the series refuses and
  # the answers column stays all-NA rather than claiming a base.
  answers <- micro_answers_for_question(alloc_dl_q("category"), alloc_data(),
                                        alloc_structure(), 5)
  expect_equal(length(answers), 5L)
  expect_true(all(is.na(as.integer(answers))))
})

# ------------------------------------------------------------------------------
# TR.MICRO.series: one value series per allocation ITEM
# ------------------------------------------------------------------------------
# scores[code] is one number per respondent and six consumers assume exactly
# that, so an Allocation's k series go under a new key instead, keyed by the
# item's zero-based position in the question's data-layer rows[].

test_that("a series carries each item's raw slot values, keyed by row index", {
  series <- micro_series_for_question(alloc_dl_q(), alloc_data(),
                                      alloc_structure(), 5)
  expect_equal(sort(names(series)), c("0", "1", "2"))
  # Row 0 is option 1, therefore column WALLETLOC_1. Zero is kept as a value;
  # the unfilled respondent is NA.
  expect_equal(as.numeric(series[["0"]]), c(50, 30, 0, 10, NA))
  expect_equal(as.numeric(series[["1"]]), c(30, 40, 0, 20, NA))
  expect_equal(as.numeric(series[["2"]]), c(20, 30, 0, 70, NA))
})

test_that("every series is length n, and a blank slot is NA not dropped", {
  for (n in c(1L, 5L, 25L)) {
    series <- micro_series_for_question(alloc_dl_q(), alloc_data(),
                                        alloc_structure(), n)
    for (k in names(series)) {
      expect_equal(length(series[[k]]), n, info = paste("n =", n, "row", k))
    }
  }
  # Non-numeric text in a slot is NA, exactly as collect_allocation_values()
  # treats it, not a zero that would drag the recomputed mean down.
  d <- alloc_data()
  d$WALLETLOC_2[1] <- "n/a"
  series <- micro_series_for_question(alloc_dl_q(), d, alloc_structure(), 5)
  expect_true(is.na(as.numeric(series[["1"]])[1]))
})

test_that("a non-allocation question gets no series at all", {
  dl_q <- list(code = "SPEND", type = "numeric",
               rows = list(list(kind = "mean", label = "Mean", mstat = "mean")))
  expect_null(micro_series_for_question(dl_q, alloc_data(), alloc_structure(), 5))
})

test_that("duplicate option labels refuse the series out loud", {
  st <- alloc_structure()
  st$options$OptionText <- c("Bank", "Other", "Other")
  st$options$DisplayText <- c("Bank", "Other", "Other")
  # The data layer collapses two same-labelled rows into one (pair_ids), so no
  # row-to-column pairing is safe and the whole question refuses.
  expect_output(
    series <- micro_series_for_question(alloc_dl_q(), alloc_data(), st, 5),
    "Other")
  expect_null(series)
  # ... and with no series there are no base markers either.
  expect_output(
    answers <- micro_answers_for_question(alloc_dl_q(), alloc_data(), st, 5))
  expect_true(all(is.na(as.integer(answers))))
})

test_that("a row out of option order refuses rather than shifting a series", {
  # Retailer and Other swapped in the published rows. Pairing row j with option
  # j would hand every Retailer cell the Other column's numbers.
  dl_q <- alloc_dl_q()
  dl_q$rows <- dl_q$rows[c(1, 3, 2)]
  expect_output(
    series <- micro_series_for_question(dl_q, alloc_data(), alloc_structure(), 5),
    "not in option order")
  expect_null(series)
})

test_that("a missing slot column refuses rather than inventing a series", {
  d <- alloc_data()
  d$WALLETLOC_3 <- NULL
  expect_output(
    series <- micro_series_for_question(alloc_dl_q(), d, alloc_structure(), 5),
    "WALLETLOC_3")
  expect_null(series)
})

test_that("a mean-row count that disagrees with Columns refuses", {
  dl_q <- alloc_dl_q()
  dl_q$rows <- dl_q$rows[1:2]     # data layer dropped a row
  expect_output(
    series <- micro_series_for_question(dl_q, alloc_data(), alloc_structure(), 5),
    "declares 3 columns")
  expect_null(series)
})

test_that("the island carries series for an allocation and omits the key without one", {
  banner <- list(columns = "Total", internal_keys = "TOTAL::Total",
                 banner_info = list())
  cfg <- list(apply_weighting = FALSE)
  dl_alloc <- list(questions = list(alloc_dl_q()))
  micro <- build_microdata(dl_alloc, alloc_data(), alloc_structure(), banner, cfg)
  expect_true(!is.null(micro$series))
  expect_equal(sort(names(micro$series[["WALLETLOC"]])), c("0", "1", "2"))
  # scores stays flat: the allocation contributes nothing to it.
  expect_null(micro$scores[["WALLETLOC"]])

  # A report with no allocation question is byte-identical to before: no key.
  dl_num <- list(questions = list(
    list(code = "SPEND", type = "numeric",
         rows = list(list(kind = "mean", label = "Mean", mstat = "mean")))))
  micro2 <- build_microdata(dl_num, alloc_data(), alloc_structure(), banner, cfg)
  expect_null(micro2$series)
})

test_that("serialize_microdata renders a series as a length-n array at n = 1", {
  banner <- list(columns = "Total", internal_keys = "TOTAL::Total",
                 banner_info = list())
  cfg <- list(apply_weighting = FALSE)
  dl_alloc <- list(questions = list(alloc_dl_q()))
  micro <- build_microdata(dl_alloc, alloc_data()[1, , drop = FALSE],
                           alloc_structure(), banner, cfg)
  json <- serialize_microdata(micro)
  # A one-respondent series must stay an ARRAY, never unbox to a bare number:
  # the reader indexes it by respondent row.
  expect_true(grepl('"series"', json, fixed = TRUE))
  expect_true(grepl('"0":[50]', json, fixed = TRUE))
})

test_that("the island entry is never zero-length, whatever the row count", {
  for (n in c(1L, 4L, 25L)) {
    answers <- micro_answers_for_question(alloc_dl_q(), alloc_data(),
                                          alloc_structure(), n)
    expect_equal(length(answers), n, info = paste("n =", n))
  }
})
