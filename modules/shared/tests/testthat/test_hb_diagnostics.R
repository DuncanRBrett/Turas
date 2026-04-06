# ==============================================================================
# TESTS: hb_diagnostics.R
# ==============================================================================
# Tests for the shared HB/MCMC convergence diagnostics module.
# Covers: NULL input, well-converged chains, R-hat, ESS, autocorrelation,
#         Geweke, single-chain warning, boundary cases, edge cases.
# ==============================================================================

library(testthat)

# Source the diagnostics module
diag_path <- file.path(
  dirname(dirname(dirname(getwd()))),
  "shared", "lib", "hb_diagnostics.R"
)
if (!file.exists(diag_path)) {
  diag_path <- file.path(getwd(), "modules", "shared", "lib", "hb_diagnostics.R")
}
if (file.exists(diag_path)) source(diag_path)


# ==============================================================================
# HELPERS
# ==============================================================================

#' Create a well-behaved independent chain (iid normal draws)
make_iid_chain <- function(n_iter = 1000, n_params = 5, seed = 2) {
  set.seed(seed)
  mat <- matrix(rnorm(n_iter * n_params), nrow = n_iter, ncol = n_params)
  colnames(mat) <- paste0("beta_", seq_len(n_params))
  mat
}

#' Create a random-walk chain with high autocorrelation
make_random_walk <- function(n_iter = 1000, n_params = 3, step_sd = 0.01, seed = 99) {
  set.seed(seed)
  mat <- matrix(NA_real_, nrow = n_iter, ncol = n_params)
  mat[1, ] <- rnorm(n_params)
  for (i in 2:n_iter) {
    mat[i, ] <- mat[i - 1, ] + rnorm(n_params, sd = step_sd)
  }
  colnames(mat) <- paste0("rw_", seq_len(n_params))
  mat
}

#' Create a chain with a mean shift (first half vs second half)
make_shifted_chain <- function(n_iter = 1000, n_params = 5, shift = 10, seed = 123) {
  set.seed(seed)
  mid <- floor(n_iter / 2)
  first_half  <- matrix(rnorm(mid * n_params, mean = 0), nrow = mid, ncol = n_params)
  second_half <- matrix(rnorm((n_iter - mid) * n_params, mean = shift), nrow = n_iter - mid, ncol = n_params)
  mat <- rbind(first_half, second_half)
  colnames(mat) <- paste0("shift_", seq_len(n_params))
  mat
}

#' Create a chain that trends upward (non-stationary)
make_trending_chain <- function(n_iter = 1000, n_params = 3, trend = 0.05, seed = 77) {
  set.seed(seed)
  mat <- matrix(NA_real_, nrow = n_iter, ncol = n_params)
  for (j in seq_len(n_params)) {
    mat[, j] <- trend * seq_len(n_iter) + rnorm(n_iter, sd = 1)
  }
  colnames(mat) <- paste0("trend_", seq_len(n_params))
  mat
}


# ==============================================================================
# 1. NULL / EMPTY INPUT HANDLING
# ==============================================================================

test_that("NULL draws returns non-converged with informative message", {
  result <- check_hb_convergence(NULL, verbose = FALSE)

  expect_false(result$converged)
  expect_true(nchar(result$summary) > 0)
  expect_true(grepl("No MCMC draws", result$summary))
  expect_null(result$gelman_rubin)
  expect_null(result$effective_n)
  expect_null(result$geweke)
  expect_null(result$autocorrelation)
})


# ==============================================================================
# 2. WELL-CONVERGED CHAIN
# ==============================================================================

test_that("well-converged iid chain passes all diagnostics", {
  draws <- make_iid_chain(n_iter = 1000, n_params = 5, seed = 2)
  result <- check_hb_convergence(draws, verbose = FALSE)

  expect_true(result$converged)
  expect_true(grepl("converged", result$summary, ignore.case = TRUE))

  # R-hat should be close to 1 for iid draws
  expect_true(all(result$gelman_rubin$rhat < 1.1))

  # ESS should be high for independent draws
  expect_true(all(result$effective_n$ess >= 100))

  # No significant Geweke z-scores expected (most should pass)
  # Allow a few false positives at 5% level, but not all
  n_sig <- sum(abs(result$geweke$z_score) > 1.96, na.rm = TRUE)
  expect_true(n_sig < ncol(draws))

  # Autocorrelation should be low
  expect_true(all(result$autocorrelation$lag1_ac < 0.9, na.rm = TRUE))

  # No recommendations for a well-converged chain
  expect_equal(length(result$recommendations), 0)
})


# ==============================================================================
# 3. NON-CONVERGED CHAIN (R-HAT)
# ==============================================================================

