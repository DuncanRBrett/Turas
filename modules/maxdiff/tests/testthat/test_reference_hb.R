# ==============================================================================
# MAXDIFF - REFERENCE GATE: HIERARCHICAL BAYES
# ==============================================================================
# Stan HB is checked by parameter recovery: choices are simulated from known
# population utilities with respondent heterogeneity, and every estimated
# population mean must land within 3 of its own reported HB_Mean_SE of the
# truth. That one check tests both the estimate and the SE: an SE reported
# ten times too small fails it.
#
# The empirical-Bayes fallback is not a model, so its reference is its stated
# formula worked by hand on three respondents.
# ==============================================================================

source(file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "testthat",
                 "helper_reference_fixture.R"), local = TRUE)

.stan_ready <- function() {
  requireNamespace("cmdstanr", quietly = TRUE) &&
    !inherits(try(cmdstanr::cmdstan_path(), silent = TRUE), "try-error")
}

test_that("Stan HB recovers known population utilities within 3 reported SEs", {
  skip_if_not(.stan_ready(), "cmdstanr or CmdStan not installed")

  # Truth relative to the designated anchor B (B = 0). Anchor is not last,
  # so the reorder-and-map-back path is exercised too.
  truth <- c(A = 1.2, B = 0, C = -0.4, D = 0.6, E = -1.0, F = -1.6)
  sim <- md_ref_simulate(truth, n_resp = 80, n_tasks = 8, items_per_task = 4,
                         indiv_sd = 0.5, seed = 31)
  items <- md_ref_items(names(truth), anchor = "B")
  config <- list(project_settings = list(Seed = 7L),
                 output_settings = list(HB_Iterations = 500L, HB_Warmup = 500L,
                                        HB_Chains = 2L))
  out <- capture.output(res <- suppressMessages(
    fit_hb_model(sim$long, items, config, verbose = FALSE)))
  expect_equal(res$model_fit$method, "cmdstanr")

  pop <- res$population_utilities
  pop <- pop[match(names(truth), pop$Item_ID), ]
  free <- pop$Item_ID != "B"
  expect_equal(pop$HB_Utility_Mean[!free], 0)
  z <- (pop$HB_Utility_Mean[free] - truth[free]) / pop$HB_Mean_SE[free]
  expect_true(all(abs(z) < 3), info = paste(round(z, 2), collapse = ", "))
  # The SE is the precision of a mean over 80 respondents, not the spread.
  expect_true(all(pop$HB_Mean_SE[free] > 0.03 & pop$HB_Mean_SE[free] < 0.3))

  # Individual utilities track each respondent's true utilities.
  iu <- res$individual_utilities
  iu <- iu[match(rownames(sim$indiv), iu$resp_id), names(truth)]
  expect_gt(cor(as.vector(as.matrix(iu[, free])), as.vector(sim$indiv[, free])), 0.85)
})

test_that("empirical-Bayes fallback matches its shrinkage formula by hand", {
  # Three respondents, one task each, items A B C all shown.
  #   R1 best A worst C -> bw (A, B, C) = ( 1,  0, -1)
  #   R2 best A worst B -> bw           = ( 1, -1,  0)
  #   R3 best B worst C -> bw           = ( 0,  1, -1)
  # Population mean: A 2/3, B 0, C -2/3.
  # Variance across respondents (n - 1): A 1/3, B 1, C 1/3.
  # within = mean(var) / n_resp = (5/9) / 3 = 5/27.
  # Shrinkage var / (var + within): A 9/14, B 27/32, C 9/14.
  # R1's A = 2/3 + 9/14 * (1 - 2/3) = 37/42.
  # R2's B = 0 + 27/32 * (-1 - 0) = -27/32.
  # R3's C = -2/3 + 9/14 * (-1 + 2/3) = -2/3 - 3/14 = -37/42.
  mk <- function(r, best, worst) {
    data.frame(resp_id = r, version = 1L, task = 1L, item_id = c("A", "B", "C"),
               position = 1:3, is_best = as.integer(c("A", "B", "C") == best),
               is_worst = as.integer(c("A", "B", "C") == worst), weight = 1,
               stringsAsFactors = FALSE)
  }
  long <- rbind(mk("R1", "A", "C"), mk("R2", "A", "B"), mk("R3", "B", "C"))
  long$obs_id <- seq_len(nrow(long))
  res <- fit_approximate_hb(long, md_ref_items(c("A", "B", "C")), list(), verbose = FALSE)

  pop <- res$population_utilities
  expect_equal(pop$HB_Utility_Mean[match(c("A", "B", "C"), pop$Item_ID)],
               c(2 / 3, 0, -2 / 3), tolerance = 1e-12)
  iu <- res$individual_utilities
  expect_equal(iu$A[iu$resp_id == "R1"], 37 / 42, tolerance = 1e-12)
  expect_equal(iu$B[iu$resp_id == "R2"], -27 / 32, tolerance = 1e-12)
  expect_equal(iu$C[iu$resp_id == "R3"], -37 / 42, tolerance = 1e-12)
  expect_true(all(is.na(pop$HB_Mean_SE)))
})
