# ==============================================================================
# KEYDRIVER - ENGINE MEDIUMS (review M3, M6, M14)
# ==============================================================================

test_that("a config that says Yes enables the feature (M14)", {
  skip_if(!exists("as_logical_setting", mode = "function"), "helper not loaded")
  # as.logical("Yes") is NA, so isTRUE(as.logical("Yes")) is FALSE: a config
  # written the way an analyst writes one switched the feature off in silence.
  expect_true(is.na(as.logical("Yes")))
  expect_true(is.na(as.logical("Y")))

  for (v in c("Yes", "yes", "YES", "Y", "y", "TRUE", "true", "T", "t",
              "1", "On", "enabled")) {
    expect_true(as_logical_setting(v), info = v)
  }
  for (v in c("No", "n", "FALSE", "0", "off", "")) {
    expect_false(as_logical_setting(v), info = v)
  }
  # Whitespace from a spreadsheet cell does not change the answer.
  expect_true(as_logical_setting(" Yes "))
  # And an unset value takes the default it is given.
  expect_false(as_logical_setting(NULL))
  expect_true(as_logical_setting(NULL, default = TRUE))
  expect_false(as_logical_setting(NA))
})

test_that("every enable_ gate goes through the helper (M14)", {
  main <- readLines(file.path(module_dir, "R", "00_main.R"))
  code <- main[!grepl("^\\s*#", main)]
  # The pattern that silently disabled any setting written as Yes. Not only the
  # enable_ gates: normalize_axes, shade_quadrants and four others had it too.
  expect_false(any(grepl("isTRUE(as.logical(config$settings$", code, fixed = TRUE)))
  # Every gate that reads a config setting, which is the set that could be
  # written "Yes" in a spreadsheet.
  gates <- grep("enable_[a-z_]+ <- .*config\\$settings\\$enable_", main, value = TRUE)
  expect_gt(length(gates), 4)
  expect_true(all(grepl("as_logical_setting", gates)), info = paste(gates, collapse = " | "))
})

test_that("one seed covers the whole run and is recoverable (M3)", {
  skip_if(!exists("kd_seed_value", mode = "function"), "seed helper not loaded")
  # Nothing was seeded except a hard-coded 42 inside the SHAP path, so two runs
  # of one config gave different intervals and a different SHAP model.
  expect_equal(kd_seed_value(list()), KD_DEFAULT_SEED)
  expect_equal(kd_seed_value(list(settings = list(random_seed = 7))), 7L)
  expect_equal(kd_seed_value(list(random_seed = "99")), 99L)
  # A value that is not a number falls back rather than erroring mid-run.
  expect_equal(kd_seed_value(list(settings = list(random_seed = "abc"))), KD_DEFAULT_SEED)

  # Applying it makes the next draw reproducible.
  kd_apply_seed(list(settings = list(random_seed = 123)))
  a <- runif(5)
  kd_apply_seed(list(settings = list(random_seed = 123)))
  expect_equal(runif(5), a)
})

test_that("the randomised steps all ask for the seed (M3)", {
  files <- c("05_bootstrap.R", "09_elastic_net.R", "00_guard.R")
  for (f in files) {
    src <- readLines(file.path(module_dir, "R", f), warn = FALSE)
    expect_true(any(grepl("kd_apply_seed", src, fixed = TRUE)), info = f)
  }
  shap <- readLines(file.path(module_dir, "R", "kda_shap", "shap_calculate.R"), warn = FALSE)
  expect_true(any(grepl("kd_apply_seed", shap, fixed = TRUE)))
  # The hard-coded seed is no longer the only thing holding it together.
  expect_false(any(grepl("^\\s*set.seed(42)", shap)))
})

test_that("an all-categorical model runs, with an empty correlation column (M6, F2)", {
  skip_if(!exists("calculate_importance_mixed", mode = "function"),
          "mixed path not loaded")
  set.seed(3)
  n <- 200
  d <- data.frame(
    G1 = factor(sample(c("a", "b"), n, TRUE)),
    G2 = factor(sample(c("x", "y", "z"), n, TRUE))
  )
  d$Y <- as.numeric(d$G1 == "a") * 2 + rnorm(n)
  cfg <- list(outcome_var = "Y", driver_vars = c("G1", "G2"), weight_var = NULL)
  f <- Y ~ G1 + G2
  model <- lm(f, data = d)
  tm <- build_term_mapping(f, d, cfg$driver_vars)

  # It used to die inside cor() with a bare error, then for a while it refused
  # the study and told the analyst to switch the correlation column off with a
  # setting that does not exist (review F2). Beta weights, relative weights and
  # Shapley values are all defined here, so the study runs and only the
  # correlation column is empty.
  imp <- NULL
  err <- tryCatch({
    suppressWarnings(capture.output(
      imp <- calculate_importance_mixed(model, d, cfg, tm, correlations = NULL)))
    ""
  }, error = function(e) conditionMessage(e))

  expect_equal(err, "")
  expect_true(is.data.frame(imp))
  expect_setequal(imp$Driver, c("G1", "G2"))
  expect_true(all(is.na(imp$Correlation)))
  # The measures that are defined for a factor all produced a number.
  expect_true(all(is.finite(imp$Beta_Weight)))
  expect_true(all(is.finite(imp$Relative_Weight)))
  expect_true(all(is.finite(imp$Shapley_Value)))
  # And the one that carries the real signal is G1, which built the outcome.
  expect_equal(imp$Driver[which.max(imp$Shapley_Value)], "G1")
})

