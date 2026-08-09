# ==============================================================================
# WEIGHTING MODULE - HAND-CHECKABLE NUMERIC ASSERTIONS (W7, W8)
# ==============================================================================
# The suite was green but weak on numbers: it verified statuses and rough
# properties and almost never an exact value. These are the values you can work
# out on paper, so a wrong answer is a failing test rather than a plausible one.
# ==============================================================================


# ==============================================================================
# Kish effective n and DEFF
# ==============================================================================

test_that("Kish n_eff and DEFF are exact on non-uniform weights", {
  # w = c(1, 1, 3): sum = 5, sum of squares = 11.
  # n_eff = 25/11 = 2.2727..., deff = 3 / (25/11) = 33/25 = 1.32,
  # efficiency = 100 / 1.32 = 75.757...%
  w <- c(1, 1, 3)

  d <- diagnose_weights(w, label = "kish", verbose = FALSE)

  expect_equal(d$effective_sample$effective_n, 25 / 11)
  expect_equal(d$effective_sample$design_effect, 33 / 25)
  expect_equal(d$effective_sample$efficiency, 100 / (33 / 25))
})

test_that("uniform weights give n_eff = n and DEFF = 1", {
  w <- rep(2.5, 40)
  d <- diagnose_weights(w, label = "uniform", verbose = FALSE)

  expect_equal(d$effective_sample$effective_n, 40)
  expect_equal(d$effective_sample$design_effect, 1)
  expect_equal(d$effective_sample$efficiency, 100)
})

test_that("validation and diagnostics quote the same DEFF (M2)", {
  # validate_calculated_weights() rounded n_eff before dividing, so on c(1,1,3)
  # it reported 3/2 = 1.5 against diagnostics' 1.32 — two of the module's own
  # outputs disagreeing about the same weights.
  w <- c(1, 1, 3)

  v <- validate_calculated_weights(w, "kish")
  d <- diagnose_weights(w, label = "kish", verbose = FALSE)

  expect_equal(v$effective_n, d$effective_sample$effective_n)
  expect_equal(v$design_effect, d$effective_sample$design_effect)
  expect_equal(v$efficiency, d$effective_sample$efficiency)
  expect_equal(v$design_effect, 1.32)
  # The rounded value is still available for display.
  expect_equal(v$effective_n_display, 2)
})


# ==============================================================================
# Design weights: analytic values for unequal strata
# ==============================================================================

test_that("unequal strata give the analytic weights", {
  # North: 10,000 people, 140 respondents -> 71.42857
  # South: 10,000 people,  60 respondents -> 166.66667
  data <- data.frame(
    Region = c(rep("North", 140), rep("South", 60)),
    stringsAsFactors = FALSE
  )
  pop <- c(North = 10000, South = 10000)

  w <- calculate_design_weights(data, "Region", pop, verbose = FALSE)

  expect_equal(unname(w[1]), 10000 / 140)
  expect_equal(unname(w[200]), 10000 / 60)
  # Both strata gross to their own population, so the total is the population.
  expect_equal(sum(w), 20000)
  # And the ratio is exactly the inverse of the sampling ratio.
  expect_equal(unname(w[200] / w[1]), 140 / 60)
})


# ==============================================================================
# Cell weights: balanced and unbalanced
# ==============================================================================

test_that("a balanced cell design leaves every weight at 1", {
  data <- data.frame(
    Gender = rep(c("Male", "Female"), each = 50),
    stringsAsFactors = FALSE
  )
  targets <- data.frame(Gender = c("Male", "Female"), target_percent = c(50, 50),
                        stringsAsFactors = FALSE)

  res <- calculate_cell_weights(data, targets, "Gender", verbose = FALSE)

  expect_true(all(res$weights == 1))
  expect_equal(sum(res$weights), 100)
})

test_that("cell weights are target share over observed share", {
  # 70 Male / 30 Female, targets 48 / 52.
  # Male:   (0.48 * 100) / 70 = 0.685714
  # Female: (0.52 * 100) / 30 = 1.733333
  data <- data.frame(
    Gender = c(rep("Male", 70), rep("Female", 30)),
    stringsAsFactors = FALSE
  )
  targets <- data.frame(Gender = c("Male", "Female"), target_percent = c(48, 52),
                        stringsAsFactors = FALSE)

  res <- calculate_cell_weights(data, targets, "Gender", verbose = FALSE)

  expect_equal(unname(res$weights[1]), 48 / 70)
  expect_equal(unname(res$weights[100]), 52 / 30)
  # Cell weights sum to n by construction, which is what makes them comparable
  # with rim weights and with normalised design weights.
  expect_equal(sum(res$weights), 100)
  # And the weighted share now equals the target.
  expect_equal(sum(res$weights[1:70]) / sum(res$weights), 0.48)
})


