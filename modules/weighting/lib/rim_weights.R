# ==============================================================================
# WEIGHTING MODULE - RIM WEIGHT CALCULATION
# ==============================================================================
# Calculate rim weights using iterative proportional fitting (raking/calibration)
# Part of TURAS Weighting Module v2.0
#
# METHODOLOGY:
# Rim weighting (also called raking or iterative proportional fitting)
# adjusts sample weights to match multiple target marginal distributions
# simultaneously. Uses the survey package calibrate() function.
#
# v2.0 CHANGES (2025-12-25):
# - Migrated from anesrake to survey::calibrate() for long-term maintainability
# - Uses modern, actively-maintained survey package (Thomas Lumley)
# - Better weight bound control during calibration (not just trimming after)
# - Support for multiple calibration methods (raking, linear, logit)
# - Foundation for future variance estimation capabilities
# - Support for base weights (rim on top of design weights)
#
# USE CASES:
# - Online panel samples requiring demographic adjustment
# - Quota samples needing rebalancing to population targets
# - General population surveys with known demographics
# - Rim weighting on top of design weights (combined weighting)
# ==============================================================================

#' Check survey Package Availability
#'
#' Checks if survey package is installed and provides installation instructions if not.
#'
#' @return Invisible TRUE if available, stops with error if not
#' @keywords internal
check_survey_available <- function() {
  if (!requireNamespace("survey", quietly = TRUE)) {
    stop(paste0(
      "\n",
      strrep("=", 70), "\n",
      "PACKAGE REQUIRED: survey\n",
      strrep("=", 70), "\n\n",
      "The 'survey' package is required for rim weighting but is not installed.\n\n",
      "To install, run:\n",
      "  install.packages('survey')\n\n",
      "This package provides robust, industry-standard survey calibration\n",
      "and raking algorithms.\n"
    ), call. = FALSE)
  }
  invisible(TRUE)
}

