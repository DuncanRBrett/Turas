# ==============================================================================
# WEIGHTING MODULE - VALIDATION FUNCTIONS
# ==============================================================================
# Input validation for weighting configuration and data
# Part of TURAS Weighting Module v1.0
# ==============================================================================

#' Validate Design Weight Configuration
#'
#' Validates that all design targets are correctly specified and match the data.
#'
#' @param data Data frame, survey data
#' @param design_targets Data frame, design target specifications
#' @param weight_name Character, name of the weight being validated
#' @return List with $valid (logical), $errors (character vector)
#' @export
validate_design_config <- function(data, design_targets, weight_name) {
  errors <- character(0)
  warnings <- character(0)

  # Filter targets for this weight
  targets <- design_targets[design_targets$weight_name == weight_name, , drop = FALSE]

  if (nrow(targets) == 0) {
    errors <- c(errors, sprintf(
      "No design targets found for weight '%s' in Design_Targets sheet",
      weight_name
    ))
    return(list(valid = FALSE, errors = errors, warnings = warnings))
  }

  # Check stratum variable exists
  stratum_var <- unique(targets$stratum_variable)
  if (length(stratum_var) > 1) {
    errors <- c(errors, sprintf(
      "Weight '%s' has multiple stratum variables: %s. Only one allowed per weight.",
      weight_name, paste(stratum_var, collapse = ", ")
    ))
  }
  stratum_var <- stratum_var[1]

  if (!stratum_var %in% names(data)) {
    errors <- c(errors, sprintf(
      "Stratum variable '%s' not found in data.\nAvailable columns: %s",
      stratum_var, paste(head(names(data), 15), collapse = ", ")
    ))
    return(list(valid = FALSE, errors = errors, warnings = warnings))
  }

  # Check no missing values in stratum variable
  n_missing <- sum(is.na(data[[stratum_var]]))
  if (n_missing > 0) {
    errors <- c(errors, sprintf(
      "Stratum variable '%s' has %d missing values (%.1f%%). Cannot calculate design weights with missing stratification data.",
      stratum_var, n_missing, 100 * n_missing / nrow(data)
    ))
  }

  # Check all categories exist in data
  data_categories <- unique(as.character(data[[stratum_var]]))
  data_categories <- data_categories[!is.na(data_categories)]
  target_categories <- as.character(targets$stratum_category)

  missing_in_data <- setdiff(target_categories, data_categories)
  if (length(missing_in_data) > 0) {
    errors <- c(errors, sprintf(
      "Categories specified in Design_Targets not found in data: %s\nCategories in data: %s",
      paste(missing_in_data, collapse = ", "),
      paste(data_categories, collapse = ", ")
    ))
  }

  missing_in_targets <- setdiff(data_categories, target_categories)
  if (length(missing_in_targets) > 0) {
    errors <- c(errors, sprintf(
      "Categories in data not specified in Design_Targets: %s\nThese cases will have no weight assigned.",
      paste(missing_in_targets, collapse = ", ")
    ))
  }

  # Check population sizes are positive
  if (any(targets$population_size <= 0, na.rm = TRUE)) {
    bad_strata <- targets$stratum_category[targets$population_size <= 0]
    errors <- c(errors, sprintf(
      "Population size must be positive. Zero or negative values for: %s",
      paste(bad_strata, collapse = ", ")
    ))
  }

  # Check for duplicate categories
  if (any(duplicated(targets$stratum_category))) {
    dups <- unique(targets$stratum_category[duplicated(targets$stratum_category)])
    errors <- c(errors, sprintf(
      "Duplicate stratum categories in Design_Targets: %s",
      paste(dups, collapse = ", ")
    ))
  }

  # Check sample sizes > 0 for each stratum
  for (i in seq_len(nrow(targets))) {
    cat_val <- targets$stratum_category[i]
    sample_n <- sum(data[[stratum_var]] == cat_val, na.rm = TRUE)
    if (sample_n == 0) {
      errors <- c(errors, sprintf(
        "Stratum '%s' has 0 observations in data. Cannot calculate weight.",
        cat_val
      ))
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings
  ))
}

