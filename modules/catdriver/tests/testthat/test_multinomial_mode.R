# ==============================================================================
# CATDRIVER - MULTINOMIAL MODE IS AMPUTATED, NOT PRETENDED (H6)
# ==============================================================================
# The guard demanded a choice of four modes; the engine fitted the same
# baseline-category model whatever was chosen, and nothing else in the module
# ever read the setting. A user who configured one_vs_all received
# baseline-category odds ratios believing they had one-vs-rest. per_outcome
# passed the guard and was then refused by the engine's own whitelist: a
# guaranteed contradiction between two files.
#
# Locked decision 3 of the handover: accept baseline_category, refuse the rest
# with an honest "not implemented" message.
# ==============================================================================

.cd_multinomial_config <- function(mode = "baseline_category", target = NULL) {
  list(
    outcome_var = "plan", outcome_type = "multinomial", outcome_label = "Plan",
    confidence_level = 0.95,
    multinomial_mode = mode,
    target_outcome_level = target,
    driver_vars = "service",
    driver_settings = data.frame(driver = "service", type = "categorical",
                                 stringsAsFactors = FALSE),
    variables = data.frame(VariableName = "service", Label = "Service",
                           stringsAsFactors = FALSE)
  )
}

.cd_refusal_of <- function(expr) {
  tryCatch({ force(expr); NULL }, turas_refusal = function(e) e)
}

test_that("baseline_category is accepted", {
  expect_true(guard_require_multinomial_mode(.cd_multinomial_config()))
})

test_that("every unimplemented mode is refused, by name", {
  for (mode in c("one_vs_all", "all_pairwise", "per_outcome", "anything_else")) {
    err <- .cd_refusal_of(guard_require_multinomial_mode(.cd_multinomial_config(mode)))
    expect_false(is.null(err), info = mode)
    expect_equal(err$code, "CFG_MULTINOMIAL_MODE_NOT_IMPLEMENTED", info = mode)
    expect_true(grepl(mode, err$problem, fixed = TRUE), info = mode)
    expect_true(grepl("multinomial_mode", err$how_to_fix), info = mode)
    expect_true(grepl("baseline_category", err$how_to_fix), info = mode)
  }
})

test_that("a missing mode is still refused, and the message offers only the mode that exists", {
  err <- .cd_refusal_of(guard_require_multinomial_mode(.cd_multinomial_config(NULL)))
  expect_equal(err$code, "CFG_MULTINOMIAL_MODE_MISSING")
  expect_true(grepl("baseline_category", err$how_to_fix))
  expect_false(grepl("one_vs_all|all_pairwise|per_outcome", err$how_to_fix))
})

test_that("the guard stays out of the way for non-multinomial outcomes", {
  cfg <- .cd_multinomial_config("one_vs_all")
  cfg$outcome_type <- "binary"
  expect_true(guard_require_multinomial_mode(cfg))
  cfg$outcome_type <- "ordinal"
  expect_true(guard_require_multinomial_mode(cfg))
})

test_that("the engine refuses an unimplemented mode even on a direct call", {
  skip_if_not_installed("nnet")

  set.seed(31)
  n <- 200
  d <- data.frame(service = factor(sample(c("Poor", "Good"), n, TRUE)))
  d$plan <- factor(sample(c("Basic", "Standard", "Premium"), n, TRUE))

  err <- .cd_refusal_of(run_multinomial_logistic_robust(
    plan ~ service, d, NULL, .cd_multinomial_config("one_vs_all"), guard_init()
  ))
  expect_false(is.null(err))
  expect_equal(err$code, "CFG_MULTINOMIAL_MODE_NOT_IMPLEMENTED")

  fit <- run_multinomial_logistic_robust(
    plan ~ service, d, NULL, .cd_multinomial_config(), guard_init()
  )
  expect_equal(fit$multinomial_mode, "baseline_category")
  expect_null(fit$target_outcome_level)
})

test_that("the shipped template offers only the mode that exists", {
  source(file.path(turas_root, "modules/catdriver/lib/generate_config_templates.R"),
         local = TRUE)
  sections <- build_catdriver_settings_def()
  fields <- unlist(lapply(sections, function(s) s$fields), recursive = FALSE)
  mode_field <- Filter(function(f) identical(f$name, "multinomial_mode"), fields)[[1]]

  expect_equal(mode_field$dropdown, "baseline_category")
  expect_false(grepl("one_vs_all|all_pairwise|per_outcome", mode_field$valid_values_text))

  # and target_outcome_level, which only meant anything for one_vs_all, is gone
  expect_length(Filter(function(f) identical(f$name, "target_outcome_level"), fields), 0)
})