# ==============================================================================
# Rim weights: margins actually achieved, and alignment preserved
# ==============================================================================

test_that("every achieved margin matches its target across several variables", {
  skip_if_not_installed("survey")

  set.seed(99)
  n <- 600
  data <- data.frame(
    Gender = sample(c("Male", "Female"), n, replace = TRUE, prob = c(0.56, 0.44)),
    Age    = sample(c("18-34", "35-54", "55+"), n, replace = TRUE,
                    prob = c(0.40, 0.33, 0.27)),
    stringsAsFactors = FALSE
  )

  targets <- list(
    Gender = c(Male = 0.48, Female = 0.52),
    Age    = c(`18-34` = 0.33, `35-54` = 0.37, `55+` = 0.30)
  )

  res <- calculate_rim_weights(data, targets, verbose = FALSE)

  expect_true(res$converged)

  # Recompute every margin from the weights themselves rather than trusting the
  # engine's own table. This is the assertion the suite never had.
  total_w <- sum(res$weights, na.rm = TRUE)
  for (var in names(targets)) {
    for (cat in names(targets[[var]])) {
      achieved <- sum(res$weights[data[[var]] == cat], na.rm = TRUE) / total_w
      expect_equal(achieved, unname(targets[[var]][cat]), tolerance = 1e-4,
                   info = paste(var, cat))
    }
  }

  # Rim weights sum to n.
  expect_equal(total_w, n, tolerance = 1e-6)
})

test_that("g-weights are exactly final / base", {
  skip_if_not_installed("survey")

  set.seed(5)
  n <- 300
  data <- data.frame(
    Gender = sample(c("Male", "Female"), n, replace = TRUE, prob = c(0.6, 0.4)),
    stringsAsFactors = FALSE
  )
  base <- runif(n, 0.5, 2)

  res <- calculate_rim_weights(
    data, list(Gender = c(Male = 0.5, Female = 0.5)),
    base_weights = base, verbose = FALSE
  )

  expect_equal(res$g_weights, res$weights / base)
})

test_that("excluded rows keep everyone else in position", {
  skip_if_not_installed("survey")

  # Rim weighting refuses outright on a missing rim variable, so the way rows
  # legitimately drop out of the calibration is a missing BASE weight. The
  # engine calibrates the complete-cases subset and re-expands it, and this
  # asserts the re-expansion lands each weight back on its own row rather than
  # on whichever row now sits in that position.
  set.seed(3)
  n <- 200
  data <- data.frame(
    id = seq_len(n),
    Gender = rep(c("Male", "Female"), c(120, 80)),
    stringsAsFactors = FALSE
  )
  base <- rep(1, n)
  base[c(7, 42, 199)] <- NA

  res <- calculate_rim_weights(
    data, list(Gender = c(Male = 0.5, Female = 0.5)),
    base_weights = base, verbose = FALSE
  )

  # Those three rows carry NA weights, and they are those three rows — not
  # three rows that happen to be at the end after a silent reorder.
  expect_equal(which(is.na(res$weights)), c(7, 42, 199))
  expect_equal(length(res$weights), n)
  expect_equal(sum(!is.na(res$weights)), n - 3)
  expect_equal(sum(res$weights, na.rm = TRUE), n - 3, tolerance = 1e-6)

  # Every remaining Male row carries the Male weight, in place.
  male_rows <- setdiff(which(data$Gender == "Male"), c(7, 42))
  expect_equal(length(unique(round(res$weights[male_rows], 10))), 1)
})

