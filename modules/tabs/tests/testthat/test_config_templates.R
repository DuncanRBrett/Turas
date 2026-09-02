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
# Guarded. A missing dependency must not break the template tests.
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
  expect_true(any(grepl("S01:Centre", cells, fixed = TRUE)))        # qual_tag_dimensions example
})

test_that("every setting build_config_object reads is offered by the template", {
  # Regression guard (review 2026-08-13): the five tab-visibility flags and the
  # general decimal_places fallback were read by build_config_object and listed
  # in TABS_KNOWN_SETTINGS, but appeared in NO template and in no documentation,
  # the only way to discover them was to read the source. A setting the engine
  # honours must be discoverable from a freshly generated config.
  #
  # The weight_* and ranking_* keys are deliberate omissions, documented as such
  # in 06_TEMPLATE_REFERENCE.md; data_file lives on the Survey_Structure Project
  # sheet. Those are named here so the exemption is explicit rather than implied.
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  settings <- openxlsx::read.xlsx(tmp, sheet = "Settings", colNames = FALSE)
  cells <- unlist(settings, use.names = FALSE)

  deliberately_absent <- c(
    "weight_na_threshold", "weight_zero_threshold", "weight_deff_warning",
    "ranking_tie_threshold_pct", "ranking_gap_threshold_pct",
    "ranking_completeness_threshold_pct", "ranking_min_base",
    "data_file"
  )
  expected <- setdiff(TABS_KNOWN_SETTINGS, deliberately_absent)
  missing <- setdiff(expected, cells)

  expect_equal(missing, character(0),
    info = paste("settings the engine reads but no template offers:",
                 paste(missing, collapse = ", ")))
})

test_that("the generated Settings sheet carries no section header without fields", {
  # The retired ROW DESCRIPTORS section left its heading behind with nothing
  # under it, so every generated template shipped an empty section (2026-08-13).
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  raw <- openxlsx::read.xlsx(tmp, sheet = "Settings", colNames = FALSE)
  hrow <- which(raw[[1]] == "Setting")[1]
  body <- raw[(hrow + 1):nrow(raw), , drop = FALSE]

  # A section header is a row with a name but no Required? marker.
  is_section <- !is.na(body[[1]]) & is.na(body[[3]])
  names_col <- as.character(body[[1]])

  empty_sections <- character(0)
  section_rows <- which(is_section)
  for (i in seq_along(section_rows)) {
    r <- section_rows[i]
    nxt <- if (i < length(section_rows)) section_rows[i + 1] else nrow(body) + 1L
    if (nxt - r <= 1L) empty_sections <- c(empty_sections, names_col[r])
  }
  expect_equal(empty_sections, character(0),
    info = paste("section headers with no settings under them:",
                 paste(empty_sections, collapse = ", ")))
})

