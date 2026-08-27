# ==============================================================================
# TESTS: HB / LATENT CLASS UNCERTAINTY AND UTILITY EXTRACTION
# ==============================================================================
#
# Covers review findings C1 and C3:
#
#   C1 — latent-class runs fell through to the aggregate extractor, which
#        cannot parse "Attribute_Level" coefficient names, and produced an
#        all-zero utilities table labelled PASS.
#   C3 — "SE", CIs, p-values and stars on every HB/LC run were computed from
#        the between-respondent heterogeneity SD, not the posterior standard
#        error of the population mean.
#
# Plus the aggregate-path CI bug found while fixing them: calculate_ci()
# inherited the level name onto its own "lower"/"upper" names, so every
# aggregate CI was NA.
# ==============================================================================

# ---------------------------------------------------------------------------
# A synthetic HB-shaped model result: coefficients named Attribute_Level, a
# per-respondent beta matrix, and a posterior SE that is much smaller than the
# heterogeneity SD (which is what an honest fit looks like).
# ---------------------------------------------------------------------------
make_fake_hb_result <- function(method = "hierarchical_bayes",
                                n_respondents = 60,
                                seed = 3) {
  set.seed(seed)

  attributes <- list(
    Brand = c("Alpha", "Beta", "Gamma"),
    Size  = c("Small", "Large")
  )
  col_names <- c("Brand_Beta", "Brand_Gamma", "Size_Large")
  true_means <- c(Brand_Beta = 0.8, Brand_Gamma = -0.3, Size_Large = 0.5)

  individual_betas <- sapply(col_names, function(cn) {
    rnorm(n_respondents, mean = true_means[[cn]], sd = 0.9)
  })
  rownames(individual_betas) <- paste0("R", seq_len(n_respondents))

  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    stringsAsFactors = FALSE
  )
  attr_df$levels_list <- unname(attributes)

  config <- list(
    attributes = attr_df,
    confidence_level = 0.95,
    zero_center_utilities = FALSE
  )

  heterogeneity_sd <- apply(individual_betas, 2, sd)

  model <- structure(list(
    method = method,
    coefficients = colMeans(individual_betas),
    std_errors = heterogeneity_sd / sqrt(n_respondents),
    heterogeneity_sd = heterogeneity_sd,
    individual_betas = individual_betas,
    col_names = col_names,
    attribute_map = setNames(
      list(list(attribute = "Brand", level = "Beta"),
           list(attribute = "Brand", level = "Gamma"),
           list(attribute = "Size",  level = "Large")),
      col_names
    )
  ), class = "turas_conjoint_model")

  list(model = model, config = config, col_names = col_names,
       n_respondents = n_respondents)
}

# ---------------------------------------------------------------------------
# C1
# ---------------------------------------------------------------------------

test_that("C1: latent-class results no longer produce an all-zero utilities table", {
  f <- make_fake_hb_result(method = "latent_class")

  utils_df <- calculate_utilities(f$model, f$config, verbose = FALSE)

  expect_s3_class(utils_df, "data.frame")
  expect_equal(nrow(utils_df), 5)  # 3 Brand levels + 2 Size levels

  non_baseline <- utils_df[!utils_df$is_baseline, ]
  expect_equal(nrow(non_baseline), 3)
  expect_false(all(non_baseline$Utility == 0))

  # And the values are the model's, not zeros
  expect_equal(
    utils_df$Utility[utils_df$Level == "Beta"],
    unname(f$model$coefficients[["Brand_Beta"]]),
    tolerance = 1e-8
  )
})

test_that("C1: importance from a latent-class run is non-zero", {
  f <- make_fake_hb_result(method = "latent_class")
  utils_df <- calculate_utilities(f$model, f$config, verbose = FALSE)

  imp <- calculate_attribute_importance(utils_df, f$config, verbose = FALSE)

  expect_true(all(imp$Importance >= 0))
  expect_gt(sum(imp$Importance), 99)
  expect_false(all(imp$Importance == 0))
})

test_that("C1: an all-zero extraction refuses instead of shipping zeros", {
  f <- make_fake_hb_result(method = "latent_class")

  # Coefficient names that match no level: exactly the failure C1 described.
  broken <- f$model
  broken$coefficients <- setNames(c(0.8, -0.3, 0.5), c("Zzz_1", "Zzz_2", "Zzz_3"))
  broken$col_names <- c("Zzz_1", "Zzz_2", "Zzz_3")
  broken$std_errors <- c(0.1, 0.1, 0.1)
  broken$heterogeneity_sd <- c(0.9, 0.9, 0.9)

  # TRS refusals are raised as conditions, so this must be caught, not returned.
  cond <- tryCatch(
    {
      calculate_utilities(broken, f$config, verbose = FALSE)
      NULL
    },
    turas_refusal = function(e) e
  )

  expect_false(is.null(cond))
  expect_equal(cond$code, "CALC_ALL_ZERO_UTILITIES")
  expect_match(conditionMessage(cond), "exactly zero")
})

