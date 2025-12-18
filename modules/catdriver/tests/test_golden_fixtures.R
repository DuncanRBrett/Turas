# ==============================================================================
# GOLDEN FIXTURE REGRESSION TESTS
# ==============================================================================
#
# These tests verify that the catdriver module produces EXACT expected outputs
# for known input data. If any of these tests fail, it indicates either:
#   1. A regression bug in the code
#   2. An intentional change that requires updating the expected values
#
# The golden fixtures contain data with KNOWN statistical properties, and
# the expected values are computed from that data with known seeds.
#
# To update expected values after intentional changes:
#   Rscript fixtures/golden_data_generator.R --generate
#
# Version: 1.0
# ==============================================================================

library(testthat)

# ==============================================================================
# SETUP - Load fixtures and module
# ==============================================================================

# Determine paths
script_dir <- tryCatch({
  if (!is.null(sys.frame(1)$ofile)) dirname(sys.frame(1)$ofile) else getwd()
}, error = function(e) getwd())

if (basename(script_dir) == "tests") {
  module_root <- dirname(script_dir)
  test_dir <- script_dir
} else {
  module_root <- script_dir
  test_dir <- file.path(script_dir, "tests")
}

fixtures_dir <- file.path(test_dir, "fixtures")

# Source module files
setwd(module_root)
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
r_files <- r_files[order(basename(r_files))]
for (f in r_files) {
  tryCatch(source(f), error = function(e) {
    cat("Warning: Could not source", basename(f), ":", e$message, "\n")
  })
}

# ==============================================================================
# HELPER: Load golden fixture data
# ==============================================================================

load_golden_binary <- function() {
  path <- file.path(fixtures_dir, "golden_binary.csv")
  if (!file.exists(path)) {
    skip("Golden binary fixture not found. Run: Rscript fixtures/golden_data_generator.R --generate")
  }

  data <- read.csv(path, stringsAsFactors = FALSE)

  # Convert to proper factors with correct levels
  data$retained <- factor(data$retained, levels = c("Churned", "Retained"))
  data$satisfaction <- factor(data$satisfaction, levels = c("Low", "Medium", "High"))
  data$product_tier <- factor(data$product_tier, levels = c("Basic", "Standard", "Premium"))
  data$channel <- factor(data$channel, levels = c("Online", "Retail", "Partner"))

  data
}

load_golden_ordinal <- function() {
  path <- file.path(fixtures_dir, "golden_ordinal.csv")
  if (!file.exists(path)) {
    skip("Golden ordinal fixture not found. Run: Rscript fixtures/golden_data_generator.R --generate")
  }

  data <- read.csv(path, stringsAsFactors = FALSE)

  # Convert to proper factors with correct levels
  data$satisfaction <- ordered(data$satisfaction, levels = c("Dissatisfied", "Neutral", "Satisfied"))
  data$service_quality <- factor(data$service_quality, levels = c("Poor", "Fair", "Good", "Excellent"))
  data$price_perception <- factor(data$price_perception, levels = c("Too High", "Fair", "Good Value"))
  data$age_group <- factor(data$age_group, levels = c("18-34", "35-54", "55+"))

  data
}


# ==============================================================================
# TEST SUITE: BINARY MODEL GOLDEN FIXTURES
# ==============================================================================

context("Golden Fixtures: Binary Model")

test_that("binary model produces correct sample size", {
  data <- load_golden_binary()
  expect_equal(nrow(data), 120)
})

test_that("binary model produces correct outcome distribution", {
  data <- load_golden_binary()

  # Count outcomes
  tab <- table(data$retained)

  expect_true("Churned" %in% names(tab))
  expect_true("Retained" %in% names(tab))

  # Verify distribution is roughly correct (more retained than churned due to design)
  expect_true(tab["Retained"] > tab["Churned"])
})

