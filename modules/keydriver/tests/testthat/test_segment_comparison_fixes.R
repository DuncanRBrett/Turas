# ==============================================================================
# KEYDRIVER - SEGMENT COMPARISON (review C2)
# ==============================================================================
# Four defects in one layer: the per-segment models were always unweighted, a
# categorical driver silently scored zero, only the first Segments row was ever
# read, and any failure returned NULL under a PASS. These cover the first two;
# the call-site defects are covered in test_segment_pipeline.R.
# ==============================================================================

skip_if(!exists("run_segment_importance_comparison", mode = "function"),
        "segment comparison not loaded")

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