# ---------------------------------------------------------------------------
# C3
# ---------------------------------------------------------------------------

test_that("C3: extract_hb_utilities reports SE and heterogeneity as separate columns", {
  f <- make_fake_hb_result()

  u <- extract_hb_utilities(f$model, f$config, verbose = FALSE)

  expect_true(all(c("Std_Error", "Heterogeneity_SD", "SE") %in% names(u)))

  non_baseline <- u[!u$is_baseline, ]

  # The standard error of the mean must be much smaller than the spread of
  # preferences across respondents. This is the whole point of C3: they were
  # the same number.
  expect_true(all(non_baseline$Std_Error < non_baseline$Heterogeneity_SD))
  expect_lt(mean(non_baseline$Std_Error), mean(non_baseline$Heterogeneity_SD) / 3)

  # SE is an alias of Std_Error, not of heterogeneity.
  expect_equal(non_baseline$SE, non_baseline$Std_Error)
})

test_that("C3: CIs are built from the standard error, not the heterogeneity SD", {
  f <- make_fake_hb_result()
  u <- extract_hb_utilities(f$model, f$config, verbose = FALSE)

  nb <- u[!u$is_baseline, ]
  z <- qnorm(0.975)

  expect_equal(nb$CI_Upper - nb$CI_Lower, 2 * z * nb$Std_Error, tolerance = 1e-8)
  expect_true(all((nb$CI_Upper - nb$CI_Lower) < 2 * z * nb$Heterogeneity_SD))
})

test_that("C3: a zero or missing SE yields NA uncertainty, not p = 0 and three stars", {
  f <- make_fake_hb_result()

  # This is the shape 13_latent_class.R used to pass for class-level utilities.
  class_model <- list(
    coefficients = f$model$coefficients,
    std_errors = rep(0, length(f$col_names)),
    heterogeneity_sd = rep(NA_real_, length(f$col_names)),
    col_names = f$col_names,
    attribute_map = f$model$attribute_map
  )

  u <- extract_hb_utilities(class_model, f$config, verbose = FALSE)
  nb <- u[!u$is_baseline, ]

  expect_true(all(is.na(nb$p_value)))
  expect_true(all(is.na(nb$Std_Error)))
  expect_true(all(nb$Significance == ""))
})

test_that("C3: the latent class extractor passes NA rather than zero SEs per class", {
  src <- readLines(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint",
                             "R", "13_latent_class.R"), warn = FALSE)
  src <- paste(src, collapse = "\n")
  expect_false(grepl("std_errors = rep(0, length(lc$class_betas[c, ]))", src, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# The aggregate-path CI bug found alongside C3
# ---------------------------------------------------------------------------

test_that("aggregate path: confidence intervals are populated, not NA", {
  coefs <- c(BrandBeta = 0.8, BrandGamma = -0.3, SizeLarge = 0.5)
  ses   <- c(BrandBeta = 0.2, BrandGamma = 0.2, SizeLarge = 0.15)

  attributes <- list(Brand = c("Alpha", "Beta", "Gamma"), Size = c("Small", "Large"))
  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    stringsAsFactors = FALSE
  )
  attr_df$levels_list <- unname(attributes)
  config <- list(attributes = attr_df, confidence_level = 0.95)

  u <- extract_attribute_utilities("Brand", coefs, ses, config, model_result = NULL)

  nb <- u[!u$is_baseline, ]
  expect_false(any(is.na(nb$CI_Lower)))
  expect_false(any(is.na(nb$CI_Upper)))
  expect_true(all(nb$CI_Lower < nb$Utility))
  expect_true(all(nb$CI_Upper > nb$Utility))
})

test_that("calculate_ci does not inherit the estimate's name", {
  ci <- calculate_ci(unname(c(Beta = 0.8)), 0.2, 0.95)
  expect_equal(names(ci), c("lower", "upper"))
  expect_false(is.na(ci["lower"]))
})

test_that("aggregate and HB utilities share the same column contract", {
  f <- make_fake_hb_result()
  hb <- extract_hb_utilities(f$model, f$config, verbose = FALSE)

  coefs <- c(BrandBeta = 0.8, BrandGamma = -0.3)
  ses   <- c(BrandBeta = 0.2, BrandGamma = 0.2)
  agg <- extract_attribute_utilities("Brand", coefs, ses, f$config, model_result = NULL)

  shared <- c("Attribute", "Level", "Utility", "Std_Error", "SE",
              "Heterogeneity_SD", "CI_Lower", "CI_Upper", "p_value",
              "Significance", "is_baseline")
  expect_true(all(shared %in% names(hb)))
  expect_true(all(shared %in% names(agg)))
})
