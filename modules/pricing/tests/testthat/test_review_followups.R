# ==============================================================================
# TURAS PRICING MODULE - REVIEW FOLLOW-UP TESTS
# ==============================================================================
# Findings from the independent review of Session A
# (docs/v2_lift/REVIEW_FINDINGS_PRICING_SESSION_A_2026-09-03.md). Each test
# names its finding and fails on main at 34078b33.
# ==============================================================================

skip_if(!exists("run_pricing_analysis", mode = "function"), "pipeline not available")
skip_if(!exists("calculate_effective_n", mode = "function"), "shared Kish helper not available")

example_script <- file.path(TURAS_ROOT, "examples", "pricing", "create_pricing_example.R")
skip_if(!file.exists(example_script), "example generator not present")

# ------------------------------------------------------------------------------
# F2: the Results workbook's Summary sheet reports the Kish effective n, not
# the count of valid weights, under "Effective Sample Size".
# ------------------------------------------------------------------------------

test_that("the Summary sheet's Effective Sample Size is the Kish figure on the analysed cases (review F2)", {
  old <- getOption("turas.example.no_run")
  options(turas.example.no_run = TRUE)
  source(example_script, local = FALSE)
  options(turas.example.no_run = old)

  out_dir <- file.path(tempdir(), "karoo_pricing_review_f2")
  unlink(out_dir, recursive = TRUE)
  capture.output(ex <- build_pricing_example(TURAS_ROOT, out_dir, verbose = FALSE,
                                             bootstrap_iterations = 20))
  # The monadic config is weighted and fast; every respondent is a valid case.
  capture.output(r <- run_pricing_analysis(ex$config_monadic))
  expect_equal(r$run_result$status, "PASS")

  wb_path <- file.path(out_dir, "Output", "Karoo_Pricing_Monadic_Results.xlsx")
  expect_true(file.exists(wb_path))
  summary <- openxlsx::read.xlsx(wb_path, sheet = "Summary", skipEmptyRows = FALSE)
  items <- as.character(summary[[1]])
  values <- as.character(summary[[2]])

  eff_row <- grep("^Effective Sample Size", items)
  valid_row <- grep("^Valid N", items)
  expect_length(eff_row, 1)
  expect_length(valid_row, 1)

  # Hand-computed Kish on the weights the run analysed.
  w <- ex$data$Weight
  kish <- sum(w)^2 / sum(w^2)
  expect_equal(as.numeric(values[eff_row]), kish, tolerance = 0.05 / kish)
  expect_equal(as.numeric(values[valid_row]), nrow(ex$data))
  # And the two are different numbers: the old row printed the count.
  expect_false(isTRUE(all.equal(as.numeric(values[eff_row]), nrow(ex$data))))
  expect_match(items[eff_row], "Kish")
})

# ------------------------------------------------------------------------------
# F3: the Newton-Miller-Smith extension is refused by name, ahead of both
# Van Westendorp branches, and PI_Scale is no longer handed to the package.
# ------------------------------------------------------------------------------

nms_cfg <- function(col_pi_cheap = "PI_Cheap", weight_var = NA_character_) {
  list(
    analysis_method = "van_westendorp", weight_var = weight_var, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    vw_monotonicity_behavior = "drop",
    van_westendorp = list(col_too_cheap = "tc", col_cheap = "ch",
                          col_expensive = "ex", col_too_expensive = "te",
                          col_pi_cheap = col_pi_cheap, col_pi_expensive = NA_character_,
                          pi_scale = 5, validate_monotonicity = FALSE),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000)
  )
}

nms_data <- function(n = 40) {
  set.seed(3)
  tc <- runif(n, 5, 15)
  data.frame(respondent_id = seq_len(n), tc = tc, ch = tc + 5, ex = tc + 12,
             te = tc + 20, PI_Cheap = sample(1:5, n, TRUE), w = 1)
}

test_that("a configured NMS extension refuses by name before any price point (F3)", {
  err <- tryCatch(validate_pricing_data(nms_data(), nms_cfg()), error = function(e) conditionMessage(e))
  expect_match(err, "FEATURE_NMS_WITHDRAWN")
  expect_match(err, "Col_PI_Cheap")
})

test_that("the NMS refusal reaches the weighted branch as well (F3)", {
  d <- nms_data()
  err <- tryCatch(validate_pricing_data(d, nms_cfg(weight_var = "w")),
                  error = function(e) conditionMessage(e))
  expect_match(err, "FEATURE_NMS_WITHDRAWN")
})