#' Calculate Rim Weights
#'
#' Calculates rim weights using survey package's calibrate() function.
#' Supports multiple calibration methods, weight bounds during fitting,
#' and optional base weights for combined weighting (rim-on-design).
#'
#' @param data Data frame, survey data
#' @param target_list Named list, variable -> named vector of target proportions (0-1 scale)
#' @param base_weights Numeric vector of base/design weights (default: NULL = all weights start at 1)
#' @param caseid Character, name of ID column (default: NULL = not used, deprecated)
#' @param max_iterations Integer, maximum calibration iterations (default: 50)
#' @param convergence_tolerance Numeric, convergence epsilon (default: 1e-7)
#' @param cap_weights Numeric, weight bounds during calibration as c(lower, upper) or single upper value (default: c(0.3, 3.0))
#' @param calibration_method Character, calibration function: "raking" (default), "linear", "logit"
#' @param verbose Logical, print progress messages (default: FALSE)
#' @return List with $weights, $converged, $margins, $design, $diagnostics
#' @export
#'
#' @examples
#' # Basic rim weighting
#' targets <- list(
#'   Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
#'   Gender = c("Male" = 0.48, "Female" = 0.52)
#' )
#' result <- calculate_rim_weights(data, targets)
#'
#' # Rim weighting on top of design weights
#' result <- calculate_rim_weights(data, targets, base_weights = data$design_weight)
calculate_rim_weights <- function(data,
                                  target_list,
                                  base_weights = NULL,
                                  caseid = NULL,
                                  max_iterations = 50,
                                  convergence_tolerance = 1e-7,
                                  cap_weights = NULL,
                                  calibration_method = "raking",
                                  verbose = FALSE) {

  # Check package availability
  check_survey_available()

  # Validate inputs
  if (!is.data.frame(data) || nrow(data) == 0) {
    stop("data must be a non-empty data frame", call. = FALSE)
  }

  if (!is.list(target_list) || length(target_list) == 0) {
    stop("target_list must be a non-empty named list", call. = FALSE)
  }

  # Validate all target variables exist
  missing_vars <- setdiff(names(target_list), names(data))
  if (length(missing_vars) > 0) {
    stop(sprintf(
      "Target variables not found in data: %s\nAvailable: %s",
      paste(missing_vars, collapse = ", "),
      paste(head(names(data), 15), collapse = ", ")
    ), call. = FALSE)
  }

  # Validate base_weights if provided
  if (!is.null(base_weights)) {
    if (length(base_weights) != nrow(data)) {
      stop(sprintf(
        "base_weights length (%d) must match data rows (%d)",
        length(base_weights), nrow(data)
      ), call. = FALSE)
    }
    if (any(base_weights[!is.na(base_weights)] <= 0)) {
      stop("base_weights must be positive (or NA)", call. = FALSE)
    }
  }

  # Handle cap_weights parameter
  # Can be: NULL, single value (upper only), or c(lower, upper)
  if (is.null(cap_weights)) {
    bounds <- c(0.3, 3.0)  # Reasonable defaults
  } else if (length(cap_weights) == 1) {
    bounds <- c(0.3, cap_weights)  # Use provided upper, default lower
  } else if (length(cap_weights) == 2) {
    bounds <- cap_weights
  } else {
    stop("cap_weights must be NULL, single value, or c(lower, upper)", call. = FALSE)
  }

  # Validate calibration method
  valid_methods <- c("raking", "linear", "logit")
  if (!tolower(calibration_method) %in% valid_methods) {
    stop(sprintf(
      "calibration_method must be one of: %s\nGot: '%s'",
      paste(valid_methods, collapse = ", "),
      calibration_method
    ), call. = FALSE)
  }

  if (verbose) {
    message("\nCalculating rim weights using survey::calibrate()...")
    message("  Variables: ", paste(names(target_list), collapse = ", "))
    message("  Method: ", calibration_method)
    message("  Weight bounds: [", bounds[1], ", ", bounds[2], "]")
    message("  Max iterations: ", max_iterations)
    message("  Convergence epsilon: ", convergence_tolerance)
    if (!is.null(base_weights)) {
      message("  Base weights: Provided (rim-on-design mode)")
    }
  }

  # Prepare data for calibration
  # survey requires factors with levels matching target names
  rake_data <- data

  for (var in names(target_list)) {
    # Convert to character, then to factor with target levels
    rake_data[[var]] <- as.character(rake_data[[var]])
    target_levels <- names(target_list[[var]])
    rake_data[[var]] <- factor(rake_data[[var]], levels = target_levels)

    # Check for unmatched levels - REFUSE if validation missed this
    n_na <- sum(is.na(rake_data[[var]]))
    if (n_na > 0) {
      unmatched_vals <- paste(unique(as.character(data[[var]][is.na(rake_data[[var]])])), collapse = ", ")
      stop(sprintf(
        "Variable '%s': %d values not in target categories.\nThis should have been caught by validation.\nUnmatched values: %s",
        var, n_na, unmatched_vals
      ), call. = FALSE)
    }
  }

  # Remove rows with any NA in weighting variables
  complete_idx <- complete.cases(rake_data[, names(target_list), drop = FALSE])

  # Also exclude rows with NA base weights if provided
  if (!is.null(base_weights)) {
    complete_idx <- complete_idx & !is.na(base_weights)
  }

  if (sum(!complete_idx) > 0) {
    if (verbose) {
      message(sprintf("  Excluding %d rows with missing weighting variables or base weights",
                     sum(!complete_idx)))
    }
    rake_data <- rake_data[complete_idx, , drop = FALSE]
  }

  # Set up starting weights
  if (is.null(base_weights)) {
    starting_weights <- rep(1, nrow(rake_data))
  } else {
    starting_weights <- base_weights[complete_idx]
  }

  # Create survey design object with starting weights
  svy_design <- survey::svydesign(
    ids = ~1,                          # No clustering (simple random sample)
    data = rake_data,
    weights = starting_weights         # Start from base weights (or 1)
  )

  # Build calibration formula
  # Format: ~var1 + var2 + ...
  formula <- as.formula(paste("~", paste(names(target_list), collapse = " + ")))

  # CRITICAL FIX: Use actual sample size as base, not hard-coded 1000
  # This ensures sum of final weights = sum of starting weights
  base_n <- sum(starting_weights)

  # Build population vector using model.matrix to get correct structure
  # This avoids fragile string parsing
  mm <- model.matrix(formula, data = rake_data)

  # Initialize population vector with correct names
  population <- numeric(ncol(mm))
  names(population) <- colnames(mm)

  # Set intercept
  population["(Intercept)"] <- base_n

  # Fill in target totals for each variable level
  for (var in names(target_list)) {
    target_props <- target_list[[var]]
    target_levels <- names(target_props)

    for (level in target_levels) {
      # Find matching column in model matrix
      # survey uses make.names() so we need to match syntactic names
      col_name <- paste0(var, level)
      col_name_syntactic <- make.names(col_name)

      # Check both the raw name and syntactic name
      if (col_name %in% names(population)) {
        population[col_name] <- target_props[level] * base_n
      } else if (col_name_syntactic %in% names(population)) {
        population[col_name_syntactic] <- target_props[level] * base_n
      }
      # If neither found, it's likely the reference level (omitted from model matrix)
    }
  }

  # Calibrate using survey package
  calibrated <- tryCatch({
    survey::calibrate(
      design = svy_design,
      formula = formula,
      population = population,
      calfun = tolower(calibration_method),
      bounds = bounds,                    # Weight bounds DURING calibration
      maxit = max_iterations,
      epsilon = convergence_tolerance,
      force = FALSE,                      # Error if doesn't converge
      trim = NULL,                        # Don't trim (bounds handle it)
      bounds.const = FALSE
    )
  }, error = function(e) {
    # Provide helpful error message
    err_msg <- conditionMessage(e)

    # Check for common issues
    if (grepl("did not converge", err_msg, ignore.case = TRUE)) {
      stop(paste0(
        "\nRim weighting did not converge after ", max_iterations, " iterations.\n\n",
        "Options:\n",
        "  1. Increase max_iterations (currently ", max_iterations, ")\n",
        "  2. Relax weight bounds (currently [", bounds[1], ", ", bounds[2], "])\n",
        "  3. Try calibration_method = 'logit' (better for bounded weights)\n",
        "  4. Reduce number of rim variables (currently ", length(target_list), ")\n\n",
        "Original error: ", err_msg, "\n"
      ), call. = FALSE)
    } else if (grepl("bounds", err_msg, ignore.case = TRUE)) {
      stop(paste0(
        "\nWeight bounds issue during calibration.\n\n",
        "Try:\n",
        "  1. Widen bounds (currently [", bounds[1], ", ", bounds[2], "])\n",
        "  2. Use calibration_method = 'linear' or 'logit'\n",
        "  3. Check target proportions are realistic\n\n",
        "Original error: ", err_msg, "\n"
      ), call. = FALSE)
    } else {
      stop(paste0(
        "\nRim weighting calibration failed:\n  ", err_msg, "\n\n",
        "Troubleshooting:\n",
        "  1. Check all target categories exist in data\n",
        "  2. Ensure no missing values in weighting variables\n",
        "  3. Verify target proportions sum to 1.0 per variable\n"
      ), call. = FALSE)
    }
  })

  # Extract final weights
  final_weights <- weights(calibrated)

  # Calculate g-weights (calibration factors) if base weights were provided
  if (!is.null(base_weights)) {
    # Protect against division by zero or near-zero base weights
    if (any(starting_weights <= 0, na.rm = TRUE)) {
      stop("Base weights must be positive. Found zero or negative values.", call. = FALSE)
    }
    g_weights <- final_weights / starting_weights
  } else {
    g_weights <- final_weights  # If starting from 1, g = final
  }

  # Prepare full-length output vectors
  weights_full <- rep(NA_real_, nrow(data))
  g_weights_full <- rep(NA_real_, nrow(data))

  weights_full[complete_idx] <- final_weights
  g_weights_full[complete_idx] <- g_weights

  # Calculate achieved margins
  margins <- calculate_achieved_margins(rake_data, target_list, final_weights)

  # Build diagnostic info
  diagnostics <- list(
    n_total = nrow(data),
    n_used = nrow(rake_data),
    n_excluded = sum(!complete_idx),
    sum_weights = sum(final_weights),
    mean_weight = mean(final_weights),
    has_base_weights = !is.null(base_weights)
  )

  if (verbose) {
    message("  Calibration successful")
    message(sprintf("  Final weight range: [%.3f, %.3f]",
                   min(weights_full, na.rm = TRUE),
                   max(weights_full, na.rm = TRUE)))
    message(sprintf("  Mean weight: %.3f (sum: %.1f)",
                   diagnostics$mean_weight, diagnostics$sum_weights))
    if (!is.null(base_weights)) {
      message(sprintf("  G-weight range: [%.3f, %.3f]",
                     min(g_weights_full, na.rm = TRUE),
                     max(g_weights_full, na.rm = TRUE)))
    }
  }

  return(list(
    weights = weights_full,
    g_weights = g_weights_full,         # Calibration factors (final/base)
    converged = TRUE,                   # TRUE if we got here (calibrate errors otherwise)
    iterations = NA_integer_,           # survey doesn't expose this
    margins = margins,
    design = calibrated,                # Full survey design object
    method = calibration_method,
    bounds = bounds,
    diagnostics = diagnostics
  ))
}

