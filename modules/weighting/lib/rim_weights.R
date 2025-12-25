# ==============================================================================
# WEIGHTING MODULE - RIM WEIGHT CALCULATION
# ==============================================================================
# Calculate rim weights using iterative proportional fitting (raking)
# Part of TURAS Weighting Module v1.0
#
# METHODOLOGY:
# Rim weighting (also called raking or iterative proportional fitting)
# adjusts sample weights to match multiple target marginal distributions
# simultaneously. Uses the anesrake package for calculation.
#
# USE CASES:
# - Online panel samples requiring demographic adjustment
# - Quota samples needing rebalancing to population targets
# - General population surveys with known demographics
# ==============================================================================

#' Check anesrake Package Availability
#'
#' Checks if anesrake is installed and provides installation instructions if not.
#'
#' @return Invisible TRUE if available, stops with error if not
#' @keywords internal
check_anesrake_available <- function() {
  if (!requireNamespace("anesrake", quietly = TRUE)) {
    stop(paste0(
      "\n",
      strrep("=", 70), "\n",
      "PACKAGE REQUIRED: anesrake\n",
      strrep("=", 70), "\n\n",
      "The 'anesrake' package is required for rim weighting but is not installed.\n\n",
      "To install, run:\n",
      "  install.packages('anesrake')\n\n",
      "This package provides iterative proportional fitting (raking) algorithms\n",
      "for survey weight calculation.\n"
    ), call. = FALSE)
  }
  invisible(TRUE)
}

