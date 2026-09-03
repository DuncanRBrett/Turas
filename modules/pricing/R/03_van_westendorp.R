# ==============================================================================
# TURAS PRICING MODULE - VAN WESTENDORP PRICE SENSITIVITY METER
# ==============================================================================
#
# Purpose: Implement Van Westendorp PSM analysis using pricesensitivitymeter package
#          Includes Newton-Miller-Smith (NMS) extension support
# Version: 12.0
# Date: 2026-03-20
#
# References:
# - Van Westendorp, P. (1976). NSS Price Sensitivity Meter (PSM)
# - Newton, Miller, Smith (1993). NMS extension for purchase probability
#
# ==============================================================================

# ==============================================================================
# VAN WESTENDORP VALIDATION AND QUALITY CHECKS
# ==============================================================================

#' Validate Van Westendorp Data Comprehensively
#'
#' Performs strict validation of Van Westendorp PSM data ensuring all 4 price
#' questions are present, valid, and logically consistent.
#'
#' @param data Data frame containing price perception responses
#' @param config Configuration list with van_westendorp column mappings
#' @param verbose Logical, print detailed validation output
#'
#' @return List with validation results:
#'   - is_valid: Logical, overall validation pass/fail
#'   - quality_score: Numeric 0-100 quality score
#'   - n_respondents: Total respondents
#'   - n_valid: Respondents with complete, valid data
#'   - n_excluded: Respondents excluded
#'   - checks: List of individual check results
#'   - issues: Character vector of issue descriptions
#'   - recommendations: Character vector of recommendations
#'
#' @details
#' Validation checks performed:
#' 1. All 4 VW columns present in data
#' 2. All 4 VW columns mapped in config
#' 3. Numeric data type (or convertible to numeric)
#' 4. Minimum sample size (30+ respondents)
#' 5. Logical price ordering per respondent
#' 6. Reasonable price range (no extreme outliers)
#' 7. No duplicate prices within respondent
#' 8. Missing data rate < 20%
#'
#' @export
validate_vw_data <- function(data, config, verbose = TRUE) {

  vw <- config$van_westendorp

  issues <- character(0)
  recommendations <- character(0)
  checks <- list()

  # ============================================================================
  # CHECK 1: All 4 VW columns mapped in config
  # ============================================================================

  required_mappings <- c("col_too_cheap", "col_cheap", "col_expensive", "col_too_expensive")
  missing_mappings <- required_mappings[
    !required_mappings %in% names(vw) |
    sapply(required_mappings, function(k) is.null(vw[[k]]) || (length(vw[[k]]) == 1 && is.na(vw[[k]])))
  ]

  checks$config_complete <- length(missing_mappings) == 0

  if (!checks$config_complete) {
    issues <- c(issues, sprintf(
      "Missing VW column mappings: %s",
      paste(missing_mappings, collapse = ", ")
    ))
    recommendations <- c(recommendations,
      "Configure all 4 VW question mappings in config$van_westendorp:",
      "  col_too_cheap: 'At what price too cheap (quality doubts)?'",
      "  col_cheap: 'At what price a bargain?'",
      "  col_expensive: 'At what price getting expensive?'",
      "  col_too_expensive: 'At what price too expensive to consider?'"
    )
  }

  # ============================================================================
  # CHECK 2: All 4 VW columns present in data
  # ============================================================================

  if (checks$config_complete) {
    col_names <- c(vw$col_too_cheap, vw$col_cheap, vw$col_expensive, vw$col_too_expensive)
    missing_cols <- col_names[!col_names %in% names(data)]

    checks$columns_present <- length(missing_cols) == 0

    if (!checks$columns_present) {
      issues <- c(issues, sprintf(
        "VW columns not found in data: %s",
        paste(missing_cols, collapse = ", ")
      ))
      recommendations <- c(recommendations,
        "Verify column names match data exactly (case-sensitive)"
      )
    }
  } else {
    checks$columns_present <- FALSE
  }

  # Exit early if columns not found
  if (!checks$columns_present) {
    return(list(
      is_valid = FALSE,
      quality_score = 0,
      n_respondents = nrow(data),
      n_valid = 0,
      n_excluded = nrow(data),
      checks = checks,
      issues = issues,
      recommendations = recommendations
    ))
  }

  # ============================================================================
  # Extract data
  # ============================================================================

  too_cheap <- as.numeric(data[[vw$col_too_cheap]])
  cheap <- as.numeric(data[[vw$col_cheap]])
  expensive <- as.numeric(data[[vw$col_expensive]])
  too_expensive <- as.numeric(data[[vw$col_too_expensive]])

  n_total <- length(too_cheap)

  # ============================================================================
  # CHECK 3: Numeric conversion success
  # ============================================================================

  na_too_cheap <- sum(is.na(too_cheap))
  na_cheap <- sum(is.na(cheap))
  na_expensive <- sum(is.na(expensive))
  na_too_expensive <- sum(is.na(too_expensive))

  total_na <- na_too_cheap + na_cheap + na_expensive + na_too_expensive
  na_rate <- total_na / (n_total * 4)

  checks$numeric_valid <- na_rate < 0.20

  if (!checks$numeric_valid) {
    issues <- c(issues, sprintf(
      "High missing/invalid data rate: %.1f%% (threshold: 20%%)",
      na_rate * 100
    ))
    recommendations <- c(recommendations,
      "Review data for non-numeric values, blanks, or text responses"
    )
  }

  # ============================================================================
  # CHECK 4: Minimum sample size
  # ============================================================================

  complete_cases <- !is.na(too_cheap) & !is.na(cheap) &
                    !is.na(expensive) & !is.na(too_expensive)
  n_complete <- sum(complete_cases)

  checks$sample_size <- n_complete >= 30

  if (!checks$sample_size) {
    issues <- c(issues, sprintf(
      "Insufficient sample size: %d complete cases (minimum: 30)",
      n_complete
    ))
    recommendations <- c(recommendations,
      "Collect additional responses before running VW analysis"
    )
  }

  # ============================================================================
  # CHECK 5: Logical price ordering
  # ============================================================================

  # Correct order: too_cheap <= cheap <= expensive <= too_expensive
  if (n_complete > 0) {
    logical_order <- too_cheap[complete_cases] <= cheap[complete_cases] &
                     cheap[complete_cases] <= expensive[complete_cases] &
                     expensive[complete_cases] <= too_expensive[complete_cases]

    n_logical <- sum(logical_order)
    n_violations <- n_complete - n_logical
    violation_rate <- n_violations / n_complete
  } else {
    n_logical <- 0
    n_violations <- 0
    violation_rate <- 0
  }

  checks$logical_order <- violation_rate < 0.10

  if (!checks$logical_order) {
    issues <- c(issues, sprintf(
      "High logical order violation rate: %.1f%% (threshold: 10%%)",
      violation_rate * 100
    ))
    recommendations <- c(recommendations,
      "Review question wording - respondents may be confused",
      "Consider excluding respondents with illogical responses"
    )
  }

  # ============================================================================
  # CHECK 6: Positive prices
  # ============================================================================

  all_prices <- c(too_cheap[complete_cases], cheap[complete_cases],
                  expensive[complete_cases], too_expensive[complete_cases])
  n_non_positive <- sum(all_prices <= 0)

  checks$positive_prices <- n_non_positive == 0

  if (!checks$positive_prices) {
    issues <- c(issues, sprintf(
      "%d non-positive price values found",
      n_non_positive
    ))
    recommendations <- c(recommendations,
      "Remove or correct zero/negative price responses"
    )
  }

  # ============================================================================
  # CHECK 7: Extreme outliers
  # ============================================================================

  if (n_complete > 0) {
    positive_prices <- all_prices[all_prices > 0]
    # Guard against empty positive price vector
    if (length(positive_prices) == 0) {
      median_price <- NA_real_
      iqr_price <- NA_real_
    } else {
      median_price <- median(positive_prices, na.rm = TRUE)
      iqr_price <- IQR(positive_prices, na.rm = TRUE)
    }

    # Extreme if > 10x median or < 0.01x median
    # Guard: only check for extremes if we have a valid median
    if (!is.na(median_price) && median_price > 0) {
      extreme_low <- sum(all_prices < median_price * 0.01, na.rm = TRUE)
      extreme_high <- sum(all_prices > median_price * 10, na.rm = TRUE)
      n_extreme <- extreme_low + extreme_high

      checks$no_extreme_outliers <- n_extreme < n_complete * 4 * 0.05  # < 5% extreme

      if (!checks$no_extreme_outliers) {
        issues <- c(issues, sprintf(
          "%d extreme price values detected (>10x or <0.01x median)",
          n_extreme
        ))
        recommendations <- c(recommendations,
          "Review extreme values for data entry errors"
        )
      }
    } else {
      # Cannot check outliers without valid median
      checks$no_extreme_outliers <- TRUE
    }
  } else {
    checks$no_extreme_outliers <- FALSE
  }

  # ============================================================================
  # CHECK 8: Duplicate prices within respondent
  # ============================================================================

  # Check for respondents who gave identical prices for different questions
  n_all_same <- sum(
    too_cheap[complete_cases] == cheap[complete_cases] &
    cheap[complete_cases] == expensive[complete_cases] &
    expensive[complete_cases] == too_expensive[complete_cases]
  )

  checks$no_duplicates <- n_all_same < n_complete * 0.05  # < 5% all same

  if (!checks$no_duplicates) {
    issues <- c(issues, sprintf(
      "%d respondents gave identical prices for all 4 questions",
      n_all_same
    ))
    recommendations <- c(recommendations,
      "Review for straight-lining or misunderstood questions"
    )
  }

  # ============================================================================
  # Calculate quality score
  # ============================================================================

  # Weight each check
  check_weights <- c(
    config_complete = 15,
    columns_present = 15,
    numeric_valid = 15,
    sample_size = 15,
    logical_order = 20,
    positive_prices = 10,
    no_extreme_outliers = 5,
    no_duplicates = 5
  )

  passed_weight <- sum(check_weights[unlist(checks)])
  quality_score <- passed_weight

  # Determine overall validity
  is_valid <- checks$config_complete &&
              checks$columns_present &&
              checks$numeric_valid &&
              checks$sample_size

  # ============================================================================
  # Print summary if verbose
  # ============================================================================

  if (verbose) {
    cat("\n")
    cat(paste(rep("=", 60), collapse = ""), "\n")
    cat("VAN WESTENDORP DATA VALIDATION\n")
    cat(paste(rep("=", 60), collapse = ""), "\n\n")

    cat(sprintf("Total respondents: %d\n", n_total))
    cat(sprintf("Complete cases: %d (%.1f%%)\n", n_complete, if (n_total > 0) n_complete/n_total * 100 else 0))
    cat(sprintf("Logical responses: %d (%.1f%%)\n", n_logical, if (n_complete > 0) n_logical/n_complete * 100 else 0))
    cat(sprintf("Quality score: %d/100\n\n", quality_score))

    cat("Validation checks:\n")
    for (check_name in names(checks)) {
      status <- if (checks[[check_name]]) "PASS" else "FAIL"
      cat(sprintf("  [%s] %s\n", status, gsub("_", " ", check_name)))
    }

    if (length(issues) > 0) {
      cat("\nIssues found:\n")
      for (issue in issues) {
        cat(sprintf("  - %s\n", issue))
      }
    }

    if (length(recommendations) > 0) {
      cat("\nRecommendations:\n")
      for (rec in recommendations) {
        cat(sprintf("  %s\n", rec))
      }
    }

    cat("\n")
  }

  # ============================================================================
  # Return results
  # ============================================================================

  list(
    is_valid = is_valid,
    quality_score = quality_score,
    n_respondents = n_total,
    n_valid = n_complete,
    n_excluded = n_total - n_complete,
    n_logical = n_logical,
    violation_rate = violation_rate,
    checks = checks,
    issues = issues,
    recommendations = recommendations
  )
}