#' Validate Rim Weight Configuration
#'
#' Validates that all rim targets are correctly specified and match the data.
#'
#' @param data Data frame, survey data
#' @param rim_targets Data frame, rim target specifications
#' @param weight_name Character, name of the weight being validated
#' @return List with $valid (logical), $errors (character vector), $warnings (character vector)
#' @export
validate_rim_config <- function(data, rim_targets, weight_name) {
  errors <- character(0)
  warnings <- character(0)

  # Filter targets for this weight
  targets <- rim_targets[rim_targets$weight_name == weight_name, , drop = FALSE]

  if (nrow(targets) == 0) {
    errors <- c(errors, sprintf(
      "No rim targets found for weight '%s' in Rim_Targets sheet",
      weight_name
    ))
    return(list(valid = FALSE, errors = errors, warnings = warnings))
  }

  # Get unique variables
  rim_variables <- unique(targets$variable)

  # Warn if too many variables
  if (length(rim_variables) > 5) {
    warnings <- c(warnings, sprintf(
      "Weight '%s' has %d rim variables. More than 5 may cause convergence issues.",
      weight_name, length(rim_variables)
    ))
  }

  # Check each variable
  for (var in rim_variables) {
    var_targets <- targets[targets$variable == var, , drop = FALSE]

    # Check variable exists in data
    if (!var %in% names(data)) {
      errors <- c(errors, sprintf(
        "Rim variable '%s' not found in data.\nAvailable columns: %s",
        var, paste(head(names(data), 15), collapse = ", ")
      ))
      next
    }

    # Check no missing values
    n_missing <- sum(is.na(data[[var]]))
    if (n_missing > 0) {
      errors <- c(errors, sprintf(
        "Rim variable '%s' has %d missing values (%.1f%%). Rim weighting requires complete data for weighting variables.",
        var, n_missing, 100 * n_missing / nrow(data)
      ))
    }

    # Check all categories exist in data
    data_categories <- unique(as.character(data[[var]]))
    data_categories <- data_categories[!is.na(data_categories)]
    target_categories <- as.character(var_targets$category)

    missing_in_data <- setdiff(target_categories, data_categories)
    if (length(missing_in_data) > 0) {
      errors <- c(errors, sprintf(
        "Categories for '%s' in Rim_Targets not found in data: %s\nCategories in data: %s",
        var, paste(missing_in_data, collapse = ", "),
        paste(data_categories, collapse = ", ")
      ))
    }

    missing_in_targets <- setdiff(data_categories, target_categories)
    if (length(missing_in_targets) > 0) {
      errors <- c(errors, sprintf(
        "Categories in data for '%s' not in Rim_Targets: %s\nAll categories must have targets.",
        var, paste(missing_in_targets, collapse = ", ")
      ))
    }

    # Check targets sum to 100
    target_sum <- sum(var_targets$target_percent, na.rm = TRUE)
    if (abs(target_sum - 100) > 0.1) {
      errors <- c(errors, sprintf(
        "Targets for variable '%s' sum to %.2f%%, must sum to 100%%",
        var, target_sum
      ))
    }

    # Check for duplicate categories
    if (any(duplicated(var_targets$category))) {
      dups <- unique(var_targets$category[duplicated(var_targets$category)])
      errors <- c(errors, sprintf(
        "Duplicate categories for variable '%s': %s",
        var, paste(dups, collapse = ", ")
      ))
    }

    # Check target percentages are valid
    if (any(var_targets$target_percent < 0, na.rm = TRUE)) {
      errors <- c(errors, sprintf(
        "Negative target percentages found for variable '%s'",
        var
      ))
    }
    if (any(var_targets$target_percent > 100, na.rm = TRUE)) {
      errors <- c(errors, sprintf(
        "Target percentages > 100 found for variable '%s'",
        var
      ))
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings
  ))
}