#' Calculate Rim Weights
#'
#' Calculates rim weights using anesrake's iterative proportional fitting.
#'
#' @param data Data frame, survey data
#' @param target_list Named list, variable -> named vector of target proportions (0-1 scale)
#' @param caseid Character, name of ID column (default: NULL = row numbers)
#' @param max_iterations Integer, maximum raking iterations (default: 25)
#' @param convergence_tolerance Numeric, convergence criterion as proportion (default: 0.01)
#' @param force_convergence Logical, return weights even if not converged (default: FALSE)
#' @param cap_weights Numeric, maximum weight during raking (default: NULL = no cap)
#' @param verbose Logical, print progress messages (default: FALSE)
#' @return List with $weights, $converged, $iterations, $margins
#' @export
#'
#' @examples
#' targets <- list(
#'   Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
#'   Gender = c("Male" = 0.48, "Female" = 0.52)
#' )
#' result <- calculate_rim_weights(data, targets)
calculate_rim_weights <- function(data,
                                  target_list,
                                  caseid = NULL,
                                  max_iterations = 25,
                                  convergence_tolerance = 0.01,
                                  force_convergence = FALSE,
                                  cap_weights = NULL,
                                  verbose = FALSE) {

  # Check package availability
  check_anesrake_available()

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

  if (verbose) {
    message("\nCalculating rim weights...")
    message("  Variables: ", paste(names(target_list), collapse = ", "))
    message("  Max iterations: ", max_iterations)
    message("  Convergence tolerance: ", convergence_tolerance * 100, "%")
  }

  # Prepare data for anesrake
  # anesrake requires factors with levels matching target names
  rake_data <- data

  for (var in names(target_list)) {
    # Convert to character, then to factor with target levels
    rake_data[[var]] <- as.character(rake_data[[var]])
    target_levels <- names(target_list[[var]])
    rake_data[[var]] <- factor(rake_data[[var]], levels = target_levels)

    # Check for unmatched levels
    n_na <- sum(is.na(rake_data[[var]]))
    if (n_na > 0) {
      warning(sprintf(
        "Variable '%s': %d values not in target categories (will be NA)",
        var, n_na
      ), call. = FALSE)
    }
  }

  # Create case ID if not provided
  if (is.null(caseid)) {
    rake_data$.case_id <- seq_len(nrow(rake_data))
    caseid_col <- ".case_id"
  } else {
    if (!caseid %in% names(rake_data)) {
      stop(sprintf("caseid column '%s' not found in data", caseid), call. = FALSE)
    }
    caseid_col <- caseid
  }

  # Prepare targets for anesrake (expects proportions summing to 1)
  anesrake_targets <- target_list

  # Set up anesrake call

  rake_result <- tryCatch({
    # Build arguments list (omit cap if NULL)
    anes_args <- list(
      inputter = anesrake_targets,
      dataframe = rake_data,
      caseid = rake_data[[caseid_col]],
      choosemethod = "total",
      type = "pctlim",
      pctlim = convergence_tolerance,
      maxit = max_iterations,
      force1 = TRUE,  # Force weights to average 1
      verbose = verbose
    )

    # Add cap only if not NULL
    if (!is.null(cap_weights)) {
      anes_args$cap <- cap_weights
    }

    do.call(anesrake::anesrake, anes_args)
  }, error = function(e) {
    stop(sprintf(
      "\nRim weighting calculation failed:\n  %s\n\nTroubleshooting:\n  1. Check all target categories exist in data\n  2. Ensure no missing values in weighting variables\n  3. Try reducing number of variables or relaxing tolerance",
      conditionMessage(e)
    ), call. = FALSE)
  })

  # Extract weights
  weights <- rake_result$weightvec

  # Check convergence
  # Note: rake_result$converge is a character string, not logical
  # "Complete convergence was achieved" = converged
  # Other values indicate non-convergence
  converge_text <- rake_result$converge
  converged <- grepl("Complete convergence", converge_text, ignore.case = TRUE)
  iterations <- rake_result$iterations

  if (!converged && !force_convergence) {
    stop(sprintf(
      "\nRim weighting did not converge after %d iterations.\n\nOptions:\n  1. Increase max_iterations (currently %d)\n  2. Relax convergence_tolerance (currently %.1f%%)\n  3. Reduce number of rim variables (currently %d)\n  4. Set force_convergence = TRUE in Advanced_Settings",
      iterations, max_iterations, convergence_tolerance * 100, length(target_list)
    ), call. = FALSE)
  }

  if (!converged && force_convergence) {
    warning(sprintf(
      "Rim weighting did not converge after %d iterations. Weights returned but may not match targets exactly.",
      iterations
    ), call. = FALSE)
  }

  if (verbose) {
    if (converged) {
      message("  Converged in ", iterations, " iterations")
    } else {
      message("  Did NOT converge (", iterations, " iterations)")
    }
  }

  # Calculate achieved margins
  margins <- calculate_achieved_margins(rake_data, target_list, weights)

  return(list(
    weights = weights,
    converged = converged,
    iterations = iterations,
    margins = margins
  ))
}

