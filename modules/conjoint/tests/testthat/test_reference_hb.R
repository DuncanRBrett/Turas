# ==============================================================================
# CONJOINT - REFERENCE GATE: HIERARCHICAL BAYES (bayesm)
# ==============================================================================
# Parameter recovery. Choices are simulated from known population part-worths
# with respondent heterogeneity (SD 0.4 on every contrast), and each estimated
# population contrast must sit within 3 of its own reported posterior SE of
# the truth. An SE reported ten times too small fails this. The module sets no
# seed of its own, so the test does.
# ==============================================================================

source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_reference_mnl.R"), local = TRUE)

test_that("HB recovers known population part-worths within 3 reported SEs", {
  skip_if_not(requireNamespace("bayesm", quietly = TRUE), "bayesm not installed")
  attrs <- list(Brand = c("Alpha", "Beta", "Gamma"), Price = c("10", "20", "30"),
                Size = c("S", "L"))
  truth <- c(BrandBeta = 0.8, BrandGamma = -0.4, Price20 = -0.6, Price30 = -1.3, SizeL = 0.5)
  sim <- cj_ref_simulate_hetero(attrs, truth, n = 150, n_tasks = 10, seed = 5)
  cfg <- sim$config
  cfg$hb_iterations <- 6000; cfg$hb_burnin <- 3000; cfg$hb_thin <- 1; cfg$hb_ncomp <- 1
  set.seed(99)
  out <- capture.output(hb <- suppressMessages(
    estimate_hierarchical_bayes(list(data = sim$data), cfg, verbose = FALSE)))
  est <- hb$coefficients
  se <- hb$std_errors
  key <- c(BrandBeta = "Brand_Beta", BrandGamma = "Brand_Gamma", Price20 = "Price_20",
           Price30 = "Price_30", SizeL = "Size_L")
  expect_true(all(key %in% names(est)), info = paste(names(est), collapse = ", "))
  z <- (est[key] - truth[names(key)]) / se[key]
  expect_true(all(abs(z) < 3), info = paste(names(key), round(z, 2), collapse = "; "))
  expect_true(all(se[key] > 0.02 & se[key] < 0.3), info = paste(round(se[key], 3), collapse = ", "))
  # The posterior covariance now travels with the fit and agrees with the SEs.
  expect_equal(sqrt(diag(hb$vcov))[key], se[key], tolerance = 1e-8)
  # Individual part-worths track each respondent's truth.
  ib <- hb$individual_betas[, key]
  expect_gt(cor(as.vector(ib), as.vector(sim$indiv[, names(key)])), 0.7)
})
