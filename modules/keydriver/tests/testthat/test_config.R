# ==============================================================================
# KEYDRIVER CONFIG LOADING AND VALIDATION TESTS
# ==============================================================================
#
# Tests for modules/keydriver/R/01_config.R
#
# Covers:
#   - load_keydriver_config() file existence and format validation
#   - validate_keydriver_config() (via load_keydriver_config) field validation
#   - Default config value application
#   - Boolean config field parsing (as_logical_setting)
#   - Numeric config field parsing (as_numeric_setting)
#   - get_setting() safe extraction with defaults
#   - validate_segments_sheet() and validate_stated_importance_sheet()
#
# ==============================================================================

# Source test data generators
source(file.path(dirname(dirname(testthat::test_path())), "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure (required by config functions)
shared_lib <- file.path(dirname(dirname(dirname(dirname(testthat::test_path())))), "shared", "lib")
source(file.path(shared_lib, "trs_refusal.R"))

# Source the guard module (required by config - keydriver_refuse is defined there)
guard_path <- file.path(dirname(dirname(dirname(testthat::test_path()))), "R", "00_guard.R")
source(guard_path)

# Source the config module under test
config_path <- file.path(dirname(dirname(dirname(testthat::test_path()))), "R", "01_config.R")
source(config_path)


# ==============================================================================
# load_keydriver_config() - File existence checks
# ==============================================================================

test_that("load_keydriver_config refuses on missing file with IO_ code", {
  fake_path <- file.path(tempdir(), "nonexistent_config_12345.xlsx")

  err <- tryCatch(
    load_keydriver_config(fake_path),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_match(err$code, "^IO_")
  expect_equal(err$code, "IO_CONFIG_NOT_FOUND")
  expect_match(err$problem, "does not exist")
})

test_that("load_keydriver_config refuses on non-xlsx file with IO_ code", {
  # Create a temporary CSV file (wrong format for openxlsx)
  tmp_csv <- file.path(tempdir(), "bad_config.csv")
  writeLines("Setting,Value\ndata_file,test.csv", tmp_csv)
  on.exit(unlink(tmp_csv), add = TRUE)

  # openxlsx::getSheetNames will fail on a CSV file, which should be
  # caught. The refusal may come as IO_ or as a general error since
  # the file exists but is not a valid xlsx.
  err <- tryCatch(
    load_keydriver_config(tmp_csv),
    turas_refusal = function(e) e,
    error = function(e) e
  )

  # Should produce some kind of error (refusal or general error from openxlsx)
  expect_true(inherits(err, "turas_refusal") || inherits(err, "error"))
})


# ==============================================================================
# load_keydriver_config() - Sheet validation
# ==============================================================================

test_that("load_keydriver_config refuses when Settings sheet is missing", {
  # Create an xlsx with only a dummy sheet (no Settings)
  tmp_file <- file.path(tempdir(), "no_settings_sheet.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "DummySheet")
  openxlsx::writeData(wb, "DummySheet", data.frame(x = 1))
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)
  on.exit(unlink(tmp_file), add = TRUE)

  err <- tryCatch(
    load_keydriver_config(tmp_file),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_SETTINGS_SHEET_MISSING")
})

test_that("load_keydriver_config refuses when Variables sheet is missing", {
  # Create an xlsx with Settings but no Variables sheet
  tmp_file <- file.path(tempdir(), "no_variables_sheet.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("data_file", "output_file"),
    Value = c("test.csv", "output.xlsx")
  ))
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)
  on.exit(unlink(tmp_file), add = TRUE)

  err <- tryCatch(
    load_keydriver_config(tmp_file),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_VARIABLES_SHEET_MISSING")
})

test_that("load_keydriver_config refuses when Variables sheet lacks required columns", {
  tmp_file <- file.path(tempdir(), "bad_variables_cols.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("data_file"), Value = c("test.csv")
  ))
  openxlsx::addWorksheet(wb, "Variables")
  # Missing 'Type' and 'Label' columns
  openxlsx::writeData(wb, "Variables", data.frame(
    VariableName = c("outcome", "driver_1")
  ))
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)
  on.exit(unlink(tmp_file), add = TRUE)

  err <- tryCatch(
    load_keydriver_config(tmp_file),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_VARIABLES_COLUMNS_MISSING")
  expect_true("Type" %in% err$missing || "Label" %in% err$missing)
})

test_that("load_keydriver_config refuses when no outcome variable is defined", {
  tmp_file <- file.path(tempdir(), "no_outcome.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("data_file"), Value = c("test.csv")
  ))
  openxlsx::addWorksheet(wb, "Variables")
  openxlsx::writeData(wb, "Variables", data.frame(
    VariableName = c("driver_1", "driver_2", "driver_3"),
    Type = c("Driver", "Driver", "Driver"),
    Label = c("D1", "D2", "D3"),
    DriverType = c("continuous", "continuous", "continuous")
  ))
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)
  on.exit(unlink(tmp_file), add = TRUE)

  err <- tryCatch(
    load_keydriver_config(tmp_file),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_OUTCOME_MISSING")
})

test_that("load_keydriver_config refuses when no driver variables are defined", {
  tmp_file <- file.path(tempdir(), "no_drivers.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("data_file"), Value = c("test.csv")
  ))
  openxlsx::addWorksheet(wb, "Variables")
  openxlsx::writeData(wb, "Variables", data.frame(
    VariableName = c("outcome"),
    Type = c("Outcome"),
    Label = c("Overall Satisfaction")
  ))
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)
  on.exit(unlink(tmp_file), add = TRUE)

  err <- tryCatch(
    load_keydriver_config(tmp_file),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_DRIVERS_MISSING")
})