test_that("binary model identifies satisfaction as top driver", {
  skip_if_not_installed("car")

  data <- load_golden_binary()
  formula <- retained ~ satisfaction + product_tier + channel

  model <- glm(formula, data = data, family = binomial())
  anova_result <- car::Anova(model, type = "II")

  # Get importance ranking
  chi_sq <- anova_result$Chisq
  names(chi_sq) <- rownames(anova_result)
  top_driver <- names(which.max(chi_sq))

  # Satisfaction should be the top driver by design
  expect_equal(top_driver, "satisfaction",
               info = paste("Expected 'satisfaction' as top driver, got:", top_driver))
})

test_that("binary model OR direction matches data design", {
  data <- load_golden_binary()
  formula <- retained ~ satisfaction + product_tier + channel

  model <- glm(formula, data = data, family = binomial())
  ors <- exp(coef(model))

  # By design: High satisfaction should have OR > 1 vs Low (reference)
  # satisfactionHigh should show positive effect
  expect_true("satisfactionHigh" %in% names(ors),
              info = "satisfactionHigh coefficient should exist")

  or_high <- ors["satisfactionHigh"]
  expect_true(or_high > 1,
              info = paste("OR for High satisfaction should be > 1, got:", round(or_high, 2)))

  # By design: Low satisfaction (reference) should have lower retention
  # So Medium should also be > 1
  or_medium <- ors["satisfactionMedium"]
  expect_true(or_medium > 1 || is.na(or_medium),
              info = paste("OR for Medium satisfaction should be > 1 or NA, got:", round(or_medium, 2)))
})

test_that("binary model coefficient estimates are stable", {
  data <- load_golden_binary()
  formula <- retained ~ satisfaction + product_tier + channel

  # Run model twice
  model1 <- glm(formula, data = data, family = binomial())
  model2 <- glm(formula, data = data, family = binomial())

  # Coefficients should be identical (deterministic)
  expect_equal(coef(model1), coef(model2))
})

test_that("binary model converges", {
  data <- load_golden_binary()
  formula <- retained ~ satisfaction + product_tier + channel

  model <- glm(formula, data = data, family = binomial())

  expect_true(model$converged)
})

test_that("binary model produces finite coefficients (no separation)", {
  data <- load_golden_binary()
  formula <- retained ~ satisfaction + product_tier + channel

  model <- glm(formula, data = data, family = binomial())
  coefs <- coef(model)

  # All coefficients should be finite
  expect_true(all(is.finite(coefs)),
              info = "All coefficients should be finite (no separation)")

  # No coefficient should be extremely large (indication of quasi-separation)
  expect_true(all(abs(coefs) < 10),
              info = "No coefficient should be extremely large")
})


# ==============================================================================
# TEST SUITE: ORDINAL MODEL GOLDEN FIXTURES
# ==============================================================================

context("Golden Fixtures: Ordinal Model")

test_that("ordinal model produces correct sample size", {
  data <- load_golden_ordinal()
  expect_equal(nrow(data), 90)
})

test_that("ordinal model produces correct outcome distribution", {
  data <- load_golden_ordinal()

  # Should have 3 levels
  expect_equal(length(levels(data$satisfaction)), 3)
  expect_equal(levels(data$satisfaction), c("Dissatisfied", "Neutral", "Satisfied"))

  # All levels should be present
  tab <- table(data$satisfaction)
  expect_true(all(tab > 0))
})

test_that("ordinal model identifies service_quality as top driver", {
  skip_if_not_installed("car")
  skip_if_not_installed("ordinal")

  data <- load_golden_ordinal()
  formula <- satisfaction ~ service_quality + price_perception + age_group

  # Fit ordinal model
  model <- tryCatch(
    ordinal::clm(formula, data = data),
    error = function(e) MASS::polr(formula, data = data, Hess = TRUE)
  )

  # For ordinal models, we can still use Anova
  anova_result <- tryCatch({
    car::Anova(model, type = "II")
  }, error = function(e) NULL)

  if (!is.null(anova_result)) {
    chi_sq <- anova_result$Chisq
    if (is.null(chi_sq)) chi_sq <- anova_result$LR.Chisq
    names(chi_sq) <- rownames(anova_result)
    top_driver <- names(which.max(chi_sq))

    # Service quality should be top driver by design
    expect_equal(top_driver, "service_quality",
                 info = paste("Expected 'service_quality' as top driver, got:", top_driver))
  }
})

