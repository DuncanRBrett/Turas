# ==============================================================================
# CONJOINT DATA LOADING AND VALIDATION - ENHANCED
# ==============================================================================
#
# Module: Conjoint Analysis - Data Management
# Purpose: Load, validate, and prepare conjoint data for analysis
# Version: 2.0.0 (Enhanced Implementation)
# Date: 2025-11-26
#
# ==============================================================================

#' Load Conjoint Data
#'
#' Loads and validates conjoint experimental data with comprehensive checks
#'
#' VALIDATION LEVELS:
#'   - CRITICAL: Stop execution if failed
#'   - WARNING: Continue but flag potential issues
#'   - INFO: Informational messages
#'
#' @param data_file Path to data file (CSV, XLSX, SAV, DTA)
#' @param config Configuration list from load_conjoint_config()
#' @param verbose Logical, print detailed progress
#' @return List with validated data and metadata
#' @export
load_conjoint_data <- function(data_file, config, verbose = TRUE) {

  log_verbose(sprintf("Loading data from: %s", basename(data_file)), verbose)

  # Validate file exists
  if (!file.exists(data_file)) {
    stop(create_error(
      "DATA",
      sprintf("Data file not found: %s", data_file),
      "Verify the file path is correct",
      sprintf("Expected location: %s", data_file)
    ), call. = FALSE)
  }

  # Load data based on file type
  data <- load_data_by_type(data_file)

  # Convert to data frame (in case of tibble)
  data <- as.data.frame(data, stringsAsFactors = FALSE)

  # Basic validation
  if (nrow(data) == 0) {
    stop(create_error(
      "DATA",
      "Data file is empty",
      "Ensure your data export contains rows"
    ), call. = FALSE)
  }

  log_verbose(sprintf("  ✓ Loaded %d rows", nrow(data)), verbose)

  # Detect and handle none option
  none_result <- handle_none_option(data, config, verbose)
  data <- none_result$data

  # Run comprehensive validation
  validation_result <- validate_conjoint_data(data, config)

  # Handle validation results
  if (!validation_result$is_valid) {
    error_msg <- create_error(
      "DATA",
      "Data validation failed",
      paste(validation_result$errors, collapse = "\n → ")
    )
    stop(error_msg, call. = FALSE)
  }

  # Print warnings
  if (length(validation_result$warnings) > 0) {
    for (warning_msg in validation_result$warnings) {
      warning(create_warning("DATA", warning_msg), call. = FALSE)
    }
  }

  # Calculate data statistics
  stats <- calculate_data_statistics(data, config)

  log_verbose(sprintf("  ✓ Validated %d respondents with %d choice sets",
                     stats$n_respondents, stats$n_choice_sets), verbose)

  # Return structured result
  list(
    data = data,
    n_respondents = stats$n_respondents,
    n_choice_sets = stats$n_choice_sets,
    n_profiles = nrow(data),
    has_none = none_result$has_none,
    none_info = if (none_result$has_none) none_result else NULL,
    validation = validation_result,
    statistics = stats
  )
}


#' Load Data by File Type
#'
#' @keywords internal
load_data_by_type <- function(data_file) {

  file_ext <- tolower(tools::file_ext(data_file))

  data <- tryCatch({
    switch(file_ext,
      "csv" = utils::read.csv(data_file, stringsAsFactors = FALSE),
      "xlsx" = openxlsx::read.xlsx(data_file),
      "xls" = openxlsx::read.xlsx(data_file),
      "sav" = {
        require_package("haven", "Package 'haven' required for SPSS files.\nInstall with: install.packages('haven')")
        haven::read_sav(data_file)
      },
      "dta" = {
        require_package("haven", "Package 'haven' required for Stata files.\nInstall with: install.packages('haven')")
        haven::read_dta(data_file)
      },
      stop(create_error(
        "DATA",
        sprintf("Unsupported file format: .%s", file_ext),
        "Supported formats: CSV, XLSX, XLS, SAV (SPSS), DTA (Stata)"
      ), call. = FALSE)
    )
  }, error = function(e) {
    stop(create_error(
      "DATA",
      sprintf("Failed to load data file: %s", conditionMessage(e)),
      "Check that the file is not corrupted or open in another program"
    ), call. = FALSE)
  })

  data
}


