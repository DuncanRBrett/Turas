# ==============================================================================
# KEYDRIVER TERM MAPPING TESTS
# ==============================================================================
#
# Tests for modules/keydriver/R/02_term_mapping.R
#
# Covers:
#   - build_term_mapping() creates valid mapping data.frame
#   - Mapping contains all original drivers
#   - find_matching_terms() finds correct model terms
#   - get_valid_driver_types() returns expected types
#   - get_valid_agg_methods() returns expected methods
#   - Categorical drivers expand to correct dummy terms
#   - driver_settings parameter enables type-based aggregation
#   - validate_term_mapping() passes with valid mapping
#   - validate_term_mapping() refuses on mismatched mapping
#   - enforce_encoding_policy() applies treatment contrasts
#   - has_categorical_predictors() detection
#   - get_numeric_drivers() extraction
#
# ==============================================================================

# Locate module root robustly (works with test_file and test_dir)
.find_module_dir <- function() {
  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(ofile)) {
    return(normalizePath(file.path(dirname(ofile), "..", ".."), mustWork = FALSE))
  }
  tp <- tryCatch(testthat::test_path(), error = function(e) ".")
  normalizePath(file.path(tp, "..", ".."), mustWork = FALSE)
}
module_dir <- .find_module_dir()
project_root <- normalizePath(file.path(module_dir, "..", ".."), mustWork = FALSE)

# Source test data generators
source(file.path(module_dir, "tests", "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure (required by guard/analysis functions)
shared_lib <- file.path(project_root, "modules", "shared", "lib")
source(file.path(shared_lib, "trs_refusal.R"))

# Source the modules under test
module_r_dir <- file.path(module_dir, "R")
source(file.path(module_r_dir, "00_guard.R"))
source(file.path(module_r_dir, "01_config.R"))
source(file.path(module_r_dir, "02_term_mapping.R"))

# Define %||% locally in case it is not already available
`%||%` <- function(a, b) if (is.null(a)) b else a


# ==============================================================================
# SETUP: Generate mixed predictor test data
# ==============================================================================

mixed_data <- generate_mixed_kda_data(n = 200, seed = 123)

mixed_driver_vars <- c("price", "quality", "service", "region", "segment")
mixed_outcome_var <- "overall_satisfaction"

mixed_formula <- stats::as.formula(
  paste(mixed_outcome_var, "~", paste(mixed_driver_vars, collapse = " + "))
)

# Convert categorical columns to factors for model.matrix
mixed_data_factored <- mixed_data
mixed_data_factored$region <- factor(mixed_data_factored$region)
mixed_data_factored$segment <- factor(mixed_data_factored$segment)


# ==============================================================================
# get_valid_driver_types() and get_valid_agg_methods()
# ==============================================================================

test_that("get_valid_driver_types returns expected type strings", {
  types <- get_valid_driver_types()
  expect_true(is.character(types))
  expect_true("continuous" %in% types)
  expect_true("ordinal" %in% types)
  expect_true("categorical" %in% types)
  expect_equal(length(types), 3)
})

test_that("get_valid_agg_methods returns expected method strings", {
  methods <- get_valid_agg_methods()
  expect_true(is.character(methods))
  expect_true("partial_r2" %in% methods)
  expect_true("grouped_permutation" %in% methods)
  expect_true("grouped_shapley" %in% methods)
  expect_equal(length(methods), 3)
})


# ==============================================================================
# build_term_mapping() - basic structure
# ==============================================================================

test_that("build_term_mapping creates valid mapping structure", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)

  expect_true(is.list(mapping))
  expect_true("term_map" %in% names(mapping))
  expect_true("driver_terms" %in% names(mapping))
  expect_true("predictor_info" %in% names(mapping))
  expect_true("all_terms" %in% names(mapping))
})

test_that("build_term_mapping mapping contains all original drivers", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)

  mapped_drivers <- unique(as.character(mapping$term_map[mapping$term_map != ""]))
  expect_true(all(mixed_driver_vars %in% mapped_drivers),
              info = paste0("Missing drivers: ",
                            paste(setdiff(mixed_driver_vars, mapped_drivers), collapse = ", ")))
})

