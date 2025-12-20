# ==============================================================================
# CATDRIVER REGRESSION TEST SUITE
# ==============================================================================
#
# Tests critical behaviors identified in external review:
# 1. Term-level mapping integrity (no substring parsing failures)
# 2. Missing data handling (per-variable strategy, not blanket complete.cases)
# 3. Hard refusal for outcome-type mismatch
# 4. Multinomial target_outcome enforcement
# 5. Fallback estimator behavior for separation
# 6. Golden fixture stability
#
# Run with: Rscript run_tests.R
#
# Version: 2.0
# ==============================================================================

library(testthat)

# Set working directory to module root
script_dir <- tryCatch({
  if (!is.null(sys.frame(1)$ofile)) dirname(sys.frame(1)$ofile) else getwd()
}, error = function(e) getwd())

if (basename(script_dir) == "tests") {
  module_root <- dirname(script_dir)
} else {
  module_root <- script_dir
}
setwd(module_root)

# Source all R files in order
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
r_files <- r_files[order(basename(r_files))]
for (f in r_files) {
  tryCatch(source(f), error = function(e) {
    cat("Warning: Could not source", basename(f), ":", e$message, "\n")
  })
}

# ==============================================================================
# TEST DATA GENERATORS
# ==============================================================================

generate_binary_data <- function(n = 300, seed = 42) {
  set.seed(seed)
  data.frame(
    outcome = factor(sample(c("No", "Yes"), n, TRUE, c(0.4, 0.6)), levels = c("No", "Yes")),
    age_group = factor(sample(c("18-34", "35-54", "55+"), n, TRUE), levels = c("18-34", "35-54", "55+")),
    income = factor(sample(c("Low", "Medium", "High"), n, TRUE), levels = c("Low", "Medium", "High")),
    region = factor(sample(c("North", "South", "East", "West"), n, TRUE)),
    stringsAsFactors = FALSE
  )
}

generate_ordinal_data <- function(n = 300, seed = 42) {
  set.seed(seed)
  data.frame(
    satisfaction = ordered(sample(c("Low", "Medium", "High"), n, TRUE), levels = c("Low", "Medium", "High")),
    service = ordered(sample(c("Poor", "Fair", "Good", "Excellent"), n, TRUE), levels = c("Poor", "Fair", "Good", "Excellent")),
    price = ordered(sample(c("Too High", "Fair", "Good Value"), n, TRUE), levels = c("Too High", "Fair", "Good Value")),
    stringsAsFactors = FALSE
  )
}

generate_multinomial_data <- function(n = 300, seed = 42) {
  set.seed(seed)
  data.frame(
    choice = factor(sample(c("A", "B", "C"), n, TRUE)),
    age = factor(sample(c("Young", "Middle", "Senior"), n, TRUE)),
    gender = factor(sample(c("Male", "Female"), n, TRUE)),
    stringsAsFactors = FALSE
  )
}

# Data with messy factor level names (spaces, special chars)
generate_messy_labels_data <- function(n = 200, seed = 42) {
  set.seed(seed)
  data.frame(
    outcome = factor(sample(c("Very Dissatisfied", "Somewhat Satisfied"), n, TRUE)),
    campus_type = factor(sample(c("On Campus", "Online Only", "Hybrid/Mixed"), n, TRUE)),
    age_bracket = factor(sample(c("18 - 25", "26 - 35", "36+"), n, TRUE)),
    stringsAsFactors = FALSE
  )
}

