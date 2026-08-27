# ==============================================================================
# TESTS: BEST-WORST ESTIMATION (review finding C2, H2)
# ==============================================================================
#
# The existing test_bws.R covers conversion, validation and the template, but
# never estimates a model — which is how C2 survived: the "simultaneous"
# estimator stacks best-tasks and worst-tasks with no sign reversal on the
# worst design, so one beta has to maximise P(best) and P(worst) at once and
# every coefficient is dragged toward zero. It reported success.
#
# H2: estimation_method = "best_worst" is offered by the template and
# implemented by the engine, but the config validator refused it.
# ==============================================================================

test_that("C2: bw_method = 'simultaneous' refuses instead of returning attenuated estimates", {
  skip_if_not_installed("mlogit")

  bws <- generate_bws_data(n_respondents = 20, n_tasks = 6, seed = 5)
  data_list <- list(data = bws$data, n_alternatives_per_set = 3)

  cond <- tryCatch(
    {
      suppressWarnings(capture.output(
        estimate_best_worst_model(data_list, bws$config,
                                  method = "simultaneous", verbose = FALSE),
        type = "output"
      ))
      NULL
    },
    turas_refusal = function(e) e
  )

  expect_false(is.null(cond))
  expect_equal(cond$code, "CALC_BW_SIMULTANEOUS_UNIMPLEMENTED")
  # The refusal must name the fix, not just complain.
  expect_true(any(grepl("sequential", cond$how_to_fix, fixed = TRUE)))
})

test_that("C2: sequential best-worst recovers the sign and rank of known utilities", {
  skip_if_not_installed("mlogit")

  bws <- generate_bws_data(n_respondents = 120, n_tasks = 10, seed = 77)
  data_list <- list(data = bws$data, n_alternatives_per_set = 3)

  suppressWarnings(capture.output(
    model <- estimate_best_worst_model(data_list, bws$config,
                                       method = "sequential", verbose = FALSE),
    type = "output"
  ))

  expect_true(isTRUE(model$is_best_worst))
  expect_equal(model$best_worst_method, "sequential")

  coefs <- model$coefficients
  expect_true(length(coefs) >= 4)

  # True utilities: BrandBeta = +0.8, BrandGamma = -0.5,
  #                 Price$20  = -0.4, Price$30   = -1.0
  find_coef <- function(pattern) {
    idx <- grep(pattern, names(coefs), fixed = TRUE)
    if (length(idx) == 0) return(NA_real_)
    unname(coefs[idx[1]])
  }

  beta   <- find_coef("Beta")
  gamma  <- find_coef("Gamma")
  p20    <- find_coef("$20")
  p30    <- find_coef("$30")

  expect_false(anyNA(c(beta, gamma, p20, p30)))

  # Signs
  expect_gt(beta, 0)
  expect_lt(gamma, 0)
  expect_lt(p20, 0)
  expect_lt(p30, 0)

  # Rank: Beta is the most preferred, $30 the least
  expect_equal(names(coefs)[which.max(coefs)], names(coefs)[grep("Beta", names(coefs), fixed = TRUE)[1]])
  expect_lt(p30, p20)
})

test_that("H2: estimation_method = 'best_worst' passes config validation", {
  settings <- list(
    estimation_method = "best_worst",
    respondent_id_column = "resp_id",
    choice_set_column = "choice_set_id",
    chosen_column = "chosen"
  )
  attributes_df <- data.frame(
    AttributeName = c("Brand", "Price"),
    NumLevels = c(3L, 3L),
    LevelNames = c("Alpha,Beta,Gamma", "$10,$20,$30"),
    stringsAsFactors = FALSE
  )

  v <- validate_config(settings, attributes_df)

  expect_false(any(grepl("estimation_method must be one of", v$errors %||% character(0))))
})

test_that("H2: an unknown estimation_method still fails validation", {
  settings <- list(estimation_method = "definitely_not_a_method")
  attributes_df <- data.frame(
    AttributeName = c("Brand", "Price"),
    NumLevels = c(3L, 3L),
    LevelNames = c("Alpha,Beta,Gamma", "$10,$20,$30"),
    stringsAsFactors = FALSE
  )

  v <- validate_config(settings, attributes_df)

  expect_true(any(grepl("estimation_method must be one of", v$errors %||% character(0))))
  expect_true(any(grepl("best_worst", v$errors %||% character(0))))
})