test_that("chain with mean shift triggers R-hat failure", {
  draws <- make_shifted_chain(n_iter = 1000, n_params = 5, shift = 10, seed = 123)
  result <- check_hb_convergence(draws, verbose = FALSE)

  expect_false(result$converged)

  # Split-chain R-hat should detect the shift
  expect_true(any(result$gelman_rubin$rhat > 1.1, na.rm = TRUE))

  # Should have a recommendation about R-hat
  rhat_rec <- grep("R-hat", result$recommendations, value = TRUE)
  expect_true(length(rhat_rec) > 0)
})


# ==============================================================================
# 4. NON-CONVERGED CHAIN (ESS) - C1 FIX
# ==============================================================================

test_that("random-walk chain triggers ESS failure even if only some parameters are bad", {
  # Random walk with tiny steps produces very high autocorrelation and low ESS.
  # The C1 fix ensures ANY parameter with ESS < 100 triggers non-convergence,
  # not just a percentage threshold.
  draws <- make_random_walk(n_iter = 200, n_params = 3, step_sd = 0.01, seed = 99)
  result <- check_hb_convergence(draws, verbose = FALSE)

  # At least one parameter should have ESS < 100
  expect_true(any(result$effective_n$ess < 100))

  # Must be flagged as non-converged
  expect_false(result$converged)

  # Should have ESS recommendation
  ess_rec <- grep("ESS", result$recommendations, value = TRUE)
  expect_true(length(ess_rec) > 0)
})


# ==============================================================================
# 5. SINGLE-CHAIN R-HAT WARNING (C2 FIX)
# ==============================================================================

test_that("split-chain R-hat emits single-chain limitation warning", {
  draws <- make_iid_chain(n_iter = 100, n_params = 2, seed = 10)

  # The warning is emitted via message() inside calculate_split_rhat,
  # which is called during check_hb_convergence
  expect_message(
    check_hb_convergence(draws, verbose = FALSE),
    "single chain"
  )
})


# ==============================================================================
# 6. HIGH AUTOCORRELATION DETECTION
# ==============================================================================

test_that("highly autocorrelated chain is detected and causes non-convergence", {
  # Create chain with extreme autocorrelation (AR(1) with rho near 1)
  set.seed(55)
  n_iter <- 500
  n_params <- 3
  mat <- matrix(NA_real_, nrow = n_iter, ncol = n_params)
  mat[1, ] <- rnorm(n_params)
  for (i in 2:n_iter) {
    mat[i, ] <- 0.98 * mat[i - 1, ] + rnorm(n_params, sd = 0.1)
  }
  colnames(mat) <- paste0("ar_", seq_len(n_params))

  result <- check_hb_convergence(mat, verbose = FALSE)

  # Lag-1 autocorrelation should be > 0.9
  expect_true(any(result$autocorrelation$lag1_ac > 0.9, na.rm = TRUE))

  # Must cause non-convergence (not just a warning)
  expect_false(result$converged)

  # Should have autocorrelation recommendation
  ac_rec <- grep("autocorrelation|thinning", result$recommendations,
                 value = TRUE, ignore.case = TRUE)
  expect_true(length(ac_rec) > 0)
})


# ==============================================================================
# 7. GEWEKE NON-STATIONARITY
# ==============================================================================

test_that("trending chain triggers Geweke failure and non-convergence", {
  draws <- make_trending_chain(n_iter = 1000, n_params = 3, trend = 0.05, seed = 77)
  result <- check_hb_convergence(draws, verbose = FALSE)

  # Geweke z-scores should be significant for trending parameters
  expect_true(any(abs(result$geweke$z_score) > 1.96, na.rm = TRUE))

  # Must cause non-convergence
  expect_false(result$converged)

  # Should have Geweke recommendation
  geweke_rec <- grep("Geweke|stationarity", result$recommendations,
                     value = TRUE, ignore.case = TRUE)
  expect_true(length(geweke_rec) > 0)
})


# ==============================================================================
# 8. ESS BOUNDARY CASE
# ==============================================================================

