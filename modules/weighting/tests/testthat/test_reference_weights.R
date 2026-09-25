# ==============================================================================
# WEIGHTING - REFERENCE GATE (robustness programme, 25 Sep 2026)
# ==============================================================================
# Every headline number the module prints, checked against an independent
# calculation: arithmetic written out in the comment, a raking loop that shares
# no code with lib/, survey::rake(), or the closed-form GREG solution for linear
# calibration. "The function returns what it returned last week" is not a
# reference; nothing here compares the engine with itself.
#
# Fixture: helper_reference_fixture.R (200 respondents, counts chosen so every
# weight is a clean fraction).
# ==============================================================================

source(file.path(MODULE_DIR, "tests", "testthat", "helper_reference_fixture.R"),
       local = FALSE)

ref_config <- function(tag, ...) {
  paths <- ref_build_config(file.path(tempdir(), paste0("wref_", tag)), ...)
  load_weighting_config(paths$config, verbose = FALSE)
}


# ==============================================================================
# Design weights
# ==============================================================================

test_that("design weights equal N/n normalised to n, worked by hand", {
  # North 30000/100 = 300, South 40000/60 = 666.67, East 30000/40 = 750.
  # Normalised by 200/100000: 0.6, 4/3, 1.5 (see ref_design_weight()).
  data <- ref_survey()
  config <- ref_config("design", specs = ref_spec("dw", "design"),
                       design_targets = ref_design_targets("dw"))

  res <- calculate_design_weights_from_config(data, config, "dw")

  expect_equal(res$weights, ref_design_weight(data$Region), tolerance = 1e-12)
  expect_equal(sum(res$weights), 200, tolerance = 1e-12)
  expect_identical(res$weight_scale, "sample")

  # The stratum table carries the applied weight and the raw N/n beside it.
  s <- res$stratum_summary
  expect_equal(s$weight[s$stratum == "South"], 4 / 3, tolerance = 1e-12)
  expect_equal(s$weight_population_scale[s$stratum == "South"], 2000 / 3,
               tolerance = 1e-12)
})

test_that("grossed design weights stay at N/n and sum to the population", {
  data <- ref_survey()
  config <- ref_config("design_gross", specs = ref_spec("dwg", "design"),
                       design_targets = ref_design_targets("dwg"),
                       advanced = data.frame(weight_name = "dwg", grossing = "Y"))

  res <- calculate_design_weights_from_config(data, config, "dwg")

  expect_equal(res$weights, ref_design_weight_grossed(data$Region), tolerance = 1e-10)
  # 100 x 300 + 60 x 2000/3 + 40 x 750 = 30000 + 40000 + 30000.
  expect_equal(sum(res$weights), 100000, tolerance = 1e-8)
  expect_identical(res$weight_scale, "population")
})


# ==============================================================================
# Cell weights
# ==============================================================================

test_that("cell weights equal target share x n / cell count, worked by hand", {
  data <- ref_survey()
  cells <- ref_cell_targets()
  config <- ref_config("cell", specs = ref_spec("cw", "cell"),
                       cell_targets = cbind(weight_name = "cw", cells))

  res <- calculate_cell_weights_from_config(data, config, "cw")

  expect_equal(res$weights, ref_cell_weight(data$Region, data$Gender),
               tolerance = 1e-12)
  expect_equal(sum(res$weights), 200, tolerance = 1e-12)
})

test_that("an empty target cell's share is redistributed pro rata, worked by hand", {
  # Add West Male at 10% with nobody in it, scaling the six real cells to 90%.
  # Real targets become 12.6, 14.4, 17.1, 18.9, 12.6, 14.4 (each x 0.9), which
  # sum to 90. Redistribution multiplies each by 100/90, which lands exactly on
  # the original 14/16/19/21/14/16, so every weight must equal ref_cell_weight().
  data <- ref_survey()
  cells <- ref_cell_targets()
  cells$target_percent <- cells$target_percent * 0.9
  cells <- rbind(cells, data.frame(Region = "West", Gender = "Male",
                                   target_percent = 10, stringsAsFactors = FALSE))
  config <- ref_config("cell_empty", specs = ref_spec("cw", "cell"),
                       cell_targets = cbind(weight_name = "cw", cells),
                       advanced = data.frame(weight_name = "cw",
                                             allow_empty_targets = "Y"))

  res <- suppressWarnings(calculate_cell_weights_from_config(data, config, "cw"))

  expect_equal(res$weights, ref_cell_weight(data$Region, data$Gender),
               tolerance = 1e-12)
  expect_equal(sum(res$weights), 200, tolerance = 1e-12)
})


# ==============================================================================
# Rim weights
# ==============================================================================

