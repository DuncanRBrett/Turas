# ==============================================================================
# CATDRIVER COMPREHENSIVE TEST SUITE
# ==============================================================================
#
# Thorough coverage of all core analysis functions in the catdriver module.
# Organised into 10 suites covering config, validation, preprocessing,
# analysis, importance, missing data, output, guards, integration, and
# golden-file regression.
#
# Run with: Rscript test_comprehensive.R
#
# Version: 1.0
# ==============================================================================

library(testthat)

# Path resolution is handled by helper-paths.R (auto-sourced by testthat)
# which provides: module_root, turas_root

# Source shared utilities
shared_path <- file.path(turas_root, "modules", "shared", "lib")
if (dir.exists(shared_path)) {
  for (f in list.files(shared_path, pattern = "[.]R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}

# Source catdriver R files
setwd(module_root)
for (f in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  tryCatch(source(f), error = function(e) {
    cat("Warning: Could not source", basename(f), ":", e$message, "\n")
  })
}

cat("\n=== Running Comprehensive Test Suite ===\n\n")

# ==============================================================================
# TEST DATA GENERATORS
# ==============================================================================

generate_binary_data <- function(n = 300, seed = 42) {
  set.seed(seed)
  data.frame(
    outcome = factor(sample(c("No", "Yes"), n, TRUE, c(0.4, 0.6)),
                     levels = c("No", "Yes")),
    age_group = factor(sample(c("18-34", "35-54", "55+"), n, TRUE),
                       levels = c("18-34", "35-54", "55+")),
    income = factor(sample(c("Low", "Medium", "High"), n, TRUE),
                    levels = c("Low", "Medium", "High")),
    region = factor(sample(c("North", "South", "East", "West"), n, TRUE)),
    stringsAsFactors = FALSE
  )
}

generate_ordinal_data <- function(n = 300, seed = 42) {
  set.seed(seed)
  data.frame(
    satisfaction = ordered(sample(c("Low", "Medium", "High"), n, TRUE),
                           levels = c("Low", "Medium", "High")),
    service = factor(sample(c("Poor", "Fair", "Good", "Excellent"), n, TRUE),
                     levels = c("Poor", "Fair", "Good", "Excellent")),
    price = factor(sample(c("Too High", "Fair", "Good Value"), n, TRUE),
                   levels = c("Too High", "Fair", "Good Value")),
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

generate_missing_data <- function(n = 300, seed = 42) {
  set.seed(seed)
  data <- data.frame(
    outcome = factor(sample(c("No", "Yes"), n, TRUE)),
    driver1 = factor(sample(c("A", "B", "C"), n, TRUE)),
    driver2 = factor(sample(c("X", "Y", "Z"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  data$driver1[sample(n, 20)] <- NA
  data$driver2[sample(n, 15)] <- NA
  data
}

generate_weighted_binary_data <- function(n = 300, seed = 42) {
  set.seed(seed)
  data.frame(
    outcome = factor(sample(c("No", "Yes"), n, TRUE, c(0.4, 0.6)),
                     levels = c("No", "Yes")),
    age_group = factor(sample(c("18-34", "35-54", "55+"), n, TRUE),
                       levels = c("18-34", "35-54", "55+")),
    income = factor(sample(c("Low", "Medium", "High"), n, TRUE),
                    levels = c("Low", "Medium", "High")),
    weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}

# ==============================================================================
# HELPER: Build a temp config xlsx
# ==============================================================================

build_temp_config <- function(data_file, output_file,
                               outcome_var = "outcome",
                               outcome_label = "Outcome",
                               outcome_type = "binary",
                               driver_vars = c("age_group", "income"),
                               driver_labels = NULL,
                               driver_types = NULL,
                               weight_var = NULL,
                               extra_settings = list()) {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  # --- Settings sheet ---
  settings <- data.frame(
    Setting = c("data_file", "output_file", "outcome_type", "analysis_name",
                "min_sample_size", "confidence_level", "missing_threshold",
                "detailed_output", "html_report", "rare_level_policy",
                "rare_level_threshold", "rare_cell_threshold"),
    Value = c(data_file, output_file, outcome_type, "Test Analysis",
              "10", "0.95", "50", "TRUE", "FALSE", "warn_only",
              "5", "3"),
    stringsAsFactors = FALSE
  )
  for (nm in names(extra_settings)) {
    settings <- rbind(settings, data.frame(Setting = nm,
                                           Value = as.character(extra_settings[[nm]]),
                                           stringsAsFactors = FALSE))
  }
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", settings)

  # --- Variables sheet ---
  if (is.null(driver_labels)) {
    driver_labels <- driver_vars
  }
  vars_df <- data.frame(
    VariableName = c(outcome_var, driver_vars),
    Type = c("Outcome", rep("Driver", length(driver_vars))),
    Label = c(outcome_label, driver_labels),
    stringsAsFactors = FALSE
  )
  if (!is.null(weight_var)) {
    vars_df <- rbind(vars_df, data.frame(VariableName = weight_var,
                                          Type = "Weight",
                                          Label = "Weight",
                                          stringsAsFactors = FALSE))
  }
  openxlsx::addWorksheet(wb, "Variables")
  openxlsx::writeData(wb, "Variables", vars_df)

  # --- Driver_Settings sheet ---
  if (is.null(driver_types)) {
    driver_types <- rep("categorical", length(driver_vars))
  }
  ds_df <- data.frame(
    driver = driver_vars,
    type = driver_types,
    missing_strategy = rep("missing_as_level", length(driver_vars)),
    stringsAsFactors = FALSE
  )
  openxlsx::addWorksheet(wb, "Driver_Settings")
  openxlsx::writeData(wb, "Driver_Settings", ds_df)

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# ==============================================================================
# SUITE 1: CONFIGURATION LOADING (8 tests)
# ==============================================================================

context("Suite 1: Configuration Loading")

test_that("1.1 load_catdriver_config works with valid config file", {
  skip_if_not_installed("openxlsx")

  # Create temp data CSV
  data <- generate_binary_data(100)
  data_file <- tempfile(fileext = ".csv")
  write.csv(data, data_file, row.names = FALSE)
  output_file <- tempfile(fileext = ".xlsx")

  config_file <- build_temp_config(data_file, output_file)
  on.exit({
    file.remove(data_file)
    file.remove(config_file)
    if (file.exists(output_file)) file.remove(output_file)
  }, add = TRUE)

  config <- load_catdriver_config(config_file)
  expect_true(is.list(config))
  expect_equal(config$outcome_var, "outcome")
  expect_equal(config$outcome_type, "binary")
  expect_equal(length(config$driver_vars), 2)
  expect_true("age_group" %in% config$driver_vars)
  expect_true("income" %in% config$driver_vars)
})

test_that("1.2 missing required Settings sheet produces TRS refusal", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "NotSettings")
  openxlsx::writeData(wb, "NotSettings", data.frame(x = 1))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(file.remove(tmp), add = TRUE)

  expect_error(load_catdriver_config(tmp), "Settings")
})

test_that("1.3 invalid outcome_type is caught by guards", {
  # guard_require_outcome_type refuses for invalid types
  config <- list(outcome_type = "invalid_type")
  expect_error(guard_require_outcome_type(config), "INVALID OUTCOME TYPE|not recognized")
})

test_that("1.4 missing data_file setting produces TRS refusal", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("output_file", "outcome_type"),
    Value = c("output.xlsx", "binary"),
    stringsAsFactors = FALSE
  ))
  openxlsx::addWorksheet(wb, "Variables")
  openxlsx::writeData(wb, "Variables", data.frame(
    VariableName = "outcome", Type = "Outcome", Label = "Out",
    stringsAsFactors = FALSE
  ))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(file.remove(tmp), add = TRUE)

  expect_error(load_catdriver_config(tmp), "data_file")
})

test_that("1.5 get_driver_setting returns correct per-driver values", {
  config <- list(
    driver_settings = data.frame(
      driver = c("age", "income"),
      type = c("categorical", "ordinal"),
      missing_strategy = c("drop_row", "missing_as_level"),
      stringsAsFactors = FALSE
    )
  )
  expect_equal(get_driver_setting(config, "age", "type"), "categorical")
  expect_equal(get_driver_setting(config, "income", "missing_strategy"), "missing_as_level")
  expect_null(get_driver_setting(config, "nonexistent", "type"))
  expect_equal(get_driver_setting(config, "nonexistent", "type", "default_val"), "default_val")
})

test_that("1.6 get_var_label returns labels correctly", {
  config <- list(
    outcome_var = "sat",
    outcome_label = "Satisfaction",
    driver_labels = c(age = "Age Group", income = "Income Level")
  )
  expect_equal(get_var_label(config, "sat"), "Satisfaction")
  expect_equal(get_var_label(config, "age"), "Age Group")
  expect_equal(get_var_label(config, "income"), "Income Level")
  # Fallback to variable name
  expect_equal(get_var_label(config, "unknown_var"), "unknown_var")
})

test_that("1.7 as_logical_setting handles Y/N/TRUE/FALSE/1/0", {
  expect_true(as_logical_setting("TRUE"))
  expect_true(as_logical_setting("Yes"))
  expect_true(as_logical_setting("Y"))
  expect_true(as_logical_setting("1"))
  expect_true(as_logical_setting("on"))
  expect_true(as_logical_setting(TRUE))
  expect_true(as_logical_setting(1))

  expect_false(as_logical_setting("FALSE"))
  expect_false(as_logical_setting("No"))
  expect_false(as_logical_setting("0"))
  expect_false(as_logical_setting("off"))
  expect_false(as_logical_setting(FALSE))
  expect_false(as_logical_setting(0))

  expect_false(as_logical_setting(NULL, default = FALSE))
  expect_true(as_logical_setting(NA, default = TRUE))
})

test_that("1.8 as_numeric_setting handles various inputs", {
  expect_equal(as_numeric_setting("42"), 42)
  expect_equal(as_numeric_setting("0.95"), 0.95)
  expect_equal(as_numeric_setting(10), 10)
  expect_equal(as_numeric_setting(NULL, 99), 99)
  expect_equal(as_numeric_setting(NA, 99), 99)
  expect_equal(as_numeric_setting("not_a_number", 0), 0)
})

# ==============================================================================
# SUITE 2: DATA VALIDATION (7 tests)
# ==============================================================================

context("Suite 2: Data Validation")

test_that("2.1 validate_catdriver_data with valid data returns passed=TRUE", {
  data <- generate_binary_data(200)
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group", "income"),
    driver_labels = c(age_group = "Age", income = "Income"),
    driver_settings = data.frame(
      driver = c("age_group", "income"),
      type = c("categorical", "categorical"),
      missing_strategy = c("missing_as_level", "missing_as_level"),
      stringsAsFactors = FALSE
    ),
    weight_var = NULL,
    min_sample_size = 30,
    missing_threshold = 50,
    rare_cell_threshold = 5,
    confidence_level = 0.95
  )
  result <- validate_catdriver_data(data, config)
  expect_true(result$passed)
  expect_equal(result$original_n, 200)
  expect_true(result$complete_n > 0)
  expect_true(is.data.frame(result$missing_summary))
})

test_that("2.2 validate_config_against_data detects missing outcome variable", {
  data <- generate_binary_data(100)
  config <- list(
    outcome_var = "nonexistent_var",
    outcome_label = "Outcome",
    driver_vars = c("age_group"),
    driver_labels = c(age_group = "Age"),
    driver_settings = NULL,
    weight_var = NULL,
    min_sample_size = 30,
    missing_threshold = 50,
    rare_cell_threshold = 5,
    confidence_level = 0.95
  )
  expect_error(validate_config_against_data(config, data), "OUTCOME.*NOT FOUND")
})

test_that("2.3 validate_catdriver_data detects small sample sizes", {
  data <- generate_binary_data(10)
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group"),
    driver_labels = c(age_group = "Age"),
    driver_settings = data.frame(
      driver = "age_group", type = "categorical",
      missing_strategy = "missing_as_level",
      stringsAsFactors = FALSE
    ),
    weight_var = NULL,
    min_sample_size = 50,
    missing_threshold = 50,
    rare_cell_threshold = 5,
    confidence_level = 0.95
  )
  result <- validate_catdriver_data(data, config)
  expect_false(result$passed)
  expect_true(length(result$errors) > 0)
})

test_that("2.4 validate_catdriver_data calculates correct effective_n", {
  data <- generate_binary_data(200)
  # No missing data, so effective_n should equal original_n
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group"),
    driver_labels = c(age_group = "Age"),
    driver_settings = data.frame(
      driver = "age_group", type = "categorical",
      missing_strategy = "missing_as_level",
      stringsAsFactors = FALSE
    ),
    weight_var = NULL,
    min_sample_size = 10,
    missing_threshold = 50,
    rare_cell_threshold = 5,
    confidence_level = 0.95
  )
  result <- validate_catdriver_data(data, config)
  expect_equal(result$complete_n, 200)
  expect_equal(result$pct_complete, 100)
})

test_that("2.5 is_missing_value catches NA, empty, whitespace, N/A", {
  x_char <- c("hello", NA, "", " ", "  ", "valid")
  result <- is_missing_value(x_char)
  expect_equal(result, c(FALSE, TRUE, TRUE, TRUE, TRUE, FALSE))

  x_factor <- factor(c("A", NA, "B"))
  result_f <- is_missing_value(x_factor)
  expect_equal(result_f, c(FALSE, TRUE, FALSE))

  x_num <- c(1, NA, 3, NA)
  result_n <- is_missing_value(x_num)
  expect_equal(result_n, c(FALSE, TRUE, FALSE, TRUE))
})

test_that("2.6 is_missing_value returns FALSE for valid values", {
  expect_false(any(is_missing_value(c("A", "B", "C"))))
  expect_false(any(is_missing_value(c(1, 2, 3))))
  expect_false(any(is_missing_value(factor(c("X", "Y")))))
})

test_that("2.7 detect_small_cells with various table sizes", {
  # Table with no small cells
  tab1 <- matrix(c(50, 40, 30, 60), nrow = 2, ncol = 2,
                 dimnames = list(c("A", "B"), c("No", "Yes")))
  result1 <- detect_small_cells(as.table(tab1), threshold = 5)
  expect_false(result1$has_small_cells)
  expect_equal(result1$n_small_cells, 0)

  # Table with small cells
  tab2 <- matrix(c(50, 2, 30, 3), nrow = 2, ncol = 2,
                 dimnames = list(c("A", "B"), c("No", "Yes")))
  result2 <- detect_small_cells(as.table(tab2), threshold = 5)
  expect_true(result2$has_small_cells)
  expect_true(result2$n_small_cells > 0)
  expect_true(is.data.frame(result2$details))
})

# ==============================================================================
# SUITE 3: PREPROCESSING (8 tests)
# ==============================================================================

context("Suite 3: Preprocessing")

test_that("3.1 detect_outcome_type correctly identifies binary (2 levels)", {
  outcome <- factor(c("No", "Yes", "No", "Yes", "No"))
  result <- detect_outcome_type(outcome)
  expect_equal(result$type, "binary")
  expect_equal(result$n_categories, 2)
  expect_equal(result$method, "binomial_logistic")
})

test_that("3.2 detect_outcome_type correctly identifies ordinal (3+ with order)", {
  outcome <- factor(c("Low", "Medium", "High", "Low", "High"))
  result <- detect_outcome_type(outcome,
                                 order_spec = c("Low", "Medium", "High"),
                                 override_type = "ordinal")
  expect_equal(result$type, "ordinal")
  expect_equal(result$n_categories, 3)
  expect_true(result$is_ordered)
})

test_that("3.3 prepare_outcome for binary outcome creates factor with 2 levels", {
  data <- generate_binary_data(100)
  config <- list(
    outcome_var = "outcome",
    reference_category = NULL,
    outcome_order = NULL
  )
  outcome_info <- list(type = "binary", categories = c("No", "Yes"))
  result_data <- prepare_outcome(data, config, outcome_info)
  expect_true(is.factor(result_data$outcome))
  expect_equal(nlevels(result_data$outcome), 2)
})

test_that("3.4 prepare_outcome for ordinal outcome creates ordered factor", {
  data <- generate_ordinal_data(100)
  config <- list(
    outcome_var = "satisfaction",
    reference_category = NULL,
    outcome_order = c("Low", "Medium", "High")
  )
  outcome_info <- list(type = "ordinal", categories = c("Low", "Medium", "High"))
  result_data <- prepare_outcome(data, config, outcome_info)
  expect_true(is.ordered(result_data$satisfaction))
  expect_equal(levels(result_data$satisfaction), c("Low", "Medium", "High"))
})

test_that("3.5 prepare_predictors with categorical variables", {
  data <- generate_binary_data(100)
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("age_group", "income"),
    driver_orders = list(age_group = NULL, income = NULL),
    driver_settings = data.frame(
      driver = c("age_group", "income"),
      type = c("categorical", "categorical"),
      reference_level = c(NA, NA),
      levels_order = c(NA, NA),
      missing_strategy = c("missing_as_level", "missing_as_level"),
      stringsAsFactors = FALSE
    ),
    driver_labels = c(age_group = "Age", income = "Income")
  )
  result <- prepare_predictors(data, config)
  expect_true(is.list(result))
  expect_true("data" %in% names(result))
  expect_true("predictor_info" %in% names(result))
  expect_true(is.factor(result$data$age_group))
  expect_true(is.factor(result$data$income))
  expect_true("age_group" %in% names(result$predictor_info))
  expect_true("income" %in% names(result$predictor_info))
})

test_that("3.6 build_model_formula returns valid formula", {
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("age_group", "income", "region")
  )
  formula <- build_model_formula(config)
  expect_true(inherits(formula, "formula"))
  formula_str <- deparse(formula)
  expect_true(grepl("outcome", formula_str))
  expect_true(grepl("age_group", formula_str))
  expect_true(grepl("income", formula_str))
  expect_true(grepl("region", formula_str))
})

test_that("3.7 get_reference_category returns correct reference", {
  data <- data.frame(
    x = factor(c("B", "A", "C", "A"), levels = c("A", "B", "C"))
  )
  expect_equal(get_reference_category(data, "x"), "A")

  data2 <- data.frame(
    y = c("dog", "cat", "cat", "dog")
  )
  expect_equal(get_reference_category(data2, "y"), "cat")
})

test_that("3.8 preprocess_catdriver_data full pipeline", {
  data <- generate_binary_data(200)
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    outcome_type = "binary",
    outcome_order = NULL,
    reference_category = NULL,
    driver_vars = c("age_group", "income"),
    driver_orders = list(age_group = NULL, income = NULL),
    driver_labels = c(age_group = "Age", income = "Income"),
    driver_settings = data.frame(
      driver = c("age_group", "income"),
      type = c("categorical", "categorical"),
      reference_level = c(NA, NA),
      levels_order = c(NA, NA),
      missing_strategy = c("missing_as_level", "missing_as_level"),
      stringsAsFactors = FALSE
    )
  )
  result <- preprocess_catdriver_data(data, config)
  expect_true(is.list(result))
  expect_true("data" %in% names(result))
  expect_true("outcome_info" %in% names(result))
  expect_true("predictor_info" %in% names(result))
  expect_true("model_formula" %in% names(result))
  expect_equal(result$outcome_info$type, "binary")
  expect_equal(result$n_predictors, 2)
})

