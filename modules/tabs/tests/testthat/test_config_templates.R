# ==============================================================================
# TABS MODULE - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for generate_config_templates.R:
#   - generate_crosstab_config_template()
#   - generate_survey_structure_template()
#   - generate_all_templates()
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_config_templates.R")
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()
tabs_root <- file.path(turas_root, "modules", "tabs")

# Source shared TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Source shared template infrastructure first (the generator relies on
# sys.frame(1)$ofile which may not resolve in test context)
shared_styles <- file.path(turas_root, "modules", "shared", "template_styles.R")
if (file.exists(shared_styles)) source(shared_styles)

# Source the template generator
source(file.path(tabs_root, "lib", "generate_config_templates.R"))

# Also source the config loader (and its table-sheet helper) so the optional
# Population sheet can be round-tripped back through load_population_sheet().
# type_utils.R provides safe_logical/safe_numeric, which build_config_object()
# calls at runtime (not just define-time), so it must load before any test
# calls build_config_object() directly.
# Guarded — a missing dependency must not break the template tests.
for (dep in c(file.path("lib", "validation_utils.R"),
              file.path("lib", "path_utils.R"),
              file.path("lib", "type_utils.R"),
              file.path("lib", "logging_utils.R"),
              file.path("lib", "config_utils.R"),
              file.path("lib", "excel_utils.R"),
              file.path("lib", "filter_utils.R"),
              file.path("lib", "data_loader.R"),
              file.path("lib", "crosstabs", "crosstabs_config.R"))) {
  p <- file.path(tabs_root, dep)
  if (file.exists(p)) try(source(p), silent = TRUE)
}


# ==============================================================================
# TESTS: generate_crosstab_config_template()
# ==============================================================================

test_that("generate_crosstab_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_crosstab_config_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_equal(result, tmp)
})

test_that("crosstab config template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Settings" %in% sheets)
  expect_true("Selection" %in% sheets)
  expect_true("Comments" %in% sheets)
  expect_true("AddedSlides" %in% sheets)
  expect_true("Population" %in% sheets)
})

test_that("crosstab config template Population sheet round-trips through the loader", {
  skip_if_not(exists("load_population_sheet", mode = "function"))
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  frame <- load_population_sheet(tmp)

  # The template ships two worked examples (Masters/Honours by Year).
  expect_false(is.null(frame))
  expect_true(all(c("banner", "group", "population") %in% names(frame)))
  expect_true("Masters" %in% frame$group)
  expect_true(all(frame$population > 1))
})

test_that("crosstab config Settings sheet has expected structure", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  settings <- openxlsx::read.xlsx(tmp, sheet = "Settings")

  # Settings sheet uses key-value layout; first column should contain field names
  expect_true(nrow(settings) > 0)
})

test_that("crosstab config Settings sheet offers the Reader report flags", {
  # WP1: freshly generated configs must expose generate_reader_report and
  # reader_ai_prose (both default FALSE), or the Reader report can never be
  # switched on from a template-built config.
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  settings <- openxlsx::read.xlsx(tmp, sheet = "Settings", colNames = FALSE)
  cells <- unlist(settings, use.names = FALSE)

  expect_true("generate_reader_report" %in% cells)
  expect_true("reader_ai_prose" %in% cells)
})

test_that("crosstab config Settings sheet offers the Qualitative (comment) tab settings", {
  # Regression guard: the qual_* dials were hand-added to live configs (drift) and
  # missing from the generator, so a fresh template could not switch on the comment tab
  # or its host-tag / confidentiality options without the operator knowing the key names.
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  settings <- openxlsx::read.xlsx(tmp, sheet = "Settings", colNames = FALSE)
  cells <- unlist(settings, use.names = FALSE)

  for (k in c("qual_workbook", "qual_confidentiality_mode", "qual_demographic_cuts",
              "qual_noteworthy_default", "qual_tag_dimensions", "qual_join_id_column")) {
    expect_true(k %in% cells, info = paste(k, "should appear in the generated Settings sheet"))
  }
  # each qual dial ships a description (the operator shouldn't have to guess the choices)
  expect_true(any(grepl("k-anonymise", cells, fixed = TRUE)))       # qual_demographic_cuts help
  expect_true(any(grepl("S03:Centre", cells, fixed = TRUE)))        # qual_tag_dimensions example
})