#' Validate Conjoint Data
#'
#' Comprehensive validation following spec Part 2
#'
#' @keywords internal
validate_conjoint_data <- function(data, config) {

  errors <- character()
  warnings <- character()
  info <- character()

  # ===== CRITICAL CHECKS (stop if fail) =====

  # Check 1: Required columns exist
  required_cols <- get_required_columns(config)
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    errors <- c(errors, sprintf(
      "Missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
    # If critical columns missing, can't continue validation
    return(list(
      is_valid = FALSE,
      errors = errors,
      warnings = warnings,
      info = info
    ))
  }

  # Check 2: Exactly one chosen per choice set
  chosen_per_set <- data %>%
    group_by(!!sym(config$choice_set_column)) %>%
    summarise(
      n_chosen = sum(!!sym(config$chosen_column)),
      .groups = "drop"
    )

  invalid_sets <- chosen_per_set %>%
    filter(n_chosen != 1)

  if (nrow(invalid_sets) > 0) {
    bad_set_ids <- head(invalid_sets[[config$choice_set_column]], 10)
    errors <- c(errors, sprintf(
      "%d choice sets do not have exactly 1 chosen alternative",
      nrow(invalid_sets)
    ))
    errors <- c(errors, sprintf(
      "Example problematic choice sets: %s",
      paste(bad_set_ids, collapse = ", ")
    ))
  }

  # Check 3: Attribute levels in data match config
  for (attr in config$attributes$AttributeName) {
    if (!attr %in% names(data)) {
      errors <- c(errors, sprintf("Attribute column '%s' not found in data", attr))
      next
    }

    config_levels <- get_attribute_levels(config, attr)
    data_levels <- unique(as.character(data[[attr]]))

    # Remove none levels for comparison
    if ("is_none_alternative" %in% names(data)) {
      non_none_data <- data[!data$is_none_alternative, ]
      data_levels <- unique(as.character(non_none_data[[attr]]))
    }

    # Check for levels in data not in config
    extra_levels <- setdiff(data_levels, config_levels)
    if (length(extra_levels) > 0) {
      errors <- c(errors, sprintf(
        "Attribute '%s': Data contains levels not in config: %s",
        attr, paste(head(extra_levels, 5), collapse = ", ")
      ))
    }

    # Check for levels in config not in data (warning only)
    missing_levels <- setdiff(config_levels, data_levels)
    if (length(missing_levels) > 0) {
      warnings <- c(warnings, sprintf(
        "Attribute '%s': Config levels not found in data: %s (This is OK if intentional)",
        attr, paste(missing_levels, collapse = ", ")
      ))
    }
  }

  # Check 4: No missing values in critical columns
  for (col in required_cols) {
    if (any(is.na(data[[col]]))) {
      n_missing <- sum(is.na(data[[col]]))
      errors <- c(errors, sprintf(
        "Column '%s' has %d missing values (NAs not allowed)",
        col, n_missing
      ))
    }
  }

  # Check 5: Chosen is binary (0/1)
  chosen_vals <- unique(data[[config$chosen_column]])
  if (!all(chosen_vals %in% c(0, 1))) {
    errors <- c(errors, sprintf(
      "'%s' column must contain only 0 and 1 (found: %s)",
      config$chosen_column,
      paste(unique(chosen_vals), collapse = ", ")
    ))
  }

  # Stop here if critical errors found
  if (length(errors) > 0) {
    return(list(
      is_valid = FALSE,
      errors = errors,
      warnings = warnings,
      info = info
    ))
  }

  # ===== WARNING CHECKS (continue with caution) =====

  # Warning 1: Low response counts per level
  min_responses <- config$min_responses_per_level
  for (attr in config$attributes$AttributeName) {
    level_counts <- data %>%
      filter(!!sym(config$chosen_column) == 1) %>%
      count(!!sym(attr), name = "n_selections")

    low_counts <- level_counts %>%
      filter(n_selections < min_responses)

    if (nrow(low_counts) > 0) {
      warnings <- c(warnings, sprintf(
        "Attribute '%s': Some levels selected fewer than %d times: %s",
        attr,
        min_responses,
        paste(low_counts[[attr]], collapse = ", ")
      ))
    }
  }

  # Warning 2: Some cards never chosen
  card_selection_rate <- data %>%
    group_by(across(all_of(config$attributes$AttributeName))) %>%
    summarise(
      n_shown = n(),
      n_chosen = sum(!!sym(config$chosen_column)),
      .groups = "drop"
    ) %>%
    filter(n_chosen == 0)

  if (nrow(card_selection_rate) > 0) {
    warnings <- c(warnings, sprintf(
      "%d unique product combinations were never chosen (may affect estimation)",
      nrow(card_selection_rate)
    ))
  }

  # Warning 3: Unbalanced choice set sizes
  set_sizes <- data %>%
    count(!!sym(config$choice_set_column), name = "n_alternatives")

  if (length(unique(set_sizes$n_alternatives)) > 1) {
    size_summary <- paste(unique(set_sizes$n_alternatives), collapse = ", ")
    warnings <- c(warnings, sprintf(
      "Unbalanced choice sets (sizes: %s alternatives). Ensure this is intentional.",
      size_summary
    ))
  }

  # Warning 4: Sample size adequacy
  n_respondents <- length(unique(data[[config$respondent_id_column]]))
  n_attributes <- nrow(config$attributes)
  max_levels <- max(config$attributes$NumLevels)

  # Rule of thumb: 300+ respondents, more for complex designs
  recommended_n <- max(300, 300 * (n_attributes / 4) * (max_levels / 4))

  if (n_respondents < recommended_n) {
    warnings <- c(warnings, sprintf(
      "Sample size (%d respondents) may be insufficient. Recommended: %d+",
      n_respondents, ceiling(recommended_n)
    ))
  }

  # Warning 5: Perfect separation check
  for (attr in config$attributes$AttributeName) {
    separation <- check_perfect_separation(data, attr, config$chosen_column)

    if (separation$has_separation) {
      if (length(separation$always_chosen) > 0) {
        warnings <- c(warnings, sprintf(
          "Attribute '%s': Level(s) always chosen (perfect separation): %s",
          attr, paste(separation$always_chosen, collapse = ", ")
        ))
      }

      if (length(separation$never_chosen) > 0) {
        warnings <- c(warnings, sprintf(
          "Attribute '%s': Level(s) never chosen: %s",
          attr, paste(separation$never_chosen, collapse = ", ")
        ))
      }
    }
  }

  # ===== INFO MESSAGES =====

  # Info: Choice set structure
  info <- c(info, sprintf(
    "Data structure: %d respondents, %d choice sets, %d total alternatives",
    n_respondents,
    length(unique(data[[config$choice_set_column]])),
    nrow(data)
  ))

  # Info: Average alternatives per choice set
  avg_alternatives <- mean(set_sizes$n_alternatives)
  info <- c(info, sprintf(
    "Average alternatives per choice set: %.1f",
    avg_alternatives
  ))

  # Return validation result
  list(
    is_valid = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    info = info
  )
}


#' Get Required Columns
#'
#' @keywords internal
get_required_columns <- function(config) {
  required <- c(
    config$respondent_id_column,
    config$choice_set_column,
    config$chosen_column,
    config$attributes$AttributeName
  )

  # Remove NAs
  required[!is.na(required)]
}


#' Calculate Data Statistics
#'
#' @keywords internal
calculate_data_statistics <- function(data, config) {

  n_respondents <- length(unique(data[[config$respondent_id_column]]))
  n_choice_sets <- length(unique(data[[config$choice_set_column]]))

  # Choice sets per respondent
  sets_per_resp <- data %>%
    group_by(!!sym(config$respondent_id_column)) %>%
    summarise(n_sets = n_distinct(!!sym(config$choice_set_column)), .groups = "drop")

  # Alternatives per choice set
  alts_per_set <- data %>%
    count(!!sym(config$choice_set_column), name = "n_alts")

  # Selection rates by attribute level
  selection_rates <- list()
  for (attr in config$attributes$AttributeName) {
    rates <- data %>%
      group_by(!!sym(attr)) %>%
      summarise(
        n_shown = n(),
        n_chosen = sum(!!sym(config$chosen_column)),
        selection_rate = n_chosen / n_shown,
        .groups = "drop"
      )

    selection_rates[[attr]] <- rates
  }

  list(
    n_respondents = n_respondents,
    n_choice_sets = n_choice_sets,
    n_total_alternatives = nrow(data),
    choice_sets_per_respondent = list(
      mean = mean(sets_per_resp$n_sets),
      min = min(sets_per_resp$n_sets),
      max = max(sets_per_resp$n_sets)
    ),
    alternatives_per_choice_set = list(
      mean = mean(alts_per_set$n_alts),
      min = min(alts_per_set$n_alts),
      max = max(alts_per_set$n_alts),
      mode = as.numeric(names(sort(table(alts_per_set$n_alts), decreasing = TRUE)[1]))
    ),
    selection_rates = selection_rates
  )
}
