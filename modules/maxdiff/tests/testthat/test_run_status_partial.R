# ==============================================================================
# MAXDIFF - A SKIPPED OR REFUSED ANALYSIS IS PARTIAL, ON THE SHEET TOO
# ==============================================================================
# Pipeline runs (helper_pipeline_fixture.R) whose config asks for something
# the run cannot deliver. The Run_Status sheet in the workbook the client
# opens must say PARTIAL and name the event, the same as the status the run
# returns. None of these runs samples Stan.
# ==============================================================================

source(file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "testthat",
                 "helper_pipeline_fixture.R"), local = TRUE)

.run_status_sheet <- function(path) {
  x <- openxlsx::read.xlsx(path, sheet = "Run_Status", colNames = FALSE,
                           skipEmptyRows = FALSE)
  cells <- as.character(unlist(x))
  status_row <- which(x[[1]] == "Status")
  list(status = if (length(status_row)) x[[2]][status_row[1]] else NA_character_,
       text = paste(cells[!is.na(cells)], collapse = "\n"))
}

# HB off, so there are no individual utilities, while the tabs export and
# TURF are on (the example config turns both on).
PN <- md_pipe_run(n = 60, weighted = FALSE,
                  output_settings = c(Generate_HB_Model = "NO"))

test_that("a refused tabs export makes the Run_Status sheet PARTIAL, not only the banner", {
  expect_true(file.exists(PN$workbook), info = paste(tail(PN$log, 30), collapse = "\n"))
  expect_equal(PN$status, "PARTIAL")
  sheet <- .run_status_sheet(PN$workbook)
  expect_equal(sheet$status, "PARTIAL")
  expect_match(sheet$text, "MODEL_NO_RESPONDENT_UTILITIES", fixed = TRUE)
  # The sheet is replaced in the workbook still in memory and saved again:
  # nothing else in the workbook moves.
  sheets <- openxlsx::getSheetNames(PN$workbook)
  expect_true(all(c("SUMMARY", "ITEM_SCORES", "SEGMENT_SCORES") %in% sheets))
  expect_equal(tail(sheets, 1), "Run_Status")
  expect_equal(sum(sheets == "Run_Status"), 1L)
  sc <- md_pipe_sheet(PN$workbook, "ITEM_SCORES")
  expect_true(all(is.finite(sc$Logit_Utility[!is.na(sc$Item_ID)])))
})