test_that("crosstab config Settings sheet writes research_house in lowercase snake_case", {
  # Regression guard: this field was previously written as "Research_House",
  # which get_config_value() (an exact-match lookup) can never find since
  # build_config_object() reads it as "research_house" — a silent no-op even
  # when the operator filled the cell in. Every other Settings-sheet field
  # uses lowercase_snake_case; this one must match that convention too.
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  settings <- openxlsx::read.xlsx(tmp, sheet = "Settings", colNames = FALSE)
  cells <- unlist(settings, use.names = FALSE)

  expect_true("research_house" %in% cells)
  expect_false("Research_House" %in% cells)
})

test_that(".KNOWN_SETTINGS whitelist recognises settings that were flagged as unrecognised on live CCPB config", {
  # Regression guard for a batch of settings that were genuinely in use
  # (loaded by build_config_object with real defaults, or consumed
  # downstream) but missing from the config loader's known-settings
  # whitelist, so every project using them saw a false "may be typos"
  # warning. The whitelist now lives in the TABS_KNOWN_SETTINGS constant (it is
  # shared with warn_merged_setting_rows), so it is checked directly rather than
  # by grepping the deparsed body of load_crosstabs_config().
  skip_if_not(exists("TABS_KNOWN_SETTINGS"))

  for (setting in c("heatmap_colour", "research_house", "qual_workbook", "qual_confidentiality_mode",
                     "qual_demographic_cuts", "qual_noteworthy_default", "min_reporting_base",
                     "qual_tag_dimensions", "qual_join_id_column")) {
    expect_true(
      setting %in% TABS_KNOWN_SETTINGS,
      info = sprintf("'%s' should be in the known-settings whitelist", setting)
    )
  }
})

test_that("build_config_object loads heatmap_colour and research_house through to the config object", {
  # Regression guard: both settings were readable downstream
  # (02_table_builder.R, stats_diagnostics.R) but never assigned in
  # build_config_object(), so they were silent no-ops even when set.
  skip_if_not(exists("build_config_object", mode = "function"))

  config_obj <- build_config_object(list(
    heatmap_colour = "#123456",
    research_house = "White Label Partner Co"
  ))

  expect_equal(config_obj$heatmap_colour, "#123456")
  expect_equal(config_obj$research_house, "White Label Partner Co")
})

test_that("build_config_object loads qual_tag_dimensions through to the config object", {
  # Regression guard (Feature 2 host tags): config_obj is an explicit whitelist, not the
  # raw settings — a qual_tag_dimensions row was read fine downstream but never assigned
  # here, so the comment tag control silently never appeared even when the setting was set.
  skip_if_not(exists("build_config_object", mode = "function"))
  config_obj <- build_config_object(list(qual_tag_dimensions = "S03:Centre, S11:Channel"))
  expect_equal(config_obj$qual_tag_dimensions, "S03:Centre, S11:Channel")
  # and it defaults to "" (a clean no-op) when unset
  expect_equal(build_config_object(list())$qual_tag_dimensions, "")
})

test_that("html_report_v2_microdata: default TRUE, explicit FALSE honoured, junk cannot flip it", {
  # The no-micro confidentiality flag (aggregates-only client ships). Only an
  # explicit FALSE may omit the island: a blank Settings cell reaches the
  # loader as the string "NA" (stringification gotcha), and junk must not
  # silently strip the live filter / custom banners from every report.
  skip_if_not(exists("build_config_object", mode = "function"))

  expect_true(build_config_object(list())$html_report_v2_microdata)   # unset -> TRUE
  expect_false(build_config_object(list(html_report_v2_microdata = "FALSE"))$html_report_v2_microdata)
  expect_false(build_config_object(list(html_report_v2_microdata = "No"))$html_report_v2_microdata)
  expect_true(build_config_object(list(html_report_v2_microdata = "TRUE"))$html_report_v2_microdata)
  expect_true(build_config_object(list(html_report_v2_microdata = "NA"))$html_report_v2_microdata)
})

test_that("html_report_v2_microdata is registered in the known-settings whitelist", {
  skip_if_not(exists("TABS_KNOWN_SETTINGS"))
  expect_true("html_report_v2_microdata" %in% TABS_KNOWN_SETTINGS)
})

test_that("build_config_object defaults research_house sensibly when unset", {
  skip_if_not(exists("build_config_object", mode = "function"))
  config_obj <- build_config_object(list())
  expect_equal(config_obj$research_house, "The Research LampPost")
})

