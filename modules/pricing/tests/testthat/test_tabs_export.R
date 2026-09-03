# ==============================================================================
# TURAS PRICING MODULE - TABS EXPORT (Session B, B3)
# ==============================================================================
# The Gabor-Granger acceptance grid leaves the module as a respondent-level
# Multi_Mention question so tabs can break it by any banner. The load-bearing
# properties are the id gate (a row-order join would hand tabs the wrong
# respondent's answers), the cell contract (tabs matches cells against
# OptionText, so 0/1 flags would report zero at every price) and the base
# disclosure.
#
# Every test in this file fails on main at 34078b33: 15_tabs_export.R does not
# exist there, and Generate_Tabs_Export = Y refused by name.
# ==============================================================================

skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

export_data <- function(n = 12, id = TRUE) {
  set.seed(11)
  d <- data.frame(
    RespID = sprintf("R%03d", seq_len(n)),
    Weight = rep(1, n),
    P60 = c(rep(1, 10), 0, 0),
    P80 = c(rep(1, 8), rep(0, 4)),
    P100 = c(rep(1, 4), rep(0, 8)),
    Cheap = seq(40, 62, length.out = n),
    Expensive = seq(90, 134, length.out = n),
    stringsAsFactors = FALSE
  )
  if (!id) d$RespID <- NULL
  d
}

export_gg <- function(data, imputation = "none") {
  prices <- c(60, 80, 100)
  cols <- c("P60", "P80", "P100")
  long <- do.call(rbind, lapply(seq_along(prices), function(i) {
    data.frame(respondent_id = data$RespID, price = prices[i],
               response = as.numeric(data[[cols[i]]]), weight = 1,
               stringsAsFactors = FALSE)
  }))
  list(
    gg_data = long,
    demand_curve = data.frame(price = prices, n_respondents = rep(nrow(data), 3),
                              purchase_intent = c(10, 8, 4) / nrow(data),
                              stringsAsFactors = FALSE),
    diagnostics = list(n_respondents = nrow(data), response_coding = "binary, 1 = would buy, 0 = would not",
                       imputation = imputation, smoothing = "none")
  )
}

export_validation <- function(data, excluded = integer(0)) {
  mask <- rep(FALSE, nrow(data))
  mask[excluded] <- TRUE
  list(clean_data = data[!mask, , drop = FALSE], n_total = nrow(data),
       n_excluded = length(excluded), n_valid = nrow(data) - length(excluded),
       exclusion_mask = mask)
}

export_config <- function(id_var = "RespID", wtp = FALSE, code = "GGACC") {
  list(
    project_name = "Export Test", currency_symbol = "R", id_var = id_var,
    weight_var = "Weight", tabs_question_code = code, export_wtp = wtp,
    van_westendorp = list(col_too_cheap = "TooCheap", col_cheap = "Cheap",
                          col_expensive = "Expensive", col_too_expensive = "TooExp"),
    gabor_granger = list(response_type = "binary", binary_coding = "ZERO_ONE"),
    monadic = list(price_column = "CellPrice", intent_column = "CellIntent"),
    segment_vars = character(0)
  )
}

run_export <- function(results, config, file = NULL) {
  if (is.null(file)) {
    file <- file.path(tempdir(), paste0("pr_export_", sample.int(1e6, 1)), "Study.xlsx")
  }
  invisible(capture.output(
    res <- export_pricing_for_tabs(results, config, output_file = sub("[.]xlsx$", "_tabs_pricing.xlsx", file),
                                   verbose = FALSE)))
  res
}

base_results <- function(data = export_data(), imputation = "none", excluded = integer(0)) {
  list(gabor_granger = export_gg(data, imputation),
       van_westendorp = list(price_points = list(PMC = 40, OPP = 60, IDP = 70, PME = 90)),
       validation = export_validation(data, excluded),
       data = data,
       output_path = file.path(tempdir(), "Study.xlsx"))
}

# ---------------------------------------------------------------------------
# The id gate
# ---------------------------------------------------------------------------

test_that("the export refuses without an ID variable rather than joining on row order", {
  expect_error(run_export(base_results(), export_config(id_var = NA_character_)),
               class = "turas_refusal")
  err <- tryCatch(run_export(base_results(), export_config(id_var = NA_character_)),
                  turas_refusal = function(e) e)
  expect_equal(err$code, "CFG_TABS_EXPORT_NO_ID")
})