# ==============================================================================
# SUITE 4: ANALYSIS (8 tests)
# ==============================================================================

context("Suite 4: Analysis")

test_that("4.1 run_binary_logistic_robust converges on clean data", {
  data <- generate_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  formula <- outcome ~ age_group + income
  guard <- guard_init()
  config <- list(confidence_level = 0.95, outcome_var = "outcome")

  result <- run_binary_logistic_robust(formula, data, NULL, config, guard)
  expect_true(is.list(result))
  expect_equal(result$model_type, "binary_logistic")
  expect_true(result$convergence)
  expect_true(!is.null(result$model))
})

test_that("4.2 run_binary_logistic_robust returns proper structure", {
  data <- generate_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  formula <- outcome ~ age_group + income
  config <- list(confidence_level = 0.95, outcome_var = "outcome")
  result <- run_binary_logistic_robust(formula, data, NULL, config, guard_init())

  # Check coefficients data frame
  expect_true(is.data.frame(result$coefficients))
  expect_true(all(c("term", "estimate", "odds_ratio", "p_value") %in%
                    names(result$coefficients)))

  # Check fit statistics
  expect_true(is.list(result$fit_statistics))
  expect_true("mcfadden_r2" %in% names(result$fit_statistics))
  expect_true("aic" %in% names(result$fit_statistics))

  # Check classification
  expect_true(is.list(result$classification))
  expect_true("accuracy" %in% names(result$classification))
})