test_that("rim weights equal an independent raking loop and survey::rake()", {
  skip_if_not_installed("survey")
  data <- ref_survey()
  targets <- ref_rim_targets()

  # Wide bounds so raking is unconstrained and has one answer.
  res <- calculate_rim_weights(data, targets, cap_weights = c(0.01, 100))
  hand <- ref_hand_rake(data, targets)

  expect_true(res$converged)
  expect_equal(res$weights, hand, tolerance = 1e-6)

  # survey::rake() is iterative post-stratification, a different routine from
  # the calibrate() the engine calls.
  des <- survey::svydesign(ids = ~1, data = data, weights = rep(1, nrow(data)))
  pop_region <- data.frame(Region = names(targets$Region),
                           Freq = 200 * unname(targets$Region))
  pop_gender <- data.frame(Gender = names(targets$Gender),
                           Freq = 200 * unname(targets$Gender))
  raked <- survey::rake(des, list(~Region, ~Gender), list(pop_region, pop_gender),
                        control = list(maxit = 100, epsilon = 1e-12))
  expect_equal(res$weights, unname(weights(raked)), tolerance = 1e-6)

  # The weighted margins recomputed from the weights, not from the engine table.
  for (v in names(targets)) {
    for (k in names(targets[[v]])) {
      expect_equal(sum(res$weights[data[[v]] == k]) / 200, targets[[v]][[k]],
                   tolerance = 1e-8, info = paste(v, k))
    }
  }
})

test_that("default bounds do not bind on the fixture, so the default run is the same raking answer", {
  skip_if_not_installed("survey")
  data <- ref_survey()
  hand <- ref_hand_rake(data, ref_rim_targets())
  # Hand raking range sits inside [0.3, 3], so the default run must equal it.
  expect_true(min(hand) > 0.3 && max(hand) < 3)

  res <- calculate_rim_weights(data, ref_rim_targets())
  expect_equal(res$weights, hand, tolerance = 1e-6)
})

test_that("linear calibration equals the closed-form GREG weights", {
  skip_if_not_installed("survey")
  # Linear calibration from d = 1 has a closed form (Deville and Sarndal 1992):
  #   w = d (1 + x' lambda),  lambda = (sum d x x')^-1 (t_x - sum d x)
  # computed here with base R linear algebra and nothing from survey.
  data <- ref_survey()
  targets <- ref_rim_targets()
  data_f <- data
  data_f$Region <- factor(data_f$Region, levels = names(targets$Region))
  data_f$Gender <- factor(data_f$Gender, levels = names(targets$Gender))
  X <- model.matrix(~ Region + Gender, data = data_f)
  t_x <- c(200, 200 * targets$Region[["South"]], 200 * targets$Region[["East"]],
           200 * targets$Gender[["Female"]])
  lambda <- solve(crossprod(X), t_x - colSums(X))
  greg <- as.vector(1 + X %*% lambda)

  res <- calculate_rim_weights(data, targets, cap_weights = c(0.01, 100),
                               calibration_method = "linear")

  expect_equal(res$weights, greg, tolerance = 1e-8)
})


# ==============================================================================
# Trimming
# ==============================================================================

test_that("cap trimming then rescale, worked by hand", {
  # w = (1, 1, 1, 1, 6), cap 3: capped (1, 1, 1, 1, 3), sum 7. Rescale by the
  # original sum over the capped sum, 10/7: four weights of 10/7 and one of
  # 30/7 = 4.2857, which is back above the cap (the documented cost).
  w <- c(1, 1, 1, 1, 6)
  spec <- list(weight_name = "dw", method = "design", apply_trimming = "Y",
               trim_method = "cap", trim_value = 3)

  res <- suppressWarnings(apply_trimming_from_config(w, spec))

  expect_equal(res$weights, c(10, 10, 10, 10, 30) / 7, tolerance = 1e-12)
  expect_equal(res$n_trimmed, 1)
  expect_equal(res$rescale_factor, 10 / 7, tolerance = 1e-12)
  expect_equal(res$sum_after, 10, tolerance = 1e-12)
  expect_equal(res$max_after_rescale, 30 / 7, tolerance = 1e-12)
})

test_that("percentile trimming uses the type-7 quantile, worked by hand", {
  # w = 1..10, trim_value 0.8. Type-7 quantile: h = (10 - 1) x 0.8 + 1 = 8.2,
  # so the threshold is 8 + 0.2 x (9 - 8) = 8.2. 9 and 10 are capped to 8.2:
  # capped sum 36 + 16.4 = 52.4 against 55, rescale factor 55 / 52.4.
  w <- as.numeric(1:10)
  spec <- list(weight_name = "dw", method = "design", apply_trimming = "Y",
               trim_method = "percentile", trim_value = 0.8)

  res <- suppressWarnings(apply_trimming_from_config(w, spec))

  expect_equal(unname(res$threshold), 8.2, tolerance = 1e-12)
  expect_equal(res$n_trimmed, 2)
  expect_equal(res$weights, c(1:8, 8.2, 8.2) * 55 / 52.4, tolerance = 1e-12)
  expect_equal(sum(res$weights), 55, tolerance = 1e-12)
})


