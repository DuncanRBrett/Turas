# ==============================================================================
# TurasTracker - Validation Module
# ==============================================================================
#
# Comprehensive validation for tracking analysis.
# Performs checks on configuration, data, and mapping before analysis begins.
#
# SHARED CODE NOTES:
# - Some validation patterns similar to TurasTabs validation.R
# - Future: Extract common validation utilities to /shared/validation_utils.R
#   (e.g., check_required_columns, validate_date_ranges)
#
# ==============================================================================

#' Run Complete Tracker Validation
#'
#' Orchestrates all validation checks for tracking analysis.
#' Returns detailed validation report and stops if critical errors found.
#'
#' @param config List. Configuration object
#' @param question_mapping Data frame. Question mapping
#' @param question_map List. Question map index
#' @param wave_data List. Loaded wave data
#' @return List containing validation results and warnings
#'
#' @export
validate_tracker_setup <- function(config, question_mapping, question_map, wave_data) {

  cat("========================================\n")
  cat("RUNNING TRACKER VALIDATION\n")
  cat("========================================\n")

  validation_results <- list(
    errors = character(0),
    warnings = character(0),
    info = character(0)
  )

  # 1. Validate configuration structure
  cat("\n1. Validating configuration structure...\n")
  config_validation <- validate_config_structure(config)
  validation_results <- merge_validation_results(validation_results, config_validation)

  # 2. Validate wave definitions
  cat("\n2. Validating wave definitions...\n")
  wave_validation <- validate_wave_definitions(config)
  validation_results <- merge_validation_results(validation_results, wave_validation)

  # 3. Validate question mapping
  cat("\n3. Validating question mapping...\n")
  mapping_validation <- validate_mapping_structure(question_mapping, config)
  validation_results <- merge_validation_results(validation_results, mapping_validation)

  # 4. Validate data availability
  cat("\n4. Validating data availability...\n")
  data_validation <- validate_data_availability(config, question_map, wave_data)
  validation_results <- merge_validation_results(validation_results, data_validation)

  # 5. Validate trackable questions
  cat("\n5. Validating trackable questions...\n")
  trackable_validation <- validate_trackable_questions(config, question_map, wave_data)
  validation_results <- merge_validation_results(validation_results, trackable_validation)

  # 6. Validate banner structure
  cat("\n6. Validating banner structure...\n")
  banner_validation <- validate_banner_structure(config, wave_data)
  validation_results <- merge_validation_results(validation_results, banner_validation)

  # 7. Validate TrackingSpecs (Enhancement Phase 1)
  cat("\n7. Validating TrackingSpecs...\n")
  specs_validation <- validate_all_tracking_specs(config, question_map)
  validation_results <- merge_validation_results(validation_results, specs_validation)

  # Print summary
  cat("\n========================================\n")
  cat("VALIDATION SUMMARY\n")
  cat("========================================\n")
  cat(paste0("Errors: ", length(validation_results$errors), "\n"))
  cat(paste0("Warnings: ", length(validation_results$warnings), "\n"))
  cat(paste0("Info: ", length(validation_results$info), "\n"))

  # Print errors
  if (length(validation_results$errors) > 0) {
    cat("\nERRORS:\n")
    for (err in validation_results$errors) {
      cat(paste0("  ✗ ", err, "\n"))
    }
  }

  # Print warnings
  if (length(validation_results$warnings) > 0) {
    cat("\nWARNINGS:\n")
    for (warn in validation_results$warnings) {
      cat(paste0("  ⚠ ", warn, "\n"))
    }
  }

  # Stop if errors found
  if (length(validation_results$errors) > 0) {
    stop("Validation failed with errors. Please fix the issues above and try again.")
  }

  cat("\n✓ Validation passed\n")
  cat("========================================\n")

  return(validation_results)
}