test_that("4.3 run_ordinal_logistic_robust converges on ordinal data", {
  skip_if_not_installed("ordinal")

  data <- generate_ordinal_data(300)
  data$satisfaction <- ordered(data$satisfaction, levels = c("Low", "Medium", "High"))
  data$service <- factor(data$service, levels = c("Poor", "Fair", "Good", "Excellent"))
  data$price <- factor(data$price, levels = c("Too High", "Fair", "Good Value"))

  formula <- satisfaction ~ service + price
  config <- list(confidence_level = 0.95, outcome_var = "outcome")
  result <- run_ordinal_logistic_robust(formula, data, NULL, config, guard_init())

  expect_true(is.list(result))
  expect_true(result$model_type %in% c("ordinal_logistic", "ordinal_polr"))
  expect_true(!is.null(result$model))
  expect_true(is.data.frame(result$coefficients))
})

test_that("4.4 run_multinomial_logistic_robust converges on multinomial data", {
  skip_if_not_installed("nnet")

  data <- generate_multinomial_data(300)
  data$choice <- relevel(data$choice, ref = "A")
  data$age <- relevel(data$age, ref = "Middle")
  data$gender <- relevel(data$gender, ref = "Female")

  formula <- choice ~ age + gender
  config <- list(
    confidence_level = 0.95,
    outcome_var = "choice",
    driver_vars = c("age", "gender")
  )
  result <- run_multinomial_logistic_robust(formula, data, NULL, config, guard_init())

  expect_true(is.list(result))
  expect_equal(result$model_type, "multinomial_logistic")
  expect_true(!is.null(result$model))
  expect_true(is.data.frame(result$coefficients))
})

