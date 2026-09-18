# ==============================================================================
# KEYDRIVER - THE SEVEN HIGHS FROM THE SESSION A REVIEW (F1 to F7)
# ==============================================================================
# F1 and F2 are covered in test_engine_mediums.R, beside the M6 test they
# replace. This file carries F3 to F7.
#
# The shape these findings share is that a feature was wired and green while
# producing nothing, so where a test can run the thing rather than read it,
# it does.
# ==============================================================================

# One loader, in helper-paths.R, rather than a skip. A skip is how three of
# these findings stayed green (review F17).
kd_ensure_module_loaded("all")

test_that("SHAP produces a driver-level number for a categorical driver (F3)", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("shapviz")
  expect_true(exists("run_shap_analysis_internal", mode = "function"))

  # shapviz's collapse takes driver -> its dummies. create_feature_map()
  # returns dummy -> driver, and it was passed through unchanged, so every
  # mixed study died with "'collapse' cannot have overlapping vectors" and
  # SHAP was dropped. The suite was green because the old test stopped at the
  # map and never ran the model.
  set.seed(7)
  n <- 400
  d <- data.frame(
    x1 = rnorm(n),
    chan = factor(sample(c("app", "branch", "call"), n, TRUE)),
    stringsAsFactors = FALSE)
  d$Y <- 2 * d$x1 +
    ifelse(d$chan == "app", 2, ifelse(d$chan == "branch", 0, -1)) + rnorm(n)

  cfg <- list(outcome_var = "Y", driver_vars = c("x1", "chan"),
              weight_var = NULL,
              settings = list(shap_sample_size = 400, n_trees = 60,
                              max_depth = 3, learning_rate = 0.2,
                              random_seed = 20260101))

  res <- NULL
  err <- tryCatch({
    invisible(capture.output(res <- run_shap_analysis_internal(d, cfg)))
    ""
  }, error = function(e) conditionMessage(e))

  expect_equal(err, "")
  expect_false(is.null(res))
  imp <- res$importance
  expect_true(is.data.frame(imp))

  # The factor driver is present, at driver level, with a finite number.
  expect_true("chan" %in% imp$driver)
  chan_row <- imp[imp$driver == "chan", , drop = FALSE]
  expect_equal(nrow(chan_row), 1L)
  expect_true(is.finite(chan_row$mean_shap))
  expect_gt(chan_row$mean_shap, 0)

  # Its dummies are not reported separately, which is what collapsing is for.
  expect_false(any(grepl("^chan(app|branch|call)$", imp$driver)))

  # And x1, which carries the larger effect, outranks it.
  expect_equal(imp$driver[which.min(imp$rank)], "x1")
})

test_that("the collapse map is inverted for shapviz, not passed straight through (F3)", {
  # Deliberately not skipped when the helper is absent: its absence is the
  # regression.
  expect_true(exists(".kd_shap_collapse", mode = "function"))
  # dummy -> driver in, driver -> dummies out.
  m <- list(GenderFemale = "Gender", GenderMale = "Gender", RegionN = "Region")
  out <- .kd_shap_collapse(m)
  expect_setequal(names(out), c("Gender", "Region"))
  expect_setequal(out$Gender, c("GenderFemale", "GenderMale"))
  expect_equal(out$Region, "RegionN")
  # The un-inverted form has a repeated value, which is exactly the
  # "overlapping vectors" shapviz refused.
  expect_null(.kd_shap_collapse(NULL))
  expect_null(.kd_shap_collapse(list()))
})

