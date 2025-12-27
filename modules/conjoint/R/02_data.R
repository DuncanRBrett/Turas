# ==============================================================================
# CONJOINT DATA LOADING AND VALIDATION - ENHANCED WITH ALCHEMER SUPPORT
# ==============================================================================
#
# Module: Conjoint Analysis - Data Management
# Purpose: Load, validate, and prepare conjoint data for analysis
# Version: 2.1.0 (Phase 1 - Alchemer Integration)
# Date: 2025-12-12
#
# SUPPORTED DATA SOURCES:
#   - alchemer: Uses import_alchemer_conjoint() for Alchemer CBC exports
#   - generic: Standard Turas format loader
#
# ==============================================================================

#' Load Conjoint Data
#'
#' Loads and validates conjoint experimental data with comprehensive checks.
#' Automatically detects data source type (Alchemer or generic) from config
#' and uses the appropriate loader.
#'
#' VALIDATION LEVELS:
#'   - CRITICAL: Stop execution if failed
#'   - WARNING: Continue but flag potential issues
#'   - INFO: Informational messages
#'
#' SUPPORTED DATA SOURCES:
#'   - alchemer: Alchemer CBC export (ResponseID, SetNumber, CardNumber, Score)
#'   - generic: Standard Turas format (resp_id, choice_set_id, alternative_id, chosen)
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
    conjoint_refuse(
      code = "IO_DATA_FILE_NOT_FOUND",
      title = "Data File Not Found",
      problem = sprintf("Data file not found: %s", data_file),
      why_it_matters = "The data file contains the survey responses needed for conjoint analysis.",
      how_to_fix = c(
        "Verify the file path is correct in your configuration",
        "Check that the file exists at the specified location",
        sprintf("Expected location: %s", data_file)
      )
    )
  }

  # Check data source type from config
  data_source <- config$data_source %||% "generic"

  # =========================================================================
  # ALCHEMER DATA SOURCE
  # =========================================================================
  if (data_source == "alchemer") {
    log_verbose("  Data source: Alchemer CBC export", verbose)

    # Use Alchemer import function
    data <- import_alchemer_conjoint(
      file_path = data_file,
      config = config,
      clean_levels = config$clean_alchemer_levels %||% TRUE,
      verbose = verbose
    )

    # Auto-detect attributes from imported data if not in config
    if (is.null(config$attributes) || nrow(config$attributes) == 0) {
      log_verbose("  Auto-detecting attributes from Alchemer data...", verbose)
      config$attributes <- get_alchemer_attributes(data)

      # Add levels_list for each attribute
      config$attributes$levels_list <- lapply(
        config$attributes$AttributeName,
        function(attr) sort(unique(data[[attr]]))
      )
    }

  # =========================================================================
  # GENERIC DATA SOURCE
  # =========================================================================
  } else {
    log_verbose("  Data source: Generic Turas format", verbose)

    # Load data based on file type
    data <- load_data_by_type(data_file)

    # Convert to data frame (in case of tibble)
    data <- as.data.frame(data, stringsAsFactors = FALSE)
  }

  # Basic validation
  if (nrow(data) == 0) {
    conjoint_refuse(
      code = "DATA_FILE_EMPTY",
      title = "Data File Is Empty",
      problem = "Data file contains no rows.",
      why_it_matters = "Cannot perform analysis without survey response data.",
      how_to_fix = c(
        "Ensure your data export contains rows",
        "Check that the survey has responses",
        sprintf("File: %s", data_file)
      )
    )
  }

  log_verbose(sprintf("  ✓ Loaded %d rows", nrow(data)), verbose)

  # Detect and handle none option
  none_result <- handle_none_option(data, config, verbose)
  data <- none_result$data

  # Run comprehensive validation
  validation_result <- validate_conjoint_data(data, config)

  # Handle validation results
  if (!validation_result$is_valid) {
    conjoint_refuse(
      code = "DATA_VALIDATION_FAILED",
      title = "Data Validation Failed",
      problem = "Data file contains errors that prevent analysis.",
      why_it_matters = "Invalid data structure or values will cause analysis to fail or produce incorrect results.",
      how_to_fix = c(
        "Review and fix the following validation errors:",
        validation_result$errors
      ),
      details = paste(validation_result$errors, collapse = "; ")
    )
  }

  # Print warnings
  if (length(validation_result$warnings) > 0) {
    for (warning_msg in validation_result$warnings) {
      message(sprintf("[TRS INFO] CONJ_DATA_WARNING: %s", warning_msg))
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
      conjoint_refuse(
        code = "IO_UNSUPPORTED_FILE_FORMAT",
        title = "Unsupported File Format",
        problem = sprintf("Unsupported file format: .%s", file_ext),
        why_it_matters = "The data loader can only read specific file formats.",
        how_to_fix = c(
          "Convert your data to a supported format",
          "Supported formats: CSV, XLSX, XLS, SAV (SPSS), DTA (Stata)",
          sprintf("Your file: %s", basename(data_file))
        )
      )
    )
  }, error = function(e) {
    conjoint_refuse(
      code = "IO_DATA_FILE_READ_ERROR",
      title = "Data File Read Failed",
      problem = sprintf("Failed to load data file: %s", conditionMessage(e)),
      why_it_matters = "Cannot proceed with analysis without loading the survey response data.",
      how_to_fix = c(
        "Check that the file is not corrupted",
        "Ensure the file is not open in another program",
        "Verify the file format matches its extension",
        sprintf("File: %s", data_file)
      )
    )
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

  # Check 2: Exactly one chosen per choice set (per respondent)
  chosen_per_set <- data %>%
    group_by(!!sym(config$respondent_id_column), !!sym(config$choice_set_column)) %>%
    summarise(
      n_chosen = sum(!!sym(config$chosen_column)),
      .groups = "drop"
    )

  invalid_sets <- chosen_per_set %>%
    filter(n_chosen != 1)

  if (nrow(invalid_sets) > 0) {
    # Show respondent_id and choice_set_id for problematic sets
    bad_examples <- head(invalid_sets, 10)
    bad_set_desc <- paste(
      sprintf("Resp %s / Set %s (%d chosen)",
              bad_examples[[config$respondent_id_column]],
              bad_examples[[config$choice_set_column]],
              bad_examples$n_chosen),
      collapse = "; "
    )
    errors <- c(errors, sprintf(
      "%d choice sets do not have exactly 1 chosen alternative",
      nrow(invalid_sets)
    ))
    errors <- c(errors, sprintf(
      "Example problematic choice sets: %s",
      bad_set_desc
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
