# ==============================================================================
# CATDRIVER - SUBGROUP COMPARISON AGAINST THE PRODUCTION SCHEMA (C2)
# ==============================================================================
# The July 2026 review's C2. build_or_comparison() read driver / level / or /
# or_ci_lower / or_ci_upper from the odds-ratio frame. The frame every run
# produces, from extract_odds_ratios_mapped(), carries factor / comparison /
# odds_ratio / or_lower / or_upper. Every column came back NULL, the comparison
# threw, 00_main swallowed the error to a console warning and returned NULL, and
# the run shipped PASS with sheets 9 to 11 saying "No subgroup comparison data".
#
# The suite's 28 subgroup tests never constructed an odds_ratios element at all,
# so the broken path had no coverage. These fixtures go through the real engine
# and the real mapper: a hand-built frame would only prove that the column names
# in the review were copied correctly.
# ==============================================================================

.cd_subgroup_fixture <- function(n = 400, seed = 4242) {
  set.seed(seed)
  d <- data.frame(
    service = factor(sample(c("Poor", "Fair", "Good"), n, TRUE)),
    price   = factor(sample(c("Cheap", "Fair", "Dear"), n, TRUE)),
    group   = factor(sample(c("A", "B"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  eta <- ifelse(d$service == "Good", 1.6, 0) + ifelse(d$service == "Fair", 0.7, 0) -
    ifelse(d$price == "Dear", 0.9, 0)
  d$churn <- factor(ifelse(plogis(eta + rlogis(n)) > 0.5, "Retained", "Churned"),
                    levels = c("Churned", "Retained"))
  d
}

.cd_subgroup_config <- function() {
  list(
    outcome_var = "churn", outcome_type = "binary", outcome_label = "Churn",
    confidence_level = 0.95,
    driver_vars = c("service", "price"),
    subgroup_var = "group",
    variables = data.frame(
      VariableName = c("service", "price"),
      Label = c("Service quality", "Price perception"),
      stringsAsFactors = FALSE
    )
  )
}

# One group's results, built the way a real run builds them: fit, map, extract.
.cd_group_result <- function(d, config) {
  f <- churn ~ service + price
  fit <- run_binary_logistic_robust(f, d, NULL, config, guard_init())
  mapping <- map_terms_to_levels(fit$model, d, f)
  list(
    status = "PASS",
    group_n = nrow(d),
    importance = calculate_importance(fit, config),
    odds_ratios = extract_odds_ratios_mapped(fit, mapping, config, 0.95),
    model_result = fit
  )
}

test_that("the production odds-ratio frame carries the mapper's column names", {
  d <- .cd_subgroup_fixture()
  config <- .cd_subgroup_config()
  or_df <- .cd_group_result(d, config)$odds_ratios

  # If this ever changes, the comparison's rename has to change with it.
  expect_true(all(c("factor", "comparison", "factor_label", "odds_ratio",
                    "or_lower", "or_upper", "p_value") %in% names(or_df)))
  expect_false(any(c("driver", "level", "or", "or_ci_lower", "or_ci_upper") %in% names(or_df)))
})

test_that("a subgroup comparison built from real results is complete, not NULL", {
  d <- .cd_subgroup_fixture()
  config <- .cd_subgroup_config()
  successful <- list(
    A = .cd_group_result(d[d$group == "A", , drop = FALSE], config),
    B = .cd_group_result(d[d$group == "B", , drop = FALSE], config)
  )

  cmp <- build_subgroup_comparison(successful, config)

  expect_false(is.null(cmp$importance_matrix))
  expect_false(is.null(cmp$or_comparison))
  expect_false(is.null(cmp$model_fit))
  expect_gt(nrow(cmp$importance_matrix), 0)
  expect_gt(nrow(cmp$or_comparison), 0)
  expect_equal(nrow(cmp$model_fit), 2)
  expect_equal(cmp$n_groups, 2)
  expect_true("classification" %in% names(cmp$importance_matrix))
  expect_true(length(cmp$insights) > 0)

  # The OR comparison must carry real numbers per group, not a column of NA
  expect_true(all(c("A_or", "B_or", "A_ci", "B_ci", "A_p", "B_p") %in% names(cmp$or_comparison)))
  expect_true(any(is.finite(cmp$or_comparison$A_or)))
  expect_true(any(is.finite(cmp$or_comparison$B_or)))
  expect_true(any(cmp$or_comparison$A_ci != "-"))
  expect_true(all(cmp$or_comparison$driver %in% c("service", "price")))
  expect_true(all(nzchar(cmp$or_comparison$level)))
})

test_that("an odds-ratio frame the comparison cannot read says so, loudly", {
  d <- .cd_subgroup_fixture()
  config <- .cd_subgroup_config()
  grp <- .cd_group_result(d, config)

  legacy <- grp$odds_ratios
  names(legacy)[names(legacy) == "factor"] <- "driver"
  names(legacy)[names(legacy) == "comparison"] <- "level"

  expect_error(normalise_or_frame(legacy, "A"), "missing the column")
  expect_error(normalise_or_frame(legacy, "A"), "factor")

  # and through the public function, so the caller's handler sees it.
  # (modifyList() would MERGE the two frames column-wise, since a data frame is
  # a list, and quietly leave the correct columns in place.)
  grp_a <- grp; grp_a$odds_ratios <- legacy
  grp_b <- grp; grp_b$odds_ratios <- legacy
  expect_error(build_subgroup_comparison(list(A = grp_a, B = grp_b), config),
               "odds-ratio table")
})

test_that("a group with no odds ratios is skipped rather than fatal", {
  d <- .cd_subgroup_fixture()
  config <- .cd_subgroup_config()
  grp <- .cd_group_result(d, config)

  expect_null(normalise_or_frame(NULL, "A"))
  expect_null(normalise_or_frame(data.frame(), "A"))

  grp_empty <- grp; grp_empty$odds_ratios <- data.frame()
  cmp <- build_subgroup_comparison(list(A = grp, B = grp_empty), config)
  expect_false(is.null(cmp$or_comparison))
  expect_gt(nrow(cmp$or_comparison), 0)   # A's rows survive
})

test_that("fewer than two successful groups is reported, not crashed", {
  d <- .cd_subgroup_fixture()
  config <- .cd_subgroup_config()
  cmp <- build_subgroup_comparison(list(A = .cd_group_result(d, config)), config)

  expect_null(cmp$or_comparison)
  expect_equal(cmp$n_groups, 1)
  expect_true(grepl("Fewer than 2", cmp$insights))
})
