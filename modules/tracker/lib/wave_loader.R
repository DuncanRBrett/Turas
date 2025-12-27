# ==============================================================================
# TurasTracker - Wave Data Loader
# ==============================================================================
#
# Loads and validates survey data for each wave.
# Supports both CSV and Excel formats.
# Handles weighting variable application.
#
# VERSION: 2.2.0 - Added parallel loading support
#
# PARALLEL PROCESSING:
# When processing large multi-wave datasets (5+ waves), parallel loading
# can significantly reduce load times. Parallelization uses the 'future'
# and 'future.apply' packages if available.
#
# To enable: load_all_waves(..., parallel = TRUE)
# Requirements: future, future.apply packages installed
# Fallback: Sequential loading if packages not available
#
# SHARED WEIGHT UTILITIES in /modules/shared/lib/weights_utils.R:
# - calculate_weight_efficiency() - Effective sample size calculation
# - calculate_design_effect() - Design effect (deff) calculation
# - validate_weights_comprehensive() - Comprehensive weight validation
# - get_weight_summary() - Descriptive weight statistics
# - standardize_weight_variable() - Create standardized weight column
# ==============================================================================

# Ensure shared utilities are available
if (!exists("calculate_weight_efficiency", mode = "function")) {
  # Find the shared/lib path - try multiple locations
  .shared_lib_path <- NULL
  .shared_lib_candidates <- c(
    # If script_dir is set (from parent run_tracker.R), go up to modules/shared/lib
    if (exists("script_dir") && !is.null(script_dir) && length(script_dir) > 0 && nzchar(script_dir[1])) {
      file.path(dirname(script_dir[1]), "shared", "lib")  # ../shared/lib from tracker dir
    } else NULL,
    # Try relative to current working directory
    file.path(getwd(), "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    # Try TURAS_HOME if set
    file.path(Sys.getenv("TURAS_HOME", unset = ""), "modules", "shared", "lib")
  )
  .shared_lib_candidates <- .shared_lib_candidates[!is.null(.shared_lib_candidates) & nzchar(.shared_lib_candidates)]

  for (.candidate in .shared_lib_candidates) {
    if (dir.exists(.candidate)) {
      .shared_lib_path <- .candidate
      break
    }
  }

  if (!is.null(.shared_lib_path) && file.exists(file.path(.shared_lib_path, "weights_utils.R"))) {
    # Source weights_utils (it has no dependencies)
    source(file.path(.shared_lib_path, "weights_utils.R"), local = FALSE)
  }

  rm(list = c(".shared_lib_path", ".shared_lib_candidates", ".candidate")[
    c(".shared_lib_path", ".shared_lib_candidates", ".candidate") %in% ls(all.names = TRUE)
  ])
}

#' Extract Categorical Question Codes
#'
#' Extracts all question codes that should preserve text/categorical values.
#' This includes:
#' - Banner variables (ALWAYS preserved as text for filtering)
#' - Single_Response, Multi_Mention, and other categorical question types
#' Numeric question types (Rating, Likert, NPS, Numeric, Index) will be converted to numeric.
#'
#' @param config List. Configuration object (for banner variables)
#' @param question_mapping Data frame. Question mapping with QuestionType column
#' @return Character vector of categorical question codes to preserve
#'
#' @keywords internal
extract_categorical_question_codes <- function(config = NULL, question_mapping = NULL) {

  categorical_codes <- character(0)

  # FIRST: Extract ALL banner variables - these MUST be preserved as text
  # Banner variables are used for filtering, so they need their original text values
  if (!is.null(config) && !is.null(config$banner) && nrow(config$banner) > 0) {
    banner <- config$banner
    wave_ids <- config$waves$WaveID

    # Collect all question codes from wave-specific columns in banner
    for (wave_id in wave_ids) {
      if (wave_id %in% names(banner)) {
        wave_codes <- banner[[wave_id]]
        # Extract non-empty codes
        valid_codes <- wave_codes[!is.na(wave_codes) & trimws(wave_codes) != ""]
        categorical_codes <- c(categorical_codes, trimws(valid_codes))
      }
    }
  }

  # SECOND: Add categorical tracked questions from question mapping
  if (!is.null(question_mapping) && "QuestionType" %in% names(question_mapping)) {
    for (i in 1:nrow(question_mapping)) {
      q_code <- question_mapping$QuestionCode[i]
      q_type <- question_mapping$QuestionType[i]

      if (is.na(q_code) || is.na(q_type)) {
        next
      }

      # Preserve text for these question types:
      # - Single_Response (categorical with text options)
      # - Multi_Mention (multiple categorical responses)
      # - Categorical, Nominal, Ordinal (explicit categorical types)
      # - Open_End (text responses)
      #
      # Convert to numeric for these types:
      # - Rating, Likert, NPS, Numeric, Index (numeric scales)
      if (grepl("single_response|multi_mention|categorical|nominal|ordinal|open_end|text|choice",
                tolower(q_type))) {
        categorical_codes <- c(categorical_codes, q_code)
      }
    }
  }

  return(unique(categorical_codes))
}


#' Load All Wave Data
#'
#' Loads data for all waves defined in tracking configuration.
#' Resolves file paths, applies weighting, and performs validation.
#'
#' @section Parallel Loading:
#' When parallel = TRUE and multiple waves exist, waves are loaded in parallel
#' using the future/future.apply framework. This can significantly speed up
#' loading for large multi-wave datasets.
#'
#' Requirements for parallel loading:
#' - future and future.apply packages installed
#' - At least 3 waves (overhead not worth it for fewer)
#' - Sufficient memory for multiple datasets in parallel
#'
#' If packages are not available, falls back to sequential loading with a message.
#'
#' @param config List. Configuration object from load_tracking_config()
#' @param data_dir Character. Directory containing wave data files (if relative paths used)
#' @param question_mapping Data frame. Question mapping (optional, for determining categorical questions)
#' @param parallel Logical. If TRUE, attempt parallel loading of waves. Default FALSE.
#' @return List of data frames, one per wave, with names as WaveIDs
#'
#' @export
load_all_waves <- function(config, data_dir = NULL, question_mapping = NULL, parallel = FALSE) {

  cat("Loading wave data files...\n")

  # Extract all categorical question codes to preserve their text values
  # This includes ALL banner variables (always text) plus categorical tracked questions
  categorical_cols <- extract_categorical_question_codes(config, question_mapping)
  if (length(categorical_cols) > 0) {
    cat(paste0("  Identified ", length(categorical_cols), " categorical question(s) to preserve as text: ",
                   paste(head(categorical_cols, 10), collapse = ", "),
                   if (length(categorical_cols) > 10) " ..." else "", "\n"))
  }

  n_waves <- nrow(config$waves)

  # ---------------------------------------------------------------------------
  # PARALLEL LOADING (for large multi-wave datasets)
  # ---------------------------------------------------------------------------
  # Use parallel loading when:
  # 1. parallel = TRUE requested
  # 2. At least 3 waves (overhead not worth it for fewer)
  # 3. Required packages are available
  use_parallel <- FALSE
  if (parallel && n_waves >= 3) {
    if (requireNamespace("future", quietly = TRUE) &&
        requireNamespace("future.apply", quietly = TRUE)) {
      use_parallel <- TRUE
      cat(paste0("  Using parallel loading for ", n_waves, " waves\n"))
    } else {
      cat("  Note: parallel=TRUE requested but future/future.apply packages not installed.\n")
      cat("  Falling back to sequential loading. Install packages for parallel support.\n")
    }
  }

  if (use_parallel) {
    # Set up parallel plan if not already configured
    if (!future::plan() %in% c("multisession", "multicore", "cluster")) {
      # Use multisession for cross-platform compatibility
      old_plan <- future::plan(future::multisession, workers = min(n_waves, parallel::detectCores() - 1))
      on.exit(future::plan(old_plan), add = TRUE)
    }

    # Prepare wave info for parallel processing
    wave_info <- lapply(1:n_waves, function(i) {
      list(
        wave_id = config$waves$WaveID[i],
        wave_name = config$waves$WaveName[i],
        data_file = config$waves$DataFile[i],
        weight_var = get_wave_weight_var(config, config$waves$WaveID[i])
      )
    })

    # Load waves in parallel
    cat("  Loading waves in parallel...\n")
    wave_results <- future.apply::future_lapply(wave_info, function(info) {
      # Resolve file path
      file_path <- resolve_data_file_path(info$data_file, data_dir)

      # Load wave data
      wave_df <- load_wave_data(file_path, info$wave_id, categorical_cols)

      # Apply weighting
      if (!is.null(info$weight_var) && info$weight_var != "") {
        wave_df <- apply_wave_weights(wave_df, info$weight_var, info$wave_id)
      } else {
        wave_df$weight_var <- 1
      }

      list(
        wave_id = info$wave_id,
        wave_name = info$wave_name,
        data = wave_df,
        n_records = nrow(wave_df)
      )
    }, future.seed = TRUE)

    # Collect results into wave_data list
    wave_data <- list()
    for (result in wave_results) {
      wave_data[[result$wave_id]] <- result$data
      cat(paste0("  Loaded Wave ", result$wave_id, ": ", result$wave_name,
                 " (", result$n_records, " records)\n"))
    }

  } else {
    # ---------------------------------------------------------------------------
    # SEQUENTIAL LOADING (default)
    # ---------------------------------------------------------------------------
    wave_data <- list()

    for (i in 1:n_waves) {
      wave_id <- config$waves$WaveID[i]
      wave_name <- config$waves$WaveName[i]
      data_file <- config$waves$DataFile[i]

      cat(paste0("  Loading Wave ", wave_id, ": ", wave_name, "\n"))

      # Resolve file path
      file_path <- resolve_data_file_path(data_file, data_dir)

      # Load wave data (passing categorical question codes to preserve)
      wave_df <- load_wave_data(file_path, wave_id, categorical_cols)

      # Apply weighting if specified
      weight_var <- get_wave_weight_var(config, wave_id)
      if (!is.null(weight_var) && weight_var != "") {
        wave_df <- apply_wave_weights(wave_df, weight_var, wave_id)
      } else {
        cat("    No weighting variable specified for this wave\n")
        # Create default weight of 1
        wave_df$weight_var <- 1
      }

      # Store in list
      wave_data[[wave_id]] <- wave_df

      cat(paste0("    Loaded ", nrow(wave_df), " records\n"))
    }
  }

  cat(paste0("Successfully loaded ", length(wave_data), " waves\n"))

  return(wave_data)
}


#' Clean Wave Data
#'
#' Cleans wave data to handle common data quality issues:
#' - Comma decimal separators (7,5 -> 7.5)
#' - DK/Don't Know/Prefer not to say -> NA
#' - Other non-response codes -> NA
#'
#' Categorical questions (Single_Response, Multi_Mention) are preserved as text.
#' Numeric questions (Rating, Likert, NPS) are converted to numeric.
#'
#' @param wave_df Data frame. Wave data
#' @param wave_id Character. Wave identifier for messages
#' @param categorical_cols Character vector. Question codes to preserve as categorical/text (optional)
#' @return Cleaned data frame
#'
#' @keywords internal
clean_wave_data <- function(wave_df, wave_id, categorical_cols = character(0)) {

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

    # Check if column might be numeric (has digits) OR looks like a question code
    if (is.character(col_data)) {
      # Check if this column is a categorical question - if so, skip numeric conversion
      # For Multi_Mention sub-columns (Q10_1, Q10_2, etc.), extract base code (Q10)
      base_code <- sub("_[0-9]+$", "", col_name)
      is_categorical <- (col_name %in% categorical_cols) || (base_code %in% categorical_cols)

      if (is_categorical) {
        # Skip categorical questions - preserve text values for Single_Response, Multi_Mention, etc.
        next
      }

      # Only clean columns that look like question codes (Q## pattern)
      # This prevents over-eager cleaning of ID columns or other numeric fields
      # that aren't survey responses
      is_question_col <- grepl("^Q[0-9]+(_[0-9]+)?$", col_name)

      if (is_question_col) {
        original_col <- col_data

        # Replace comma decimals with period decimals
        col_data <- gsub(",", ".", col_data, fixed = TRUE)

        # Replace non-response codes with NA (use which() to avoid NA issues)
        for (code in non_response_codes) {
          # Only check non-NA values to avoid toupper() warnings
          non_na_idx <- which(!is.na(col_data))
          if (length(non_na_idx) > 0) {
            match_idx <- non_na_idx[trimws(toupper(col_data[non_na_idx])) == toupper(code)]
            if (length(match_idx) > 0) {
              col_data[match_idx] <- NA
            }
          }
        }

        # Try converting to numeric
        col_numeric <- suppressWarnings(as.numeric(col_data))

        # If conversion created NAs where there weren't any, report it
        new_nas <- sum(is.na(col_numeric)) - sum(is.na(original_col))
        if (new_nas > 0) {
          n_cleaned <- n_cleaned + 1
          if (is_question_col && new_nas == length(original_col[!is.na(original_col)])) {
            # All non-NA values were converted to NA - this is a problem
            cat(paste0("    WARNING: ", col_name, ": All ", new_nas, " values are non-numeric (converted to NA). Check data source.\n"))
          } else {
            cat(paste0("    ", col_name, ": Converted ", new_nas, " non-numeric values to NA\n"))
          }
        }

        # For question columns, use the numeric version even if all values are NA
        # This ensures consistent data types for question responses
        if (is_question_col || sum(!is.na(col_numeric)) > 0) {
          wave_df[[col_name]] <- col_numeric
        }
      }
    }
  }

  if (n_cleaned > 0) {
    cat(paste0("    Cleaned ", n_cleaned, " column(s) with comma decimals or DK values\n"))
  }

  return(wave_df)
}