#' Validate Van Westendorp with TRS Refusal
#'
#' Runs comprehensive validation and refuses analysis if critical checks fail.
#'
#' @param data Data frame containing price perception responses
#' @param config Configuration list with van_westendorp settings
#' @param verbose Logical, print validation output
#'
#' @return Validation result if passing, otherwise raises TRS refusal
#'
#' @export
validate_vw_with_refusal <- function(data, config, verbose = TRUE) {

  validation <- validate_vw_data(data, config, verbose = verbose)

  if (!validation$is_valid) {
    # Determine most critical issue for refusal code
    if (!validation$checks$config_complete) {
      code <- "CFG_VW_INCOMPLETE"
      reason <- "Van Westendorp requires all 4 price questions to be configured"
    } else if (!validation$checks$columns_present) {
      code <- "DATA_VW_COLUMNS_MISSING"
      reason <- "Van Westendorp columns not found in data"
    } else if (!validation$checks$sample_size) {
      code <- "DATA_VW_INSUFFICIENT_SAMPLE"
      reason <- sprintf("Only %d complete cases (minimum: 30)", validation$n_valid)
    } else {
      code <- "DATA_VW_QUALITY"
      reason <- "Data quality too low for reliable analysis"
    }

    pricing_refuse(
      code = code,
      title = "Van Westendorp Validation Failed",
      problem = reason,
      why_it_matters = "Van Westendorp PSM requires all 4 price perception questions with valid, logically consistent responses to produce reliable price points.",
      how_to_fix = validation$recommendations,
      details = list(
        quality_score = validation$quality_score,
        n_valid = validation$n_valid,
        issues = validation$issues
      )
    )
  }

  return(validation)
}


