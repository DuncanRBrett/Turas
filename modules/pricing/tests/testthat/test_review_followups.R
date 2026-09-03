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
