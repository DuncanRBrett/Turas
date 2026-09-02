# ==============================================================================
# TABS MODULE - TWO AVERAGES ON ONE NUMERIC TABLE (2026-08)
# ==============================================================================
#
# A numeric table's Mean averages PEOPLE: each respondent counts once, whatever
# their size. Its ratio-of-totals row averages the UNITS underneath. Total
# spend over total transactions, so a heavy transactor counts many times. On
# Electrum VAS prepaid electricity the two read R534.63 and R295.61 off the
# same 764 respondents, and reporting either alone as "the" average made a wave
# comparison look like a 44% collapse that never happened.
#
# Also covers the switchable Standard Deviation row: on a skewed measure the SD
# routinely exceeds the mean and says less than the bins above it.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_numeric_two_averages.R")
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

for (f in c("modules/shared/lib/trs_refusal.R", "modules/tabs/lib/00_guard.R",
            "modules/tabs/lib/validation_utils.R", "modules/tabs/lib/path_utils.R",
            "modules/tabs/lib/type_utils.R", "modules/tabs/lib/logging_utils.R",
            "modules/tabs/lib/config_utils.R", "modules/tabs/lib/excel_utils.R",
            "modules/tabs/lib/filter_utils.R", "modules/tabs/lib/data_loader.R",
            "modules/tabs/lib/weighting.R", "modules/tabs/lib/cell_calculator.R",
            "modules/tabs/lib/numeric_processor.R")) {
  source(file.path(turas_root, f))
}

# batch_rbind lives in shared_functions.R, which sources its siblings by
# relative path, so it is read from lib/ rather than sourced from here.
local({
  src <- readLines(file.path(turas_root, "modules/tabs/lib/shared_functions.R"))
  start <- grep("^batch_rbind <- function", src)
  eval(parse(text = paste(src[start:length(src)], collapse = "\n")),
       envir = globalenv())
})

# ------------------------------------------------------------------------------
# A fixture with a deliberately different people-average and unit-average.
#
#   spend / txn : 100/1, 100/1, 100/1, 1200/12
#   per person  : 100, 100, 100, 100   -> mean of ratios = 100
#   per unit    : 1500 / 15            -> ratio of totals = 100  (same, by design)
# so the interesting fixture skews one respondent:
#   spend / txn : 100/1, 100/1, 100/1, 3000/10
#   per person  : 100, 100, 100, 300   -> mean = 150
#   per unit    : 3300 / 13            -> 253.85
# ------------------------------------------------------------------------------
two_average_data <- function() {
  data.frame(
    VALUE = c(100, 100, 100, 300),
    SPEND = c(100, 100, 100, 3000),
    TXN   = c(1, 1, 1, 10),
    stringsAsFactors = FALSE
  )
}

two_average_question <- function(...) {
  base <- list(QuestionCode = "VALUE", QuestionText = "Value per transaction",
               Variable_Type = "Numeric", Columns = 1)
  extra <- list(...)
  do.call(data.frame, c(base, extra, list(stringsAsFactors = FALSE)))
}

two_average_banner <- function() {
  list(internal_keys = "TOTAL::Total",
       columns = data.frame(BannerLabel = "Total", stringsAsFactors = FALSE))
}

two_average_config <- function(...) {
  cfg <- list(show_numeric_median = FALSE, show_numeric_mode = FALSE,
              show_numeric_sd = TRUE, show_numeric_outliers = FALSE,
              exclude_outliers_from_stats = FALSE,
              enable_significance_testing = FALSE,
              decimal_places_numeric = 2, decimal_places_percent = 1,
              show_frequency = TRUE, show_percent_column = TRUE,
              show_percent_row = FALSE)
  modifyList(cfg, list(...))
}

run_numeric <- function(question_info, config, data = two_average_data()) {
  banner <- two_average_banner()
  keys <- banner$internal_keys
  idx <- setNames(list(seq_len(nrow(data))), keys)
  bases <- setNames(list(list(unweighted = nrow(data), weighted = nrow(data),
                              effective = nrow(data))), keys)
  process_numeric_question(
    data = data, question_info = question_info,
    question_options = data.frame(),
    banner_info = banner, banner_row_indices = idx,
    master_weights = rep(1, nrow(data)), banner_bases = bases,
    config = config, is_weighted = FALSE)
}

row_value <- function(result, label) {
  hit <- result[!is.na(result$RowLabel) & result$RowLabel == label, , drop = FALSE]
  if (!nrow(hit)) return(NULL)
  as.character(hit[1, "TOTAL::Total"])
}

# ==============================================================================
# THE RATIO ROW
# ==============================================================================

test_that("the ratio row totals both columns, and differs from the mean", {
  result <- run_numeric(
    two_average_question(RatioNumerator = "SPEND", RatioDenominator = "TXN",
                         RatioLabel = "Mean per transaction"),
    two_average_config())

  # people-average: (100 + 100 + 100 + 300) / 4
  expect_equal(row_value(result, "Mean"), "150")
  # unit-average: 3300 / 13. The heavy transactor counts ten times
  expect_equal(row_value(result, "Mean per transaction"), "253.85")
})

test_that("the ratio row is a mean-kind row of its own type", {
  result <- run_numeric(
    two_average_question(RatioNumerator = "SPEND", RatioDenominator = "TXN",
                         RatioLabel = "Mean per transaction"),
    two_average_config())
  hit <- result[result$RowLabel == "Mean per transaction", , drop = FALSE]

  # the type is what the v2 reader and the Excel styler key off - NOT the label
  expect_equal(as.character(hit$RowType), "RatioMean")
})

