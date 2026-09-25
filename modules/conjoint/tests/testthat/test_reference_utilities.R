# ==============================================================================
# CONJOINT - REFERENCE GATE: PART-WORTH TABLE (aggregate path)
# ==============================================================================
# The Part-Worth Utilities sheet prints zero-centred utilities. Each centred
# level is a linear combination of the estimated contrasts with the baseline:
#
#   u = A b,  b = (0, b_2, ..., b_L),  A = I - 11'/L
#   Var(u) = A[, 2:L] V A[, 2:L]'     (V = vcov of b_2..b_L)
#
# so every level, the baseline included, has its own SE, and the CI printed
# next to a centred utility is u +/- z SE(u). Before Duncan's ruling of
# 25 Sep 2026 the sheet printed the contrast SE (the level against the
# baseline) and a contrast CI shifted by the centring mean, with no CI at all
# for the baseline. The contrast SE is still what WTP needs, so it is kept
# in its own column, SE_vs_Baseline.
# ==============================================================================

source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_reference_mnl.R"), local = TRUE)

.fit <- function(seed = 11) {
  s <- generate_synthetic_cbc(n_respondents = 150, n_tasks = 8, n_alts = 3, seed = seed)
  m <- estimate_with_clogit(s$data, s$config, verbose = FALSE)
  list(s = s, m = m, ref = cj_ref_mnl(s$data, s$attributes, "task_id"))
}

test_that("centred part-worths carry their own SE and CI, the baseline included", {
  skip_if_not(requireNamespace("survival", quietly = TRUE), "survival not installed")
  f <- .fit()
  cfg <- f$s$config; cfg$zero_center_utilities <- TRUE
  u <- calculate_utilities(f$m, cfg, verbose = FALSE)
  z <- qnorm(0.975)
  for (a in names(f$s$attributes)) {
    lv <- f$s$attributes[[a]]
    r <- cj_ref_centred(f$ref$coef, f$ref$vcov, a, lv)
    rows <- u[u$Attribute == a, ][match(lv, u$Level[u$Attribute == a]), ]
    expect_equal(rows$Utility, unname(r$utility), tolerance = 1e-5, info = a)
    expect_equal(rows$Std_Error, unname(r$se), tolerance = 1e-4, info = a)
    expect_equal(rows$CI_Lower, unname(r$utility - z * r$se), tolerance = 1e-4, info = a)
    expect_equal(rows$CI_Upper, unname(r$utility + z * r$se), tolerance = 1e-4, info = a)
    expect_equal(rows$p_value, unname(2 * pnorm(-abs(r$utility / r$se))), tolerance = 1e-4, info = a)
    # The contrast with the baseline keeps its own SE for WTP.
    expect_equal(rows$SE_vs_Baseline[-1], unname(f$ref$se[paste0(a, lv[-1])]), tolerance = 1e-4, info = a)
    expect_true(is.na(rows$SE_vs_Baseline[1]) || rows$SE_vs_Baseline[1] == 0, info = a)
    expect_true(is.finite(rows$CI_Lower[1]), info = paste(a, "baseline CI"))
  }
})

test_that("with centring off, the table is the raw contrasts and the baseline has no CI", {
  skip_if_not(requireNamespace("survival", quietly = TRUE), "survival not installed")
  f <- .fit(seed = 12)
  cfg <- f$s$config; cfg$zero_center_utilities <- FALSE
  u <- calculate_utilities(f$m, cfg, verbose = FALSE)
  z <- qnorm(0.975)
  a <- "Brand"; lv <- f$s$attributes[[a]]
  rows <- u[u$Attribute == a, ][match(lv, u$Level[u$Attribute == a]), ]
  nm <- paste0(a, lv[-1])
  expect_equal(rows$Utility, c(0, unname(f$ref$coef[nm])), tolerance = 1e-5)
  expect_equal(rows$Std_Error[-1], unname(f$ref$se[nm]), tolerance = 1e-4)
  expect_equal(rows$CI_Lower[-1], unname(f$ref$coef[nm] - z * f$ref$se[nm]), tolerance = 1e-4)
  expect_true(is.na(rows$CI_Lower[1]))
})

test_that("HB path: centred part-worths get SEs from the posterior covariance", {
  # A hand-built HB result: one attribute, three levels, baseline A.
  # Posterior mean contrasts b = (0, 0.6, -0.3), posterior covariance of
  # (b_B, b_C) V = [0.04 0.01; 0.01 0.09].
  # Centred u = b - mean(b) = (-0.1, 0.5, -0.4).
  # A[, 2:3] = [-1/3 -1/3; 2/3 -1/3; -1/3 2/3]
  # Var(u_A) = (0.04 + 2 x 0.01 + 0.09) / 9 = 0.15 / 9     -> SE 0.129099
  # Var(u_B) = (4 x 0.04 - 4 x 0.01 + 0.09) / 9 = 0.21 / 9 -> SE 0.152753
  # Var(u_C) = (0.04 - 4 x 0.01 + 4 x 0.09) / 9 = 0.36 / 9 -> SE 0.2
  cfg <- list(
    attributes = data.frame(AttributeName = "Brand", NumLevels = 3, LevelNames = "A,B,C",
                            stringsAsFactors = FALSE),
    zero_center_utilities = TRUE, confidence_level = 0.95)
  cfg$attributes$levels_list <- list(c("A", "B", "C"))
  V <- matrix(c(0.04, 0.01, 0.01, 0.09), 2, dimnames = list(c("Brand_B", "Brand_C"), c("Brand_B", "Brand_C")))
  hb <- list(coefficients = c(Brand_B = 0.6, Brand_C = -0.3),
             std_errors = c(Brand_B = 0.2, Brand_C = 0.3),
             heterogeneity_sd = c(Brand_B = 1, Brand_C = 1),
             col_names = c("Brand_B", "Brand_C"), vcov = V)
  u <- extract_hb_utilities(hb, cfg, verbose = FALSE)
  u <- u[match(c("A", "B", "C"), u$Level), ]
  expect_equal(u$Utility, c(-0.1, 0.5, -0.4), tolerance = 1e-12)
  expect_equal(u$Std_Error, sqrt(c(0.15, 0.21, 0.36) / 9), tolerance = 1e-9)
  z <- qnorm(0.975)
  expect_equal(u$CI_Lower, u$Utility - z * u$Std_Error, tolerance = 1e-9)
  expect_equal(u$SE_vs_Baseline, c(NA, 0.2, 0.3))
})
