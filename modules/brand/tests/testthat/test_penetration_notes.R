# ==============================================================================
# TEST: "Which penetration is which" reconciliation block (review 2026-07-12,
# M7 and section 6). Built from engine results already in the payload.
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
  ROOT <<- find_root()
  source(file.path(ROOT, "modules", "brand", "lib", "html_report", "panels",
                   "14_summary_panel.R"), local = FALSE)
})

.fake_results <- function() {
  list(
    structure = list(brands = data.frame(
      Category = c("Dressings", "Dressings"), CategoryCode = c("DSS", "DSS"),
      BrandCode = c("A", "B"), BrandLabel = c("A", "B"), stringsAsFactors = FALSE)),
    results = list(portfolio_overview = list(categories = list(
      DSS = list(cat_usage_pct = 62.5, n_buyers_uw = 5L, total_n_uw = 8L)))))
}
.fake_cr <- function() list(
  cat_buying_frequency = list(status = "PASS", pct_buyers = 71.2, n_buyers = 57, n_respondents = 80),
  dirichlet_norms = list(status = "PASS",
                         category_metrics = list(penetration = 0.5625, n_buyers = 45L, n_respondents = 80L))
)

test_that("three penetration figures are listed with value, base and definition", {
  pn <- .brsum_penetration_notes(.fake_cr(), .fake_results(), "Dressings",
                                 config = list(target_timeframe_months = 3L))
  expect_false(is.null(pn))
  expect_equal(length(pn$notes), 3L)
  keys <- vapply(pn$notes, function(n) n$key, character(1))
  expect_equal(keys, c("cat_usage", "cat_buyers_freq", "cat_pen_purchase"))
  vals <- vapply(pn$notes, function(n) n$value, numeric(1))
  expect_equal(vals, c(62.5, 71.2, 56.2))
  expect_equal(pn$notes[[1]]$n, 5L); expect_equal(pn$notes[[1]]$base_n, 8L)
  expect_equal(pn$notes[[3]]$n, 45L); expect_equal(pn$notes[[3]]$base_n, 80L)
  for (n in pn$notes) {
    expect_true(nzchar(n$definition)); expect_true(nzchar(n$base))
    expect_false(grepl("—", paste(n$definition, n$label, pn$intro)))
  }
  expect_match(pn$notes[[3]]$label, "P3M")
})

test_that("missing sources are simply omitted; nothing at all gives NULL", {
  cr <- .fake_cr(); cr$cat_buying_frequency <- list(status = "REFUSED")
  pn <- .brsum_penetration_notes(cr, .fake_results(), "Dressings")
  expect_equal(length(pn$notes), 2L)
  expect_null(.brsum_penetration_notes(list(), list(), "Nowhere"))
})

test_that("the summary card grid carries the callout container", {
  html <- .brsum_card_grid_skeleton()
  expect_true(grepl("data-brsum-pen-notes", html, fixed = TRUE))
})
