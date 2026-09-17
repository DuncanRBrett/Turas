# ==============================================================================
# MAXDIFF - THE STATS PACK CHECKBOX AGREES WITH THE CONFIG
# ==============================================================================
# Item 9 of the v2 follow-up handover. The GUI checkbox shipped unticked and the
# GUI's choice IS the toggle the run obeys (Session A, M11), so a config saying
# Generate_Stats_Pack = YES silently produced no pack. Duncan hit this on
# 2026-09-03. The checkbox is now defaulted from the config.
# ==============================================================================

gui_file <- file.path(TURAS_ROOT, "modules", "maxdiff", "run_maxdiff_gui.R")
gui_env <- new.env()
sys.source(gui_file, envir = gui_env)
read_setting <- gui_env$maxdiff_config_stats_pack

write_cfg <- function(sheets) {
  path <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(sheets, path)
  path
}

test_that("the config reader finds YES in OUTPUT_SETTINGS", {
  path <- write_cfg(list(OUTPUT_SETTINGS = data.frame(
    Option_Name = c("Generate_Charts", "Generate_Stats_Pack"),
    Value = c("NO", "YES"), stringsAsFactors = FALSE
  )))
  expect_true(read_setting(path))
})

test_that("the config reader finds NO in OUTPUT_SETTINGS", {
  path <- write_cfg(list(OUTPUT_SETTINGS = data.frame(
    Option_Name = "Generate_Stats_Pack", Value = "NO", stringsAsFactors = FALSE
  )))
  expect_false(read_setting(path))
})

test_that("OUTPUT_SETTINGS wins over the legacy PROJECT_SETTINGS spelling", {
  path <- write_cfg(list(
    PROJECT_SETTINGS = data.frame(Setting_Name = "Generate_Stats_Pack",
                                  Value = "N", stringsAsFactors = FALSE),
    OUTPUT_SETTINGS  = data.frame(Option_Name = "Generate_Stats_Pack",
                                  Value = "Y", stringsAsFactors = FALSE)
  ))
  expect_true(read_setting(path))
})

test_that("the legacy PROJECT_SETTINGS spelling is read when OUTPUT_SETTINGS is silent", {
  path <- write_cfg(list(
    PROJECT_SETTINGS = data.frame(Setting_Name = "Generate_Stats_Pack",
                                  Value = "Y", stringsAsFactors = FALSE),
    OUTPUT_SETTINGS  = data.frame(Option_Name = "Generate_Charts",
                                  Value = "Y", stringsAsFactors = FALSE)
  ))
  expect_true(read_setting(path))
})

test_that("a config that does not mention the setting reads as NULL", {
  path <- write_cfg(list(OUTPUT_SETTINGS = data.frame(
    Option_Name = "Generate_Charts", Value = "YES", stringsAsFactors = FALSE
  )))
  expect_null(read_setting(path))
})

test_that('the workbook placeholder "NA" is not read as a value', {
  path <- write_cfg(list(OUTPUT_SETTINGS = data.frame(
    Option_Name = "Generate_Stats_Pack", Value = "NA", stringsAsFactors = FALSE
  )))
  expect_null(read_setting(path))
})

test_that("a missing or unreadable file reads as NULL rather than erroring", {
  expect_null(read_setting(NULL))
  expect_null(read_setting(file.path(tempdir(), "no_such_config.xlsx")))
})

test_that("the GUI checkbox takes its default from the config, not a hard-coded FALSE", {
  src <- readLines(gui_file, warn = FALSE)
  at <- grep('checkboxInput("generate_stats_pack"', src, fixed = TRUE)
  expect_length(at, 1)
  block <- paste(src[at:(at + 2)], collapse = "\n")
  expect_match(block, "isTRUE(.cfg_sp)", fixed = TRUE)
  expect_false(grepl("value = FALSE", block, fixed = TRUE))
})

test_that("00_main.R prints a line when the GUI setting and the config disagree", {
  main <- paste(readLines(file.path(TURAS_ROOT, "modules", "maxdiff", "R", "00_main.R"),
                          warn = FALSE), collapse = "\n")
  expect_match(main, "which differs from the config", fixed = TRUE)
  expect_match(main, ".sp_config", fixed = TRUE)
})