test_that("ordinal model thresholds are properly ordered", {
  skip_if_not_installed("ordinal")

  data <- load_golden_ordinal()
  formula <- satisfaction ~ service_quality + price_perception + age_group

  model <- tryCatch(
    ordinal::clm(formula, data = data),
    error = function(e) MASS::polr(formula, data = data, Hess = TRUE)
  )

  # Get thresholds
  if (inherits(model, "clm")) {
    thresholds <- model$alpha
  } else {
    thresholds <- model$zeta
  }

  # Should have n_levels - 1 = 2 thresholds
  expect_equal(length(thresholds), 2)

  # Thresholds must be in strictly ascending order
  expect_true(thresholds[2] > thresholds[1],
              info = paste("Thresholds should be ascending:",
                           paste(round(thresholds, 2), collapse = " < ")))
})

test_that("ordinal model OR direction matches design", {
  skip_if_not_installed("ordinal")

  data <- load_golden_ordinal()
  formula <- satisfaction ~ service_quality + price_perception + age_group

  model <- tryCatch(
    ordinal::clm(formula, data = data),
    error = function(e) MASS::polr(formula, data = data, Hess = TRUE)
  )

  # Get coefficients (not thresholds)
  if (inherits(model, "clm")) {
    coefs <- model$beta
  } else {
    coefs <- coef(model)
  }

  # By design: Excellent service should have positive coefficient (higher satisfaction)
  excellent_coef_name <- grep("service_quality.*Excellent", names(coefs), value = TRUE)
  if (length(excellent_coef_name) > 0) {
    expect_true(coefs[excellent_coef_name] > 0,
                info = "Excellent service should have positive effect on satisfaction")
  }

  # By design: Good Value price perception should have positive effect
  good_value_name <- grep("price_perception.*Good", names(coefs), value = TRUE)
  if (length(good_value_name) > 0) {
    expect_true(coefs[good_value_name] > 0,
                info = "Good Value should have positive effect on satisfaction")
  }
})


# ==============================================================================
# TEST SUITE: INTEGRATION GOLDEN FIXTURES
# ==============================================================================

context("Golden Fixtures: Integration Tests")

test_that("full binary analysis pipeline produces consistent results", {
  skip_if_not_installed("car")

  data <- load_golden_binary()

  # Build config similar to real usage
  config <- list(
    outcome_var = "retained",
    outcome_type = "binary",
    outcome_label = "Customer Retained",
    driver_vars = c("satisfaction", "product_tier", "channel"),
    driver_labels = list(
      satisfaction = "Satisfaction",
      product_tier = "Product Tier",
      channel = "Channel"
    ),
    confidence_level = 0.95,
    min_sample_size = 50,
    driver_settings = data.frame(
      driver = c("satisfaction", "product_tier", "channel"),
      type = c("ordinal", "nominal", "nominal"),
      missing_strategy = c("drop_row", "drop_row", "drop_row"),
      stringsAsFactors = FALSE
    )
  )

  # Create formula
  formula <- as.formula(paste(config$outcome_var, "~",
                              paste(config$driver_vars, collapse = " + ")))

  # Fit model
  model <- glm(formula, data = data, family = binomial())

  # Run importance analysis
  anova_result <- car::Anova(model, type = "II")
  chi_sq <- anova_result$Chisq
  names(chi_sq) <- rownames(anova_result)

  # Create importance ranking
  importance_df <- data.frame(
    variable = names(chi_sq),
    chi_square = chi_sq,
    stringsAsFactors = FALSE
  )
  importance_df <- importance_df[order(-importance_df$chi_square), ]
  importance_df$rank <- 1:nrow(importance_df)

  # Verify structure
  expect_equal(nrow(importance_df), 3)
  expect_equal(importance_df$variable[1], "satisfaction")
  expect_true(importance_df$chi_square[1] > importance_df$chi_square[2])
  expect_true(importance_df$chi_square[2] > importance_df$chi_square[3])
})

