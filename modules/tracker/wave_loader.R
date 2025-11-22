# ==============================================================================
# TurasTracker - Wave Data Loader
# ==============================================================================
#
# Loads and validates survey data for each wave.
# Supports both CSV and Excel formats.
# Handles weighting variable application.
#
# VERSION: 2.0.0 - Phase 4 Update
#
# PHASE 4 UPDATE:
# Shared weight utilities NOW AVAILABLE in shared/weights.R:
# - calculate_weight_efficiency() - Effective sample size calculation
# - calculate_design_effect() - Design effect (deff) calculation
# - validate_weights() - Comprehensive weight validation
# - get_weight_summary() - Descriptive weight statistics
# - standardize_weight_variable() - Create standardized weight column
#
# This module currently uses local calculate_weight_efficiency() function.
# New code should use shared/weights.R functions for consistency.
# ==============================================================================

#' Load All Wave Data
#'
#' Loads data for all waves defined in tracking configuration.
#' Resolves file paths, applies weighting, and performs validation.
#'
#' @param config List. Configuration object from load_tracking_config()
#' @param data_dir Character. Directory containing wave data files (if relative paths used)
#' @return List of data frames, one per wave, with names as WaveIDs
#'
#' @export
load_all_waves <- function(config, data_dir = NULL) {

  message("Loading wave data files...")

  wave_data <- list()

  for (i in 1:nrow(config$waves)) {
    wave_id <- config$waves$WaveID[i]
    wave_name <- config$waves$WaveName[i]
    data_file <- config$waves$DataFile[i]

    message(paste0("  Loading Wave ", wave_id, ": ", wave_name))

    # Resolve file path
    file_path <- resolve_data_file_path(data_file, data_dir)

    # Load wave data
    wave_df <- load_wave_data(file_path, wave_id)

    # Apply weighting if specified
    weight_var <- get_wave_weight_var(config, wave_id)
    if (!is.null(weight_var) && weight_var != "") {
      wave_df <- apply_wave_weights(wave_df, weight_var, wave_id)
    } else {
      message("    No weighting variable specified for this wave")
      # Create default weight of 1
      wave_df$weight_var <- 1
    }

    # Store in list
    wave_data[[wave_id]] <- wave_df

    message(paste0("    Loaded ", nrow(wave_df), " records"))
  }

  message(paste0("Successfully loaded ", length(wave_data), " waves"))

  return(wave_data)
}


#' Clean Wave Data
#'
#' Cleans wave data to handle common data quality issues:
#' - Comma decimal separators (7,5 -> 7.5)
#' - DK/Don't Know/Prefer not to say -> NA
#' - Other non-response codes -> NA
#'
#' @param wave_df Data frame. Wave data
#' @param wave_id Character. Wave identifier for messages
#' @return Cleaned data frame
#'
#' @keywords internal
clean_wave_data <- function(wave_df, wave_id) {

  n_cleaned <- 0

  # List of non-response codes to convert to NA
  non_response_codes <- c("DK", "Don't Know", "Don't know", "NS", "NR",
                          "Prefer not to say", "Refused", "N/A", "NA")

  for (col_name in names(wave_df)) {
    col_data <- wave_df[[col_name]]

    # Skip if already numeric
    if (is.numeric(col_data)) {
      next
    }

    # Skip if all NA
    if (all(is.na(col_data))) {
      next
    }

    # Check if column might be numeric (has digits)
    if (is.character(col_data)) {
      # Check if any values contain digits or decimal separators (use which() to avoid NA issues)
      non_na_idx <- which(!is.na(col_data))
      non_na_values <- col_data[non_na_idx]
      has_numbers <- length(non_na_values) > 0 && any(grepl("[0-9]", non_na_values))

      if (has_numbers) {
        original_col <- col_data

        # Replace comma decimals with period decimals
        col_data <- gsub(",", ".", col_data, fixed = TRUE)

        # Replace non-response codes with NA (use which() to avoid NA issues)
        for (code in non_response_codes) {
          match_idx <- which(trimws(toupper(col_data)) == toupper(code))
          if (length(match_idx) > 0) {
            col_data[match_idx] <- NA
          }
        }

        # Try converting to numeric
        col_numeric <- suppressWarnings(as.numeric(col_data))

        # If conversion created NAs where there weren't any, report it
        new_nas <- sum(is.na(col_numeric)) - sum(is.na(original_col))
        if (new_nas > 0) {
          n_cleaned <- n_cleaned + 1
          message(paste0("    ", col_name, ": Converted ", new_nas, " non-numeric values to NA"))
        }

        # If at least some values converted successfully, use the numeric version
        if (sum(!is.na(col_numeric)) > 0) {
          wave_df[[col_name]] <- col_numeric
        }
      }
    }
  }

  if (n_cleaned > 0) {
    message(paste0("    Cleaned ", n_cleaned, " column(s) with comma decimals or DK values"))
  }

  return(wave_df)
}


