# ==============================================================================
# TESTS: delivery manifest (modules/tabs/lib/delivery_manifest.R)
# ==============================================================================
# The manifest is the thing that stops a build shipping quietly. These tests hold
# it to that: it must always say whether respondent records are in the file, and
# it must never claim a protection the build is not applying.
# ==============================================================================

if (!exists("tabs_delivery_manifest", mode = "function")) {
  source(file.path(rprojroot::find_root(rprojroot::has_dir(".git")),
                   "modules", "tabs", "lib", "delivery_manifest.R"))
}

micro_fixture <- function(n = 600) {
  list(n = n, answers = list(Q1 = rep(0L, n)), weights = rep(1, n))
}

joined <- function(m) paste(m$lines, collapse = "\n")


test_that("a build carrying microdata says so, with the count", {
  m <- tabs_delivery_manifest(micro_fixture(600), NULL, list())
  expect_true(m$microdata)
  expect_true(m$restricted)
  expect_equal(m$n, 600L)
  expect_match(joined(m), "Respondent-level records\\s*: YES \\(600 respondents\\)")
  expect_match(joined(m), "Row-level weights\\s*: YES")
  expect_match(joined(m), "turned back into a respondent-level dataset")
  expect_match(joined(m), "html_report_v2_microdata = FALSE")
})


test_that("the confidentiality ship says so, and makes no restricted claim", {
  m <- tabs_delivery_manifest(NULL, NULL, list())
  expect_false(m$microdata)
  expect_false(m$restricted)
  expect_true(is.na(m$n))
  expect_match(joined(m), "Respondent-level records\\s*: NO")
  expect_match(joined(m), "Row-level weights\\s*: NO")
  expect_match(joined(m), "published figures only")
  # The warning paragraph belongs only to a build that earns it.
  expect_false(grepl("turned back into a respondent-level dataset", joined(m)))
})


test_that("min_reporting_base is reported, and its on-screen-only limit is named", {
  m_set <- tabs_delivery_manifest(micro_fixture(), NULL, list(min_reporting_base = 5))
  expect_match(joined(m_set), "Minimum reporting base\\s*: 5")
  expect_match(joined(m_set), "hides sub-k cells ON SCREEN")

  m_unset <- tabs_delivery_manifest(micro_fixture(), NULL, list())
  expect_match(joined(m_unset), "Minimum reporting base\\s*: not set")
  expect_false(grepl("ON SCREEN", joined(m_unset)))

  # k = 1 is off, not a threshold of one.
  m_one <- tabs_delivery_manifest(NULL, NULL, list(min_reporting_base = 1))
  expect_match(joined(m_one), "Minimum reporting base\\s*: not set")
})


test_that("a build with no comment tab makes no claim about verbatims", {
  for (empty in list(NULL, "", "null")) {
    m <- tabs_delivery_manifest(NULL, empty, list(qual_confidentiality_mode = "full"))
    expect_match(joined(m), "no comment tab in this build")
    expect_match(joined(m), "Comment demographic tags\\s*: not applicable")
  }
})


test_that("each verbatim confidentiality mode is described as what it does", {
  q <- '{"questions":[]}'
  expect_match(joined(tabs_delivery_manifest(NULL, q, list(qual_confidentiality_mode = "full"))),
               "FULL text in the file")
  expect_match(joined(tabs_delivery_manifest(NULL, q, list(qual_confidentiality_mode = "redacted"))),
               "direct identifiers scrubbed")
  expect_match(joined(tabs_delivery_manifest(NULL, q, list(qual_confidentiality_mode = "hidden"))),
               "no text in the file")
  # Unset defaults to hidden, matching qual_island_builder.R.
  expect_match(joined(tabs_delivery_manifest(NULL, q, list())), "no text in the file")
})