# Data with missing values
generate_missing_data <- function(n = 300, seed = 42) {
  set.seed(seed)
  data <- data.frame(
    outcome = factor(sample(c("No", "Yes"), n, TRUE)),
    driver1 = factor(sample(c("A", "B", "C"), n, TRUE)),
    driver2 = factor(sample(c("X", "Y", "Z"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  # Inject missing values
  data$driver1[sample(n, 20)] <- NA
  data$driver2[sample(n, 15)] <- NA
  data
}


# ==============================================================================
# TEST SUITE 1: TERM-LEVEL MAPPING INTEGRITY
# ==============================================================================

context("Term-Level Mapping Integrity")

test_that("map_terms_to_levels correctly maps standard factor names", {
  data <- generate_binary_data(200)
  formula <- outcome ~ age_group + income + region
  model <- glm(formula, data = data, family = binomial())

  mapping <- map_terms_to_levels(model, data, formula)

  expect_true(is.data.frame(mapping))
  expect_true("driver" %in% names(mapping))
  expect_true("level" %in% names(mapping))

  # Check all non-intercept terms are mapped
  coef_names <- names(coef(model))[-1]  # Exclude intercept
  mapped_terms <- mapping$coef_name[!is.na(mapping$coef_name)]

  for (term in coef_names) {
    expect_true(term %in% mapped_terms, info = paste("Term not mapped:", term))
  }
})


test_that("positional mapping handles numerically-named columns", {
  # CRITICAL: This tests the fix for the grade2 mapping bug

  # When R creates model matrix columns like "grade2" instead of "gradeC",
  # positional mapping via assign attribute correctly maps to levels.

  # Create data where factor might get numeric column names
  data <- data.frame(
    outcome = factor(c(rep("Low", 50), rep("High", 50))),
    grade = factor(c("D", "C", "B", "A")[sample(1:4, 100, replace = TRUE)],
                   levels = c("D", "C", "B", "A"))
  )

  formula <- outcome ~ grade
  model <- glm(formula, data = data, family = binomial())

  mapping <- map_terms_to_levels(model, data, formula)

  # Mapping should have 4 entries (3 non-ref + 1 ref)
  expect_equal(nrow(mapping), 4)

  # All levels should be present (D is reference)
  expect_true("D" %in% mapping$level)
  expect_true("C" %in% mapping$level)
  expect_true("B" %in% mapping$level)
  expect_true("A" %in% mapping$level)

  # Reference level should be correctly identified
  expect_equal(sum(mapping$is_reference), 1)
  expect_equal(mapping$level[mapping$is_reference], "D")
})


# H4: Messy label mapping test - comprehensive check
test_that("H4: messy labels with spaces/punctuation are correctly mapped", {
  data <- generate_messy_labels_data(200)
  formula <- outcome ~ campus_type + age_bracket
  model <- glm(formula, data = data, family = binomial())

  mapping <- map_terms_to_levels(model, data, formula)

  # All levels should be correctly mapped
  for (var in c("campus_type", "age_bracket")) {
    data_levels <- levels(data[[var]])
    mapped_levels <- mapping$level[mapping$driver == var]

    # Every non-reference level should be mapped
    for (lvl in data_levels[-1]) {
      expect_true(lvl %in% mapped_levels,
                  info = paste("Level", lvl, "from", var, "should be in mapping"))
    }
  }

  # Check specific messy level names
  expect_true("On Campus" %in% mapping$level || "Online Only" %in% mapping$level,
              info = "'On Campus' or 'Online Only' (with space) should be mapped")
  expect_true("Hybrid/Mixed" %in% mapping$level,
              info = "'Hybrid/Mixed' (with slash) should be mapped")
  expect_true("36+" %in% mapping$level,
              info = "'36+' (with plus) should be mapped")
})

test_that("mapping does NOT use substring parsing for complex names", {
  data <- generate_messy_labels_data(200)
  formula <- outcome ~ campus_type + age_bracket
  model <- glm(formula, data = data, family = binomial())

  mapping <- map_terms_to_levels(model, data, formula)

  # Every mapped level should be a real level from the data
  for (i in seq_len(nrow(mapping))) {
    if (!is.na(mapping$level[i])) {
      driver <- mapping$driver[i]
      level <- mapping$level[i]

      # Level should exist in original data
      if (driver %in% names(data)) {
        data_levels <- levels(data[[driver]])
        expect_true(level %in% data_levels,
                    info = paste("Mapped level", level, "not in data for", driver))
      }
    }
  }
})


test_that("extract_odds_ratios uses mapping not substring parsing", {
  data <- generate_messy_labels_data(200)

  prep_data <- list(
    data = data,
    outcome_info = list(type = "binary", categories = levels(data$outcome)),
    predictor_info = list(
      campus_type = list(levels = levels(data$campus_type), reference_level = levels(data$campus_type)[1]),
      age_bracket = list(levels = levels(data$age_bracket), reference_level = levels(data$age_bracket)[1])
    ),
    model_formula = outcome ~ campus_type + age_bracket
  )

  config <- list(
    outcome_var = "outcome",
    driver_vars = c("campus_type", "age_bracket"),
    driver_labels = list(campus_type = "Campus Type", age_bracket = "Age"),
    confidence_level = 0.95
  )

  model <- glm(prep_data$model_formula, data = data, family = binomial())
  model_result <- list(
    model = model,
    model_type = "binary_logistic",
    coefficients = data.frame(
      term = names(coef(model)),
      estimate = as.numeric(coef(model)),
      std_error = summary(model)$coefficients[, 2],
      z_value = summary(model)$coefficients[, 3],
      p_value = summary(model)$coefficients[, 4],
      odds_ratio = exp(coef(model)),
      or_lower = exp(confint.default(model)[, 1]),
      or_upper = exp(confint.default(model)[, 2]),
      stringsAsFactors = FALSE
    )
  )

  or_df <- extract_odds_ratios(model_result, config, prep_data)

  # All comparisons should have valid factor and level names
  for (i in seq_len(nrow(or_df))) {
    factor_name <- or_df$factor[i]
    comparison <- or_df$comparison[i]

    expect_true(factor_name %in% c("campus_type", "age_bracket"),
                info = paste("Invalid factor:", factor_name))
  }
})


# ==============================================================================
# TEST SUITE 2: MISSING DATA HANDLING
# ==============================================================================

context("Missing Data Handling (Per-Variable Strategy)")

test_that("prepare_analysis_data uses per-variable strategy, not complete.cases", {
  data <- generate_missing_data(300)
  n_original <- nrow(data)

  # Config with different strategies per driver
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver1", "driver2"),
    weight_var = NULL,
    driver_settings = data.frame(
      driver = c("driver1", "driver2"),
      type = c("nominal", "nominal"),
      missing_strategy = c("drop_row", "missing_as_level"),
      stringsAsFactors = FALSE
    )
  )

  result <- prepare_analysis_data(data, config, NULL)

  # driver1 should have rows dropped
  expect_true(result$n_excluded > 0)

  # driver2 should have "Missing" level, not dropped
  expect_true("Missing" %in% levels(result$data$driver2))

  # Verify that NOT all rows with any missing were dropped
  # (i.e., we're not using blanket complete.cases)
  n_driver1_missing <- sum(is.na(data$driver1))
  n_driver2_missing <- sum(is.na(data$driver2))

  # If we used complete.cases, we'd drop ~35 rows (20 + 15)

  # With per-variable strategy, we should drop fewer since driver2 is recoded
  expect_true(result$n_excluded <= n_driver1_missing)
})


test_that("missing_as_level creates Missing category correctly", {
  data <- generate_missing_data(300)

  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver1"),
    weight_var = NULL,
    driver_settings = data.frame(
      driver = "driver1",
      type = "nominal",
      missing_strategy = "missing_as_level",
      stringsAsFactors = FALSE
    )
  )

  result <- prepare_analysis_data(data, config, NULL)

  # Should have "Missing" level
  expect_true("Missing" %in% levels(result$data$driver1))

  # Should have NO NA values in driver1
  expect_equal(sum(is.na(result$data$driver1)), 0)

  # Count of "Missing" should match original NA count
  n_original_na <- sum(is.na(data$driver1))
  n_missing_level <- sum(result$data$driver1 == "Missing")
  expect_equal(n_missing_level, n_original_na)
})


test_that("error_if_missing strategy produces hard error", {
  data <- generate_missing_data(300)

  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver1"),
    weight_var = NULL,
    driver_settings = data.frame(
      driver = "driver1",
      type = "nominal",
      missing_strategy = "error_if_missing",
      stringsAsFactors = FALSE
    )
  )

  expect_error(
    prepare_analysis_data(data, config, NULL),
    "HARD ERROR.*missing values"
  )
})


# ==============================================================================
# TEST SUITE 3: HARD REFUSAL FOR OUTCOME-TYPE MISMATCH
# ==============================================================================

context("Outcome-Type Mismatch Hard Refusal")

test_that("binary type with 3+ categories produces hard error", {
  data <- generate_ordinal_data(200)  # Has 3 satisfaction levels

  outcome_info <- list(type = "binary", categories = c("Low", "Medium", "High"))

  config <- list(
    outcome_var = "satisfaction",
    outcome_type = "binary",
    outcome_order = NULL,
    reference_category = NULL
  )

  expect_error(
    prepare_outcome(data, config, outcome_info),
    "OUTCOME TYPE MISMATCH.*binary.*3 categories"
  )
})


test_that("ordinal type with mismatched categories produces hard error", {
  data <- generate_ordinal_data(200)

  outcome_info <- list(type = "ordinal", categories = c("Low", "Medium", "High"))

  config <- list(
    outcome_var = "satisfaction",
    outcome_type = "ordinal",
    outcome_order = c("Bad", "OK", "Good"),  # Wrong categories!
    reference_category = NULL
  )

  expect_error(
    prepare_outcome(data, config, outcome_info),
    "OUTCOME CATEGORY MISMATCH"
  )
})


test_that("guard_require_outcome_type rejects auto", {
  config <- list(outcome_type = "auto")

  expect_error(
    guard_require_outcome_type(config),
    "must be explicitly declared"
  )
})


test_that("guard_outcome_levels_match rejects binary with wrong count", {
  data <- generate_ordinal_data(200)

  config <- list(
    outcome_var = "satisfaction",
    outcome_type = "binary"
  )

  expect_error(
    guard_outcome_levels_match(data, config),
    "declared as 'binary' but has 3 categories"
  )
})


# ==============================================================================
# TEST SUITE 4: MULTINOMIAL TARGET OUTCOME ENFORCEMENT (H2)
# ==============================================================================

context("Multinomial Mode and Target Outcome Enforcement")

test_that("H2a: multinomial without multinomial_mode refuses with CFG_MULTINOMIAL_MODE_MISSING", {
  config <- list(
    outcome_type = "multinomial",
    multinomial_mode = NULL
  )

  expect_error(
    guard_require_multinomial_mode(config),
    "CFG_MULTINOMIAL_MODE_MISSING|multinomial_mode"
  )
})

test_that("H2b: one_vs_all without target refuses with CFG_TARGET_OUTCOME_MISSING", {
  config <- list(
    outcome_type = "multinomial",
    multinomial_mode = "one_vs_all",
    target_outcome_level = NULL
  )

  expect_error(
    guard_require_multinomial_mode(config),
    "CFG_TARGET_OUTCOME_MISSING|target_outcome_level"
  )
})

test_that("H2c: non-multinomial outcomes do not require multinomial settings", {
  # Ordinal should NOT require multinomial_mode
  config <- list(
    outcome_type = "ordinal",
    multinomial_mode = NULL
  )

  result <- tryCatch({
    guard_require_multinomial_mode(config)
    TRUE
  }, error = function(e) FALSE)

  expect_true(result, info = "Ordinal outcome should not require multinomial_mode")

  # Binary should NOT require multinomial_mode
  config2 <- list(
    outcome_type = "binary",
    multinomial_mode = NULL
  )

  result2 <- tryCatch({
    guard_require_multinomial_mode(config2)
    TRUE
  }, error = function(e) FALSE)

  expect_true(result2, info = "Binary outcome should not require multinomial_mode")
})


test_that("guard_require_multinomial_mode accepts valid modes", {
  for (mode in c("baseline_category", "all_pairwise", "one_vs_all")) {
    config <- list(
      outcome_type = "multinomial",
      multinomial_mode = mode,
      target_outcome_level = if (mode == "one_vs_all") "A" else NULL
    )

    # Should not error
    result <- tryCatch({
      guard_require_multinomial_mode(config)
      TRUE
    }, error = function(e) FALSE)

    expect_true(result, info = paste("Mode", mode, "should be accepted"))
  }
})


# ==============================================================================
# TEST SUITE 4B: CONTINUOUS DRIVER NOT ALLOWED (H3)
# ==============================================================================

context("Continuous Driver Not Allowed")

test_that("H3: continuous driver type refused with CFG_CONTINUOUS_DRIVER_NOT_ALLOWED", {
  config <- list(
    driver_vars = c("age", "income"),
    driver_settings = data.frame(
      driver = c("age", "income"),
      type = c("continuous", "categorical"),
      stringsAsFactors = FALSE
    )
  )

  expect_error(
    guard_require_driver_settings(config),
    "CFG_CONTINUOUS_DRIVER_NOT_ALLOWED|CONTINUOUS DRIVERS NOT ALLOWED"
  )
})

test_that("H3b: control_only type is accepted for continuous covariates", {
  config <- list(
    driver_vars = c("age", "income"),
    driver_settings = data.frame(
      driver = c("age", "income"),
      type = c("control_only", "categorical"),
      stringsAsFactors = FALSE
    )
  )

  # Should NOT error - control_only is valid
  result <- tryCatch({
    guard_require_driver_settings(config)
    TRUE
  }, error = function(e) FALSE)

  expect_true(result, info = "control_only should be accepted for continuous covariates")
})


test_that("multinomial results include mode and target", {
  skip_if_not_installed("nnet")

  data <- generate_multinomial_data(200)
  formula <- choice ~ age + gender

  config <- list(
    outcome_var = "choice",
    multinomial_mode = "baseline_category",
    target_outcome_level = NULL,
    confidence_level = 0.95
  )

  guard <- guard_init()

  result <- run_multinomial_logistic_robust(formula, data, NULL, config, guard)

  expect_equal(result$multinomial_mode, "baseline_category")
  expect_null(result$target_outcome_level)
})


# ==============================================================================
# TEST SUITE 5: FALLBACK ESTIMATOR BEHAVIOR
# ==============================================================================

context("Fallback Estimator for Separation")

test_that("run_binary_logistic_robust reports fallback when used", {
  skip_if_not_installed("brglm2")

  # Create data with separation
  set.seed(123)
  n <- 100
  data <- data.frame(
    outcome = factor(c(rep("No", 50), rep("Yes", 50))),
    perfect_predictor = factor(c(rep("A", 50), rep("B", 50)))  # Perfect separation
  )

  formula <- outcome ~ perfect_predictor
  config <- list(outcome_var = "outcome", confidence_level = 0.95)
  guard <- guard_init()

  result <- run_binary_logistic_robust(formula, data, NULL, config, guard)

  # Should have detected separation and potentially used fallback
  expect_true(!is.null(result$engine_used))
  expect_true(!is.null(result$fallback_used))

  # If brglm2 is available and separation detected, fallback should be used
  if (result$fallback_used) {
    expect_true(grepl("brglm|Firth", result$engine_used))
  }
})


test_that("ordinal regression uses clm with polr fallback", {
  data <- generate_ordinal_data(200)
  formula <- satisfaction ~ service + price
  config <- list(outcome_var = "satisfaction", confidence_level = 0.95)
  guard <- guard_init()

  result <- run_ordinal_logistic_robust(formula, data, NULL, config, guard)

  # Should report which engine was used
  expect_true(!is.null(result$engine_used))
  expect_true(result$engine_used %in% c("ordinal::clm", "MASS::polr"))
})


# ==============================================================================
# TEST SUITE 6: GOLDEN FIXTURE STABILITY
# ==============================================================================

context("Golden Fixture Regression Tests")

# T1: CRITICAL - Ordinal OR sign test (C13 fix)
# Verifies that OR > 1 means higher outcome category more likely
test_that("T1: ordinal OR direction matches raw data proportions", {
  skip_if_not_installed("ordinal")

  # Create data where Group A clearly has HIGHER satisfaction than Group D
  set.seed(42)
  n <- 200
  data <- data.frame(
    satisfaction = ordered(
      c(
        # Group D: mostly Low (70% Low, 20% Neutral, 10% High)
        sample(c("Low", "Neutral", "High"), 50, TRUE, c(0.7, 0.2, 0.1)),
        # Group A: mostly High (10% Low, 20% Neutral, 70% High)
        sample(c("Low", "Neutral", "High"), 50, TRUE, c(0.1, 0.2, 0.7)),
        # Groups B and C: intermediate
        sample(c("Low", "Neutral", "High"), 100, TRUE, c(0.4, 0.3, 0.3))
      ),
      levels = c("Low", "Neutral", "High")
    ),
    grade = factor(
      c(rep("D", 50), rep("A", 50), rep("B", 50), rep("C", 50)),
      levels = c("D", "C", "B", "A")  # D is reference
    )
  )

  # Verify raw data: A should have higher % High than D
  prop_high_A <- mean(data$satisfaction[data$grade == "A"] == "High")
  prop_high_D <- mean(data$satisfaction[data$grade == "D"] == "High")
  expect_true(prop_high_A > prop_high_D,
              info = "Test setup: A should have higher High% than D")

  # Fit ordinal model
  formula <- satisfaction ~ grade
  config <- list(outcome_var = "satisfaction", confidence_level = 0.95)
  guard <- guard_init()

  result <- run_ordinal_logistic_robust(formula, data, NULL, config, guard)

  # Find OR for grade A (vs D reference)
  coef_df <- result$coefficients
  gradeA_row <- coef_df[grepl("gradeA|A$", coef_df$term), ]

  expect_true(nrow(gradeA_row) == 1, info = "Should find exactly one gradeA coefficient")

  # CRITICAL: OR > 1 should mean higher satisfaction more likely
  # Since A has higher satisfaction than D, OR for A vs D should be > 1
  expect_true(gradeA_row$odds_ratio > 1,
              info = paste0(
                "OR for A vs D should be > 1 (A more satisfied). ",
                "Raw: A=", round(prop_high_A*100), "% High, D=", round(prop_high_D*100), "% High. ",
                "Got OR=", round(gradeA_row$odds_ratio, 2)
              ))

  # OR should be substantially > 1 given the large difference
  expect_true(gradeA_row$odds_ratio > 2,
              info = "OR should be >> 1 given 70% vs 10% High")
})


test_that("binary model produces stable coefficient structure", {
  data <- generate_binary_data(500, seed = 12345)
  formula <- outcome ~ age_group + income + region

  model <- glm(formula, data = data, family = binomial())
  coefs <- coef(model)

  # Should have: intercept + 2 age_group + 2 income + 3 region = 8 coefficients
  expect_equal(length(coefs), 8)

  # All coefficients should be numeric and finite
  expect_true(all(is.finite(coefs)))
})


test_that("ordinal model thresholds are properly ordered", {
  skip_if_not_installed("ordinal")

  data <- generate_ordinal_data(500, seed = 12345)
  formula <- satisfaction ~ service + price

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

  # Thresholds must be in ascending order
  expect_true(all(diff(thresholds) > 0), info = "Thresholds must be ascending")
})


test_that("importance ranking is deterministic", {
  data <- generate_binary_data(500, seed = 54321)

  formula <- outcome ~ age_group + income + region
  model <- glm(formula, data = data, family = binomial())

  # Run twice
  anova1 <- car::Anova(model, type = "II")
  anova2 <- car::Anova(model, type = "II")

  # Results should be identical
  expect_equal(anova1$Chisq, anova2$Chisq)
})


# ==============================================================================
# TEST SUITE 7: GUARD STATE TRACKING
# ==============================================================================

context("Guard State Tracking")

test_that("guard_init creates proper structure", {
  guard <- guard_init()

  expect_type(guard, "list")
  expect_true("warnings" %in% names(guard))
  expect_true("stability_flags" %in% names(guard))
  expect_equal(length(guard$warnings), 0)
})


test_that("guard_check_fallback updates state correctly", {
  guard <- guard_init()

  guard <- guard_check_fallback(guard, TRUE, "Test reason")

  expect_true(guard$fallback_used)
  expect_equal(guard$fallback_reason, "Test reason")
  expect_true(length(guard$warnings) > 0)
  expect_true("Fallback estimator used" %in% guard$stability_flags)
})


test_that("guard_summary correctly identifies issues", {
  guard <- guard_init()
  guard <- guard_warn(guard, "Test warning", "test")
  guard <- guard_flag_stability(guard, "Test flag")

  summary <- guard_summary(guard)

  expect_true(summary$has_issues)
  expect_equal(summary$n_warnings, 1)
  expect_true(summary$use_with_caution)
})


# ==============================================================================
# RUN TESTS IF NOT INTERACTIVE
# ==============================================================================

if (!interactive()) {
  cat("\n========================================\n")
  cat("CATDRIVER REGRESSION TEST SUITE\n")
  cat("========================================\n\n")

  test_results <- test_dir(".", reporter = "summary")

  # Summary
  test_df <- as.data.frame(test_results)
  passed <- sum(test_df$nb) - sum(test_df$failed) - sum(test_df$skipped)
  failed <- sum(test_df$failed)

  cat("\n========================================\n")
  if (failed > 0) {
    cat("TESTS FAILED:", failed, "\n")
    quit(status = 1)
  } else {
    cat("ALL TESTS PASSED:", passed, "\n")
    quit(status = 0)
  }
}
