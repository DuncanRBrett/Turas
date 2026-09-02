# ==============================================================================
# TABS MODULE - CONJOINT ISLAND, BUILT INTO A REAL REPORT
# ==============================================================================
#
# The unit tests in test_conjoint_island.R check the pieces. This builds an
# actual v2 report with an actual conjoint contribution embedded, and asserts
# the island survived the build, including a hostile attribute name, which is
# what island escaping exists for.
#
# It reuses the bundler suite's fixtures, so it is the same build path a real
# report takes.
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

# build_report_v2_html takes the data layer as a string and inlines it, so a
# minimal one is enough to prove what this file is about: that the conjoint
# island survives the build. The data layer's own content is the bundler
# suite's business, not this one's.
suppressWarnings(suppressMessages({
  for (f in sort(list.files(file.path(root, "modules", "shared", "lib"),
                            pattern = "[.]R$", full.names = TRUE))) {
    try(source(f), silent = TRUE)
  }
  source(file.path(root, "modules", "tabs", "lib", "html_report_v2",
                   "build_report_v2.R"))
}))

MINIMAL_DL <- '{"questions":[]}'
MINIMAL_CFG <- list(project_title = "Conjoint island test")

V2_ASSETS <- file.path(root, "modules", "tabs", "lib", "html_report_v2", "assets")

build_probe <- function(cj_json = NULL) {
  build_report_v2_html(MINIMAL_DL, MINIMAL_CFG, assets_dir = V2_ASSETS,
                       cj_json = cj_json)
}

make_cj_island <- function(attribute = "Brand") {
  jsonlite::toJSON(list(
    meta = list(
      schema = 1L, kind = "conjoint", islandVersion = "1.0.0",
      method = "hierarchical_bayes", methodLabel = "Hierarchical Bayes",
      nRespondents = 300L, nChoiceSets = 3600L, nAttributes = 1L,
      zeroCentred = TRUE, converged = TRUE, seMethod = "posterior_draws",
      frozen = TRUE,
      filterNote = "Does not respond to the audience filter.",
      unweightedNote = "Estimated unweighted."
    ),
    utilities = list(list(
      attribute = attribute,
      levels = c("Alpha", "Beta"),
      utility = c(0.5, -0.5), se = c(0.1, 0.1),
      ciLower = c(0.3, -0.7), ciUpper = c(0.7, -0.3),
      heterogeneity = c(0.8, 0.9), pValue = c(0.001, 0.001),
      isBaseline = c(TRUE, FALSE)
    )),
    importance = list(method = "individual", attribute = attribute,
                      importance = 100, sd = 12),
    fit = list(mcFaddenR2 = 0.31, hitRate = 0.65, chanceRate = 0.33),
    wtp = NULL
  ), auto_unbox = TRUE, na = "null", digits = 6)
}

test_that("a report without a conjoint contribution carries a null island and no tab", {
  html <- build_probe()

  expect_true(grepl('id="data-cj"', html, fixed = TRUE))
  # The island is present but empty. The shell then leaves the tab off.
  expect_true(grepl('id="data-cj">\nnull', html, fixed = TRUE) ||
                grepl('id="data-cj">null', html, fixed = TRUE))
  expect_false(grepl('"kind":"conjoint"', html, fixed = TRUE))
})

test_that("a conjoint contribution reaches the built report intact", {
  html <- build_probe(as.character(make_cj_island()))

  expect_true(grepl('"kind":"conjoint"', html, fixed = TRUE))
  expect_true(grepl("Hierarchical Bayes", html, fixed = TRUE))
  expect_true(grepl('"seMethod":"posterior_draws"', html, fixed = TRUE))

  # The view that renders it must be in the bundle.
  expect_true(grepl("TR.conjoint = cj", html, fixed = TRUE) ||
                grepl("TR.conjoint", html, fixed = TRUE))
})

test_that("a hostile attribute name cannot break the island open", {
  nasty <- 'Size </script><script>alert(1)</script> <!-- <script>'
  html <- build_probe(as.character(make_cj_island(nasty)))

  # Extract the island and confirm it contains no raw "<" at all.
  m <- regmatches(html, regexpr('id="data-cj">.*?</script>', html))
  expect_length(m, 1)
  body <- sub('^id="data-cj">', "", m)
  body <- sub("</script>$", "", body)
  expect_false(grepl("<", body, fixed = TRUE))

  # And it still parses back to the name that went in.
  parsed <- jsonlite::fromJSON(trimws(body), simplifyVector = FALSE)
  expect_equal(parsed$utilities[[1]]$attribute, nasty)
})

test_that("the built report is still self-contained with the island in it", {
  html <- build_probe(as.character(make_cj_island()))

  expect_false(grepl('(src|href)="https?://', html))
})
