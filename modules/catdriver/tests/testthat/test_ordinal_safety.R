# ==============================================================================
# CATDRIVER - ORDINAL SAFETY (H3, H4)
# ==============================================================================
# H3. The direction-sanity guard was broken twice over. guard_warn() and
#     guard_flag_stability() are copy-on-modify, and both return values were
#     discarded, so the warning never registered; and guard_flag_stability()
#     takes two arguments while the call passed three, so the moment the check
#     actually fired it threw "unused argument" and aborted the run. The only
#     automated protection against a reversed ordinal outcome either did nothing
#     or crashed.
# H4. An ordinal outcome with no Order was sorted alphabetically, silently.
# ==============================================================================

# The guard only acts when it has checked more than two level comparisons, so
# the driver needs four levels.
.cd_reversed_fixture <- function(n = 600, seed = 99) {
  set.seed(seed)
  d <- data.frame(service = factor(sample(c("Poor", "Fair", "Good", "Excellent"), n, TRUE),
                                   levels = c("Poor", "Fair", "Good", "Excellent")))
  eta <- c(Poor = -1.5, Fair = -0.4, Good = 1.0, Excellent = 2.2)[as.character(d$service)]
  u <- eta + rlogis(n)
  raw <- ifelse(u > 1.2, "High", ifelse(u > -0.6, "Mid", "Low"))
  # Handed to the model in reverse: the fitted odds ratios will point the
  # opposite way from the raw proportions, which is what the guard exists for.
  d$satisfaction <- factor(raw, levels = c("High", "Mid", "Low"), ordered = TRUE)
  d
}

.cd_ordinal_config <- function(order = c("Low", "Mid", "High")) {
  list(
    outcome_var = "satisfaction", outcome_type = "ordinal",
    outcome_label = "Satisfaction", confidence_level = 0.95,
    outcome_order = order,
    driver_vars = c("service"),
    variables = data.frame(VariableName = "service", Label = "Service",
                           stringsAsFactors = FALSE)
  )
}

# ------------------------------------------------------------------------- H3

test_that("the direction-sanity guard fires when the data order contradicts the declared Order", {
  skip_if_not_installed("ordinal")

  # Rewritten 2026-09-19 after review finding F11. The old construction compared
  # the model against raw proportions computed in the MODEL's own top level, so
  # reversing the order flipped both sides and the mismatch count was zero by
  # construction: the guard could never fire on the case it is named for. The
  # reference point now comes from the config's declared Order, which is
  # independent of what the model was given.
  #
  # Here the data reach the model as High < Mid < Low while the Variables sheet
  # declares Low;Mid;High. That is the real defect: the odds ratios describe
  # movement towards Low while the analyst believes they describe High.
  d <- .cd_reversed_fixture()
  config <- .cd_ordinal_config()          # declares Low;Mid;High
  prep_data <- list(
    data = d,
    outcome_info = list(type = "ordinal", categories = levels(d$satisfaction))
  )
  fit <- run_ordinal_logistic_robust(satisfaction ~ service, d, NULL, config, guard_init())

  guard <- guard_direction_sanity(guard_init(), prep_data, fit, config)

  expect_true(any(grepl("OUTCOME ORDER MAY BE REVERSED", guard$warnings)),
              info = paste(guard$warnings, collapse = " | "))
  expect_true(any(grepl("High", guard$warnings)))       # names the declared top
  expect_true(any(grepl("possible outcome order reversal", guard$stability_flags)))
  expect_true(length(guard$soft_failures$direction_sanity) > 0)
})

test_that("the guard says nothing when there is no declared Order to check against", {
  skip_if_not_installed("ordinal")

  d <- .cd_reversed_fixture()
  config <- .cd_ordinal_config(order = NULL)
  prep_data <- list(
    data = d,
    outcome_info = list(type = "ordinal", categories = levels(d$satisfaction))
  )
  fit <- run_ordinal_logistic_robust(satisfaction ~ service, d, NULL, config, guard_init())

  # Nothing independent to compare against. H4 refuses this config upstream, so
  # the guard should not invent a finding out of the model's own ordering.
  guard <- guard_direction_sanity(guard_init(), prep_data, fit, config)
  expect_length(guard$warnings, 0)
})