#' Calculate Rim Weights from Config
#'
#' Wrapper function that uses configuration objects to calculate rim weights.
#' Supports optional base weights for combined weighting.
#'
#' @param data Data frame, survey data
#' @param config List, full configuration object
#' @param weight_name Character, name of the weight to calculate
#' @param base_weight_column Character, name of column containing base weights (default: NULL)
#' @param verbose Logical, print progress messages
#' @return List with $weights, $converged, $iterations, $margins, $validation
#' @export
calculate_rim_weights_from_config <- function(data, config, weight_name,
                                              base_weight_column = NULL,
                                              verbose = FALSE) {

  # Get rim targets for this weight
  targets_df <- get_rim_targets(config, weight_name)

  if (is.null(targets_df) || nrow(targets_df) == 0) {
    stop(sprintf(
      "No rim targets found for weight '%s'",
      weight_name
    ), call. = FALSE)
  }

  # Validate configuration against data
  validation <- validate_rim_config(data, targets_df, weight_name)

  if (!validation$valid) {
    stop(sprintf(
      "\nRim weight configuration validation failed for '%s':\n  %s",
      weight_name,
      paste(validation$errors, collapse = "\n  ")
    ), call. = FALSE)
  }

  if (length(validation$warnings) > 0) {
    for (w in validation$warnings) {
      warning(w, call. = FALSE)
    }
  }

  # Build target list from config
  # Format: list(Variable = c(Category1 = 0.30, Category2 = 0.70, ...))
  target_list <- list()
  rim_variables <- unique(targets_df$variable)

  for (var in rim_variables) {
    var_targets <- targets_df[targets_df$variable == var, , drop = FALSE]
    target_list[[var]] <- setNames(
      as.numeric(var_targets$target_percent) / 100,  # Convert to proportions
      as.character(var_targets$category)
    )
  }

  # Get base weights if specified
  base_weights <- NULL
  if (!is.null(base_weight_column)) {
    if (!base_weight_column %in% names(data)) {
      stop(sprintf(
        "base_weight_column '%s' not found in data",
        base_weight_column
      ), call. = FALSE)
    }
    base_weights <- data[[base_weight_column]]
  }

  # Get advanced settings
  max_iter <- as.numeric(get_advanced_setting(config, weight_name, "max_iterations", 50))
  conv_tol <- as.numeric(get_advanced_setting(config, weight_name, "convergence_tolerance", 1e-7))

  # Get calibration method (new in v2.0)
  calib_method <- get_advanced_setting(config, weight_name, "calibration_method", "raking")

  # Get weight bounds (new in v2.0)
  # Can be single value or comma-separated "lower,upper"
  bounds_setting <- get_advanced_setting(config, weight_name, "weight_bounds", "0.3,3.0")
  if (is.character(bounds_setting) && grepl(",", bounds_setting)) {
    parts <- strsplit(bounds_setting, ",")[[1]]
    if (length(parts) != 2) {
      stop(sprintf(
        "Invalid weight_bounds format: '%s'. Expected 'lower,upper' (e.g., '0.3,3.0') or single value.",
        bounds_setting
      ), call. = FALSE)
    }
    bounds <- as.numeric(parts)
    if (any(is.na(bounds))) {
      stop(sprintf(
        "Invalid weight_bounds values: '%s'. Both lower and upper must be numeric.",
        bounds_setting
      ), call. = FALSE)
    }
  } else {
    bounds <- c(0.3, as.numeric(bounds_setting))  # Interpret as upper bound only
  }

  # Calculate weights
  result <- calculate_rim_weights(
    data = data,
    target_list = target_list,
    base_weights = base_weights,
    caseid = NULL,                      # Deprecated
    max_iterations = max_iter,
    convergence_tolerance = conv_tol,
    cap_weights = bounds,
    calibration_method = calib_method,
    verbose = verbose
  )

  # Validate calculated weights
  result$validation <- validate_calculated_weights(result$weights, weight_name)
  result$rim_variables <- rim_variables
  result$target_list <- target_list

  return(result)
}