#' Run Van Westendorp PSM Analysis
#'
#' Wrapper around pricesensitivitymeter package providing consistent
#' Turas interface and extended output formatting. Includes NMS extension
#' for purchase probability calibration when purchase intent columns are provided.
#'
#' @param data Data frame containing price perception responses
#' @param config Configuration list with van_westendorp settings
#' @param validate Logical, run comprehensive validation first (default TRUE)
#'
#' @return List containing price_points, ranges, curves, nms_results,
#'         descriptives, diagnostics, validation
#'
#' @export
run_van_westendorp <- function(data, config, validate = TRUE) {

  # Load package
  if (!requireNamespace("pricesensitivitymeter", quietly = TRUE)) {
    pricing_refuse(
      code = "PKG_PSM_MISSING",
      title = "Required Package Missing",
      problem = "Package 'pricesensitivitymeter' is not installed",
      why_it_matters = "Cannot run Van Westendorp analysis without the pricesensitivitymeter package",
      how_to_fix = "Install the package: install.packages('pricesensitivitymeter')"
    )
  }

  vw <- config$van_westendorp

  # ============================================================================
  # STEP 0: Run comprehensive validation if requested
  # ============================================================================

  validation_result <- NULL
  if (validate) {
    validation_result <- validate_vw_with_refusal(data, config, verbose = TRUE)
  }

  # ============================================================================
  # STEP 1: Extract and validate columns
  # ============================================================================

  required_cols <- c(vw$col_too_cheap, vw$col_cheap,
                     vw$col_expensive, vw$col_too_expensive)

  missing_cols <- required_cols[!required_cols %in% names(data)]
  if (length(missing_cols) > 0) {
    pricing_refuse(
      code = "DATA_VW_COLUMNS_MISSING",
      title = "Van Westendorp Columns Not Found",
      problem = sprintf("%d required column(s) missing from data", length(missing_cols)),
      why_it_matters = "Cannot run Van Westendorp analysis without all 4 price perception questions",
      how_to_fix = c(
        "Verify column names in configuration match data exactly (case-sensitive)",
        "Check that all 4 VW questions are present in the data file"
      ),
      missing = missing_cols,
      observed = names(data),
      expected = required_cols
    )
  }

  too_cheap <- as.numeric(data[[vw$col_too_cheap]])
  cheap <- as.numeric(data[[vw$col_cheap]])
  expensive <- as.numeric(data[[vw$col_expensive]])
  too_expensive <- as.numeric(data[[vw$col_too_expensive]])

  # ============================================================================
  # STEP 2: Check for NMS purchase intent columns
  # ============================================================================

  has_nms <- !is.null(vw$col_pi_cheap) &&
             !is.na(vw$col_pi_cheap) &&
             vw$col_pi_cheap %in% names(data)

  pi_cheap <- NULL
  pi_expensive <- NULL

  if (has_nms) {
    pi_cheap <- as.numeric(data[[vw$col_pi_cheap]])

    if (!is.null(vw$col_pi_expensive) &&
        !is.na(vw$col_pi_expensive) &&
        vw$col_pi_expensive %in% names(data)) {
      pi_expensive <- as.numeric(data[[vw$col_pi_expensive]])
    }
  }

  # ============================================================================
  # STEP 3: Run pricesensitivitymeter analysis
  # ============================================================================
  # Weights (review C1). When the config names a weight variable, the price
  # points come from psm_analysis_weighted() on a survey design; before this
  # the headline points were unweighted while the stats pack said "Weighting
  # applied: Yes". A failure on the weighted path refuses; it never falls
  # back to the unweighted estimator.
  weight_var <- config$weight_var
  vw_weights <- NULL
  if (!is.null(weight_var) && !is.na(weight_var) && weight_var %in% names(data)) {
    vw_weights <- as.numeric(data[[weight_var]])
  }

  # Monotonicity semantics (review H3). "flag_only" keeps intransitive
  # respondents in the curves (validate = FALSE, disclosed); "drop" and "fix"
  # run validate = TRUE, which is what every run silently did before.
  behavior <- config$vw_monotonicity_behavior %||% "drop"
  validate_flag <- !identical(behavior, "flag_only")

  psm_fit <- fit_vw_psm(
    too_cheap, cheap, expensive, too_expensive,
    weights = vw_weights, validate = validate_flag,
    pi_cheap = if (has_nms) pi_cheap else NULL,
    pi_expensive = if (has_nms) pi_expensive else NULL,
    pi_scale = vw$pi_scale
  )
  psm_result <- psm_fit$psm
  estimator <- psm_fit$estimator

  # ============================================================================
  # STEP 4: Extract and restructure results
  # ============================================================================

  # Core price points
  price_points <- list(
    PMC = psm_result$pricerange_lower,
    OPP = psm_result$opp,
    IDP = psm_result$idp,
    PME = psm_result$pricerange_upper
  )

  # Ranges
  acceptable_range <- list(
    lower = price_points$PMC,
    upper = price_points$PME,
    width = price_points$PME - price_points$PMC
  )

  optimal_range <- list(
    lower = price_points$OPP,
    upper = price_points$IDP,
    width = price_points$IDP - price_points$OPP
  )

  # Curves for plotting
  curves <- data.frame(
    price = psm_result$data_vanwestendorp$price,
    too_cheap = psm_result$data_vanwestendorp$ecdf_toocheap,
    not_cheap = psm_result$data_vanwestendorp$ecdf_not_cheap,
    cheap = 1 - psm_result$data_vanwestendorp$ecdf_not_cheap,
    not_expensive = psm_result$data_vanwestendorp$ecdf_not_expensive,
    expensive = 1 - psm_result$data_vanwestendorp$ecdf_not_expensive,
    too_expensive = psm_result$data_vanwestendorp$ecdf_tooexpensive,
    stringsAsFactors = FALSE
  )

  # ============================================================================
  # STEP 5: Extract NMS results if available
  # ============================================================================

  nms_results <- NULL

  if (has_nms && !is.null(psm_result$pi_scale)) {
    nms_results <- list(
      trial_optimal = psm_result$price_optimal_reach,
      revenue_optimal = psm_result$price_optimal_revenue,
      data = psm_result$data_nms
    )
  }

  # ============================================================================
  # STEP 6: Calculate descriptive statistics
  # ============================================================================

  calc_desc <- function(x, name) {
    x <- x[!is.na(x)]
    data.frame(
      variable = name,
      n = length(x),
      mean = mean(x),
      median = median(x),
      sd = sd(x),
      min = min(x),
      max = max(x),
      stringsAsFactors = FALSE
    )
  }

  descriptives <- rbind(
    calc_desc(too_cheap, "Too Cheap"),
    calc_desc(cheap, "Cheap/Bargain"),
    calc_desc(expensive, "Expensive"),
    calc_desc(too_expensive, "Too Expensive")
  )

  # ============================================================================
  # STEP 7: Compile diagnostics
  # ============================================================================

  # Count valid cases
  complete_cases <- !is.na(too_cheap) & !is.na(cheap) &
                    !is.na(expensive) & !is.na(too_expensive)
  n_total <- length(too_cheap)
  n_valid <- sum(complete_cases)

  # Check monotonicity violations
  monotonic <- too_cheap[complete_cases] <= cheap[complete_cases] &
               cheap[complete_cases] <= expensive[complete_cases] &
               expensive[complete_cases] <= too_expensive[complete_cases]
  n_violations <- sum(!monotonic)
  violation_rate <- if (n_valid > 0) n_violations / n_valid else 0

  # The analysed base is psm's own: the complete cases it received minus the
  # cases it set aside as invalid (review H3: the old n_valid counted
  # respondents the curves had excluded).
  # psm counts the intransitive cases whether or not validate excluded them;
  # under validate = FALSE they stay in the curves, so the analysed base is
  # the whole complete-case sample.
  n_invalid_psm <- as.integer(psm_result$invalid_cases %||% 0L)
  n_analysed <- as.integer(psm_result$total_sample %||% n_valid) -
    (if (validate_flag) n_invalid_psm else 0L)

  diagnostics <- list(
    n_total = n_total,
    n_valid = n_valid,
    n_excluded = n_total - n_valid,
    n_analysed = n_analysed,
    n_invalid_psm = n_invalid_psm,
    n_violations = n_violations,
    violation_rate = violation_rate,
    monotonicity_behavior = behavior,
    validate_flag = validate_flag,
    weighted = !is.null(vw_weights),
    estimator = estimator,
    price_range = range(c(too_cheap, cheap, expensive, too_expensive), na.rm = TRUE),
    has_nms = has_nms,
    method = "van_westendorp"
  )

  # Add warning if violation rate high
  if (violation_rate > 0.10) {
    diagnostics$warning <- sprintf(
      "%.1f%% of respondents gave illogical price sequences. Review data quality.",
      violation_rate * 100
    )
  }

  # ============================================================================
  # STEP 8: Calculate confidence intervals if requested (using existing bootstrap)
  # ============================================================================

  confidence_intervals <- NULL
  if (isTRUE(vw$calculate_confidence)) {
    # The bootstrap brackets the estimator that was reported: same validate
    # flag, same weighting, and the table's estimate column is the headline
    # point (review C3).
    confidence_intervals <- bootstrap_vw_confidence(
      too_cheap, cheap, expensive, too_expensive,
      weights = vw_weights,
      validate = validate_flag,
      point_estimates = unlist(price_points[c("PMC", "OPP", "IDP", "PME")]),
      iterations = vw$bootstrap_iterations %||% 1000,
      level = vw$confidence_level %||% 0.95
    )
  }

  # ============================================================================
  # STEP 9: Return structured results
  # ============================================================================

  list(
    price_points = price_points,
    acceptable_range = acceptable_range,
    optimal_range = optimal_range,
    curves = curves,
    nms_results = nms_results,
    confidence_intervals = confidence_intervals,
    descriptives = descriptives,
    diagnostics = diagnostics,
    validation = validation_result,  # Include validation results
    raw_psm = psm_result  # Keep for advanced users
  )
}


