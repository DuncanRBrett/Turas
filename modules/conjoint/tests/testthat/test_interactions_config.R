# ==============================================================================
# TESTS: INTERACTIONS ARE CONFIGURABLE, ANALYSED, AND NOT SILENTLY DROPPED
# ==============================================================================
#
# Review finding H6: interaction_terms was never copied out of the Settings
# sheet, so config$interaction_terms was always NULL and a user who configured
# Brand:Price got a main-effects analysis in silence. The template wrote
# auto_detect_interactions while the code read interaction_auto_detect.
# analyze_interaction() searched for "Brand_x_Price" among coefficients that
# mlogit names "BrandBeta:Price$20", so every interaction analysis came back
# empty. And the utilities extractor drops ":"-named coefficients, so the
# simulator would have simulated main effects from an interaction model.
# ==============================================================================

test_that("H6: interaction settings reach the config object", {
  settings <- list(
    interaction_terms = "Brand:Price",
    auto_detect_interactions = "TRUE",
    interaction_max = "4"
  )

  # Build only the fields under test, the way load_conjoint_config does.
  cfg <- list(
    interaction_terms = settings$interaction_terms %||% "",
    interaction_auto_detect = safe_logical(
      settings$auto_detect_interactions %||% settings$interaction_auto_detect,
      default = FALSE
    ),
    interaction_max = safe_numeric(settings$interaction_max, 3)
  )

  expect_equal(cfg$interaction_terms, "Brand:Price")
  expect_true(cfg$interaction_auto_detect)
  expect_equal(cfg$interaction_max, 4)
})

test_that("H6: the loader reads both spellings of the auto-detect setting", {
  src <- paste(readLines(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint",
                                   "R", "01_config.R"), warn = FALSE), collapse = "\n")
  expect_true(grepl("settings_list$interaction_terms", src, fixed = TRUE))
  expect_true(grepl("settings_list$auto_detect_interactions", src, fixed = TRUE))
  expect_true(grepl("settings_list$interaction_auto_detect", src, fixed = TRUE))
})

test_that("H6: parse_interactions_from_config produces a spec once the field exists", {
  attr_df <- data.frame(
    AttributeName = c("Brand", "Price", "Size"),
    NumLevels = c(3L, 2L, 2L),
    stringsAsFactors = FALSE
  )
  config <- list(
    attributes = attr_df,
    interaction_terms = "Brand:Price",
    interaction_auto_detect = FALSE,
    interaction_max = 3
  )

  spec <- parse_interactions_from_config(config)

  expect_false(is.null(spec))
  expect_equal(spec$n_interactions, 1)
  expect_equal(spec$interactions[[1]], c("Brand", "Price"))
})

test_that("H6: interaction coefficients are matched by mlogit's colon convention", {
  coef_names <- c(
    "BrandBeta", "BrandGamma", "Price$20",
    "BrandBeta:Price$20", "BrandGamma:Price$20",
    "SizeLarge"
  )

  mask <- .match_interaction_coefficients(coef_names, c("Brand", "Price"))

  expect_equal(coef_names[mask], c("BrandBeta:Price$20", "BrandGamma:Price$20"))

  # The old internal name is not what mlogit produces, and must not match.
  expect_false(any(grepl("Brand_x_Price", coef_names, fixed = TRUE)))
})

test_that("H6: analyze_interaction finds the coefficients it used to miss", {
  model <- list(
    has_interactions = TRUE,
    coefficients = c(
      BrandBeta = 0.5, "Price$20" = -0.4,
      "BrandBeta:Price$20" = 0.3
    ),
    std_errors = c(
      BrandBeta = 0.1, "Price$20" = 0.1,
      "BrandBeta:Price$20" = 0.12
    )
  )

  res <- analyze_interaction(model, c("Brand", "Price"), config = list())

  expect_equal(nrow(res), 1)
  expect_equal(res$Combination, "BrandBeta:Price$20")
  expect_equal(res$Coefficient, 0.3)
  expect_equal(res$Std_Error, 0.12)
  expect_false(is.na(res$P_Value))
})