test_that("build_term_mapping predictor_info has correct dimensions", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)

  info <- mapping$predictor_info
  expect_s3_class(info, "data.frame")
  expect_equal(nrow(info), length(mixed_driver_vars))
  expect_true("driver" %in% names(info))
  expect_true("type" %in% names(info))
  expect_true("n_terms" %in% names(info))
  expect_true("reference_level" %in% names(info))
})

test_that("build_term_mapping detects continuous vs categorical types from data", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)
  info <- mapping$predictor_info

  # price, quality, service should be continuous
  for (drv in c("price", "quality", "service")) {
    drv_type <- info$type[info$driver == drv]
    expect_equal(drv_type, "continuous",
                 info = paste0(drv, " should be detected as continuous"))
  }

  # region, segment should be categorical
  for (drv in c("region", "segment")) {
    drv_type <- info$type[info$driver == drv]
    expect_equal(drv_type, "categorical",
                 info = paste0(drv, " should be detected as categorical"))
  }
})


# ==============================================================================
# Categorical drivers expand to correct dummy terms
# ==============================================================================

test_that("categorical drivers expand to correct number of dummy terms", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)

  # region has 4 levels -> 3 dummy terms (treatment contrasts)
  region_n_terms <- mapping$predictor_info$n_terms[mapping$predictor_info$driver == "region"]
  expect_equal(region_n_terms, nlevels(mixed_data_factored$region) - 1,
               info = "region should have (n_levels - 1) dummy terms")

  # segment has 3 levels -> 2 dummy terms

  segment_n_terms <- mapping$predictor_info$n_terms[mapping$predictor_info$driver == "segment"]
  expect_equal(segment_n_terms, nlevels(mixed_data_factored$segment) - 1,
               info = "segment should have (n_levels - 1) dummy terms")
})

test_that("continuous drivers have exactly 1 term each", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)

  for (drv in c("price", "quality", "service")) {
    n_terms <- mapping$predictor_info$n_terms[mapping$predictor_info$driver == drv]
    expect_equal(n_terms, 1, info = paste0(drv, " should have exactly 1 model term"))
  }
})

test_that("driver_terms lists map to correct model coefficient names", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)

  # Continuous drivers should have their variable name as the sole term
  expect_equal(mapping$driver_terms[["price"]], "price")
  expect_equal(mapping$driver_terms[["quality"]], "quality")
  expect_equal(mapping$driver_terms[["service"]], "service")

  # Categorical driver terms should start with the driver name
  for (term in mapping$driver_terms[["region"]]) {
    expect_true(startsWith(term, "region"),
                info = paste0("Region term '", term, "' should start with 'region'"))
  }
  for (term in mapping$driver_terms[["segment"]]) {
    expect_true(startsWith(term, "segment"),
                info = paste0("Segment term '", term, "' should start with 'segment'"))
  }
})


# ==============================================================================
# find_matching_terms()
# ==============================================================================

test_that("find_matching_terms finds exact match for continuous drivers", {
  terms <- c("price", "quality", "regionNorth", "regionSouth")
  matches <- find_matching_terms(terms, "price", mixed_data_factored, "continuous")
  expect_equal(matches, "price")
})

test_that("find_matching_terms finds factor level terms for categorical drivers", {
  # Build actual model matrix terms
  mm <- stats::model.matrix(mixed_formula, data = mixed_data_factored)
  terms_to_map <- setdiff(colnames(mm), "(Intercept)")

  matches <- find_matching_terms(terms_to_map, "region", mixed_data_factored, "categorical")

  # Should find all region dummy terms
  expect_true(length(matches) > 0, info = "Should find at least one region term")
  expect_true(length(matches) == nlevels(mixed_data_factored$region) - 1)
  for (m in matches) {
    expect_true(startsWith(m, "region"))
  }
})

test_that("find_matching_terms does not match partial driver name overlaps", {
  # Ensure that a driver named "price" does not match "price_per_unit"
  terms <- c("price", "price_per_unit", "quality")
  matches <- find_matching_terms(terms, "price", mixed_data_factored, "continuous")
  expect_equal(matches, "price",
               info = "Should only match exact 'price', not 'price_per_unit'")
})


# ==============================================================================
# driver_settings parameter enables type-based mapping
# ==============================================================================

