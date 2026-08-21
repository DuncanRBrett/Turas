# ==============================================================================
# PRE-FLIGHT WIRING + REACHABLE DESIGN OPT-INS (review 2026-08-21, I-22 / I-23)
# ==============================================================================
# Two fixes of the same class — validation refusing what the engine would allow,
# and validation that never ran at all:
#
#  I-22  validation/preflight_validators.R was absent from run_weighting.R's
#        source whitelist, so validate_weighting_preflight() and its 14 checks
#        never executed in a real run while a 482-line test suite kept passing
#        against them. The loader also skipped missing files silently, which is
#        how that went unnoticed.
#
#  I-23  validate_design_config() refused unconditionally and ran BEFORE the
#        engine read allow_unmatched / allow_empty_targets, so the refusal told
#        the operator to set a flag that then changed nothing.

turas_root <- rprojroot::find_root(rprojroot::has_dir(".git"))
wlib <- file.path(turas_root, "modules", "weighting", "lib")

suppressWarnings({
  try(source(file.path(turas_root, "modules/shared/lib/trs_refusal.R")), silent = TRUE)
  for (f in c("00_guard.R", "validation.R", "config_loader.R",
              "validation/preflight_validators.R")) {
    try(source(file.path(wlib, f)), silent = TRUE)
  }
})

# A stratified frame with a target category nobody is in ("East"), which trips
# both the empty-target checks at once.
design_fixture <- function() {
  list(
    data = data.frame(region = c(rep("North", 60), rep("South", 40)),
                      stringsAsFactors = FALSE),
    targets = data.frame(
      weight_name = "w1", stratum_variable = "region",
      stratum_category = c("North", "South", "East"),
      population_size = c(10000, 8000, 5000), stringsAsFactors = FALSE)
  )
}

context("I-23 — design weight opt-ins are reachable")

test_that("an empty target stratum refuses by default", {
  f <- design_fixture()
  res <- validate_design_config(f$data, f$targets, "w1")
  expect_false(res$valid)
  expect_gt(length(res$errors), 0)
})

test_that("allow_empty_targets clears the empty stratum instead of dead-ending", {
  f <- design_fixture()
  res <- validate_design_config(f$data, f$targets, "w1", allow_empty_targets = TRUE)
  # The whole point: the config the refusal told you to fix with this flag now
  # actually passes, and the condition is reported as a warning rather than lost.
  expect_true(res$valid)
  expect_equal(length(res$errors), 0)
  expect_gt(length(res$warnings), 0)
  expect_true(any(grepl("redistributed", res$warnings)))
})

test_that("allow_unmatched clears data categories that have no target", {
  # Data has a category the targets never mention -> those respondents cannot be
  # stratified. That is the allow_unmatched case.
  data <- data.frame(region = c(rep("North", 50), rep("South", 30), rep("West", 20)),
                     stringsAsFactors = FALSE)
  targets <- data.frame(weight_name = "w1", stratum_variable = "region",
                        stratum_category = c("North", "South"),
                        population_size = c(10000, 8000), stringsAsFactors = FALSE)

  strict <- validate_design_config(data, targets, "w1")
  expect_false(strict$valid)

  relaxed <- validate_design_config(data, targets, "w1", allow_unmatched = TRUE)
  expect_true(relaxed$valid)
  expect_gt(length(relaxed$warnings), 0)
})

test_that("the opt-ins do not excuse genuinely broken config", {
  # A flag says "I know about the empty cell", not "skip validation". A stratum
  # variable that is not in the data at all must still refuse with both flags on.
  data <- data.frame(province = rep("Gauteng", 20), stringsAsFactors = FALSE)
  targets <- data.frame(weight_name = "w1", stratum_variable = "region",
                        stratum_category = "North", population_size = 100,
                        stringsAsFactors = FALSE)
  res <- validate_design_config(data, targets, "w1",
                                allow_unmatched = TRUE, allow_empty_targets = TRUE)
  expect_false(res$valid)
  expect_true(any(grepl("not found in data", res$errors)))
})