#' Validate Configuration Structure
#'
#' @keywords internal
validate_config_structure <- function(config) {
  results <- list(errors = character(0), warnings = character(0), info = character(0))

  # Check required components exist
  required_components <- c("waves", "settings", "banner", "tracked_questions")
  for (comp in required_components) {
    if (!comp %in% names(config)) {
      results$errors <- c(results$errors, paste0("Missing required config component: ", comp))
    }
  }

  # Check required settings
  required_settings <- c("project_name")
  for (setting in required_settings) {
    if (!setting %in% names(config$settings)) {
      results$warnings <- c(results$warnings, paste0("Missing setting '", setting, "' (will use default)"))
    }
  }

  # Validate decimal places
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)
  if (!is.numeric(decimal_places) || decimal_places < 0 || decimal_places > 3) {
    results$errors <- c(results$errors, "decimal_places_ratings must be between 0 and 3")
  }

  return(results)
}


#' Validate Wave Definitions
#'
#' @keywords internal
validate_wave_definitions <- function(config) {
  results <- list(errors = character(0), warnings = character(0), info = character(0))

  waves <- config$waves

  # Check minimum waves
  if (nrow(waves) < 2) {
    results$errors <- c(results$errors, "At least 2 waves required for tracking analysis")
  }

  # Check for duplicates
  if (any(duplicated(waves$WaveID))) {
    results$errors <- c(results$errors, "Duplicate WaveIDs found")
  }

  if (any(duplicated(waves$WaveName))) {
    results$warnings <- c(results$warnings, "Duplicate WaveNames found")
  }

  # Validate dates
  for (i in 1:nrow(waves)) {
    start_date <- waves$FieldworkStart[i]
    end_date <- waves$FieldworkEnd[i]

    if (!is.na(start_date) && !is.na(end_date)) {
      if (end_date < start_date) {
        results$errors <- c(results$errors,
                           paste0("Wave ", waves$WaveID[i], ": FieldworkEnd before FieldworkStart"))
      }
    }
  }

  # Check chronological order
  if (all(!is.na(waves$FieldworkStart))) {
    if (any(diff(waves$FieldworkStart) < 0)) {
      results$warnings <- c(results$warnings, "Waves not in chronological order")
    }
  }

  results$info <- c(results$info, paste0("Tracking ", nrow(waves), " waves"))

  return(results)
}


#' Validate Question Mapping Structure
#'
#' @keywords internal
validate_mapping_structure <- function(question_mapping, config) {
  results <- list(errors = character(0), warnings = character(0), info = character(0))

  # Check required columns
  required_cols <- c("QuestionCode", "QuestionText", "QuestionType")
  missing_cols <- setdiff(required_cols, names(question_mapping))
  if (length(missing_cols) > 0) {
    results$errors <- c(results$errors,
                       paste0("Missing columns in question mapping: ", paste(missing_cols, collapse = ", ")))
  }

  # Check for wave columns - use flexible detection to support any wave naming
  # (W1, W2, W3 or Wave1, Wave2, Wave3 or custom names)
  known_metadata_cols <- c("QuestionCode", "QuestionText", "QuestionType", "SourceQuestions", "TrackingSpecs")
  potential_wave_cols <- setdiff(names(question_mapping), known_metadata_cols)

  wave_cols <- character(0)
  for (col in potential_wave_cols) {
    # Count non-empty values - if > 50% of rows have data, it's likely a wave column
    non_empty_count <- sum(!is.na(question_mapping[[col]]) & trimws(as.character(question_mapping[[col]])) != "")
    if (non_empty_count > nrow(question_mapping) * 0.5) {
      wave_cols <- c(wave_cols, col)
    }
  }

  if (length(wave_cols) == 0) {
    results$errors <- c(results$errors, "No wave columns found in question mapping")
  } else {
    # Check wave columns match wave count
    n_config_waves <- nrow(config$waves)
    if (length(wave_cols) != n_config_waves) {
      results$warnings <- c(results$warnings,
                           paste0("Number of wave columns (", length(wave_cols),
                                 ") doesn't match config waves (", n_config_waves, ")"))
    }
  }

  # Check for duplicate question codes
  if (any(duplicated(question_mapping$QuestionCode))) {
    results$errors <- c(results$errors, "Duplicate QuestionCodes in mapping")
  }

  # Validate question types
  valid_types <- c("Rating", "SingleChoice", "MultiChoice", "Multi_Mention", "NPS", "Index", "OpenEnd", "Composite")
  invalid_types <- setdiff(unique(question_mapping$QuestionType), valid_types)
  if (length(invalid_types) > 0) {
    results$warnings <- c(results$warnings,
                         paste0("Unknown question types: ", paste(invalid_types, collapse = ", ")))
  }

  results$info <- c(results$info, paste0("Mapped ", nrow(question_mapping), " questions"))

  return(results)
}