#' Load Single Wave Data File
#'
#' Loads a single wave data file, detecting format (CSV or Excel).
#'
#' @param file_path Character. Full path to data file
#' @param wave_id Character. Wave identifier for error messages
#' @param categorical_cols Character vector. Question codes to preserve as categorical/text (optional)
#' @return Data frame containing wave data
#'
#' @keywords internal
load_wave_data <- function(file_path, wave_id, categorical_cols = character(0)) {

  if (!file.exists(file_path)) {
    # TRS Refusal: IO_WAVE_DATA_NOT_FOUND
    tracker_refuse(
      code = "IO_WAVE_DATA_NOT_FOUND",
      title = "Wave Data File Not Found",
      problem = paste0("Cannot find data file for Wave ", wave_id),
      why_it_matters = "Cannot analyze trends without wave data.",
      how_to_fix = c(
        "Check that the DataFile path in config is correct",
        "Verify the file exists at the specified location"
      ),
      details = paste0("Expected path: ", file_path)
    )
  }

  # Detect file format from extension
  file_ext <- tolower(tools::file_ext(file_path))

  if (file_ext == "csv") {
    # Load CSV file
    wave_df <- tryCatch({
      read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    }, error = function(e) {
      # TRS Refusal: IO_CSV_READ_FAILED
      tracker_refuse(
        code = "IO_CSV_READ_FAILED",
        title = "Failed to Read CSV File",
        problem = paste0("Error reading CSV file for Wave ", wave_id),
        why_it_matters = "Cannot load wave data without successfully reading the file.",
        how_to_fix = c(
          "Check that the CSV file is valid",
          "Verify the file is not corrupted or open in another application"
        ),
        details = e$message
      )
    })

  } else if (file_ext %in% c("xlsx", "xls")) {
    # Load Excel file (assume first sheet unless specified)
    wave_df <- tryCatch({
      openxlsx::read.xlsx(file_path, sheet = 1, check.names = FALSE)
    }, error = function(e) {
      # TRS Refusal: IO_EXCEL_READ_FAILED
      tracker_refuse(
        code = "IO_EXCEL_READ_FAILED",
        title = "Failed to Read Excel File",
        problem = paste0("Error reading Excel file for Wave ", wave_id),
        why_it_matters = "Cannot load wave data without successfully reading the file.",
        how_to_fix = c(
          "Check that the Excel file is valid",
          "Verify the file is not corrupted or open in another application"
        ),
        details = e$message
      )
    })

  } else {
    # TRS Refusal: IO_UNSUPPORTED_FORMAT
    tracker_refuse(
      code = "IO_UNSUPPORTED_FORMAT",
      title = "Unsupported File Format",
      problem = paste0("File format '", file_ext, "' is not supported for Wave ", wave_id),
      why_it_matters = "Only CSV and Excel files can be loaded.",
      how_to_fix = "Convert the data file to CSV (.csv) or Excel (.xlsx/.xls) format.",
      details = paste0("File path: ", file_path)
    )
  }

  # Basic validation
  if (nrow(wave_df) == 0) {
    # TRS Refusal: DATA_EMPTY_WAVE
    tracker_refuse(
      code = "DATA_EMPTY_WAVE",
      title = "Empty Wave Data",
      problem = paste0("Data file for Wave ", wave_id, " contains no rows."),
      why_it_matters = "Cannot analyze an empty data file.",
      how_to_fix = c(
        "Verify the correct data file was specified",
        "Check that the file contains survey responses"
      ),
      details = paste0("File path: ", file_path)
    )
  }

  # Clean data (handle comma decimals, DK values, etc.)
  # Categorical questions are preserved as text (not converted to numeric)
  wave_df <- clean_wave_data(wave_df, wave_id, categorical_cols)

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
    cat(paste0("    Weight efficiency: ", round(eff_n, 1), " (out of ", length(valid_weights), " records)\n"))
  }

  return(wave_df)
}


