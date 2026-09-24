# ==============================================================================
# POPULATION_MARGINS SHEET LOADS AS NUMBERS
# ==============================================================================
# auto_detect_header_read() reads every sheet as text. The margins loader
# converted Target_Prop one cell at a time back INTO that text column, so it
# stayed "0.45", tapply(sum) failed, and any config with a Population_Margins
# sheet refused the whole run at CFG_LOAD_FAILED ("invalid 'type'
# (character)"). Found by the pipeline gate, 24 Sep 2026; no test loaded the
# sheet from a workbook before.
# ==============================================================================

library(testthat)

test_that("Population_Margins Target_Prop loads as numbers and feeds the margin check", {
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path), add = TRUE)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Population_Margins")
  openxlsx::writeData(wb, "Population_Margins", data.frame(
    Variable = "region", Category_Label = c("North", "South"),
    Category_Code = c(1, 2), Target_Prop = c(0.45, 0.55)))
  turas_saveWorkbook(wb, path, overwrite = TRUE)

  pm <- load_population_margins_sheet(path)
  expect_true(is.numeric(pm$Target_Prop))
  expect_equal(pm$Target_Prop, c(0.45, 0.55))
  expect_equal(pm$Category_Code, c("1", "2"))

  d <- data.frame(region = c(1, 1, 2, 2), w = c(1, 1, 1, 1))
  mc <- compute_margin_comparison(d, d$w, pm)
  mc <- mc[order(mc$Category_Code), ]
  # 50% each against 45% and 55%: +5pp and -5pp, both RED
  expect_equal(mc$Diff_pp, c(5, -5), tolerance = 1e-9)
  expect_equal(mc$Flag, c("RED", "RED"))
})