test_that("H6: the simulator refuses a with-interactions utilities table", {
  utilities <- data.frame(
    Attribute = c("Brand", "Brand", "Price", "Price"),
    Level = c("Alpha", "Beta", "$10", "$20"),
    Utility = c(0, 0.5, 0, -0.4),
    stringsAsFactors = FALSE
  )
  attr(utilities, "has_interactions") <- TRUE
  attr(utilities, "dropped_interaction_coefs") <- "BrandBeta:Price$20"

  products <- list(list(Brand = "Beta", Price = "$20"))

  cond <- tryCatch(
    { predict_market_shares(products, utilities, verbose = FALSE); NULL },
    turas_refusal = function(e) e
  )

  expect_false(is.null(cond))
  expect_equal(cond$code, "CALC_INTERACTIONS_NOT_IN_SIMULATOR")
})

test_that("H6: a main-effects utilities table still simulates", {
  utilities <- data.frame(
    Attribute = c("Brand", "Brand", "Price", "Price"),
    Level = c("Alpha", "Beta", "$10", "$20"),
    Utility = c(0, 0.5, 0, -0.4),
    stringsAsFactors = FALSE
  )

  products <- list(
    list(Brand = "Beta", Price = "$20"),
    list(Brand = "Alpha", Price = "$10")
  )

  shares <- predict_market_shares(products, utilities, verbose = FALSE)

  expect_true(is.list(shares) || is.data.frame(shares))
})

test_that("H6: dropped interaction coefficients are announced, not swallowed", {
  attributes <- list(Brand = c("Alpha", "Beta"), Price = c("$10", "$20"))
  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    stringsAsFactors = FALSE
  )
  attr_df$levels_list <- unname(attributes)

  model <- list(
    method = "mlogit",
    coefficients = c(BrandBeta = 0.5, "Price$20" = -0.4, "BrandBeta:Price$20" = 0.3),
    std_errors = c(BrandBeta = 0.1, "Price$20" = 0.1, "BrandBeta:Price$20" = 0.12)
  )
  config <- list(attributes = attr_df, confidence_level = 0.95,
                 zero_center_utilities = TRUE)

  out <- capture.output(
    u <- calculate_utilities(model, config, verbose = FALSE),
    type = "output"
  )

  expect_true(any(grepl("CONJ_INTERACTIONS_NOT_IN_UTILITIES", out)))
  expect_true(isTRUE(attr(u, "has_interactions")))
  expect_equal(attr(u, "dropped_interaction_coefs"), "BrandBeta:Price$20")
})

# ---------------------------------------------------------------------------
# The report keeps everything except the simulator
# ---------------------------------------------------------------------------

test_that("H6: the report is built without its simulator, not skipped entirely", {
  root <- Sys.getenv("TURAS_ROOT")
  main <- paste(readLines(file.path(root, "modules", "conjoint", "R", "00_main.R"),
                          warn = FALSE), collapse = "\n")

  # The gate is on the SIMULATOR, which is what cannot represent an
  # interaction model — not on everything the run produces. (Between these two
  # changes the whole HTML report was skipped, which threw away a valid
  # importance table and diagnostics; that report has since been retired
  # altogether, and the gate now lives in the standalone simulator builder.)
  expect_false(grepl("TURAS: HTML REPORT SKIPPED", main, fixed = TRUE))

  sim <- paste(readLines(file.path(root, "modules", "conjoint", "lib",
                                   "html_simulator", "99_simulator_main.R"),
                         warn = FALSE), collapse = "\n")
  expect_true(grepl("CALC_INTERACTIONS_NOT_IN_SIMULATOR", sim, fixed = TRUE))
  expect_true(grepl('attr(utilities, "has_interactions")', sim, fixed = TRUE))

  # The limitation must reach the warning list, because the final status is
  # computed from the warning count — otherwise the run announces a PARTIAL
  # event and then reports PASS.
  expect_true(grepl("interaction_warning", main, fixed = TRUE))
})