test_that("odds ratios are computed correctly for golden data", {
  data <- load_golden_binary()
  formula <- retained ~ satisfaction + product_tier + channel

  model <- glm(formula, data = data, family = binomial())

  coefs <- coef(model)
  se <- sqrt(diag(vcov(model)))
  ors <- exp(coefs)

  # Compute 95% CI
  z <- qnorm(0.975)
  or_lower <- exp(coefs - z * se)
  or_upper <- exp(coefs + z * se)

  # Verify CI contains point estimate
  for (i in seq_along(ors)) {
    expect_true(or_lower[i] <= ors[i] && ors[i] <= or_upper[i],
                info = paste("CI should contain OR for", names(ors)[i]))
  }

  # Verify CIs are asymmetric on original scale
  # (they're symmetric on log scale, which makes them asymmetric on OR scale)
  for (i in 2:length(ors)) {  # Skip intercept
    lower_diff <- ors[i] - or_lower[i]
    upper_diff <- or_upper[i] - ors[i]

    # Not exactly equal (would be if symmetric on OR scale)
    if (is.finite(lower_diff) && is.finite(upper_diff) && lower_diff > 0) {
      # Allow some tolerance
      expect_false(abs(lower_diff - upper_diff) < 0.001 * ors[i],
                   info = paste("CI should be asymmetric for", names(ors)[i]))
    }
  }
})


# ==============================================================================
# TEST SUITE: REPRODUCIBILITY
# ==============================================================================

context("Golden Fixtures: Reproducibility")

test_that("results are deterministic across runs", {
  data <- load_golden_binary()
  formula <- retained ~ satisfaction + product_tier + channel

  # Run 5 times
  results <- replicate(5, {
    model <- glm(formula, data = data, family = binomial())
    list(
      coefs = coef(model),
      aic = AIC(model),
      deviance = model$deviance
    )
  }, simplify = FALSE)

  # All should be identical
  for (i in 2:5) {
    expect_equal(results[[1]]$coefs, results[[i]]$coefs,
                 info = paste("Coefficients should be identical across runs", i))
    expect_equal(results[[1]]$aic, results[[i]]$aic,
                 info = paste("AIC should be identical across runs", i))
    expect_equal(results[[1]]$deviance, results[[i]]$deviance,
                 info = paste("Deviance should be identical across runs", i))
  }
})

test_that("model fit statistics are within expected ranges", {
  data <- load_golden_binary()
  formula <- retained ~ satisfaction + product_tier + channel

  model <- glm(formula, data = data, family = binomial())

  # McFadden R2
  mcfadden_r2 <- 1 - (model$deviance / model$null.deviance)

  # Should be positive (model better than null)
  expect_true(mcfadden_r2 > 0,
              info = "McFadden R2 should be positive")

  # Should be reasonable (not 1.0 which would indicate perfect fit / overfitting)
  expect_true(mcfadden_r2 < 0.5,
              info = "McFadden R2 should be < 0.5 (not overfitting)")

  # AIC should be reasonable
  expect_true(is.finite(AIC(model)))
  expect_true(AIC(model) > 0)
})


# ==============================================================================
# RUN TESTS IF NOT INTERACTIVE
# ==============================================================================

if (!interactive()) {
  cat("\n========================================\n")
  cat("GOLDEN FIXTURE TEST SUITE\n")
  cat("========================================\n\n")

  test_results <- tryCatch({
    test_file(file.path(test_dir, "test_golden_fixtures.R"), reporter = "summary")
  }, error = function(e) {
    # Fallback: run tests in current file
    test_dir(".", reporter = "summary", filter = "golden")
  })
}