#' Validate Data Availability
#'
#' @keywords internal
validate_data_availability <- function(config, question_map, wave_data) {
  results <- list(errors = character(0), warnings = character(0), info = character(0))

  wave_ids <- config$waves$WaveID

  # Check all waves loaded
  for (wave_id in wave_ids) {
    if (!wave_id %in% names(wave_data)) {
      results$errors <- c(results$errors, paste0("Wave ", wave_id, " data not loaded"))
    } else {
      wave_df <- wave_data[[wave_id]]

      # Check weight_var exists
      if (!"weight_var" %in% names(wave_df)) {
        results$errors <- c(results$errors, paste0("Wave ", wave_id, ": weight_var not found"))
      }

      # Check for valid weights
      if ("weight_var" %in% names(wave_df)) {
        n_valid <- sum(!is.na(wave_df$weight_var) & wave_df$weight_var > 0)
        if (n_valid == 0) {
          results$errors <- c(results$errors, paste0("Wave ", wave_id, ": no valid weights"))
        } else {
          results$info <- c(results$info,
                           paste0("Wave ", wave_id, ": ", nrow(wave_df), " records, ",
                                 n_valid, " valid weights"))
        }
      }
    }
  }

  return(results)
}


#' Validate Trackable Questions
#'
#' @keywords internal
validate_trackable_questions <- function(config, question_map, wave_data) {
  results <- list(errors = character(0), warnings = character(0), info = character(0))

  tracked_questions <- config$tracked_questions$QuestionCode
  wave_ids <- config$waves$WaveID

  if (length(tracked_questions) == 0) {
    results$errors <- c(results$errors, "No tracked questions specified")
    return(results)
  }

  # Check each tracked question
  for (q_code in tracked_questions) {
    # Check if question exists in mapping
    if (!q_code %in% names(question_map$standard_to_wave)) {
      results$warnings <- c(results$warnings,
                           paste0("Tracked question '", q_code, "' not found in question mapping"))
      next
    }

    # Get question metadata to check if it's a composite
    q_metadata <- get_question_metadata(question_map, q_code)
    is_composite <- !is.null(q_metadata) && !is.na(q_metadata$QuestionType) &&
                    q_metadata$QuestionType == "Composite"
    is_multi_mention <- !is.null(q_metadata) && !is.na(q_metadata$QuestionType) &&
                       q_metadata$QuestionType == "Multi_Mention"

    # Skip data existence check for composites (they're calculated, not in raw data)
    if (is_composite) {
      next
    }

    # Check availability in each wave (for non-composite questions)
    missing_waves <- character(0)
    for (wave_id in wave_ids) {
      wave_code <- get_wave_question_code(question_map, q_code, wave_id)
      if (is.na(wave_code)) {
        missing_waves <- c(missing_waves, wave_id)
      } else {
        # Check if exists in data
        if (wave_id %in% names(wave_data)) {
          # For Multi_Mention, check for pattern columns (Q10_1, Q10_2, etc.)
          if (is_multi_mention) {
            wave_code_escaped <- gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", wave_code)
            pattern <- paste0("^", wave_code_escaped, "_[0-9]+$")
            matched_cols <- grep(pattern, names(wave_data[[wave_id]]), value = TRUE)
            if (length(matched_cols) == 0) {
              missing_waves <- c(missing_waves, paste0(wave_id, "(data)"))
            }
          } else {
            # For other question types, check exact column name
            if (!wave_code %in% names(wave_data[[wave_id]])) {
              missing_waves <- c(missing_waves, paste0(wave_id, "(data)"))
            }
          }
        }
      }
    }

    if (length(missing_waves) > 0) {
      results$warnings <- c(results$warnings,
                           paste0("Question '", q_code, "' missing in: ",
                                 paste(missing_waves, collapse = ", ")))
    }
  }

  # Count questions available across all waves
  all_wave_questions <- get_questions_across_all_waves(question_map, wave_ids)
  tracked_and_available <- intersect(tracked_questions, all_wave_questions)

  results$info <- c(results$info,
                   paste0(length(tracked_and_available), " of ", length(tracked_questions),
                         " tracked questions available across all waves"))

  if (length(tracked_and_available) == 0) {
    results$errors <- c(results$errors, "No tracked questions available across all waves")
  }

  return(results)
}