test_that("ESS near threshold of 100 is handled correctly", {
  # Create a chain with moderate autocorrelation that puts ESS near the boundary.
  # AR(1) with rho ~ 0.8 on 500 samples gives ESS roughly ~55-140 depending on

  # the parameter, so some may land near 100.
  set.seed(202)
  n_iter <- 500
  n_params <- 5
  mat <- matrix(NA_real_, nrow = n_iter, ncol = n_params)
  mat[1, ] <- rnorm(n_params)

  # Mix of autocorrelation strengths: some will be above 100, some below
  rhos <- c(0.85, 0.80, 0.70, 0.60, 0.50)
  for (j in seq_len(n_params)) {
    for (i in 2:n_iter) {
      mat[i, j] <- rhos[j] * mat[i - 1, j] + rnorm(1, sd = sqrt(1 - rhos[j]^2))
    }
  }
  colnames(mat) <- paste0("bnd_", seq_len(n_params))

  result <- check_hb_convergence(mat, verbose = FALSE)

  # Verify ESS values are computed and finite

  expect_true(all(is.finite(result$effective_n$ess)))
  expect_true(all(result$effective_n$ess > 0))

  # The highly autocorrelated parameters should have lower ESS
  ess_vals <- result$effective_n$ess
  # beta_1 (rho=0.85) should have lower ESS than beta_5 (rho=0.50)
  expect_true(ess_vals[1] < ess_vals[5])

  # If any parameter is below 100, converged must be FALSE
  if (any(ess_vals < 100)) {
    expect_false(result$converged)
  }
})


# ==============================================================================
# 9. ZERO-VARIANCE CHAIN
# ==============================================================================

test_that("constant chain (zero variance) is handled gracefully", {
  n_iter <- 200
  n_params <- 3
  mat <- matrix(5.0, nrow = n_iter, ncol = n_params)
  colnames(mat) <- paste0("const_", seq_len(n_params))

  # Should not error (no division by zero)
  expect_no_error(
    result <- check_hb_convergence(mat, verbose = FALSE)
  )

  # R-hat should be 1.0 (W = 0 path returns 1.0)
  expect_true(all(result$gelman_rubin$rhat == 1.0))

  # ESS and other diagnostics should be finite or NA, not NaN/Inf
  if (!is.null(result$effective_n)) {
    expect_true(all(is.finite(result$effective_n$ess) | is.na(result$effective_n$ess)))
  }
})


# ==============================================================================
# 10. SINGLE-PARAMETER DRAWS
# ==============================================================================

test_that("single-column matrix works correctly", {
  set.seed(33)
  mat <- matrix(rnorm(500), ncol = 1)
  colnames(mat) <- "solo_param"

  expect_no_error(
    result <- check_hb_convergence(mat, verbose = FALSE)
  )

  # Should return all diagnostic components
  expect_true(!is.null(result$gelman_rubin))
  expect_true(!is.null(result$effective_n))
  expect_true(!is.null(result$geweke))
  expect_true(!is.null(result$autocorrelation))

  # Each diagnostic should have exactly one row
  expect_equal(nrow(result$gelman_rubin), 1)
  expect_equal(nrow(result$effective_n), 1)
  expect_equal(nrow(result$geweke), 1)
  expect_equal(nrow(result$autocorrelation), 1)
})


# ==============================================================================
# 11. VERY SHORT CHAIN
# ==============================================================================

test_that("very short chain (10 iterations) is handled gracefully", {
  set.seed(88)
  mat <- matrix(rnorm(10 * 3), nrow = 10, ncol = 3)
  colnames(mat) <- paste0("short_", 1:3)

  expect_no_error(
    result <- check_hb_convergence(mat, verbose = FALSE)
  )

  # Should return a result with all diagnostic fields present
  expect_true(is.logical(result$converged))
  expect_true(!is.null(result$gelman_rubin))
  expect_true(!is.null(result$effective_n))

  # ESS cannot exceed the number of iterations
  expect_true(all(result$effective_n$ess <= 10))
})


# ==============================================================================
# DIAGNOSTIC RETURN STRUCTURE
# ==============================================================================

test_that("return structure has all expected fields", {
  draws <- make_iid_chain(n_iter = 200, n_params = 2, seed = 1)
  result <- check_hb_convergence(draws, verbose = FALSE)

  expect_true("converged"       %in% names(result))
  expect_true("gelman_rubin"    %in% names(result))
  expect_true("effective_n"     %in% names(result))
  expect_true("geweke"          %in% names(result))
  expect_true("autocorrelation" %in% names(result))
  expect_true("summary"         %in% names(result))
  expect_true("recommendations" %in% names(result))

  # Check column names in diagnostic data frames
  expect_true("rhat"     %in% names(result$gelman_rubin))
  expect_true("ess"      %in% names(result$effective_n))
  expect_true("z_score"  %in% names(result$geweke))
  expect_true("lag1_ac"  %in% names(result$autocorrelation))
})

test_that("verbose output does not error", {
  draws <- make_iid_chain(n_iter = 200, n_params = 2, seed = 1)

  expect_no_error(
    capture.output(
      result <- check_hb_convergence(draws, verbose = TRUE),
      type = "output"
    )
  )
  expect_true(is.logical(result$converged))
})
