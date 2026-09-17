# ==============================================================================
# MAXDIFF - THE SHIPPED KAROO EXAMPLE SAYS WHAT THE README SAYS IT SAYS
# ==============================================================================
# R3 of the v2 follow-up handover. Allow_Approx_Utilities_Export shipped YES.
# It is inert under Stan, where the export is stamped because the fit is
# genuine, but on a machine without cmdstanr it let approximate utilities
# through into a crosstab that cannot tell them from posterior estimates. The
# example now ships the refusal, and the README describes it.
#
# The workbook is a binary Duncan hand-edits in Excel. It is edited one cell at
# a time in Excel or openpyxl, never loadWorkbook() + save, which collapses
# every sheet's declared dimension to A1, and never by re-running
# create_maxdiff_example.R, which reverts his other edits.
# ==============================================================================

cfg_path <- file.path(TURAS_ROOT, "examples", "maxdiff", "Karoo_MaxDiff_Config.xlsx")

test_that("the shipped Karoo config refuses the approximate export by default", {
  skip_if(!file.exists(cfg_path), "shipped example config not found")
  os <- openxlsx::read.xlsx(cfg_path, sheet = "OUTPUT_SETTINGS", skipEmptyRows = FALSE)
  nc <- intersect(c("Option_Name", "Setting_Name", "Option"), names(os))[1]
  vc <- intersect(c("Value", "Setting_Value"), names(os))[1]
  row <- which(trimws(as.character(os[[nc]])) == "Allow_Approx_Utilities_Export")
  expect_length(row, 1)
  expect_equal(toupper(trimws(as.character(os[[vc]][row]))), "NO")
})

test_that("Duncan's other hand edits to the shipped config are intact", {
  skip_if(!file.exists(cfg_path), "shipped example config not found")
  os <- openxlsx::read.xlsx(cfg_path, sheet = "OUTPUT_SETTINGS", skipEmptyRows = FALSE)
  nc <- intersect(c("Option_Name", "Setting_Name", "Option"), names(os))[1]
  vc <- intersect(c("Value", "Setting_Value"), names(os))[1]
  get <- function(k) {
    r <- which(trimws(as.character(os[[nc]])) == k)
    if (length(r) != 1) return(NA_character_)
    toupper(trimws(as.character(os[[vc]][r])))
  }
  expect_equal(get("Generate_HTML_Report"), "YES")
  expect_equal(get("Generate_Charts"), "YES")
  expect_equal(get("Generate_Stats_Pack"), "YES")
})

test_that("no sheet's declared dimension collapsed when the cell was edited", {
  skip_if(!file.exists(cfg_path), "shipped example config not found")
  # A loadWorkbook() round trip rewrites every <dimension ref="..."> to "A1".
  # R still reads such a workbook; openpyxl tools do not.
  sheets <- openxlsx::getSheetNames(cfg_path)
  expect_true(all(c("PROJECT_SETTINGS", "ITEMS", "SURVEY_MAPPING",
                    "SEGMENT_SETTINGS", "OUTPUT_SETTINGS") %in% sheets))
  for (sn in sheets) {
    df <- openxlsx::read.xlsx(cfg_path, sheet = sn, skipEmptyRows = FALSE)
    expect_true(nrow(df) > 0, info = sn)
    expect_true(ncol(df) > 1, info = sn)
  }
})

test_that("the README describes the refusal, not the old permissive setting", {
  readme <- file.path(TURAS_ROOT, "examples", "maxdiff", "README.md")
  skip_if(!file.exists(readme), "example README not found")
  txt <- paste(readLines(readme, warn = FALSE), collapse = "\n")
  expect_match(txt, "Allow_Approx_Utilities_Export = NO", fixed = TRUE)
  expect_false(grepl("This example is configured for that\nworld", txt, fixed = TRUE))
})