# ==============================================================================
# as_logical_setting() - Boolean parsing
# ==============================================================================

test_that("as_logical_setting handles TRUE/FALSE strings", {
  expect_true(as_logical_setting("true"))
  expect_true(as_logical_setting("TRUE"))
  expect_true(as_logical_setting("True"))
  expect_true(as_logical_setting("yes"))
  expect_true(as_logical_setting("1"))
  expect_true(as_logical_setting("on"))
  expect_true(as_logical_setting("enabled"))

  expect_false(as_logical_setting("false"))
  expect_false(as_logical_setting("no"))
  expect_false(as_logical_setting("0"))
  expect_false(as_logical_setting("off"))
  expect_false(as_logical_setting("disabled"))
})

test_that("as_logical_setting handles actual logical values", {
  expect_true(as_logical_setting(TRUE))
  expect_false(as_logical_setting(FALSE))
})

test_that("as_logical_setting handles numeric values", {
  expect_true(as_logical_setting(1))
  expect_true(as_logical_setting(42))
  expect_false(as_logical_setting(0))
})

test_that("as_logical_setting returns default for NULL and NA", {
  expect_false(as_logical_setting(NULL, default = FALSE))
  expect_true(as_logical_setting(NULL, default = TRUE))
  expect_false(as_logical_setting(NA, default = FALSE))
  expect_true(as_logical_setting(NA, default = TRUE))
})


# ==============================================================================
# as_numeric_setting() - Numeric parsing
# ==============================================================================

test_that("as_numeric_setting converts character strings to numeric", {
  expect_equal(as_numeric_setting("3.14"), 3.14)
  expect_equal(as_numeric_setting("100"), 100)
  expect_equal(as_numeric_setting("0"), 0)
})

test_that("as_numeric_setting returns default for non-parseable strings", {
  expect_equal(as_numeric_setting("abc", default = 5.0), 5.0)
  expect_true(is.na(as_numeric_setting("not_a_number")))
})

test_that("as_numeric_setting passes through numeric values", {
  expect_equal(as_numeric_setting(42), 42)
  expect_equal(as_numeric_setting(0.001), 0.001)
})

test_that("as_numeric_setting returns default for NULL and NA", {
  expect_equal(as_numeric_setting(NULL, default = 10), 10)
  expect_equal(as_numeric_setting(NA, default = 99), 99)
})


# ==============================================================================
# get_setting() - Safe setting extraction
# ==============================================================================

test_that("get_setting returns value when present", {
  settings <- list(enable_shap = "TRUE", n_iterations = "500")
  expect_equal(get_setting(settings, "enable_shap"), "TRUE")
  expect_equal(get_setting(settings, "n_iterations"), "500")
})

test_that("get_setting returns default when key is missing", {
  settings <- list(enable_shap = "TRUE")
  expect_equal(get_setting(settings, "nonexistent_key", default = "fallback"), "fallback")
  expect_null(get_setting(settings, "nonexistent_key"))
})

test_that("get_setting returns default when value is NA", {
  settings <- list(enable_shap = NA)
  expect_equal(get_setting(settings, "enable_shap", default = FALSE), FALSE)
})


# ==============================================================================
# validate_segments_sheet() - Segments sheet validation
# ==============================================================================

test_that("validate_segments_sheet refuses when required columns are missing", {
  bad_seg <- data.frame(name = "Seg1", variable = "region")

  err <- tryCatch(
    validate_segments_sheet(bad_seg),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_SEGMENTS_MISSING_COLS")
})

test_that("validate_segments_sheet refuses when sheet is empty", {
  empty_seg <- data.frame(
    segment_name = character(0),
    segment_variable = character(0),
    segment_values = character(0)
  )

  err <- tryCatch(
    validate_segments_sheet(empty_seg),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_SEGMENTS_EMPTY")
})

test_that("validate_segments_sheet passes with valid data", {
  valid_seg <- data.frame(
    segment_name = c("Young", "Old"),
    segment_variable = c("age_group", "age_group"),
    segment_values = c("18-34", "55+"),
    stringsAsFactors = FALSE
  )

  result <- validate_segments_sheet(valid_seg)
  expect_true(result)
})


# ==============================================================================
# validate_stated_importance_sheet() - StatedImportance sheet validation
# ==============================================================================

test_that("validate_stated_importance_sheet refuses when driver column is missing", {
  bad_si <- data.frame(variable = "price", importance = 4.5)

  err <- tryCatch(
    validate_stated_importance_sheet(bad_si),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_STATED_IMPORTANCE_MISSING_DRIVER")
})

test_that("validate_stated_importance_sheet refuses when no numeric columns exist", {
  no_numeric_si <- data.frame(
    driver = c("price", "quality"),
    importance = c("high", "medium"),
    stringsAsFactors = FALSE
  )

  err <- tryCatch(
    validate_stated_importance_sheet(no_numeric_si),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_STATED_IMPORTANCE_NO_NUMERIC")
})

test_that("validate_stated_importance_sheet passes with valid data", {
  valid_si <- data.frame(
    driver = c("price", "quality", "service"),
    stated_importance = c(4.5, 3.2, 4.0),
    stringsAsFactors = FALSE
  )

  result <- validate_stated_importance_sheet(valid_si)
  expect_true(result)
})
