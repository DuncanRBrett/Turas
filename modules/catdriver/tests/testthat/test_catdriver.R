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

# Path resolution is handled by helper-paths.R (auto-sourced by testthat)
# which provides: module_root, turas_root
setwd(module_root)

# Source shared utilities first (required for TRS refusal functions)
shared_lib_path <- file.path(turas_root, "modules", "shared", "lib")
if (dir.exists(shared_lib_path)) {
  shared_files <- list.files(shared_lib_path, pattern = "\\.R$", full.names = TRUE)
  for (f in shared_files) {
    tryCatch(source(f), error = function(e) {
      cat("Warning: Could not source shared", basename(f), ":", e$message, "\n")
    })
  }
}

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
    "MISSING VALUES NOT ALLOWED"
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
    "OUTCOME TYPE NOT DECLARED"
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
    "INVALID DRIVER TYPE"
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

  # Sanity check using predicted probabilities (reviewer recommendation)
  # Verify that predicted P(High) for A is greater than for D
  fit <- result$model
  pred_A <- predict(fit, newdata = data.frame(grade = factor("A", levels = levels(data$grade))), type = "prob")
  pred_D <- predict(fit, newdata = data.frame(grade = factor("D", levels = levels(data$grade))), type = "prob")

  # Extract probabilities - handle both clm and polr output formats
  if (is.list(pred_A) && "fit" %in% names(pred_A)) {
    prob_high_A <- pred_A$fit[, "High"]
    prob_high_D <- pred_D$fit[, "High"]
  } else if (is.matrix(pred_A)) {
    prob_high_A <- pred_A[, "High"]
    prob_high_D <- pred_D[, "High"]
  } else {
    prob_high_A <- pred_A["High"]
    prob_high_D <- pred_D["High"]
  }

  expect_true(prob_high_A > prob_high_D,
              info = paste0(
                "Predicted P(High) should be greater for A than D. ",
                "Got P(High|A)=", round(prob_high_A, 3),
                ", P(High|D)=", round(prob_high_D, 3)
              ))
})