test_that("Van Westendorp without the extension still validates (F3)", {
  d <- nms_data()
  cfg <- nms_cfg(col_pi_cheap = NA_character_)
  v <- validate_pricing_data(d, cfg)
  expect_true(is.data.frame(v$clean_data))
  expect_gt(nrow(v$clean_data), 0)
  # An empty string is the config workbook's other way of saying nothing.
  expect_silent(invisible(validate_pricing_data(d, nms_cfg(col_pi_cheap = ""))))
})

test_that("PI_Scale is no longer passed to the package (F3)", {
  # The template pre-fills PI_Scale = 5, which the package reads as a vector of
  # scale points and rejects. The engine must not forward it.
  src <- readLines(file.path(TURAS_ROOT, "modules", "pricing", "R", "03_van_westendorp.R"))
  call_start <- grep("^  psm_fit <- fit_vw_psm\\(", src)
  expect_length(call_start, 1)
  call_end <- call_start + which(grepl("^  \\)$", src[call_start:length(src)]))[1] - 1
  expect_false(any(grepl("pi_scale", src[call_start:call_end])))
})

# ------------------------------------------------------------------------------
# F7 to F12: the small ones
# ------------------------------------------------------------------------------

test_that("the price ladder speaks the study's currency, and no em dash (F7)", {
  tier_table <- data.frame(tier = c("Value", "Core", "Premium"),
                           price = c(59.99, 79.99, 109.99),
                           stringsAsFactors = FALSE)
  notes <- generate_ladder_notes(
    tier_table = tier_table,
    gap_analysis = list(flags = character(0)),
    reference_prices = list(PMC = 58, PME = 110),
    anchor_tier_idx = 2,
    currency = "R")
  joined <- paste(notes, collapse = " ")
  expect_match(joined, "R79.99", fixed = TRUE)
  expect_false(grepl("$", joined, fixed = TRUE))
  # Both bounds notes fire on these numbers, so all three sites are covered.
  expect_match(joined, "R59.99", fixed = TRUE)
  expect_match(joined, "R109.99", fixed = TRUE)

  src <- readLines(file.path(TURAS_ROOT, "modules", "pricing", "R", "11_price_ladder.R"))
  expect_false(any(grepl("—", src)))
  expect_false(any(grepl('"[$]%[.]2f', src)))
})

test_that("a zero weight is excluded once, at validation (F8)", {
  d <- data.frame(respondent_id = 1:40, price = rep(c(10, 20), 20),
                  buy = rep(c(1, 0), 20), w = c(0, rep(1, 39)))
  cfg <- list(
    analysis_method = "gabor_granger", weight_var = "w", dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    gg_monotonicity_behavior = "diagnostic_only", gg_stop_early_imputation = "NONE",
    gabor_granger = list(data_format = "long", price_column = "price",
                         response_column = "buy", respondent_column = "respondent_id",
                         response_type = "binary", binary_coding = "ZERO_ONE",
                         smoothing_method = "isotonic", check_monotonicity = FALSE,
                         calculate_elasticity = FALSE, revenue_optimization = TRUE,
                         confidence_intervals = FALSE, bootstrap_iterations = 10,
                         confidence_level = 0.95),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000))
  invisible(capture.output(v <- validate_pricing_data(d, cfg)))
  expect_equal(nrow(v$clean_data), 39)
  expect_true(any(grepl("zero values", unlist(v$warnings))))
  # The summary still counts what arrived, so the exclusion is visible.
  expect_equal(v$weight_summary$n_zero, 1)
})

test_that("the weighted bootstrap does not repeat the package warning (F9)", {
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE), "psm not available")
  set.seed(13)
  base <- runif(60, 60, 100)
  d <- data.frame(too_cheap = base * 0.5, cheap = base * 0.75,
                  expensive = base * 1.25, too_expensive = base * 1.6)
  d$expensive[1:6] <- d$cheap[1:6] * 0.9   # intransitive, kept under flag_only
  d$w <- 1
  d$respondent_id <- seq_len(nrow(d))
  cfg <- list(analysis_method = "van_westendorp", weight_var = NA_character_,
              dk_codes = numeric(0), currency_symbol = "R",
              van_westendorp = list(col_too_cheap = "too_cheap", col_cheap = "cheap",
                                    col_expensive = "expensive", col_too_expensive = "too_expensive",
                                    validate_monotonicity = TRUE, violation_threshold = 0.5,
                                    calculate_confidence = TRUE, bootstrap_iterations = 25,
                                    confidence_level = 0.95),
              vw_monotonicity_behavior = "flag_only",
              validation = list(min_completeness = 0.8, min_sample = 5,
                                price_min = 0, price_max = 10000))
  warns <- character(0)
  withCallingHandlers(
    invisible(capture.output(run_van_westendorp(d, cfg))),
    warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") }
  )
  inconsistent <- sum(grepl("inconsistent price structures", warns, fixed = TRUE))
  # The headline call may still warn once; 25 replicates must not add 25 more.
  expect_lte(inconsistent, 1)
})