#' Load Single Wave Data File
#'
#' Loads a single wave data file, detecting format (CSV or Excel).
#'
#' @param file_path Character. Full path to data file
#' @param wave_id Character. Wave identifier for error messages
#' @return Data frame containing wave data
#'
#' @keywords internal
load_wave_data <- function(file_path, wave_id) {

  if (!file.exists(file_path)) {
    stop(paste0("Data file not found for Wave ", wave_id, ": ", file_path))
  }

  # Detect file format from extension
  file_ext <- tolower(tools::file_ext(file_path))

  if (file_ext == "csv") {
    # Load CSV file
    wave_df <- tryCatch({
      read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    }, error = function(e) {
      stop(paste0("Error reading CSV file for Wave ", wave_id, ": ", e$message))
    })

  } else if (file_ext %in% c("xlsx", "xls")) {
    # Load Excel file (assume first sheet unless specified)
    wave_df <- tryCatch({
      openxlsx::read.xlsx(file_path, sheet = 1, check.names = FALSE)
    }, error = function(e) {
      stop(paste0("Error reading Excel file for Wave ", wave_id, ": ", e$message))
    })

  } else {
    stop(paste0("Unsupported file format for Wave ", wave_id, ": ", file_ext, " (expected csv, xlsx, or xls)"))
  }

  # Basic validation
  if (nrow(wave_df) == 0) {
    stop(paste0("Data file for Wave ", wave_id, " is empty"))
  }

  # Clean data (handle comma decimals, DK values, etc.)
  wave_df <- clean_wave_data(wave_df, wave_id)

  return(wave_df)
}


#' Resolve Data File Path
#'
#' Resolves data file path, handling both absolute and relative paths.
#'
#' @param data_file Character. File path from configuration
#' @param data_dir Character. Base directory for relative paths (optional)
#' @return Character. Resolved absolute path
#'
#' @keywords internal
resolve_data_file_path <- function(data_file, data_dir = NULL) {

  # If absolute path, use as-is
  if (file.exists(data_file)) {
    return(normalizePath(data_file))
  }

  # If relative path and data_dir provided, combine
  if (!is.null(data_dir)) {
    combined_path <- file.path(data_dir, data_file)
    if (file.exists(combined_path)) {
      return(normalizePath(combined_path))
    }
  }

  # If not found, return original (will error in load_wave_data)
  return(data_file)
}


#' Get Weight Variable for Wave
#'
#' Retrieves the weighting variable name for a specific wave.
#' MVT assumption: Same weight variable name across all waves.
#'
#' @param config List. Configuration object
#' @param wave_id Character. Wave identifier
#' @return Character. Weight variable name, or NULL if not specified
#'
#' @keywords internal
get_wave_weight_var <- function(config, wave_id) {

  # Check if WeightVar column exists in waves definition
  if ("WeightVar" %in% names(config$waves)) {
    # Use which() to avoid NA issues in logical indexing
    wave_idx <- which(config$waves$WaveID == wave_id)
    if (length(wave_idx) > 0) {
      wave_row <- config$waves[wave_idx[1], ]
      weight_var <- wave_row$WeightVar[1]
      if (!is.na(weight_var) && weight_var != "") {
        return(weight_var)
      }
    }
  }

  # Fall back to global setting
  weight_var <- get_setting(config, "weight_variable", default = NULL)

  return(weight_var)
}