test_that("a duplicate stratum category still refuses with both flags on", {
  f <- design_fixture()
  dup <- rbind(f$targets, f$targets[1, ])
  res <- validate_design_config(f$data, dup, "w1",
                                allow_unmatched = TRUE, allow_empty_targets = TRUE)
  expect_false(res$valid)
  expect_true(any(grepl("[Dd]uplicate", res$errors)))
})

context("I-22 — pre-flight is wired in and advisory")

test_that("the loader now sources the preflight file", {
  loader <- readLines(file.path(turas_root, "modules/weighting/run_weighting.R"))
  expect_true(any(grepl("preflight_validators.R", loader, fixed = TRUE)))
  # ...and refuses rather than silently skipping a missing file, which is what
  # let the layer stay dead in the first place.
  expect_true(any(grepl("Required module file not found", loader, fixed = TRUE)))
})

test_that("run_weighting calls the preflight before the weight loop", {
  loader <- readLines(file.path(turas_root, "modules/weighting/run_weighting.R"))
  call_line <- grep("validate_weighting_preflight\\(config, data\\)", loader)
  loop_line <- grep("^  for \\(i in seq_len\\(nrow\\(weight_specs\\)\\)\\)", loader)
  expect_length(call_line, 1)
  expect_length(loop_line, 1)
  expect_lt(call_line[1], loop_line[1])
})

test_that("report_preflight_findings prints findings without refusing", {
  log <- data.frame(
    Check = c("Cell Combinations vs Data", "Colour Codes"),
    Issue = c("Cell Combination Not in Data", "Invalid Colour"),
    Detail = c("Weight 'w1': combination x has zero respondents", "brand_colour is not a hex code"),
    Context = c("w1", ""),
    Severity = c("Error", "Warning"),
    stringsAsFactors = FALSE
  )
  out <- capture.output(res <- report_preflight_findings(log))
  expect_null(res)                                   # advisory: returns, never stops
  expect_true(any(grepl("PRE-FLIGHT", out)))
  expect_true(any(grepl("does not stop the run", out)))
  expect_true(any(grepl("zero respondents", out)))
  expect_true(any(grepl("WOULD BLOCK", out)))        # errors flagged, not enforced
})

test_that("an empty or absent findings log prints nothing at all", {
  expect_length(capture.output(report_preflight_findings(NULL)), 0)
  expect_length(capture.output(report_preflight_findings(data.frame())), 0)
})

test_that("a long findings list is capped rather than flooding the console", {
  log <- data.frame(
    Check = rep("Cell Combinations vs Data", 25),
    Issue = rep("Cell Combination Not in Data", 25),
    Detail = sprintf("combination %d has zero respondents", seq_len(25)),
    Context = rep("w1", 25), Severity = rep("Error", 25),
    stringsAsFactors = FALSE
  )
  out <- capture.output(report_preflight_findings(log, max_per_severity = 5))
  expect_true(any(grepl("and 20 more", out)))
  expect_false(any(grepl("combination 25 has", out)))
})

test_that("an empty cell is reported at the severity the engine will apply", {
  # With allow_empty_targets set for the weight, the cell engine redistributes
  # rather than refusing, so preflight must not log an Error it will not act on
  # - that was the contradiction that made wiring this layer in unsafe.
  cell_df <- data.frame(weight_name = "w1", region = "East", target_percent = 10,
                        stringsAsFactors = FALSE)
  data <- data.frame(region = c(rep("North", 10), rep("South", 10)),
                     stringsAsFactors = FALSE)

  strict <- check_cell_combinations_vs_data(cell_df, data, NULL, config = NULL)
  expect_equal(strict$Severity[nrow(strict)], "Error")

  # A config whose Advanced_Settings opts in for this weight.
  # advanced_settings is WIDE: weight_name plus one column per setting.
  cfg <- list(advanced_settings = data.frame(
    weight_name = "w1", allow_empty_targets = "YES",
    stringsAsFactors = FALSE))
  relaxed <- check_cell_combinations_vs_data(cell_df, data, NULL, config = cfg)
  expect_equal(relaxed$Severity[nrow(relaxed)], "Info")
  expect_true(grepl("redistributed", relaxed$Detail[nrow(relaxed)]))
})
