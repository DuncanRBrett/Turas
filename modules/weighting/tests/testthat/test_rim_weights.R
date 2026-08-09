# ==============================================================================
# TESTS: Rim Weight Calculation (rim_weights.R)
# ==============================================================================

test_that("calculate_rim_weights converges with valid targets", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 200)

  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52),
    Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 200)
  expect_true(all(!is.na(result$weights)))
  expect_true(all(result$weights > 0))
})

test_that("rim weights achieve target margins", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 500)

  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  # Check achieved margin for Gender
  weighted_male <- sum(result$weights[data$Gender == "Male"]) / sum(result$weights)
  expect_equal(weighted_male, 0.48, tolerance = 0.01)
})

test_that("rim weights with base weights (rim-on-design)", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 200)

  # Create some base weights
  base_weights <- runif(200, 0.5, 2.0)

  targets <- list(
    Gender = c("Male" = 0.50, "Female" = 0.50)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    base_weights = base_weights,
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 200)
  expect_true(all(result$weights > 0))
})

test_that("rim weights with multiple variables", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 300)

  targets <- list(
    Gender = c("Male" = 0.50, "Female" = 0.50),
    Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    Region = c("North" = 0.25, "South" = 0.25, "East" = 0.25, "West" = 0.25)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 300)
  expect_true(all(result$weights > 0))
})

test_that("rim weights with cap", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 200)

  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    cap_weights = 3.0,
    verbose = FALSE
  )

  expect_true(all(result$weights <= 3.0 + 0.01))  # Small tolerance
})

test_that("calculate_rim_weights_from_config works end-to-end", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("survey")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_rim_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  result <- calculate_rim_weights_from_config(
    data = data,
    config = config,
    weight_name = "rim_weight",
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 200)
  expect_true(!is.null(result$margins))
})

test_that("calculate_achieved_margins returns correct structure", {
  skip_if_not_installed("survey")
  skip_if(!exists("calculate_achieved_margins", mode = "function"),
          "calculate_achieved_margins not available")

  set.seed(42)
  data <- create_simple_survey(n = 200)

  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  if (!is.null(result$margins)) {
    expect_true(is.data.frame(result$margins))
    expect_true("variable" %in% names(result$margins))
    expect_true("category" %in% names(result$margins))
    expect_true("target_pct" %in% names(result$margins) ||
                "target_percent" %in% names(result$margins))
  }
})

test_that("rim weights with single variable produce valid output", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- data.frame(
    Gender = sample(c("Male", "Female"), 100, replace = TRUE, prob = c(0.6, 0.4)),
    stringsAsFactors = FALSE
  )

  targets <- list(
    Gender = c("Male" = 0.50, "Female" = 0.50)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  expect_length(result$weights, 100)
  expect_true(all(result$weights > 0))
})

# ==============================================================================
# DEMANDING TARGETS: calibration_method matters
# ==============================================================================
# A rim target that needs a 3x+ stretch on one category is feasible, but the
# default calfun ("raking") cannot reach it at any bound setting. Logit can.
# These tests pin that behaviour, and pin the refusal that tells a config
# author which lever to pull.