#' Fit The Price Sensitivity Meter, Weighted Or Not
#'
#' One place that decides which pricesensitivitymeter estimator runs. With
#' weights it builds a `survey::svydesign` and calls `psm_analysis_weighted()`;
#' without, `psm_analysis()`. The headline run and every bootstrap replicate
#' go through here, so they cannot disagree on the estimator (review C1, C3).
#'
#' @param too_cheap,cheap,expensive,too_expensive Numeric vectors.
#' @param weights Numeric vector of case weights, or NULL for unweighted.
#' @param validate Logical, exclude intransitive respondents inside psm.
#' @param pi_cheap,pi_expensive Optional NMS purchase-intent vectors.
#' @param pi_scale Optional NMS scale (5 or 100).
#' @param interpolate Logical, interpolate the curves.
#' @return A list with `psm` (the psm object) and `estimator` (a sentence).
#' @keywords internal
fit_vw_psm <- function(too_cheap, cheap, expensive, too_expensive,
                       weights = NULL, validate = TRUE,
                       pi_cheap = NULL, pi_expensive = NULL, pi_scale = NULL,
                       interpolate = TRUE) {

  nms_args <- list()
  if (!is.null(pi_cheap)) {
    nms_args$pi_cheap <- pi_cheap
    if (!is.null(pi_expensive)) nms_args$pi_expensive <- pi_expensive
    if (!is.null(pi_scale) && !is.na(pi_scale)) nms_args$pi_scale <- as.numeric(pi_scale)
  }

  if (is.null(weights)) {
    psm <- do.call(pricesensitivitymeter::psm_analysis, c(list(
      toocheap = too_cheap, cheap = cheap, expensive = expensive,
      tooexpensive = too_expensive, validate = validate,
      interpolate = interpolate, interpolation_steps = 0.1
    ), nms_args))
    return(list(psm = psm, estimator = "psm_analysis (unweighted)"))
  }

  if (!requireNamespace("survey", quietly = TRUE)) {
    pricing_refuse(
      code = "PKG_SURVEY_MISSING",
      title = "Package survey Is Not Installed",
      problem = "A weight variable is configured, and weighted Van Westendorp needs the survey package.",
      why_it_matters = "Without it the price points could only be computed unweighted, which is not what the config asked for.",
      how_to_fix = "Install it: renv::install('survey'), or remove Weight_Variable to run unweighted."
    )
  }

  bad_w <- is.na(weights) | !is.finite(weights) | weights <= 0
  if (any(bad_w)) {
    pricing_refuse(
      code = "DATA_VW_WEIGHTS_INVALID",
      title = "Weights Reaching The Van Westendorp Estimator Are Not Usable",
      problem = sprintf("%d weight(s) are missing, non-finite or not positive.", sum(bad_w)),
      why_it_matters = "The survey design cannot carry them and the price points would be computed on a different base than the one declared.",
      how_to_fix = "Exclude those respondents upstream or repair the weight column."
    )
  }

  df <- data.frame(tc = too_cheap, ch = cheap, ex = expensive, te = too_expensive,
                   w = weights)
  pi_names <- list()
  if (!is.null(pi_cheap)) {
    df$pic <- pi_cheap
    pi_names$pi_cheap <- "pic"
    if (!is.null(pi_expensive)) {
      df$pie <- pi_expensive
      pi_names$pi_expensive <- "pie"
    }
    if (!is.null(pi_scale) && !is.na(pi_scale)) pi_names$pi_scale <- as.numeric(pi_scale)
  }

  psm <- tryCatch({
    design <- survey::svydesign(ids = ~1, weights = ~w, data = df)
    do.call(pricesensitivitymeter::psm_analysis_weighted, c(list(
      toocheap = "tc", cheap = "ch", expensive = "ex", tooexpensive = "te",
      design = design, validate = validate,
      interpolate = interpolate, interpolation_steps = 0.1
    ), pi_names))
  }, error = function(e) {
    pricing_refuse(
      code = "MODEL_VW_WEIGHTED_FAILED",
      title = "Weighted Van Westendorp Estimation Failed",
      problem = sprintf("psm_analysis_weighted() stopped with: %s", conditionMessage(e)),
      why_it_matters = "The config asks for weighted price points. Falling back to unweighted ones would ship numbers on a different population under a weighted label.",
      how_to_fix = c(
        "Check the weight column for extreme or zero values.",
        "Check that the four price columns are numeric and mostly complete.",
        "Remove Weight_Variable to run unweighted, and say so in the report."
      )
    )
  })

  list(psm = psm, estimator = "psm_analysis_weighted (survey design)")
}