test_that("build_term_mapping uses driver_settings when provided", {
  driver_settings <- data.frame(
    driver = mixed_driver_vars,
    driver_type = c("continuous", "continuous", "continuous", "categorical", "categorical"),
    aggregation_method = c("direct", "direct", "direct", "partial_r2", "partial_r2"),
    reference_level = c(NA, NA, NA, NA, NA),
    stringsAsFactors = FALSE
  )

  mapping <- build_term_mapping(
    mixed_formula, mixed_data_factored, mixed_driver_vars,
    driver_settings = driver_settings
  )

  info <- mapping$predictor_info

  # Types should come from driver_settings, not data inference
  expect_equal(info$type[info$driver == "price"], "continuous")
  expect_equal(info$type[info$driver == "region"], "categorical")
  expect_equal(info$type[info$driver == "segment"], "categorical")
})


# ==============================================================================
# validate_term_mapping()
# ==============================================================================

test_that("validate_term_mapping passes with valid mapping", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)
  result <- validate_term_mapping(mapping, mixed_driver_vars)
  expect_true(result)
})

test_that("validate_term_mapping refuses when drivers are missing from mapping", {
  mapping <- build_term_mapping(mixed_formula, mixed_data_factored, mixed_driver_vars)

  # Manually corrupt the mapping: remove one driver's terms
  mapping$term_map[mapping$term_map == "price"] <- ""
  mapping$driver_terms[["price"]] <- character(0)

  err <- tryCatch(
    validate_term_mapping(mapping, mixed_driver_vars),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "MAPPER_TERM_MISMATCH")
})


# ==============================================================================
# enforce_encoding_policy()
# ==============================================================================

test_that("enforce_encoding_policy converts character columns to factors", {
  data_copy <- mixed_data
  expect_true(is.character(data_copy$region))

  result <- enforce_encoding_policy(data_copy, mixed_driver_vars)

  expect_true(is.factor(result$data$region))
  expect_true(is.factor(result$data$segment))
})

test_that("enforce_encoding_policy applies treatment contrasts", {
  data_copy <- mixed_data
  result <- enforce_encoding_policy(data_copy, mixed_driver_vars)

  # Check that contrasts are treatment contrasts
  region_contrasts <- attr(result$data$region, "contrasts")
  expect_equal(region_contrasts, "contr.treatment")
})

test_that("enforce_encoding_policy generates encoding report", {
  data_copy <- mixed_data
  result <- enforce_encoding_policy(data_copy, mixed_driver_vars)

  report <- result$encoding_report
  expect_s3_class(report, "data.frame")
  expect_true(nrow(report) > 0)
  expect_true("driver" %in% names(report))
  expect_true("encoded_as" %in% names(report))
  expect_true("contrasts" %in% names(report))
})

test_that("enforce_encoding_policy leaves numeric columns unchanged", {
  data_copy <- mixed_data
  result <- enforce_encoding_policy(data_copy, mixed_driver_vars)

  expect_true(is.numeric(result$data$price))
  expect_true(is.numeric(result$data$quality))
  expect_true(is.numeric(result$data$service))
  expect_equal(result$data$price, data_copy$price)
})


# ==============================================================================
# has_categorical_predictors() and get_numeric_drivers()
# ==============================================================================

test_that("has_categorical_predictors detects factors", {
  expect_true(has_categorical_predictors(mixed_data, mixed_driver_vars))
})

test_that("has_categorical_predictors returns FALSE for all-numeric data", {
  numeric_data <- generate_basic_kda_data(n = 50, n_drivers = 3)
  expect_false(has_categorical_predictors(numeric_data, paste0("driver_", 1:3)))
})

test_that("get_numeric_drivers returns only numeric columns", {
  numeric_drivers <- get_numeric_drivers(mixed_data, mixed_driver_vars)
  expect_true(all(c("price", "quality", "service") %in% numeric_drivers))
  expect_false("region" %in% numeric_drivers)
  expect_false("segment" %in% numeric_drivers)
})

test_that("get_numeric_drivers handles all-numeric case", {
  numeric_data <- generate_basic_kda_data(n = 50, n_drivers = 3)
  drv_vars <- paste0("driver_", 1:3)
  result <- get_numeric_drivers(numeric_data, drv_vars)
  expect_setequal(result, drv_vars)
})
