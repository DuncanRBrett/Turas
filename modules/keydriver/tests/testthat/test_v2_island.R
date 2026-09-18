# ==============================================================================
# KEYDRIVER - THE V2 REPORT ISLAND (TR.KD)
# ==============================================================================
# A keydriver run writes {output}_kd_island.json; a tabs run for the same
# project embeds it and the report gains a Key drivers tab. The load-bearing
# properties are that a block the run did not produce is ABSENT rather than
# empty, that a single-element list still serialises as an array, and that
# nothing claims an interval the bootstrap never computed.
# ==============================================================================

kd_ensure_module_loaded("all")
source(file.path(module_dir, "R", "13_v2_island.R"), local = FALSE)
expect_true(exists("serialize_keydriver_layer", mode = "function"))

# A small, complete results object. Built here rather than by running the
# pipeline, so a change to the island's shape fails here with a readable
# message instead of somewhere inside a 900-respondent run.
kd_island_fixture <- function() {
  imp <- data.frame(
    Driver           = c("digital", "fees", "waiting"),
    Label            = c("Digital banking", "Clarity of fees", "Wait time"),
    Beta_Weight      = c(47.8, 24.0, 8.2),
    Beta_Coefficient = c(0.54, 0.27, -0.11),
    Relative_Weight  = c(45.5, 21.3, 8.1),
    Shapley_Value    = c(45.8, 21.1, 8.4),
    Correlation      = c(0.77, 0.61, -0.32),
    Beta_Rank        = c(1, 2, 3),
    RelWeight_Rank   = c(1, 2, 3),
    Shapley_Rank     = c(1, 2, 3),
    Corr_Rank        = c(1, 2, 3),
    Average_Rank     = c(1, 2, 3),
    stringsAsFactors = FALSE)

  boot <- data.frame(
    Driver         = rep(c("digital", "fees", "waiting"), 2),
    Method         = rep(c("Relative_Weight", "Correlation"), each = 3),
    Point_Estimate = c(45.5, 21.3, 8.1, 0.77, 0.61, -0.32),
    CI_Lower       = c(41.2, 18.0, 5.9, 0.74, 0.57, -0.38),
    CI_Upper       = c(49.9, 24.8, 10.6, 0.80, 0.64, -0.26),
    SE             = c(2.2, 1.7, 1.2, 0.014, 0.019, 0.030),
    stringsAsFactors = FALSE)

  set.seed(4)
  n <- 120
  d <- data.frame(digital = rnorm(n), fees = rnorm(n), waiting = rnorm(n))
  d$y <- 2 * d$digital + d$fees - 0.5 * d$waiting + rnorm(n)
  model <- stats::lm(y ~ digital + fees + waiting, data = d)

  quad <- structure(
    list(data = data.frame(
      driver = c("digital", "fees", "waiting"),
      x = c(100, 0, 42), y = c(100, 37.5, 12),
      x_threshold = rep(24.3, 3), y_threshold = rep(34.2, 3),
      quadrant = c(2, 1, 3),
      quadrant_label = c("Keep Up Good Work", "Concentrate Here", "Low Priority"),
      gap = c(0, 37.5, 10.5), priority_score = c(0, 37.5, 19),
      stringsAsFactors = FALSE)),
    class = "quadrant_results",
    importance_source_requested = "shap",
    importance_source_used = "auto (shap was requested and is absent)")

  seg <- list(
    age_band = list(
      comparison_matrix = data.frame(
        Driver = c("digital", "fees", "waiting"),
        Younger_Pct = c(42.1, 26.3, 8.0), Younger_Rank = c(1, 2, 3),
        Older_Pct = c(44.4, 24.8, 9.1),   Older_Rank = c(1, 2, 3),
        Mean_Pct = c(43.3, 25.5, 8.6),
        stringsAsFactors = FALSE),
      classifications = data.frame(
        Driver = c("digital", "fees", "waiting"),
        Classification = c("Universal", "Universal", "Low Priority"),
        Description = c("a", "b", "c"),
        stringsAsFactors = FALSE),
      insights = "digital is the #1 driver across all 2 segments",
      segment_results = list(Younger = data.frame(), Older = data.frame()),
      segment_bases = list(Younger = 412, Older = 488),
      min_segment_n = 60))

  cfg <- list(
    outcome_var = "y", driver_vars = c("digital", "fees", "waiting"),
    weight_var = NULL, output_file = "kd_results.xlsx",
    variables = data.frame(VariableName = "y", Label = "Overall satisfaction",
                           stringsAsFactors = FALSE),
    settings = list(analysis_name = "Test study", bootstrap_iterations = 250,
                    bootstrap_ci_level = 0.95, min_segment_n = 60))

  list(importance = imp, bootstrap_ci = boot, model = model, quadrant = quad,
       segment_comparisons = seg, config = cfg, run_status = "PASS")
}

