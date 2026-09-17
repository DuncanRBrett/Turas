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
  # GGACC_4 is the rejecters' own column: without it tabs drops them from the
  # Multi_Mention base and every rung reads higher than the module (review F1).
  expect_equal(res$columns,
               c("RespID", "GGACC_1", "GGACC_2", "GGACC_3", "GGACC_4", "pricing_valid"))
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
  # Rows 11 and 12 would not buy at any rung, so they carry the rejecters'
  # answer rather than an empty row (review F1).
  expect_equal(sum(sheet$GGACC_4 == "Would not buy at any price", na.rm = TRUE), 2)
  expect_true(all(is.na(sheet$GGACC_4[1:10])))
  # And the Options rows carry exactly those labels.
  expect_equal(res$options$OptionText, c("R60.00", "R80.00", "R100.00", "Would not buy at any price"))
})

test_that("the Options rows are keyed by column, which is how Multi_Mention looks them up", {
  # A tabs Multi_Mention matches its options with ^{code}_[0-9]+$ against the
  # Options sheet's QuestionCode (question_orchestrator.R). Rows keyed by the
  # bare question code, which is what an Allocation uses, match nothing: every
  # answer is reported unmatched and the question is dropped from the report.
  # The integrated demo caught exactly that.
  res <- run_export(base_results(), export_config())
  expect_equal(res$options$QuestionCode, c("GGACC_1", "GGACC_2", "GGACC_3", "GGACC_4"))
  expect_true(all(grepl("^GGACC_[0-9]+$", res$options$QuestionCode)))
  expect_equal(res$options$DisplayText, res$options$OptionText)
  expect_true(all(res$options$ShowInOutput == "Y"))
  # DisplayOrder is written as text, because tabs reads every structure sheet
  # as text and sorts with order(). A short ladder is unpadded, exactly as it
  # was; a ladder of ten or more rungs is zero-padded so it does not display as
  # 1, 10, 11, 2 (review F19).
  expect_equal(res$options$DisplayOrder, c("1", "2", "3", "4"))
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
  expect_equal(grid$Columns, 4)   # three rungs plus the rejecters' column (F1)
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
  # This row used to say "filter on it to reproduce the pricing report's base",
  # which review F1 showed to be false: an excluded respondent has every
  # acceptance column blank, so a Multi_Mention table has already left them out.
  expect_match(get_row("pricing_valid"), "will not change it")
  expect_false(grepl("reproduce the pricing report's base", get_row("pricing_valid"), fixed = TRUE))
  expect_match(get_row("Base agreement"), "equals the pricing report's analysed base")
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
  cols <- paste0("GGACC_", 1:4)
  idx <- list(`TOTAL::Total` = seq_len(nrow(sheet)))
  w <- rep(1, nrow(sheet))

  got <- vapply(res$options$OptionText, function(opt) {
    unname(counts(sheet, idx, opt, "GGACC", TRUE, cols, names(idx), w))
  }, numeric(1))
  expect_equal(unname(got), c(10, 8, 4, 2))

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
  expect_equal(unname(got_flags), c(0, 0, 0, 0))
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

# ------------------------------------------------------------------------------
# F4: a respondent the completeness rule excluded is out of the exported base
# ------------------------------------------------------------------------------

test_that("pricing_valid drops the ladders the completeness rule excluded (F4)", {
  skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")
  prices <- c(20, 40, 60, 80, 100)
  cols <- paste0("p", prices)
  config <- list(
    analysis_method = "gabor_granger", weight_var = NA_character_, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    gg_monotonicity_behavior = "diagnostic_only", gg_stop_early_imputation = "NONE",
    generate_tabs_export = TRUE, tabs_question_code = "GGACC", export_wtp = FALSE,
    gabor_granger = list(data_format = "wide", price_sequence = prices,
                         response_columns = cols, response_type = "binary",
                         binary_coding = "ZERO_ONE", smoothing_method = "isotonic",
                         check_monotonicity = FALSE, calculate_elasticity = FALSE,
                         revenue_optimization = TRUE, confidence_intervals = FALSE,
                         bootstrap_iterations = 10, confidence_level = 0.95),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000))

  set.seed(21)
  n <- 300
  ceiling <- runif(n, 15, 105)
  m <- sapply(prices, function(p) as.integer(p <= ceiling))
  m[matrix(runif(n * length(prices)) < 0.03, nrow = n)] <- NA_integer_
  d <- as.data.frame(m)
  names(d) <- cols
  d$respondent_id <- seq_len(n)

  invisible(capture.output(v <- validate_pricing_data(d, config)))
  invisible(capture.output(g <- run_gabor_granger(v$clean_data, config)))
  n_excluded <- g$diagnostics$completeness$n_excluded
  expect_gt(n_excluded, 0)

  out <- file.path(tempdir(), "pricing_f4_tabs_export.xlsx")
  unlink(out)
  on.exit(unlink(out), add = TRUE)
  invisible(capture.output(res <- export_pricing_for_tabs(
    list(data = d, validation = v, gabor_granger = g), config, out, verbose = FALSE)))

  data_sheet <- openxlsx::read.xlsx(out, sheet = "DATA", skipEmptyRows = FALSE)
  expect_true("pricing_valid" %in% names(data_sheet))
  # The exported base is the module's own analysed base, not the whole file.
  expect_equal(sum(data_sheet$pricing_valid == 1), g$diagnostics$n_respondents)
  expect_equal(sum(data_sheet$pricing_valid == 0), n_excluded)
})

# ------------------------------------------------------------------------------
# F1: the rejecters keep their place in the tabs base
# ------------------------------------------------------------------------------

# tabs' own base rule, sourced rather than reimplemented.
tabs_mm_base <- function(df, code, n_cols) {
  root <- TURAS_ROOT
  if (!exists("calculate_multimention_base", mode = "function")) {
    source(file.path(root, "modules", "tabs", "lib", "weighting.R"))
  }
  calculate_multimention_base(df, code, n_cols, rep(1, nrow(df)))$unweighted
}

f1_export <- function(d, config, tag) {
  invisible(capture.output(v <- validate_pricing_data(d, config)))
  invisible(capture.output(g <- run_gabor_granger(v$clean_data, config)))
  out <- file.path(tempdir(), paste0("pricing_f1_", tag, ".xlsx"))
  unlink(out)
  invisible(capture.output(export_pricing_for_tabs(
    list(data = d, validation = v, gabor_granger = g), config, out, verbose = FALSE)))
  list(path = out, gg = g,
       data = openxlsx::read.xlsx(out, sheet = "DATA", skipEmptyRows = FALSE))
}

f1_cfg <- function(prices, cols, imputation = "NONE") {
  list(
    analysis_method = "gabor_granger", weight_var = NA_character_, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    gg_monotonicity_behavior = "diagnostic_only", gg_stop_early_imputation = imputation,
    generate_tabs_export = TRUE, tabs_question_code = "GGACC", export_wtp = FALSE,
    gabor_granger = list(data_format = "wide", price_sequence = prices,
                         response_columns = cols, response_type = "binary",
                         binary_coding = "ZERO_ONE", smoothing_method = "isotonic",
                         check_monotonicity = FALSE, calculate_elasticity = FALSE,
                         revenue_optimization = TRUE, confidence_intervals = FALSE,
                         bootstrap_iterations = 10, confidence_level = 0.95),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000))
}

