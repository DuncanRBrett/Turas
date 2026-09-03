# ==============================================================================
# TURAS PRICING MODULE - ENGINE HONESTY TESTS (review C1, C2, C3, H3-H7, M1, M5, M14)
# ==============================================================================
# The weighted paths, the sequential ladder, the coherence of the confidence
# table with the headline, the response coding and the smoothing. Every test
# here fails on the code as it stood on 2026-09-03 before Session A.
# ==============================================================================

skip_if(!exists("run_van_westendorp", mode = "function"), "VW engine not available")
skip_if(!exists("run_gabor_granger", mode = "function"), "GG engine not available")

# ------------------------------------------------------------------------------
# Fixtures
# ------------------------------------------------------------------------------

# One population with a log-normal value anchor; the weight favours the
# respondents above the median anchor, so every weighted point sits higher.
anchored_vw <- function(n = 300, seed = 12) {
  set.seed(seed)
  anchor <- exp(rnorm(n, log(80), 0.3))
  m <- cbind(anchor * 0.55 * exp(rnorm(n, 0, 0.1)), anchor * 0.78 * exp(rnorm(n, 0, 0.1)),
             anchor * 1.25 * exp(rnorm(n, 0, 0.1)), anchor * 1.60 * exp(rnorm(n, 0, 0.1)))
  m <- t(apply(m, 1, sort))
  d <- data.frame(too_cheap = m[, 1], cheap = m[, 2], expensive = m[, 3], too_expensive = m[, 4])
  d$w <- ifelse(anchor > median(anchor), 1.6, 0.4)
  d$respondent_id <- seq_len(n)
  d
}

# Two groups whose price perceptions differ, for the duplication golden.
two_group_vw <- function(n_each = 120, seed = 11) {
  set.seed(seed)
  mk <- function(base, n) {
    tc <- base * runif(n, 0.45, 0.60); ch <- base * runif(n, 0.70, 0.85)
    ex <- base * runif(n, 1.15, 1.35); te <- base * runif(n, 1.50, 1.80)
    data.frame(too_cheap = tc, cheap = ch, expensive = ex, too_expensive = te)
  }
  d <- rbind(cbind(mk(50, n_each), group = "A"), cbind(mk(100, n_each), group = "B"))
  d$w <- ifelse(d$group == "A", 0.5, 1.5)
  d$respondent_id <- seq_len(nrow(d))
  d
}

vw_cfg <- function(weight_var = NA_character_, behavior = "drop", confidence = FALSE,
                   iterations = 60) {
  list(
    analysis_method = "van_westendorp", weight_var = weight_var, dk_codes = numeric(0),
    currency_symbol = "R",
    van_westendorp = list(col_too_cheap = "too_cheap", col_cheap = "cheap",
                          col_expensive = "expensive", col_too_expensive = "too_expensive",
                          validate_monotonicity = TRUE, violation_threshold = 0.5,
                          calculate_confidence = confidence, bootstrap_iterations = iterations,
                          confidence_level = 0.95),
    vw_monotonicity_behavior = behavior,
    validation = list(min_completeness = 0.8, min_sample = 5, price_min = 0, price_max = 10000)
  )
}

quiet <- function(expr) { capture.output(r <- expr); r }

# ------------------------------------------------------------------------------
# C1: weighted Van Westendorp
# ------------------------------------------------------------------------------

test_that("weighted VW price points differ from unweighted and name their estimator (C1)", {
  d <- anchored_vw()
  un <- quiet(run_van_westendorp(d, vw_cfg()))
  we <- quiet(run_van_westendorp(d, vw_cfg(weight_var = "w")))
  # The weight favours the dearer half, so every weighted point sits higher.
  expect_gt(we$price_points$OPP, un$price_points$OPP)
  expect_gt(we$price_points$IDP, un$price_points$IDP)
  expect_gt(we$price_points$PME, un$price_points$PME)
  expect_match(we$diagnostics$estimator, "weighted")
  expect_true(we$diagnostics$weighted)
  expect_match(un$diagnostics$estimator, "unweighted")
})

