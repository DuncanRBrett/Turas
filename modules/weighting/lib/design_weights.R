# ==============================================================================
# WEIGHTING MODULE - DESIGN WEIGHT CALCULATION
# ==============================================================================
# Calculate design weights for stratified samples
# Part of TURAS Weighting Module v1.0
#
# METHODOLOGY:
# Design weights adjust for unequal selection probabilities in stratified samples.
# For each stratum: weight = population_size / sample_size
#
# USE CASES:
# - Customer lists with known segment sizes
# - Employee surveys with departmental stratification
# - Stratified random samples with known population counts
# ==============================================================================

#' Calculate Design Weights
#'
#' Calculates design weights for a stratified sample based on population sizes.
#'
#' @param data Data frame, survey data
#' @param stratum_variable Character, column name for stratification variable
#' @param population_sizes Named vector, stratum category -> population count
#' @param verbose Logical, print progress messages (default: FALSE)
#' @return Numeric vector of weights (length = nrow(data))
#' @export
#'
#' @examples
#' pop_sizes <- c("Small" = 2000, "Medium" = 500, "Large" = 100)
#' weights <- calculate_design_weights(data, "customer_size", pop_sizes)
calculate_design_weights <- function(data,
                                     stratum_variable,
                                     population_sizes,
                                     verbose = FALSE) {

  # Validate inputs
  if (!is.data.frame(data) || nrow(data) == 0) {
    stop("data must be a non-empty data frame", call. = FALSE)
  }

  if (!stratum_variable %in% names(data)) {
    stop(sprintf(
      "Stratum variable '%s' not found in data.\nAvailable columns: %s",
      stratum_variable,
      paste(head(names(data), 15), collapse = ", ")
    ), call. = FALSE)
  }

  if (!is.numeric(population_sizes) || is.null(names(population_sizes))) {
    stop("population_sizes must be a named numeric vector", call. = FALSE)
  }

  if (verbose) {
    message("\nCalculating design weights...")
    message("  Stratum variable: ", stratum_variable)
    message("  Number of strata: ", length(population_sizes))
  }

  # Get stratum values from data
  stratum_values <- as.character(data[[stratum_variable]])

  # Initialize weight vector
  weights <- rep(NA_real_, nrow(data))

  # Track issues
  unmatched_categories <- character(0)
  zero_sample_strata <- character(0)

  # Calculate weights for each stratum
  for (stratum_cat in names(population_sizes)) {
    pop_size <- population_sizes[stratum_cat]

    # Find rows in this stratum
    in_stratum <- stratum_values == stratum_cat & !is.na(stratum_values)
    sample_size <- sum(in_stratum)

    if (sample_size == 0) {
      zero_sample_strata <- c(zero_sample_strata, stratum_cat)
      next
    }

    # Calculate weight: population / sample
    weight <- pop_size / sample_size

    if (verbose) {
      message(sprintf(
        "    %s: pop=%d, sample=%d, weight=%.4f",
        stratum_cat, pop_size, sample_size, weight
      ))
    }

    weights[in_stratum] <- weight
  }

  # Check for unmatched rows (categories in data not in population_sizes)
  unmatched <- is.na(weights) & !is.na(stratum_values)
  n_unmatched <- sum(unmatched)

  if (n_unmatched > 0) {
    unmatched_cats <- unique(stratum_values[unmatched])
    warning(sprintf(
      "%d rows (%d%%) have categories not in population_sizes: %s\nThese rows will have NA weights.",
      n_unmatched,
      round(100 * n_unmatched / nrow(data)),
      paste(unmatched_cats, collapse = ", ")
    ), call. = FALSE)
  }

  # Report zero sample strata
  if (length(zero_sample_strata) > 0) {
    warning(sprintf(
      "Strata with population targets but no sample observations: %s",
      paste(zero_sample_strata, collapse = ", ")
    ), call. = FALSE)
  }

  # Report NA stratum values
  n_na_stratum <- sum(is.na(stratum_values))
  if (n_na_stratum > 0) {
    warning(sprintf(
      "%d rows have NA stratum values. These will have NA weights.",
      n_na_stratum
    ), call. = FALSE)
  }

  if (verbose) {
    n_valid <- sum(!is.na(weights) & weights > 0)
    message("  Weights assigned: ", n_valid, " of ", nrow(data), " rows")
  }

  return(weights)
}