test_that("a respondent who would not buy at any rung gets an answer of their own (F1)", {
  skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")
  prices <- c(20, 40, 60)
  cols <- paste0("p", prices)
  # Six respondents: four accept something, two accept nothing.
  d <- data.frame(respondent_id = 1:6,
                  p20 = c(1, 1, 1, 1, 0, 0),
                  p40 = c(1, 1, 0, 0, 0, 0),
                  p60 = c(1, 0, 0, 0, 0, 0))
  ex <- f1_export(d, f1_cfg(prices, cols), "small")
  last <- paste0("GGACC_", length(prices) + 1)
  expect_true(last %in% names(ex$data))
  expect_equal(sum(!is.na(ex$data[[last]])), 2)
  expect_equal(unique(ex$data[[last]][!is.na(ex$data[[last]])]), "Would not buy at any price")
  # It never lands on a respondent who accepted something.
  accepted <- rowSums(!is.na(ex$data[, paste0("GGACC_", seq_along(prices))])) > 0
  expect_true(all(is.na(ex$data[[last]][accepted])))

  # The Options rows carry it, keyed by column like every rung.
  opts <- openxlsx::read.xlsx(ex$path, sheet = "QUESTIONMAP_SNIPPET",
                              skipEmptyRows = FALSE, colNames = FALSE)
  flat <- as.character(unlist(opts))
  expect_true(any(grepl(paste0("GGACC_", length(prices) + 1), flat, fixed = TRUE)))
  expect_true(any(grepl("Would not buy at any price", flat, fixed = TRUE)))
})

