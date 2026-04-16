# ==============================================================================
# BRAND MODULE TESTS - CONFIG TEMPLATE GENERATORS
# ==============================================================================

# --- Find project root ---
.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
    dir <- dirname(dir)
  }
  getwd()
}

TURAS_ROOT <- .find_turas_root_for_test()

# Source shared infrastructure
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(f, local = FALSE), error = function(e) NULL)
  }
}

# Source template styles
source(file.path(TURAS_ROOT, "modules", "shared", "template_styles.R"))

# Source config template generators
source(file.path(TURAS_ROOT, "modules", "brand", "R", "generate_config_templates.R"))


# ==============================================================================
# BRAND_CONFIG.XLSX TESTS
# ==============================================================================

test_that("generate_brand_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_brand_config_template(tmp, overwrite = TRUE)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
})

test_that("Brand_Config.xlsx has correct sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_config_template(tmp, overwrite = TRUE)

  sheets <- openxlsx::getSheetNames(tmp)
  expect_true("Settings" %in% sheets)
  expect_true("Categories" %in% sheets)
  expect_true("DBA_Assets" %in% sheets)
})

test_that("Brand_Config Settings sheet has all required settings", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_config_template(tmp, overwrite = TRUE)

  settings <- openxlsx::read.xlsx(tmp, sheet = "Settings", colNames = FALSE)

  # Check key settings exist somewhere in the file
  all_settings <- settings[, 1]
  required_settings <- c(
    "project_name", "client_name", "study_type", "wave", "data_file",
    "focal_brand", "focal_assignment", "element_funnel", "element_mental_avail",
    "element_cep_turf", "element_repertoire", "element_drivers_barriers",
    "element_dba", "element_portfolio", "element_wom", "output_dir",
    "structure_file"
  )

  for (setting in required_settings) {
    expect_true(setting %in% all_settings,
                info = sprintf("Missing setting: %s", setting))
  }
})

test_that("Brand_Config Categories sheet has example rows", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_config_template(tmp, overwrite = TRUE)

  categories <- openxlsx::read.xlsx(tmp, sheet = "Categories", startRow = 3)

  # Should have example rows
  expect_true(nrow(categories) >= 3)
  expect_true("Frozen Vegetables" %in% categories[, 1])
})

test_that("Brand_Config refuses when file exists and overwrite = FALSE", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  # Create file first
  generate_brand_config_template(tmp, overwrite = TRUE)

  # Try again without overwrite
  result <- generate_brand_config_template(tmp, overwrite = FALSE)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_FILE_EXISTS")
})

test_that("Brand_Config creates output directory if needed", {
  tmp_dir <- file.path(tempdir(), "brand_test_subdir_config")
  tmp <- file.path(tmp_dir, "Brand_Config.xlsx")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  result <- generate_brand_config_template(tmp, overwrite = TRUE)
  expect_equal(result$status, "PASS")
  expect_true(dir.exists(tmp_dir))
  expect_true(file.exists(tmp))
})

test_that("Brand_Config element toggle defaults are correct", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_config_template(tmp, overwrite = TRUE)

  settings <- openxlsx::read.xlsx(tmp, sheet = "Settings", colNames = FALSE)

  # Find element rows and check defaults
  get_default <- function(setting_name) {
    idx <- which(settings[, 1] == setting_name)
    if (length(idx) == 0) return(NA)
    settings[idx, 2]
  }

  # Group A elements default Y
  expect_equal(get_default("element_funnel"), "Y")
  expect_equal(get_default("element_mental_avail"), "Y")
  expect_equal(get_default("element_repertoire"), "Y")
  expect_equal(get_default("element_drivers_barriers"), "Y")
  expect_equal(get_default("element_portfolio"), "Y")
  expect_equal(get_default("element_wom"), "Y")

  # DBA defaults N (survey time cost)
  expect_equal(get_default("element_dba"), "N")
})


# ==============================================================================
# SURVEY_STRUCTURE.XLSX TESTS
# ==============================================================================

test_that("generate_brand_survey_structure_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_brand_survey_structure_template(tmp, overwrite = TRUE)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
})