test_that("demographic tags: 'safe' without a k is reported as raw, not as safe", {
  q <- '{"questions":[]}'
  # This mirrors the engine: qual_island_builder downgrades 'safe' to 'allow'
  # when min_reporting_base is unset, because there is nothing to anonymise
  # against. The manifest must not print a protection the build is not applying.
  m_bad <- tabs_delivery_manifest(NULL, q, list(qual_demographic_cuts = "safe"))
  expect_match(joined(m_bad), "declared safe but k is unset")

  m_good <- tabs_delivery_manifest(NULL, q, list(qual_demographic_cuts = "safe",
                                                 min_reporting_base = 10))
  expect_match(joined(m_good), "k-anonymised against k=10")

  m_block <- tabs_delivery_manifest(NULL, q, list(qual_demographic_cuts = "block"))
  expect_match(joined(m_block), "comments carry no demographics")

  m_allow <- tabs_delivery_manifest(NULL, q, list(qual_demographic_cuts = "allow"))
  expect_match(joined(m_allow), "every tag ships")
})


test_that("the manifest never claims direct identifiers are absent by accident", {
  # It is a fixed statement of what the island format is, and it must hold for
  # both ships, because it is the one reassuring line a client may be shown.
  expect_match(joined(tabs_delivery_manifest(micro_fixture(), NULL, list())),
               "indices only, never IDs or raw text")
})


test_that("the file name is carried when known, and omitted when not", {
  m <- tabs_delivery_manifest(NULL, NULL, list(), "/a/b/SACS_Crosstabs_report.html")
  expect_match(joined(m), "File: SACS_Crosstabs_report.html", fixed = TRUE)
  expect_false(grepl("File:", joined(tabs_delivery_manifest(NULL, NULL, list()))))
})


test_that("a NULL config and a missing n do not break the manifest", {
  expect_silent(m <- tabs_delivery_manifest(NULL, NULL, NULL))
  expect_match(joined(m), "Respondent-level records\\s*: NO")
  m2 <- tabs_delivery_manifest(list(answers = list()), NULL, NULL)
  expect_true(m2$microdata)
  expect_match(joined(m2), "count unknown")
  expect_match(joined(m2), "Row-level weights\\s*: NO")
})


test_that("the printer emits the lines and returns the manifest invisibly", {
  out <- capture.output(res <- tabs_print_delivery_manifest(micro_fixture(12), NULL, list()))
  expect_true(any(grepl("TURAS DELIVERY MANIFEST", out)))
  expect_true(any(grepl("YES \\(12 respondents\\)", out)))
  expect_true(res$microdata)
})


# -- tabs_microdata_wanted(): the GUI's client-safe choice decides the build ---

test_that("microdata is wanted by default, with no reason recorded", {
  d <- tabs_microdata_wanted(list(html_report_v2_microdata = TRUE), client_safe = FALSE)
  expect_true(d$wanted)
  expect_true(is.na(d$reason))
  d <- tabs_microdata_wanted(list(), client_safe = FALSE)
  expect_true(d$wanted)
})

test_that("the config switch turns the island off and says so", {
  d <- tabs_microdata_wanted(list(html_report_v2_microdata = FALSE), client_safe = FALSE)
  expect_false(d$wanted)
  expect_identical(d$reason, "config")
})

test_that("the GUI client-safe choice turns the island off even when the config says TRUE", {
  d <- tabs_microdata_wanted(list(html_report_v2_microdata = TRUE), client_safe = TRUE)
  expect_false(d$wanted)
  expect_identical(d$reason, "gui")
})

test_that("both switches off reports the config, the earlier decision", {
  d <- tabs_microdata_wanted(list(html_report_v2_microdata = FALSE), client_safe = TRUE)
  expect_false(d$wanted)
  expect_identical(d$reason, "config")
})

test_that("the default client_safe argument reads the GUI global and is FALSE when unset", {
  if (exists("TURAS_DELIVERY_CLIENT_SAFE", envir = .GlobalEnv)) {
    rm("TURAS_DELIVERY_CLIENT_SAFE", envir = .GlobalEnv)
  }
  expect_true(tabs_microdata_wanted(list(html_report_v2_microdata = TRUE))$wanted)
  assign("TURAS_DELIVERY_CLIENT_SAFE", TRUE, envir = .GlobalEnv)
  on.exit(rm("TURAS_DELIVERY_CLIENT_SAFE", envir = .GlobalEnv), add = TRUE)
  expect_false(tabs_microdata_wanted(list(html_report_v2_microdata = TRUE))$wanted)
})
