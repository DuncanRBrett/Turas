# ==============================================================================
# TEST: GUI verdict + ingestion helpers in R/00_guard.R
# (review 2026-07-12: H5 PARTIAL surfaced, M2 generator refusals not
#  reported as success, M8 weights coerced or refused)
# ==============================================================================
library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  source(file.path(find_root(), "modules", "brand", "R", "00_guard.R"), local = FALSE)
})

.ok_gen <- list(status = "PASS")
.write_tmp <- function(ext) { f <- tempfile(fileext = ext); writeLines("x", f); f }

test_that("a clean run with both reports written is success", {
  h <- .write_tmp(".html"); x <- .write_tmp(".xlsx")
  out <- brand_gui_outcome(list(status = "PASS", warnings = character(0)),
                           .ok_gen, .ok_gen, h, x)
  expect_equal(out$level, "success")
  expect_true(out$success)
  expect_equal(out$html_path, h)
  expect_equal(out$xlsx_path, x)
  expect_length(out$warnings, 0L)
  expect_match(out$headline, "successfully")
})

test_that("a PARTIAL engine run is never announced as success (H5)", {
  h <- .write_tmp(".html"); x <- .write_tmp(".xlsx")
  res <- list(status = "PARTIAL",
              warnings = "Role map build failed: no Questions sheet. v2 elements will skip")
  out <- brand_gui_outcome(res, .ok_gen, .ok_gen, h, x)
  expect_equal(out$level, "partial")
  expect_true(out$success)
  expect_false(grepl("successfully", out$headline))
  expect_match(out$headline, "1 warning")
  expect_true(any(grepl("Role map build failed", out$warnings)))
})

test_that("an HTML generator refusal is reported as a problem, not success (M2)", {
  x <- .write_tmp(".xlsx")
  html_ref <- list(status = "REFUSED", code = "IO_HTML_WRITE_FAILED",
                   message = "cannot open output folder")
  out <- brand_gui_outcome(list(status = "PASS", warnings = character(0)),
                           html_ref, .ok_gen, tempfile(fileext = ".html"), x)
  expect_equal(out$level, "partial")
  expect_null(out$html_path)
  expect_equal(out$xlsx_path, x)
  expect_match(out$headline, "HTML report was not written")
  expect_true(any(grepl("cannot open output folder", out$warnings)))
})

test_that("a PASS generator whose file is missing is still a problem", {
  out <- brand_gui_outcome(list(status = "PASS"), .ok_gen, .ok_gen,
                           tempfile(fileext = ".html"), tempfile(fileext = ".xlsx"))
  expect_equal(out$level, "partial")
  expect_null(out$html_path); expect_null(out$xlsx_path)
  expect_length(out$warnings, 2L)
})

test_that("a PASS generator that dropped a layer is reported, not announced as success", {
  h <- .write_tmp(".html"); x <- .write_tmp(".xlsx")
  html_ok_with_note <- list(status = "PASS",
                            warnings = "chart layer dropped, transform failed: missing value where TRUE/FALSE needed")
  out <- brand_gui_outcome(list(status = "PASS", warnings = character(0)),
                           html_ok_with_note, .ok_gen, h, x)
  expect_equal(out$level, "partial")
  expect_equal(out$html_path, h)                 # the file was written ...
  expect_true(any(grepl("chart layer dropped", out$warnings)))   # ... but the reader is told
  expect_false(grepl("successfully", out$headline))
})

test_that("an engine refusal is an error verdict", {
  out <- brand_gui_outcome(list(status = "REFUSED", message = "CFG bad"))
  expect_equal(out$level, "error")
  expect_false(out$success)
  expect_match(out$headline, "CFG bad")
})

test_that(".brand_coerce_weights coerces text numbers and refuses junk", {
  ok <- .brand_coerce_weights(c("1.5", "2", "0.7"), "WT")
  expect_null(ok$status)
  expect_equal(ok$weights, c(1.5, 2, 0.7))
  num <- .brand_coerce_weights(c(0.8, 1.2), "WT")
  expect_equal(num$weights, c(0.8, 1.2))
  bad <- .brand_coerce_weights(c("1", "n/a", "two"), "WT")
  expect_equal(bad$status, "REFUSED")
  expect_equal(bad$code, "DATA_WEIGHT_NOT_NUMERIC")
  expect_match(bad$message, "2 non-numeric")
  expect_match(bad$message, "n/a")
})

test_that(".brand_coerce_weights refuses blank weight cells and names the rows", {
  # Duncan's ruling (2026-09-06, review F3): a weight column with a hole in
  # it is a data problem, so no numbers come out until it is fixed. This
  # replaces the earlier zero-fill plus PARTIAL warning.
  blank <- .brand_coerce_weights(c("1.5", "2", NA, ""), "WT")
  expect_equal(blank$status, "REFUSED")
  expect_equal(blank$code, "DATA_WEIGHT_BLANK")
  expect_match(blank$message, "2 blank cell", fixed = TRUE)
  expect_match(blank$message, "rows 3, 4", fixed = TRUE)
  expect_match(blank$how_to_fix, "weight_variable", fixed = TRUE)

  # An all-blank column is refused on the same code. Zero-filling it would
  # give every respondent weight 0 and every weighted number a base of 0.
  all_blank <- .brand_coerce_weights(c(NA, NA, NA), "WT")
  expect_equal(all_blank$status, "REFUSED")
  expect_equal(all_blank$code, "DATA_WEIGHT_BLANK")
  expect_match(all_blank$message, "3 blank cell", fixed = TRUE)

  # More than ten blanks are truncated in the message, not dumped.
  many <- .brand_coerce_weights(c(rep(NA_real_, 12), 1, 2), "WT")
  expect_equal(many$status, "REFUSED")
  expect_match(many$message, ", ...", fixed = TRUE)
})

test_that(".brand_as_refusal normalises both refusal shapes and ignores results", {
  trs <- structure(list(run_status = "REFUSE", refused = TRUE, code = "DATA_X",
                        problem = "bad", how_to_fix = "fix it",
                        message = "long text"),
                   class = "turas_refusal_result")
  r <- .brand_as_refusal(trs)
  expect_equal(r$status, "REFUSED"); expect_equal(r$code, "DATA_X")
  expect_equal(r$how_to_fix, "fix it")
  plain <- .brand_as_refusal(list(status = "REFUSED", code = "CFG_Y", message = "m"))
  expect_equal(plain$code, "CFG_Y")
  expect_null(.brand_as_refusal(list(status = "PASS")))
  expect_null(.brand_as_refusal(TRUE))
  expect_null(.brand_as_refusal(NULL))
})