# NOTE: calculate_weight_efficiency() is now provided by
# /modules/shared/lib/weights_utils.R (sourced at top of this file)


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

  cat("Validating wave data structure...\n")

  # Check all waves loaded
  expected_waves <- config$waves$WaveID
  loaded_waves <- names(wave_data)

  missing_waves <- setdiff(expected_waves, loaded_waves)
  if (length(missing_waves) > 0) {
    # TRS Refusal: DATA_MISSING_WAVES
    tracker_refuse(
      code = "DATA_MISSING_WAVES",
      title = "Missing Wave Data",
      problem = paste0(length(missing_waves), " wave(s) failed to load."),
      why_it_matters = "All waves must be loaded for complete trend analysis.",
      how_to_fix = c(
        "Check that all wave data files exist",
        "Verify file paths in configuration are correct"
      ),
      expected = expected_waves,
      missing = missing_waves
    )
  }

  # Validate each wave
  for (wave_id in expected_waves) {
    wave_df <- wave_data[[wave_id]]

    # Check weight_var exists
    if (!"weight_var" %in% names(wave_df)) {
      # TRS Refusal: BUG_WEIGHT_VAR_MISSING
      tracker_refuse(
        code = "BUG_WEIGHT_VAR_MISSING",
        title = "Weight Variable Not Created",
        problem = paste0("Wave ", wave_id, ": weight_var column was not created."),
        why_it_matters = "Weight variable is required for weighted calculations.",
        how_to_fix = c(
          "This is an internal error - please report it",
          "Check that weight configuration is correct"
        )
      )
    }

    # Check for tracked question variables
    # Get question codes for this wave from mapping
    # FIXED: Use the wave_id directly instead of constructing "Wave" + index
    # This fixes the "condition has length > 1" error and supports flexible wave naming
    wave_col <- wave_id

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

  cat("  Wave data validation completed\n")

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