test_that("a long-format price that did not parse refuses by what it is (F10)", {
  d <- data.frame(respondent_id = rep(1:20, times = 2),
                  price = rep(c("R60", "R80"), each = 20),
                  buy = rep(c(1, 0), 20), w = 1, stringsAsFactors = FALSE)
  cfg <- list(
    analysis_method = "gabor_granger", weight_var = NA_character_, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    gg_monotonicity_behavior = "diagnostic_only", gg_stop_early_imputation = "NO_AFTER_STOP",
    gabor_granger = list(data_format = "long", price_column = "price",
                         response_column = "buy", respondent_column = "respondent_id",
                         response_type = "binary", binary_coding = "ZERO_ONE",
                         smoothing_method = "isotonic", check_monotonicity = FALSE,
                         calculate_elasticity = FALSE, revenue_optimization = TRUE,
                         confidence_intervals = FALSE, bootstrap_iterations = 10,
                         confidence_level = 0.95),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000))
  err <- tryCatch(suppressWarnings(invisible(capture.output(run_gabor_granger(d, cfg)))),
                  error = function(e) conditionMessage(e))
  expect_match(err, "DATA_GG_PRICE_NOT_NUMERIC")
  expect_match(err, "did not read as numbers")
})

test_that("the interval sheet carries the curve it brackets (F11)", {
  prices <- c(10, 20, 30, 40)
  n <- 120
  set.seed(17)
  ceiling <- runif(n, 5, 45)
  d <- as.data.frame(sapply(prices, function(p) as.integer(p <= ceiling)))
  names(d) <- paste0("g", prices)
  d$respondent_id <- seq_len(n)
  cfg <- list(
    analysis_method = "gabor_granger", weight_var = NA_character_, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    gg_monotonicity_behavior = "smooth", gg_stop_early_imputation = "NONE",
    gabor_granger = list(data_format = "wide", price_sequence = prices,
                         response_columns = paste0("g", prices),
                         response_type = "binary", binary_coding = "ZERO_ONE",
                         smoothing_method = "isotonic", check_monotonicity = FALSE,
                         calculate_elasticity = FALSE, revenue_optimization = TRUE,
                         confidence_intervals = TRUE, bootstrap_iterations = 40,
                         confidence_level = 0.95),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000))
  invisible(capture.output(r <- run_gabor_granger(d, cfg)))
  ci <- r$confidence_intervals
  expect_true("published" %in% names(ci))
  expect_equal(ci$published, r$demand_curve$purchase_intent)
})

test_that("the stats pack's scope rows describe a pricing config (F11)", {
  cfg <- list(
    analysis_method = "both", weight_var = "Weight", id_var = "RespID",
    van_westendorp = list(col_too_cheap = "tc", col_cheap = "ch",
                          col_expensive = "ex", col_too_expensive = "te"),
    gabor_granger = list(price_sequence = c(60, 80, 100, 120, 140),
                         response_columns = c("g60", "g80", "g100", "g120", "g140")))
  cols <- .pricing_configured_columns(cfg)
  expect_equal(length(cols), 11)
  expect_true(all(c("tc", "g140", "Weight", "RespID") %in% cols))
  expect_equal(length(cfg$gabor_granger$price_sequence), 5)
  # An empty config counts nothing rather than erroring.
  expect_equal(length(.pricing_configured_columns(list())), 0)
})

test_that("the monadic model sheet carries the p-value caveat (F11)", {
  skip_if(!requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")
  caveat <- "Weighted fit: glm treats the weights as frequency weights."
  results <- list(
    demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.6, 0.3),
                              n = c(50, 50)),
    observed_data = data.frame(price = c(10, 20), n = c(50, 50),
                               observed_intent = c(0.6, 0.3)),
    optimal_price = list(price = 20, predicted_intent = 0.3, revenue_index = 6),
    model_summary = list(model_type = "logistic", n_observations = 100, aic = 120.5,
                         null_deviance = 130, residual_deviance = 110, pseudo_r2 = 0.15,
                         price_coefficient_p = 0.0000004, p_value_caveat = caveat),
    diagnostics = list(method = "monadic"))
  config <- list(analysis_method = "monadic", currency_symbol = "R",
                 project_name = "F11 caveat", output = list())
  validation <- list(n_total = 100, n_valid = 100, n_excluded = 0, n_warnings = 0,
                     warnings = list())
  out <- file.path(tempdir(), "pricing_f11_caveat.xlsx")
  unlink(out)
  on.exit(unlink(out), add = TRUE)
  invisible(capture.output(write_pricing_output(results, list(), validation, config, out)))
  ms <- openxlsx::read.xlsx(out, sheet = "Mon_Model_Summary", skipEmptyRows = FALSE)
  expect_true(any(grepl("caveat", ms[[1]], ignore.case = TRUE)))
  expect_true(any(grepl("frequency weights", ms[[2]], fixed = TRUE)))
})

