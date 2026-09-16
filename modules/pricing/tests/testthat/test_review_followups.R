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