test_that("random_seed changes the intervals a RUN produces (F6)", {
  expect_true(exists("run_keydriver_analysis_impl", mode = "function"))
  example_script <- file.path(project_root, "examples", "keydriver",
                              "create_keydriver_example.R")
  skip_if(!file.exists(example_script), "example generator not present")
  skip_if_not_installed("readxl")

  # Deliberately through the whole pipeline. bootstrap_importance_ci() always
  # honoured a config it was given; the defect was that the pipeline never
  # gave it one, so it seeded from an empty list and random_seed was inert. A
  # direct call to the function passes either way, which is how this survived.
  old_opt <- getOption("turas.example.no_run")
  options(turas.example.no_run = TRUE)
  source(example_script, local = FALSE)
  options(turas.example.no_run = old_opt)

  seed_dir <- file.path(tempdir(), "kd_f6_seed")
  unlink(seed_dir, recursive = TRUE)
  invisible(capture.output(ex <- build_keydriver_example(out_dir = seed_dir,
                                                         verbose = FALSE)))

  build_cfg <- function(path, seed) {
    settings <- as.data.frame(readxl::read_excel(ex$config, sheet = "Settings"))
    set_value <- function(df, key, value) {
      if (key %in% df$Setting) df$Value[df$Setting == key] <- value
      else df <- rbind(df, data.frame(Setting = key, Value = value))
      df
    }
    settings <- set_value(settings, "random_seed", as.character(seed))
    settings <- set_value(settings, "enable_bootstrap", "TRUE")
    settings <- set_value(settings, "bootstrap_iterations", "150")
    settings <- set_value(settings, "enable_shap", "FALSE")
    settings <- set_value(settings, "enable_quadrant", "FALSE")
    settings <- set_value(settings, "enable_html_report", "FALSE")
    settings <- set_value(settings, "output_file",
                          file.path(seed_dir, paste0("seed_", seed, ".xlsx")))

    wb <- openxlsx::createWorkbook()
    add <- function(name, df) {
      openxlsx::addWorksheet(wb, name)
      openxlsx::writeData(wb, name, df)
    }
    add("Settings", settings)
    for (sh in c("Variables", "Segments", "StatedImportance")) {
      add(sh, as.data.frame(readxl::read_excel(ex$config, sheet = sh)))
    }
    if (exists("turas_saveWorkbook", mode = "function")) {
      turas_saveWorkbook(wb, path, overwrite = TRUE)
    } else {
      openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
    }
    path
  }

  run_seed <- function(seed) {
    cfg <- build_cfg(file.path(seed_dir, paste0("cfg_", seed, ".xlsx")), seed)
    invisible(capture.output(
      r <- suppressWarnings(run_keydriver_analysis_impl(cfg))))
    r
  }

  r1 <- run_seed(2026)
  r2 <- run_seed(1)

  lower <- function(r) {
    b <- r$bootstrap_ci
    if (is.null(b)) return(NULL)
    df <- if (is.data.frame(b)) b else b$result
    if (is.null(df)) return(NULL)
    col <- intersect(c("ci_lower", "CI_Lower", "lower"), names(df))[1]
    if (is.na(col)) return(NULL)
    as.numeric(df[[col]])
  }

  l1 <- lower(r1); l2 <- lower(r2)
  expect_false(is.null(l1))
  expect_false(is.null(l2))
  expect_equal(length(l1), length(l2))
  # Two seeds, two sets of intervals. They used to be identical to the last
  # decimal whatever the config said.
  expect_false(isTRUE(all.equal(l1, l2)))
  # And the seed each run used is on the record.
  expect_equal(r1$run_status, "PASS")
})

test_that("the pipeline hands the bootstrap its config, and records the seed (F6)", {
  main <- readLines(file.path(module_dir, "R", "00_main.R"), warn = FALSE)
  code <- main[!grepl("^\\s*#", main)]
  block <- paste(code, collapse = "\n")
  expect_true(grepl("bootstrap_importance_ci(", block, fixed = TRUE))
  # The call site passes config.
  call_start <- grep("bootstrap_importance_ci(", code, fixed = TRUE)[1]
  expect_false(is.na(call_start))
  call_block <- paste(code[call_start:(call_start + 10)], collapse = "\n")
  expect_true(grepl("config = config", call_block, fixed = TRUE))

  # The SHAP sub-config carries the seed rather than falling back every time.
  expect_true(grepl("random_seed = config$settings$random_seed", block, fixed = TRUE))

  # xgboost's cross-validation and final fit are both seeded.
  sm <- paste(readLines(file.path(module_dir, "R", "kda_shap", "shap_model.R"),
                        warn = FALSE), collapse = "\n")
  expect_equal(length(gregexpr("kd_apply_seed(config)", sm, fixed = TRUE)[[1]]), 2L)

  # And the seed is written where someone reproducing the run will look.
  out <- paste(readLines(file.path(module_dir, "R", "04_output.R"), warn = FALSE),
               collapse = "\n")
  expect_true(grepl('"random_seed"', out, fixed = TRUE))
  expect_true(grepl("kd_seed_value(config)", out, fixed = TRUE))
})

test_that("the pipeline sources its own pre-flight validators (F7)", {
  main <- readLines(file.path(module_dir, "R", "00_main.R"), warn = FALSE)
  code <- main[!grepl("^\\s*#", main)]
  block <- paste(code, collapse = "\n")
  # Every other step the pipeline needs sources itself from find_turas_root().
  # These checks did not, so the GUI ran them and every headless call, which
  # the example README offers as an equal path, skipped them in silence.
  expect_true(grepl('"validation", "preflight_validators.R"', block, fixed = TRUE))
  expect_true(grepl("find_turas_root()", block, fixed = TRUE))
  # The source happens before the orchestrator is called.
  src_at <- regexpr("preflight_validators.R", block, fixed = TRUE)[1]
  call_at <- regexpr("validate_keydriver_preflight(", block, fixed = TRUE)[1]
  expect_gt(src_at, 0)
  expect_lt(src_at, call_at)
})

test_that("the pre-flight banner counts the checks that exist (F5, F7)", {
  pf <- file.path(module_dir, "lib", "validation", "preflight_validators.R")
  src <- readLines(pf, warn = FALSE)
  # Thirteen since check 5 went.
  n_calls <- sum(grepl("^  error_log <- check_", src))
  expect_equal(n_calls, 13L)
  expect_true(any(grepl("KD_PREFLIGHT_CHECK_COUNT <- 13L", src, fixed = TRUE)))
  # The banner reads the constant rather than a typed number.
  expect_false(any(grepl("All 14 pre-flight checks passed", src, fixed = TRUE)))
  expect_true(any(grepl("All %d pre-flight checks passed", src, fixed = TRUE)))
})