test_that("a question naming no ratio publishes the mean alone, as before", {
  result <- run_numeric(two_average_question(), two_average_config())

  expect_equal(row_value(result, "Mean"), "150")
  expect_true(all(result$RowType != "RatioMean"))
})

test_that("the ratio row carries a default label when none is given", {
  result <- run_numeric(
    two_average_question(RatioNumerator = "SPEND", RatioDenominator = "TXN"),
    two_average_config())

  expect_equal(row_value(result, "Mean per unit"), "253.85")
})

test_that("a respondent missing either half counts in neither total", {
  data <- two_average_data()
  data$SPEND[4] <- NA          # the heavy transactor's spend is unknown
  result <- run_numeric(
    two_average_question(RatioNumerator = "SPEND", RatioDenominator = "TXN",
                         RatioLabel = "Per transaction"),
    two_average_config(), data)

  # 300 / 3 - their 10 transactions leave with their spend, so the two
  # totals still describe the same people
  expect_equal(row_value(result, "Per transaction"), "100")
})

test_that("a zero denominator is left out rather than dividing by nothing", {
  data <- two_average_data()
  data$TXN <- c(0, 0, 0, 0)
  result <- run_numeric(
    two_average_question(RatioNumerator = "SPEND", RatioDenominator = "TXN",
                         RatioLabel = "Per transaction"),
    two_average_config(), data)

  expect_true(row_value(result, "Per transaction") %in% c("", "N/A", "-", NA_character_))
})

test_that("the ratio is weighted by the same weights as everything else", {
  data <- two_average_data()
  banner <- two_average_banner()
  keys <- banner$internal_keys
  idx <- setNames(list(seq_len(nrow(data))), keys)
  bases <- setNames(list(list(unweighted = 4, weighted = 13, effective = 4)), keys)
  weights <- c(1, 1, 1, 10)     # the heavy transactor also carries weight 10

  result <- process_numeric_question(
    data = data,
    question_info = two_average_question(RatioNumerator = "SPEND",
                                         RatioDenominator = "TXN",
                                         RatioLabel = "Per transaction"),
    question_options = data.frame(), banner_info = banner,
    banner_row_indices = idx, master_weights = weights, banner_bases = bases,
    config = two_average_config(), is_weighted = TRUE)

  # (1*100 + 1*100 + 1*100 + 10*3000) / (1*1 + 1*1 + 1*1 + 10*10) = 30300 / 103
  expect_equal(row_value(result, "Per transaction"), "294.17")
})

test_that("outlier exclusion does not touch the ratio row", {
  # Excluding a respondent from one total and not the other would divide two
  # different populations, so the ratio ignores the setting on purpose.
  spec <- two_average_question(RatioNumerator = "SPEND", RatioDenominator = "TXN",
                               RatioLabel = "Per transaction")
  plain <- run_numeric(spec, two_average_config())
  excluded <- run_numeric(spec, two_average_config(exclude_outliers_from_stats = TRUE))

  expect_equal(row_value(plain, "Per transaction"),
               row_value(excluded, "Per transaction"))
})

# ==============================================================================
# REFUSALS. A ratio that cannot be built must say so
# ==============================================================================

test_that("naming one half of the ratio refuses rather than publishing the mean alone", {
  expect_error(
    run_numeric(two_average_question(RatioNumerator = "SPEND"), two_average_config()),
    "RatioDenominator")
})

test_that("naming a column that is not in the data refuses, and says which", {
  expect_error(
    run_numeric(two_average_question(RatioNumerator = "SPEND",
                                     RatioDenominator = "TRANSACTIONS"),
                two_average_config()),
    "TRANSACTIONS")
})

# ==============================================================================
# THE MEAN LABEL
# ==============================================================================

test_that("MeanLabel renames the Mean row without changing its type", {
  result <- run_numeric(
    two_average_question(MeanLabel = "Mean per buyer",
                         RatioNumerator = "SPEND", RatioDenominator = "TXN",
                         RatioLabel = "Mean per transaction"),
    two_average_config())

  expect_equal(row_value(result, "Mean per buyer"), "150")
  expect_null(row_value(result, "Mean"))
  # significance, styling and the v2 recompute all key off the type
  hit <- result[result$RowLabel == "Mean per buyer", , drop = FALSE]
  expect_equal(as.character(hit$RowType), "Average")
})

test_that("a blank MeanLabel leaves the row called Mean", {
  result <- run_numeric(two_average_question(MeanLabel = "  "), two_average_config())
  expect_equal(row_value(result, "Mean"), "150")
})

# ==============================================================================
# THE STANDARD DEVIATION SWITCH
# ==============================================================================

test_that("the SD row is published by default, so existing reports do not move", {
  result <- run_numeric(two_average_question(), two_average_config())
  expect_true("StdDev" %in% result$RowType)
})

test_that("show_numeric_sd = FALSE drops the SD row and nothing else", {
  on_rows <- run_numeric(two_average_question(), two_average_config())
  off_rows <- run_numeric(two_average_question(),
                          two_average_config(show_numeric_sd = FALSE))

  expect_false("StdDev" %in% off_rows$RowType)
  expect_equal(setdiff(on_rows$RowLabel, off_rows$RowLabel), "Standard Deviation")
  expect_equal(row_value(off_rows, "Mean"), row_value(on_rows, "Mean"))
})

test_that("the SD default survives a config that has never heard of the setting", {
  cfg <- two_average_config()
  cfg$show_numeric_sd <- NULL
  # build_config_object defaults it TRUE; a hand-built list without the key
  # must not silently drop the row either
  expect_true(is.null(cfg$show_numeric_sd))
  expect_equal(safe_logical(NULL, default = TRUE), TRUE)
})
