# ==============================================================================
# TABS MODULE - CATDRIVER ISLAND, BUILT INTO A REAL REPORT
# ==============================================================================
#
# The catdriver module writes a frozen contribution (TR.CD); a tabs run embeds
# it when catdriver_island names the file. This builds an actual v2 report with
# an actual catdriver contribution in it and asserts the island survived the
# build, that the renderer travelled with it, that a report without one is
# exactly as it was, and that a hostile driver label cannot break the island
# open.
#
# It uses the same build path a real report takes.
# ==============================================================================

library(testthat)

detect_root <- function() {
  home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(home) && dir.exists(file.path(home, "modules"))) return(normalizePath(home))
  d <- normalizePath(getwd(), mustWork = FALSE)
  for (i in 1:8) {
    if (dir.exists(file.path(d, "modules", "tabs"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("cannot find the Turas root")
}
root <- detect_root()

suppressWarnings(suppressMessages({
  for (f in sort(list.files(file.path(root, "modules", "shared", "lib"),
                            pattern = "[.]R$", full.names = TRUE))) {
    try(source(f), silent = TRUE)
  }
  source(file.path(root, "modules", "tabs", "lib", "html_report_v2",
                   "build_report_v2.R"))
}))

MINIMAL_DL <- '{"questions":[]}'
MINIMAL_CFG <- list(project_title = "Catdriver island test")
V2_ASSETS <- file.path(root, "modules", "tabs", "lib", "html_report_v2", "assets")

build_probe <- function(cd_json = NULL) {
  build_report_v2_html(MINIMAL_DL, MINIMAL_CFG, assets_dir = V2_ASSETS,
                       cd_json = cd_json)
}

make_cd_island <- function(driver_label = "Service Quality") {
  jsonlite::toJSON(list(
    meta = list(
      schema_version = 1L, kind = "catdriver",
      analysis_name = "Demo: Customer Churn Analysis",
      outcome = list(var = "churn", label = "Customer Churn", type = "binary"),
      run_status = "PARTIAL",
      weighted = TRUE, weight_var = "survey_weight",
      n_drivers = 1L, has_odds_ratios = TRUE, has_lifts = FALSE,
      has_subgroups = FALSE, frozen = TRUE,
      filter_note = "Report filters do not apply here.",
      confidence_level = 0.95
    ),
    importance = list(
      method = "LR chi-square share (car::Anova type II on glm)",
      rows = list(list(driver = "service_quality", label = driver_label,
                       pct = 58.2, statistic = 91.4, df = 3L, rank = 1L,
                       effect = "Very Large"))
    ),
    odds_ratios = list(
      interval_kind = "wald", bootstrap = FALSE,
      rows = list(list(driver = "service_quality", label = driver_label,
                       level = "Excellent", reference = "Poor",
                       or = 11.36, lo = 5.2, hi = 24.8, p = 0.0000035))
    ),
    fit = list(engine = "glm", model_type = "binary_logistic",
               mcfadden_r2 = 0.1326, n = 456, n_original = 500, n_excluded = 44,
               n_eff = 409.3, converged = TRUE)
  ), auto_unbox = TRUE, na = "null", digits = 6)
}

test_that("a report without a catdriver contribution carries a null island and no tab", {
  html <- build_probe()

  expect_true(grepl('id="data-cd"', html, fixed = TRUE))
  expect_true(grepl('id="data-cd"[^>]*>\\s*null', html))
  expect_false(grepl('"kind":"catdriver"', html, fixed = TRUE))
  # and the renderer is left out of the bundle, which is what keeps a report
  # without a categorical driver study exactly the size it was
  expect_false(grepl("TR.catdriver = cd", html, fixed = TRUE))
})

test_that("a catdriver contribution reaches the built report intact", {
  html <- build_probe(as.character(make_cd_island()))

  expect_true(grepl('"kind":"catdriver"', html, fixed = TRUE))
  expect_true(grepl("LR chi-square share", html, fixed = TRUE))
  expect_true(grepl('"n_eff":409.3', html, fixed = TRUE))

  # The view that renders it must be in the bundle, or the shell refuses at
  # boot rather than showing an empty tab.
  expect_true(grepl("TR.catdriver", html, fixed = TRUE))
  expect_true(grepl("Categorical drivers", html, fixed = TRUE))
})

test_that("a hostile driver label cannot break the island open", {
  nasty <- 'Service </script><script>alert(1)</script> <!-- <script>'
  html <- build_probe(as.character(make_cd_island(nasty)))

  m <- regmatches(html, regexpr('id="data-cd"[^>]*>.*?</script>', html))
  expect_length(m, 1)
  body <- sub('^id="data-cd"[^>]*>', "", m)
  body <- sub("</script>$", "", body)
  expect_false(grepl("<", body, fixed = TRUE))
})

test_that("the island travels beside the others without disturbing them", {
  html <- build_probe(as.character(make_cd_island()))
  for (id in c("data-cj", "data-md", "data-pr", "data-kd", "data-qual")) {
    expect_true(grepl(sprintf('id="%s"', id), html, fixed = TRUE), info = id)
    expect_true(grepl(sprintf('id="%s"[^>]*>\\s*null', id), html), info = id)
  }
})