isl <- serialize_keydriver_layer(kd_island_fixture(), kd_island_fixture()$config,
                                 data_info = list(n_complete = 120, n_missing = 3),
                                 verbose = FALSE)

test_that("the island carries every block the view needs", {
  expect_true(is.list(isl))
  expect_setequal(names(isl), c("meta", "importance", "ci", "fit", "quadrant", "segments"))
  expect_identical(isl$meta$kind, "keydriver")
  expect_identical(isl$meta$schema_version, KD_ISLAND_SCHEMA_VERSION)
})

test_that("the base says what it rests on", {
  b <- isl$meta$base
  expect_equal(b$n, 120)
  expect_equal(b$n_excluded, 3)
  expect_false(b$weighted)
  # An unweighted study carries no effective n, rather than one equal to n.
  expect_null(b$n_eff)
})

test_that("importance carries a value, a rank and a direction per driver", {
  d <- isl$importance$drivers
  expect_equal(length(d), 3)
  expect_equal(d[[1]]$driver, "digital")
  expect_equal(d[[1]]$label, "Digital banking")
  expect_equal(d[[1]]$values$shapley, 45.8)
  expect_equal(d[[1]]$ranks$shapley, 1)
  # The negative coefficient becomes a direction the view can mark. Importance
  # shares are magnitudes and carry no sign of their own.
  expect_equal(d[[3]]$direction, -1)
  expect_equal(d[[1]]$direction, 1)
})

test_that("a method without a bootstrap is named, not left blank (decision 3)", {
  ms <- isl$importance$methods
  keys <- vapply(ms, function(m) m$key, character(1))
  expect_true("shapley" %in% keys)
  shap <- ms[[which(keys == "shapley")]]
  expect_false(shap$interval)
  expect_equal(shap$note, "no interval available")
  # And the CI block says the same thing from its own side.
  expect_true("shapley" %in% isl$ci$no_interval)
  expect_false("shapley" %in% isl$ci$methods)
})

test_that("the intervals are the ones the bootstrap actually produced", {
  expect_equal(length(isl$ci$rows), 6)
  expect_setequal(isl$ci$methods, c("relative_weight", "correlation"))
  r1 <- isl$ci$rows[[1]]
  expect_equal(r1$driver, "digital")
  expect_equal(r1$method, "relative_weight")
  expect_equal(r1$lo, 41.2)
  expect_equal(r1$hi, 49.9)
  expect_equal(isl$ci$iterations, 250)
  expect_equal(isl$ci$level, 0.95)
  # The reader must not mistake the bootstrap mean for the headline figure.
  expect_true(grepl("mean of the bootstrap distribution", isl$ci$note, fixed = TRUE))
})

test_that("the fit block carries R squared, F and VIF", {
  f <- isl$fit
  expect_true(f$r2 > 0.5 && f$r2 <= 1)
  expect_equal(f$df1, 3)
  expect_equal(f$n_model, 120)
  expect_equal(length(f$vif), 3)
  expect_equal(f$vif_thresholds$moderate, 5)
  expect_equal(f$vif_thresholds$high, 10)
})

test_that("the quadrant carries its thresholds and the source that made it", {
  q <- isl$quadrant
  expect_equal(length(q$points), 3)
  expect_equal(q$thresholds$x, 24.3)
  expect_equal(q$thresholds$y, 34.2)
  # Which source was asked for against the one that ran. Recorded on the
  # result and, before this island, read by nobody.
  expect_equal(q$importance_source$requested, "shap")
  expect_true(grepl("shap was requested", q$importance_source$used, fixed = TRUE))
})

test_that("every segment carries its base and the threshold it had to clear", {
  s <- isl$segments
  expect_equal(length(s), 1)
  expect_equal(s[[1]]$variable, "age_band")
  bases <- vapply(s[[1]]$segments, function(x) x$n, numeric(1))
  expect_equal(unname(bases), c(412, 488))
  expect_equal(s[[1]]$min_base, 60)
  expect_equal(s[[1]]$rows[[1]]$values$Younger, 42.1)
  expect_equal(s[[1]]$rows[[1]]$classification, "Universal")
})

