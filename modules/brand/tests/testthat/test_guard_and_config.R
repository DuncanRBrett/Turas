# ==============================================================================
# BRAND MODULE TESTS - GUARD LAYER & CONFIG LOADER
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

# Source brand module files
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "01_config.R"))

# Source template styles and generators for creating test fixtures
source(file.path(TURAS_ROOT, "modules", "shared", "template_styles.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "generate_config_templates.R"))


# --- Fixture generator ---
# Creates minimal valid config files directly (not from template) for testing
.create_test_config_files <- function(tmp_dir = tempdir()) {
  config_path <- file.path(tmp_dir, "Brand_Config.xlsx")
  structure_path <- file.path(tmp_dir, "Survey_Structure.xlsx")

  # --- Create Brand_Config.xlsx with required settings ---
  wb_cfg <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb_cfg, "Settings")

  settings <- data.frame(
    Setting = c("project_name", "client_name", "study_type", "wave",
                "data_file", "respondent_id_col", "weight_variable",
                "focal_brand", "focal_assignment",
                "element_funnel", "element_mental_avail", "element_cep_turf",
                "element_repertoire", "element_drivers_barriers",
                "element_dba", "element_portfolio", "element_wom",
                "alpha", "min_base_size", "low_base_warning",
                "colour_focal", "colour_focal_accent",
                "colour_competitor", "colour_category_avg",
                "output_dir", "output_html", "output_excel", "output_csv",
                "tracker_ids", "report_title", "structure_file",
                "show_about_section",
                "dba_fame_threshold", "dba_uniqueness_threshold"),
    Value = c("Test Project", "Test Client", "cross-sectional", "1",
              "data/test.csv", "Respondent_ID", "",
              "IPK", "balanced",
              "Y", "Y", "Y", "Y", "Y", "N", "Y", "Y",
              "0.05", "30", "75",
              "#1A5276", "#2E86C1", "#B0B0B0", "#808080",
              "output/test", "Y", "Y", "Y", "Y",
              "Brand Health Report", "Survey_Structure.xlsx",
              "Y", "0.5", "0.5"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_cfg, "Settings", settings)

  # Categories sheet
  openxlsx::addWorksheet(wb_cfg, "Categories")
  categories <- data.frame(
    Category = c("Dry Seasonings & Spices", "Ready Meals", "Sauces"),
    Type = c("transactional", "transactional", "transactional"),
    Timeframe_Long = c("12 months", "12 months", "12 months"),
    Timeframe_Target = c("3 months", "3 months", "3 months"),
    Focal_Weight = c(0.34, 0.33, 0.33),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_cfg, "Categories", categories)

  # DBA_Assets sheet
  openxlsx::addWorksheet(wb_cfg, "DBA_Assets")
  dba <- data.frame(
    AssetCode = c("LOGO"), AssetLabel = c("Logo"),
    AssetType = c("image"), FilePath = c("assets/logo.png"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_cfg, "DBA_Assets", dba)

  openxlsx::saveWorkbook(wb_cfg, config_path, overwrite = TRUE)

  # --- Create Survey_Structure.xlsx ---
  wb_ss <- openxlsx::createWorkbook()

  # Project sheet
  openxlsx::addWorksheet(wb_ss, "Project")
  project <- data.frame(
    Setting = c("project_name", "data_file", "client_name", "focal_brand"),
    Value = c("Test Project", "data/test.csv", "Test Client", "IPK"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_ss, "Project", project)

  # Questions sheet
  openxlsx::addWorksheet(wb_ss, "Questions")
  questions <- data.frame(
    QuestionCode = c("BRANDAWARE_DSS", "BRANDATTR_DSS_01", "BRANDATT1_DSS",
                     "WOM_POS_REC"),
    QuestionText = c("Brands heard of", "Adds great flavour to food",
                     "Brand attitude", "Received positive WOM"),
    VariableType = c("Multi_Mention", "Multi_Mention",
                     "Single_Mention", "Multi_Mention"),
    Battery = c("awareness", "cep_matrix", "attitude", "wom"),
    Category = c("Dry Seasonings & Spices", "Dry Seasonings & Spices",
                 "Dry Seasonings & Spices", "ALL"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_ss, "Questions", questions)

  # Options sheet
  openxlsx::addWorksheet(wb_ss, "Options")
  options <- data.frame(
    QuestionCode = rep("BRANDATT1_DSS", 5),
    OptionText = as.character(1:5),
    DisplayText = c("I love it", "I prefer it", "Would buy if no choice",
                    "Would refuse", "No opinion"),
    DisplayOrder = 1:5,
    ShowInOutput = rep("Y", 5),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_ss, "Options", options)

  # Brands sheet
  openxlsx::addWorksheet(wb_ss, "Brands")
  brands <- data.frame(
    Category = c("Dry Seasonings & Spices", "Dry Seasonings & Spices", "Ready Meals"),
    BrandCode = c("IPK", "ROB", "IPK"),
    BrandLabel = c("IPK", "Robertsons", "IPK"),
    DisplayOrder = c(1, 2, 1),
    IsFocal = c("Y", "N", "Y"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_ss, "Brands", brands)

  # CEPs sheet
  openxlsx::addWorksheet(wb_ss, "CEPs")
  ceps <- data.frame(
    Category = rep("Dry Seasonings & Spices", 3),
    CEPCode = c("CEP01", "CEP02", "CEP03"),
    CEPText = c("Adds great flavour to food", "Family enjoys", "Healthy option"),
    DisplayOrder = 1:3,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_ss, "CEPs", ceps)

  # Attributes sheet
  openxlsx::addWorksheet(wb_ss, "Attributes")
  attrs <- data.frame(
    Category = rep("Dry Seasonings & Spices", 2),
    AttrCode = c("ATTR01", "ATTR02"),
    AttrText = c("Good value", "High quality"),
    DisplayOrder = 1:2,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_ss, "Attributes", attrs)

  # DBA_Assets sheet
  openxlsx::addWorksheet(wb_ss, "DBA_Assets")
  dba_ss <- data.frame(
    AssetCode = "LOGO", AssetLabel = "Logo", AssetType = "image",
    FameQuestionCode = "DBA_FAME_LOGO",
    UniqueQuestionCode = "DBA_UNIQUE_LOGO",
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb_ss, "DBA_Assets", dba_ss)

  openxlsx::saveWorkbook(wb_ss, structure_path, overwrite = TRUE)

  list(config_path = config_path, structure_path = structure_path)
}


# ==============================================================================
# GUARD LAYER TESTS
# ==============================================================================

test_that("guard_validate_brand_config passes with valid config", {
  config <- list(
    project_name = "Test",
    client_name = "Client",
    focal_brand = "IPK",
    data_file = "data/test.csv",
    output_dir = "output/test",
    structure_file = "structure.xlsx",
    study_type = "cross-sectional",
    focal_assignment = "balanced"
  )

  result <- guard_validate_brand_config(config)
  expect_equal(result$status, "PASS")
})

test_that("guard_validate_brand_config refuses NULL config", {
  expect_error(guard_validate_brand_config(NULL))
})

test_that("guard_validate_brand_config refuses missing required fields", {
  config <- list(
    project_name = "Test",
    client_name = "Client"
    # Missing: focal_brand, data_file, output_dir, structure_file
  )

  expect_error(guard_validate_brand_config(config))
})

test_that("guard_validate_brand_config refuses invalid study_type", {
  config <- list(
    project_name = "Test", client_name = "Client", focal_brand = "IPK",
    data_file = "data.csv", output_dir = "out", structure_file = "ss.xlsx",
    study_type = "longitudinal"
  )

  expect_error(guard_validate_brand_config(config))
})

test_that("guard_validate_brand_config refuses invalid focal_assignment", {
  config <- list(
    project_name = "Test", client_name = "Client", focal_brand = "IPK",
    data_file = "data.csv", output_dir = "out", structure_file = "ss.xlsx",
    focal_assignment = "random"
  )

  expect_error(guard_validate_brand_config(config))
})

test_that("guard_validate_categories passes with valid categories", {
  cats <- data.frame(
    Category = c("Dry Seasonings & Spices", "Ready Meals"),
    Type = c("transactional", "transactional"),
    Timeframe_Target = c("3 months", "3 months"),
    stringsAsFactors = FALSE
  )
  config <- list(focal_assignment = "balanced", element_portfolio = "Y")

  result <- guard_validate_categories(cats, config)
  expect_equal(result$status, "PASS")
})

test_that("guard_validate_categories refuses empty categories", {
  config <- list(focal_assignment = "balanced")
  expect_error(guard_validate_categories(data.frame(), config))
})

test_that("guard_validate_categories refuses invalid category type", {
  cats <- data.frame(
    Category = "Test",
    Type = "invalid_type",
    Timeframe_Target = "3 months",
    stringsAsFactors = FALSE
  )
  config <- list(focal_assignment = "balanced", element_portfolio = "N")
  expect_error(guard_validate_categories(cats, config))
})

test_that("guard_validate_categories refuses portfolio with single category", {
  cats <- data.frame(
    Category = "Only One",
    Type = "transactional",
    Timeframe_Target = "3 months",
    stringsAsFactors = FALSE
  )
  config <- list(focal_assignment = "balanced", element_portfolio = "Y")
  expect_error(guard_validate_categories(cats, config))
})

test_that("guard_validate_categories validates priority weights sum", {
  cats <- data.frame(
    Category = c("A", "B"),
    Type = c("transactional", "transactional"),
    Timeframe_Target = c("3m", "3m"),
    Focal_Weight = c(0.3, 0.3),  # sums to 0.6, not 1.0
    stringsAsFactors = FALSE
  )
  config <- list(focal_assignment = "priority", element_portfolio = "Y")
  expect_error(guard_validate_categories(cats, config))
})

test_that("guard_validate_categories passes valid priority weights", {
  cats <- data.frame(
    Category = c("A", "B"),
    Type = c("transactional", "transactional"),
    Timeframe_Target = c("3m", "3m"),
    Focal_Weight = c(0.6, 0.4),
    stringsAsFactors = FALSE
  )
  config <- list(focal_assignment = "priority", element_portfolio = "Y")
  result <- guard_validate_categories(cats, config)
  expect_equal(result$status, "PASS")
})

test_that("guard_validate_structure refuses missing focal brand", {
  structure <- list(
    brands = data.frame(
      Category = "Test", BrandCode = "OTHER",
      BrandLabel = "Other", stringsAsFactors = FALSE
    )
  )
  config <- list(focal_brand = "IPK", element_mental_avail = "N")
  expect_error(guard_validate_structure(structure, config))
})

test_that("guard_validate_structure refuses missing CEPs when MA enabled", {
  structure <- list(
    brands = data.frame(
      Category = "Test", BrandCode = "IPK",
      BrandLabel = "IPK", stringsAsFactors = FALSE
    ),
    ceps = data.frame()  # empty
  )
  config <- list(focal_brand = "IPK", element_mental_avail = "Y")
  expect_error(guard_validate_structure(structure, config))
})

test_that("guard_validate_data refuses empty data", {
  config <- list(study_type = "cross-sectional")
  expect_error(guard_validate_data(NULL, list(), config))
  expect_error(guard_validate_data(data.frame(), list(), config))
})

test_that("guard_validate_data warns on missing weight column", {
  data <- data.frame(x = 1:10)
  config <- list(study_type = "cross-sectional",
                 weight_variable = "nonexistent_weight")
  structure <- list()

  result <- guard_validate_data(data, structure, config)
  expect_equal(result$status, "PARTIAL")
  expect_true(length(result$warnings) > 0)
  expect_true(any(grepl("weight", result$warnings, ignore.case = TRUE)))
})


# ==============================================================================
# CONFIG LOADER TESTS
# ==============================================================================

test_that("load_brand_config refuses non-existent file", {
  expect_error(load_brand_config("/nonexistent/path/Brand_Config.xlsx"))
})

test_that("load_brand_config loads valid config file", {
  tmp_dir <- file.path(tempdir(), "brand_config_test")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  files <- .create_test_config_files(tmp_dir)
  config <- load_brand_config(files$config_path)

  expect_true(is.list(config))
  expect_equal(config$project_name, "Test Project")
  expect_equal(config$client_name, "Test Client")
  expect_equal(config$focal_brand, "IPK")
})

test_that("load_brand_config parses element toggles to logical", {
  tmp_dir <- file.path(tempdir(), "brand_config_toggle_test")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  files <- .create_test_config_files(tmp_dir)
  config <- load_brand_config(files$config_path)

  # Element toggles should be logical
  expect_true(is.logical(config$element_funnel))
  expect_true(is.logical(config$element_mental_avail))
  expect_true(is.logical(config$element_dba))
  expect_true(is.logical(config$element_portfolio))

  # Defaults: all Y except DBA
  expect_true(config$element_funnel)
  expect_true(config$element_mental_avail)
  expect_false(config$element_dba)
})

test_that("load_brand_config loads categories", {
  tmp_dir <- file.path(tempdir(), "brand_config_cats_test")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  files <- .create_test_config_files(tmp_dir)
  config <- load_brand_config(files$config_path)

  expect_true(is.data.frame(config$categories))
  expect_true(nrow(config$categories) >= 3)  # 3 example rows
  expect_true("Category" %in% names(config$categories))
})

test_that("load_brand_config sets sensible defaults", {
  tmp_dir <- file.path(tempdir(), "brand_config_defaults_test")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  files <- .create_test_config_files(tmp_dir)
  config <- load_brand_config(files$config_path)

  expect_equal(config$alpha, 0.05)
  expect_equal(config$min_base_size, 30)
  expect_equal(config$low_base_warning, 75)
  expect_equal(config$dba_fame_threshold, 0.50)
  expect_equal(config$colour_focal, "#1A5276")
})


# ==============================================================================
# SURVEY STRUCTURE LOADER TESTS
# ==============================================================================

test_that("load_brand_survey_structure refuses non-existent file", {
  expect_error(load_brand_survey_structure("/nonexistent/Survey_Structure.xlsx"))
})

test_that("load_brand_survey_structure loads valid structure file", {
  tmp_dir <- file.path(tempdir(), "brand_structure_test")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  files <- .create_test_config_files(tmp_dir)
  structure <- load_brand_survey_structure(files$structure_path)

  expect_true(is.list(structure))
  expect_true(is.data.frame(structure$brands))
  expect_true(is.data.frame(structure$ceps))
  expect_true(is.data.frame(structure$attributes))
  expect_true(is.data.frame(structure$questions))
  expect_true(is.data.frame(structure$options))
})

test_that("get_brands_for_category filters correctly", {
  structure <- list(
    brands = data.frame(
      Category = c("A", "A", "B"),
      BrandCode = c("X", "Y", "Z"),
      BrandLabel = c("X", "Y", "Z"),
      DisplayOrder = c(1, 2, 1),
      IsFocal = c("Y", "N", "Y"),
      stringsAsFactors = FALSE
    )
  )

  brands_a <- get_brands_for_category(structure, "A")
  expect_equal(nrow(brands_a), 2)
  expect_equal(brands_a$BrandCode, c("X", "Y"))

  brands_b <- get_brands_for_category(structure, "B")
  expect_equal(nrow(brands_b), 1)
  expect_equal(brands_b$BrandCode, "Z")

  brands_c <- get_brands_for_category(structure, "C")
  expect_equal(nrow(brands_c), 0)
})

test_that("get_ceps_for_category filters and sorts correctly", {
  structure <- list(
    ceps = data.frame(
      Category = c("A", "A", "B"),
      CEPCode = c("C2", "C1", "C3"),
      CEPText = c("Two", "One", "Three"),
      DisplayOrder = c(2, 1, 1),
      stringsAsFactors = FALSE
    )
  )

  ceps_a <- get_ceps_for_category(structure, "A")
  expect_equal(nrow(ceps_a), 2)
  expect_equal(ceps_a$CEPCode[1], "C1")  # sorted by DisplayOrder
})

test_that("get_questions_for_battery filters by battery and category", {
  structure <- list(
    questions = data.frame(
      QuestionCode = c("Q1", "Q2", "Q3"),
      Battery = c("awareness", "cep_matrix", "awareness"),
      Category = c("A", "A", "ALL"),
      stringsAsFactors = FALSE
    )
  )

  awareness_a <- get_questions_for_battery(structure, "awareness", "A")
  expect_equal(nrow(awareness_a), 2)  # Q1 (cat A) + Q3 (ALL)

  cep_a <- get_questions_for_battery(structure, "cep_matrix", "A")
  expect_equal(nrow(cep_a), 1)
})

test_that(".parse_yn handles all valid inputs", {
  expect_true(.parse_yn("Y"))
  expect_true(.parse_yn("y"))
  expect_true(.parse_yn("YES"))
  expect_true(.parse_yn("yes"))
  expect_true(.parse_yn("TRUE"))
  expect_true(.parse_yn("1"))
  expect_true(.parse_yn(TRUE))

  expect_false(.parse_yn("N"))
  expect_false(.parse_yn("n"))
  expect_false(.parse_yn("NO"))
  expect_false(.parse_yn("FALSE"))
  expect_false(.parse_yn("0"))
  expect_false(.parse_yn(FALSE))

  expect_false(.parse_yn(NULL, default = FALSE))
  expect_true(.parse_yn(NULL, default = TRUE))
  expect_false(.parse_yn(NA, default = FALSE))
})


# ==============================================================================
# PATH RESOLUTION TESTS (OneDrive portability)
# ==============================================================================

test_that("load_brand_config resolves relative paths against config dir", {
  tmp_dir <- file.path(tempdir(), "brand_path_test")
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  files <- .create_test_config_files(tmp_dir)
  config <- load_brand_config(files$config_path)

  # project_root should be the config file's directory
  expect_equal(normalizePath(config$project_root, mustWork = FALSE),
               normalizePath(tmp_dir, mustWork = FALSE))

  # Resolved paths should be absolute (regardless of what's in config)
  expect_true(!is.null(config$structure_file_resolved))
  expect_true(grepl("^/", config$structure_file_resolved) ||
              grepl("^[A-Z]:", config$structure_file_resolved))

  # Resolved structure file should point to the right place
  expect_true(file.exists(config$structure_file_resolved))
})

test_that("relative data_file path resolves correctly", {
  tmp_dir <- file.path(tempdir(), "brand_rel_data_test")
  sub_dir <- file.path(tmp_dir, "data")
  dir.create(sub_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  # Create data in a subdirectory
  data_path <- file.path(sub_dir, "survey.csv")
  write.csv(data.frame(x = 1:5), data_path, row.names = FALSE)

  # Create config with relative data_file path
  config_path <- file.path(tmp_dir, "cfg.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("project_name", "client_name", "data_file", "focal_brand",
                "output_dir", "structure_file"),
    Value = c("Test", "Client", "data/survey.csv", "IPK",
              "output", "Survey_Structure.xlsx"),
    stringsAsFactors = FALSE
  ))
  openxlsx::addWorksheet(wb, "Categories")
  openxlsx::writeData(wb, "Categories", data.frame(
    Category = "FV", Type = "transactional", Timeframe_Target = "3m",
    stringsAsFactors = FALSE
  ))
  openxlsx::addWorksheet(wb, "DBA_Assets")
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  config <- load_brand_config(config_path)

  # data_file should be the original relative value
  expect_equal(config$data_file, "data/survey.csv")

  # data_file_resolved should be absolute and point to the correct file
  expect_true(file.exists(config$data_file_resolved))
  expect_equal(normalizePath(config$data_file_resolved),
               normalizePath(data_path))
})
