# ==============================================================================
# WEIGHTING MODULE - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for generate_config_templates.R:
#   - generate_weight_config_template()
#   - generate_all_weighting_templates()
#
# Run with:
#   testthat::test_file("modules/weighting/tests/testthat/test_config_templates.R")
# ==============================================================================

# setup.R provides TURAS_ROOT and MODULE_DIR

# Source shared template infrastructure first (required by generator)
shared_styles <- file.path(TURAS_ROOT, "modules", "shared", "template_styles.R")
if (file.exists(shared_styles)) source(shared_styles)

# Source the template generator
source(file.path(MODULE_DIR, "lib", "generate_config_templates.R"))


# ==============================================================================
# TESTS: generate_weight_config_template()
# ==============================================================================

test_that("generate_weight_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_weight_config_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_true(isTRUE(result))
})

test_that("weighting config template contains all 7 expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expected_sheets <- c("General", "Weight_Specifications", "Design_Targets",
                        "Rim_Targets", "Cell_Targets", "Advanced_Settings", "Notes")
  for (s in expected_sheets) {
    expect_true(s %in% sheets,
                info = sprintf("Missing sheet '%s'", s))
  }
})

test_that("Weight_Specifications sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  ws <- openxlsx::read.xlsx(tmp, sheet = "Weight_Specifications", startRow = 3)

  expected_cols <- c("weight_name", "method", "apply_trimming")
  for (col in expected_cols) {
    expect_true(col %in% names(ws),
                info = sprintf("Missing column '%s' in Weight_Specifications", col))
  }
})

test_that("Rim_Targets sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  rt <- openxlsx::read.xlsx(tmp, sheet = "Rim_Targets", startRow = 3)

  expected_cols <- c("weight_name", "variable", "category", "target_percent")
  for (col in expected_cols) {
    expect_true(col %in% names(rt),
                info = sprintf("Missing column '%s' in Rim_Targets", col))
  }
})

test_that("Design_Targets sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  dt <- openxlsx::read.xlsx(tmp, sheet = "Design_Targets", startRow = 3)

  expected_cols <- c("weight_name", "stratum_variable", "stratum_category", "population_size")
  for (col in expected_cols) {
    expect_true(col %in% names(dt),
                info = sprintf("Missing column '%s' in Design_Targets", col))
  }
})

