# ==============================================================================
# Tests for build_br_subtab_nav() — the three-level IA sub-tab tiering
# (Phase 1, Slice 1). See docs/PHASE1_CLARITY_IMPLEMENTATION_PLAN.md.
#
# What's covered:
#   - Primary "category story" tabs are emitted first, in .BR_PRIMARY_SUBTABS
#     order, ahead of a "Detail" divider; appendix tabs follow, muted.
#   - No tab is dropped; every button keeps its switcher data-* attributes.
#   - Active-on-load is unchanged (still the funnel tab) — the load-state
#     safety guarantee.
#   - No-funnel categories fall back to the original untiered order.
#   - Empty / appendix-only / primary-only edge cases.
# ==============================================================================
library(testthat)

.find_root_snav <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_snav()
source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "03_page_builder.R"))

# --- helpers ----------------------------------------------------------------
mk <- function(key, label, subpanel, internal_tab = "") {
  list(key = key, label = label, subpanel = subpanel, internal_tab = internal_tab)
}

# A full per-category tab set in the order build_br_category_panel() builds it
# (funnel first, MA Metrics buried 6th, then rep/wom/appendix elements).
full_tabs <- function() list(
  mk("fn-funnel",       "Brand Funnel",          "fn",   "funnel"),
  mk("fn-relationship", "Brand Attitude",        "fn",   "relationship"),
  mk("ma-attributes",   "Brand Attributes",      "ma",   "attributes"),
  mk("ma-ceps",         "Category Entry Points", "ma",   "ceps"),
  mk("ma-advantage",    "Mental Advantage",      "ma",   "advantage"),
  mk("ma-metrics",      "MA Metrics",            "ma",   "metrics"),
  mk("rep",             "Category Buying",       "rep"),
  mk("wom",             "Word of Mouth",         "wom"),
  mk("branded_reach",   "Branded Reach",         "br"),
  mk("demographics",    "Demographics",          "demo"),
  mk("adhoc",           "Ad Hoc",                "ah"),
  mk("audience_lens",   "Audience Lens",         "al")
)

pos <- function(html, needle) regexpr(needle, html, fixed = TRUE)[[1]]
n_match <- function(html, needle) {
  m <- gregexpr(needle, html, fixed = TRUE)[[1]]
  if (length(m) == 1L && m[1L] == -1L) 0L else length(m)
}

# --- the taxonomy constant is the documented single source of truth ---------
test_that(".BR_PRIMARY_SUBTABS is the expected primary set", {
  expect_equal(.BR_PRIMARY_SUBTABS, c("fn-funnel", "ma-metrics", "rep", "wom"))
})

# --- core tiering behaviour --------------------------------------------------
test_that("primary tabs render first, in taxonomy order, before the Detail divider", {
  out <- build_br_subtab_nav(full_tabs(), "bak")

  sep <- pos(out, 'class="br-subtab-sep"')
  expect_true(sep > 0)                       # divider is present
  expect_true(grepl("br-subtab-grouplabel", out))

  # Every primary tab sits before the divider...
  for (k in .BR_PRIMARY_SUBTABS) {
    expect_true(pos(out, sprintf('data-subtab="%s"', k)) < sep,
                info = paste("primary before divider:", k))
  }
  # ...and primary tabs appear in .BR_PRIMARY_SUBTABS order (MA Metrics, which
  # was 6th in the input, is promoted to 2nd).
  expect_true(pos(out, 'data-subtab="fn-funnel"') <
              pos(out, 'data-subtab="ma-metrics"'))
  expect_true(pos(out, 'data-subtab="ma-metrics"') <
              pos(out, 'data-subtab="rep"'))
  expect_true(pos(out, 'data-subtab="rep"') <
              pos(out, 'data-subtab="wom"'))

  # Appendix tabs sit after the divider.
  for (k in c("fn-relationship", "ma-attributes", "ma-ceps", "ma-advantage",
              "branded_reach", "demographics", "adhoc", "audience_lens")) {
    expect_true(pos(out, sprintf('data-subtab="%s"', k)) > sep,
                info = paste("appendix after divider:", k))
  }
})