test_that("01_config.R finds the shared saver from its own location (F12)", {
  cfg_file <- file.path(TURAS_ROOT, "modules", "pricing", "R", "01_config.R")
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  # A working directory with no Turas root above it, which is the condition
  # the cwd walk could not handle.
  elsewhere <- file.path(tempdir(), "pricing_f12_elsewhere")
  dir.create(elsewhere, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(elsewhere, recursive = TRUE), add = TRUE)
  writeLines(c(
    sprintf('setwd("%s")', elsewhere),
    sprintf('source("%s")', cfg_file),
    'cat(if (exists("turas_save_workbook_atomic", mode = "function")) "FOUND" else "MISSING", "\\n")'
  ), script)
  out <- suppressWarnings(system2("Rscript", c("--vanilla", shQuote(script)),
                                  stdout = TRUE, stderr = TRUE))
  out <- paste(out, collapse = "\n")
  expect_match(out, "FOUND")
  expect_false(grepl("IO_SAVER_NOT_FOUND", out, fixed = TRUE))
})

# ------------------------------------------------------------------------------
# F16: a deliverable refused after the run result was taken still changes it
# ------------------------------------------------------------------------------

test_that("a refused late deliverable is not reported as a clean PASS (F16)", {
  skip_if(!exists("run_pricing_analysis", mode = "function"), "pipeline not available")
  skip_if(!file.exists(example_script), "example generator not present")

  old <- getOption("turas.example.no_run")
  options(turas.example.no_run = TRUE)
  source(example_script, local = FALSE)
  options(turas.example.no_run = old)
  skip_if(!exists("write_pricing_config", mode = "function"), "config writer not available")

  out_dir <- file.path(tempdir(), "karoo_pricing_f16")
  unlink(out_dir, recursive = TRUE)
  capture.output(ex <- build_pricing_example(TURAS_ROOT, out_dir, verbose = FALSE,
                                             bootstrap_iterations = 20))

  # A Van Westendorp-only run has no demand curve, so step 9 refuses
  # DATA_SIMULATOR_NO_CURVE and writes nothing. The analysis itself is fine, so
  # before this fix the run closed at PASS with the refusal on the console and
  # nothing in run_result to show for it.
  cfg_path <- file.path(out_dir, "Karoo_VWonly_Sim.xlsx")
  capture.output(write_pricing_config(
    cfg_path, method = "van_westendorp",
    data_file = basename(ex$data_file),
    output_file = "Output/Karoo_VWonly_Results.xlsx",
    simulator = TRUE, stats_pack = FALSE, bootstrap_iterations = 20))

  capture.output(r <- run_pricing_analysis(cfg_path))
  expect_equal(r$run_result$status, "PARTIAL")
  events <- r$run_result$events %||% list()
  expect_gt(length(events), 0)
  codes <- vapply(events, function(e) as.character(e$code %||% ""), character(1))
  expect_true(any(grepl("SIMULATOR", codes)))
  # No simulator file was written, which is what the event is about.
  expect_null(r$simulator_path)

  # The control: the shipped both-methods config writes everything it promises
  # and still closes clean.
  capture.output(ok <- run_pricing_analysis(ex$config))
  expect_equal(ok$run_result$status, "PASS")
  expect_length(ok$run_result$events %||% list(), 0)
})

test_that("the simulator's own refusal reaches the run state (F16)", {
  skip_if(!exists("run_pricing_analysis", mode = "function"), "pipeline not available")
  # A Van Westendorp-only run asked for a simulator: step 9 refuses
  # DATA_SIMULATOR_NO_CURVE. Before the fix that reached the console only.
  src <- readLines(file.path(TURAS_ROOT, "modules", "pricing", "R", "00_main.R"))
  sim_block <- src[grep("^  sim_note <- function", src):length(src)]
  stop_at <- grep("^  simulator_path <- NULL", sim_block)[1]
  expect_true(length(stop_at) == 1 && stop_at > 1)
  expect_true(any(grepl("turas_run_state_partial", sim_block[seq_len(stop_at)])))

  # And the run result is rebuilt after the late steps, not before them.
  rebuild <- grep("run_result <- turas_run_state_result\\(trs_state\\)", src)
  snapshot <- grep("TRS: Get run result \\(before output generation\\)", src)
  step9 <- grep("9\\. Building the standalone simulator", src)
  expect_true(length(rebuild) >= 1)
  expect_true(any(rebuild > step9))
  expect_true(all(snapshot < step9))
})
