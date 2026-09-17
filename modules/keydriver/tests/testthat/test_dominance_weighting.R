# ==============================================================================
# KEYDRIVER - WEIGHTED DOMINANCE (review H5)
# ==============================================================================
# A weighted run multiplied the outcome and every driver by sqrt(w) and fitted
# unweighted, with a comment claiming that is "algebraically equivalent to
# weighted least squares". It is not, for R-squared, which is the whole of what
# dominance decomposes: the transformation changes the total sum of squares and
# the intercept's meaning, so summary()$r.squared on the transformed data is
# not the weighted R-squared.
# ==============================================================================

skip_if_not(file.exists(file.path(module_dir, "R", "11_dominance.R")), "dominance not present")
skip_if_not_installed("domir")
suppressWarnings(try(source(file.path(module_dir, "R", "11_dominance.R")), silent = TRUE))
skip_if(!exists("run_dominance_analysis", mode = "function"), "dominance not loaded")

dom_fixture <- function(n = 300, seed = 1) {
  set.seed(seed)
  d <- data.frame(D1 = rnorm(n), D2 = rnorm(n), D3 = rnorm(n), W = 1)
  half <- seq_len(n / 2)
  d$W[half] <- 9
  d$Y <- 0.2 * d$D1 + 0.8 * d$D2 + 0.1 * d$D3 + rnorm(n, sd = 0.4)
  # The heavily weighted half behaves differently, so weighting has to matter.
  d$Y[half] <- 1.5 * d$D1[half] + 0.1 * d$D2[half] + 0.1 * d$D3[half] + rnorm(n / 2, sd = 0.4)
  d
}

test_that("weighted dominance reconstructs the weighted model R-squared (H5)", {
  d <- dom_fixture()
  cfg <- list(outcome_var = "Y", driver_vars = c("D1", "D2", "D3"), weight_var = "W")
  invisible(capture.output(r <- run_dominance_analysis(d, cfg)))
  expect_equal(r$status, "PASS")

  weighted_r2 <- summary(lm(Y ~ D1 + D2 + D3, data = d, weights = d$W))$r.squared
  # The identity that defines a dominance decomposition. The sqrt(w) transform
  # missed it: on this fixture it landed near but not on the right number.
  expect_equal(sum(r$result$general_dominance), weighted_r2, tolerance = 1e-8)
  expect_true(isTRUE(r$result$weighted))
  expect_equal(r$result$weight_variable, "W")
})

test_that("a weighted run differs from an unweighted one, and says which it was (H5)", {
  d <- dom_fixture()
  base <- list(outcome_var = "Y", driver_vars = c("D1", "D2", "D3"))
  invisible(capture.output(un <- run_dominance_analysis(d, base)))
  invisible(capture.output(we <- run_dominance_analysis(d, c(base, list(weight_var = "W")))))
  expect_equal(un$status, "PASS")
  expect_equal(we$status, "PASS")
  expect_false(isTRUE(un$result$weighted))
  expect_true(isTRUE(we$result$weighted))

  unweighted_r2 <- summary(lm(Y ~ D1 + D2 + D3, data = d))$r.squared
  expect_equal(sum(un$result$general_dominance), unweighted_r2, tolerance = 1e-8)
  # The heavily weighted half behaves differently, so the two decompositions
  # must disagree about which driver dominates.
  expect_gt(max(abs(un$result$general_dominance - we$result$general_dominance)), 0.01)
})

test_that("the sqrt-of-weights transform is gone from the source (H5)", {
  src <- readLines(file.path(module_dir, "R", "11_dominance.R"))
  # The transform itself is gone. The phrase survives once, inside the comment
  # that explains why it was wrong, so match the code rather than the prose.
  expect_false(any(grepl("w_sqrt", src, fixed = TRUE)))
  expect_false(any(grepl("d_wt", src, fixed = TRUE)))
  expect_false(any(grepl("Pre-weight data", src, fixed = TRUE)))
  expect_equal(sum(grepl("algebraically equivalent", src, fixed = TRUE)), 1)
  expect_true(any(grepl("It is not, for R-squared", src, fixed = TRUE)))
})

test_that("a truncated driver set is disclosed, not silently dropped (H5)", {
  set.seed(4)
  n <- 400
  p <- 18
  d <- as.data.frame(matrix(rnorm(n * p), n, p))
  names(d) <- paste0("D", seq_len(p))
  d$Y <- rowSums(d[, 1:5]) * 0.4 + rnorm(n, sd = 0.6)
  cfg <- list(outcome_var = "Y", driver_vars = paste0("D", seq_len(p)), weight_var = NULL)
  invisible(capture.output(r <- run_dominance_analysis(d, cfg)))
  # Eighteen drivers, fifteen analysed. That is a degraded run, not a clean one.
  expect_equal(r$status, "PARTIAL")
  expect_equal(length(r$result$drivers_omitted), 3)
  expect_match(r$result$truncation_note, "NOT in this table")
  expect_match(r$result$truncation_note, "unmeasured")
  expect_equal(r$result$n_drivers, 15)
})
