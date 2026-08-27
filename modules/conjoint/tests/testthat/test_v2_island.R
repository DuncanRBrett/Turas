# ==============================================================================
# TESTS: V2 REPORT ISLAND SERIALISATION
# ==============================================================================
#
# The island is the contract between a conjoint run and the interactive
# report's Conjoint tab. What matters here is honesty at the edges: a block
# the run did not produce must be ABSENT from the JSON, not present as an
# empty object — jsonlite writes a NULL list element as {}, and {} is truthy
# in JavaScript, which rendered an HB run's Model fit panel as seven
# em-dashes (C-delta review, finding 2).
# ==============================================================================

make_island_results <- function(method = "hierarchical_bayes",
                                fit_statistics = NULL) {
  utilities <- data.frame(
    Attribute = c("Brand", "Brand", "Price", "Price"),
    Level = c("Alpha", "Beta", "$10", "$20"),
    Utility = c(-0.25, 0.25, 0.3, -0.3),
    Std_Error = c(NA, 0.1, NA, 0.1),
    CI_Lower = c(-0.25, 0.05, 0.3, -0.5),
    CI_Upper = c(-0.25, 0.45, 0.3, -0.1),
    is_baseline = c(TRUE, FALSE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  importance <- data.frame(Attribute = c("Brand", "Price"),
                           Importance = c(45.5, 54.5),
                           stringsAsFactors = FALSE)
  diagnostics <- if (is.null(fit_statistics)) list() else
    list(fit_statistics = fit_statistics)

  list(
    utilities = utilities,
    importance = importance,
    diagnostics = diagnostics,
    model_result = list(method = method, n_respondents = 200L),
    config = list(project_name = "Island test",
                  output_file = file.path(tempdir(), "island_test.xlsx"))
  )
}

test_that("an HB run's island carries no fit block at all - absent, not {}", {
  island <- serialize_conjoint_layer(make_island_results(), verbose = FALSE)

  expect_false("fit" %in% names(island))
  expect_false("wtp" %in% names(island))   # no wtp_result either

  # And the written JSON agrees: no "fit" key, so the view's truthiness
  # check cannot be fooled by an empty object.
  out <- tempfile(fileext = ".json")
  on.exit(unlink(out), add = TRUE)
  res <- write_conjoint_island(make_island_results(), output_file = out,
                               verbose = FALSE)
  expect_equal(res$status, "PASS")
  txt <- paste(readLines(out, warn = FALSE), collapse = "")
  expect_false(grepl('"fit"', txt, fixed = TRUE))
  expect_false(grepl("{}", txt, fixed = TRUE))
})

test_that("an MNL run's island carries its fit statistics, named for the view", {
  fit <- list(mcfadden_r2 = 0.31, hit_rate = 0.65, chance_rate = 1 / 3,
              log_likelihood_fitted = -284.7, log_likelihood_null = -438.6,
              n_obs = 1200L, n_parameters = 7L)
  island <- serialize_conjoint_layer(
    make_island_results(method = "mlogit", fit_statistics = fit),
    verbose = FALSE)

  expect_true("fit" %in% names(island))
  expect_equal(island$fit$mcFaddenR2, 0.31)
  expect_equal(island$fit$hitRate, 0.65)
  expect_equal(island$fit$nParameters, 7)
})