test_that("the direction-sanity guard leaves a consistent model alone", {
  skip_if_not_installed("ordinal")

  d <- .cd_reversed_fixture()
  d$satisfaction <- factor(as.character(d$satisfaction),
                           levels = c("Low", "Mid", "High"), ordered = TRUE)

  config <- .cd_ordinal_config()          # the declared Order now matches the data
  fit <- run_ordinal_logistic_robust(satisfaction ~ service, d, NULL, config, guard_init())
  prep_data <- list(
    data = d,
    outcome_info = list(type = "ordinal", categories = levels(d$satisfaction))
  )

  guard <- guard_direction_sanity(guard_init(), prep_data, fit, config)
  expect_false(any(grepl("OUTCOME ORDER MAY BE REVERSED", guard$warnings)))
  expect_length(guard$stability_flags, 0)
})

test_that("guard_flag_stability takes two arguments, and a third is an error", {
  expect_equal(length(formals(guard_flag_stability)), 2L)

  # The old direction-sanity call passed a category as a third argument. That is
  # not a silent no-op: it throws the moment the check fires, which took the run
  # with it.
  expect_error(guard_flag_stability(guard_init(), "flag", "category"),
               "unused argument")
})

# ------------------------------------------------------------------------- H4

test_that("an ordinal outcome with no declared Order is refused", {
  config <- .cd_ordinal_config(order = NULL)

  err <- tryCatch({
    guard_ordinal_outcome_order(config)
    NULL
  }, turas_refusal = function(e) e)

  expect_false(is.null(err))
  expect_equal(err$code, "CFG_OUTCOME_ORDER_MISSING")
  expect_true(grepl("Order", err$how_to_fix))
  expect_true(grepl("Variables sheet", err$how_to_fix))
  expect_true(grepl("alphabetically", conditionMessage(err)))

  # empty strings and NA count as no order
  expect_error(guard_ordinal_outcome_order(.cd_ordinal_config(order = character(0))))
  expect_error(guard_ordinal_outcome_order(.cd_ordinal_config(order = NA_character_)))
  expect_error(guard_ordinal_outcome_order(.cd_ordinal_config(order = "")))
})

test_that("an ordinal outcome with an Order passes, and other outcome types are untouched", {
  expect_true(guard_ordinal_outcome_order(.cd_ordinal_config()))

  binary_config <- .cd_ordinal_config(order = NULL)
  binary_config$outcome_type <- "binary"
  expect_true(guard_ordinal_outcome_order(binary_config))

  multi_config <- .cd_ordinal_config(order = NULL)
  multi_config$outcome_type <- "multinomial"
  expect_true(guard_ordinal_outcome_order(multi_config))
})

test_that("the pipeline's pre-analysis guard refuses a text ordinal outcome with no Order", {
  # The same check through the door the run actually uses (00_main.R calls
  # guard_pre_analysis before anything is fitted), not just the function.
  set.seed(11)
  n <- 200
  data <- data.frame(
    satisfaction = sample(c("Low", "Medium", "High"), n, TRUE),
    service = factor(sample(c("Poor", "Good"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  config <- list(
    outcome_var = "satisfaction", outcome_type = "ordinal",
    outcome_label = "Satisfaction", outcome_order = NULL,
    driver_vars = "service",
    driver_settings = data.frame(driver = "service", type = "categorical",
                                 stringsAsFactors = FALSE),
    variables = data.frame(VariableName = "service", Label = "Service",
                           stringsAsFactors = FALSE)
  )

  err <- tryCatch({
    guard_pre_analysis(config, data)
    NULL
  }, turas_refusal = function(e) e)

  expect_false(is.null(err))
  expect_equal(err$code, "CFG_OUTCOME_ORDER_MISSING")
  expect_true(grepl("satisfaction", err$problem))

  # With the Order declared, the same config clears every pre-analysis guard
  config$outcome_order <- c("Low", "Medium", "High")
  expect_silent(guard_pre_analysis(config, data))
})