# ==============================================================================
# Kish effective n, DEFF, efficiency, distribution
# ==============================================================================

test_that("DEFF is exactly 2 on the one-in-five construction, at any scale", {
  # Groups of five: four weigh 0.5 and one weighs 3. Per group sum w = 5 and
  # sum w^2 = 4 x 0.25 + 9 = 10. With 40 groups: sum w = 200, sum w^2 = 400,
  # n_eff = 200^2 / 400 = 100, DEFF = 200 / 100 = 2, efficiency 50%.
  w <- rep(c(0.5, 0.5, 0.5, 0.5, 3), 40)

  d <- diagnose_weights(w, label = "deff2")
  expect_equal(d$effective_sample$effective_n, 100, tolerance = 1e-12)
  expect_equal(d$effective_sample$design_effect, 2, tolerance = 1e-12)
  expect_equal(d$effective_sample$efficiency, 50, tolerance = 1e-12)

  # Grossed to a population (x 1000): Kish is scale-free, so nothing moves.
  g <- diagnose_weights(w * 1000, label = "deff2_grossed")
  expect_equal(g$effective_sample$effective_n, 100, tolerance = 1e-9)
  expect_equal(g$effective_sample$design_effect, 2, tolerance = 1e-12)

  # And it is the number tabs prints as the effective base for the same
  # weights: the shared definition in modules/shared/lib/effective_n.R.
  source(file.path(TURAS_ROOT, "modules", "shared", "lib", "effective_n.R"), local = TRUE)
  expect_equal(d$effective_sample$effective_n, calculate_effective_n(w), tolerance = 1e-12)
  expect_equal(g$effective_sample$effective_n, calculate_effective_n(w * 1000), tolerance = 1e-9)
})

test_that("the design weight's Kish figures, worked by hand", {
  # Weights 0.6 (x100), 4/3 (x60), 1.5 (x40). sum w = 200.
  # sum w^2 = 100 x 0.36 + 60 x 16/9 + 40 x 2.25 = 36 + 320/3 + 90 = 698/3.
  # n_eff = 40000 / (698/3) = 120000/698 = 171.9198; DEFF = 698/600 = 1.16333.
  w <- ref_design_weight(ref_survey()$Region)
  d <- diagnose_weights(w, label = "dw")

  expect_equal(d$effective_sample$effective_n, 120000 / 698, tolerance = 1e-12)
  expect_equal(d$effective_sample$design_effect, 698 / 600, tolerance = 1e-12)
  expect_equal(d$effective_sample$efficiency, 100 * 600 / 698, tolerance = 1e-12)
  expect_equal(d$effective_sample$effective_n_display, 172)
})

test_that("distribution statistics, worked by hand", {
  # w = (1, 2, 3, 4, 10). Type-7 quartiles: Q1 = 2, median 3, Q3 = 4.
  # Mean 4. Sample SD: squared deviations 9 + 4 + 1 + 0 + 36 = 50, / 4 = 12.5,
  # SD = sqrt(12.5) = 3.5355, CV = 3.5355 / 4 = 0.8839.
  # Kish: sum 20, sum of squares 130, n_eff = 400/130, DEFF = 5 x 130/400 = 1.625.
  w <- c(1, 2, 3, 4, 10)
  d <- diagnose_weights(w, label = "dist")

  expect_equal(d$distribution$min, 1)
  expect_equal(d$distribution$q1, 2)
  expect_equal(d$distribution$median, 3)
  expect_equal(d$distribution$q3, 4)
  expect_equal(d$distribution$max, 10)
  expect_equal(d$distribution$mean, 4)
  expect_equal(d$distribution$sd, sqrt(12.5), tolerance = 1e-12)
  expect_equal(d$distribution$cv, sqrt(12.5) / 4, tolerance = 1e-12)
  expect_equal(d$effective_sample$effective_n, 400 / 130, tolerance = 1e-12)
  expect_equal(d$effective_sample$design_effect, 1.625, tolerance = 1e-12)
  # Extreme-weight counts: 4 and 10 are above 3; only 10 is above 5.
  expect_equal(d$extreme_weights$n_gt_3, 2)
  expect_equal(d$extreme_weights$n_gt_5, 1)
})

test_that("NA and zero weights are left out of Kish and counted", {
  # (NA, 0, 1, 1, 3): valid (1, 1, 3), n_eff = 25/11, DEFF = 3 x 11/25 = 1.32.
  d <- diagnose_weights(c(NA, 0, 1, 1, 3), label = "na")

  expect_equal(d$sample_size$n_total, 5)
  expect_equal(d$sample_size$n_valid, 3)
  expect_equal(d$sample_size$n_na, 1)
  expect_equal(d$sample_size$n_zero, 1)
  expect_equal(d$effective_sample$effective_n, 25 / 11, tolerance = 1e-12)
  expect_equal(d$effective_sample$design_effect, 1.32, tolerance = 1e-12)
})