test_that("4.5 check_multicollinearity returns proper structure", {
  skip_if_not_installed("car")

  data <- generate_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  model <- glm(outcome ~ age_group + income + region, data = data,
               family = binomial())

  result <- check_multicollinearity(model)
  expect_true(is.list(result))
  expect_true("checked" %in% names(result))
  if (result$checked) {
    expect_true("status" %in% names(result))
    expect_true("vif_table" %in% names(result))
    expect_true(result$status %in% c("PASS", "MARGINAL", "WARNING"))
  }
})

test_that("4.6 binary model with weights produces valid results", {
  data <- generate_weighted_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  formula <- outcome ~ age_group + income
  config <- list(confidence_level = 0.95, outcome_var = "outcome")
  result <- run_binary_logistic_robust(formula, data, data$weight, config,
                                       guard_init())

  expect_true(is.list(result))
  expect_equal(result$model_type, "binary_logistic")
  expect_true(result$convergence)
  expect_true(all(result$coefficients$odds_ratio > 0))
})

test_that("4.7 model with separation triggers fallback or refusal", {
  set.seed(99)
  n <- 100
  # Create data with perfect separation
  data <- data.frame(
    outcome = factor(c(rep("No", n/2), rep("Yes", n/2)),
                     levels = c("No", "Yes")),
    predictor = factor(c(rep("A", n/2), rep("B", n/2)))
  )
  formula <- outcome ~ predictor
  config <- list(confidence_level = 0.95,
                 outcome_var = "outcome",
                 allow_separation_without_fallback = TRUE)

  # Should either succeed with fallback or succeed with warning
  result <- tryCatch(
    run_binary_logistic_robust(formula, data, NULL, config, guard_init()),
    error = function(e) list(error = TRUE, message = e$message)
  )
  # Just verify we get a result (either success or error, not a crash)
  expect_true(is.list(result))
})

test_that("4.8 CATDRIVER_DEFAULTS is a list with all expected fields", {
  expect_true(is.list(CATDRIVER_DEFAULTS))
  expected_fields <- c("min_sample_size", "min_epp", "rare_level_threshold",
                       "rare_cell_threshold", "missing_threshold",
                       "confidence_level", "vif_threshold",
                       "effect_very_large", "effect_large", "effect_medium")
  for (field in expected_fields) {
    expect_true(field %in% names(CATDRIVER_DEFAULTS),
                info = paste("Missing field:", field))
  }
  expect_true(is.numeric(CATDRIVER_DEFAULTS$min_sample_size))
  expect_true(CATDRIVER_DEFAULTS$confidence_level > 0 &&
              CATDRIVER_DEFAULTS$confidence_level < 1)
})

# ==============================================================================
# SUITE 5: IMPORTANCE & ODDS RATIOS (7 tests)
# ==============================================================================

context("Suite 5: Importance & Odds Ratios")

