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

#' Run Van Westendorp PSM Analysis
#'
#' Wrapper around pricesensitivitymeter package providing consistent
#' Turas interface and extended output formatting. Includes NMS extension
#' for purchase probability calibration when purchase intent columns are provided.
#'
#' @param data Data frame containing price perception responses
#' @param config Configuration list with van_westendorp settings
#'
#' @return List containing price_points, ranges, curves, nms_results,
#'         descriptives, diagnostics
#'
#' @export
run_van_westendorp <- function(data, config) {

  # Load package
  if (!requireNamespace("pricesensitivitymeter", quietly = TRUE)) {
    stop("Package 'pricesensitivitymeter' required. Install with: install.packages('pricesensitivitymeter')",
         call. = FALSE)
  }

  vw <- config$van_westendorp

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