test_that("the export refuses when the ID variable is not in the data", {
  err <- tryCatch(run_export(base_results(), export_config(id_var = "NotThere")),
                  turas_refusal = function(e) e)
  expect_equal(err$code, "DATA_TABS_EXPORT_ID_MISSING")
})

test_that("the export refuses on repeated or blank ids", {
  d <- export_data()
  d$RespID[3] <- d$RespID[2]
  err <- tryCatch(run_export(base_results(d), export_config()), turas_refusal = function(e) e)
  expect_equal(err$code, "DATA_TABS_EXPORT_ID_NOT_UNIQUE")
})

test_that("the export refuses when the ladder is keyed on something else", {
  d <- export_data()
  r <- base_results(d)
  r$gabor_granger$gg_data$respondent_id <- paste0("X", r$gabor_granger$gg_data$respondent_id)
  err <- tryCatch(run_export(r, export_config()), turas_refusal = function(e) e)
  expect_equal(err$code, "DATA_TABS_EXPORT_ID_MISMATCH")
})

test_that("the export refuses when there is nothing to export", {
  r <- base_results()
  r$gabor_granger <- NULL
  err <- tryCatch(run_export(r, export_config(wtp = FALSE)), turas_refusal = function(e) e)
  expect_equal(err$code, "DATA_TABS_EXPORT_NOTHING")
})

# ---------------------------------------------------------------------------
# The DATA sheet
# ---------------------------------------------------------------------------

test_that("the workbook is written with three sheets and the column contract", {
  res <- run_export(base_results(), export_config())
  expect_equal(res$status, "PASS")
  expect_true(file.exists(res$output_file))
  expect_match(basename(res$output_file), "_tabs_pricing[.]xlsx$")
  expect_setequal(openxlsx::getSheetNames(res$output_file),
                  c("DATA", "QUESTIONMAP_SNIPPET", "METHOD"))
  expect_equal(res$columns,
               c("RespID", "GGACC_1", "GGACC_2", "GGACC_3", "pricing_valid"))
})

test_that("a cell holds the rung's label where the respondent would buy, and is empty otherwise", {
  # Not 0/1: tabs counts a mention by comparing the cell to OptionText.
  res <- run_export(base_results(), export_config())
  sheet <- openxlsx::read.xlsx(res$output_file, sheet = "DATA", skipEmptyRows = FALSE)
  expect_equal(sheet$GGACC_1[1], "R60.00")
  expect_true(is.na(sheet$GGACC_1[11]))
  expect_equal(sum(sheet$GGACC_1 == "R60.00", na.rm = TRUE), 10)
  expect_equal(sum(sheet$GGACC_2 == "R80.00", na.rm = TRUE), 8)
  expect_equal(sum(sheet$GGACC_3 == "R100.00", na.rm = TRUE), 4)
  # And the Options rows carry exactly those labels.
  expect_equal(res$options$OptionText, c("R60.00", "R80.00", "R100.00"))
})

test_that("the Options rows are keyed by column, which is how Multi_Mention looks them up", {
  # A tabs Multi_Mention matches its options with ^{code}_[0-9]+$ against the
  # Options sheet's QuestionCode (question_orchestrator.R). Rows keyed by the
  # bare question code, which is what an Allocation uses, match nothing: every
  # answer is reported unmatched and the question is dropped from the report.
  # The integrated demo caught exactly that.
  res <- run_export(base_results(), export_config())
  expect_equal(res$options$QuestionCode, c("GGACC_1", "GGACC_2", "GGACC_3"))
  expect_true(all(grepl("^GGACC_[0-9]+$", res$options$QuestionCode)))
  expect_equal(res$options$DisplayText, res$options$OptionText)
  expect_true(all(res$options$ShowInOutput == "Y"))
  expect_equal(res$options$DisplayOrder, 1:3)
  # The data columns and the option keys are the same set, in the same order.
  grid_cols <- grep("^GGACC_[0-9]+$", res$columns, value = TRUE)
  expect_equal(grid_cols, res$options$QuestionCode)
})