#' Bootstrap Confidence Intervals for Van Westendorp
#'
#' Percentile bootstrap intervals for the four price points, around the
#' estimator that was reported.
#'
#' Policy (one policy, shared with the Gabor-Granger bootstrap, review C3 and
#' M14): respondents are resampled with equal probability, each carrying its
#' own weight, and every replicate is estimated by the same routine as the
#' headline, with the same `validate` flag and the same weighting. The
#' `estimate` column is the headline point, not the bootstrap mean; the
#' bootstrap mean has its own column.
#'
#' @param too_cheap,cheap,expensive,too_expensive Numeric vectors.
#' @param weights Numeric vector of case weights, or NULL.
#' @param validate Logical, the headline's validate flag.
#' @param point_estimates Named numeric (PMC, OPP, IDP, PME): the headline
#'   points. When NULL the bootstrap mean fills the column and says so.
#' @param iterations Number of bootstrap iterations.
#' @param level Confidence level (e.g. 0.95).
#'
#' @return Data frame with metric, estimate, boot_mean, se, ci_lower,
#'   ci_upper; attribute `policy` describes the resampling. NULL when fewer
#'   than ten replicates succeeded.
#'
#' @keywords internal
bootstrap_vw_confidence <- function(too_cheap, cheap, expensive, too_expensive,
                                    weights = NULL, validate = TRUE,
                                    point_estimates = NULL,
                                    iterations = 1000, level = 0.95) {

  alpha <- 1 - level

  # Complete cases only; psm receives the same base as the headline.
  complete_idx <- !is.na(too_cheap) & !is.na(cheap) &
                  !is.na(expensive) & !is.na(too_expensive)
  if (!is.null(weights)) complete_idx <- complete_idx & !is.na(weights) & weights > 0

  too_cheap_c <- too_cheap[complete_idx]
  cheap_c <- cheap[complete_idx]
  expensive_c <- expensive[complete_idx]
  too_expensive_c <- too_expensive[complete_idx]
  weights_c <- if (!is.null(weights)) as.numeric(weights[complete_idx]) else NULL

  n_c <- length(too_cheap_c)

  if (n_c < 30) {
    pricing_console_warning(
      sprintf("Sample size (n=%d) may be too small for reliable bootstrap confidence intervals", n_c),
      context = "VW Bootstrap CI"
    )
  }

  boot_results <- matrix(NA_real_, nrow = iterations, ncol = 4)
  colnames(boot_results) <- c("PMC", "OPP", "IDP", "PME")

  successful <- 0L
  for (i in seq_len(iterations)) {
    idx <- sample.int(n_c, n_c, replace = TRUE)
    fit <- tryCatch(
      fit_vw_psm(too_cheap_c[idx], cheap_c[idx], expensive_c[idx], too_expensive_c[idx],
                 weights = if (!is.null(weights_c)) weights_c[idx] else NULL,
                 validate = validate, interpolate = TRUE),
      error = function(e) NULL
    )
    if (is.null(fit)) next
    psm_boot <- fit$psm
    boot_results[i, ] <- c(psm_boot$pricerange_lower, psm_boot$opp,
                           psm_boot$idp, psm_boot$pricerange_upper)
    successful <- successful + 1L
  }

  if (successful < iterations * 0.5) {
    pricing_console_warning(
      sprintf("VW bootstrap: only %d/%d iterations succeeded, so the intervals may be unreliable",
              successful, iterations),
      context = "VW Bootstrap CI"
    )
  }

  if (successful < 10L) {
    pricing_console_warning(
      sprintf("VW bootstrap: only %d successful iterations, returning no intervals", successful),
      context = "VW Bootstrap CI"
    )
    return(NULL)
  }

  ci_lower <- apply(boot_results, 2, quantile, probs = alpha / 2, na.rm = TRUE)
  ci_upper <- apply(boot_results, 2, quantile, probs = 1 - alpha / 2, na.rm = TRUE)
  boot_mean <- colMeans(boot_results, na.rm = TRUE)
  boot_se <- apply(boot_results, 2, sd, na.rm = TRUE)

  metrics <- c("PMC", "OPP", "IDP", "PME")
  estimate <- if (!is.null(point_estimates)) {
    as.numeric(point_estimates[metrics])
  } else {
    boot_mean
  }

  out <- data.frame(
    metric = metrics,
    estimate = estimate,
    boot_mean = as.numeric(boot_mean),
    se = as.numeric(boot_se),
    ci_lower = as.numeric(ci_lower),
    ci_upper = as.numeric(ci_upper),
    n_successful = successful,
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  attr(out, "policy") <- paste0(
    "Respondents resampled with equal probability carrying their weights; ",
    "each replicate estimated by ", if (is.null(weights_c)) "psm_analysis" else "psm_analysis_weighted",
    " with validate = ", if (validate) "TRUE" else "FALSE",
    "; estimate column is the headline point",
    if (is.null(point_estimates)) " (bootstrap mean, no headline supplied)" else ""
  )
  out
}
