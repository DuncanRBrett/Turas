# ==============================================================================
# KEYDRIVER - SEGMENT COMPARISON (review C2)
# ==============================================================================
# Four defects in one layer: the per-segment models were always unweighted, a
# categorical driver silently scored zero, only the first Segments row was ever
# read, and any failure returned NULL under a PASS. These cover the first two;
# the call-site defects are covered in test_segment_pipeline.R.
# ==============================================================================

# Loaded rather than skipped (review F17).
kd_ensure_module_loaded("core")
expect_true(exists("run_segment_importance_comparison", mode = "function"))

# Two segments. In segment A the driver X1 dominates; in segment B it is X2.
# A weight column deliberately favours the half of each segment where the
# relationship is strongest, so a weighted fit must differ from an unweighted
# one by more than noise.
seg_fixture <- function(n = 400, seed = 11) {
  set.seed(seed)
  mk <- function(b1, b2, lab) {
    x1 <- rnorm(n); x2 <- rnorm(n)
    y <- b1 * x1 + b2 * x2 + rnorm(n, sd = 0.4)
    data.frame(X1 = x1, X2 = x2, Y = y, Seg = lab, stringsAsFactors = FALSE)
  }
  d <- rbind(mk(0.9, 0.1, "A"), mk(0.1, 0.9, "B"))
  # Weight the first half of every segment far more heavily, and make that half
  # behave differently, so weighting has something to bite on.
  d$W <- 1
  half <- c(seq_len(n / 2), n + seq_len(n / 2))
  d$W[half] <- 6
  d$Y[half] <- d$Y[half] + 1.6 * d$X2[half]
  d
}

test_that("a weighted segment run differs from an unweighted one (C2)", {
  d <- seg_fixture()
  cfg <- list(top_n = 2, rank_diff_threshold = 2, min_segment_n = 30)
  un <- suppressWarnings(capture.output(
    a <- run_segment_importance_comparison(d, "Y", c("X1", "X2"), "Seg", config = cfg)))
  we <- suppressWarnings(capture.output(
    b <- run_segment_importance_comparison(d, "Y", c("X1", "X2"), "Seg",
                                           config = cfg, weight_var = "W")))
  ia <- a$comparison_matrix
  ib <- b$comparison_matrix
  expect_true(is.data.frame(ia) && is.data.frame(ib))
  num_a <- unlist(ia[, vapply(ia, is.numeric, logical(1)), drop = FALSE])
  num_b <- unlist(ib[, vapply(ib, is.numeric, logical(1)), drop = FALSE])
  expect_equal(length(num_a), length(num_b))
  # The weights move the numbers. Before the fix they could not, because the
  # function never saw a weight column.
  expect_gt(max(abs(num_a - num_b), na.rm = TRUE), 1)
})

test_that("a categorical driver is not silently scored zero (C2)", {
  set.seed(3)
  n <- 500
  region <- sample(c("North", "South", "East"), n, TRUE)
  x1 <- rnorm(n)
  # Region matters a great deal; X1 barely at all.
  y <- 2.5 * (region == "North") - 1.8 * (region == "South") + 0.05 * x1 + rnorm(n, sd = 0.3)
  d <- data.frame(X1 = x1, Region = factor(region), Y = y,
                  Seg = rep(c("A", "B"), length.out = n), stringsAsFactors = FALSE)

  out <- suppressWarnings(capture.output(
    r <- run_segment_importance_comparison(d, "Y", c("X1", "Region"), "Seg",
                                           config = list(min_segment_n = 30))))
  cm <- r$comparison_matrix
  expect_true("Region" %in% cm$Driver)
  vals <- unlist(cm[cm$Driver == "Region", vapply(cm, is.numeric, logical(1)), drop = FALSE])
  vals <- vals[!is.na(vals)]
  expect_gt(length(vals), 0)
  # It scored 0 in every segment before the fix, because coefs["Region"] is NA
  # when the model names the term RegionNorth.
  expect_true(all(vals > 0))
  # And it is the dominant driver, which is what the data says.
  x1_vals <- unlist(cm[cm$Driver == "X1", vapply(cm, is.numeric, logical(1)), drop = FALSE])
  expect_gt(mean(vals), mean(x1_vals[!is.na(x1_vals)]))
})