test_that("a weight of 2 equals duplicating the respondent (weighted-path golden)", {
  d <- two_group_vw(n_each = 60)
  d$w2 <- ifelse(d$group == "B", 2, 1)
  dup <- rbind(d, d[d$group == "B", ])
  we <- quiet(run_van_westendorp(d, vw_cfg(weight_var = "w2")))
  un <- quiet(run_van_westendorp(dup, vw_cfg()))
  for (p in c("PMC", "OPP", "IDP", "PME")) {
    expect_equal(we$price_points[[p]], un$price_points[[p]], tolerance = 0.02, info = p)
  }
})

test_that("scaling every answer scales every price point (VW golden)", {
  d <- two_group_vw(n_each = 60)
  d2 <- d; for (c in c("too_cheap", "cheap", "expensive", "too_expensive")) d2[[c]] <- d[[c]] * 2
  a <- quiet(run_van_westendorp(d, vw_cfg()))
  b <- quiet(run_van_westendorp(d2, vw_cfg()))
  for (p in c("PMC", "OPP", "IDP", "PME")) {
    expect_equal(b$price_points[[p]], 2 * a$price_points[[p]], tolerance = 0.01, info = p)
  }
})

test_that("the weighted path refuses rather than falls back (C1)", {
  d <- two_group_vw(n_each = 40)
  expect_error(fit_vw_psm(d$too_cheap, d$cheap, d$expensive, d$too_expensive,
                          weights = c(NA, d$w[-1])),
               "DATA_VW_WEIGHTS_INVALID")
  testthat::local_mocked_bindings(
    psm_analysis_weighted = function(...) stop("design exploded"),
    .package = "pricesensitivitymeter"
  )
  expect_error(fit_vw_psm(d$too_cheap, d$cheap, d$expensive, d$too_expensive, weights = d$w),
               "MODEL_VW_WEIGHTED_FAILED")
})

# ------------------------------------------------------------------------------
# C3 + H3: the interval brackets the reported estimator
# ------------------------------------------------------------------------------

test_that("the CI table's estimate column is the headline point and the point sits inside its interval (C3)", {
  d <- anchored_vw(n = 200)
  r <- quiet(run_van_westendorp(d, vw_cfg(weight_var = "w", confidence = TRUE, iterations = 60)))
  ci <- r$confidence_intervals
  expect_equal(ci$estimate, unname(unlist(r$price_points[ci$metric])))
  expect_true("boot_mean" %in% names(ci))
  expect_true(all(ci$ci_lower <= ci$estimate & ci$estimate <= ci$ci_upper))
  expect_match(attr(ci, "policy"), "psm_analysis_weighted")
  expect_match(attr(ci, "policy"), "validate = TRUE")
})

test_that("flag_only keeps intransitive respondents in the curves and drop excludes them (H3)", {
  d <- anchored_vw(n = 200)
  set.seed(3)
  swap <- sample(nrow(d), 30)
  tmp <- d$cheap[swap]; d$cheap[swap] <- d$expensive[swap]; d$expensive[swap] <- tmp

  kept <- quiet(run_van_westendorp(d, vw_cfg(behavior = "flag_only")))
  v <- validate_pricing_data(d, vw_cfg(behavior = "drop"))
  dropped <- quiet(run_van_westendorp(v$clean_data, vw_cfg(behavior = "drop")))

  expect_false(kept$diagnostics$validate_flag)
  expect_true(dropped$diagnostics$validate_flag)
  expect_gt(kept$diagnostics$n_analysed, dropped$diagnostics$n_analysed)
  expect_equal(dropped$diagnostics$n_analysed, dropped$diagnostics$n_valid)
  # The excluded respondents move the curves: the optimal point differs. (The
  # indifference point can coincide, since a cheap/expensive swap moves both
  # of its curves symmetrically.)
  expect_false(isTRUE(all.equal(kept$price_points$OPP, dropped$price_points$OPP)))
})

