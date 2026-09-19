# ==============================================================================
# CATDRIVER - FIXES FROM THE INDEPENDENT REVIEW OF SESSION A (F1 to F5)
# ==============================================================================
# REVIEW_FINDINGS_CATDRIVER_SESSION_A_2026-09-19.md.
#
# F3 CRITICAL. The subgroup comparison keyed on driver and level only, so a
#    multinomial outcome's K-1 odds ratios per driver level collapsed into one
#    row and the table reported whichever outcome level came last.
# F4 CRITICAL. predict() on a clm without newdata returns each respondent's
#    probability of their OWN observed category. The ordinal probability lift
#    averaged that and called the difference a lift.
# F1 HIGH. car::Anova on a clm is a Wald test, not a likelihood-ratio one. The
#    stamp said LR on every path, having been checked on glm only.
# F2 HIGH. A weight variable that could not be used ran unweighted under PASS
#    with the Declaration still naming it.
# F5 HIGH. The Declaration printed the analysed count as received and vice
#    versa, so it claimed more respondents analysed than received.
# ==============================================================================

.cd_f_fixture <- function(n = 500, seed = 4242) {
  set.seed(seed)
  d <- data.frame(
    service = factor(sample(c("Poor", "Fair", "Good"), n, TRUE)),
    region  = factor(sample(c("North", "South"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  eta <- ifelse(d$service == "Good", 1.5, 0) + ifelse(d$service == "Fair", 0.6, 0)
  d$plan <- factor(apply(cbind(1, exp(eta), exp(eta * 0.4)), 1,
                         function(p) sample(c("Basic", "Premium", "Standard"), 1, prob = p)))
  u <- eta + rlogis(n)
  d$satisfaction <- factor(ifelse(u > 1, "High", ifelse(u > -0.5, "Mid", "Low")),
                           levels = c("Low", "Mid", "High"), ordered = TRUE)
  d$wt <- runif(n, 0.5, 1.8)
  d$wt <- d$wt / mean(d$wt)
  d
}

.cd_f_config <- function(outcome, type, extra = list()) {
  base <- list(
    outcome_var = outcome, outcome_type = type, outcome_label = outcome,
    confidence_level = 0.95, multinomial_mode = "baseline_category",
    driver_vars = "service",
    driver_settings = data.frame(driver = "service", type = "categorical",
                                 stringsAsFactors = FALSE),
    variables = data.frame(VariableName = "service", Label = "Service",
                           stringsAsFactors = FALSE)
  )
  utils::modifyList(base, extra)
}

# --------------------------------------------------------------------------- F3

test_that("a multinomial subgroup comparison keeps one row per outcome level", {
  skip_if_not_installed("nnet")

  d <- .cd_f_fixture()
  config <- .cd_f_config("plan", "multinomial")

  group_result <- function(dd) {
    f <- plan ~ service
    fit <- run_multinomial_logistic_robust(f, dd, NULL, config, guard_init())
    mapping <- map_multinomial_terms(fit$model, dd, f, "plan")
    list(status = "PASS", group_n = nrow(dd),
         importance = calculate_importance(fit, config),
         odds_ratios = extract_odds_ratios_mapped(fit, mapping, config, 0.95),
         model_result = fit)
  }

  successful <- list(North = group_result(d[d$region == "North", , drop = FALSE]),
                     South = group_result(d[d$region == "South", , drop = FALSE]))

  or_df <- successful$North$odds_ratios
  n_levels <- length(unique(or_df$outcome_level))
  expect_gt(n_levels, 1)                       # the fixture must exercise the defect

  cmp <- build_subgroup_comparison(successful, config)

  expect_true("outcome_level" %in% names(cmp$or_comparison))
  expect_equal(length(unique(cmp$or_comparison$outcome_level)), n_levels)
  # one row per driver level per outcome level, not one per driver level
  expect_equal(nrow(cmp$or_comparison),
               nrow(unique(or_df[, c("factor", "comparison", "outcome_level")])))

  # and the odds ratios are the mapper's own, level by level
  for (i in seq_len(nrow(cmp$or_comparison))) {
    row <- cmp$or_comparison[i, ]
    src <- or_df[or_df$factor == row$driver &
                   or_df$comparison == row$level &
                   or_df$outcome_level == row$outcome_level, ]
    expect_equal(row$North_or, src$odds_ratio[1], tolerance = 1e-8,
                 info = paste(row$driver, row$level, row$outcome_level))
  }
})

test_that("a binary subgroup comparison is unchanged and carries no outcome level", {
  d <- .cd_f_fixture()
  d$churn <- factor(as.integer(d$satisfaction == "High"))
  config <- .cd_f_config("churn", "binary")

  group_result <- function(dd) {
    f <- churn ~ service
    fit <- run_binary_logistic_robust(f, dd, NULL, config, guard_init())
    list(status = "PASS", group_n = nrow(dd),
         importance = calculate_importance(fit, config),
         odds_ratios = extract_odds_ratios_mapped(fit, map_terms_to_levels(fit$model, dd, f),
                                                  config, 0.95),
         model_result = fit)
  }
  successful <- list(North = group_result(d[d$region == "North", , drop = FALSE]),
                     South = group_result(d[d$region == "South", , drop = FALSE]))

  cmp <- build_subgroup_comparison(successful, config)
  expect_true(all(is.na(cmp$or_comparison$outcome_level)))
  expect_equal(nrow(cmp$or_comparison), 2L)    # two non-reference service levels
})

# --------------------------------------------------------------------------- F4

test_that("an ordinal fit returns a probability per outcome category", {
  skip_if_not_installed("ordinal")

  d <- .cd_f_fixture()
  config <- .cd_f_config("satisfaction", "ordinal",
                         list(outcome_order = c("Low", "Mid", "High")))
  fit <- run_ordinal_logistic_robust(satisfaction ~ service, d, NULL, config, guard_init())

  pp <- fit$predicted_probs
  expect_true(is.matrix(pp))
  expect_equal(ncol(pp), 3L)
  expect_equal(colnames(pp), c("Low", "Mid", "High"))
  expect_true(all(abs(rowSums(pp) - 1) < 1e-8))

  # The old behaviour, stated exactly: a vector holding each respondent's
  # probability of the category they were observed in. That is a fit diagnostic,
  # not the probability of anything a reader would ask about.
  own_category <- predict(fit$model, type = "prob")$fit
  expect_true(is.null(dim(own_category)))
  observed <- as.character(d$satisfaction)
  by_observed <- pp[cbind(seq_len(nrow(pp)), match(observed, colnames(pp)))]
  expect_equal(unname(own_category), unname(by_observed), tolerance = 1e-10)
  # and it is not P(High) except for the respondents who were observed High
  expect_gt(max(abs(own_category - pp[, "High"])), 0.5)
})

test_that("the ordinal probability lift is a lift of the top category, and says so", {
  skip_if_not_installed("ordinal")

  d <- .cd_f_fixture()
  config <- .cd_f_config("satisfaction", "ordinal",
                         list(outcome_order = c("Low", "Mid", "High")))
  fit <- run_ordinal_logistic_robust(satisfaction ~ service, d, NULL, config, guard_init())
  prep <- list(data = d, outcome_info = list(type = "ordinal",
                                             categories = levels(d$satisfaction)))

  lift <- calculate_probability_lift(fit, prep, config)

  expect_false(is.null(lift))
  expect_true(all(lift$outcome_level == "High"))

  # every figure equals the mean of the High column for that driver level
  for (i in seq_len(nrow(lift))) {
    expected <- mean(fit$predicted_probs[d$service == lift$level[i], "High"])
    expect_equal(lift$mean_predicted_prob[i], round(expected, 3), tolerance = 1e-8,
                 info = lift$level[i])
  }
})

test_that("a probability vector on a three-category outcome produces no lift at all", {
  d <- .cd_f_fixture()
  config <- .cd_f_config("satisfaction", "ordinal",
                         list(outcome_order = c("Low", "Mid", "High")))
  prep <- list(data = d, outcome_info = list(type = "ordinal",
                                             categories = levels(d$satisfaction)))
  fake_fit <- list(model = NULL, predicted_probs = runif(nrow(d)))

  expect_null(suppressWarnings(calculate_probability_lift(fake_fit, prep, config)))
})

# --------------------------------------------------------------------------- F1

test_that("the importance stamp names the statistic car::Anova actually returned", {
  skip_if_not_installed("ordinal")
  skip_if_not_installed("car")

  d <- .cd_f_fixture()
  d$churn <- factor(as.integer(d$satisfaction == "High"))

  ord_fit <- run_ordinal_logistic_robust(
    satisfaction ~ service, d, NULL,
    .cd_f_config("satisfaction", "ordinal", list(outcome_order = c("Low", "Mid", "High"))),
    guard_init())
  ord_imp <- calculate_importance(ord_fit, .cd_f_config("satisfaction", "ordinal"))
  expect_true(all(grepl("Wald chi-square share", ord_imp$method)))
  expect_false(any(grepl("LR chi-square", ord_imp$method)))

  bin_fit <- run_binary_logistic_robust(churn ~ service, d, NULL,
                                        .cd_f_config("churn", "binary"), guard_init())
  bin_imp <- calculate_importance(bin_fit, .cd_f_config("churn", "binary"))
  expect_true(all(grepl("LR chi-square share", bin_imp$method)))

  # the label follows the column, so it cannot drift from the statistic again
  expect_true(grepl("Wald", .cd_anova_method_label(
    data.frame(Df = 1, Chisq = 1, `Pr(>Chisq)` = 1, check.names = FALSE))))
  expect_true(grepl("LR", .cd_anova_method_label(
    data.frame(`LR Chisq` = 1, Df = 1, check.names = FALSE))))
})

# --------------------------------------------------------------------------- F2

test_that("a weight variable that cannot be used refuses instead of running unweighted", {
  d <- .cd_f_fixture()

  misspelled <- .cd_f_config("satisfaction", "ordinal", list(weight_var = "survey_wieght"))
  err <- tryCatch({ guard_weight_variable_usable(misspelled, d); NULL },
                  turas_refusal = function(e) e)
  expect_false(is.null(err))
  expect_equal(err$code, "CFG_WEIGHT_VAR_NOT_FOUND")
  expect_true(grepl("survey_wieght", err$problem))
  expect_true(grepl("Weight row", err$how_to_fix))

  text_weights <- d
  text_weights$wt <- as.character(rep("heavy", nrow(d)))
  err2 <- tryCatch({
    guard_weight_variable_usable(.cd_f_config("satisfaction", "ordinal",
                                              list(weight_var = "wt")), text_weights)
    NULL
  }, turas_refusal = function(e) e)
  expect_equal(err2$code, "CFG_WEIGHT_VAR_NOT_NUMERIC")

  all_na <- d
  all_na$wt <- NA_real_
  err3 <- tryCatch({
    guard_weight_variable_usable(.cd_f_config("satisfaction", "ordinal",
                                              list(weight_var = "wt")), all_na)
    NULL
  }, turas_refusal = function(e) e)
  expect_equal(err3$code, "CFG_WEIGHT_VAR_NOT_NUMERIC")

  # a real weight column still passes
  expect_true(guard_weight_variable_usable(
    .cd_f_config("satisfaction", "ordinal", list(weight_var = "wt")), d))
})

test_that("a column with nothing numeric in it is not silently repaired into all-ones", {
  expect_false(normalise_catdriver_weights(rep(NA_real_, 10), "wt")$usable)
  expect_false(normalise_catdriver_weights(rep("heavy", 10), "wt")$usable)
  expect_null(normalise_catdriver_weights(rep(NA_real_, 10), "wt")$weights)

  # a column with SOME real weights is still usable, and the repairs are counted
  partial <- normalise_catdriver_weights(c(1.2, NA, 0.8, NA), "wt")
  expect_true(partial$usable)
  expect_equal(partial$n_na_imputed, 2L)
})

# --------------------------------------------------------------------------- F5

test_that("the stats pack Declaration cannot analyse more respondents than it received", {
  skip_if_not_installed("openxlsx")

  d <- .cd_f_fixture()
  d$churn <- factor(as.integer(d$satisfaction == "High"))
  config <- .cd_f_config("churn", "binary")
  config$output_file <- file.path(tempdir(), "cd_f5.xlsx")

  fit <- run_binary_logistic_robust(churn ~ service, d, NULL, config, guard_init())
  analysed <- 460L
  result <- list(
    importance = calculate_importance(fit, config),
    model_result = fit,
    prep_data = list(data = d[seq_len(analysed), ], outcome_info = list(type = "binary")),
    diagnostics = list(analysis_n = analysed, original_n = nrow(d)),
    weight_diagnostics = NULL
  )

  payload <- NULL
  had_writer <- exists("turas_write_stats_pack", envir = globalenv(), inherits = FALSE)
  original <- if (had_writer) get("turas_write_stats_pack", envir = globalenv()) else NULL
  assign("turas_write_stats_pack", function(p, path) { payload <<- p; path }, envir = globalenv())
  on.exit({
    if (had_writer) assign("turas_write_stats_pack", original, envir = globalenv())
    else rm("turas_write_stats_pack", envir = globalenv())
  }, add = TRUE)

  suppressMessages(generate_catdriver_stats_pack(
    config = config, survey_data = d[seq_len(analysed), ], result = result,
    run_result = list(status = "PASS", events = list()),
    start_time = Sys.time(), verbose = FALSE))

  expect_equal(payload$data_receipt$n_rows, nrow(d))        # received
  expect_equal(payload$data_used$n_respondents, analysed)   # analysed
  expect_equal(payload$data_used$n_excluded, nrow(d) - analysed)
  expect_lte(payload$data_used$n_respondents, payload$data_receipt$n_rows)

  # and an unusable weight is not named as if it had been applied
  expect_equal(payload$data_used$weight_variable, "")
  expect_false(payload$data_used$weighted)
})