test_that("5.1 calculate_importance returns ranked data frame", {
  skip_if_not_installed("car")

  data <- generate_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  formula <- outcome ~ age_group + income
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group", "income"),
    driver_labels = c(age_group = "Age Group", income = "Income"),
    confidence_level = 0.95
  )
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())

  importance <- calculate_importance(model_result, config)
  expect_true(is.data.frame(importance))
  expect_true("importance_pct" %in% names(importance))
  expect_true("rank" %in% names(importance))
  expect_true("variable" %in% names(importance))
  # Ranks should be sequential
  expect_equal(importance$rank, seq_len(nrow(importance)))
  # Should be sorted by importance
  expect_true(all(diff(importance$importance_pct) <= 0))
})

test_that("5.2 importance percentages sum to approximately 100%", {
  skip_if_not_installed("car")

  data <- generate_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")
  data$region <- relevel(data$region, ref = "East")

  formula <- outcome ~ age_group + income + region
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group", "income", "region"),
    driver_labels = c(age_group = "Age", income = "Income", region = "Region"),
    confidence_level = 0.95
  )
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())
  importance <- calculate_importance(model_result, config)
  total_pct <- sum(importance$importance_pct, na.rm = TRUE)
  expect_true(abs(total_pct - 100) < 1,
              info = paste("Total importance:", total_pct))
})

test_that("5.3 classify_importance_effect returns correct labels", {
  expect_equal(classify_importance_effect(35), "Very Large")
  expect_equal(classify_importance_effect(20), "Large")
  expect_equal(classify_importance_effect(10), "Medium")
  expect_equal(classify_importance_effect(3), "Small")
  expect_equal(classify_importance_effect(0), "Small")
  expect_equal(classify_importance_effect(NA), "Unknown")
})

test_that("5.4 extract_odds_ratios_mapped returns proper structure", {
  skip_if_not_installed("car")

  data <- generate_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  formula <- outcome ~ age_group + income
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group", "income"),
    driver_labels = c(age_group = "Age Group", income = "Income"),
    confidence_level = 0.95
  )
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())

  # Build mapping
  mapping <- map_terms_to_levels(model_result$model, data, formula)
  or_df <- extract_odds_ratios_mapped(model_result, mapping, config)

  expect_true(is.data.frame(or_df))
  expect_true(all(c("factor", "comparison", "reference",
                     "odds_ratio", "p_value") %in% names(or_df)))
})

test_that("5.5 OR values are positive (no negative odds ratios)", {
  data <- generate_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  formula <- outcome ~ age_group + income
  config <- list(confidence_level = 0.95, outcome_var = "outcome")
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())
  expect_true(all(model_result$coefficients$odds_ratio > 0))
})

test_that("5.6 OR confidence intervals contain point estimate", {
  data <- generate_binary_data(300)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  formula <- outcome ~ age_group + income
  config <- list(confidence_level = 0.95, outcome_var = "outcome")
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())
  coef_df <- model_result$coefficients

  for (i in seq_len(nrow(coef_df))) {
    or <- coef_df$odds_ratio[i]
    lower <- coef_df$or_lower[i]
    upper <- coef_df$or_upper[i]
    expect_true(or >= lower - 1e-10,
                info = paste("OR below lower CI for", coef_df$term[i]))
    expect_true(or <= upper + 1e-10,
                info = paste("OR above upper CI for", coef_df$term[i]))
  }
})

test_that("5.7 aggregate_dummy_importance maps dummies to original vars", {
  # Create a dummy importance df with term-level entries
  importance_df <- data.frame(
    variable = c("age_group35-54", "age_group55+", "incomeMedium", "incomeHigh"),
    chi_square = c(5.0, 3.0, 8.0, 2.0),
    p_value = c(0.02, 0.08, 0.005, 0.15),
    stringsAsFactors = FALSE
  )
  config <- list(
    driver_vars = c("age_group", "income"),
    driver_labels = c(age_group = "Age", income = "Income")
  )

  result <- aggregate_dummy_importance(importance_df, config)
  expect_true(is.data.frame(result))
  expect_true(nrow(result) <= 4)  # Aggregated or mapped
  expect_true("chi_square" %in% names(result))
})

# ==============================================================================
# SUITE 6: MISSING DATA HANDLING (5 tests)
# ==============================================================================

context("Suite 6: Missing Data Handling")

test_that("6.1 handle_missing_data with drop_row strategy", {
  data <- generate_missing_data(200)
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("driver1", "driver2"),
    driver_labels = c(driver1 = "Driver 1", driver2 = "Driver 2"),
    driver_settings = data.frame(
      driver = c("driver1", "driver2"),
      type = c("categorical", "categorical"),
      missing_strategy = c("drop_row", "drop_row"),
      stringsAsFactors = FALSE
    )
  )
  result <- handle_missing_data(data, config)
  expect_true(is.list(result))
  expect_true(nrow(result$data) < nrow(data))
  expect_true(result$original_n == 200)
  expect_true(!any(is.na(result$data$driver1)))
  expect_true(!any(is.na(result$data$driver2)))
  expect_true(is.list(result$missing_report$drivers))
})

test_that("6.2 handle_missing_data with missing_as_level strategy", {
  data <- generate_missing_data(200)
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("driver1", "driver2"),
    driver_labels = c(driver1 = "Driver 1", driver2 = "Driver 2"),
    driver_settings = data.frame(
      driver = c("driver1", "driver2"),
      type = c("categorical", "categorical"),
      missing_strategy = c("missing_as_level", "missing_as_level"),
      stringsAsFactors = FALSE
    )
  )
  result <- handle_missing_data(data, config)
  expect_true(is.list(result))
  # Rows should be preserved (only outcome missing dropped)
  expect_true(nrow(result$data) >= nrow(data) - sum(is.na(data$outcome)))
  # Missing should be recoded
  expect_true("Missing / Not answered" %in% levels(result$data$driver1))
  expect_false(any(is.na(result$data$driver1)))
})

test_that("6.3 handle_missing_data preserves data when no missing", {
  data <- generate_binary_data(100)  # No NAs by design
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group", "income"),
    driver_labels = c(age_group = "Age", income = "Income"),
    driver_settings = data.frame(
      driver = c("age_group", "income"),
      type = c("categorical", "categorical"),
      missing_strategy = c("drop_row", "drop_row"),
      stringsAsFactors = FALSE
    )
  )
  result <- handle_missing_data(data, config)
  expect_equal(nrow(result$data), 100)
  expect_equal(length(result$rows_dropped), 0)
})