# ------------------------------------------------------------------------------
# C2: stop-early Gabor-Granger
# ------------------------------------------------------------------------------

gg_cfg <- function(cols, prices, weight_var = NA_character_, imputation = "NONE",
                   response_type = "binary", binary_coding = "ZERO_ONE",
                   behavior = "smooth", smoothing = "isotonic", confidence = FALSE,
                   min_sample = 1) {
  list(
    analysis_method = "gabor_granger", weight_var = weight_var, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    gg_monotonicity_behavior = behavior, gg_stop_early_imputation = imputation,
    gabor_granger = list(data_format = "wide", price_sequence = prices, response_columns = cols,
                         response_type = response_type, binary_coding = binary_coding,
                         smoothing_method = smoothing, check_monotonicity = FALSE,
                         calculate_elasticity = TRUE, revenue_optimization = TRUE,
                         confidence_intervals = confidence, bootstrap_iterations = 80,
                         confidence_level = 0.95),
    validation = list(min_completeness = 0.8, min_sample = min_sample, price_min = 0, price_max = 10000)
  )
}

# A ladder where every respondent has a ceiling; the stop-early copy is NA
# above the first No.
ladder_data <- function(n = 200, prices = c(20, 40, 60, 80, 100), seed = 5) {
  set.seed(seed)
  ceiling <- runif(n, 15, 105)
  full <- sapply(prices, function(p) as.integer(p <= ceiling))
  colnames(full) <- paste0("full_", prices)
  stop <- full
  for (i in seq_len(n)) {
    first_no <- which(full[i, ] == 0L)
    if (length(first_no) && first_no[1] < length(prices)) stop[i, (first_no[1] + 1):length(prices)] <- NA
  }
  colnames(stop) <- paste0("stop_", prices)
  d <- data.frame(respondent_id = seq_len(n), full, stop)
  d$w <- 1
  d
}

test_that("unequal rung bases refuse by default and name the per-rung counts (C2)", {
  d <- ladder_data()
  prices <- c(20, 40, 60, 80, 100)
  cfg <- gg_cfg(paste0("stop_", prices), prices)
  err <- tryCatch(quiet(run_gabor_granger(d, cfg)), error = function(e) conditionMessage(e))
  expect_match(err, "DATA_GG_UNEQUAL_BASES")
  expect_match(err, "Answered base per rung")
  # The full ladder has equal bases and passes.
  expect_silent(quiet(run_gabor_granger(d, gg_cfg(paste0("full_", prices), prices))))
})

test_that("NO_AFTER_STOP recovers the full ladder's demand and stamps itself (C2)", {
  d <- ladder_data()
  prices <- c(20, 40, 60, 80, 100)
  full <- quiet(run_gabor_granger(d, gg_cfg(paste0("full_", prices), prices)))
  imp <- quiet(run_gabor_granger(d, gg_cfg(paste0("stop_", prices), prices, imputation = "NO_AFTER_STOP")))
  # Imputation reconstructs exactly the full ladder here (no noise), so the
  # curves agree and the bases are all n.
  expect_equal(imp$demand_curve$purchase_intent_raw, full$demand_curve$purchase_intent_raw, tolerance = 1e-12)
  expect_true(all(imp$demand_curve$n_respondents == nrow(d)))
  expect_match(imp$diagnostics$imputation, "NO_AFTER_STOP")
  # And the naive survivors-only curve was higher at the top rung.
  naive <- calculate_demand_curve(prepare_gg_wide_data(d, gg_cfg(paste0("stop_", prices), prices)$gabor_granger,
                                                       gg_cfg(paste0("stop_", prices), prices)))
  expect_gt(naive$purchase_intent[5], imp$demand_curve$purchase_intent_raw[5])
})

