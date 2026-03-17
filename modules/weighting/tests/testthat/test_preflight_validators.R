# ==============================================================================
# TESTS: Preflight Validators (preflight_validators.R)
# ==============================================================================
# Tests for the 14 cross-referential checks that validate config vs data
# before weighting calculations begin.
# ==============================================================================

skip_if_not <- function(cond, msg) {
  if (!cond) skip(msg)
}

# Helper to create a minimal valid config
make_test_config <- function() {
  list(
    general = list(project_name = "Test", data_file = "data.csv"),
    weight_specs = data.frame(
      weight_name = "w1",
      method = "rim",
      stringsAsFactors = FALSE
    ),
    rim_targets = data.frame(
      weight_name = "w1",
      variable = c("Gender", "Gender"),
      category = c("Male", "Female"),
      target_percent = c(50, 50),
      stringsAsFactors = FALSE
    ),
    design_targets = NULL,
    cell_targets = NULL,
    advanced_settings = NULL,
    notes = NULL
  )
}

# --- Check: Weight specs methods ---

test_that("check_weight_specs_methods detects invalid method", {
  skip_if(!exists("check_weight_specs_methods", mode = "function"),
          "check_weight_specs_methods not available")

  specs <- data.frame(
    weight_name = "w1",
    method = "invalid_method",
    stringsAsFactors = FALSE
  )
  available_sheets <- c("General", "Weight_Specifications", "Rim_Targets")
  error_log <- NULL
  result <- check_weight_specs_methods(specs, available_sheets, error_log)
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("invalid", result$Detail, ignore.case = TRUE)))
})

test_that("check_weight_specs_methods passes with valid single-method config", {
  skip_if(!exists("check_weight_specs_methods", mode = "function"),
          "check_weight_specs_methods not available")

  specs <- data.frame(
    weight_name = "w1",
    method = "rim",
    stringsAsFactors = FALSE
  )
  available_sheets <- c("General", "Weight_Specifications", "Rim_Targets")
  error_log <- NULL
  result <- check_weight_specs_methods(specs, available_sheets, error_log)
  expect_true(is.null(result) || nrow(result) == 0 || sum(result$Severity == "Error") == 0)
})

# --- Check: Rim targets sum ---

test_that("check_rim_targets_sum detects incorrect sum", {
  skip_if(!exists("check_rim_targets_sum", mode = "function"),
          "check_rim_targets_sum not available")

  rim_df <- data.frame(
    weight_name = rep("w1", 2),
    variable = c("Gender", "Gender"),
    category = c("Male", "Female"),
    target_percent = c(45, 50),  # sums to 95, not 100
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_rim_targets_sum(rim_df, error_log)
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("100", result$Detail)))
})

test_that("check_rim_targets_sum passes with correct sum", {
  skip_if(!exists("check_rim_targets_sum", mode = "function"),
          "check_rim_targets_sum not available")

  rim_df <- data.frame(
    weight_name = rep("w1", 2),
    variable = c("Gender", "Gender"),
    category = c("Male", "Female"),
    target_percent = c(48.5, 51.5),
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_rim_targets_sum(rim_df, error_log)
  expect_true(is.null(result) || nrow(result) == 0 || sum(result$Severity == "Error") == 0)
})

# --- Check: Cell combinations vs data (dynamic columns) ---

test_that("check_cell_combinations_vs_data detects missing variable column", {
  skip_if(!exists("check_cell_combinations_vs_data", mode = "function"),
          "check_cell_combinations_vs_data not available")

  cell_df <- data.frame(
    weight_name = "w1",
    Gender = "Male",
    NonExistent = "A",
    target_percent = 50,
    stringsAsFactors = FALSE
  )
  data <- data.frame(
    Gender = c("Male", "Female"),
    Age = c("18-34", "35-54"),
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_cell_combinations_vs_data(cell_df, data, error_log)
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("Not Found", result$Issue)))
})

test_that("check_cell_combinations_vs_data detects missing combination", {
  skip_if(!exists("check_cell_combinations_vs_data", mode = "function"),
          "check_cell_combinations_vs_data not available")

  cell_df <- data.frame(
    weight_name = "w1",
    Gender = "Other",
    Age = "65+",
    target_percent = 10,
    stringsAsFactors = FALSE
  )
  data <- data.frame(
    Gender = c("Male", "Female", "Male", "Female"),
    Age = c("18-34", "18-34", "35-54", "35-54"),
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_cell_combinations_vs_data(cell_df, data, error_log)
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("Not in Data", result$Issue)))
})