#' Survey sample deliberately far from the rim targets below.
#' Rural is ~8% of the sample against a 27% target — a 3.3x stretch.
#' @keywords internal
create_demanding_survey <- function(n = 1101, seed = 7) {
  set.seed(seed)
  data.frame(
    Region = sample(c("Metro", "Urban", "Rural"), n, replace = TRUE,
                    prob = c(0.62, 0.30, 0.08)),
    Gender = sample(c("Male", "Female"), n, replace = TRUE,
                    prob = c(0.40, 0.60)),
    Age = sample(c("18-34", "35-54", "55+"), n, replace = TRUE,
                 prob = c(0.50, 0.32, 0.18)),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
demanding_targets <- function() {
  list(
    Region = c("Metro" = 0.30, "Urban" = 0.43, "Rural" = 0.27),
    Gender = c("Male" = 0.49, "Female" = 0.51),
    Age = c("18-34" = 0.28, "35-54" = 0.36, "55+" = 0.36)
  )
}

test_that("logit converges on a demanding target that raking cannot reach", {
  skip_if_not_installed("survey")

  data <- create_demanding_survey()
  targets <- demanding_targets()

  # Raking fails even with generous bounds and iterations
  expect_error(
    suppressWarnings(calculate_rim_weights(
      data = data, target_list = targets,
      cap_weights = c(0.05, 20), calibration_method = "raking",
      max_iterations = 200, verbose = FALSE
    )),
    class = "turas_refusal"
  )

  # Logit finds the solution
  result <- calculate_rim_weights(
    data = data, target_list = targets,
    cap_weights = c(0.1, 10), calibration_method = "logit",
    max_iterations = 200, verbose = FALSE
  )

  expect_true(all(result$weights > 0))
  expect_true(all(result$weights >= 0.1 & result$weights <= 10))
  # Every achieved margin lands on its target
  expect_true(max(abs(result$margins$diff_pct)) < 0.01)
})

test_that("non-convergence refusal names logit as the fix", {
  skip_if_not_installed("survey")

  data <- create_demanding_survey()
  targets <- demanding_targets()

  refusal <- tryCatch(
    suppressWarnings(calculate_rim_weights(
      data = data, target_list = targets,
      cap_weights = c(0.3, 3.0), calibration_method = "raking",
      max_iterations = 50, verbose = FALSE
    )),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "MODEL_NO_CONVERGENCE")
  # survey's own error is the bare string "Calibration failed" — the refusal
  # must still classify it as non-convergence and quote the achieved epsilon.
  expect_match(conditionMessage(refusal), "logit")
  expect_match(conditionMessage(refusal), "Failed to converge: eps=")
})

test_that("config-driven path surfaces the calibration_method refusal and honours logit", {
  skip_if_not_installed("survey")
  skip_if_not_installed("openxlsx")

  data <- create_demanding_survey()

  # Build a config whose Advanced_Settings carries calibration_method
  build_config <- function(method) {
    data_path <- file.path(tempdir(), "demanding_survey.csv")
    write.csv(data, data_path, row.names = FALSE)

    config_path <- file.path(tempdir(), paste0("demanding_config_", method, ".xlsx"))
    wb <- openxlsx::createWorkbook()

    openxlsx::addWorksheet(wb, "General")
    openxlsx::writeData(wb, "General", data.frame(
      Setting = c("project_name", "data_file", "save_diagnostics"),
      Value = c("Demanding Rim Target", data_path, "N"),
      stringsAsFactors = FALSE
    ))

    openxlsx::addWorksheet(wb, "Weight_Specifications")
    openxlsx::writeData(wb, "Weight_Specifications", data.frame(
      weight_name = "rim_weight", method = "rim",
      description = "Demanding rim target", apply_trimming = "N",
      trim_method = NA, trim_value = NA, stringsAsFactors = FALSE
    ))

    openxlsx::addWorksheet(wb, "Rim_Targets")
    openxlsx::writeData(wb, "Rim_Targets", data.frame(
      weight_name = rep("rim_weight", 8),
      variable = c(rep("Region", 3), rep("Gender", 2), rep("Age", 3)),
      category = c("Metro", "Urban", "Rural", "Male", "Female",
                   "18-34", "35-54", "55+"),
      target_percent = c(30, 43, 27, 49, 51, 28, 36, 36),
      stringsAsFactors = FALSE
    ))

    openxlsx::addWorksheet(wb, "Advanced_Settings")
    openxlsx::writeData(wb, "Advanced_Settings", data.frame(
      weight_name = "rim_weight",
      max_iterations = 200,
      convergence_tolerance = 1e-7,
      calibration_method = method,
      weight_bounds = "0.1,10.0",
      stringsAsFactors = FALSE
    ))

    openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
    config_path
  }

  # Default method from config: raking — must refuse, and must say "logit"
  raking_config <- load_weighting_config(build_config("raking"), verbose = FALSE)
  refusal <- tryCatch(
    suppressWarnings(calculate_rim_weights_from_config(
      data = data, config = raking_config,
      weight_name = "rim_weight", verbose = FALSE
    )),
    turas_refusal = function(e) e
  )
  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "MODEL_NO_CONVERGENCE")
  expect_match(conditionMessage(refusal), "logit")

  # Same config with calibration_method = logit succeeds
  logit_config <- load_weighting_config(build_config("logit"), verbose = FALSE)
  result <- calculate_rim_weights_from_config(
    data = data, config = logit_config,
    weight_name = "rim_weight", verbose = FALSE
  )
  expect_equal(result$method, "logit")
  expect_true(all(result$weights > 0))
  expect_true(max(abs(result$margins$diff_pct)) < 0.01)
})

test_that("linear calibration refuses when it produces zero or negative weights", {
  skip_if_not_installed("survey")

  data <- create_demanding_survey()
  targets <- demanding_targets()

  # Lower bound of zero: linear parks respondents exactly on it
  zero_refusal <- tryCatch(
    calculate_rim_weights(
      data = data, target_list = targets,
      cap_weights = c(0, 10), calibration_method = "linear",
      max_iterations = 200, verbose = FALSE
    ),
    turas_refusal = function(e) e
  )
  expect_s3_class(zero_refusal, "turas_refusal")
  expect_equal(zero_refusal$code, "CALC_NONPOSITIVE_WEIGHTS")

  # Unbounded: linear goes negative
  negative_refusal <- tryCatch(
    calculate_rim_weights(
      data = data, target_list = targets,
      cap_weights = c(-Inf, Inf), calibration_method = "linear",
      max_iterations = 200, verbose = FALSE
    ),
    turas_refusal = function(e) e
  )
  expect_s3_class(negative_refusal, "turas_refusal")
  expect_equal(negative_refusal$code, "CALC_NONPOSITIVE_WEIGHTS")

  # A positive lower bound keeps linear usable
  ok <- calculate_rim_weights(
    data = data, target_list = targets,
    cap_weights = c(0.1, 10), calibration_method = "linear",
    max_iterations = 200, verbose = FALSE
  )
  expect_true(all(ok$weights > 0))
})
