# Tests for features removed by the V2 lift (review 2026-07-11, C2 and M1).
#
# LCA and ensemble were both config-exposed, documented, and unreachable: 767
# and 370 lines that no production path could call. A user who followed the
# README got ordinary k-means with no warning. The handover's locked decisions
# 3 and 4 amputate both rather than wire them up.
#
# The point of these tests is the SECOND half of that decision. Deleting the
# code without refusing the setting would leave exactly the bug being fixed: a
# knob that looks live and does nothing. A config that still asks for either
# must be told, not quietly given k-means.
#
# Refusals are conditions of class "turas_refusal" (see test_guards_hard.R).

.removed_features_config <- function(...) {
  base <- list(
    data_file = "stub.xlsx",
    id_variable = "respondent_id",
    clustering_vars = "v1,v2,v3",
    k_fixed = "3",
    method = "kmeans"
  )
  utils::modifyList(base, list(...))
}

test_that("a config that still asks for LCA is refused, not silently ignored (C2)", {
  expect_error(
    validate_segment_config(.removed_features_config(use_lca = "TRUE")),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_segment_config(.removed_features_config(use_lca = "TRUE")),
    turas_refusal = function(e) e
  )
  expect_true(grepl("LCA|latent class", conditionMessage(err), ignore.case = TRUE))
  expect_true(grepl("removed", conditionMessage(err), ignore.case = TRUE))
})

test_that("an LCA tuning setting on its own is refused too (C2)", {
  # A config carrying lca_n_classes without use_lca was still written by
  # someone who believed the feature existed.
  expect_error(
    validate_segment_config(.removed_features_config(lca_n_classes = "4")),
    class = "turas_refusal"
  )
})

test_that("use_lca = FALSE is not a refusal (C2)", {
  # An old template carrying the default must stay runnable. Whatever else
  # validation decides, it must not be stopped over a setting left at off.
  outcome <- tryCatch(
    validate_segment_config(.removed_features_config(use_lca = "FALSE")),
    turas_refusal = function(e) conditionMessage(e)
  )
  if (is.character(outcome)) {
    expect_false(grepl("latent class|use_lca", outcome, ignore.case = TRUE))
  } else {
    expect_true(is.list(outcome))
    expect_null(outcome$use_lca)
  }
})

test_that("a config that still asks for the ensemble method is refused by name (M1)", {
  err <- tryCatch(
    validate_segment_config(.removed_features_config(method = "ensemble")),
    turas_refusal = function(e) e
  )
  expect_s3_class(err, "turas_refusal")
  expect_true(grepl("ensemble", conditionMessage(err), ignore.case = TRUE))
  expect_true(grepl("removed", conditionMessage(err), ignore.case = TRUE))
})

test_that("the hard guard no longer advertises ensemble (M1)", {
  # Three layers disagreed: the parser refused ensemble, the guard allowed it
  # and named it in its own how-to-fix, and the dispatcher had no arm for it.
  expect_error(guard_require_valid_method("ensemble"), class = "turas_refusal")

  err <- tryCatch(guard_require_valid_method("spectral"), turas_refusal = function(e) e)
  expect_false(grepl("ensemble", conditionMessage(err), ignore.case = TRUE))
})

test_that("the LCA and ensemble implementations are gone from the module (C2, M1)", {
  expect_false(exists("run_lca", mode = "function"))
  expect_false(exists("compare_kmeans_lca", mode = "function"))
  expect_false(exists("run_ensemble_clustering", mode = "function"))

  r_dir <- file.path(Sys.getenv("TURAS_ROOT"), "modules", "segment", "R")
  expect_false(file.exists(file.path(r_dir, "11_lca.R")))
  expect_false(file.exists(file.path(r_dir, "14_ensemble.R")))
})

test_that("the generated template offers no LCA switch (C2)", {
  skip_if_not(exists("generate_segment_config_template", mode = "function"),
              "template generator not loaded")

  out <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out), add = TRUE)
  generate_segment_config_template(output_path = out)

  cfg <- openxlsx::read.xlsx(out, sheet = "Config", skipEmptyRows = FALSE)
  settings <- tolower(as.character(cfg[[1]]))
  expect_false(any(grepl("^use_lca$", settings)))
  expect_false(any(grepl("^lca_", settings)))
})
