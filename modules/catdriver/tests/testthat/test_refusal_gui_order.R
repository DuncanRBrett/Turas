# ==============================================================================
# CATDRIVER - REFUSALS IN THE GUI'S SOURCE ORDER (C3)
# ==============================================================================
# The July 2026 production review's C3. Two definitions of catdriver_refuse()
# existed: the live one in 08_guard.R (reason=/fix=) and a stale one in
# 00_guard.R (code=/how_to_fix=). The GUI sources 08_guard.R and then 00_main.R,
# whose top-level code re-sourced 00_guard.R, so the stale signature won in every
# production session and every refusal came out as
# "BUG_INTERNAL_ERROR: report to the Turas development team" with the fix text
# destroyed. The test helper sources R/ in SORTED order, which binds the correct
# signature, so the suite could never see it.
#
# These tests therefore run in a subprocess that sources the files in the GUI's
# own order (run_catdriver_gui.R), not the helper's.
# ==============================================================================

.cd_gui_source_lines <- function(root) {
  files <- c(
    "07_utilities.R", "08_guard.R", "08a_guards_hard.R", "08b_guards_soft.R",
    "01_config.R", "02_validation.R", "03_preprocessing.R", "09_mapper.R",
    "10_missing.R", "04_analysis.R", "04a_ordinal.R", "04b_multinomial.R",
    "05_importance.R", "06a_sheets_summary.R", "06b_sheets_detail.R",
    "06_output.R", "06c_sheets_subgroup.R", "11_subgroup_comparison.R",
    "00_main.R"
  )
  c(
    # The GUI runs with the Turas root as the working directory. 00_main.R's
    # own path fallbacks used to find R/00_guard.R from there, which is how the
    # stale refusal signature reached production; the subprocess must reproduce
    # that working directory or the test cannot see the defect.
    sprintf('setwd("%s")', root),
    sprintf('source("%s")', file.path(root, "modules/shared/lib/import_all.R")),
    sprintf('source("%s")', file.path(root, "modules/catdriver/R", files))
  )
}

.cd_run_in_gui_order <- function(root, body_lines) {
  rscript <- file.path(R.home("bin"), "Rscript")
  script <- tempfile("cd_gui_order_", fileext = ".R")
  writeLines(c(.cd_gui_source_lines(root), body_lines), script)
  out <- suppressWarnings(system2(rscript, shQuote(script), stdout = TRUE, stderr = TRUE))
  unlink(script)
  out
}

test_that("a refusal raised in the GUI's source order is a clean REFUSE, not BUG_INTERNAL_ERROR", {
  skip_if(!file.exists(file.path(R.home("bin"), "Rscript")), "Rscript not found")

  out <- .cd_run_in_gui_order(turas_root, c(
    'res <- with_refusal_handler(',
    '  catdriver_refuse(',
    '    reason = "CFG_TEST_GUI_ORDER",',
    '    title = "TEST REFUSAL",',
    '    problem = "A deliberately broken setting.",',
    '    why_it_matters = "The user must see what to change.",',
    '    fix = "Set Outcome_Variable in the Settings sheet."',
    '  )',
    ')',
    'cat("STATUS:", res$run_status, "\\n")',
    'cat("CODE:", res$code, "\\n")',
    'cat("FIXTEXT:", res$how_to_fix, "\\n")',
    'cat("REFUSAL_CLASS:", inherits(res, "turas_refusal_result"), "\\n")'
  ))
  info <- paste(out, collapse = "\n")

  expect_false(any(grepl("BUG_INTERNAL_ERROR", out, fixed = TRUE)), info = info)
  expect_false(any(grepl("unused argument", out, fixed = TRUE)), info = info)
  expect_true(any(grepl("^STATUS: REFUSE", out)), info = info)
  expect_true(any(grepl("^CODE: CFG_TEST_GUI_ORDER", out)), info = info)
  expect_true(any(grepl("^FIXTEXT: Set Outcome_Variable", out)), info = info)
  expect_true(any(grepl("^REFUSAL_CLASS: TRUE", out)), info = info)
})

test_that("a broken config file refuses cleanly in the GUI's source order", {
  skip_if(!file.exists(file.path(R.home("bin"), "Rscript")), "Rscript not found")
  skip_if_not_installed("openxlsx")

  # A workbook with a Settings sheet whose columns are not Setting/Value: the
  # loader's CFG_SETTINGS_STRUCTURE_INVALID path, which is what a user hits.
  bad_cfg <- tempfile("cd_bad_config_", fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings",
                      data.frame(Parameter = "Outcome_Variable", Setting = "Q1",
                                 stringsAsFactors = FALSE))
  openxlsx::addWorksheet(wb, "Variables")
  openxlsx::writeData(wb, "Variables",
                      data.frame(VariableName = "Q1", Type = "outcome", Label = "Q1",
                                 stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, bad_cfg, overwrite = TRUE)

  out <- .cd_run_in_gui_order(turas_root, c(
    sprintf('res <- with_refusal_handler(load_catdriver_config("%s"))', bad_cfg),
    'cat("STATUS:", res$run_status, "\\n")',
    'cat("CODE:", res$code, "\\n")',
    'cat("FIXNONEMPTY:", isTRUE(nzchar(res$how_to_fix)), "\\n")'
  ))
  unlink(bad_cfg)
  info <- paste(out, collapse = "\n")

  expect_false(any(grepl("BUG_INTERNAL_ERROR", out, fixed = TRUE)), info = info)
  expect_true(any(grepl("^STATUS: REFUSE", out)), info = info)
  expect_true(any(grepl("^CODE: CFG_", out)), info = info)
  expect_true(any(grepl("^FIXNONEMPTY: TRUE", out)), info = info)
})

test_that("the module defines catdriver_refuse exactly once", {
  r_dir <- file.path(turas_root, "modules", "catdriver", "R")
  hits <- unlist(lapply(list.files(r_dir, pattern = "\\.R$", full.names = TRUE), function(f) {
    grep("^catdriver_refuse <- function", readLines(f, warn = FALSE), value = FALSE)
  }))
  expect_equal(length(hits), 1L)
  expect_false(file.exists(file.path(r_dir, "00_guard.R")))
})