test_that("generate_weight_config_template returns TRS refusal for NULL path", {
  result <- generate_weight_config_template(NULL)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("generate_weight_config_template returns TRS refusal for non-character path", {
  result <- generate_weight_config_template(123)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})


# ==============================================================================
# TESTS: generate_all_weighting_templates()
# ==============================================================================

test_that("generate_all_weighting_templates creates file in output dir", {
  tmp_dir <- tempdir()
  out_dir <- file.path(tmp_dir, paste0("weighting_tpl_", Sys.getpid()))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  result <- generate_all_weighting_templates(out_dir)

  expected_path <- file.path(out_dir, "Weight_Config.xlsx")
  expect_true(file.exists(expected_path))
  expect_true(isTRUE(result))
})

test_that("generate_all_weighting_templates returns TRS refusal for NULL dir", {
  result <- generate_all_weighting_templates(NULL)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("Advanced_Settings offers the settings the engine reads, and only those", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  adv <- openxlsx::read.xlsx(tmp, sheet = "Advanced_Settings", startRow = 3)

  # calculate_rim_weights_from_config() reads each of these
  for (col in c("weight_name", "max_iterations", "convergence_tolerance",
                "calibration_method", "weight_bounds")) {
    expect_true(col %in% names(adv),
                info = sprintf("Missing column '%s' in Advanced_Settings", col))
  }

  # force_convergence was offered as a Y/N dropdown but read by nothing, so a
  # config author could set it and silently get a refusal anyway. Removed.
  expect_false("force_convergence" %in% names(adv))

  # The example row must itself be a valid configuration.
  # (Row 3 is the header, row 4 the help text, so the example starts at row 5 —
  #  find it by weight_name rather than by position.)
  example <- adv[!is.na(adv$weight_name) & adv$weight_name == "wgt_demo", , drop = FALSE]
  expect_equal(nrow(example), 1)
  expect_true(example$calibration_method[1] %in% c("raking", "linear", "logit"))
  expect_match(as.character(example$weight_bounds[1]), "^[0-9.]+,[0-9.]+$")
})

# ==============================================================================
# ROUND TRIP: the template the module generates must load in the module's loader
# ==============================================================================
# write_table_sheet() puts a title in row 1 and the real headers in row 3, so a
# plain read_excel() takes the title as the header row and every generated
# template was refused with CFG_MISSING_COLUMNS before it could weight anything.
# Nothing caught it because every fixture and example script writes headers in
# row 1, and the template tests above read at startRow = 3 and never touch the
# loader. This test is that missing gate.

#' Write a value into a Setting/Value sheet, finding the row by setting name
#' rather than by a hardcoded coordinate (the layout is what is under test).
#' @keywords internal
set_template_setting <- function(wb, path, sheet, setting, value) {
  raw <- suppressMessages(readxl::read_excel(path, sheet = sheet,
                                             col_names = FALSE, col_types = "text"))
  row_idx <- which(as.character(raw[[1]]) == setting)
  if (length(row_idx) != 1) {
    stop(sprintf("Expected exactly one '%s' row in %s, found %d",
                 setting, sheet, length(row_idx)))
  }
  openxlsx::writeData(wb, sheet, value, startRow = row_idx[1], startCol = 2)
}

test_that("a filled-in generated template loads through load_weighting_config", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("readxl")

  tmp <- tempfile(fileext = ".xlsx")
  data_path <- tempfile(fileext = ".csv")
  on.exit(unlink(c(tmp, data_path)), add = TRUE)

  write.csv(create_simple_survey(n = 50), data_path, row.names = FALSE)
  generate_weight_config_template(tmp)

  # Fill the two settings the template deliberately ships blank
  wb <- openxlsx::loadWorkbook(tmp)
  set_template_setting(wb, tmp, "General", "project_name", "Template Round Trip")
  set_template_setting(wb, tmp, "General", "data_file", data_path)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  config <- load_weighting_config(tmp, verbose = FALSE)

  expect_equal(config$general$project_name, "Template Round Trip")

  # The template's own worked example must survive the trip intact: three
  # weights, each with the targets its method needs.
  expect_true(all(c("wgt_demo", "wgt_design", "wgt_cell") %in%
                    config$weight_specifications$weight_name))
  expect_true(nrow(config$rim_targets) > 0)
  expect_true(nrow(config$design_targets) > 0)
  expect_true(nrow(config$cell_targets) > 0)

  # Help text ("[REQUIRED] ...") must not arrive as data
  expect_false(any(grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                         config$weight_specifications$weight_name)))

  # Advanced_Settings carries the calibration settings the rim engine reads
  expect_true(all(c("calibration_method", "weight_bounds") %in%
                    names(config$advanced_settings)))
})

test_that("the checked-in template workbooks load once filled in", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("openxlsx")

  templates <- file.path(TURAS_ROOT, "modules", "weighting", "docs", "templates",
                         c("Weight_Config.xlsx", "Weight_Config_Template.xlsx"))

  data_path <- tempfile(fileext = ".csv")
  on.exit(unlink(data_path), add = TRUE)
  write.csv(create_simple_survey(n = 50), data_path, row.names = FALSE)

  for (tpl in templates) {
    skip_if(!file.exists(tpl), sprintf("%s not present", basename(tpl)))

    # Work on a copy — never write to the shipped file from a test
    work <- tempfile(fileext = ".xlsx")
    file.copy(tpl, work, overwrite = TRUE)
    on.exit(unlink(work), add = TRUE)

    wb <- openxlsx::loadWorkbook(work)
    set_template_setting(wb, work, "General", "project_name", "Shipped Template Check")
    set_template_setting(wb, work, "General", "data_file", data_path)
    openxlsx::saveWorkbook(wb, work, overwrite = TRUE)

    config <- load_weighting_config(work, verbose = FALSE)
    expect_equal(config$general$project_name, "Shipped Template Check",
                 info = sprintf("%s did not load", basename(tpl)))
    expect_true(nrow(config$weight_specifications) > 0,
                info = sprintf("%s has no weight specifications", basename(tpl)))
  }
})


# ==============================================================================
# TESTS: the template's own examples must not be refused by the engine
# ==============================================================================

test_that("no example weight spec pairs rim with post-hoc trimming", {
  # apply_trimming = Y on a rim/rake spec is refused (CFG_TRIM_USE_CAP), because
  # capping after calibration breaks the margins raking just achieved. The
  # shipped template used to demonstrate exactly that combination, so anyone
  # copying the example row got a refusal.
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)

  specs <- as.data.frame(load_config_table_sheet(
    tmp, "Weight_Specifications",
    required_cols = c("weight_name", "method")
  ))

  offending <- specs[
    tolower(as.character(specs$method)) %in% c("rim", "rake") &
      toupper(as.character(specs$apply_trimming)) %in% "Y", , drop = FALSE
  ]

  expect_equal(
    nrow(offending), 0,
    info = paste("Rim example rows with apply_trimming = Y:",
                 paste(offending$weight_name, collapse = ", "))
  )
})

test_that("every example weight spec survives apply_trimming_from_config", {
  # The stronger form of the check above: run each example row through the
  # function that refuses, rather than asserting on its fields.
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)

  specs <- as.data.frame(load_config_table_sheet(
    tmp, "Weight_Specifications",
    required_cols = c("weight_name", "method")
  ))

  weights <- c(0.5, 1.0, 2.0, 5.0, 10.0)

  for (i in seq_len(nrow(specs))) {
    spec <- as.list(specs[i, ])
    err <- tryCatch({
      apply_trimming_from_config(weights, spec, verbose = FALSE)
      NULL
    }, error = function(e) conditionMessage(e))

    expect_null(err, info = sprintf("example row '%s' (%s) was refused: %s",
                                    spec$weight_name, spec$method, err))
  }
})