#' Validate Banner Structure
#'
#' @keywords internal
validate_banner_structure <- function(config, wave_data) {
  results <- list(errors = character(0), warnings = character(0), info = character(0))

  banner <- config$banner

  if (nrow(banner) == 0) {
    results$errors <- c(results$errors, "Banner structure is empty")
    return(results)
  }

  # Check for Total
  if (!"Total" %in% banner$BreakVariable &&
      !any(grepl("(?i)total", banner$BreakLabel))) {
    results$warnings <- c(results$warnings, "No 'Total' column defined in banner")
  }

  # Validate break variables exist in data
  wave_ids <- names(wave_data)
  if (length(wave_ids) > 0) {
    # Check first wave (assume consistent structure)
    wave_df <- wave_data[[wave_ids[1]]]

    for (i in 1:nrow(banner)) {
      break_var <- banner$BreakVariable[i]

      # Skip "Total"
      if (tolower(break_var) == "total") {
        next
      }

      # Check if variable exists
      if (!break_var %in% names(wave_df)) {
        results$warnings <- c(results$warnings,
                             paste0("Banner variable '", break_var, "' not found in Wave ",
                                   wave_ids[1], " data"))
      }
    }
  }

  results$info <- c(results$info, paste0("Banner has ", nrow(banner), " breakouts"))

  return(results)
}


#' Merge Validation Results
#'
#' @keywords internal
merge_validation_results <- function(results1, results2) {
  return(list(
    errors = c(results1$errors, results2$errors),
    warnings = c(results1$warnings, results2$warnings),
    info = c(results1$info, results2$info)
  ))
}


# ==============================================================================
# TRACKINGSPECS VALIDATION (Enhancement Phase 1)
# ==============================================================================

#' Validate All TrackingSpecs
#'
#' Validates TrackingSpecs for all tracked questions.
#' Checks syntax, compatibility with question types, and existence of referenced options.
#'
#' @param config List. Configuration object
#' @param question_map List. Question map index
#' @return List with errors, warnings, and info
#'
#' @keywords internal
validate_all_tracking_specs <- function(config, question_map) {
  results <- list(errors = character(0), warnings = character(0), info = character(0))

  # Check if TrackingSpecs column exists
  has_tracking_specs <- "TrackingSpecs" %in% names(question_map$question_metadata)

  if (!has_tracking_specs) {
    results$info <- c(results$info, "No TrackingSpecs column found (using defaults for all questions)")
    return(results)
  }

  tracked_questions <- config$tracked_questions$QuestionCode
  n_with_specs <- 0

  for (q_code in tracked_questions) {
    # Get metadata
    metadata <- get_question_metadata(question_map, q_code)

    if (is.null(metadata)) {
      next  # Already validated in trackable_questions check
    }

    # Get TrackingSpecs
    tracking_specs <- get_tracking_specs(question_map, q_code)

    if (is.null(tracking_specs)) {
      next  # No specs = use defaults (valid)
    }

    n_with_specs <- n_with_specs + 1

    # Validate specs syntax
    validation <- validate_tracking_specs(tracking_specs, metadata$QuestionType)

    if (!validation$valid) {
      results$errors <- c(results$errors,
                         paste0("Question '", q_code, "': ", validation$message))
    } else {
      # Additional contextual validation can go here
      # For example, checking if specified categories exist in data
      results$info <- c(results$info,
                       paste0("Question '", q_code, "': TrackingSpecs validated (", tracking_specs, ")"))
    }
  }

  if (n_with_specs > 0) {
    results$info <- c(results$info,
                     paste0(n_with_specs, " questions have custom TrackingSpecs"))
  }

  return(results)
}