#' Apply Weighting to Wave Data
#'
#' Applies weighting variable to wave data, creating a standardized weight_var column.
#'
#' SHARED CODE NOTE: This weight calculation logic is identical to TurasTabs
#' Future: Extract to /shared/weights.R::apply_weights()
#'   - Calculate_weight_efficiency() should also be shared
#'   - Weight validation logic should be shared
#'   - Weight summary statistics should be shared
#'
#' @param wave_df Data frame. Wave data
#' @param weight_var Character. Name of weighting variable in data
#' @param wave_id Character. Wave identifier for messages
#' @return Data frame with standardized weight_var column added
#'
#' @keywords internal
apply_wave_weights <- function(wave_df, weight_var, wave_id) {

  # Check if weight variable exists
  if (!weight_var %in% names(wave_df)) {
    warning(paste0("Weight variable '", weight_var, "' not found in Wave ", wave_id, " data. Using unweighted data (all weights = 1)."))
    wave_df$weight_var <- 1
    return(wave_df)
  }

  # Extract weight values
  weights <- wave_df[[weight_var]]

  # Validate weights
  if (any(is.na(weights))) {
    n_missing <- sum(is.na(weights))
    warning(paste0("Wave ", wave_id, ": ", n_missing, " records have missing weights (will be excluded)"))
  }

  if (any(weights[!is.na(weights)] <= 0)) {
    n_invalid <- sum(weights[!is.na(weights)] <= 0)
    warning(paste0("Wave ", wave_id, ": ", n_invalid, " records have zero or negative weights (will be excluded)"))
    # Actually exclude invalid weights by setting to NA (use which() to avoid NA issues)
    invalid_idx <- which(!is.na(weights) & weights <= 0)
    if (length(invalid_idx) > 0) {
      weights[invalid_idx] <- NA
    }
  }

  # Create standardized weight column
  wave_df$weight_var <- weights

  # Calculate weight efficiency (measure of weight distribution)
  # SHARED CODE NOTE: This calculation should be in /shared/weights.R
  # Use which() to avoid NA issues in logical indexing
  valid_idx <- which(!is.na(weights) & weights > 0)
  valid_weights <- weights[valid_idx]
  if (length(valid_weights) > 0) {
    eff_n <- calculate_weight_efficiency(valid_weights)
    message(paste0("    Weight efficiency: ", round(eff_n, 1), " (out of ", length(valid_weights), " records)"))
  }

  return(wave_df)
}


#' Calculate Weight Efficiency
#'
#' Calculates effective sample size given a vector of weights.
#' Efficiency = (sum of weights)^2 / sum of squared weights
#'
#' SHARED CODE NOTE: This should be extracted to /shared/weights.R
#' Identical calculation used in TurasTabs
#'
#' @param weights Numeric vector of weight values
#' @return Numeric. Effective sample size
#'
#' @keywords internal
calculate_weight_efficiency <- function(weights) {
  sum_weights <- sum(weights, na.rm = TRUE)
  sum_weights_squared <- sum(weights^2, na.rm = TRUE)

  if (sum_weights_squared == 0) {
    return(0)
  }

  eff_n <- (sum_weights^2) / sum_weights_squared
  return(eff_n)
}


