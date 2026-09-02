# ==============================================================================
# TABS MODULE - MAXDIFF ISLAND, BUILT INTO A REAL REPORT
# ==============================================================================
#
# The unit tests in test_maxdiff_island.R check the pieces. This builds an
# actual v2 report with an actual MaxDiff contribution embedded, and asserts
# the island survived the build, including a hostile item label, which is
# what island escaping exists for. Same shape as test_conjoint_island_e2e.R.
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
MINIMAL_CFG <- list(project_title = "MaxDiff island test")
V2_ASSETS <- file.path(root, "modules", "tabs", "lib", "html_report_v2", "assets")

build_probe <- function(md_json = NULL, cj_json = NULL) {
  build_report_v2_html(MINIMAL_DL, MINIMAL_CFG, assets_dir = V2_ASSETS,
                       cj_json = cj_json, md_json = md_json)
}

make_md_island <- function(label = "Free delivery") {
  jsonlite::toJSON(list(
    meta = list(
      schema = 1L, kind = "maxdiff", islandVersion = "1.0.0",
      method = "empirical_bayes", methodLabel = "Empirical Bayes fallback (count-based)",
      estimationNote = "Not Bayesian posterior estimates.",
      nRespondents = 300L, nTasks = 8L, itemsPerTask = 4L, nItems = 2L,
      weighted = FALSE, weightingNote = "Unweighted.", frozen = TRUE,
      filterNote = "Does not respond to the audience filter."
    ),
    scores = list(
      itemId = c("A", "B"), label = c(label, "Gift wrap"),
      bestPct = c(50, 5), worstPct = c(5, 62.5), netScore = c(45, -57.5),
      hbUtility = c(1.2, -1.3), hbSpread = c(0.4, 0.6), share = c(80, 20),
      rescaled = c(100, 0), rescaleMethod = "0_100"
    )
  ), auto_unbox = TRUE, na = "null", digits = 6)
}

test_that("a report without a MaxDiff contribution carries a null island and no tab", {
  html <- build_probe()
  expect_true(grepl('id="data-md"', html, fixed = TRUE))
  expect_true(grepl('id="data-md">\nnull', html, fixed = TRUE) ||
                grepl('id="data-md">null', html, fixed = TRUE))
  expect_false(grepl('"kind":"maxdiff"', html, fixed = TRUE))
})

test_that("a MaxDiff contribution reaches the built report intact", {
  html <- build_probe(md_json = as.character(make_md_island()))
  expect_true(grepl('"kind":"maxdiff"', html, fixed = TRUE))
  expect_true(grepl("Empirical Bayes fallback", html, fixed = TRUE))
  # The view that renders it must be in the bundle.
  expect_true(grepl("TR.maxdiff = {}", html, fixed = TRUE))
})

test_that("conjoint and MaxDiff contributions coexist in one report", {
  cj <- jsonlite::toJSON(list(
    meta = list(schema = 1L, kind = "conjoint", method = "hierarchical_bayes",
                methodLabel = "Hierarchical Bayes", frozen = TRUE),
    utilities = list(list(attribute = "Brand", levels = c("A", "B"),
                          utility = c(0.5, -0.5), isBaseline = c(TRUE, FALSE)))
  ), auto_unbox = TRUE, na = "null")
  html <- build_probe(md_json = as.character(make_md_island()), cj_json = as.character(cj))
  expect_true(grepl('"kind":"maxdiff"', html, fixed = TRUE))
  expect_true(grepl('"kind":"conjoint"', html, fixed = TRUE))
})

test_that("a hostile item label cannot break the island open", {
  nasty <- 'Loyalty </script><script>alert(1)</script> <!-- <script>'
  html <- build_probe(md_json = as.character(make_md_island(nasty)))

  m <- regmatches(html, regexpr('id="data-md">.*?</script>', html))
  expect_length(m, 1)
  body <- sub('^id="data-md">', "", m)
  body <- sub("</script>$", "", body)
  expect_false(grepl("<", body, fixed = TRUE))

  parsed <- jsonlite::fromJSON(trimws(body), simplifyVector = FALSE)
  expect_equal(parsed$scores$label[[1]], nasty)
})

test_that("the built report is still self-contained with the island in it", {
  html <- build_probe(md_json = as.character(make_md_island()))
  expect_false(grepl('(src|href)="https?://', html))
})