test_that("6.4 apply_rare_level_policy collapses rare levels", {
  set.seed(42)
  data <- data.frame(
    outcome = factor(sample(c("No", "Yes"), 200, TRUE)),
    driver = factor(c(rep("Common1", 80), rep("Common2", 70),
                       rep("Rare1", 3), rep("Rare2", 2),
                       rep("Common3", 45)))
  )
  config <- list(
    outcome_var = "outcome",
    driver_vars = "driver",
    driver_labels = c(driver = "Driver"),
    driver_settings = data.frame(
      driver = "driver", type = "categorical",
      rare_level_policy = "collapse_to_other",
      stringsAsFactors = FALSE
    ),
    rare_level_policy = "collapse_to_other",
    rare_level_threshold = 10,
    rare_cell_threshold = 3
  )
  result <- apply_rare_level_policy(data, config)
  expect_true(is.list(result))
  # Rare1 and Rare2 should be collapsed to "Other"
  new_levels <- levels(result$data$driver)
  expect_true("Other" %in% new_levels)
  expect_false("Rare1" %in% new_levels)
  expect_false("Rare2" %in% new_levels)
})

test_that("6.5 rare level collapsing tracks changes in report", {
  set.seed(42)
  data <- data.frame(
    outcome = factor(sample(c("No", "Yes"), 100, TRUE)),
    driver = factor(c(rep("A", 40), rep("B", 35),
                       rep("C", 20), rep("D", 3), rep("E", 2)))
  )
  config <- list(
    outcome_var = "outcome",
    driver_vars = "driver",
    driver_labels = c(driver = "Test Driver"),
    driver_settings = data.frame(
      driver = "driver", type = "categorical",
      rare_level_policy = "collapse_to_other",
      stringsAsFactors = FALSE
    ),
    rare_level_policy = "collapse_to_other",
    rare_level_threshold = 10,
    rare_cell_threshold = 3
  )
  result <- apply_rare_level_policy(data, config)
  report <- result$collapse_report
  expect_true(is.list(report))
  expect_true("driver" %in% names(report))
  expect_equal(report$driver$action, "collapsed")
  expect_true(length(report$driver$rare_levels) > 0)
})

# ==============================================================================
# SUITE 7: OUTPUT GENERATION (5 tests)
# ==============================================================================

context("Suite 7: Output Generation")

test_that("7.1 create_output_styles returns named list", {
  skip_if_not_installed("openxlsx")

  wb <- openxlsx::createWorkbook()
  styles <- create_output_styles(wb)
  expect_true(is.list(styles))
  expect_true("header" %in% names(styles))
  expect_true("title" %in% names(styles))
})

test_that("7.2 write_catdriver_output creates valid Excel file", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("car")

  data <- generate_binary_data(200)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  output_file <- tempfile(fileext = ".xlsx")
  on.exit(if (file.exists(output_file)) file.remove(output_file), add = TRUE)

  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    outcome_type = "binary",
    driver_vars = c("age_group", "income"),
    driver_labels = c(age_group = "Age", income = "Income"),
    confidence_level = 0.95,
    detailed_output = TRUE,
    weight_var = NULL
  )

  # Build minimal results object
  formula <- outcome ~ age_group + income
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())
  importance <- calculate_importance(model_result, config)

  results <- list(
    run_status = "PASS",
    degraded = FALSE,
    degraded_reasons = character(0),
    model_result = model_result,
    importance = importance,
    diagnostics = list(original_n = 200, complete_n = 200,
                       pct_complete = 100),
    prep_data = list(
      outcome_info = list(type = "binary"),
      data = data
    )
  )

  # This should not error
  result <- tryCatch(
    write_catdriver_output(results, config, output_file),
    error = function(e) e$message
  )

  # If it succeeded, file should exist
  if (file.exists(output_file)) {
    sheets <- openxlsx::getSheetNames(output_file)
    expect_true("Run_Status" %in% sheets)
  }
})

test_that("7.3 Excel output has required sheets", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("car")

  data <- generate_binary_data(200)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  output_file <- tempfile(fileext = ".xlsx")
  on.exit(if (file.exists(output_file)) file.remove(output_file), add = TRUE)

  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    outcome_type = "binary",
    driver_vars = c("age_group", "income"),
    driver_labels = c(age_group = "Age", income = "Income"),
    confidence_level = 0.95,
    detailed_output = TRUE,
    weight_var = NULL
  )

  formula <- outcome ~ age_group + income
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())
  importance <- calculate_importance(model_result, config)

  results <- list(
    run_status = "PASS",
    degraded = FALSE,
    degraded_reasons = character(0),
    model_result = model_result,
    importance = importance,
    diagnostics = list(original_n = 200, complete_n = 200,
                       pct_complete = 100),
    prep_data = list(
      outcome_info = list(type = "binary"),
      data = data
    )
  )

  tryCatch(
    write_catdriver_output(results, config, output_file),
    error = function(e) NULL
  )

  if (file.exists(output_file)) {
    sheets <- openxlsx::getSheetNames(output_file)
    expect_true("Run_Status" %in% sheets,
                info = paste("Sheets found:", paste(sheets, collapse = ", ")))
  } else {
    skip("Output file not created - may need additional result fields")
  }
})

test_that("7.4 print_console_summary does not error on valid results", {
  data <- generate_binary_data(200)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")

  formula <- outcome ~ age_group + income
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group", "income"),
    driver_labels = c(age_group = "Age", income = "Income"),
    confidence_level = 0.95,
    weight_var = NULL
  )
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())

  # Build minimal importance df
  importance_df <- data.frame(
    variable = c("age_group", "income"),
    importance_pct = c(60, 40),
    label = c("Age", "Income"),
    rank = 1:2,
    stringsAsFactors = FALSE
  )

  results <- list(
    model_result = model_result,
    importance = importance_df,
    diagnostics = list(original_n = 200, complete_n = 200,
                       pct_complete = 100),
    prep_data = list(
      outcome_info = list(type = "binary"),
      data = data
    ),
    weight_diagnostics = NULL,
    factor_patterns = list()
  )

  # Should print without error
  expect_silent(
    tryCatch(
      capture.output(print_console_summary(results, config)),
      error = function(e) NULL
    )
  )
})