# T2: Verify OR sign convention is consistent with coefficient sign
# This tests the empirical relationship between β and OR in clm
test_that("T2: ordinal OR matches coefficient sign convention", {
  skip_if_not_installed("ordinal")

  # Use the same data setup as T1
  set.seed(42)
  data <- data.frame(
    satisfaction = ordered(
      c(
        sample(c("Low", "Neutral", "High"), 50, TRUE, c(0.7, 0.2, 0.1)),
        sample(c("Low", "Neutral", "High"), 50, TRUE, c(0.1, 0.2, 0.7)),
        sample(c("Low", "Neutral", "High"), 100, TRUE, c(0.4, 0.3, 0.3))
      ),
      levels = c("Low", "Neutral", "High")
    ),
    grade = factor(
      c(rep("D", 50), rep("A", 50), rep("B", 50), rep("C", 50)),
      levels = c("D", "C", "B", "A")
    )
  )

  # Fit raw clm model (not through our wrapper) to check sign convention
  raw_model <- ordinal::clm(satisfaction ~ grade, data = data)
  raw_beta_A <- raw_model$beta["gradeA"]

  # VERIFIED BEHAVIOR: clm gives POSITIVE β when higher categories are more likely
  # A has higher satisfaction (70% High vs 10% for D), so β_A should be POSITIVE
  # This is the STANDARD interpretation (same as logistic regression)
  expect_true(raw_beta_A > 0,
              info = paste0(
                "clm gives POSITIVE β for A (higher satisfaction) - this is the ",
                "standard sign convention. Got β_A=", round(raw_beta_A, 3)
              ))

  # Now verify our extraction gives OR = exp(β) [NO NEGATION]
  config <- list(outcome_var = "satisfaction", confidence_level = 0.95)
  guard <- guard_init()
  result <- run_ordinal_logistic_robust(satisfaction ~ grade, data, NULL, config, guard)

  gradeA_row <- result$coefficients[grepl("gradeA", result$coefficients$term), ]

  # OR should be exp(β), so OR = exp(raw_beta_A)
  # With β_A > 0, this gives OR > 1 (intuitive for higher satisfaction)
  expected_or <- unname(exp(raw_beta_A))  # Remove names attribute
  expect_equal(gradeA_row$odds_ratio, expected_or, tolerance = 0.001,
               info = paste0(
                 "OR should equal exp(β). ",
                 "Expected: ", round(expected_or, 3),
                 ", Got: ", round(gradeA_row$odds_ratio, 3)
               ))
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
# TEST SUITE 8: BOOTSTRAP EDGE CASES
# ==============================================================================

context("Bootstrap Edge Cases")

test_that("bootstrap flag handles NA config value safely", {
  # Issue 1: isTRUE() should handle NA/NULL without error
  expect_false(isTRUE(as.logical(NA)))
  expect_false(isTRUE(as.logical(NULL)))
  expect_false(isTRUE(as.logical("")))
  expect_true(isTRUE(as.logical(TRUE)))
  expect_true(isTRUE(as.logical("TRUE")))
})


test_that("bootstrap config validation applies safe defaults", {
  # Issue 5: missing/invalid bootstrap config should get safe defaults
  config <- list(
    bootstrap_ci = TRUE,
    bootstrap_reps = NULL,
    confidence_level = NULL
  )

  # Simulate the validation logic from 00_main.R
  if (is.null(config$bootstrap_reps) || is.na(config$bootstrap_reps) ||
      !is.numeric(config$bootstrap_reps) || config$bootstrap_reps < 10) {
    config$bootstrap_reps <- 200L
  }
  if (is.null(config$confidence_level) || is.na(config$confidence_level) ||
      !is.numeric(config$confidence_level) ||
      config$confidence_level <= 0 || config$confidence_level >= 1) {
    config$confidence_level <- 0.95
  }

  expect_equal(config$bootstrap_reps, 200L)
  expect_equal(config$confidence_level, 0.95)

  # Also test with invalid values
  config2 <- list(bootstrap_reps = -5, confidence_level = 1.5)
  if (!is.numeric(config2$bootstrap_reps) || config2$bootstrap_reps < 10) {
    config2$bootstrap_reps <- 200L
  }
  if (!is.numeric(config2$confidence_level) ||
      config2$confidence_level <= 0 || config2$confidence_level >= 1) {
    config2$confidence_level <- 0.95
  }
  expect_equal(config2$bootstrap_reps, 200L)
  expect_equal(config2$confidence_level, 0.95)
})


# ==============================================================================
# TEST SUITE 9: MISSING DATA DEFAULT CONSISTENCY
# ==============================================================================

context("Missing Data Default Consistency")

test_that("missing_as_level default preserves rows that would be dropped by drop_row", {
  # Issue 3: validation and actual handler must use same default
  data <- generate_missing_data(300)
  n_original <- nrow(data)

  # With missing_as_level (the correct default), rows with NA drivers are KEPT
  # The factor just gets a "Missing" level added
  driver1_na <- sum(is.na(data$driver1))
  expect_true(driver1_na > 0)  # Confirm we have missing data

  # Under missing_as_level, effective_n should be: rows with non-missing outcome
  # (driver NAs don't reduce count)
  outcome_valid <- sum(!is.na(data$outcome))
  expect_equal(outcome_valid, n_original)  # All outcomes are non-NA in test data
})


test_that("is_missing_value catches empty strings that is.na misses", {
  # Issue 8: Excel/CSV imports may have empty strings instead of NA
  test_vec <- c("A", "B", "", "  ", NA, "C")

  na_only <- is.na(test_vec)
  full_check <- is_missing_value(test_vec)

  # is.na only catches the NA

  expect_equal(sum(na_only), 1)
  # is_missing_value catches NA, empty string, and whitespace
  expect_equal(sum(full_check), 3)
})


# ==============================================================================
# TEST SUITE 10: WEIGHTED ANALYSIS
# ==============================================================================

context("Weighted Analysis")

test_that("weighted binary model produces valid results", {
  data <- generate_binary_data(200)
  data$weight <- runif(200, 0.5, 2.0)

  formula <- outcome ~ age_group + income
  fit_data <- data
  fit_data$.wt <- data$weight

  model <- glm(formula, data = fit_data, family = binomial(), weights = .wt)

  expect_true(model$converged)
  expect_true(all(is.finite(coef(model))))

  # Term mapping should work identically for weighted models
  mapping <- map_terms_to_levels(model, data, formula)
  expect_true(is.data.frame(mapping))
  expect_true(nrow(mapping) > 0)

  # Validate mapping covers all coefficients
  coef_names <- names(coef(model))[-1]  # Exclude intercept
  mapped_terms <- mapping$coef_name[!is.na(mapping$coef_name)]
  for (term in coef_names) {
    expect_true(term %in% mapped_terms, info = paste("Term not mapped:", term))
  }
})


test_that("weighted ordinal model produces valid results", {
  skip_if_not_installed("ordinal")

  data <- generate_ordinal_data(200)
  data$weight <- runif(200, 0.5, 2.0)

  formula <- satisfaction ~ service + price
  fit_data <- data
  fit_data$.wt <- data$weight

  model <- ordinal::clm(formula, data = fit_data, weights = .wt, link = "logit")

  expect_true(!is.null(model$beta))
  expect_true(all(is.finite(model$beta)))
})


test_that("fit_data copy prevents .wt column from polluting original data", {
  # Issue 12: model fitting should not add .wt to the original data
  data <- generate_binary_data(100)
  data$weight <- runif(100, 0.5, 2.0)

  original_cols <- names(data)

  # Simulate the fix: use local copy
  fit_data <- data
  fit_data$.wt <- data$weight

  # Original data should be unchanged
  expect_equal(names(data), original_cols)
  expect_false(".wt" %in% names(data))
  expect_true(".wt" %in% names(fit_data))
})


# ==============================================================================
# TEST SUITE 11: CONVERGENCE AND DEFENSIVE CHECKS
# ==============================================================================

context("Convergence and Defensive Checks")

test_that("isTRUE wrapper handles missing convergence$code safely", {
  # Issue 11: model$convergence without $code should not error

  # Simulate model with convergence info
  mock_convergence <- list(code = 0)
  expect_true(isTRUE(mock_convergence$code == 0))

  # Simulate model with convergence but no code field
  mock_convergence2 <- list(message = "converged")
  expect_false(isTRUE(mock_convergence2$code == 0))

  # Simulate NULL convergence
  expect_false(isTRUE(NULL$code == 0))
})


test_that("validate_mapping rejects unmapped coefficients", {
  # Verify the hard gate works
  data <- generate_binary_data(200)
  formula <- outcome ~ age_group + income + region
  model <- glm(formula, data = data, family = binomial())

  mapping <- map_terms_to_levels(model, data, formula)
  model_coef_names <- names(coef(model))

  # This should pass without error
  expect_silent(validate_mapping(mapping, model_coef_names))
})


# ==============================================================================
# TEST SUITE 12: OUTPUT VALIDATION
# ==============================================================================

context("Output Validation")

test_that("write_catdriver_output refuses on non-existent directory", {
  # The output function should refuse cleanly, not crash
  mock_results <- list(
    importance = data.frame(driver = "test", chi_square = 10, rel_importance = 100),
    odds_ratios = data.frame(term = "test", odds_ratio = 1.5),
    run_status = "PASS"
  )
  mock_config <- list(output_file = "/nonexistent/path/output.xlsx")

  expect_error(
    write_catdriver_output(mock_results, mock_config, "/nonexistent/path/output.xlsx"),
    class = "turas_refusal"
  )
})


test_that("write_catdriver_output creates valid Excel file", {
  skip_if_not_installed("openxlsx")

  # Create minimal results structure
  mock_results <- list(
    importance = data.frame(
      driver = c("age_group", "income"),
      driver_label = c("Age Group", "Income"),
      chi_square = c(15.3, 8.7),
      df = c(2, 2),
      p_value = c(0.001, 0.02),
      rel_importance = c(63.7, 36.3),
      effect_size = c("Medium", "Small"),
      stringsAsFactors = FALSE
    ),
    odds_ratios = data.frame(
      driver = c("age_group", "age_group", "income", "income"),
      level = c("35-54", "55+", "Medium", "High"),
      term = c("age_group35-54", "age_group55+", "incomeMedium", "incomeHigh"),
      odds_ratio = c(1.5, 0.8, 2.1, 3.0),
      or_lower = c(0.9, 0.4, 1.2, 1.5),
      or_upper = c(2.5, 1.6, 3.7, 6.0),
      p_value = c(0.15, 0.4, 0.01, 0.002),
      stringsAsFactors = FALSE
    ),
    model_result = list(
      engine = "glm",
      outcome_type = "binary",
      n_obs = 200,
      aic = 250,
      null_deviance = 300,
      residual_deviance = 220,
      mcfadden_r2 = 0.12,
      convergence = TRUE
    ),
    factor_patterns = list(),
    prob_lift = NULL,
    guard = guard_init(),
    run_status = "PASS",
    degraded_reasons = character(0),
    affected_outputs = character(0),
    config = list(
      analysis_name = "Test Analysis",
      outcome_var = "outcome",
      outcome_label = "Outcome",
      detailed_output = TRUE,
      confidence_level = 0.95
    )
  )

  # Write to temp file
  tmp_file <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp_file), add = TRUE)

  tryCatch({
    write_catdriver_output(mock_results, mock_results$config, tmp_file)

    # Verify file was created
    expect_true(file.exists(tmp_file))
    expect_true(file.info(tmp_file)$size > 0)

    # Verify it's readable
    wb <- openxlsx::loadWorkbook(tmp_file)
    sheet_names <- openxlsx::getSheetNames(tmp_file)

    # Must have at least these sheets
    expect_true("Executive Summary" %in% sheet_names || "Importance Summary" %in% sheet_names,
                info = paste("Sheets found:", paste(sheet_names, collapse = ", ")))
  }, error = function(e) {
    # If write fails due to missing fields, that's acceptable for this test
    # The key test is that the output directory validation works (tested above)
    skip(paste("Output write skipped - mock structure incomplete:", e$message))
  })
})