test_that("impute_gg_no_after_stop fills only the rungs above the first No", {
  long <- data.frame(respondent_id = c(1, 1, 1, 1, 2, 2, 2, 2),
                     price = rep(c(10, 20, 30, 40), 2),
                     response = c(1, 0, NA, NA, NA, 1, 1, NA), weight = 1)
  out <- impute_gg_no_after_stop(long)
  expect_equal(out$response[out$respondent_id == 1], c(1, 0, 0, 0))
  # Respondent 2 never said No: nothing is imputed, and the leading NA stays.
  expect_equal(out$response[out$respondent_id == 2], c(NA, 1, 1, NA))
})

# ------------------------------------------------------------------------------
# H5 + M5: response coding is exact and declared
# ------------------------------------------------------------------------------

test_that("1/2-coded data refuses as binary and passes under ONE_TWO with the right meaning (H5)", {
  prices <- c(10, 20, 30)
  d <- data.frame(respondent_id = 1:4, w = 1,
                  g10 = c(1, 1, 1, 2), g20 = c(1, 2, 1, 2), g30 = c(2, 2, 1, 2))
  cfg <- gg_cfg(c("g10", "g20", "g30"), prices, behavior = "diagnostic_only")
  err <- tryCatch(validate_pricing_data(d, cfg), error = function(e) conditionMessage(e))
  expect_match(err, "DATA_GG_NOT_BINARY")
  expect_match(err, "ONE_TWO")

  cfg2 <- gg_cfg(c("g10", "g20", "g30"), prices, binary_coding = "ONE_TWO", behavior = "diagnostic_only")
  v <- validate_pricing_data(d, cfg2)
  r <- quiet(run_gabor_granger(v$clean_data, cfg2))
  # 1 = buy, 2 = not: 3/4, 2/4, 1/4.
  expect_equal(r$demand_curve$purchase_intent, c(0.75, 0.5, 0.25))
  expect_match(r$diagnostics$response_coding, "ONE_TWO")
})

test_that("a declared-binary column with a 3 in it refuses (H5)", {
  expect_equal(code_gg_response(c(0, 1, NA), list(response_type = "binary")), c(0, 1, NA))
  d <- data.frame(respondent_id = 1:3, w = 1, g10 = c(0, 1, 3), g20 = c(0, 0, 1))
  expect_error(validate_pricing_data(d, gg_cfg(c("g10", "g20"), c(10, 20))), "DATA_GG_NOT_BINARY")
})

test_that("Response_Type = auto refuses (M5)", {
  expect_error(code_gg_response(c(1, 3, 5), list(response_type = "auto")), "CFG_GG_RESPONSE_TYPE")
})

test_that("Gabor-Granger golden: hand-computed demand, revenue and optimum", {
  prices <- c(10, 20, 30)
  d <- data.frame(respondent_id = 1:4, w = 1,
                  g10 = c(1, 1, 1, 0), g20 = c(1, 0, 1, 0), g30 = c(0, 0, 1, 0))
  r <- quiet(run_gabor_granger(d, gg_cfg(c("g10", "g20", "g30"), prices, behavior = "diagnostic_only")))
  expect_equal(r$demand_curve$purchase_intent, c(0.75, 0.5, 0.25))
  expect_equal(r$revenue_curve$revenue_index, c(7.5, 10, 7.5))
  expect_equal(r$optimal_price$price, 20)
  expect_equal(r$diagnostics$smoothing, "none")
})

# ------------------------------------------------------------------------------
# M1 + M14: smoothing pools, and the band brackets the smoothed curve
# ------------------------------------------------------------------------------

test_that("isotonic smoothing pools violators instead of raising them (M1)", {
  prices <- c(10, 20, 30, 40, 50)
  intent <- c(0.90, 0.95, 0.70, 0.75, 0.50)
  iso <- smooth_isotonic(prices, intent)
  cm <- smooth_cummax(prices, intent)
  expect_true(all(diff(iso) <= 1e-12))
  expect_equal(sum(iso), sum(intent), tolerance = 1e-12)   # PAVA preserves the mean
  expect_gt(sum(cm), sum(intent))                           # cummax only ever raises
  expect_equal(iso[1:2], c(0.925, 0.925))
})