test_that("the tabs base now equals the module's analysed base (F1)", {
  skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")
  skip_if(!file.exists(file.path(TURAS_ROOT, "modules", "tabs", "lib", "weighting.R")),
          "tabs weighting not present")
  prices <- c(20, 40, 60, 80, 100)
  cols <- paste0("p", prices)
  set.seed(31)
  n <- 200
  ceiling <- runif(n, 15, 105)
  d <- as.data.frame(sapply(prices, function(p) as.integer(p <= ceiling)))
  names(d) <- cols
  d$respondent_id <- seq_len(n)
  ex <- f1_export(d, f1_cfg(prices, cols), "base")
  n_cols <- length(prices) + 1
  expect_equal(tabs_mm_base(ex$data, "GGACC", n_cols),
               ex$gg$diagnostics$n_respondents)
  # Without the last column tabs drops whoever accepted nothing.
  rungs_only <- ex$data[, c("respondent_id", paste0("GGACC_", seq_along(prices)))]
  expect_lt(tabs_mm_base(rungs_only, "GGACC", length(prices)),
            ex$gg$diagnostics$n_respondents)
})

test_that("a stop-early ladder's cheapest rung no longer reads 100% in tabs (F1)", {
  skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")
  skip_if(!file.exists(file.path(TURAS_ROOT, "modules", "tabs", "lib", "weighting.R")),
          "tabs weighting not present")
  prices <- c(20, 40, 60, 80)
  cols <- paste0("p", prices)
  set.seed(5)
  n <- 150
  ceiling <- runif(n, 10, 90)
  m <- sapply(prices, function(p) as.integer(p <= ceiling))
  for (i in seq_len(n)) {
    fn <- which(m[i, ] == 0L)
    if (length(fn) && fn[1] < length(prices)) m[i, (fn[1] + 1):length(prices)] <- NA
  }
  d <- as.data.frame(m)
  names(d) <- cols
  d$respondent_id <- seq_len(n)
  ex <- f1_export(d, f1_cfg(prices, cols, imputation = "NO_AFTER_STOP"), "stop")

  n_cols <- length(prices) + 1
  base <- tabs_mm_base(ex$data, "GGACC", n_cols)
  mentions <- sum(!is.na(ex$data[["GGACC_1"]]))
  tabs_pct <- 100 * mentions / base
  report_pct <- 100 * ex$gg$demand_curve$purchase_intent[1]
  # Under NO_AFTER_STOP a No at the first rung blanks the whole row, so the
  # old export made the bottom rung 100% by construction.
  expect_lt(tabs_pct, 100)
  expect_equal(tabs_pct, report_pct, tolerance = 0.01)

  old_base <- tabs_mm_base(ex$data[, c("respondent_id", paste0("GGACC_", seq_along(prices)))],
                           "GGACC", length(prices))
  expect_equal(100 * mentions / old_base, 100)
})

