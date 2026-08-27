# ==============================================================================
# TESTS: CONFIG PARSING AND STATS PACK HONESTY (M1, M2, M3, M5)
# ==============================================================================

root <- Sys.getenv("TURAS_ROOT")
read_src <- function(...) paste(readLines(file.path(root, ...), warn = FALSE), collapse = "\n")

# ---------------------------------------------------------------------------
# M5 — unknown and duplicate setting names
# ---------------------------------------------------------------------------

test_that("M5: the known-settings list is derived from the code, not hand-written", {
  known <- .known_conjoint_settings()

  expect_gt(length(known), 40)
  # Names that are genuinely read must all be present — a hand-list drifts and
  # then warns about settings that work.
  for (s in c("estimation_method", "baseline_handling", "generate_market_simulator",
              "include_diagnostics", "wtp_price_attribute", "hb_iterations",
              "interaction_terms", "zero_center_utilities")) {
    expect_true(s %in% known, info = s)
  }
})

test_that("M5: an unrecognised setting name is reported with a suggestion", {
  out <- capture.output(
    .report_unknown_settings(c("estimation_method", "estimation_metod"), verbose = TRUE),
    type = "output"
  )
  txt <- paste(out, collapse = "\n")

  expect_true(grepl("CFG_UNKNOWN_SETTING", txt, fixed = TRUE))
  expect_true(grepl("estimation_metod", txt, fixed = TRUE))
  expect_true(grepl("did you mean 'estimation_method'", txt, fixed = TRUE))
})

test_that("M5: recognised settings produce no warning at all", {
  out <- capture.output(
    .report_unknown_settings(c("estimation_method", "hb_iterations"), verbose = TRUE),
    type = "output"
  )
  expect_equal(length(out), 0)
})

test_that("M5: the shipped example config produces no unknown-setting warnings", {
  cfg_path <- file.path(root, "modules", "conjoint", "examples", "example_config.xlsx")
  skip_if(!file.exists(cfg_path), "example config not found")

  out <- capture.output(
    cfg <- load_conjoint_config(cfg_path, verbose = FALSE),
    type = "output"
  )

  expect_false(any(grepl("CFG_UNKNOWN_SETTING", out, fixed = TRUE)))
})

test_that("M5: a duplicated setting refuses rather than picking the first", {
  src <- read_src("modules", "conjoint", "R", "01_config.R")
  expect_true(grepl("CFG_DUPLICATE_SETTING", src, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# M3 — zero-centring and base_level_method
# ---------------------------------------------------------------------------

test_that("M3: the aggregate path honours zero_center_utilities", {
  coefs <- c(BrandBeta = 0.9, BrandGamma = 0.3)
  ses   <- c(BrandBeta = 0.1, BrandGamma = 0.1)

  attributes <- list(Brand = c("Alpha", "Beta", "Gamma"))
  attr_df <- data.frame(AttributeName = "Brand", NumLevels = 3L,
                        stringsAsFactors = FALSE)
  attr_df$levels_list <- unname(attributes)

  centred <- extract_attribute_utilities(
    "Brand", coefs, ses,
    list(attributes = attr_df, confidence_level = 0.95,
         zero_center_utilities = TRUE),
    model_result = NULL
  )
  raw <- extract_attribute_utilities(
    "Brand", coefs, ses,
    list(attributes = attr_df, confidence_level = 0.95,
         zero_center_utilities = FALSE),
    model_result = NULL
  )

  # Centred: the three levels sum to zero. Raw: the baseline is zero.
  expect_equal(sum(centred$Utility), 0, tolerance = 1e-9)
  expect_equal(raw$Utility[raw$Level == "Alpha"], 0, tolerance = 1e-9)
  expect_equal(raw$Utility[raw$Level == "Beta"], 0.9, tolerance = 1e-9)
  expect_false(isTRUE(all.equal(centred$Utility, raw$Utility)))
})

test_that("M3: base_level_method is gone from the config surface", {
  # It advertised effects coding, which this module does not implement, and
  # nothing read the setting.
  cfg <- read_src("modules", "conjoint", "R", "01_config.R")
  tpl <- read_src("modules", "conjoint", "R", "12_config_template.R")

  expect_false(grepl("base_level_method = settings_list", cfg, fixed = TRUE))
  expect_false(grepl('must be \'first\', \'last\', or \'effects\'', cfg, fixed = TRUE))
  expect_false(grepl('add("ESTIMATION METHOD", "base_level_method"', tpl, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# M1 / M2 — stats pack
# ---------------------------------------------------------------------------

test_that("M1: the stats pack no longer credits ChoiceModelR", {
  src <- read_src("modules", "conjoint", "R", "00_main.R")

  # ChoiceModelR appears nowhere in this module and is not in renv.lock; the
  # HB engine is bayesm.
  expect_false(grepl("ChoiceModelR", src, fixed = TRUE))
  expect_true(grepl("bayesm::rhierMnlRwMixture (HB)", src, fixed = TRUE))
  expect_true(grepl("mlogit (MNL)", src, fixed = TRUE))
  expect_true(grepl("survival::clogit (MNL)", src, fixed = TRUE))
})

test_that("M1: the packages list follows the method that ran", {
  src <- read_src("modules", "conjoint", "R", "00_main.R")
  expect_false(grepl('packages         = c("openxlsx", "mlogit", "survival", "dfidx")',
                     src, fixed = TRUE))
  expect_true(grepl("packages         = packages_used", src, fixed = TRUE))
})

test_that("M1: WTP status is read from the result, not from settings that do not exist", {
  src <- read_src("modules", "conjoint", "R", "00_main.R")
  expect_false(grepl("isTRUE(config$enable_wtp)", src, fixed = TRUE))
  expect_true(grepl("wtp_flag    <- !is.null(wtp_result)", src, fixed = TRUE))
})

test_that("M1: fit statistics are read from where they are actually attached", {
  src <- read_src("modules", "conjoint", "R", "00_main.R")
  expect_true(grepl("fit_stats <- diagnostics$fit_statistics", src, fixed = TRUE))
  # calculate_choice_fit_stats returns log_likelihood_fitted, not log_likelihood
  expect_true(grepl("fit_stats$log_likelihood_fitted", src, fixed = TRUE))

  util <- read_src("modules", "conjoint", "R", "04_utilities.R")
  expect_true(grepl("log_likelihood_fitted = ll_fitted", util, fixed = TRUE))
})

test_that("M2: the stats pack can be switched off from the config", {
  src <- read_src("modules", "conjoint", "R", "00_main.R")

  # The old form read only the capitalised name, defaulted a miss to "Y", and
  # OR'd in a checkbox that can only turn the pack on.
  expect_false(grepl('toupper(config$settings$Generate_Stats_Pack %||% "Y") == "Y"',
                     src, fixed = TRUE))
  expect_true(grepl(".settings_lookup(config$settings, \"generate_stats_pack\")",
                    src, fixed = TRUE))
})