test_that("no tab is dropped and the switcher wiring is preserved", {
  tabs <- full_tabs()
  out  <- build_br_subtab_nav(tabs, "bak")
  expect_equal(n_match(out, 'data-subtab="'), length(tabs))          # all present
  expect_equal(n_match(out, 'onclick="switchCategorySubtab(this)"'),
               length(tabs))                                          # all wired
  expect_equal(n_match(out, 'data-group="bak"'), length(tabs))        # group tagged
})

test_that("active-on-load is unchanged — the funnel tab, exactly one active", {
  out <- build_br_subtab_nav(full_tabs(), "bak")
  expect_equal(n_match(out, 'class="br-subtab-btn active"'), 1L)
  expect_match(out,
    'class="br-subtab-btn active" data-group="bak" data-subtab="fn-funnel"',
    fixed = TRUE)
})

test_that("appendix tabs are flagged muted; primary tabs are not", {
  out <- build_br_subtab_nav(full_tabs(), "bak")
  # 8 appendix tabs in the full set (12 total − 4 primary).
  expect_equal(n_match(out, "br-subtab-btn--appendix"), 8L)
  # The appendix modifier never lands on a primary tab.
  for (k in .BR_PRIMARY_SUBTABS) {
    expect_false(grepl(
      sprintf('br-subtab-btn--appendix[^>]*data-subtab="%s"', k), out),
      info = k)
  }
})

test_that("data-subpanel and data-internal-tab survive the reorder", {
  out <- build_br_subtab_nav(full_tabs(), "bak")
  expect_match(out, 'data-subtab="ma-metrics" data-subpanel="ma" data-internal-tab="metrics"',
               fixed = TRUE)
  expect_match(out, 'data-subtab="fn-funnel" data-subpanel="fn" data-internal-tab="funnel"',
               fixed = TRUE)
})

# --- edge cases --------------------------------------------------------------
test_that("a category with no funnel falls back to the original order, untiered", {
  # First tab (ma-attributes) is not primary → no tiering, no divider.
  nofun <- list(
    mk("ma-attributes", "Brand Attributes",      "ma", "attributes"),
    mk("ma-ceps",       "Category Entry Points",  "ma", "ceps"),
    mk("ma-metrics",    "MA Metrics",             "ma", "metrics"),
    mk("rep",           "Category Buying",        "rep")
  )
  out <- build_br_subtab_nav(nofun, "pas")
  expect_false(grepl("br-subtab-sep", out))          # no divider
  expect_false(grepl("br-subtab-btn--appendix", out)) # nothing muted
  # original order preserved (ma-metrics stays after ma-ceps)
  expect_true(pos(out, 'data-subtab="ma-ceps"') <
              pos(out, 'data-subtab="ma-metrics"'))
  # first tab is the active one
  expect_match(out,
    'class="br-subtab-btn active" data-group="pas" data-subtab="ma-attributes"',
    fixed = TRUE)
})

test_that("primary-only set emits no divider", {
  prim <- list(
    mk("fn-funnel", "Brand Funnel",    "fn",  "funnel"),
    mk("ma-metrics", "MA Metrics",     "ma",  "metrics"),
    mk("rep",        "Category Buying", "rep"),
    mk("wom",        "Word of Mouth",   "wom")
  )
  out <- build_br_subtab_nav(prim, "dss")
  expect_false(grepl("br-subtab-sep", out))
  expect_equal(n_match(out, 'data-subtab="'), 4L)
  expect_equal(n_match(out, 'class="br-subtab-btn active"'), 1L)
})

test_that("empty tab list returns an empty string", {
  expect_identical(build_br_subtab_nav(list(), "bak"), "")
})