#' Validate Calculated Weights
#'
#' Post-calculation validation of weight vector quality.
#'
#' @param weights Numeric vector of calculated weights
#' @param label Character, label for reporting
#' @return List with validation results and quality metrics
#' @export
validate_calculated_weights <- function(weights, label = "Weights") {
  results <- list(
    valid = TRUE,
    n_total = length(weights),
    n_valid = sum(!is.na(weights) & is.finite(weights) & weights > 0),
    n_na = sum(is.na(weights)),
    n_zero = sum(!is.na(weights) & weights == 0),
    n_negative = sum(!is.na(weights) & weights < 0),
    n_infinite = sum(!is.na(weights) & is.infinite(weights)),
    errors = character(0),
    warnings = character(0)
  )

  # Fatal issues
  if (results$n_negative > 0) {
    results$valid <- FALSE
    results$errors <- c(results$errors, sprintf(
      "%s: %d negative weights detected. This indicates a calculation error.",
      label, results$n_negative
    ))
  }

  if (results$n_infinite > 0) {
    results$valid <- FALSE
    results$errors <- c(results$errors, sprintf(
      "%s: %d infinite weights detected. Check for division by zero.",
      label, results$n_infinite
    ))
  }

  if (results$n_valid == 0) {
    results$valid <- FALSE
    results$errors <- c(results$errors, sprintf(
      "%s: No valid weights calculated.",
      label
    ))
  }

  # Warnings
  if (results$n_na > 0) {
    pct <- 100 * results$n_na / results$n_total
    results$warnings <- c(results$warnings, sprintf(
      "%s: %d NA weights (%.1f%%). These cases will be excluded from weighted analysis.",
      label, results$n_na, pct
    ))
  }

  if (results$n_zero > 0) {
    pct <- 100 * results$n_zero / results$n_total
    results$warnings <- c(results$warnings, sprintf(
      "%s: %d zero weights (%.1f%%). These cases will be excluded from weighted analysis.",
      label, results$n_zero, pct
    ))
  }

  # Quality checks on valid weights
  valid_weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]

  if (length(valid_weights) > 0) {
    results$min <- min(valid_weights)
    results$max <- max(valid_weights)
    results$mean <- mean(valid_weights)
    results$cv <- sd(valid_weights) / mean(valid_weights)

    # Calculate design effect
    sum_w <- sum(valid_weights)
    sum_w2 <- sum(valid_weights^2)
    results$effective_n <- round((sum_w^2) / sum_w2)
    results$design_effect <- length(valid_weights) / results$effective_n
    results$efficiency <- 100 * results$effective_n / length(valid_weights)

    # Quality warnings
    if (results$max > 10) {
      results$warnings <- c(results$warnings, sprintf(
        "%s: Maximum weight %.2f is very high (>10). Consider trimming.",
        label, results$max
      ))
    }

    if (results$design_effect > 3) {
      results$warnings <- c(results$warnings, sprintf(
        "%s: Design effect %.2f is high (>3). Effective sample size reduced to %.0f%%.",
        label, results$design_effect, results$efficiency
      ))
    }

    if (results$cv > 1.0) {
      results$warnings <- c(results$warnings, sprintf(
        "%s: Weight CV %.2f is high (>1.0). Consider checking targets or trimming.",
        label, results$cv
      ))
    }
  }

  return(results)
}

#' Validate Weight Specification Row
#'
#' Validates a single row from the Weight_Specifications sheet.
#'
#' @param spec Named list or data frame row with weight specification
#' @return List with $valid and $errors
#' @export
validate_weight_spec <- function(spec) {
  errors <- character(0)

  # Required fields
  if (is.null(spec$weight_name) || is.na(spec$weight_name) || spec$weight_name == "") {
    errors <- c(errors, "weight_name is required and cannot be empty")
  }

  if (is.null(spec$method) || is.na(spec$method)) {
    errors <- c(errors, "method is required")
  } else if (!tolower(spec$method) %in% c("design", "rim")) {
    errors <- c(errors, sprintf(
      "method must be 'design' or 'rim', got: '%s'",
      spec$method
    ))
  }

  # Trimming validation
  apply_trim <- !is.null(spec$apply_trimming) &&
                !is.na(spec$apply_trimming) &&
                toupper(spec$apply_trimming) == "Y"

  if (apply_trim) {
    if (is.null(spec$trim_method) || is.na(spec$trim_method)) {
      errors <- c(errors, "trim_method required when apply_trimming = Y")
    } else if (!tolower(spec$trim_method) %in% c("cap", "percentile")) {
      errors <- c(errors, sprintf(
        "trim_method must be 'cap' or 'percentile', got: '%s'",
        spec$trim_method
      ))
    }

    if (is.null(spec$trim_value) || is.na(spec$trim_value)) {
      errors <- c(errors, "trim_value required when apply_trimming = Y")
    } else {
      trim_val <- suppressWarnings(as.numeric(spec$trim_value))
      if (is.na(trim_val) || trim_val <= 0) {
        errors <- c(errors, sprintf(
          "trim_value must be a positive number, got: '%s'",
          spec$trim_value
        ))
      }

      # Percentile-specific validation
      if (!is.na(spec$trim_method) && tolower(spec$trim_method) == "percentile") {
        if (!is.na(trim_val) && (trim_val <= 0 || trim_val >= 1)) {
          errors <- c(errors, sprintf(
            "For percentile trimming, trim_value must be between 0 and 1 (e.g., 0.95), got: %s",
            spec$trim_value
          ))
        }
      }
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors
  ))
}