test_that("the pipeline's smoothing is isotonic by default and keeps the raw curve (M1)", {
  prices <- c(10, 20, 30, 40)
  set.seed(9)
  d <- data.frame(respondent_id = 1:60, w = 1,
                  g10 = rbinom(60, 1, 0.8), g20 = rbinom(60, 1, 0.9),
                  g30 = rbinom(60, 1, 0.5), g40 = rbinom(60, 1, 0.3))
  r <- quiet(run_gabor_granger(d, gg_cfg(c("g10", "g20", "g30", "g40"), prices)))
  expect_equal(r$diagnostics$smoothing, "isotonic")
  expect_true("purchase_intent_raw" %in% names(r$demand_curve))
  expect_true(all(diff(r$demand_curve$purchase_intent) <= 1e-12))
  expect_equal(sum(r$demand_curve$purchase_intent), sum(r$demand_curve$purchase_intent_raw), tolerance = 1e-9)
})

test_that("the GG bootstrap band brackets the published smoothed curve (M14)", {
  prices <- c(10, 20, 30, 40)
  set.seed(21)
  d <- data.frame(respondent_id = 1:150, w = runif(150, 0.5, 1.5),
                  g10 = rbinom(150, 1, 0.85), g20 = rbinom(150, 1, 0.9),
                  g30 = rbinom(150, 1, 0.5), g40 = rbinom(150, 1, 0.3))
  r <- quiet(run_gabor_granger(d, gg_cfg(c("g10", "g20", "g30", "g40"), prices,
                                          weight_var = "w", confidence = TRUE)))
  ci <- r$confidence_intervals
  expect_true(all(ci$ci_lower <= r$demand_curve$purchase_intent + 1e-9))
  expect_true(all(ci$ci_upper >= r$demand_curve$purchase_intent - 1e-9))
  expect_match(attr(ci, "policy"), "isotonic")
  expect_match(attr(ci, "policy"), "carrying their weights")
})

# ------------------------------------------------------------------------------
# H4 + H6: monadic weights
# ------------------------------------------------------------------------------

skip_if(!exists("run_monadic_analysis", mode = "function"), "monadic engine not available")

mon_cfg <- function(weight_var = NA_character_) {
  list(weight_var = weight_var, unit_cost = NA_real_, currency_symbol = "R",
       monadic = list(price_column = "price_shown", intent_column = "purchase_intent",
                      intent_type = "binary", model_type = "logistic", prediction_points = 50,
                      confidence_intervals = FALSE))
}

test_that("monadic cell means are weighted and the p-value carries its caveat (H4, H6)", {
  d <- generate_monadic_data(n = 300)
  set.seed(2); d$w <- ifelse(d$purchase_intent == 1, 1.6, 0.6)   # weight favours buyers
  un <- quiet(run_monadic_analysis(d, mon_cfg()))
  we <- quiet(run_monadic_analysis(d, mon_cfg("w")))
  expect_true(all(we$observed_data$observed_intent >= un$observed_data$observed_intent))
  expect_true("weighted_n" %in% names(we$observed_data))
  expect_null(un$model_summary$p_value_caveat)
  expect_match(we$model_summary$p_value_caveat, "frequency weights")
})

test_that("grossing weights refuse and mean-1 weights are used as given (H4)", {
  d <- generate_monadic_data(n = 300)
  d$w <- 1200
  expect_error(quiet(run_monadic_analysis(d, mon_cfg("w"))), "DATA_MONADIC_GROSSING_WEIGHTS")
  d$w <- rep(c(0.8, 1.2), length.out = nrow(d))
  r <- quiet(run_monadic_analysis(d, mon_cfg("w")))
  expect_true(is.finite(r$model_summary$coefficients[2, 1]))
  expect_lt(r$model_summary$coefficients[2, 1], 0)
})