test_that("check_cell_combinations_vs_data passes with valid data", {
  skip_if(!exists("check_cell_combinations_vs_data", mode = "function"),
          "check_cell_combinations_vs_data not available")

  cell_df <- data.frame(
    weight_name = c("w1", "w1"),
    Gender = c("Male", "Female"),
    Age = c("18-34", "35-54"),
    target_percent = c(50, 50),
    stringsAsFactors = FALSE
  )
  data <- data.frame(
    Gender = c("Male", "Female", "Male", "Female"),
    Age = c("18-34", "35-54", "18-34", "35-54"),
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_cell_combinations_vs_data(cell_df, data, error_log)
  expect_true(is.null(result) || nrow(result) == 0 || sum(result$Severity == "Error") == 0)
})

# --- Check: Cell targets sum ---

test_that("check_cell_targets_sum detects incorrect sum", {
  skip_if(!exists("check_cell_targets_sum", mode = "function"),
          "check_cell_targets_sum not available")

  cell_df <- data.frame(
    weight_name = rep("w1", 2),
    Gender = c("Male", "Female"),
    target_percent = c(30, 30),  # sums to 60, not 100
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_cell_targets_sum(cell_df, error_log)
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("100", result$Detail)))
})

# --- Check: Trim config consistency ---

test_that("check_trim_config_consistency detects missing trim_method", {
  skip_if(!exists("check_trim_config_consistency", mode = "function"),
          "check_trim_config_consistency not available")

  specs <- data.frame(
    weight_name = "w1",
    method = "rim",
    apply_trimming = "Y",
    trim_method = NA,
    trim_value = 5,
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_trim_config_consistency(specs, error_log)
  expect_true(nrow(result) > 0)
})

# --- Check: Duplicate weight names ---

test_that("check_duplicate_weight_names detects duplicates", {
  skip_if(!exists("check_duplicate_weight_names", mode = "function"),
          "check_duplicate_weight_names not available")

  specs <- data.frame(
    weight_name = c("w1", "w1", "w2"),
    method = c("rim", "design", "rim"),
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_duplicate_weight_names(specs, error_log)
  expect_true(nrow(result) > 0)
  expect_true(any(grepl("Duplicate", result$Issue, ignore.case = TRUE)))
})

test_that("check_duplicate_weight_names passes with unique names", {
  skip_if(!exists("check_duplicate_weight_names", mode = "function"),
          "check_duplicate_weight_names not available")

  specs <- data.frame(
    weight_name = c("w1", "w2", "w3"),
    method = c("rim", "design", "cell"),
    stringsAsFactors = FALSE
  )
  error_log <- NULL
  result <- check_duplicate_weight_names(specs, error_log)
  expect_true(is.null(result) || nrow(result) == 0)
})

# --- Check: Colour codes ---

test_that("check_colour_codes detects invalid hex", {
  skip_if(!exists("check_colour_codes", mode = "function"),
          "check_colour_codes not available")

  # check_colour_codes expects config$brand_colour directly, not nested in general
  config <- list(brand_colour = "not-a-hex", accent_colour = "#2aa198")
  error_log <- NULL
  result <- check_colour_codes(config, error_log)
  expect_true(nrow(result) > 0)
})

test_that("check_colour_codes passes with valid hex", {
  skip_if(!exists("check_colour_codes", mode = "function"),
          "check_colour_codes not available")

  config <- list(brand_colour = "#1e3a5f", accent_colour = "#2aa198")
  error_log <- NULL
  result <- check_colour_codes(config, error_log)
  expect_true(is.null(result) || nrow(result) == 0)
})

# --- Orchestrator ---

test_that("validate_weighting_preflight runs without error on valid config", {
  skip_if(!exists("validate_weighting_preflight", mode = "function"),
          "validate_weighting_preflight not available")

  data <- create_simple_survey(n = 100)
  # Orchestrator expects config$specs, not config$weight_specs
  config <- list(
    specs = data.frame(
      weight_name = "w1",
      method = "rim",
      stringsAsFactors = FALSE
    ),
    rim_targets = data.frame(
      weight_name = rep("w1", 2),
      variable = c("Gender", "Gender"),
      category = c("Male", "Female"),
      target_percent = c(50, 50),
      stringsAsFactors = FALSE
    ),
    design_targets = NULL,
    cell_targets = NULL,
    advanced_settings = NULL,
    available_sheets = c("General", "Weight_Specifications", "Rim_Targets")
  )

  result <- validate_weighting_preflight(config, data)
  expect_true(is.data.frame(result))
})

test_that("validate_weighting_preflight detects issues in bad config", {
  skip_if(!exists("validate_weighting_preflight", mode = "function"),
          "validate_weighting_preflight not available")

  data <- create_simple_survey(n = 100)
  config <- list(
    specs = data.frame(
      weight_name = "w1",
      method = "invalid",
      stringsAsFactors = FALSE
    ),
    rim_targets = NULL,
    design_targets = NULL,
    cell_targets = NULL,
    advanced_settings = NULL,
    available_sheets = c("General", "Weight_Specifications")
  )

  result <- validate_weighting_preflight(config, data)
  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
})