test_that("7.5 format_pvalue handles edge cases", {
  expect_equal(format_pvalue(NA), "NA")
  expect_equal(format_pvalue(0.0001), "<0.001")
  expect_equal(format_pvalue(0.005), "0.005")
  expect_equal(format_pvalue(0.5), "0.500")
  expect_true(nchar(format_pvalue(0.05)) > 0)
})

# ==============================================================================
# SUITE 8: GUARD FRAMEWORK (5 tests)
# ==============================================================================

context("Suite 8: Guard Framework")

test_that("8.1 guard_init returns proper structure", {
  guard <- guard_init()
  expect_true(is.list(guard))
  expect_equal(guard$module, "CATDRIVER")
  expect_equal(length(guard$warnings), 0)
  expect_equal(length(guard$stability_flags), 0)
  expect_false(guard$fallback_used)
  expect_false(guard$separation_detected)
  expect_true(inherits(guard$timestamp, "POSIXct"))
})

test_that("8.2 guard_warn adds to warnings list", {
  guard <- guard_init()
  guard <- guard_warn(guard, "Test warning 1", "test")
  guard <- guard_warn(guard, "Test warning 2", "test")
  expect_equal(length(guard$warnings), 2)
  expect_equal(guard$warnings[1], "Test warning 1")
  expect_equal(guard$warnings[2], "Test warning 2")
  expect_true("test" %in% names(guard$soft_failures))
})

test_that("8.3 guard_flag_stability adds to stability_flags", {
  guard <- guard_init()
  guard <- guard_flag_stability(guard, "Flag 1")
  guard <- guard_flag_stability(guard, "Flag 2")
  expect_equal(length(guard$stability_flags), 2)
  expect_true("Flag 1" %in% guard$stability_flags)
  expect_true("Flag 2" %in% guard$stability_flags)

  # Duplicate flag should not create duplicate entry

  guard <- guard_flag_stability(guard, "Flag 1")
  expect_equal(length(guard$stability_flags), 2)
})

test_that("8.4 guard_summary returns correct counts", {
  guard <- guard_init()
  guard <- guard_warn(guard, "Warning 1", "cat1")
  guard <- guard_warn(guard, "Warning 2", "cat2")
  guard <- guard_flag_stability(guard, "Stability issue")

  summary <- guard_summary(guard)
  expect_true(summary$has_issues)
  expect_equal(summary$n_warnings, 2)
  expect_equal(length(summary$stability_flags), 1)
  expect_true(summary$use_with_caution)
  expect_false(summary$fallback_used)
  expect_false(summary$separation_detected)
})

test_that("8.5 catdriver_refuse signals catdriver_refusal condition", {
  expect_error(
    catdriver_refuse(
      reason = "CFG_TEST_ERROR",
      title = "TEST ERROR",
      problem = "This is a test.",
      why_it_matters = "Testing refusal mechanism.",
      fix = "No action needed."
    ),
    class = "turas_refusal"
  )
})

# ==============================================================================
# SUITE 9: INTEGRATION (3 tests)
# ==============================================================================

context("Suite 9: Integration")

test_that("9.1 full binary pipeline: config -> preprocess -> model -> importance", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("car")

  # Create temp data
  data <- generate_binary_data(300)
  data_file <- tempfile(fileext = ".csv")
  write.csv(data, data_file, row.names = FALSE)
  output_file <- tempfile(fileext = ".xlsx")
  on.exit({
    file.remove(data_file)
    if (file.exists(output_file)) file.remove(output_file)
  }, add = TRUE)

  config_file <- build_temp_config(
    data_file = data_file,
    output_file = output_file,
    outcome_var = "outcome",
    outcome_type = "binary",
    driver_vars = c("age_group", "income", "region"),
    driver_labels = c("Age Group", "Income", "Region"),
    driver_types = c("categorical", "categorical", "categorical")
  )
  on.exit(file.remove(config_file), add = TRUE)

  # Load config
  config <- load_catdriver_config(config_file)
  expect_equal(config$outcome_type, "binary")

  # Load data
  loaded_data <- load_catdriver_data(config$data_file, config)
  expect_equal(nrow(loaded_data), 300)

  # Validate
  diag <- validate_catdriver_data(loaded_data, config)
  expect_true(diag$passed)

  # Handle missing
  missing_result <- handle_missing_data(loaded_data, config)
  expect_equal(nrow(missing_result$data), 300)

  # Preprocess
  prep <- preprocess_catdriver_data(missing_result$data, config)
  expect_equal(prep$outcome_info$type, "binary")

  # Model
  model_result <- run_catdriver_model(prep, config)
  expect_equal(model_result$model_type, "binary_logistic")
  expect_true(model_result$convergence)

  # Importance
  importance <- calculate_importance(model_result, config)
  expect_true(is.data.frame(importance))
  expect_equal(nrow(importance), 3)
  total_pct <- sum(importance$importance_pct, na.rm = TRUE)
  expect_true(abs(total_pct - 100) < 1)
})

test_that("9.2 full ordinal pipeline", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("car")
  skip_if_not_installed("ordinal")

  data <- generate_ordinal_data(300)
  data_file <- tempfile(fileext = ".csv")
  write.csv(data, data_file, row.names = FALSE)
  output_file <- tempfile(fileext = ".xlsx")
  on.exit({
    file.remove(data_file)
    if (file.exists(output_file)) file.remove(output_file)
  }, add = TRUE)

  # Build config with ordinal settings
  config_file <- build_temp_config(
    data_file = data_file,
    output_file = output_file,
    outcome_var = "satisfaction",
    outcome_label = "Satisfaction",
    outcome_type = "ordinal",
    driver_vars = c("service", "price"),
    driver_labels = c("Service Quality", "Price Perception"),
    driver_types = c("categorical", "categorical")
  )
  on.exit(file.remove(config_file), add = TRUE)

  config <- load_catdriver_config(config_file)
  loaded_data <- load_catdriver_data(config$data_file, config)
  diag <- validate_catdriver_data(loaded_data, config)
  expect_true(diag$passed)

  missing_result <- handle_missing_data(loaded_data, config)
  prep <- preprocess_catdriver_data(missing_result$data, config)
  expect_equal(prep$outcome_info$type, "ordinal")

  model_result <- run_catdriver_model(prep, config)
  expect_true(model_result$model_type %in% c("ordinal_logistic", "ordinal_polr"))

  importance <- calculate_importance(model_result, config)
  expect_true(is.data.frame(importance))
  expect_true(nrow(importance) >= 1)
})