test_that("crosstab config Settings sheet writes research_house in lowercase snake_case", {
  # Regression guard: this field was previously written as "Research_House",
  # which get_config_value() (an exact-match lookup) can never find since
  # build_config_object() reads it as "research_house". A silent no-op even
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

test_that("html_report_v2_cover is whitelisted, logical, and defaults to FALSE", {
  # The cover shipped with no operator control at all. It was gated purely in
  # JavaScript, so a study could not decline it. The setting must survive all
  # three registration points or it is a silent no-op: the known-settings
  # whitelist (else an "unrecognised setting" warning), the logical list (else
  # the TRUE/FALSE cell is not coerced), and build_config_object (else
  # config_obj$html_report_v2_cover is NULL however the sheet is filled in).
  skip_if_not(exists("TABS_KNOWN_SETTINGS"))
  expect_true("html_report_v2_cover" %in% TABS_KNOWN_SETTINGS)

  skip_if_not(exists("build_config_object", mode = "function"))
  expect_false(build_config_object(list())$html_report_v2_cover)
  expect_true(build_config_object(list(html_report_v2_cover = "TRUE"))$html_report_v2_cover)
  expect_false(build_config_object(list(html_report_v2_cover = "FALSE"))$html_report_v2_cover)
  # a blank cell is not an opt-in
  expect_false(build_config_object(list(html_report_v2_cover = ""))$html_report_v2_cover)
})

test_that("html_report_v2_cover_findings parses a number, ALL, or nothing", {
  # Duncan pinned more than five findings and the cover silently showed five.
  # The count is now his to set. Blank stays NULL so the island is unchanged and
  # the renderer's own default of 5 stands; ALL is the no-limit sentinel 0.
  skip_if_not(exists("TABS_KNOWN_SETTINGS"))
  expect_true("html_report_v2_cover_findings" %in% TABS_KNOWN_SETTINGS)
  # NOT a plain numeric setting: "ALL" is legal, so the generic must-be-a-number
  # validation would refuse a valid cell.
  skip_if_not(exists(".TABS_NUMERIC_SETTINGS"))
  expect_false("html_report_v2_cover_findings" %in% .TABS_NUMERIC_SETTINGS)

  skip_if_not(exists("build_config_object", mode = "function"))
  f <- function(v) build_config_object(list(html_report_v2_cover_findings = v))$html_report_v2_cover_findings
  expect_null(f(NULL))
  expect_null(f(""))
  expect_null(f("   "))
  expect_equal(f("12"), 12)
  expect_equal(f(12), 12)
  expect_equal(f("8.6"), 8)          # floored, never a fractional pin count
  expect_equal(f("ALL"), 0)
  expect_equal(f("all"), 0)          # case-insensitive
  expect_equal(f(" All "), 0)        # and trimmed
  # junk falls back to the default rather than to zero findings
  expect_null(f("lots"))
  expect_null(f("0"))
  expect_null(f("-4"))
})

test_that("build_config_object loads qual_tag_dimensions through to the config object", {
  # Regression guard (Feature 2 host tags): config_obj is an explicit whitelist, not the
  # raw settings. A qual_tag_dimensions row was read fine downstream but never assigned
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

  # AreaSummary/Theme retired with the area cards (2026-08-05); Category stays
  expected_cols <- c("QuestionCode", "Include", "UseBanner", "KeyShare", "Category",
                     "ExcludeFromInsights")
  retired_cols <- c("AreaSummary", "Theme")
  for (col in retired_cols) {
    expect_false(col %in% names(selection),
                 info = sprintf("Retired column '%s' must not regenerate", col))
  }
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
# MERGED SETTING ROWS. A setting with no Value cell must not vanish quietly
# ==============================================================================

context("crosstabs_config: merged setting rows")

# The Settings sheet formats SECTION HEADERS as a row merged across A:E. A real
# setting row that picks up that formatting has no Value cell, readxl reads NA,
# load_config_sheet drops the setting, and the run uses the default in silence,
# how CCPB W2026 lost question_mapping and shipped an unpaired Tracking tab.
msr_fixture <- function(merge_rows = integer(0), merge_cols = 1:5) {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  df <- data.frame(
    Setting = c("apply_weighting", "WEIGHTING", "question_mapping", "sampling_note"),
    Value   = c("FALSE", NA, "map.xlsx", "Substitution allowed"),
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
  f <- msr_fixture(merge_rows = 4, merge_cols = 2:5)   # B4:E4. B is the anchor
  on.exit(unlink(f), add = TRUE)
  expect_equal(length(capture.output(hits <- warn_merged_setting_rows(f))), 0)
  expect_equal(length(hits), 0)
})

test_that("several broken rows are listed together, in sheet order", {
  f <- msr_fixture(merge_rows = c(5, 4))           # sampling_note + question_mapping
  on.exit(unlink(f), add = TRUE)
  out <- capture.output(hits <- warn_merged_setting_rows(f))
  expect_equal(hits, c("question_mapping", "sampling_note"))     # row 4 before row 5
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
  expect_true(all(c("question_mapping", "sampling_note", "qual_verbatim_scope")
                  %in% TABS_KNOWN_SETTINGS))
  expect_false(any(duplicated(TABS_KNOWN_SETTINGS)))
})

# ==============================================================================
# CASE-MISMATCHED SETTING NAMES. The lookup is exact, the typo check is not
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
  # An unknown name is the typo check's job, not this one. No double-reporting.
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


# ==============================================================================
# TESTS: the template must not seed a config that refuses to run
# (regression: ASSA 2026-08)
# ==============================================================================
#
# The Selection sheet used to ship an example row `Total | N | Y | ... | Total`
# captioned "always include as first banner". build_banner_structure() creates
# the Total column itself and starts banner questions at column 2, so that row
# names a question the Questions sheet does not have, which
# check_banner_variables() logs as a BLOCKING Error. Anyone who filled the
# template in around the example rows got a config that refused to run.

read_template_selection <- function(path) {
  sel <- openxlsx::read.xlsx(path, sheet = "Selection", startRow = 3,
                             colNames = TRUE, skipEmptyRows = FALSE)
  sel[!is.na(sel$QuestionCode) & !grepl("^\\[", sel$QuestionCode), , drop = FALSE]
}

test_that("the crosstab template seeds no Total row", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  generate_crosstab_config_template(tmp)

  sel <- read_template_selection(tmp)

  expect_false("Total" %in% sel$QuestionCode)
  expect_true(nrow(sel) > 0)   # the other examples are still there
})

test_that("every banner example in the template is a real example question", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  generate_crosstab_config_template(tmp)

  sel <- read_template_selection(tmp)
  banners <- sel$QuestionCode[!is.na(sel$UseBanner) & toupper(sel$UseBanner) == "Y"]

  # Whatever the examples are, each must also appear as a question example, or
  # the shipped template is a config that cannot pass preflight.
  ss <- tempfile(fileext = ".xlsx")
  on.exit(unlink(ss), add = TRUE)
  generate_survey_structure_template(ss)
  q <- openxlsx::read.xlsx(ss, sheet = "Questions", startRow = 3, colNames = TRUE,
                           skipEmptyRows = FALSE)
  q <- q[!is.na(q$QuestionCode) & !grepl("^\\[", q$QuestionCode), , drop = FALSE]

  expect_true(all(banners %in% q$QuestionCode))
})

test_that("banner DisplayOrder starts at 2, leaving column 1 for Total", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  generate_crosstab_config_template(tmp)

  sel <- read_template_selection(tmp)
  orders <- suppressWarnings(as.numeric(
    sel$DisplayOrder[!is.na(sel$UseBanner) & toupper(sel$UseBanner) == "Y"]))
  orders <- orders[!is.na(orders)]

  expect_true(length(orders) > 0)
  expect_true(min(orders) >= 2)
})

# ==============================================================================
# TRACKING QUESTION_MAPPING TEMPLATE
# ==============================================================================
# A tracker's mapping is the one file a study cannot build retrospectively: get
# it wrong at wave one and wave two has no history to join to. Until 2026-08-13
# the only shipped mapping template was the AGGREGATE one (a different contract
#. Live codes, one wave column), so a study on the raw-data path had no way to
# discover that composites need SourceQuestions or that segment trends need a
# Banners sheet, short of reading examples/sacs_segment_backfill.R.

test_that("the tracking Question_Mapping template carries both sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_tracking_questionmap_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)
  expect_true("QuestionMap" %in% sheets)
  expect_true("Banners" %in% sheets)
})