test_that("an excluded respondent is never given the rejecters' answer (F1)", {
  skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")
  prices <- c(20, 40, 60, 80, 100)
  cols <- paste0("p", prices)
  set.seed(21)
  n <- 120
  ceiling <- runif(n, 15, 105)
  m <- sapply(prices, function(p) as.integer(p <= ceiling))
  m[matrix(runif(n * length(prices)) < 0.05, nrow = n)] <- NA_integer_
  d <- as.data.frame(m)
  names(d) <- cols
  d$respondent_id <- seq_len(n)
  ex <- f1_export(d, f1_cfg(prices, cols), "excluded")
  last <- paste0("GGACC_", length(prices) + 1)
  # The column must exist, or the rest of this test passes vacuously.
  expect_true(last %in% names(ex$data))
  expect_gt(sum(ex$data$pricing_valid == 0), 0)
  expect_true(all(is.na(ex$data[[last]][ex$data$pricing_valid == 0])))
  # It does land on the analysed respondents who accepted nothing.
  expect_gt(sum(!is.na(ex$data[[last]])), 0)
  expect_true(all(ex$data$pricing_valid[!is.na(ex$data[[last]])] == 1))
})

# ------------------------------------------------------------------------------
# F15: a long-format study is refused for the real reason
# ------------------------------------------------------------------------------

test_that("a long-format study is told the export needs one row per respondent (F15)", {
  skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")
  prices <- c(20, 40, 60)
  n <- 20
  # One row per respondent per rung, which is what Data_Format = long means.
  d <- do.call(rbind, lapply(prices, function(p) data.frame(
    respondent_id = sprintf("R%03d", seq_len(n)),
    price = p,
    buy = as.integer(p <= 40),
    stringsAsFactors = FALSE)))
  config <- list(
    analysis_method = "gabor_granger", weight_var = NA_character_, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    gg_monotonicity_behavior = "diagnostic_only", gg_stop_early_imputation = "NONE",
    generate_tabs_export = TRUE, tabs_question_code = "GGACC", export_wtp = FALSE,
    gabor_granger = list(data_format = "long", price_column = "price",
                         response_column = "buy", respondent_column = "respondent_id",
                         response_type = "binary", binary_coding = "ZERO_ONE",
                         smoothing_method = "isotonic", check_monotonicity = FALSE,
                         calculate_elasticity = FALSE, revenue_optimization = TRUE,
                         confidence_intervals = FALSE, bootstrap_iterations = 10,
                         confidence_level = 0.95),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000))

  invisible(capture.output(v <- validate_pricing_data(d, config)))
  invisible(capture.output(g <- run_gabor_granger(v$clean_data, config)))
  out <- file.path(tempdir(), "pricing_f15.xlsx")
  unlink(out)
  on.exit(unlink(out), add = TRUE)
  err <- tryCatch({
    invisible(capture.output(export_pricing_for_tabs(
      list(data = d, validation = v, gabor_granger = g), config, out, verbose = FALSE)))
    "NO REFUSAL"
  }, error = function(e) conditionMessage(e))

  expect_match(err, "CFG_TABS_EXPORT_LONG_FORMAT")
  expect_match(err, "one row per respondent")
  expect_match(err, "Data_Format = wide")
  # And it no longer blames ids that are perfectly correct.
  expect_false(grepl("DATA_TABS_EXPORT_ID_NOT_UNIQUE", err, fixed = TRUE))
  expect_false(grepl("Give every respondent one unique id", err, fixed = TRUE))
  # The analysis itself was fine; only the export is refused.
  expect_equal(length(unique(g$gg_data$respondent_id)), n)
})