test_that("Patterns levers pass the config whitelist (the config_obj gotcha)", {
  empty <- build_config_object(list())
  expect_null(empty$patterns_headline)
  expect_null(empty$patterns_exclude_banners)
  cfg <- build_config_object(list(
    patterns_headline = "Q78, Q79",
    patterns_exclude_banners = "Interviewer"))
  expect_equal(cfg$patterns_headline, "Q78, Q79")
  expect_equal(cfg$patterns_exclude_banners, "Interviewer")
})

test_that("crosstab config Selection sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  selection <- openxlsx::read.xlsx(tmp, sheet = "Selection", startRow = 3)

  expected_cols <- c("QuestionCode", "Include", "UseBanner", "KeyShare", "AreaSummary")
  for (col in expected_cols) {
    expect_true(col %in% names(selection),
                info = sprintf("Missing column '%s' in Selection sheet", col))
  }
})


# ==============================================================================
# TESTS: generate_survey_structure_template()
# ==============================================================================

test_that("generate_survey_structure_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_survey_structure_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_equal(result, tmp)
})

test_that("survey structure template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_survey_structure_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Project" %in% sheets)
  expect_true("Questions" %in% sheets)
  expect_true("Options" %in% sheets)
  expect_true("Composite_Metrics" %in% sheets)
})

test_that("survey structure Questions sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_survey_structure_template(tmp)
  questions <- openxlsx::read.xlsx(tmp, sheet = "Questions", startRow = 3)

  expected_cols <- c("QuestionCode", "QuestionText", "Variable_Type", "Columns")
  for (col in expected_cols) {
    expect_true(col %in% names(questions),
                info = sprintf("Missing column '%s' in Questions sheet", col))
  }
})

test_that("survey structure Options sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_survey_structure_template(tmp)
  options_df <- openxlsx::read.xlsx(tmp, sheet = "Options", startRow = 3)

  expected_cols <- c("QuestionCode", "OptionText", "DisplayText")
  for (col in expected_cols) {
    expect_true(col %in% names(options_df),
                info = sprintf("Missing column '%s' in Options sheet", col))
  }
})


# ==============================================================================
# TESTS: generate_all_templates()
# ==============================================================================

test_that("generate_all_templates creates both files", {
  tmp_dir <- tempdir()
  out_dir <- file.path(tmp_dir, paste0("tabs_templates_", Sys.getpid()))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  result <- generate_all_templates(out_dir)

  config_path <- file.path(out_dir, "Crosstab_Config.xlsx")
  structure_path <- file.path(out_dir, "Survey_Structure.xlsx")

  expect_true(file.exists(config_path),
              info = "Crosstab_Config.xlsx should be created")
  expect_true(file.exists(structure_path),
              info = "Survey_Structure.xlsx should be created")
})

test_that("crosstab config template overwrites existing file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  first_size <- file.size(tmp)

  generate_crosstab_config_template(tmp)
  second_size <- file.size(tmp)

  # File should still exist and be valid

  expect_true(file.exists(tmp))
  expect_true(second_size > 0)
})

# ==============================================================================
# MERGED SETTING ROWS — a setting with no Value cell must not vanish quietly
# ==============================================================================

context("crosstabs_config: merged setting rows")