#' Calculate Design Weights from Config
#'
#' Wrapper function that uses configuration objects to calculate design weights.
#'
#' @param data Data frame, survey data
#' @param config List, full configuration object
#' @param weight_name Character, name of the weight to calculate
#' @param verbose Logical, print progress messages
#' @return List with $weights, $validation, $stratum_summary
#' @export
calculate_design_weights_from_config <- function(data, config, weight_name, verbose = FALSE) {

  # Get design targets for this weight
  targets <- get_design_targets(config, weight_name)

  if (is.null(targets) || nrow(targets) == 0) {
    stop(sprintf(
      "No design targets found for weight '%s'",
      weight_name
    ), call. = FALSE)
  }

  # Validate configuration against data
  validation <- validate_design_config(data, targets, weight_name)

  if (!validation$valid) {
    stop(sprintf(
      "\nDesign weight configuration validation failed for '%s':\n  %s",
      weight_name,
      paste(validation$errors, collapse = "\n  ")
    ), call. = FALSE)
  }

  if (length(validation$warnings) > 0) {
    for (w in validation$warnings) {
      warning(w, call. = FALSE)
    }
  }

  # Get stratum variable (should be unique per weight)
  stratum_variable <- unique(targets$stratum_variable)[1]

  # Build population sizes named vector
  population_sizes <- setNames(
    as.numeric(targets$population_size),
    as.character(targets$stratum_category)
  )

  # Calculate weights
  weights <- calculate_design_weights(
    data = data,
    stratum_variable = stratum_variable,
    population_sizes = population_sizes,
    verbose = verbose
  )

  # Build stratum summary
  stratum_values <- as.character(data[[stratum_variable]])
  stratum_summary <- data.frame(
    stratum = character(0),
    population_size = numeric(0),
    sample_size = numeric(0),
    weight = numeric(0),
    stringsAsFactors = FALSE
  )

  for (cat in names(population_sizes)) {
    sample_n <- sum(stratum_values == cat, na.rm = TRUE)
    wt <- if (sample_n > 0) population_sizes[cat] / sample_n else NA_real_

    stratum_summary <- rbind(stratum_summary, data.frame(
      stratum = cat,
      population_size = population_sizes[cat],
      sample_size = sample_n,
      weight = wt,
      stringsAsFactors = FALSE
    ))
  }

  # Validate calculated weights
  weight_validation <- validate_calculated_weights(weights, weight_name)

  return(list(
    weights = weights,
    validation = weight_validation,
    stratum_summary = stratum_summary,
    stratum_variable = stratum_variable
  ))
}

#' Print Design Weight Summary
#'
#' Prints a formatted summary of design weight calculation.
#'
#' @param result List, result from calculate_design_weights_from_config
#' @param weight_name Character, name of the weight
#' @export
print_design_summary <- function(result, weight_name) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("DESIGN WEIGHT SUMMARY: ", weight_name, "\n")
  cat(strrep("=", 70), "\n")
  cat("\nMethod: Design Weights (Stratified Sample)\n")
  cat("Stratum Variable: ", result$stratum_variable, "\n")
  cat("\nStratum Details:\n")
  cat(strrep("-", 60), "\n")
  cat(sprintf("%-20s %12s %12s %12s\n",
              "Stratum", "Population", "Sample", "Weight"))
  cat(strrep("-", 60), "\n")

  for (i in seq_len(nrow(result$stratum_summary))) {
    row <- result$stratum_summary[i, ]
    cat(sprintf("%-20s %12s %12d %12.4f\n",
                row$stratum,
                format(row$population_size, big.mark = ","),
                row$sample_size,
                row$weight))
  }

  cat(strrep("-", 60), "\n")

  # Total
  total_pop <- sum(result$stratum_summary$population_size)
  total_sample <- sum(result$stratum_summary$sample_size)
  cat(sprintf("%-20s %12s %12d\n",
              "TOTAL",
              format(total_pop, big.mark = ","),
              total_sample))

  cat("\n")
}

#' Normalize Design Weights
#'
#' Normalize design weights to sum to sample size (mean = 1).
#' This is useful when you want relative weights rather than absolute.
#'
#' @param weights Numeric vector of design weights
#' @param target_sum Numeric, desired sum of weights (default: NULL = n valid weights)
#' @return Numeric vector of normalized weights
#' @export
normalize_design_weights <- function(weights, target_sum = NULL) {
  valid_idx <- !is.na(weights) & is.finite(weights) & weights > 0
  n_valid <- sum(valid_idx)

  if (n_valid == 0) {
    warning("No valid weights to normalize", call. = FALSE)
    return(weights)
  }

  if (is.null(target_sum)) {
    target_sum <- n_valid
  }

  current_sum <- sum(weights[valid_idx])

  if (current_sum == 0) {
    warning("Sum of weights is zero, cannot normalize", call. = FALSE)
    return(weights)
  }

  # Scale factor to achieve target sum
  scale_factor <- target_sum / current_sum

  # Apply to valid weights only
  normalized <- weights
  normalized[valid_idx] <- weights[valid_idx] * scale_factor

  return(normalized)
}

#' Calculate Grossing Weights
#'
#' Creates weights that gross up the sample to population totals.
#' Unlike normalized weights, these represent actual population counts.
#'
#' @param weights Numeric vector of design weights
#' @param population_total Numeric, total population size
#' @return Numeric vector of grossing weights
#' @export
calculate_grossing_weights <- function(weights, population_total) {
  if (!is.numeric(population_total) || population_total <= 0) {
    stop("population_total must be a positive number", call. = FALSE)
  }

  valid_idx <- !is.na(weights) & is.finite(weights) & weights > 0
  n_valid <- sum(valid_idx)

  if (n_valid == 0) {
    warning("No valid weights to convert to grossing weights", call. = FALSE)
    return(weights)
  }

  # Design weights already represent population proportions
  # Grossing weight = design_weight * (population_total / sum_of_design_weights)

  sum_weights <- sum(weights[valid_idx])
  scale_factor <- population_total / sum_weights

  grossing <- weights
  grossing[valid_idx] <- weights[valid_idx] * scale_factor

  return(grossing)
}
