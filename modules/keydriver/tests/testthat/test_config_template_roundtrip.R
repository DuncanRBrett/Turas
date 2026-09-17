# ==============================================================================
# KEYDRIVER - the config template this module generates must load in this module
# ==============================================================================
# write_table_sheet() puts a title in row 1, a subtitle in row 2, the real
# column headers in row 3 and per-column help text in row 4. The config loader
# read with openxlsx::read.xlsx() and no startRow, so it took the title as the
# header row and refused the module's own generated template.
#
# Nothing caught it because every test fixture and example script builds configs
# with headers in row 1, and the template tests read at startRow = 3 and never
# went through the loader. This test is the round trip.
# ==============================================================================

library(testthat)

turas_root <- local({
  p <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(p, "modules", "shared", "lib"))) return(normalizePath(p))
    p <- dirname(p)
  }
  NULL
})

skip_if(is.null(turas_root), "Turas root not found")
skip_if_not_installed("openxlsx")
skip_if_not_installed("readxl")

source(file.path(turas_root, "modules/shared/lib/config_utils.R"))
source(file.path(turas_root, "modules/shared/template_styles.R"))
source(file.path(turas_root, "modules/keydriver/lib/generate_config_templates.R"))

generated_template <- function() {
  p <- tempfile(fileext = ".xlsx")
  suppressMessages(generate_keydriver_config_template(p))
  p
}

test_that("the generated template's sheets load with their real headers", {
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)

  settings <- as.data.frame(load_config_table_sheet(
    p, "Settings", required_cols = c("Setting", "Value")
  ))

  # Row 1 is the title. If it were still being read as the header, "Setting"
  # and "Value" would not be column names at all.
  expect_true(all(c("Setting", "Value") %in% names(settings)))
  expect_gt(nrow(settings), 0)

  variables <- as.data.frame(load_config_table_sheet(
    p, "Variables", required_cols = "VariableName"
  ))
  expect_true("VariableName" %in% names(variables))
  expect_gt(nrow(variables), 0)
})

test_that("the help text row never arrives as data", {
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)

  variables <- as.data.frame(load_config_table_sheet(
    p, "Variables", required_cols = "VariableName"
  ))

  expect_false(any(grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                         as.character(variables[[1]]))))
})

test_that("every generated sheet still carries a title in row 1", {
  # If this ever stops being true the loader's header scan is doing nothing,
  # and the test above would pass for the wrong reason.
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)

  for (sh in openxlsx::getSheetNames(p)) {
    raw <- suppressMessages(readxl::read_excel(p, sheet = sh, col_names = FALSE,
                                               n_max = 1, col_types = "text"))
    expect_true(grepl("TURAS", as.character(raw[[1]][1]), fixed = TRUE),
                info = sprintf("sheet %s", sh))
  }
})

test_that("load_keydriver_config accepts the template it generates", {
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)

  for (f in list.files(file.path(turas_root, "modules/keydriver/R"),
                       pattern = "[.]R$", full.names = TRUE)) {
    try(suppressMessages(suppressWarnings(source(f))), silent = TRUE)
  }
  skip_if_not(exists("load_keydriver_config", mode = "function"))

  cfg <- suppressMessages(load_keydriver_config(p))

  expect_type(cfg, "list")
  expect_true("settings" %in% names(cfg))
  # The two optional sheets ship empty, so an untouched template asks for
  # neither a segment comparison nor a stated-importance comparison, and the
  # loader says so rather than refusing (review M12).
  expect_null(cfg$segments)
  expect_null(cfg$stated_importance)
})

test_that("a StatedImportance rating survives the template's help row as a number", {
  # The help row above the data used to type the whole column character, and
  # the module refused with CFG_STATED_IMPORTANCE_NO_NUMERIC. The template no
  # longer ships example rows, so the guard is built here from the template's
  # own column definitions and the same writer, which is where the bug lived.
  p <- tempfile(fileext = ".xlsx")
  on.exit(unlink(p), add = TRUE)

  wb <- openxlsx::createWorkbook()
  write_table_sheet(
    wb = wb,
    sheet_name = "StatedImportance",
    columns_def = build_stated_importance_columns(),
    title = "TURAS Key Driver Analysis - Stated Importance",
    subtitle = "Round-trip guard",
    example_rows = list(
      list(driver = "digital_banking", stated_importance = 8.2),
      list(driver = "fees_clarity", stated_importance = 7.5)
    ),
    num_blank_rows = 5
  )
  if (exists("turas_saveWorkbook", mode = "function")) {
    turas_saveWorkbook(wb, p, overwrite = TRUE)
  } else {
    openxlsx::saveWorkbook(wb, p, overwrite = TRUE)
  }

  si <- as.data.frame(load_config_table_sheet(p, "StatedImportance",
                                              required_cols = "driver"))
  expect_true(is.numeric(si$stated_importance))
  expect_equal(si$stated_importance[!is.na(si$stated_importance)], c(8.2, 7.5))
})

test_that("the template offers every sheet the loader reads (M11)", {
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)
  sheets <- readxl::excel_sheets(p)
  # CustomSlides and Insights have been read by the loader since v10.4 and
  # the template never offered them, so the feature was undiscoverable from
  # the file an analyst actually opens.
  expect_true(all(c("Settings", "Variables", "Segments", "StatedImportance",
                    "CustomSlides", "Insights") %in% sheets))
})

test_that("the template offers every Setting the code reads (M11)", {
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)
  settings <- as.data.frame(load_config_table_sheet(
    p, "Settings", required_cols = c("Setting", "Value")))
  keys <- settings$Setting[!is.na(settings$Setting)]

  # Read out of the code, not invented: the v10.4 method gates and their
  # tuning knobs, the display modes, the seed, and the report's own keys.
  needed <- c(
    "enable_elastic_net", "enable_nca", "enable_dominance", "enable_gam",
    "elastic_net_alpha", "elastic_net_nfolds", "gam_k", "nca_test_reps",
    "min_segment_n", "correlation_display", "bootstrap_display", "random_seed",
    "vif_moderate_threshold", "vif_high_threshold",
    "company_name", "client_name", "researcher_name",
    "researcher_logo_path", "client_logo_path",
    paste0("html_show_", c("exec_summary", "importance", "methods",
                           "effect_sizes", "correlations", "diagnostics",
                           "segments", "shap", "quadrant", "bootstrap", "guide")))
  expect_equal(setdiff(needed, keys), character(0))

  # One bootstrap default everywhere, including here (review M8).
  expect_equal(trimws(as.character(
    settings$Value[settings$Setting == "bootstrap_iterations"])), "1000")
})