# The Settings sheet formats SECTION HEADERS as a row merged across A:E. A real
# setting row that picks up that formatting has no Value cell, readxl reads NA,
# load_config_sheet drops the setting, and the run uses the default in silence —
# how CCPB W2026 lost question_mapping and shipped an unpaired Tracking tab.
msr_fixture <- function(merge_rows = integer(0), merge_cols = 1:5) {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  df <- data.frame(
    Setting = c("apply_weighting", "WEIGHTING", "question_mapping", "priority_metric"),
    Value   = c("FALSE", NA, "map.xlsx", "Mean"),
    stringsAsFactors = FALSE)
  openxlsx::writeData(wb, "Settings", df)          # header row 1, data rows 2-5
  for (r in merge_rows) openxlsx::mergeCells(wb, "Settings", cols = merge_cols, rows = r)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

test_that("excel_col_number converts single and multi-letter references", {
  expect_equal(excel_col_number("A"), 1L)
  expect_equal(excel_col_number("B"), 2L)
  expect_equal(excel_col_number("Z"), 26L)
  expect_equal(excel_col_number("AB"), 28L)
})

test_that("a merged setting row is named, with its row and merge range", {
  f <- msr_fixture(merge_rows = 4)                 # row 4 = question_mapping
  on.exit(unlink(f), add = TRUE)
  out <- capture.output(hits <- warn_merged_setting_rows(f))
  expect_equal(hits, "question_mapping")
  expect_true(any(grepl("question_mapping", out)))
  expect_true(any(grepl("row 4", out)))
  expect_true(any(grepl("A4:E4", out)))
  expect_true(any(grepl("unmerge", out, ignore.case = TRUE)))
})

test_that("a merged SECTION HEADER is not mistaken for a broken setting", {
  f <- msr_fixture(merge_rows = 3)                 # row 3 = "WEIGHTING", a header
  on.exit(unlink(f), add = TRUE)
  out <- capture.output(hits <- warn_merged_setting_rows(f))
  expect_equal(length(hits), 0)
  expect_equal(length(out), 0)
})

test_that("an unmerged sheet says nothing at all", {
  f <- msr_fixture()
  on.exit(unlink(f), add = TRUE)
  out <- capture.output(hits <- warn_merged_setting_rows(f))
  expect_equal(length(hits), 0)
  expect_equal(length(out), 0)
})

test_that("a merge that leaves the Value cell readable is not reported", {
  f <- msr_fixture(merge_rows = 4, merge_cols = 2:5)   # B4:E4 — B is the anchor
  on.exit(unlink(f), add = TRUE)
  expect_equal(length(capture.output(hits <- warn_merged_setting_rows(f))), 0)
  expect_equal(length(hits), 0)
})

test_that("several broken rows are listed together, in sheet order", {
  f <- msr_fixture(merge_rows = c(5, 4))           # priority_metric + question_mapping
  on.exit(unlink(f), add = TRUE)
  out <- capture.output(hits <- warn_merged_setting_rows(f))
  expect_equal(hits, c("question_mapping", "priority_metric"))   # row 4 before row 5
})

test_that("an unreadable file or missing sheet is silent, never an error", {
  expect_silent(h1 <- warn_merged_setting_rows(tempfile(fileext = ".xlsx")))
  expect_equal(length(h1), 0)
  f <- msr_fixture(merge_rows = 4)
  on.exit(unlink(f), add = TRUE)
  expect_silent(h2 <- warn_merged_setting_rows(f, sheet_name = "NoSuchSheet"))
  expect_equal(length(h2), 0)
})

test_that("TABS_KNOWN_SETTINGS is the shared list, not a private copy", {
  expect_true(is.character(TABS_KNOWN_SETTINGS))
  expect_true(all(c("question_mapping", "priority_metric", "qual_verbatim_scope")
                  %in% TABS_KNOWN_SETTINGS))
  expect_false(any(duplicated(TABS_KNOWN_SETTINGS)))
})

# ==============================================================================
# CASE-MISMATCHED SETTING NAMES — the lookup is exact, the typo check is not
# ==============================================================================

context("crosstabs_config: case-mismatched setting names")

test_that("a case variant is named, with the spelling the loader wants", {
  out <- capture.output(
    hits <- warn_case_mismatched_settings(list(Research_House = "TRL",
                                               apply_weighting = "FALSE")))
  expect_equal(hits, "Research_House")
  expect_true(any(grepl("Research_House", out, fixed = TRUE)))
  expect_true(any(grepl("research_house", out, fixed = TRUE)))
  expect_false(any(grepl("apply_weighting", out, fixed = TRUE)))
})

test_that("a variant that already has a correct twin is marked, with the collision warning", {
  out <- capture.output(
    hits <- warn_case_mismatched_settings(list(analyst_name = "D", Analyst_Name = "D")))
  expect_equal(hits, "Analyst_Name")
  expect_true(any(grepl("[duplicate]", out, fixed = TRUE)))
  expect_true(any(grepl("DELETE", out, fixed = TRUE)))
})

test_that("correctly named settings, and genuine unknowns, are left alone", {
  # An unknown name is the typo check's job, not this one — no double-reporting.
  expect_silent(h <- warn_case_mismatched_settings(
    list(apply_weighting = "FALSE", nonsense_setting = "x")))
  expect_equal(length(h), 0)
  expect_equal(length(capture.output(warn_case_mismatched_settings(list()))), 0)
})

test_that("the CCPB case-variant labels are all recognised as canonical settings", {
  # Regression guard for the live CCPB configs: these four rows carry values
  # that never reached a run because the sheet capitalises them.
  for (nm in c("research_house", "project_name", "analyst_name", "generate_stats_pack")) {
    expect_true(nm %in% TABS_KNOWN_SETTINGS, info = nm)
  }
  out <- capture.output(hits <- warn_case_mismatched_settings(
    list(Generate_Stats_Pack = "Y", Project_Name = "P",
         Analyst_Name = "D", Research_House = "TRL")))
  expect_equal(length(hits), 4)
})