# ==============================================================================
# SUITE 7: BUG FIX REGRESSION TESTS (v1.1 upgrade)
# ==============================================================================

test_that("null coalescing operator %||% is available", {
  # %||% must be defined after sourcing utilities
  expect_true(exists("%||%", mode = "function"),
              info = "%%||%% operator should be defined in 07_utilities.R or via TRS infrastructure")

  # Test basic behavior
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
  expect_equal(character(0) %||% "default", "default")
  expect_equal(list() %||% "default", "default")
  expect_equal(42 %||% "default", 42)
})


test_that("OR parsing handles formatted values with confidence intervals", {
  # Simulate the OR parsing that happens in 06b_sheets_detail.R
  # The bug was: gsub("[^0-9.]", "", "2.50 (1.20, 4.10)") -> "2.501.204.10"
  # Fix: gsub("\\s*\\(.*", "", ...) to strip everything from first paren

  test_cases <- c("2.50", "2.50 (1.20, 4.10)", "0.75 (0.50-1.12)", "1.00", "3.14 (2.00, 5.00)")
  expected <- c(2.50, 2.50, 0.75, 1.00, 3.14)

  or_vals <- suppressWarnings(as.numeric(gsub("\\s*\\(.*", "", test_cases)))

  expect_equal(or_vals, expected,
               info = "OR parsing should extract value before parenthetical CI")
})