test_that("segment_values groups the levels it is given (C2)", {
  set.seed(5)
  n <- 600
  seg <- sample(c("18-24", "25-34", "35-49", "50+"), n, TRUE)
  x1 <- rnorm(n); x2 <- rnorm(n)
  young <- seg %in% c("18-24", "25-34")
  y <- ifelse(young, 0.9 * x1 + 0.1 * x2, 0.1 * x1 + 0.9 * x2) + rnorm(n, sd = 0.4)
  d <- data.frame(X1 = x1, X2 = x2, Y = y, Age = seg, stringsAsFactors = FALSE)

  out <- suppressWarnings(capture.output(
    r <- run_segment_importance_comparison(
      d, "Y", c("X1", "X2"), "Age",
      segment_values = list(Younger = c("18-24", "25-34"), Older = c("35-49", "50+")),
      config = list(min_segment_n = 30))))
  cm <- r$comparison_matrix
  pct_cols <- grep("_Pct$", names(cm), value = TRUE)
  pct_cols <- setdiff(pct_cols, "Mean_Pct")
  # Two groups, named as given, not the four raw levels.
  expect_equal(sort(pct_cols), c("Older_Pct", "Younger_Pct"))
  younger <- cm[["Younger_Pct"]]
  older <- cm[["Older_Pct"]]
  expect_gt(younger[cm$Driver == "X1"], younger[cm$Driver == "X2"])
  expect_gt(older[cm$Driver == "X2"], older[cm$Driver == "X1"])
})

# ------------------------------------------------------------------------------
# C2, the call site: every Segments row is read, and a failure degrades the run
# ------------------------------------------------------------------------------

test_that("the Segments sheet becomes named groups, per variable (C2)", {
  # Not a skip: the helper IS the fix, so its absence is a failure.
  expect_true(exists(".kd_segment_definitions", mode = "function"))
  segs <- data.frame(
    segment_name = c("Younger", "Older", "Metro", "Non-metro"),
    segment_variable = c("Age", "Age", "Area", "Area"),
    segment_values = c("18-24; 25-34", "35-49; 50+", "Urban", "Rural, Peri-urban"),
    stringsAsFactors = FALSE
  )
  defs <- .kd_segment_definitions(segs)
  # Two variables, not one: the call site read segment_variable[1] only.
  expect_equal(sort(names(defs)), c("Age", "Area"))
  expect_equal(sort(names(defs$Age)), c("Older", "Younger"))
  expect_equal(defs$Age$Younger, c("18-24", "25-34"))
  expect_equal(defs$Area$`Non-metro`, c("Rural", "Peri-urban"))

  # A row with no values falls back to whatever the data has, which is the old
  # single-row behaviour.
  bare <- data.frame(segment_name = "All", segment_variable = "Age",
                     segment_values = NA_character_, stringsAsFactors = FALSE)
  expect_equal(length(.kd_segment_definitions(bare)$Age), 0)

  # A blank variable is not a segment.
  blank <- data.frame(segment_name = "x", segment_variable = "",
                      segment_values = "a; b", stringsAsFactors = FALSE)
  expect_equal(length(.kd_segment_definitions(blank)), 0)
})

test_that("an unnamed grouping list refuses rather than guessing a label (C2)", {
  d <- seg_fixture(n = 120)
  err <- tryCatch(
    suppressWarnings(capture.output(
      run_segment_importance_comparison(d, "Y", c("X1", "X2"), "Seg",
                                        segment_values = list(c("A"), c("B")),
                                        config = list(min_segment_n = 30)))),
    error = function(e) conditionMessage(e))
  expect_true(is.character(err))
  expect_match(err, "CFG_SEGMENT_GROUPS_UNNAMED")
})

test_that("a named weight column that is not in the data refuses (C2)", {
  d <- seg_fixture(n = 120)
  err <- tryCatch(
    suppressWarnings(capture.output(
      run_segment_importance_comparison(d, "Y", c("X1", "X2"), "Seg",
                                        config = list(min_segment_n = 30),
                                        weight_var = "NotThere"))),
    error = function(e) conditionMessage(e))
  expect_true(is.character(err))
  expect_match(err, "DATA_SEGMENT_WEIGHT_NOT_FOUND")
  # Silently reverting to an unweighted fit is the failure mode this replaces.
  expect_match(err, "unweighted")
})

test_that("validation names a segment variable the data does not have (C2)", {
  src <- readLines(file.path(module_dir, "R", "02_validation.R"))
  # The old line dropped it with a comment saying not to refuse; nothing said so.
  expect_false(any(grepl("don't refuse if missing", src, fixed = TRUE)))
  expect_true(any(grepl("missing_segment_vars", src, fixed = TRUE)))
  expect_true(any(grepl("the data does not have", src, fixed = TRUE)))

  main <- readLines(file.path(module_dir, "R", "00_main.R"))
  # And the pipeline turns that into a degraded run rather than a clean PASS.
  idx <- grep("missing_segment_vars", main)
  expect_gt(length(idx), 0)
  window <- main[seq(min(idx), min(min(idx) + 6, length(main)))]
  expect_true(any(grepl("degraded_reasons", window)))
})
