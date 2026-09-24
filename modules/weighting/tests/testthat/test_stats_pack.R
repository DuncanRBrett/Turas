# ==============================================================================
# TESTS: generate_weighting_stats_pack() (run_weighting.R)
# ==============================================================================
# Review 2026-09-24 found three wrong figures in the weighting stats pack:
#   1. The headline "Effective N after weighting" and "DEFF" rows described the
#      first weight in the config with no label, so a design weight listed
#      before a rim weight reported the design weight's near-perfect figures.
#   2. When a weight failed (PARTIAL run), the excluded count read 0: the
#      failed weight has no column, and OR-ing its zero-length test into the
#      mask collapsed the whole mask.
#   3. The Declaration said "No, unweighted analysis" on every weighting run.
# These tests call the stats pack builder directly with hand-built results.
# ==============================================================================

#' A weight_results entry for a weight that was calculated
make_weight_result <- function(effective_n, design_effect) {
  list(diagnostics = list(
    effective_sample = list(effective_n = effective_n, design_effect = design_effect,
                            efficiency = 100 / design_effect),
    quality = list(status = "GOOD")))
}

#' A weight_results entry for a weight that failed (the run_weighting() placeholder)
make_failed_weight_result <- function(n_rows) {
  list(weights = rep(NA_real_, n_rows), diagnostics = NULL, error = TRUE)
}

#' Build the pack and read back one sheet as label/value pairs
build_pack <- function(data, weight_names, weight_results) {
  out_dir <- tempfile("stats_pack_")
  dir.create(out_dir)
  config <- list(
    general = list(project_name = "Stats pack test",
                   output_file_resolved = file.path(out_dir, "weights.xlsx")),
    weight_specifications = data.frame(
      weight_name = c("design_wt", "rim_wt"), method = c("design", "rim"),
      stringsAsFactors = FALSE))
  path <- generate_weighting_stats_pack(config, data, weight_names, weight_results,
                                        run_state = NULL, start_time = proc.time(),
                                        verbose = FALSE)
  expect_true(file.exists(path))
  path
}

read_pack_rows <- function(path, sheet) {
  d <- openxlsx::read.xlsx(path, sheet = sheet, colNames = FALSE, skipEmptyRows = FALSE)
  stats::setNames(as.character(d[[2]]), as.character(d[[1]]))
}

# 1,000 respondents; 50 have no design weight (unmatched cells).
pack_data <- data.frame(id = 1:1000, design_wt = c(rep(NA_real_, 50), rep(1, 950)))

test_that("a failed weight does not hide the respondents another weight excludes", {
  results <- list(design_wt = make_weight_result(950, 1.0),
                  rim_wt = make_failed_weight_result(1000))
  path <- build_pack(pack_data, c("design_wt", "rim_wt"), results)

  declaration <- read_pack_rows(path, "Declaration")
  expect_match(declaration[["Respondents Analysed"]], "50 excluded")
})

test_that("the Declaration names the weights the run produced, not 'unweighted'", {
  results <- list(design_wt = make_weight_result(950, 1.0),
                  rim_wt = make_failed_weight_result(1000))
  path <- build_pack(pack_data, c("design_wt", "rim_wt"), results)

  declaration <- read_pack_rows(path, "Declaration")
  expect_equal(declaration[["Weighting"]], "Yes, weight variable: design_wt")
})

test_that("Weights Calculated says which weight failed instead of listing it as calculated", {
  results <- list(design_wt = make_weight_result(950, 1.0),
                  rim_wt = make_failed_weight_result(1000))
  path <- build_pack(pack_data, c("design_wt", "rim_wt"), results)

  assumptions <- read_pack_rows(path, "Assumptions")
  expect_equal(assumptions[["Weights Calculated"]],
               "design_wt (design); rim_wt (failed, not written)")
})

test_that("with several weights the headline Effective N and DEFF name their weight", {
  data <- data.frame(id = 1:1000, design_wt = 1, rim_wt = 1)
  results <- list(design_wt = make_weight_result(1000, 1.0),
                  rim_wt = make_weight_result(554, 1.805))
  path <- build_pack(data, c("design_wt", "rim_wt"), results)

  assumptions <- read_pack_rows(path, "Assumptions")
  expect_equal(assumptions[["Effective N after weighting"]], "1,000 (design_wt)")
  expect_equal(assumptions[["DEFF"]], "1.000 (design_wt)")
  expect_match(assumptions[["Per-weight diagnostics"]], "rim_wt: eff_n=554, DEFF=1.805")
})

test_that("with one weight the headline rows are unchanged", {
  data <- data.frame(id = 1:1000, rim_wt = 1)
  results <- list(rim_wt = make_weight_result(554, 1.805))
  path <- build_pack(data, "rim_wt", results)

  assumptions <- read_pack_rows(path, "Assumptions")
  expect_equal(assumptions[["Effective N after weighting"]], "554")
  expect_equal(assumptions[["DEFF"]], "1.805")
})