test_that("one numeric driver among categoricals does not kill the run (F1)", {
  skip_if(!exists("calculate_correlations", mode = "function"),
          "analysis not loaded")
  # stats::cor() on a frame with a factor column raises "'x' must be numeric".
  # The unweighted path handed it the whole driver list, so an unweighted
  # mixed study with one numeric driver died part-way through the importance
  # table. The weighted twin survived, which is how it stayed hidden.
  set.seed(11)
  n <- 150
  d <- data.frame(
    x1 = rnorm(n),
    g  = factor(sample(c("a", "b"), n, TRUE)),
    h  = factor(sample(c("p", "q"), n, TRUE)),
    w  = runif(n, 0.5, 2)
  )
  d$Y <- d$x1 * 2 + rnorm(n)

  for (wv in list(NULL, "w")) {
    cfg <- list(outcome_var = "Y", driver_vars = c("x1", "g", "h"), weight_var = wv)
    m <- calculate_correlations(d, cfg)
    expect_true(is.matrix(m))
    expect_setequal(rownames(m), c("Y", "x1", "g", "h"))
    # The numeric pair is real and the factor cells are NA, not an error.
    expect_true(is.finite(m["Y", "x1"]))
    expect_gt(m["Y", "x1"], 0.7)
    expect_true(is.na(m["Y", "g"]))
    expect_true(is.na(m["g", "h"]))
  }

  # And with no numeric driver at all it is a full NA matrix, not a failure.
  cfg0 <- list(outcome_var = "Y", driver_vars = c("g", "h"), weight_var = NULL)
  m0 <- calculate_correlations(d, cfg0)
  expect_true(all(is.na(m0[, c("g", "h")])))
})

test_that("standardised betas use weighted SDs on a weighted study (M1)", {
  skip_if(!exists("weighted_sd", mode = "function"), "helper not loaded")
  # A standardised beta is b * (sd_x / sd_y). The coefficients came from a
  # weighted fit and the SDs did not, so the ratio mixed the model's weighted
  # population with the file's unweighted one.
  x <- c(1, 2, 3, 4, 100)
  w <- c(1, 1, 1, 1, 20)
  expect_false(isTRUE(all.equal(weighted_sd(x, w), stats::sd(x))))
  # Hand check: with equal weights it is the population SD, not the sample one.
  y <- c(2, 4, 6)
  expect_equal(weighted_sd(y, c(1, 1, 1)), sqrt(mean((y - mean(y))^2)))
  # Too little to work with is NA, not a wrong number.
  expect_true(is.na(weighted_sd(c(1, NA), c(1, NA))))
  expect_true(is.na(weighted_sd(c(1, 2), c(0, 0))))
})

test_that("the engine asks for a weighted SD when a weight is configured (M1)", {
  src <- readLines(file.path(module_dir, "R", "03_analysis.R"))
  code <- src[!grepl("^\\s*#", src)]
  # Both standardised-beta sites, the plain and the mixed, now branch on it.
  expect_gte(sum(grepl("weighted_sd(", code, fixed = TRUE)), 3)
})

test_that("the bootstrap says what its numbers are (M4)", {
  skip_if(!exists("bootstrap_importance_ci", mode = "function"), "bootstrap not loaded")
  set.seed(5)
  n <- 150
  d <- data.frame(D1 = rnorm(n), D2 = rnorm(n), W = runif(n, 0.5, 2))
  d$Y <- 0.7 * d$D1 + 0.2 * d$D2 + rnorm(n, sd = 0.5)

  invisible(capture.output(
    res <- bootstrap_importance_ci(d, "Y", c("D1", "D2"),
                                   config = list(bootstrap_iterations = 100))))
  policy <- attr(res, "bootstrap_policy")
  expect_false(is.null(policy))
  # The three things a reader of the sheet could not otherwise know.
  expect_match(policy, "MEAN OF THE BOOTSTRAP DISTRIBUTION")
  expect_match(policy, "will not equal")
  expect_match(policy, "Shapley values carry no interval")
  expect_equal(attr(res, "iterations_requested"), 100L)
  expect_equal(attr(res, "iterations_used") + attr(res, "iterations_dropped"), 100L)
  # Shapley is stamped in prose, not as rows of NA, which would read as
  # missing data rather than as a method without an interval.
  expect_false("Shapley_Value" %in% res$Method)
})

test_that("a weighted bootstrap names its resampling policy (M4)", {
  skip_if(!exists("bootstrap_importance_ci", mode = "function"), "bootstrap not loaded")
  set.seed(6)
  n <- 150
  d <- data.frame(D1 = rnorm(n), D2 = rnorm(n), W = runif(n, 0.5, 2))
  d$Y <- 0.7 * d$D1 + 0.2 * d$D2 + rnorm(n, sd = 0.5)
  invisible(capture.output(
    res <- bootstrap_importance_ci(d, "Y", c("D1", "D2"), weights = "W",
                                   config = list(bootstrap_iterations = 100))))
  policy <- attr(res, "bootstrap_policy")
  expect_match(policy, "probability proportional")
  expect_match(policy, "fitted unweighted")
})

test_that("each facet gets its own quadrant lines (M5)", {
  src <- readLines(file.path(module_dir, "R", "kda_quadrant", "quadrant_comparison.R"))
  # The lines were drawn from the FIRST segment's thresholds on every panel,
  # so each segment's points were divided by another segment's mean.
  expect_false(any(grepl("xintercept = all_segments$x_threshold[1]", src, fixed = TRUE)))
  expect_false(any(grepl("yintercept = all_segments$y_threshold[1]", src, fixed = TRUE)))
  expect_true(any(grepl("aes(xintercept = x_threshold)", src, fixed = TRUE)))
  expect_true(any(grepl("inherit.aes = FALSE", src, fixed = TRUE)))
})