test_that("the template offers every QuestionMap column the tracker and backfill read", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_tracking_questionmap_template(tmp, waves = c("2024", "2025", "2026"))
  raw <- openxlsx::read.xlsx(tmp, sheet = "QuestionMap", colNames = FALSE)
  hrow <- which(raw[[1]] == "QuestionCode")[1]
  expect_false(is.na(hrow))
  cols <- trimws(as.character(unlist(raw[hrow, ])))

  # tracking_metrics() reads QuestionCode / QuestionText / TrackingSpecs and the
  # wave column; sacs_segment_backfill.R additionally reads SourceQuestions to
  # rebuild a composite for prior waves.
  for (k in c("QuestionCode", "QuestionText", "TrackingSpecs", "SourceQuestions",
              "Wave2024", "Wave2025", "Wave2026")) {
    expect_true(k %in% cols, info = paste(k, "should be a QuestionMap column"))
  }
})

test_that("the generated mapping loads through the real reader with a composite row", {
  skip_if_not(exists("load_question_mapping", mode = "function"),
              "tracking_island.R not sourced in this run")
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_tracking_questionmap_template(tmp)
  qm <- load_question_mapping(tmp)
  expect_false(is.null(qm))
  # help rows are dropped, examples survive
  expect_true(all(c("ENG01", "Engagement") %in% trimws(as.character(qm$QuestionCode))))
  comp <- qm[trimws(as.character(qm$QuestionCode)) == "Engagement", , drop = FALSE]
  expect_true(nzchar(trimws(as.character(comp$SourceQuestions[1]))),
    info = "the composite example must show SourceQuestions filled. That is the whole point of the column")
})

test_that("the Banners sheet reads with its header in row 1 and no stray dimensions", {
  # The backfill reads this sheet plainly, so row 1 must be the header, and
  # anything in column A becomes a banner dimension. A help note written into
  # column A would silently become a breakout named after its own instructions.
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_tracking_questionmap_template(tmp)
  b <- openxlsx::read.xlsx(tmp, sheet = "Banners")
  expect_equal(names(b)[1], "BreakLabel")

  labels <- trimws(as.character(b$BreakLabel))
  labels <- labels[!is.na(labels) & nzchar(labels)]
  expect_true("Total" %in% labels)
  # every dimension is a short name, not prose
  expect_true(all(nchar(labels) <= 40),
    info = paste("stray text in column A becomes a banner dimension:",
                 paste(labels[nchar(labels) > 40], collapse = " | ")))
})

test_that("generate_all_templates ships the mapping alongside config and structure", {
  tmp_dir <- file.path(tempdir(), paste0("tabs_tpl_", as.integer(runif(1, 1, 1e6))))
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  res <- generate_all_templates(tmp_dir)
  expect_true(file.exists(res$mapping))
  expect_true("Banners" %in% openxlsx::getSheetNames(res$mapping))
})
