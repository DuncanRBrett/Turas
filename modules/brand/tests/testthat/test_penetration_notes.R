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
    expect_false(grepl(intToUtf8(8212L),
                       paste(n$definition, n$label, pn$intro),
                       fixed = TRUE))
  }
  expect_match(pn$notes[[3]]$label, "P3M")
})

test_that("missing sources are simply omitted; nothing at all gives NULL", {
  cr <- .fake_cr(); cr$cat_buying_frequency <- list(status = "REFUSED")
  pn <- .brsum_penetration_notes(cr, .fake_results(), "Dressings")
  expect_equal(length(pn$notes), 2L)
  expect_null(.brsum_penetration_notes(list(), list(), "Nowhere"))
})

test_that("the How this works drawer carries the callout container", {
  # Stage 3 moved the "Which penetration is which" block out of the card
  # grid, where it was always open, into the collapsed "How this works"
  # drawer at the foot of the Overview. The container keeps its name, so
  # renderPenetrationNotes() in js/brand_summary_panel.js still finds it.
  html <- .brsum_howto_drawer()
  expect_true(grepl("data-brsum-pen-notes", html, fixed = TRUE))
  expect_false(grepl("data-brsum-pen-notes", .brsum_card_grid_skeleton(),
                     fixed = TRUE))

  # The drawer starts collapsed, and the toggle says so.
  expect_true(grepl('class="brsum-howto-body" hidden', html, fixed = TRUE))
  expect_true(grepl('aria-expanded="false"', html, fixed = TRUE))
  expect_true(grepl("brsumToggleHowTo(this)", html, fixed = TRUE))

  # One disclosure, not two: the methodology callout inside the drawer is
  # rendered expanded, so opening the drawer shows everything.
  if (exists("turas_callout", mode = "function")) {
    expect_false(grepl("t-callout collapsed", html, fixed = TRUE))
  }
})
