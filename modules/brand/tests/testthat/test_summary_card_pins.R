# ==============================================================================
# Tests for the per-card pin markup on the brand summary panel.
# Each card in .brsum_card_grid_skeleton() must:
#   - carry data-section="brsum-{key}" so brand_pins.js can find it
#   - render a <button class="br-pin-btn brsum-card-pin"> wired to brTogglePin
#   - mark the body with data-pin-as-table so capture grabs the body content
# ==============================================================================
library(testthat)

.find_root_brsum <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_brsum()

source(file.path(ROOT, "modules", "brand", "lib", "html_report", "panels",
                 "14_summary_panel.R"))


SUMMARY_CARD_KEYS <- c("hero", "mental", "funnel",
                       "working", "weak",
                       "conversation", "repertoire")
SUMMARY_CARD_COUNT <- length(SUMMARY_CARD_KEYS)


test_that("each summary card renders a unique data-section + pin button", {
  html <- .brsum_card_grid_skeleton()
  for (k in SUMMARY_CARD_KEYS) {
    expect_match(html,
      paste0('data-section="brsum-', k, '"'),
      fixed = TRUE,
      info = paste("section attribute missing for card", k))
    expect_match(html,
      paste0("brTogglePin\\('brsum-", k, "'\\)"),
      info = paste("brTogglePin call missing for card", k))
  }
})


test_that("each summary card body is marked data-pin-as-table for capture", {
  html <- .brsum_card_grid_skeleton()
  matches <- gregexpr("data-pin-as-table", html, fixed = TRUE)[[1]]
  hits <- if (length(matches) == 1L && matches[1] == -1L) 0L else length(matches)
  expect_identical(hits, SUMMARY_CARD_COUNT)
})


test_that("pin buttons carry the shared br-pin-btn class so brand_pins.js wires them", {
  html <- .brsum_card_grid_skeleton()
  matches <- gregexpr('class="br-pin-btn brsum-card-pin"', html, fixed = TRUE)[[1]]
  hits <- if (length(matches) == 1L && matches[1] == -1L) 0L else length(matches)
  expect_identical(hits, SUMMARY_CARD_COUNT)
})


test_that("section ids are unique across the card grid", {
  html <- .brsum_card_grid_skeleton()
  # data-section appears twice per card (once on <section>, once on the
  # <button>) — that's expected. Check unique values match the card count.
  ids <- regmatches(html, gregexpr('data-section="brsum-[^"]+"', html))[[1]]
  expect_identical(length(unique(ids)), SUMMARY_CARD_COUNT)
})


# ------------------------------------------------------------------------------
# Analyst commentary block — pinnable as its own section
# ------------------------------------------------------------------------------

test_that("analyst commentary renders a pin button + data-pin-as-table region", {
  html <- .brsum_insight_editor()
  expect_match(html, 'data-section="brsum-insight"', fixed = TRUE)
  expect_match(html, "brTogglePin\\('brsum-insight'\\)")
  expect_match(html, 'class="br-pin-btn brsum-card-pin"', fixed = TRUE)
  # The rendered markdown div carries data-pin-as-table so capture grabs
  # the formatted commentary, not the raw textarea.
  expect_match(html,
    'class="brsum-insight-rendered" id="brsum-insight-rendered" data-pin-as-table',
    fixed = TRUE)
})
