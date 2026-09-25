# ==============================================================================
# CONJOINT - REFERENCE GATE: AGGREGATE MNL
# ==============================================================================
# The module's default engine is mlogit, so mlogit cannot be its reference.
# Both aggregate paths (mlogit, and the survival::clogit fallback) are checked
# against a multinomial logit written from its likelihood
# (helper_reference_mnl.R), and against each other.
#
#   P(a chosen in set s) = exp(x_a b) / sum_{j in s} exp(x_j b)
#   x = dummy coding, first listed level of each attribute = 0
# ==============================================================================

source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_reference_mnl.R"), local = TRUE)

.cbc <- function(seed = 7, n = 150) generate_synthetic_cbc(n_respondents = n, n_tasks = 8,
                                                            n_alts = 3, seed = seed)

test_that("mlogit path: coefficients and SEs equal the hand-written MNL", {
  skip_if_not(requireNamespace("mlogit", quietly = TRUE), "mlogit not installed")
  s <- .cbc()
  ref <- cj_ref_mnl(s$data, s$attributes, "task_id")
  m <- estimate_with_mlogit(s$data, s$config, verbose = FALSE)
  expect_equal(unname(m$coefficients[names(ref$coef)]), unname(ref$coef), tolerance = 1e-5)
  expect_equal(unname(m$std_errors[names(ref$coef)]), unname(ref$se), tolerance = 1e-4)
  expect_equal(unname(m$loglik["fitted"]), ref$loglik, tolerance = 1e-6)
})

test_that("clogit fallback: coefficients and SEs equal the hand-written MNL and mlogit", {
  skip_if_not(requireNamespace("survival", quietly = TRUE), "survival not installed")
  s <- .cbc(seed = 8)
  ref <- cj_ref_mnl(s$data, s$attributes, "task_id")
  cl <- estimate_with_clogit(s$data, s$config, verbose = FALSE)
  expect_equal(unname(cl$coefficients[names(ref$coef)]), unname(ref$coef), tolerance = 1e-5)
  expect_equal(unname(cl$std_errors[names(ref$coef)]), unname(ref$se), tolerance = 1e-4)
  skip_if_not(requireNamespace("mlogit", quietly = TRUE), "mlogit not installed")
  ml <- estimate_with_mlogit(s$data, s$config, verbose = FALSE)
  expect_equal(unname(cl$coefficients[names(ref$coef)]),
               unname(ml$coefficients[names(ref$coef)]), tolerance = 1e-5)
})

test_that("McFadden R-squared is 1 - LL / LL0 with LL0 the equal-shares likelihood", {
  skip_if_not(requireNamespace("mlogit", quietly = TRUE), "mlogit not installed")
  s <- .cbc(seed = 9)
  ref <- cj_ref_mnl(s$data, s$attributes, "task_id")
  # 1200 sets of 3 alternatives: LL0 = 1200 x log(1/3).
  expect_equal(ref$loglik_null, 1200 * log(1 / 3))
  m <- estimate_with_mlogit(s$data, s$config, verbose = FALSE)
  u <- calculate_utilities(m, s$config, verbose = FALSE)
  s$config$zero_center_utilities <- TRUE
  d <- calculate_model_diagnostics(m, list(data = s$data, n_respondents = 150), u,
                                   calculate_attribute_importance(u, s$config, verbose = FALSE),
                                   s$config, verbose = FALSE)
  expect_equal(unname(d$fit_statistics$mcfadden_r2), 1 - ref$loglik / ref$loglik_null, tolerance = 1e-6)
  # The clogit fallback reports the same null, so the same study gets the
  # same R-squared whichever engine ran. mlogit's own "null" fits a constant
  # per alternative position, which is not the null of a no-constant model.
  cl <- estimate_with_clogit(s$data, s$config, verbose = FALSE)
  expect_equal(unname(cl$loglik["null"]), ref$loglik_null, tolerance = 1e-6)
  expect_equal(unname(m$loglik["null"]), ref$loglik_null, tolerance = 1e-6)
})
