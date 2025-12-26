# ==============================================================================
# TURAS PRICING MODULE - VAN WESTENDORP PRICE SENSITIVITY METER
# ==============================================================================
#
# Purpose: Implement Van Westendorp PSM analysis using pricesensitivitymeter package
#          Includes Newton-Miller-Smith (NMS) extension support
# Version: 2.0.0
# Date: 2025-12-11
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
  missing_mappings <- required_mappings[!required_mappings %in% names(vw) |
                                         sapply(vw[required_mappings], is.null) |
                                         sapply(vw[required_mappings], is.na)]

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
  logical_order <- too_cheap[complete_cases] <= cheap[complete_cases] &
                   cheap[complete_cases] <= expensive[complete_cases] &
                   expensive[complete_cases] <= too_expensive[complete_cases]

  n_logical <- sum(logical_order)
  n_violations <- n_complete - n_logical
  violation_rate <- n_violations / n_complete

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
    median_price <- median(all_prices[all_prices > 0], na.rm = TRUE)
    iqr_price <- IQR(all_prices[all_prices > 0], na.rm = TRUE)

    # Extreme if > 10x median or < 0.01x median
    extreme_low <- sum(all_prices < median_price * 0.01)
    extreme_high <- sum(all_prices > median_price * 10)
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
    cat(sprintf("Complete cases: %d (%.1f%%)\n", n_complete, n_complete/n_total * 100))
    cat(sprintf("Logical responses: %d (%.1f%%)\n", n_logical, n_logical/n_complete * 100))
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

    # Source guard if available
    if (exists("pricing_refuse", mode = "function")) {
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
    } else {
      stop(sprintf("[%s] %s", code, reason), call. = FALSE)
    }
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
    stop("Package 'pricesensitivitymeter' required. Install with: install.packages('pricesensitivitymeter')",
         call. = FALSE)
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
    stop(sprintf("Columns not found: %s\nAvailable: %s",
                 paste(missing_cols, collapse = ", "),
                 paste(names(data), collapse = ", ")),
         call. = FALSE)
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

  psm_args <- list(
    toocheap = too_cheap,
    cheap = cheap,
    expensive = expensive,
    tooexpensive = too_expensive,
    validate = TRUE,
    interpolate = TRUE,
    interpolation_steps = 500
  )

  # Add NMS parameters if available
  if (has_nms) {
    psm_args$pi_cheap <- pi_cheap
    if (!is.null(pi_expensive)) {
      psm_args$pi_expensive <- pi_expensive
    }
  }

  psm_result <- do.call(pricesensitivitymeter::psm_analysis, psm_args)

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
      trial_optimal = psm_result$price_optimal_trial,
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
  violation_rate <- n_violations / n_valid

  diagnostics <- list(
    n_total = n_total,
    n_valid = n_valid,
    n_excluded = n_total - n_valid,
    n_violations = n_violations,
    violation_rate = violation_rate,
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
    confidence_intervals <- bootstrap_vw_confidence(
      too_cheap, cheap, expensive, too_expensive,
      weights = NULL,
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


#' Bootstrap Confidence Intervals for Van Westendorp
#'
#' Calculates confidence intervals for price points using bootstrap resampling.
#'
#' @param too_cheap Vector of "too cheap" prices
#' @param cheap Vector of "bargain" prices
#' @param expensive Vector of "expensive" prices
#' @param too_expensive Vector of "too expensive" prices
#' @param weights Vector of case weights (defaults to equal weights if NULL)
#' @param iterations Number of bootstrap iterations
#' @param level Confidence level (e.g., 0.95 for 95% CI)
#'
#' @return Data frame with price point estimates and confidence intervals
#'
#' @keywords internal
bootstrap_vw_confidence <- function(too_cheap, cheap, expensive, too_expensive,
                                    weights = NULL,
                                    iterations = 1000, level = 0.95) {

  n <- length(too_cheap)
  alpha <- 1 - level

  # Remove NA cases for bootstrap
  complete_idx <- !is.na(too_cheap) & !is.na(cheap) &
                  !is.na(expensive) & !is.na(too_expensive)

  too_cheap_c <- too_cheap[complete_idx]
  cheap_c <- cheap[complete_idx]
  expensive_c <- expensive[complete_idx]
  too_expensive_c <- too_expensive[complete_idx]

  n_c <- length(too_cheap_c)

  if (n_c < 30) {
    warning("Sample size too small for reliable bootstrap confidence intervals",
            call. = FALSE)
  }

  # Storage for bootstrap results
  boot_results <- matrix(NA, nrow = iterations, ncol = 4)
  colnames(boot_results) <- c("PMC", "OPP", "IDP", "PME")

  # Run bootstrap using pricesensitivitymeter
  for (i in seq_len(iterations)) {
    # Resample respondents with replacement
    idx <- sample(n_c, n_c, replace = TRUE)

    boot_too_cheap <- too_cheap_c[idx]
    boot_cheap <- cheap_c[idx]
    boot_expensive <- expensive_c[idx]
    boot_too_expensive <- too_expensive_c[idx]

    # Run analysis
    tryCatch({
      psm_boot <- pricesensitivitymeter::psm_analysis(
        toocheap = boot_too_cheap,
        cheap = boot_cheap,
        expensive = boot_expensive,
        tooexpensive = boot_too_expensive,
        validate = FALSE,
        interpolate = TRUE
      )

      boot_results[i, ] <- c(
        psm_boot$pricerange_lower,
        psm_boot$opp,
        psm_boot$idp,
        psm_boot$pricerange_upper
      )
    }, error = function(e) {
      # Skip failed iterations
    })
  }

  # Calculate percentile confidence intervals
  ci_lower <- apply(boot_results, 2, quantile, probs = alpha/2, na.rm = TRUE)
  ci_upper <- apply(boot_results, 2, quantile, probs = 1 - alpha/2, na.rm = TRUE)
  ci_mean <- colMeans(boot_results, na.rm = TRUE)
  ci_se <- apply(boot_results, 2, sd, na.rm = TRUE)

  data.frame(
    metric = c("PMC", "OPP", "IDP", "PME"),
    estimate = ci_mean,
    se = ci_se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    stringsAsFactors = FALSE
  )
}
