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

test_that("an all-categorical model refuses the correlation column (M6)", {
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

  err <- tryCatch({
    suppressWarnings(capture.output(
      calculate_importance_mixed(model, d, cfg, tm, correlations = NULL)))
    "NO REFUSAL"
  }, error = function(e) conditionMessage(e))
  # It used to die inside cor() with a bare error and no guidance.
  expect_match(err, "DATA_NO_NUMERIC_DRIVERS")
  expect_match(err, "only defined between numbers")
})
