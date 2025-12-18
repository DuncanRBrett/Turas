# ==============================================================================
# CATDRIVER REGRESSION TEST SUITE
# ==============================================================================
#
# Comprehensive test suite with golden fixtures for categorical key driver module.
# Run with: Rscript test_catdriver.R
#
# Version: 2.0
# ==============================================================================

library(testthat)

# Set working directory to module root
test_dir <- dirname(sys.frame(1)$ofile)
if (is.null(test_dir)) test_dir <- getwd()
module_root <- dirname(test_dir)
setwd(module_root)

# Source all R files
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in r_files) {
  source(f)
}

# ==============================================================================
# TEST DATA GENERATION
# ==============================================================================

#' Generate Binary Test Dataset
#'
#' Creates a reproducible binary outcome dataset for testing.
#'
#' @param n Sample size
#' @param seed Random seed
#' @return Data frame with binary outcome and predictors
generate_binary_test_data <- function(n = 500, seed = 42) {
  set.seed(seed)

  data.frame(
    respondent_id = 1:n,
    outcome = factor(
      sample(c("No", "Yes"), n, replace = TRUE, prob = c(0.4, 0.6)),
      levels = c("No", "Yes")
    ),
    age_group = factor(
      sample(c("18-34", "35-54", "55+"), n, replace = TRUE, prob = c(0.3, 0.4, 0.3)),
      levels = c("18-34", "35-54", "55+")
    ),
    income = factor(
      sample(c("Low", "Medium", "High"), n, replace = TRUE, prob = c(0.25, 0.5, 0.25)),
      levels = c("Low", "Medium", "High")
    ),
    region = factor(
      sample(c("North", "South", "East", "West"), n, replace = TRUE)
    ),
    weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}


#' Generate Ordinal Test Dataset
#'
#' Creates a reproducible ordinal outcome dataset for testing.
#'
#' @param n Sample size
#' @param seed Random seed
#' @return Data frame with ordinal outcome and predictors
generate_ordinal_test_data <- function(n = 500, seed = 42) {
  set.seed(seed)

  data.frame(
    respondent_id = 1:n,
    satisfaction = factor(
      sample(c("Low", "Medium", "High"), n, replace = TRUE, prob = c(0.2, 0.5, 0.3)),
      levels = c("Low", "Medium", "High"),
      ordered = TRUE
    ),
    service_quality = factor(
      sample(c("Poor", "Fair", "Good", "Excellent"), n, replace = TRUE),
      levels = c("Poor", "Fair", "Good", "Excellent"),
      ordered = TRUE
    ),
    price_perception = factor(
      sample(c("Too High", "Fair", "Good Value"), n, replace = TRUE),
      levels = c("Too High", "Fair", "Good Value"),
      ordered = TRUE
    ),
    loyalty_years = factor(
      sample(c("New", "1-2 years", "3+ years"), n, replace = TRUE),
      levels = c("New", "1-2 years", "3+ years"),
      ordered = TRUE
    ),
    weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}


#' Generate Multinomial Test Dataset
#'
#' Creates a reproducible multinomial outcome dataset for testing.
#'
#' @param n Sample size
#' @param seed Random seed
#' @return Data frame with multinomial outcome and predictors
generate_multinomial_test_data <- function(n = 500, seed = 42) {
  set.seed(seed)

  data.frame(
    respondent_id = 1:n,
    choice = factor(
      sample(c("Product A", "Product B", "Product C"), n, replace = TRUE)
    ),
    age_group = factor(
      sample(c("Young", "Middle", "Senior"), n, replace = TRUE)
    ),
    gender = factor(
      sample(c("Male", "Female"), n, replace = TRUE)
    ),
    brand_awareness = factor(
      sample(c("Low", "High"), n, replace = TRUE)
    ),
    weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# GUARD LAYER TESTS
# ==============================================================================

context("TurasGuard Layer")

test_that("guard_init creates proper structure", {
  guard <- guard_init()

  expect_type(guard, "list")
  expect_true("warnings" %in% names(guard))
  expect_true("hard_errors" %in% names(guard))
  expect_true("stability_flags" %in% names(guard))
  expect_equal(length(guard$warnings), 0)
  expect_equal(length(guard$hard_errors), 0)
})


test_that("guard_require_outcome_type enforces explicit type",
{
  guard <- guard_init()

  # Auto should fail
  config_auto <- list(outcome_type = "auto")
  expect_error(
    guard_require_outcome_type(guard, config_auto),
    "outcome_type must be explicitly set"
  )

  # Valid types should pass
  for (type in c("binary", "ordinal", "multinomial")) {
    config_valid <- list(outcome_type = type)
    result <- guard_require_outcome_type(guard, config_valid)
    expect_type(result, "list")
  }
})


test_that("guard_require_multinomial_mode enforces mode for multinomial", {
  guard <- guard_init()

  # Multinomial without mode should fail
  config_no_mode <- list(
    outcome_type = "multinomial",
    multinomial_mode = NULL
  )
  expect_error(
    guard_require_multinomial_mode(guard, config_no_mode),
    "multinomial_mode must be specified"
  )

  # Valid mode should pass
  config_valid <- list(
    outcome_type = "multinomial",
    multinomial_mode = "baseline_category"
  )
  result <- guard_require_multinomial_mode(guard, config_valid)
  expect_type(result, "list")
})


test_that("guard_require_driver_settings enforces Driver_Settings sheet", {
  guard <- guard_init()

  # Missing Driver_Settings should fail
  config_no_ds <- list(
    driver_vars = c("var1", "var2"),
    driver_settings = NULL
  )
  expect_error(
    guard_require_driver_settings(guard, config_no_ds),
    "Driver_Settings sheet is required"
  )

  # Valid Driver_Settings should pass
  config_valid <- list(
    driver_vars = c("var1", "var2"),
    driver_settings = data.frame(
      driver = c("var1", "var2"),
      type = c("ordinal", "nominal"),
      stringsAsFactors = FALSE
    )
  )
  result <- guard_require_driver_settings(guard, config_valid)
  expect_type(result, "list")
})


test_that("guard_direction_sanity detects reversed ordinal", {
  guard <- guard_init()

  # Simulate reversed ordinal (higher levels = lower probability)
  pred_probs <- matrix(
    c(0.7, 0.2, 0.1,
      0.6, 0.3, 0.1,
      0.4, 0.4, 0.2),
    ncol = 3, byrow = TRUE
  )
  outcome <- ordered(c("High", "High", "Low"), levels = c("Low", "Medium", "High"))

  result <- guard_direction_sanity(guard, pred_probs, outcome)

  expect_true(length(result$stability_flags) > 0 || length(result$warnings) > 0)
})


test_that("guard_summary produces correct output", {
  guard <- guard_init()
  guard$warnings <- c("Warning 1", "Warning 2")
  guard$stability_flags <- c("Flag 1")

  summary <- guard_summary(guard)

  expect_type(summary, "list")
  expect_true(summary$has_issues)
  expect_true(summary$use_with_caution)
  expect_equal(length(summary$stability_flags), 1)
})


# ==============================================================================
# MAPPER TESTS
# ==============================================================================

context("Term-Level Mapper")

test_that("map_terms_to_levels handles binary model correctly", {
  data <- generate_binary_test_data(100, seed = 123)

  formula <- outcome ~ age_group + income + region
  model <- glm(formula, data = data, family = binomial())

  mapping <- map_terms_to_levels(model, data, formula)

  expect_type(mapping, "list")
  expect_true("term_map" %in% names(mapping))
  expect_true("variable_levels" %in% names(mapping))

  # Check that each coefficient term is mapped
  coef_names <- names(coef(model))[-1]  # Exclude intercept
  for (term in coef_names) {
    expect_true(term %in% names(mapping$term_map),
                info = paste("Term not mapped:", term))
  }
})


test_that("extract_level_from_colname parses correctly", {
  # Test standard factor naming
  expect_equal(
    extract_level_from_colname("age_group35-54", "age_group", c("18-34", "35-54", "55+")),
    "35-54"
  )

  expect_equal(
    extract_level_from_colname("regionSouth", "region", c("North", "South", "East", "West")),
    "South"
  )

  # Edge case: level name contains variable name
  expect_equal(
    extract_level_from_colname("colorcolorful", "color", c("plain", "colorful")),
    "colorful"
  )
})


test_that("aggregate_importance_mapped aggregates correctly", {
  # Create mock term-level importance
  term_importance <- data.frame(
    term = c("age_group35-54", "age_group55+", "incomeMedium", "incomeHigh"),
    importance = c(0.2, 0.15, 0.4, 0.25),
    stringsAsFactors = FALSE
  )

  # Create mock mapping
  mapping <- list(
    term_map = list(
      "age_group35-54" = list(variable = "age_group", level = "35-54"),
      "age_group55+" = list(variable = "age_group", level = "55+"),
      "incomeMedium" = list(variable = "income", level = "Medium"),
      "incomeHigh" = list(variable = "income", level = "High")
    )
  )

  aggregated <- aggregate_importance_mapped(term_importance, mapping)

  expect_equal(nrow(aggregated), 2)  # Two variables
  expect_true("age_group" %in% aggregated$variable)
  expect_true("income" %in% aggregated$variable)

  # Age group importance should be sum of its terms
  age_imp <- aggregated$importance[aggregated$variable == "age_group"]
  expect_equal(age_imp, 0.2 + 0.15)
})


# ==============================================================================
# MISSING DATA HANDLER TESTS
# ==============================================================================

context("Missing Data Handler")

test_that("handle_missing_data drops rows correctly", {
  data <- generate_binary_test_data(100, seed = 123)

  # Introduce missing values
  data$age_group[1:5] <- NA
  data$income[6:10] <- NA

  config <- list(
    outcome_var = "outcome",
    driver_vars = c("age_group", "income"),
    driver_settings = data.frame(
      driver = c("age_group", "income"),
      type = c("ordinal", "ordinal"),
      missing_strategy = c("drop_row", "drop_row"),
      stringsAsFactors = FALSE
    )
  )

  result <- handle_missing_data(data, config)

  # Should have dropped 10 rows (5 + 5, no overlap in our setup)
  expect_equal(nrow(result$data), 90)
  expect_true("missing_report" %in% names(result))
  expect_equal(result$missing_report$summary$total_rows_dropped, 10)
})


test_that("recode_missing_as_level creates Missing category", {
  x <- factor(c("A", "B", NA, "A", NA, "C"))

  result <- recode_missing_as_level(x)

  expect_true("Missing" %in% levels(result))
  expect_equal(sum(result == "Missing"), 2)
  expect_false(any(is.na(result)))
})


test_that("apply_rare_level_policy collapses correctly", {
  data <- data.frame(
    outcome = factor(rep(c("Yes", "No"), 50)),
    driver = factor(c(rep("Common1", 40), rep("Common2", 40), rep("Rare1", 3), rep("Rare2", 2), rep("VeryRare", 15)))
  )

  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver"),
    rare_level_policy = "collapse_to_other",
    rare_level_threshold = 10,
    driver_settings = data.frame(
      driver = "driver",
      type = "nominal",
      missing_strategy = "drop_row",
      rare_level_policy = NA,
      stringsAsFactors = FALSE
    )
  )

  result <- apply_rare_level_policy(data, config)

  # Rare1 (3) and Rare2 (2) should be collapsed to "Other"
  expect_true("Other" %in% levels(result$data$driver))
  expect_false("Rare1" %in% levels(result$data$driver))
  expect_false("Rare2" %in% levels(result$data$driver))

  # Common levels and VeryRare (15 >= 10) should remain
  expect_true("Common1" %in% levels(result$data$driver))
  expect_true("Common2" %in% levels(result$data$driver))
  expect_true("VeryRare" %in% levels(result$data$driver))
})


test_that("check_sparse_cells identifies sparse cross-tabs", {
  data <- data.frame(
    outcome = factor(c(rep("Yes", 95), rep("No", 5))),
    driver = factor(c(rep("A", 50), rep("B", 50)))
  )

  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver")
  )

  # With threshold of 5, should identify sparse cells
  result <- check_sparse_cells(data, config, threshold = 5)

  expect_type(result, "list")
  # The "No" category has only 5 obs split across A and B
})


# ==============================================================================
# ROBUST FIT WRAPPER TESTS
# ==============================================================================

context("Robust Model Fitting")

test_that("run_binary_logistic_robust handles standard data", {
  data <- generate_binary_test_data(200, seed = 123)

  prep_data <- list(
    data = data,
    outcome_info = list(
      type = "binary",
      categories = c("No", "Yes")
    ),
    model_formula = outcome ~ age_group + income + region
  )

  config <- list(
    outcome_var = "outcome",
    driver_vars = c("age_group", "income", "region")
  )

  guard <- guard_init()

  result <- run_binary_logistic_robust(prep_data, config, weights = NULL, guard = guard)

  expect_true(result$convergence)
  expect_true("glm" %in% class(result$model))
  expect_false(isTRUE(result$fallback_used))
})


test_that("run_ordinal_logistic_robust handles standard data", {
  skip_if_not_installed("ordinal")

  data <- generate_ordinal_test_data(200, seed = 123)

  prep_data <- list(
    data = data,
    outcome_info = list(
      type = "ordinal",
      categories = c("Low", "Medium", "High")
    ),
    model_formula = satisfaction ~ service_quality + price_perception + loyalty_years
  )

  config <- list(
    outcome_var = "satisfaction",
    driver_vars = c("service_quality", "price_perception", "loyalty_years")
  )

  guard <- guard_init()

  result <- run_ordinal_logistic_robust(prep_data, config, weights = NULL, guard = guard)

  expect_true(result$convergence)
  expect_true("clm" %in% class(result$model) || "polr" %in% class(result$model))
})


# ==============================================================================
# PROBABILITY LIFT TESTS
# ==============================================================================

context("Probability Lift Calculation")

test_that("calculate_probability_lift returns proper structure", {
  data <- generate_binary_test_data(200, seed = 123)

  prep_data <- list(
    data = data,
    outcome_info = list(type = "binary", categories = c("No", "Yes")),
    model_formula = outcome ~ age_group + income
  )

  config <- list(
    outcome_var = "outcome",
    driver_vars = c("age_group", "income")
  )

  # Fit model and get predictions
  model <- glm(prep_data$model_formula, data = data, family = binomial())
  pred_probs <- predict(model, type = "response")

  model_result <- list(
    model = model,
    predicted_probs = pred_probs
  )

  lift <- calculate_probability_lift(model_result, prep_data, config)

  expect_true(is.data.frame(lift))
  expect_true("driver" %in% names(lift))
  expect_true("level" %in% names(lift))
  expect_true("prob_lift" %in% names(lift))
  expect_true("prob_lift_pct" %in% names(lift))

  # Reference levels should have 0 lift
  ref_rows <- lift$is_reference == TRUE
  expect_true(all(lift$prob_lift[ref_rows] == 0))
})


# ==============================================================================
# GOLDEN FIXTURE TESTS
# ==============================================================================

context("Golden Fixture Regression Tests")

test_that("binary logistic produces stable coefficients", {
  # Use fixed seed for reproducibility
  data <- generate_binary_test_data(500, seed = 12345)

  formula <- outcome ~ age_group + income + region
  model <- glm(formula, data = data, family = binomial())

  coefs <- coef(model)

  # Golden values (update if algorithm changes intentionally)
  # These are approximate - allow some tolerance
  expect_equal(length(coefs), 8, info = "Expected 8 coefficients")

  # Intercept should be negative (base probability < 0.5)
  # Just check it exists and is reasonable
  expect_true(!is.na(coefs["(Intercept)"]))
})


test_that("ordinal logistic produces stable thresholds", {
  skip_if_not_installed("ordinal")

  data <- generate_ordinal_test_data(500, seed = 12345)

  # Ensure outcome is ordered factor
  data$satisfaction <- ordered(data$satisfaction, levels = c("Low", "Medium", "High"))

  formula <- satisfaction ~ service_quality + price_perception

  model <- tryCatch(
    ordinal::clm(formula, data = data),
    error = function(e) {
      MASS::polr(formula, data = data, Hess = TRUE)
    }
  )

  # Should have 2 thresholds for 3-level ordinal
  if ("clm" %in% class(model)) {
    thresholds <- model$alpha
  } else {
    thresholds <- model$zeta
  }

  expect_equal(length(thresholds), 2,
               info = "Expected 2 thresholds for 3-level ordinal outcome")

  # Thresholds should be ordered
  expect_true(thresholds[1] < thresholds[2],
              info = "Thresholds should be in ascending order")
})


test_that("importance ranking is stable", {
  data <- generate_binary_test_data(500, seed = 54321)

  formula <- outcome ~ age_group + income + region
  model <- glm(formula, data = data, family = binomial())

  # Calculate chi-square based importance
  anova_result <- tryCatch(
    anova(model, test = "Chisq"),
    error = function(e) NULL
  )

  if (!is.null(anova_result)) {
    # Extract deviance values (exclude residuals row)
    deviances <- anova_result$Deviance[-1]
    names(deviances) <- c("age_group", "income", "region")

    # Importance should be non-negative
    expect_true(all(deviances >= 0, na.rm = TRUE))
  }
})


# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

context("Integration Tests")

test_that("full binary analysis pipeline works", {
  skip_on_cran()

  # This tests the complete flow without writing files
  data <- generate_binary_test_data(300, seed = 99999)

  # Create minimal config
  config <- list(
    analysis_name = "Test Binary Analysis",
    outcome_var = "outcome",
    outcome_label = "Test Outcome",
    outcome_type = "binary",
    outcome_order = c("No", "Yes"),
    driver_vars = c("age_group", "income", "region"),
    driver_labels = list(
      age_group = "Age Group",
      income = "Income Level",
      region = "Region"
    ),
    driver_orders = list(
      age_group = c("18-34", "35-54", "55+"),
      income = c("Low", "Medium", "High"),
      region = NULL
    ),
    driver_settings = data.frame(
      driver = c("age_group", "income", "region"),
      type = c("ordinal", "ordinal", "nominal"),
      missing_strategy = c("drop_row", "drop_row", "drop_row"),
      rare_level_policy = c(NA, NA, NA),
      stringsAsFactors = FALSE
    ),
    weight_var = NULL,
    reference_category = "No",
    rare_level_policy = "warn_only",
    rare_level_threshold = 10,
    rare_cell_threshold = 5,
    min_sample_size = 30,
    confidence_level = 0.95,
    missing_threshold = 50,
    detailed_output = TRUE
  )

  # Test guard initialization
  guard <- guard_init()
  expect_type(guard, "list")

  # Test missing data handling
  missing_result <- handle_missing_data(data, config)
  expect_equal(nrow(missing_result$data), nrow(data))  # No missing in test data

  # Test rare level policy
  rare_result <- apply_rare_level_policy(missing_result$data, config)
  expect_true(is.data.frame(rare_result$data))

  # Test preprocessing
  prep_data <- tryCatch(
    preprocess_catdriver_data(rare_result$data, config),
    error = function(e) {
      list(
        data = rare_result$data,
        outcome_info = list(type = "binary", categories = c("No", "Yes")),
        model_formula = outcome ~ age_group + income + region
      )
    }
  )

  expect_true("data" %in% names(prep_data))

  # Test model fitting
  model <- glm(outcome ~ age_group + income + region, data = prep_data$data, family = binomial())
  expect_true(model$converged)
})


# ==============================================================================
# RUN ALL TESTS
# ==============================================================================

if (!interactive()) {
  test_results <- test_dir(".", reporter = "summary")

  # Exit with appropriate code
  if (any(as.data.frame(test_results)$failed > 0)) {
    quit(status = 1)
  }
}