test_that("pricing_valid reproduces the module's analysed base, in data row order", {
  d <- export_data()
  res <- run_export(base_results(d, excluded = c(2, 5)), export_config())
  sheet <- openxlsx::read.xlsx(res$output_file, sheet = "DATA", skipEmptyRows = FALSE)
  expect_equal(sheet$pricing_valid[c(1, 2, 3, 5)], c(1, 0, 1, 0))
  expect_equal(sum(sheet$pricing_valid), nrow(d) - 2)
  expect_equal(sheet$RespID, d$RespID)
})

test_that("the question code is sanitised into a valid column prefix", {
  res <- run_export(base_results(), export_config(code = "GG ACC!"))
  expect_equal(res$question_code, "GG_ACC_")
  expect_true(all(c("GG_ACC__1", "GG_ACC__2") %in% res$columns))
})

# ---------------------------------------------------------------------------
# WTP
# ---------------------------------------------------------------------------

test_that("WTP is opt-in, derived from the ladder, and censored at the top rung", {
  res <- run_export(base_results(), export_config(wtp = TRUE))
  expect_true("GGACC_WTP" %in% res$columns)
  sheet <- openxlsx::read.xlsx(res$output_file, sheet = "DATA", skipEmptyRows = FALSE)
  # Respondents 1 to 4 accepted every rung, so their WTP is the top rung.
  expect_equal(sheet$GGACC_WTP[1:4], rep(100, 4))
  # Respondents 11 and 12 accepted nothing.
  expect_true(all(is.na(sheet$GGACC_WTP[11:12])))
  method <- openxlsx::read.xlsx(res$output_file, sheet = "METHOD", skipEmptyRows = FALSE)
  wtp_row <- method$Value[method$Item == "Willingness to pay"]
  expect_match(wtp_row, "RIGHT-CENSORED")
  expect_match(wtp_row, "R100.00")
})

test_that("without the ladder, WTP falls back to the Van Westendorp midpoint and says so", {
  d <- export_data()
  r <- base_results(d)
  r$gabor_granger <- NULL
  res <- run_export(r, export_config(wtp = TRUE))
  sheet <- openxlsx::read.xlsx(res$output_file, sheet = "DATA", skipEmptyRows = FALSE)
  expect_equal(sheet$GGACC_WTP[1], median(c(d$Cheap[1], d$Expensive[1])))
  method <- openxlsx::read.xlsx(res$output_file, sheet = "METHOD", skipEmptyRows = FALSE)
  expect_match(method$Value[method$Item == "Willingness to pay"], "midpoint")
})

# ---------------------------------------------------------------------------
# The stamping sheets
# ---------------------------------------------------------------------------

test_that("QUESTIONMAP_SNIPPET writes the grid row and documents what tabs reads directly", {
  res <- run_export(base_results(), export_config())
  qm <- res$questionmap
  grid <- qm[qm$QuestionCode == "GGACC", ]
  expect_equal(nrow(grid), 1)
  expect_equal(grid$Variable_Type, "Multi_Mention")
  expect_equal(grid$Columns, 3)
  expect_match(grid$Data_Source, "DATA sheet")
  # The VW and monadic rows point at the survey file, not at this export.
  vw_row <- qm[qm$QuestionCode == "Cheap", ]
  expect_equal(nrow(vw_row), 1)
  expect_match(vw_row$Data_Source, "survey data file")
  expect_match(vw_row$Note, "Documentation row")
  expect_true("CellPrice" %in% qm$QuestionCode)
})

test_that("METHOD states the base difference, the weighting and what is NOT exported", {
  res <- run_export(base_results(), export_config())
  method <- openxlsx::read.xlsx(res$output_file, sheet = "METHOD", skipEmptyRows = FALSE)
  get_row <- function(item) method$Value[method$Item == item]
  expect_match(get_row("Cell contract"), "OptionText")
  expect_match(get_row("Cell contract"), "zero at every price")
  expect_match(get_row("Coding rule"), "1 = would buy")
  expect_match(get_row("pricing_valid"), "reproduce the pricing report's base")
  expect_match(get_row("Weighting"), "tabs weights them again")
  expect_match(get_row("What is NOT here"), "differences of exactly zero")
  expect_match(get_row("Id column"), "RespID")
})