test_that("cap_weights is honoured at a bound that is not the default", {
  skip_if_not_installed("survey")

  # The existing cap test asserted <= 3.01 against a default upper bound of 3.0,
  # so it passed whether or not the cap was honoured. This one uses a bound the
  # default would never produce, and asserts the only two honest outcomes: the
  # cap holds, or the run refuses because it cannot hold. Silently returning
  # weights above the cap — the failure the old test could not see — is neither.
  data <- data.frame(
    Gender = rep(c("Male", "Female"), c(300, 100)),
    stringsAsFactors = FALSE
  )
  targets <- list(Gender = c(Male = 0.5, Female = 0.5))

  uncapped <- calculate_rim_weights(data, targets, verbose = FALSE)
  # 0.5 * 400 / 100 = 2.0 for Female.
  expect_equal(max(uncapped$weights, na.rm = TRUE), 2.0, tolerance = 1e-6)
  expect_equal(uncapped$bounds, c(0.3, 3.0))

  outcome <- tryCatch(
    calculate_rim_weights(data, targets, cap_weights = c(0.5, 1.4), verbose = FALSE),
    turas_refusal = function(e) e
  )

  if (inherits(outcome, "turas_refusal")) {
    # The cap cannot be met while hitting the target, and the run says so.
    expect_true(outcome$code %in% c("MODEL_NO_CONVERGENCE", "MODEL_BOUNDS_ERROR"))
  } else {
    expect_lte(max(outcome$weights, na.rm = TRUE), 1.4 + 1e-8)
    expect_equal(outcome$bounds, c(0.5, 1.4))
  }
})


# ==============================================================================
# W7: the exported cores validate what the config path already validated
# ==============================================================================

test_that("rim targets that do not sum to 1 are refused, not absorbed", {
  # The population vector is built with the first category implied by the
  # intercept, so an excess or shortfall was silently taken out of that one
  # category — the run calibrated to a distribution nobody wrote down.
  data <- data.frame(Gender = rep(c("Male", "Female"), 50),
                     stringsAsFactors = FALSE)

  refusal <- tryCatch(
    calculate_rim_weights(data, list(Gender = c(Male = 0.53, Female = 0.52)),
                          verbose = FALSE),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "CFG_TARGET_SUM_ERROR")
  expect_match(conditionMessage(refusal), "1.0500")
})

test_that("a duplicated rim target category is refused by name", {
  data <- data.frame(Gender = rep(c("Male", "Female"), 50),
                     stringsAsFactors = FALSE)
  targets <- c(Male = 0.3, Female = 0.5, Male = 0.2)

  refusal <- tryCatch(
    calculate_rim_weights(data, list(Gender = targets), verbose = FALSE),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "CFG_DUPLICATE_TARGET_CATEGORY")
  expect_match(conditionMessage(refusal), "'Male'")
})

test_that("a negative rim target is refused", {
  data <- data.frame(Gender = rep(c("Male", "Female"), 50),
                     stringsAsFactors = FALSE)

  refusal <- tryCatch(
    calculate_rim_weights(data, list(Gender = c(Male = 1.2, Female = -0.2)),
                          verbose = FALSE),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "CFG_INVALID_TARGET_VALUE")
})

test_that("a zero or negative cell target is refused", {
  data <- data.frame(Gender = rep(c("Male", "Female"), 50),
                     stringsAsFactors = FALSE)

  for (bad in list(c(100, 0), c(120, -20), c(100, NA))) {
    targets <- data.frame(Gender = c("Male", "Female"), target_percent = bad,
                          stringsAsFactors = FALSE)
    refusal <- tryCatch(
      calculate_cell_weights(data, targets, "Gender", verbose = FALSE),
      turas_refusal = function(e) e
    )
    expect_s3_class(refusal, "turas_refusal")
    expect_equal(refusal$code, "CFG_INVALID_TARGET_VALUE")
  }
})


# ==============================================================================
# W7a: surrounding whitespace no longer decides whether a category matches
# ==============================================================================

test_that("a stray space in a target label no longer breaks the match", {
  data <- data.frame(Region = rep(c("North", "South"), each = 50),
                     stringsAsFactors = FALSE)
  # As typed into Excel, where the space is invisible.
  pop <- c(` North` = 1000, `South ` = 1000)

  w <- calculate_design_weights(data, "Region", pop, verbose = FALSE)

  expect_false(any(is.na(w)))
  expect_equal(unname(unique(w)), 20)
})

test_that("case is still respected when matching categories", {
  # Whitespace is never meaningful; case is. "male" and "Male" are two answers,
  # and quietly merging them would be a real error.
  data <- data.frame(Region = rep(c("North", "south"), each = 50),
                     stringsAsFactors = FALSE)
  pop <- c(North = 1000, South = 1000)

  refusal <- tryCatch(
    suppressWarnings(calculate_design_weights(data, "Region", pop, verbose = FALSE)),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "DATA_UNWEIGHTED_ROWS")
  expect_match(conditionMessage(refusal), "'south'")
})