#' Calculate Rim Weights from Config
#'
#' Wrapper function that uses configuration objects to calculate rim weights.
#'
#' @param data Data frame, survey data
#' @param config List, full configuration object
#' @param weight_name Character, name of the weight to calculate
#' @param verbose Logical, print progress messages
#' @return List with $weights, $converged, $iterations, $margins, $validation
#' @export
calculate_rim_weights_from_config <- function(data, config, weight_name, verbose = FALSE) {

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

  # Get advanced settings
  max_iter <- as.numeric(get_advanced_setting(config, weight_name, "max_iterations", 25))
  conv_tol <- as.numeric(get_advanced_setting(config, weight_name, "convergence_tolerance", 0.01))
  force_conv <- toupper(get_advanced_setting(config, weight_name, "force_convergence", "N")) == "Y"

  # Get cap from weight specification (if apply_trimming during calculation)
  spec <- get_weight_spec(config, weight_name)
  cap_weights <- NULL
  # Note: We don't apply cap during anesrake by default, we trim after
  # This gives cleaner separation of concerns

  # Calculate weights
  result <- calculate_rim_weights(
    data = data,
    target_list = target_list,
    caseid = NULL,
    max_iterations = max_iter,
    convergence_tolerance = conv_tol,
    force_convergence = force_conv,
    cap_weights = cap_weights,
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
#' Compares target vs achieved marginal distributions.
#'
#' @param data Data frame with factor variables
#' @param target_list Named list of target proportions
#' @param weights Numeric vector of weights
#' @return Data frame with comparison
#' @keywords internal
calculate_achieved_margins <- function(data, target_list, weights) {
  results <- data.frame(
    variable = character(0),
    category = character(0),
    target_pct = numeric(0),
    achieved_pct = numeric(0),
    diff_pct = numeric(0),
    stringsAsFactors = FALSE
  )

  for (var in names(target_list)) {
    targets <- target_list[[var]]

    for (cat in names(targets)) {
      target_pct <- targets[cat] * 100

      # Calculate weighted percentage
      in_cat <- data[[var]] == cat & !is.na(data[[var]])
      achieved_pct <- 100 * sum(weights[in_cat]) / sum(weights[!is.na(data[[var]])])

      results <- rbind(results, data.frame(
        variable = var,
        category = cat,
        target_pct = target_pct,
        achieved_pct = achieved_pct,
        diff_pct = achieved_pct - target_pct,
        stringsAsFactors = FALSE
      ))
    }
  }

  return(results)
}

#' Print Rim Weight Summary
#'
#' Prints a formatted summary of rim weight calculation.
#'
#' @param result List, result from calculate_rim_weights_from_config
#' @param weight_name Character, name of the weight
#' @export
print_rim_summary <- function(result, weight_name) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("RIM WEIGHT SUMMARY: ", weight_name, "\n")
  cat(strrep("=", 70), "\n")
  cat("\nMethod: Rim Weighting (Iterative Proportional Fitting)\n")

  if (result$converged) {
    cat("Convergence: CONVERGED in ", result$iterations, " iterations\n")
  } else {
    cat("Convergence: NOT CONVERGED after ", result$iterations, " iterations\n")
  }

  cat("Variables: ", paste(result$rim_variables, collapse = ", "), "\n")

  cat("\nTarget Achievement:\n")
  cat(strrep("-", 65), "\n")
  cat(sprintf("%-15s %-15s %10s %10s %10s\n",
              "Variable", "Category", "Target%", "Achieved%", "Diff%"))
  cat(strrep("-", 65), "\n")

  for (i in seq_len(nrow(result$margins))) {
    row <- result$margins[i, ]
    diff_str <- sprintf("%+.1f", row$diff_pct)
    cat(sprintf("%-15s %-15s %10.1f %10.1f %10s\n",
                row$variable,
                row$category,
                row$target_pct,
                row$achieved_pct,
                diff_str))
  }

  cat(strrep("-", 65), "\n")
  cat("\n")
}

#' Prepare Rim Variables
#'
#' Prepares data frame variables for rim weighting by converting to factors
#' with appropriate levels.
#'
#' @param data Data frame, survey data
#' @param target_list Named list of target proportions
#' @return Data frame with converted variables
#' @keywords internal
prepare_rim_variables <- function(data, target_list) {
  for (var in names(target_list)) {
    if (!var %in% names(data)) {
      stop(sprintf("Variable '%s' not found in data", var), call. = FALSE)
    }

    target_levels <- names(target_list[[var]])

    # Convert to character first, then to factor
    data[[var]] <- as.character(data[[var]])

    # Check for values not in targets
    unique_vals <- unique(data[[var]])
    unique_vals <- unique_vals[!is.na(unique_vals)]
    missing_in_targets <- setdiff(unique_vals, target_levels)

    if (length(missing_in_targets) > 0) {
      warning(sprintf(
        "Variable '%s' has values not in targets: %s\nThese will be treated as NA.",
        var, paste(missing_in_targets, collapse = ", ")
      ), call. = FALSE)
    }

    data[[var]] <- factor(data[[var]], levels = target_levels)
  }

  return(data)
}