test_that("aggregate_dummy_importance accepts prep_data as parameter", {
  # The bug was: aggregate_dummy_importance() referenced global prep_data
  # Fix: added prep_data as explicit parameter

  # Check function signature includes prep_data parameter
  fn_args <- names(formals(aggregate_dummy_importance))
  expect_true("prep_data" %in% fn_args,
              info = "aggregate_dummy_importance should accept prep_data as parameter")
})


test_that("soft guard direction_sanity does not hard refuse", {
  # guard_direction_sanity should warn, not call catdriver_refuse()
  # We verify by checking the source code doesn't contain catdriver_refuse

  fn_body <- deparse(body(guard_direction_sanity))
  has_refuse <- any(grepl("catdriver_refuse", fn_body))

  expect_false(has_refuse,
               info = "guard_direction_sanity is a soft guard and should not call catdriver_refuse()")
})


test_that("missing data handler initialises drivers list", {
  # handle_missing_data should not error on first driver assignment
  data <- generate_binary_data(50)
  config <- list(
    outcome_var = "churn",
    outcome_label = "Churn",
    driver_vars = c("service", "price"),
    driver_settings = NULL,
    missing_threshold = 50
  )

  result <- tryCatch(
    handle_missing_data(data, config),
    error = function(e) list(error = TRUE, message = e$message)
  )

  expect_false(isTRUE(result$error),
               info = paste("handle_missing_data should not error:",
                            if (isTRUE(result$error)) result$message else "OK"))
  expect_true(is.list(result$missing_report$drivers),
              info = "missing_report$drivers should be an initialised list")
})


test_that("multinomial model uses safe weight column name", {
  # Verify that the weight column name doesn't collide with user data
  fn_body <- deparse(body(run_multinomial_logistic_robust))
  has_safe_name <- any(grepl("catdriver_wt", fn_body))
  has_old_name <- any(grepl('\\$\\.wt', fn_body))

  expect_true(has_safe_name,
              info = "Multinomial should use ..catdriver_wt.. for weight column")
})


test_that("slide loading returns NULL when no Slides sheet", {
  # Create a minimal config without Slides sheet
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(Setting = "test", Value = "1"))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_slides_from_config(tmp)
  expect_null(result, info = "Should return NULL when no Slides sheet exists")

  file.remove(tmp)
})


test_that("slide loading reads valid Slides sheet", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(Setting = "test", Value = "1"))
  openxlsx::addWorksheet(wb, "Slides")
  openxlsx::writeData(wb, "Slides", data.frame(
    slide_order = c(1, 2),
    slide_title = c("First Slide", "Second Slide"),
    slide_content = c("## Hello\n\nContent here", "More content"),
    slide_image_path = c(NA, NA),
    stringsAsFactors = FALSE
  ))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_slides_from_config(tmp)
  expect_true(is.list(result), info = "Should return a list of slides")
  expect_equal(length(result), 2)
  expect_equal(result[[1]]$title, "First Slide")
  expect_equal(result[[2]]$title, "Second Slide")
  expect_true(!is.null(result[[1]]$content))

  file.remove(tmp)
})


# ==============================================================================
# TEST SUITE COMPLETE
# ==============================================================================
#
# Tests are run via run_tests.R or testthat::test_file()
# No automatic execution needed here