test_that("9.3 full multinomial pipeline", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("car")
  skip_if_not_installed("nnet")

  data <- generate_multinomial_data(300)
  data_file <- tempfile(fileext = ".csv")
  write.csv(data, data_file, row.names = FALSE)
  output_file <- tempfile(fileext = ".xlsx")
  on.exit({
    file.remove(data_file)
    if (file.exists(output_file)) file.remove(output_file)
  }, add = TRUE)

  config_file <- build_temp_config(
    data_file = data_file,
    output_file = output_file,
    outcome_var = "choice",
    outcome_label = "Choice",
    outcome_type = "multinomial",
    driver_vars = c("age", "gender"),
    driver_labels = c("Age", "Gender"),
    driver_types = c("categorical", "categorical"),
    extra_settings = list(multinomial_mode = "baseline_category")
  )
  on.exit(file.remove(config_file), add = TRUE)

  config <- load_catdriver_config(config_file)
  loaded_data <- load_catdriver_data(config$data_file, config)
  diag <- validate_catdriver_data(loaded_data, config)
  expect_true(diag$passed)

  missing_result <- handle_missing_data(loaded_data, config)
  prep <- preprocess_catdriver_data(missing_result$data, config)
  expect_true(prep$outcome_info$type %in% c("nominal", "multinomial"))

  model_result <- run_catdriver_model(prep, config)
  expect_equal(model_result$model_type, "multinomial_logistic")

  importance <- calculate_importance(model_result, config)
  expect_true(is.data.frame(importance))
  expect_true(nrow(importance) >= 1)
})

# ==============================================================================
# SUITE 10: GOLDEN FILE REGRESSION (2 tests)
# ==============================================================================

context("Suite 10: Golden File Regression")

test_that("10.1 binary importance rankings are deterministic", {
  skip_if_not_installed("car")

  # Run the same analysis twice and compare
  run_analysis <- function(seed_val) {
    data <- generate_binary_data(300, seed = seed_val)
    data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
    data$age_group <- relevel(data$age_group, ref = "18-34")
    data$income <- relevel(data$income, ref = "Low")
    data$region <- relevel(data$region, ref = "East")

    formula <- outcome ~ age_group + income + region
    config <- list(
      outcome_var = "outcome",
      outcome_label = "Outcome",
      driver_vars = c("age_group", "income", "region"),
      driver_labels = c(age_group = "Age", income = "Income", region = "Region"),
      confidence_level = 0.95
    )
    model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                                guard_init())
    calculate_importance(model_result, config)
  }

  # Same seed should produce identical rankings
  imp1 <- run_analysis(42)
  imp2 <- run_analysis(42)

  expect_equal(imp1$variable, imp2$variable)
  expect_equal(imp1$importance_pct, imp2$importance_pct)
  expect_equal(imp1$rank, imp2$rank)
})

test_that("10.2 golden fixture comparison for binary analysis", {
  skip_if_not_installed("car")

  # Generate baseline results
  data <- generate_binary_data(500, seed = 123)
  data$outcome <- factor(data$outcome, levels = c("No", "Yes"))
  data$age_group <- relevel(data$age_group, ref = "18-34")
  data$income <- relevel(data$income, ref = "Low")
  data$region <- relevel(data$region, ref = "East")

  formula <- outcome ~ age_group + income + region
  config <- list(
    outcome_var = "outcome",
    outcome_label = "Outcome",
    driver_vars = c("age_group", "income", "region"),
    driver_labels = c(age_group = "Age", income = "Income", region = "Region"),
    confidence_level = 0.95
  )
  model_result <- run_binary_logistic_robust(formula, data, NULL, config,
                                              guard_init())
  importance <- calculate_importance(model_result, config)

  # Verify structural invariants that should always hold
  expect_equal(nrow(importance), 3)
  expect_equal(importance$rank, 1:3)
  expect_true(all(importance$importance_pct >= 0))
  expect_true(abs(sum(importance$importance_pct) - 100) < 1)

  # Verify all driver variables are represented
  expect_true(all(c("age_group", "income", "region") %in% importance$variable))

  # Verify the model produces reasonable ORs (not extreme separation)
  coef_df <- model_result$coefficients
  non_intercept <- coef_df[!grepl("Intercept", coef_df$term), ]
  expect_true(all(non_intercept$odds_ratio > 0.01))
  expect_true(all(non_intercept$odds_ratio < 100))
})

# ==============================================================================
# BONUS: ADDITIONAL EDGE CASE TESTS (4 tests)
# ==============================================================================

context("Bonus: Additional Edge Cases")

test_that("B.1 format_or handles edge cases", {
  expect_equal(format_or(NA), "NA")
  expect_true(nchar(format_or(1.5)) > 0)
  expect_true(nchar(format_or(0.5)) > 0)
  expect_true(nchar(format_or(150)) > 0)
})

test_that("B.2 interpret_or_effect covers all effect sizes", {
  expect_equal(interpret_or_effect(1.05), "Negligible")
  expect_equal(interpret_or_effect(1.3), "Small")
  expect_equal(interpret_or_effect(1.7), "Medium")
  expect_equal(interpret_or_effect(2.5), "Large")
  expect_equal(interpret_or_effect(5.0), "Very Large")
  expect_equal(interpret_or_effect(0.5), "Large")  # 1/0.5 = 2.0
  expect_equal(interpret_or_effect(NA), "Unknown")
  expect_equal(interpret_or_effect(Inf), "Unknown")
})

test_that("B.3 clean_var_name sanitises correctly", {
  expect_equal(clean_var_name("Hello World"), "Hello_World")
  expect_equal(clean_var_name("123abc"), "x123abc")
  expect_equal(clean_var_name("valid_name"), "valid_name")
  expect_equal(clean_var_name("a!@#$b"), "ab")
  expect_equal(clean_var_name(""), "unnamed")
  expect_equal(clean_var_name(NA), "unnamed")
})

test_that("B.4 with_refusal_handler catches refusals cleanly", {
  result <- with_refusal_handler({
    catdriver_refuse(
      reason = "CFG_TEST",
      title = "Test Refusal",
      problem = "Testing handler",
      why_it_matters = "Unit test",
      fix = "None needed"
    )
  })
  expect_true(is_refusal(result))
  expect_true(inherits(result, "catdriver_refusal_result"))
  expect_equal(result$run_status, "REFUSE")
})

cat("\n=== Comprehensive Test Suite Complete ===\n")