test_that("a block the run did not produce is absent, not empty", {
  # jsonlite writes a NULL list element as {}, which is truthy in JavaScript,
  # so an empty block would light up a panel with nothing in it.
  bare <- kd_island_fixture()
  bare$bootstrap_ci <- NULL
  bare$quadrant <- NULL
  bare$segment_comparisons <- NULL
  out <- serialize_keydriver_layer(bare, bare$config, verbose = FALSE)

  expect_false("ci" %in% names(out))
  expect_false("quadrant" %in% names(out))
  expect_false("segments" %in% names(out))
  expect_true("importance" %in% names(out))
  expect_false(out$meta$has_ci)
  expect_false(out$meta$has_quadrant)
  expect_equal(out$meta$n_segment_vars, 0)
})

test_that("no importance table means no island at all", {
  bare <- kd_island_fixture()
  bare$importance <- NULL
  expect_null(serialize_keydriver_layer(bare, bare$config, verbose = FALSE))

  empty <- kd_island_fixture()
  empty$importance <- empty$importance[0, , drop = FALSE]
  expect_null(serialize_keydriver_layer(empty, empty$config, verbose = FALSE))
})

test_that("the tab is marked frozen and says so in words", {
  expect_true(isTRUE(isl$meta$frozen))
  expect_true(grepl("do not apply here", isl$meta$filter_note, fixed = TRUE))
})

test_that("a one-element list still serialises as an array", {
  # auto_unbox turns a length-one vector into a scalar, and a view that maps
  # over it then breaks on the study with one bootstrapped method.
  skip_if_not_installed("jsonlite")
  one <- kd_island_fixture()
  one$bootstrap_ci <- one$bootstrap_ci[one$bootstrap_ci$Method == "Correlation", , drop = FALSE]
  built <- serialize_keydriver_layer(one, one$config, verbose = FALSE)

  path <- tempfile(fileext = ".json")
  on.exit(unlink(path), add = TRUE)
  jsonlite::write_json(.kd_island_keep_arrays(built), path,
                       auto_unbox = TRUE, na = "null", digits = 6)
  back <- jsonlite::fromJSON(path, simplifyVector = FALSE)

  expect_true(is.list(back$ci$methods))
  expect_equal(length(back$ci$methods), 1)
  expect_true(is.list(back$ci$no_interval))
  expect_true(is.list(back$segments[[1]]$insights))
})

test_that("write_keydriver_island names the file after the workbook", {
  skip_if_not_installed("jsonlite")
  fx <- kd_island_fixture()
  dir <- tempfile(); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  fx$config$output_file <- file.path(dir, "Study_Results.xlsx")

  res <- write_keydriver_island(fx, fx$config, verbose = FALSE)
  expect_equal(res$status, "PASS")
  expect_equal(basename(res$output_file), "Study_Results_kd_island.json")
  expect_true(file.exists(res$output_file))

  back <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  expect_identical(back$meta$kind, "keydriver")
})

test_that("a run with nothing to contribute is skipped, not refused", {
  # A missing Key drivers tab is not worth failing an otherwise good run over,
  # and the run has already said why there is no importance table.
  fx <- kd_island_fixture()
  fx$importance <- NULL
  res <- write_keydriver_island(fx, fx$config, verbose = FALSE)
  expect_equal(res$status, "SKIPPED")
  expect_null(res$output_file)
})

test_that("the pipeline writes the island and the engine keeps segment bases", {
  main <- readLines(file.path(module_dir, "R", "00_main.R"), warn = FALSE)
  code <- main[!grepl("^\\s*#", main)]
  block <- paste(code, collapse = "\n")
  expect_true(grepl("write_keydriver_island(", block, fixed = TRUE))
  expect_true(grepl("13_v2_island.R", block, fixed = TRUE))
  # nEff comes from the shared Kish, not a second inline one.
  expect_true(grepl("calculate_effective_n(", block, fixed = TRUE))
  expect_false(grepl("sum_w2 <- sum(w_valid^2)", block, fixed = TRUE))

  seg <- paste(readLines(file.path(module_dir, "R", "07_segment_comparison.R"),
                         warn = FALSE), collapse = "\n")
  expect_true(grepl("segment_bases", seg, fixed = TRUE))
})
