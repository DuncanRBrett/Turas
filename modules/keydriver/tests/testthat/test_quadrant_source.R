# ==============================================================================
# KEYDRIVER - QUADRANT IMPORTANCE SOURCE (review H11 / M2)
# ==============================================================================
# The template's dropdown offered "shapley", "relative" and "beta". The engine's
# switch handles "shap", "relative_weights", "regression", "correlation" and
# "auto". So three of the five values an analyst could pick fell through to the
# default branch and the chart was built from whatever "auto" chose, with
# nothing saying so.
# ==============================================================================

skip_if_not(file.exists(file.path(module_dir, "R", "kda_quadrant", "quadrant_data_prep.R")),
            "quadrant prep not present")
suppressWarnings(try(source(file.path(module_dir, "R", "kda_quadrant", "quadrant_data_prep.R")),
                     silent = TRUE))
skip_if(!exists("extract_importance_scores", mode = "function"), "quadrant prep not loaded")

quad_results <- function(...) {
  extra <- list(...)
  imp <- data.frame(
    Driver = c("A", "B", "C"),
    Correlation = c(0.6, 0.4, 0.2),
    Beta_Weight = c(0.5, 0.3, 0.1),
    Relative_Weight = c(50, 30, 20),
    Shapley_Value = c(0.30, 0.18, 0.12),
    stringsAsFactors = FALSE
  )
  for (nm in names(extra)) imp[[nm]] <- extra[[nm]]
  list(importance = imp)
}

test_that("one canonical list of sources exists (H11)", {
  expect_true(exists("KD_QUADRANT_IMPORTANCE_SOURCES"))
  expect_equal(KD_QUADRANT_IMPORTANCE_SOURCES,
               c("auto", "shap", "relative_weights", "regression", "correlation"))
  # The values the old template offered are not in it, deliberately.
  expect_false("shapley" %in% KD_QUADRANT_IMPORTANCE_SOURCES)
  expect_false("relative" %in% KD_QUADRANT_IMPORTANCE_SOURCES)
  expect_false("beta" %in% KD_QUADRANT_IMPORTANCE_SOURCES)
})

test_that("an unrecognised source refuses and names the valid set (H11)", {
  err <- tryCatch({
    extract_importance_scores(quad_results(), list(importance_source = "shapley"))
    "NO REFUSAL"
  }, error = function(e) conditionMessage(e))
  expect_match(err, "CFG_QUADRANT_IMPORTANCE_SOURCE")
  expect_match(err, "relative_weights")
  # And it tells the analyst what the old dropdown values became.
  expect_match(err, "Older templates")
})

test_that("each recognised source picks its own column (H11)", {
  by_corr <- extract_importance_scores(quad_results(), list(importance_source = "correlation"))
  by_beta <- extract_importance_scores(quad_results(), list(importance_source = "regression"))
  by_rw <- extract_importance_scores(quad_results(), list(importance_source = "relative_weights"))
  # Three different measures must not produce one identical answer, which is
  # what falling through to auto did.
  expect_false(isTRUE(all.equal(by_corr$importance, by_beta$importance)))
  expect_equal(attr(by_rw, "importance_source_requested"), "relative_weights")
  expect_equal(attr(by_rw, "importance_source_used"), "relative_weights")
})

test_that("shap means TreeSHAP, and says so when it had to use something else (H11)", {
  # SHAP_Importance is the TreeSHAP output; Shapley_Value is the regression
  # decomposition. Asking for shap used to take Shapley_Value first.
  with_shap <- extract_importance_scores(
    quad_results(SHAP_Importance = c(10, 60, 30)),
    list(importance_source = "shap"))
  expect_equal(attr(with_shap, "importance_source_used"), "shap")
  # The TreeSHAP ranking, not the Shapley one.
  expect_equal(which.max(with_shap$importance), 2)

  # No TreeSHAP column: it falls back, and records that it did.
  without <- extract_importance_scores(quad_results(), list(importance_source = "shap"))
  expect_equal(attr(without, "importance_source_requested"), "shap")
  expect_match(attr(without, "importance_source_used"), "shapley_value")
  expect_match(attr(without, "importance_source_used"), "not in the results")
})

test_that("the template dropdown and the engine agree (H11)", {
  tmpl <- file.path(module_dir, "lib", "generate_config_templates.R")
  skip_if_not(file.exists(tmpl), "template generator not present")
  src <- paste(readLines(tmpl, warn = FALSE), collapse = "\n")
  expect_true(grepl('dropdown = c("auto", "shap", "relative_weights", "regression", "correlation")',
                    src, fixed = TRUE))
  expect_false(grepl('"shapley", "relative", "beta"', src, fixed = TRUE))
})