test_that("a ladder of ten or more rungs still displays in price order (F19)", {
  skip_if(!exists(".pricing_tabs_options", mode = "function"), "helper not available")
  prices <- seq(10, 120, by = 10)   # eleven rungs, twelve options with the rejecters
  opts <- .pricing_tabs_options("GGACC", prices, "R")
  expect_equal(nrow(opts), length(prices) + 1)
  # Sorted as text, which is what tabs does, the order is still the price order.
  expect_equal(order(opts$DisplayOrder), seq_len(nrow(opts)))
  expect_equal(opts$DisplayOrder[1], "01")
  expect_equal(opts$DisplayOrder[12], "12")
  # The unpadded form is the one that breaks, which is why this test exists.
  expect_false(identical(order(as.character(seq_len(12))), seq_len(12)))
})

# ------------------------------------------------------------------------------
# F17, F18: the snippet names the sheet tabs reads, and a blank currency warns
# ------------------------------------------------------------------------------

test_that("the snippet sends the analyst to the sheet tabs actually reads (F17)", {
  skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")
  res <- run_export(base_results(), export_config())
  sheet <- openxlsx::read.xlsx(res$output_file, sheet = "QUESTIONMAP_SNIPPET",
                               skipEmptyRows = FALSE, colNames = FALSE)
  header <- as.character(sheet[[1]][1])
  expect_match(header, "Questions sheet")
  expect_match(header, "Survey_Structure")
  # It says plainly that QuestionMap is something else, and which columns tabs ignores.
  expect_match(header, "QuestionMap is the tracking")
  expect_match(header, "ignores them")
  # And the grid row's note no longer describes a coding tabs cannot read.
  grid <- res$questionmap[res$questionmap$QuestionCode == "GGACC", ]
  expect_false(grepl("0/1 column per rung", grid$Note, fixed = TRUE))
  expect_match(grid$Note, "price label")
})

test_that("a blank currency warns that the labels can turn into numbers (F18)", {
  skip_if(!exists("export_pricing_for_tabs", mode = "function"), "exporter not available")
  cfg <- export_config()
  cfg$currency_symbol <- ""
  out <- file.path(tempdir(), "pricing_f18.xlsx")
  unlink(out)
  on.exit(unlink(out), add = TRUE)
  console <- capture.output(
    res <- export_pricing_for_tabs(base_results(), cfg, out, verbose = FALSE))
  expect_true(any(grepl("Currency_Symbol is blank", console, fixed = TRUE)))
  expect_true(any(grepl("reports 0%", console, fixed = TRUE)))

  method <- openxlsx::read.xlsx(out, sheet = "METHOD", skipEmptyRows = FALSE)
  row <- method$Value[method$Item == "Currency symbol"]
  expect_length(row, 1)
  expect_match(row, "bare number")

  # A currency is set, so nothing is warned about.
  out2 <- file.path(tempdir(), "pricing_f18_ok.xlsx")
  unlink(out2)
  on.exit(unlink(out2), add = TRUE)
  console2 <- capture.output(
    export_pricing_for_tabs(base_results(), export_config(), out2, verbose = FALSE))
  expect_false(any(grepl("Currency_Symbol is blank", console2, fixed = TRUE)))
  method2 <- openxlsx::read.xlsx(out2, sheet = "METHOD", skipEmptyRows = FALSE)
  expect_length(method2$Value[method2$Item == "Currency symbol"], 0)
})

test_that("the GUI names the deliverables that exist (F7)", {
  gui <- file.path(TURAS_ROOT, "modules", "pricing", "run_pricing_gui.R")
  skip_if(!file.exists(gui), "GUI not present")
  src <- paste(readLines(gui, warn = FALSE), collapse = "\n")
  expect_false(grepl("Open the HTML file for the interactive report", src, fixed = TRUE))
  expect_match(src, "There is no separate HTML report")
})
