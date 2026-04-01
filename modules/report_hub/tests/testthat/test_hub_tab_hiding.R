# ==============================================================================
# Hub Tab Hiding Tests
# ==============================================================================
#
# Verifies that hub_navigation.js injects CSS to hide duplicate inner-report
# tabs (About, Pinned Views, Slides) when reports are embedded in the hub.
# ==============================================================================

library(testthat)

# Resolve hub_navigation.js path
turas_root <- Sys.getenv("TURAS_ROOT")
if (!nzchar(turas_root)) turas_root <- getwd()
nav_js_path <- file.path(turas_root, "modules", "report_hub", "js", "hub_navigation.js")
if (!file.exists(nav_js_path)) {
  turas_root <- normalizePath(file.path(getwd(), "..", "..", "..", ".."), mustWork = FALSE)
  nav_js_path <- file.path(turas_root, "modules", "report_hub", "js", "hub_navigation.js")
}

skip_if_no_nav <- function() {
  skip_if(!file.exists(nav_js_path), "hub_navigation.js not found")
}

nav_js <- if (file.exists(nav_js_path)) {
  paste(readLines(nav_js_path, warn = FALSE), collapse = "\n")
} else {
  ""
}

test_that("hub hides inner report About tabs", {
  skip_if_no_nav()
  expect_true(grepl("report-tab.*data-tab.*about", nav_js),
              info = "Missing CSS to hide .report-tab[data-tab='about']")
})

test_that("hub hides inner report Pinned Views tabs across all module patterns", {
  skip_if_no_nav()
  # Standard modules (tabs, tracker, segment, confidence, weighting)
  expect_true(grepl("report-tab.*data-tab.*pinned", nav_js),
              info = "Missing CSS for .report-tab[data-tab='pinned']")
  # Conjoint
  expect_true(grepl("cj-report-tab.*data-tab.*pinned", nav_js),
              info = "Missing CSS for .cj-report-tab[data-tab='pinned']")
  # Keydriver (uses non-standard data-kd-tab attribute)
  expect_true(grepl("kd-report-tab.*data-kd-tab.*pinned", nav_js),
              info = "Missing CSS for .kd-report-tab[data-kd-tab='pinned']")
  # Catdriver
  expect_true(grepl("cd-analysis-tab.*data-tab.*pinned", nav_js),
              info = "Missing CSS for .cd-analysis-tab[data-tab='pinned']")
})

test_that("hub hides inner report Slides/Qualitative tabs", {
  skip_if_no_nav()
  expect_true(grepl("data-tab.*qualitative", nav_js),
              info = "Missing CSS for qualitative tab hiding")
  expect_true(grepl("data-tab.*slides", nav_js),
              info = "Missing CSS for slides tab hiding")
})

test_that("hub hides inner report tab panels", {
  skip_if_no_nav()
  expect_true(grepl("#tab-pinned", nav_js, fixed = TRUE),
              info = "Missing CSS for #tab-pinned panel hiding")
  expect_true(grepl("#tab-about", nav_js, fixed = TRUE),
              info = "Missing CSS for #tab-about panel hiding")
})
