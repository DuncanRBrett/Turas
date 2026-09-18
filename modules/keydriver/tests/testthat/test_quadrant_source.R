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
# Loaded rather than skipped: a file-level skip makes this file report
# 0 tests under test_file, which reads as success (review F17).
kd_ensure_module_loaded("quadrant")
expect_true(exists("extract_importance_scores", mode = "function"))

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


# ==============================================================================
# WHAT "auto" RESOLVES TO (review F26)
# ==============================================================================
# Closed as working as intended, and documented. "auto" is the Shapley
# decomposition, always, even when SHAP has run. That is deliberate: the
# importance table on the same tab is ranked by Shapley, so a quadrant built on
# SHAP would disagree with the table beside it about which driver is biggest,
# with nothing on the page saying why.
#
# The defect F26 actually found was in the docs, which said "Uses SHAP if
# enabled, otherwise Shapley". The code has never done that. These tests bind
# the two together so they cannot drift apart again.

test_that("auto resolves to Shapley even when SHAP importance is present (F26)", {
  skip_if(!exists("select_best_importance", mode = "function"),
          "quadrant prep not loaded")
  imp <- data.frame(
    Driver          = c("a", "b"),
    Shapley_Value   = c(60, 40),
    SHAP_Importance = c(30, 70),   # deliberately the opposite order
    stringsAsFactors = FALSE)

  out <- suppressWarnings(utils::capture.output(res <- select_best_importance(imp)))
  expect_equal(res$importance, c(60, 40))
  expect_equal(res$driver[which.max(res$importance)], "a")
  # And it says which one it used, rather than choosing in silence.
  expect_true(any(grepl("Shapley", out, fixed = TRUE)))
})

test_that("auto falls through to SHAP only when Shapley is absent (F26)", {
  skip_if(!exists("select_best_importance", mode = "function"),
          "quadrant prep not loaded")
  imp <- data.frame(Driver = c("a", "b"), SHAP_Importance = c(30, 70),
                    stringsAsFactors = FALSE)
  out <- suppressWarnings(utils::capture.output(res <- select_best_importance(imp)))
  expect_equal(res$importance, c(30, 70))
  expect_true(any(grepl("SHAP", out, fixed = TRUE)))
})

test_that("the docs describe what auto actually does (F26)", {
  # The claim that was there before, and was never true of the code.
  wrong <- "Uses SHAP if enabled, otherwise Shapley"
  docs <- c(list.files(file.path(module_dir, "docs"), pattern = "[.]md$", full.names = TRUE),
            file.path(module_dir, "README.md"))
  docs <- docs[file.exists(docs)]
  for (d in docs) {
    src <- paste(readLines(d, warn = FALSE), collapse = "\n")
    expect_false(grepl(wrong, src, fixed = TRUE), info = basename(d))
  }

  ref <- file.path(module_dir, "docs", "06_TEMPLATE_REFERENCE.md")
  skip_if(!file.exists(ref), "template reference not present")
  src <- paste(readLines(ref, warn = FALSE), collapse = "\n")
  expect_true(grepl("The Shapley decomposition, always", src, fixed = TRUE))

  # And the config template an analyst opens says the same thing.
  gen <- paste(readLines(file.path(module_dir, "lib", "generate_config_templates.R"),
                         warn = FALSE), collapse = "\n")
  expect_true(grepl("'auto' means the Shapley decomposition", gen, fixed = TRUE))
  expect_true(grepl("set 'shap' explicitly", gen, fixed = TRUE))
})