test_that("Survey_Structure.xlsx has all required sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_survey_structure_template(tmp, overwrite = TRUE)

  sheets <- openxlsx::getSheetNames(tmp)
  expected_sheets <- c("Project", "Questions", "Options", "Brands",
                       "CEPs", "Attributes", "DBA_Assets")

  for (sheet in expected_sheets) {
    expect_true(sheet %in% sheets,
                info = sprintf("Missing sheet: %s", sheet))
  }
})

test_that("Survey_Structure Questions sheet has correct columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_survey_structure_template(tmp, overwrite = TRUE)

  questions <- openxlsx::read.xlsx(tmp, sheet = "Questions", startRow = 3)

  expected_cols <- c("QuestionCode", "QuestionText", "VariableType",
                     "Battery", "Category")
  actual_cols <- names(questions)

  for (col in expected_cols) {
    expect_true(col %in% actual_cols,
                info = sprintf("Missing column: %s", col))
  }
})

test_that("Survey_Structure Brands sheet has example rows with IsFocal", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_survey_structure_template(tmp, overwrite = TRUE)

  brands <- openxlsx::read.xlsx(tmp, sheet = "Brands", startRow = 3)

  expect_true(nrow(brands) >= 5)
  # At least one focal brand
  # Skip the help text row (row 4 in Excel = row 2 in data after header)
  data_rows <- brands[!grepl("^\\[", brands[, 1], perl = TRUE), ]
  expect_true("Y" %in% data_rows$IsFocal)
})

test_that("Survey_Structure CEPs sheet has example rows", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_survey_structure_template(tmp, overwrite = TRUE)

  ceps <- openxlsx::read.xlsx(tmp, sheet = "CEPs", startRow = 3)

  expect_true(nrow(ceps) >= 3)
})

test_that("Survey_Structure Options sheet has attitude scale examples", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_survey_structure_template(tmp, overwrite = TRUE)

  options <- openxlsx::read.xlsx(tmp, sheet = "Options", startRow = 3)

  # Should have the 5-level attitude scale examples
  expect_true(nrow(options) >= 5)
})

test_that("Survey_Structure refuses when file exists", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_survey_structure_template(tmp, overwrite = TRUE)

  result <- generate_brand_survey_structure_template(tmp, overwrite = FALSE)
  expect_equal(result$status, "REFUSED")
})

test_that("Survey_Structure creates output directory if needed", {
  tmp_dir <- file.path(tempdir(), "brand_test_subdir_structure")
  tmp <- file.path(tmp_dir, "Survey_Structure.xlsx")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  result <- generate_brand_survey_structure_template(tmp, overwrite = TRUE)
  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))
})


# ==============================================================================
# CROSS-FILE CONSISTENCY TESTS
# ==============================================================================

test_that("Both templates can be generated to same directory", {
  tmp_dir <- file.path(tempdir(), "brand_test_both")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  config_path <- file.path(tmp_dir, "Brand_Config.xlsx")
  structure_path <- file.path(tmp_dir, "Survey_Structure.xlsx")

  r1 <- generate_brand_config_template(config_path, overwrite = TRUE)
  r2 <- generate_brand_survey_structure_template(structure_path, overwrite = TRUE)

  expect_equal(r1$status, "PASS")
  expect_equal(r2$status, "PASS")
  expect_true(file.exists(config_path))
  expect_true(file.exists(structure_path))
})

test_that("Battery codes in Questions examples match documented CBM batteries", {
  valid_batteries <- c("awareness", "cep_matrix", "attribute", "attitude",
                       "attitude_oe", "cat_buying", "penetration", "wom", "dba")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_brand_survey_structure_template(tmp, overwrite = TRUE)

  questions <- openxlsx::read.xlsx(tmp, sheet = "Questions", startRow = 3)
  # Filter to actual data rows (skip help text row)
  data_rows <- questions[!grepl("^\\[", questions[, 1], perl = TRUE), ]
  batteries_used <- unique(data_rows$Battery)
  batteries_used <- batteries_used[!is.na(batteries_used)]

  for (b in batteries_used) {
    expect_true(b %in% valid_batteries,
                info = sprintf("Invalid battery code: %s", b))
  }
})