#' Validate Wave Data Structure
#'
#' Performs structural validation on loaded wave data.
#' Checks for required columns, data types, and consistency.
#'
#' @param wave_data List. Named list of wave data frames
#' @param config List. Configuration object
#' @param question_mapping Data frame. Question mapping
#' @return Invisible TRUE if validation passes, stops with error otherwise
#'
#' @export
validate_wave_data <- function(wave_data, config, question_mapping) {

  message("Validating wave data structure...")

  # Check all waves loaded
  expected_waves <- config$waves$WaveID
  loaded_waves <- names(wave_data)

  missing_waves <- setdiff(expected_waves, loaded_waves)
  if (length(missing_waves) > 0) {
    stop(paste0("Missing data for waves: ", paste(missing_waves, collapse = ", ")))
  }

  # Validate each wave
  for (wave_id in expected_waves) {
    wave_df <- wave_data[[wave_id]]

    # Check weight_var exists
    if (!"weight_var" %in% names(wave_df)) {
      stop(paste0("Wave ", wave_id, ": weight_var column not created"))
    }

    # Check for tracked question variables
    # Get question codes for this wave from mapping
    wave_col <- paste0("Wave", which(config$waves$WaveID == wave_id))

    if (wave_col %in% names(question_mapping)) {
      wave_questions <- trimws(as.character(question_mapping[[wave_col]]))
      # Use which() to avoid NA issues in logical indexing
      valid_idx <- which(!is.na(wave_questions) & wave_questions != "")
      wave_questions <- wave_questions[valid_idx]

      # Filter out composite questions (they're calculated, not in raw data)
      if ("QuestionType" %in% names(question_mapping)) {
        # Get indices of non-composite questions (use which() to avoid NA issues)
        non_composite_idx <- which(question_mapping$QuestionType != "Composite" |
                                   is.na(question_mapping$QuestionType))
        wave_questions_to_check <- question_mapping[[wave_col]][non_composite_idx]
        valid_check_idx <- which(!is.na(wave_questions_to_check) &
                                 wave_questions_to_check != "")
        wave_questions_to_check <- wave_questions_to_check[valid_check_idx]
        question_types_to_check <- question_mapping$QuestionType[non_composite_idx]
        question_types_to_check <- question_types_to_check[valid_check_idx]
      } else {
        wave_questions_to_check <- wave_questions
        question_types_to_check <- rep(NA, length(wave_questions))
      }

      # Check which questions are missing
      # For Multi_Mention questions, check for pattern Q##_1, Q##_2, etc.
      missing_questions <- character(0)
      for (i in seq_along(wave_questions_to_check)) {
        q_code <- wave_questions_to_check[i]
        q_type <- question_types_to_check[i]

        # For Multi_Mention, check if at least one option column exists
        if (!is.na(q_type) && q_type == "Multi_Mention") {
          # Build pattern: ^{q_code}_{digits}$
          q_code_escaped <- gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", q_code)
          pattern <- paste0("^", q_code_escaped, "_[0-9]+$")
          matched_cols <- grep(pattern, names(wave_df), value = TRUE)

          if (length(matched_cols) == 0) {
            missing_questions <- c(missing_questions, q_code)
          }
        } else {
          # For other question types, check exact column name
          if (!q_code %in% names(wave_df)) {
            missing_questions <- c(missing_questions, q_code)
          }
        }
      }

      if (length(missing_questions) > 0) {
        warning(paste0(
          "Wave ", wave_id, ": ",
          length(missing_questions), " mapped questions not found in data: ",
          paste(head(missing_questions, 5), collapse = ", "),
          if (length(missing_questions) > 5) "..." else ""
        ))
      }
    }
  }

  message("  Wave data validation completed")

  invisible(TRUE)
}


#' Get Wave Data Summary
#'
#' Generates summary statistics for loaded wave data.
#'
#' @param wave_data List. Named list of wave data frames
#' @return Data frame with summary statistics per wave
#'
#' @export
get_wave_summary <- function(wave_data) {

  summary_list <- list()

  for (wave_id in names(wave_data)) {
    wave_df <- wave_data[[wave_id]]

    summary_list[[wave_id]] <- data.frame(
      WaveID = wave_id,
      TotalRecords = nrow(wave_df),
      ValidWeights = sum(!is.na(wave_df$weight_var) & wave_df$weight_var > 0),
      SumWeights = sum(wave_df$weight_var, na.rm = TRUE),
      EffectiveN = calculate_weight_efficiency(wave_df$weight_var),
      Variables = ncol(wave_df),
      stringsAsFactors = FALSE
    )
  }

  summary_df <- do.call(rbind, summary_list)
  rownames(summary_df) <- NULL

  return(summary_df)
}