#' Calculate Achieved Margins
#'
#' Computes weighted margins and compares to targets.
#'
#' @param data Data frame with rim variables
#' @param target_list Named list of target proportions
#' @param weights Numeric vector of weights
#' @return Data frame with achieved vs target margins
#' @keywords internal
calculate_achieved_margins <- function(data, target_list, weights) {

  margins_list <- list()

  for (var in names(target_list)) {
    target_props <- target_list[[var]]

    for (cat in names(target_props)) {
      # Calculate weighted proportion
      in_cat <- data[[var]] == cat
      in_cat[is.na(in_cat)] <- FALSE

      achieved_pct <- sum(weights[in_cat]) / sum(weights) * 100
      target_pct <- target_props[cat] * 100

      margins_list[[length(margins_list) + 1]] <- data.frame(
        variable = var,
        category = cat,
        target_pct = target_pct,
        achieved_pct = achieved_pct,
        diff_pct = achieved_pct - target_pct,
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, margins_list)
}

#' Print Rim Weighting Summary
#'
#' Displays a formatted summary of rim weighting results.
#'
#' @param result List returned from calculate_rim_weights
#' @param weight_name Character, name of the weight
#' @export
print_rim_summary <- function(result, weight_name = "rim_weight") {

  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("RIM WEIGHTING SUMMARY:", weight_name, "\n")
  cat(strrep("=", 70), "\n\n")

  cat("Method: Rim Weighting via survey::calibrate()\n")
  cat("Calibration Method:", result$method, "\n")
  cat("Convergence:", if(result$converged) "✓ Converged" else "✗ Did not converge", "\n")
  cat("Weight Bounds: [", result$bounds[1], ", ", result$bounds[2], "]\n", sep = "")
  if (result$diagnostics$has_base_weights) {
    cat("Base Weights: Yes (rim-on-design mode)\n")
  }
  cat("\n")

  valid_weights <- result$weights[!is.na(result$weights)]
  cat("WEIGHT STATISTICS:\n")
  cat(sprintf("  Total rows:       %d\n", result$diagnostics$n_total))
  cat(sprintf("  Used in cal:      %d\n", result$diagnostics$n_used))
  cat(sprintf("  Excluded (NA):    %d\n", result$diagnostics$n_excluded))
  cat(sprintf("  Sum of weights:   %.1f\n", result$diagnostics$sum_weights))
  cat(sprintf("  Mean weight:      %.3f\n", result$diagnostics$mean_weight))
  cat(sprintf("  Min weight:       %.3f\n", min(valid_weights)))
  cat(sprintf("  Max weight:       %.3f\n", max(valid_weights)))
  cat(sprintf("  Median weight:    %.3f\n", median(valid_weights)))
  cat("\n")

  if (result$diagnostics$has_base_weights) {
    valid_g <- result$g_weights[!is.na(result$g_weights)]
    cat("G-WEIGHT STATISTICS (calibration factors):\n")
    cat(sprintf("  Mean g-weight:    %.3f\n", mean(valid_g)))
    cat(sprintf("  Min g-weight:     %.3f\n", min(valid_g)))
    cat(sprintf("  Max g-weight:     %.3f\n", max(valid_g)))
    cat("\n")
  }

  if (!is.null(result$margins)) {
    cat("ACHIEVED MARGINS:\n\n")
    print(result$margins, row.names = FALSE)
    cat("\n")
  }

  cat(strrep("=", 70), "\n")
}
