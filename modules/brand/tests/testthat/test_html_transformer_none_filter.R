# ==============================================================================
# Regression: the HTML data transformer must drop "None of the above"
# pseudo-brand rows so the rendered funnel / portfolio / cat-buying panels
# never carry a NONE row with em-dash cells.
# ==============================================================================
# The engine's get_brands_for_category() filters NONE. The HTML transformer
# reads structure$brands DIRECTLY (bypassing that helper) — so it has to
# repeat the filter. This test pins the duplication so the next refactor
# can't silently regress it.
# ==============================================================================

library(testthat)

.find_root_none <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_none()

source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "01_data_transformer.R"))


test_that(".dt_drop_none_brands removes canonical NONE rows", {
  tbl <- data.frame(
    BrandCode = c("IPK", "ROB", "NONE", "KNORR"),
    BrandLabel = c("Ina Paarman's", "Robertsons",
                    "None of the above", "Knorr"),
    stringsAsFactors = FALSE
  )
  out <- .dt_drop_none_brands(tbl)
  expect_identical(out$BrandCode, c("IPK", "ROB", "KNORR"))
})


test_that(".dt_drop_none_brands removes whitespace / case variants", {
  tbl <- data.frame(
    BrandCode = c("IPK", "none", "Nota", " NA ", "NoneOfTheAbove"),
    stringsAsFactors = FALSE
  )
  out <- .dt_drop_none_brands(tbl)
  expect_identical(out$BrandCode, "IPK")
})


test_that(".dt_drop_none_brands is a no-op when no NONE row present", {
  tbl <- data.frame(BrandCode = c("IPK", "ROB"), stringsAsFactors = FALSE)
  out <- .dt_drop_none_brands(tbl)
  expect_identical(out, tbl)
})


test_that(".dt_drop_none_brands preserves a real brand code that contains 'none'", {
  # Don't false-positive on legitimate brand codes that happen to spell
  # something containing 'none' inside a longer string.
  tbl <- data.frame(
    BrandCode = c("IPK", "NONESUCH", "ANONE"),  # neither matches the regex
    stringsAsFactors = FALSE
  )
  out <- .dt_drop_none_brands(tbl)
  expect_identical(out$BrandCode, c("IPK", "NONESUCH", "ANONE"))
})


test_that(".dt_drop_none_brands tolerates NULL / empty input", {
  expect_null(.dt_drop_none_brands(NULL))
  expect_identical(.dt_drop_none_brands(data.frame()), data.frame())
})


test_that(".dt_drop_none_brands tolerates a table without BrandCode column", {
  # CEPs / Attributes / DBA tables don't have BrandCode — must be untouched.
  tbl <- data.frame(CEPCode = c("CEP01", "CEP02"), stringsAsFactors = FALSE)
  out <- .dt_drop_none_brands(tbl)
  expect_identical(out, tbl)
})