test_that("a rung nobody skipped and a rung with gaps are both disclosed", {
  d <- export_data()
  r <- base_results(d)
  # Three respondents never answered the top rung.
  gg <- r$gabor_granger$gg_data
  gg$response[gg$price == 100 & gg$respondent_id %in% d$RespID[1:3]] <- NA
  r$gabor_granger$gg_data <- gg
  res <- run_export(r, export_config())
  method <- openxlsx::read.xlsx(res$output_file, sheet = "METHOD", skipEmptyRows = FALSE)
  bases <- method$Value[method$Item == "Per-rung answered base"]
  expect_match(bases, "12 / 12 / 9")
  expect_match(bases, "reads lower in tabs")
})

test_that("stop-early imputation is named on the METHOD sheet", {
  res <- run_export(base_results(imputation = "NO_AFTER_STOP: unanswered rungs after a respondent's first No coded as No"),
                    export_config())
  method <- openxlsx::read.xlsx(res$output_file, sheet = "METHOD", skipEmptyRows = FALSE)
  expect_match(method$Value[method$Item == "Stop-early imputation"], "NO_AFTER_STOP")
})

test_that("no em dash reaches the operator from the exporter", {
  src <- paste(readLines(file.path(TURAS_ROOT, "modules", "pricing", "R", "15_tabs_export.R"),
                         warn = FALSE), collapse = "\n")
  expect_false(grepl("—", src))
})

# ---------------------------------------------------------------------------
# Integration proof: the export read by the tabs processor itself
# ---------------------------------------------------------------------------

test_that("tabs counts the exported grid correctly, and would count 0/1 flags as nothing", {
  cell_calc <- file.path(TURAS_ROOT, "modules", "tabs", "lib", "cell_calculator.R")
  skip_if(!file.exists(cell_calc), "tabs cell calculator not present")
  env <- new.env(parent = globalenv())
  invisible(capture.output(suppressWarnings(suppressMessages({
    for (f in c("type_utils.R", "cell_calculator.R")) {
      try(sys.source(file.path(TURAS_ROOT, "modules", "tabs", "lib", f), envir = env),
          silent = TRUE)
    }
  }))))
  skip_if(!exists("calculate_row_counts", envir = env, mode = "function"),
          "calculate_row_counts not loadable on its own")
  counts <- get("calculate_row_counts", envir = env)

  res <- run_export(base_results(), export_config())
  sheet <- openxlsx::read.xlsx(res$output_file, sheet = "DATA", skipEmptyRows = FALSE)
  cols <- paste0("GGACC_", 1:3)
  idx <- list(`TOTAL::Total` = seq_len(nrow(sheet)))
  w <- rep(1, nrow(sheet))

  got <- vapply(res$options$OptionText, function(opt) {
    unname(counts(sheet, idx, opt, "GGACC", TRUE, cols, names(idx), w))
  }, numeric(1))
  expect_equal(unname(got), c(10, 8, 4))

  # And the option keys select exactly the columns the processor builds from
  # Columns = k, so tabs finds every rung.
  qm <- res$questionmap[res$questionmap$QuestionCode == "GGACC", ]
  expect_equal(paste0("GGACC_", seq_len(qm$Columns)), res$options$QuestionCode)

  # The same grid written as 0/1 flags, which the July brief specified and the
  # tabs contract does not read: every rung counts zero.
  flags <- sheet
  for (j in seq_along(cols)) {
    flags[[cols[j]]] <- as.numeric(!is.na(sheet[[cols[j]]]))
  }
  got_flags <- vapply(res$options$OptionText, function(opt) {
    unname(counts(flags, idx, opt, "GGACC", TRUE, cols, names(idx), w))
  }, numeric(1))
  expect_equal(unname(got_flags), c(0, 0, 0))
})

# ---------------------------------------------------------------------------
# The config setting no longer refuses
# ---------------------------------------------------------------------------

test_that("Generate_Tabs_Export = Y is accepted now, and still needs an id", {
  skip_if(!exists("apply_pricing_defaults", mode = "function"), "config loader not available")
  ok <- apply_pricing_defaults(list(generate_tabs_export = "Y", id_var = "RespID"))
  expect_true(isTRUE(ok$generate_tabs_export))

  err <- tryCatch(apply_pricing_defaults(list(generate_tabs_export = "Y")),
                  turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_TABS_EXPORT_NO_ID")
})
