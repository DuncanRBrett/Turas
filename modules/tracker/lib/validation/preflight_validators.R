# ==============================================================================
# PREFLIGHT VALIDATORS - TURAS Tracker Module
# ==============================================================================
# Cross-referential validation between config, waves, mapping, and data files.
# Catches configuration mistakes before the tracking analysis pipeline begins.
#
# VERSION HISTORY:
# V1.0 - Initial creation (2026-03-08)
#        - 15 cross-referential checks
#        - Standalone log_preflight_issue helper
#        - validate_tracker_preflight() orchestrator
#
# USAGE:
#   source("modules/tracker/lib/validation/preflight_validators.R")
#   error_log <- validate_tracker_preflight(config, waves_df, tracked_df,
#                                           mapping_df, wave_data_list,
#                                           banner_df, error_log)
#
# FUNCTIONS EXPORTED:
#   - log_preflight_issue()             - Error log helper
#   - check_wave_files_exist()          - DataFile paths exist
#   - check_wave_ids_unique()           - No duplicate WaveIDs
#   - check_wave_dates_valid()          - Date logic and chronology
#   - check_tracked_questions_in_mapping() - TrackedQuestions in QuestionMap
#   - check_question_columns_in_data()  - Mapped columns exist in wave data
#   - check_tracking_specs_valid()      - TrackingSpecs syntax validation
#   - check_banner_variables_in_data()  - Banner variables in wave data
#   - check_banner_category_sizes()     - Banner categories meet minimum base
#   - check_baseline_wave_valid()       - baseline_wave matches a WaveID
#   - check_weight_variable_in_waves()  - Weight variable in wave data
#   - check_minimum_wave_count()        - At least 2 waves defined
#   - check_nps_question_range()        - NPS questions have 0-10 scale
#   - check_rating_question_numeric()   - Rating questions have numeric data
#   - check_structure_file_refs()       - StructureFile/ConfigFile paths valid
#   - check_logo_and_colours()          - Logo path valid, hex colours valid
#   - validate_tracker_preflight()      - Main orchestrator
# ==============================================================================


# ==============================================================================
# HELPER: Log a pre-flight issue to the error log data frame
# ==============================================================================

#' Log a pre-flight validation issue
#'
#' Appends a row to the error log data frame. The caller MUST capture
#' the returned data frame (the original is not modified in place).
#'
#' @param error_log Data frame with columns: Timestamp, Component, Issue_Type,
#'   Description, QuestionCode, Severity
#' @param issue_type Character, short label for the issue category
#' @param description Character, human-readable description of the problem
#' @param question_code Character, related code or identifier (default "")
#' @param severity Character, one of "Error", "Warning", "Info" (default "Warning")
#' @return Data frame with the new entry appended
#' @keywords internal
log_preflight_issue <- function(error_log, issue_type, description,
                                question_code = "", severity = "Warning") {
  new_entry <- data.frame(
    Timestamp = as.character(Sys.time()),
    Component = "Preflight",
    Issue_Type = issue_type,
    Description = description,
    QuestionCode = question_code,
    Severity = severity,
    stringsAsFactors = FALSE
  )
  rbind(error_log, new_entry)
}


# ==============================================================================
# CHECK 1: Wave data files exist
# ==============================================================================

#' Check Wave Files Exist
#'
#' Verifies that every DataFile path in the Waves sheet resolves to an
#' existing file. Paths are resolved relative to the config file directory.
#'
#' @param waves_df Data frame from the Waves sheet
#' @param config_dir Character, directory containing the config file
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_wave_files_exist <- function(waves_df, config_dir, error_log) {
  if (is.null(waves_df) || nrow(waves_df) == 0) return(error_log)
  if (!"DataFile" %in% names(waves_df)) return(error_log)

  for (i in seq_len(nrow(waves_df))) {
    data_file <- trimws(as.character(waves_df$DataFile[i]))
    if (is.na(data_file) || data_file == "") next

    wave_id <- if ("WaveID" %in% names(waves_df)) waves_df$WaveID[i] else paste0("Row ", i)

    # Resolve path: if absolute, use as-is; otherwise relative to config_dir
    resolved_path <- if (grepl("^(/|[A-Za-z]:)", data_file)) {
      data_file
    } else {
      file.path(config_dir, data_file)
    }

    if (!file.exists(resolved_path)) {
      error_log <- log_preflight_issue(
        error_log, "Missing Wave Data File",
        sprintf("Wave '%s': DataFile not found at '%s' (resolved to '%s'). Ensure the file exists and the path is correct.",
                wave_id, data_file, normalizePath(resolved_path, mustWork = FALSE)),
        wave_id, "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 2: Wave IDs are unique
# ==============================================================================

#' Check Wave IDs Unique
#'
#' Verifies no duplicate WaveID values exist in the Waves sheet.
#'
#' @param waves_df Data frame from the Waves sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_wave_ids_unique <- function(waves_df, error_log) {
  if (is.null(waves_df) || nrow(waves_df) == 0) return(error_log)
  if (!"WaveID" %in% names(waves_df)) return(error_log)

  wave_ids <- waves_df$WaveID[!is.na(waves_df$WaveID) & trimws(waves_df$WaveID) != ""]
  dup_ids <- wave_ids[duplicated(wave_ids)]

  if (length(dup_ids) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Duplicate WaveIDs",
      sprintf("Waves sheet contains duplicate WaveID(s): %s. Each wave must have a unique identifier.",
              paste(unique(dup_ids), collapse = ", ")),
      paste(unique(dup_ids), collapse = ", "),
      "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 3: Wave dates are valid and chronological
# ==============================================================================

#' Check Wave Dates Valid
#'
#' Verifies that FieldworkStart <= FieldworkEnd for each wave where both
#' are provided, and that waves are in chronological order.
#'
#' @param waves_df Data frame from the Waves sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_wave_dates_valid <- function(waves_df, error_log) {
  if (is.null(waves_df) || nrow(waves_df) == 0) return(error_log)

  has_start <- "FieldworkStart" %in% names(waves_df)
  has_end <- "FieldworkEnd" %in% names(waves_df)
  if (!has_start && !has_end) return(error_log)

  parsed_starts <- c()

  for (i in seq_len(nrow(waves_df))) {
    wave_id <- if ("WaveID" %in% names(waves_df)) waves_df$WaveID[i] else paste0("Row ", i)

    start_val <- if (has_start) trimws(as.character(waves_df$FieldworkStart[i])) else NA
    end_val <- if (has_end) trimws(as.character(waves_df$FieldworkEnd[i])) else NA

    start_date <- suppressWarnings(as.Date(start_val))
    end_date <- suppressWarnings(as.Date(end_val))

    # Check parseable dates
    if (!is.na(start_val) && start_val != "" && is.na(start_date)) {
      error_log <- log_preflight_issue(
        error_log, "Invalid Date Format",
        sprintf("Wave '%s': FieldworkStart '%s' is not a valid date. Use YYYY-MM-DD format.",
                wave_id, start_val),
        wave_id, "Warning"
      )
    }

    if (!is.na(end_val) && end_val != "" && is.na(end_date)) {
      error_log <- log_preflight_issue(
        error_log, "Invalid Date Format",
        sprintf("Wave '%s': FieldworkEnd '%s' is not a valid date. Use YYYY-MM-DD format.",
                wave_id, end_val),
        wave_id, "Warning"
      )
    }

    # Check start <= end
    if (!is.na(start_date) && !is.na(end_date) && start_date > end_date) {
      error_log <- log_preflight_issue(
        error_log, "Date Range Invalid",
        sprintf("Wave '%s': FieldworkStart (%s) is after FieldworkEnd (%s).",
                wave_id, start_val, end_val),
        wave_id, "Error"
      )
    }

    # Collect start dates for chronological check
    if (!is.na(start_date)) {
      parsed_starts <- c(parsed_starts, as.numeric(start_date))
    }
  }

  # Check chronological order
  if (length(parsed_starts) >= 2) {
    for (j in 2:length(parsed_starts)) {
      if (parsed_starts[j] < parsed_starts[j - 1]) {
        error_log <- log_preflight_issue(
          error_log, "Waves Not Chronological",
          "Waves are not in chronological order by FieldworkStart. Reorder the Waves sheet so earlier waves appear first.",
          "", "Warning"
        )
        break
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 4: Tracked questions exist in question mapping
# ==============================================================================

#' Check Tracked Questions in Mapping
#'
#' Verifies that every QuestionCode in the TrackedQuestions sheet exists in
#' the QuestionMap sheet.
#'
#' @param tracked_df Data frame from the TrackedQuestions sheet
#' @param mapping_df Data frame from the QuestionMap sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_tracked_questions_in_mapping <- function(tracked_df, mapping_df, error_log) {
  if (is.null(tracked_df) || nrow(tracked_df) == 0) return(error_log)
  if (is.null(mapping_df) || nrow(mapping_df) == 0) return(error_log)
  if (!"QuestionCode" %in% names(tracked_df)) return(error_log)
  if (!"QuestionCode" %in% names(mapping_df)) return(error_log)

  tracked_codes <- unique(tracked_df$QuestionCode[
    !is.na(tracked_df$QuestionCode) & trimws(tracked_df$QuestionCode) != ""
  ])
  mapping_codes <- unique(mapping_df$QuestionCode[
    !is.na(mapping_df$QuestionCode) & trimws(mapping_df$QuestionCode) != ""
  ])

  missing_in_mapping <- setdiff(tracked_codes, mapping_codes)
  if (length(missing_in_mapping) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Tracked Question Not Mapped",
      sprintf("%d tracked question(s) not found in QuestionMap: %s. Add these to the QuestionMap sheet or remove from TrackedQuestions.",
              length(missing_in_mapping),
              paste(missing_in_mapping, collapse = ", ")),
      paste(missing_in_mapping, collapse = ", "),
      "Error"
    )
  }

  # Info: mapping entries not in tracked questions
  not_tracked <- setdiff(mapping_codes, tracked_codes)
  if (length(not_tracked) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Mapped Question Not Tracked",
      sprintf("%d question(s) in QuestionMap but not in TrackedQuestions: %s. These will not be analysed. If intentional, ignore this message.",
              length(not_tracked),
              paste(not_tracked, collapse = ", ")),
      "", "Info"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 5: Question columns exist in wave data
# ==============================================================================

#' Check Question Columns in Data
#'
#' For each wave, verifies that the column names specified in the question
#' mapping actually exist in the corresponding wave data.
#'
#' @param mapping_df Data frame from the QuestionMap sheet
#' @param wave_data_list Named list of data frames, keyed by WaveID
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_question_columns_in_data <- function(mapping_df, wave_data_list, error_log) {
  if (is.null(mapping_df) || nrow(mapping_df) == 0) return(error_log)
  if (is.null(wave_data_list) || length(wave_data_list) == 0) return(error_log)

  wave_ids <- names(wave_data_list)

  for (wave_id in wave_ids) {
    if (!wave_id %in% names(mapping_df)) next

    wave_data <- wave_data_list[[wave_id]]
    if (is.null(wave_data) || !is.data.frame(wave_data)) next

    data_cols <- names(wave_data)
    missing_cols <- c()

    for (i in seq_len(nrow(mapping_df))) {
      q_code <- mapping_df$QuestionCode[i]
      col_name <- trimws(as.character(mapping_df[[wave_id]][i]))

      if (is.na(col_name) || col_name == "") next

      if (!col_name %in% data_cols) {
        missing_cols <- c(missing_cols, sprintf("%s->%s", q_code, col_name))
      }
    }

    if (length(missing_cols) > 0) {
      error_log <- log_preflight_issue(
        error_log, "Missing Data Columns",
        sprintf("Wave '%s': %d mapped column(s) not found in data: %s",
                wave_id, length(missing_cols),
                paste(utils::head(missing_cols, 10), collapse = ", ")),
        wave_id, "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 6: TrackingSpecs syntax validation
# ==============================================================================

#' Check Tracking Specs Valid
#'
#' Validates the syntax of TrackingSpecs entries in the TrackedQuestions sheet.
#' Ensures all keywords are recognised and parameterised specs have valid format.
#'
#' @param tracked_df Data frame from the TrackedQuestions sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_tracking_specs_valid <- function(tracked_df, error_log) {
  if (is.null(tracked_df) || nrow(tracked_df) == 0) return(error_log)
  if (!"TrackingSpecs" %in% names(tracked_df)) return(error_log)

  valid_keywords <- c(
    "mean", "top_box", "top2_box", "top3_box",
    "bottom_box", "bottom2_box",
    "distribution", "nps_score",
    "promoters_pct", "passives_pct", "detractors_pct",
    "full", "all", "top3", "auto", "any", "count_mean"
  )

  # Patterns for parameterised specs
  range_pattern <- "^range:[0-9]+-[0-9]+$"
  category_pattern <- "^category:.+$"
  option_pattern <- "^option:.+$"

  for (i in seq_len(nrow(tracked_df))) {
    specs_raw <- trimws(as.character(tracked_df$TrackingSpecs[i]))
    if (is.na(specs_raw) || specs_raw == "") next

    q_code <- if ("QuestionCode" %in% names(tracked_df)) {
      tracked_df$QuestionCode[i]
    } else {
      paste0("Row ", i)
    }

    # Split on comma
    tokens <- trimws(strsplit(specs_raw, ",")[[1]])
    invalid_tokens <- c()

    for (token in tokens) {
      if (token == "") next

      is_valid <- token %in% valid_keywords ||
        grepl(range_pattern, token, perl = TRUE) ||
        grepl(category_pattern, token, perl = TRUE) ||
        grepl(option_pattern, token, perl = TRUE)

      if (!is_valid) {
        invalid_tokens <- c(invalid_tokens, token)
      }

      # Validate range format (range:X-Y where X < Y)
      if (grepl("^range:", token)) {
        range_part <- sub("^range:", "", token)
        range_nums <- suppressWarnings(as.numeric(strsplit(range_part, "-")[[1]]))
        if (length(range_nums) != 2 || any(is.na(range_nums))) {
          invalid_tokens <- c(invalid_tokens, token)
        } else if (range_nums[1] >= range_nums[2]) {
          error_log <- log_preflight_issue(
            error_log, "Invalid Range Spec",
            sprintf("Question '%s': range spec '%s' has start >= end. Use range:LOW-HIGH format.",
                    q_code, token),
            q_code, "Warning"
          )
        }
      }
    }

    if (length(invalid_tokens) > 0) {
      error_log <- log_preflight_issue(
        error_log, "Invalid TrackingSpecs",
        sprintf("Question '%s': unrecognised TrackingSpecs token(s): %s. Valid keywords: %s. Parameterised: range:X-Y, category:VALUE, option:VALUE.",
                q_code,
                paste(invalid_tokens, collapse = ", "),
                paste(valid_keywords, collapse = ", ")),
        q_code, "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 7: Banner variables exist in wave data
# ==============================================================================

#' Check Banner Variables in Data
#'
#' Verifies that banner BreakVariable column names exist in the respective
#' wave data files.
#'
#' @param banner_df Data frame from the Banner sheet
#' @param wave_data_list Named list of data frames, keyed by WaveID
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_banner_variables_in_data <- function(banner_df, wave_data_list, error_log) {
  if (is.null(banner_df) || nrow(banner_df) == 0) return(error_log)
  if (is.null(wave_data_list) || length(wave_data_list) == 0) return(error_log)

  wave_ids <- names(wave_data_list)

  for (i in seq_len(nrow(banner_df))) {
    break_var <- trimws(as.character(banner_df$BreakVariable[i]))
    break_label <- if ("BreakLabel" %in% names(banner_df)) {
      trimws(as.character(banner_df$BreakLabel[i]))
    } else {
      break_var
    }

    if (is.na(break_var) || break_var == "") next

    # Skip "Total" - it is a virtual variable
    if (tolower(break_var) == "total") next

    for (wave_id in wave_ids) {
      # Check if there is a wave-specific column mapping
      wave_col_name <- break_var
      if (wave_id %in% names(banner_df)) {
        mapped_name <- trimws(as.character(banner_df[[wave_id]][i]))
        if (!is.na(mapped_name) && mapped_name != "") {
          # Skip "Total" mapping
          if (tolower(mapped_name) == "total") next
          wave_col_name <- mapped_name
        }
      }

      wave_data <- wave_data_list[[wave_id]]
      if (is.null(wave_data) || !is.data.frame(wave_data)) next

      if (!wave_col_name %in% names(wave_data)) {
        error_log <- log_preflight_issue(
          error_log, "Missing Banner Column",
          sprintf("Banner '%s' (%s): column '%s' not found in Wave '%s' data.",
                  break_label, break_var, wave_col_name, wave_id),
          wave_id, "Error"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 8: Banner category sizes meet minimum base
# ==============================================================================

#' Check Banner Category Sizes
#'
#' Warns if any banner category in any wave has fewer respondents than
#' the configured minimum_base threshold.
#'
#' @param banner_df Data frame from the Banner sheet
#' @param wave_data_list Named list of data frames, keyed by WaveID
#' @param minimum_base Integer, minimum sample size threshold
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_banner_category_sizes <- function(banner_df, wave_data_list, minimum_base,
                                        error_log) {
  if (is.null(banner_df) || nrow(banner_df) == 0) return(error_log)
  if (is.null(wave_data_list) || length(wave_data_list) == 0) return(error_log)
  if (is.null(minimum_base) || is.na(minimum_base)) minimum_base <- 30

  wave_ids <- names(wave_data_list)

  for (i in seq_len(nrow(banner_df))) {
    break_var <- trimws(as.character(banner_df$BreakVariable[i]))
    if (is.na(break_var) || break_var == "") next
    if (tolower(break_var) == "total") next

    break_label <- if ("BreakLabel" %in% names(banner_df)) {
      trimws(as.character(banner_df$BreakLabel[i]))
    } else {
      break_var
    }

    for (wave_id in wave_ids) {
      wave_col_name <- break_var
      if (wave_id %in% names(banner_df)) {
        mapped_name <- trimws(as.character(banner_df[[wave_id]][i]))
        if (!is.na(mapped_name) && mapped_name != "") {
          if (tolower(mapped_name) == "total") next
          wave_col_name <- mapped_name
        }
      }

      wave_data <- wave_data_list[[wave_id]]
      if (is.null(wave_data) || !is.data.frame(wave_data)) next
      if (!wave_col_name %in% names(wave_data)) next

      # Tabulate category sizes
      category_counts <- table(wave_data[[wave_col_name]], useNA = "no")
      small_cats <- category_counts[category_counts < minimum_base]

      if (length(small_cats) > 0) {
        small_labels <- paste(
          sprintf("%s (n=%d)", names(small_cats), as.integer(small_cats)),
          collapse = ", "
        )
        error_log <- log_preflight_issue(
          error_log, "Small Banner Category",
          sprintf("Banner '%s', Wave '%s': %d category(ies) below minimum base of %d: %s. Results for these categories may be suppressed.",
                  break_label, wave_id, length(small_cats), minimum_base, small_labels),
          wave_id, "Warning"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 9: Baseline wave is valid
# ==============================================================================

#' Check Baseline Wave Valid
#'
#' If baseline_wave is specified in config, verifies it matches a WaveID
#' in the Waves sheet.
#'
#' @param config List, configuration object (or named list with settings)
#' @param waves_df Data frame from the Waves sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_baseline_wave_valid <- function(config, waves_df, error_log) {
  # Extract baseline_wave from config (may be nested under settings)
  baseline_wave <- config$baseline_wave
  if (is.null(baseline_wave) && !is.null(config$settings)) {
    baseline_wave <- config$settings$baseline_wave
  }

  if (is.null(baseline_wave) || is.na(baseline_wave) || trimws(baseline_wave) == "") {
    return(error_log)
  }

  baseline_wave <- trimws(baseline_wave)

  if (is.null(waves_df) || nrow(waves_df) == 0 || !"WaveID" %in% names(waves_df)) {
    return(error_log)
  }

  valid_wave_ids <- waves_df$WaveID[!is.na(waves_df$WaveID) & trimws(waves_df$WaveID) != ""]

  if (!baseline_wave %in% valid_wave_ids) {
    error_log <- log_preflight_issue(
      error_log, "Invalid Baseline Wave",
      sprintf("baseline_wave '%s' does not match any WaveID in the Waves sheet. Valid WaveIDs: %s.",
              baseline_wave, paste(valid_wave_ids, collapse = ", ")),
      baseline_wave, "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 10: Weight variable exists in wave data
# ==============================================================================

#' Check Weight Variable in Waves
#'
#' Verifies that the weight variable (global or wave-specific) exists in
#' each wave's data and contains valid numeric values.
#'
#' @param config List, configuration object
#' @param waves_df Data frame from the Waves sheet
#' @param wave_data_list Named list of data frames, keyed by WaveID
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_weight_variable_in_waves <- function(config, waves_df, wave_data_list, error_log) {
  if (is.null(wave_data_list) || length(wave_data_list) == 0) return(error_log)

  # Global weight variable
  global_weight <- config$weight_variable
  if (is.null(global_weight) && !is.null(config$settings)) {
    global_weight <- config$settings$weight_variable
  }

  has_wave_weights <- !is.null(waves_df) && "WeightVar" %in% names(waves_df)

  for (wave_id in names(wave_data_list)) {
    # Determine the weight variable for this wave
    wave_weight <- NULL
    if (has_wave_weights) {
      wave_row <- waves_df[!is.na(waves_df$WaveID) & waves_df$WaveID == wave_id, ]
      if (nrow(wave_row) > 0) {
        wv <- trimws(as.character(wave_row$WeightVar[1]))
        if (!is.na(wv) && wv != "") {
          wave_weight <- wv
        }
      }
    }

    weight_var <- if (!is.null(wave_weight)) wave_weight else global_weight
    if (is.null(weight_var) || is.na(weight_var) || trimws(weight_var) == "") next

    weight_var <- trimws(weight_var)
    wave_data <- wave_data_list[[wave_id]]
    if (is.null(wave_data) || !is.data.frame(wave_data)) next

    if (!weight_var %in% names(wave_data)) {
      error_log <- log_preflight_issue(
        error_log, "Missing Weight Variable",
        sprintf("Wave '%s': weight variable '%s' not found in data columns.",
                wave_id, weight_var),
        wave_id, "Error"
      )
      next
    }

    # Check values are numeric and non-negative
    weights <- wave_data[[weight_var]]
    numeric_weights <- suppressWarnings(as.numeric(weights))
    n_invalid <- sum(is.na(numeric_weights) & !is.na(weights))

    if (n_invalid > 0) {
      error_log <- log_preflight_issue(
        error_log, "Non-Numeric Weights",
        sprintf("Wave '%s': weight variable '%s' has %d non-numeric value(s).",
                wave_id, weight_var, n_invalid),
        wave_id, "Error"
      )
    }

    valid_weights <- numeric_weights[!is.na(numeric_weights)]
    if (length(valid_weights) > 0 && any(valid_weights < 0)) {
      error_log <- log_preflight_issue(
        error_log, "Negative Weights",
        sprintf("Wave '%s': weight variable '%s' contains negative values.",
                wave_id, weight_var),
        wave_id, "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 11: Minimum wave count
# ==============================================================================

#' Check Minimum Wave Count
#'
#' Verifies at least 2 waves are defined (a tracking study requires
#' multiple measurement points).
#'
#' @param waves_df Data frame from the Waves sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_minimum_wave_count <- function(waves_df, error_log) {
  if (is.null(waves_df) || !is.data.frame(waves_df)) {
    error_log <- log_preflight_issue(
      error_log, "No Waves Defined",
      "No Waves sheet found or it is empty. A tracking study requires at least 2 waves.",
      "", "Error"
    )
    return(error_log)
  }

  # Count non-empty rows
  if ("WaveID" %in% names(waves_df)) {
    valid_rows <- sum(!is.na(waves_df$WaveID) & trimws(waves_df$WaveID) != "")
  } else {
    valid_rows <- nrow(waves_df)
  }

  if (valid_rows < 2) {
    error_log <- log_preflight_issue(
      error_log, "Insufficient Waves",
      sprintf("Only %d wave(s) defined. A tracking study requires at least 2 waves to analyse trends.",
              valid_rows),
      "", "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 12: NPS questions have 0-10 scale data
# ==============================================================================

#' Check NPS Question Range
#'
#' For questions with QuestionType = NPS, verifies that the actual data
#' values fall within the expected 0-10 scale.
#'
#' @param tracked_df Data frame from the TrackedQuestions sheet
#' @param mapping_df Data frame from the QuestionMap sheet
#' @param wave_data_list Named list of data frames, keyed by WaveID
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_nps_question_range <- function(tracked_df, mapping_df, wave_data_list,
                                     error_log) {
  if (is.null(tracked_df) || nrow(tracked_df) == 0) return(error_log)
  if (is.null(wave_data_list) || length(wave_data_list) == 0) return(error_log)
  if (!"QuestionType" %in% names(tracked_df)) return(error_log)

  nps_questions <- tracked_df[
    !is.na(tracked_df$QuestionType) &
    toupper(trimws(tracked_df$QuestionType)) == "NPS", ]

  if (nrow(nps_questions) == 0) return(error_log)

  wave_ids <- names(wave_data_list)

  for (i in seq_len(nrow(nps_questions))) {
    q_code <- nps_questions$QuestionCode[i]

    for (wave_id in wave_ids) {
      # Determine column name for this wave
      col_name <- q_code
      if (!is.null(mapping_df) && "QuestionCode" %in% names(mapping_df) &&
          wave_id %in% names(mapping_df)) {
        map_row <- mapping_df[!is.na(mapping_df$QuestionCode) &
                              mapping_df$QuestionCode == q_code, ]
        if (nrow(map_row) > 0) {
          mapped_col <- trimws(as.character(map_row[[wave_id]][1]))
          if (!is.na(mapped_col) && mapped_col != "") {
            col_name <- mapped_col
          }
        }
      }

      wave_data <- wave_data_list[[wave_id]]
      if (is.null(wave_data) || !is.data.frame(wave_data)) next
      if (!col_name %in% names(wave_data)) next

      vals <- suppressWarnings(as.numeric(wave_data[[col_name]]))
      vals <- vals[!is.na(vals)]
      if (length(vals) == 0) next

      out_of_range <- vals[vals < 0 | vals > 10]
      if (length(out_of_range) > 0) {
        pct_bad <- round(100 * length(out_of_range) / length(vals), 1)
        error_log <- log_preflight_issue(
          error_log, "NPS Range Violation",
          sprintf("NPS question '%s', Wave '%s': %.1f%% of values (%d) are outside the 0-10 range. NPS requires a 0-10 scale.",
                  q_code, wave_id, pct_bad, length(out_of_range)),
          q_code, "Error"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 13: Rating questions have numeric data
# ==============================================================================

#' Check Rating Question Numeric
#'
#' For questions with QuestionType = Rating, verifies that the data contains
#' numeric values suitable for mean calculation.
#'
#' @param tracked_df Data frame from the TrackedQuestions sheet
#' @param mapping_df Data frame from the QuestionMap sheet
#' @param wave_data_list Named list of data frames, keyed by WaveID
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_rating_question_numeric <- function(tracked_df, mapping_df, wave_data_list,
                                          error_log) {
  if (is.null(tracked_df) || nrow(tracked_df) == 0) return(error_log)
  if (is.null(wave_data_list) || length(wave_data_list) == 0) return(error_log)
  if (!"QuestionType" %in% names(tracked_df)) return(error_log)

  rating_questions <- tracked_df[
    !is.na(tracked_df$QuestionType) &
    toupper(trimws(tracked_df$QuestionType)) == "RATING", ]

  if (nrow(rating_questions) == 0) return(error_log)

  wave_ids <- names(wave_data_list)

  for (i in seq_len(nrow(rating_questions))) {
    q_code <- rating_questions$QuestionCode[i]

    for (wave_id in wave_ids) {
      # Determine column name for this wave
      col_name <- q_code
      if (!is.null(mapping_df) && "QuestionCode" %in% names(mapping_df) &&
          wave_id %in% names(mapping_df)) {
        map_row <- mapping_df[!is.na(mapping_df$QuestionCode) &
                              mapping_df$QuestionCode == q_code, ]
        if (nrow(map_row) > 0) {
          mapped_col <- trimws(as.character(map_row[[wave_id]][1]))
          if (!is.na(mapped_col) && mapped_col != "") {
            col_name <- mapped_col
          }
        }
      }

      wave_data <- wave_data_list[[wave_id]]
      if (is.null(wave_data) || !is.data.frame(wave_data)) next
      if (!col_name %in% names(wave_data)) next

      vals <- wave_data[[col_name]]
      vals_non_na <- vals[!is.na(vals)]
      if (length(vals_non_na) == 0) next

      numeric_vals <- suppressWarnings(as.numeric(vals_non_na))
      n_non_numeric <- sum(is.na(numeric_vals))
      pct_non_numeric <- round(100 * n_non_numeric / length(vals_non_na), 1)

      if (pct_non_numeric > 10) {
        error_log <- log_preflight_issue(
          error_log, "Non-Numeric Rating Data",
          sprintf("Rating question '%s', Wave '%s': %.1f%% of non-NA values are non-numeric. Rating questions require numeric data for mean calculation.",
                  q_code, wave_id, pct_non_numeric),
          q_code, "Warning"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 14: Structure and config file references valid
# ==============================================================================

#' Check Structure File References
#'
#' If StructureFile or ConfigFile columns are specified in the Waves sheet,
#' verifies those files exist.
#'
#' @param waves_df Data frame from the Waves sheet
#' @param config_dir Character, directory containing the config file
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_structure_file_refs <- function(waves_df, config_dir, error_log) {
  if (is.null(waves_df) || nrow(waves_df) == 0) return(error_log)

  ref_columns <- c("StructureFile", "ConfigFile")

  for (ref_col in ref_columns) {
    if (!ref_col %in% names(waves_df)) next

    for (i in seq_len(nrow(waves_df))) {
      ref_path <- trimws(as.character(waves_df[[ref_col]][i]))
      if (is.na(ref_path) || ref_path == "") next

      wave_id <- if ("WaveID" %in% names(waves_df)) waves_df$WaveID[i] else paste0("Row ", i)

      # Resolve path
      resolved_path <- if (grepl("^(/|[A-Za-z]:)", ref_path)) {
        ref_path
      } else {
        file.path(config_dir, ref_path)
      }

      if (!file.exists(resolved_path)) {
        error_log <- log_preflight_issue(
          error_log, sprintf("Missing %s", ref_col),
          sprintf("Wave '%s': %s not found at '%s' (resolved to '%s').",
                  wave_id, ref_col, ref_path,
                  normalizePath(resolved_path, mustWork = FALSE)),
          wave_id, "Warning"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 15: Logo path and colour codes
# ==============================================================================

#' Check Logo and Colours
#'
#' Validates that researcher_logo_path (if specified) points to an existing
#' file, and that brand_colour and accent_colour are valid hex colour codes.
#'
#' @param config List, configuration object
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_logo_and_colours <- function(config, error_log) {
  # Extract from config or config$settings
  get_setting <- function(name) {
    val <- config[[name]]
    if (is.null(val) && !is.null(config$settings)) {
      val <- config$settings[[name]]
    }
    val
  }

  # --- Logo path ---
  logo_path <- get_setting("researcher_logo_path")
  if (!is.null(logo_path) && !is.na(logo_path) && trimws(logo_path) != "") {
    logo_path <- trimws(logo_path)
    if (!file.exists(logo_path)) {
      error_log <- log_preflight_issue(
        error_log, "Logo File Not Found",
        sprintf("researcher_logo_path '%s' does not exist. Reports will render without a logo.",
                logo_path),
        "", "Warning"
      )
    }
  }

  # --- Hex colour validation ---
  hex_pattern <- "^#[0-9A-Fa-f]{6}$"

  colour_fields <- list(
    brand_colour = "Brand colour",
    accent_colour = "Accent colour"
  )

  for (field_name in names(colour_fields)) {
    val <- get_setting(field_name)
    if (!is.null(val) && !is.na(val) && trimws(val) != "") {
      val <- trimws(val)
      if (!grepl(hex_pattern, val)) {
        error_log <- log_preflight_issue(
          error_log, "Invalid Colour Code",
          sprintf("%s '%s' is not a valid hex colour code. Expected format: #RRGGBB (e.g., #323367).",
                  colour_fields[[field_name]], val),
          "", "Warning"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# PREFLIGHT ORCHESTRATOR
# ==============================================================================

#' Run Pre-Flight Validation for Tracker
#'
#' Orchestrates all 15 pre-flight checks against config, waves, tracked
#' questions, question mapping, and loaded wave data. Returns the updated
#' error log data frame.
#'
#' @param config List, tracker configuration object
#' @param waves_df Data frame from the Waves sheet
#' @param tracked_df Data frame from the TrackedQuestions sheet
#' @param mapping_df Data frame from the QuestionMap sheet
#' @param wave_data_list Named list of data frames keyed by WaveID
#' @param banner_df Data frame from the Banner sheet (NULL to skip banner checks)
#' @param error_log Data frame, error log (NULL to create a new one)
#' @param config_dir Character, directory containing the config file (defaults to ".")
#' @param verbose Logical, print progress messages (default TRUE)
#' @return Updated error_log data frame
#' @export
validate_tracker_preflight <- function(config, waves_df, tracked_df, mapping_df,
                                       wave_data_list, banner_df = NULL,
                                       error_log = NULL, config_dir = ".",
                                       verbose = TRUE) {

  # Initialise error log if not provided
  if (is.null(error_log)) {
    error_log <- data.frame(
      Timestamp = character(),
      Component = character(),
      Issue_Type = character(),
      Description = character(),
      QuestionCode = character(),
      Severity = character(),
      stringsAsFactors = FALSE
    )
  }

  if (verbose) {
    cat("\n  ========================================\n")
    cat("  TRACKER PRE-FLIGHT CHECKS\n")
    cat("  ========================================\n")
  }

  # Extract minimum_base from config
  minimum_base <- config$minimum_base
  if (is.null(minimum_base) && !is.null(config$settings)) {
    minimum_base <- config$settings$minimum_base
  }
  if (is.null(minimum_base) || is.na(minimum_base)) minimum_base <- 30

  n_before <- nrow(error_log)

  # --- Check 1: Wave data files exist ---
  if (verbose) cat("  [1/15] Checking wave data files...\n")
  error_log <- check_wave_files_exist(waves_df, config_dir, error_log)

  # --- Check 2: Wave IDs unique ---
  if (verbose) cat("  [2/15] Checking WaveID uniqueness...\n")
  error_log <- check_wave_ids_unique(waves_df, error_log)

  # --- Check 3: Wave dates valid ---
  if (verbose) cat("  [3/15] Checking wave date validity...\n")
  error_log <- check_wave_dates_valid(waves_df, error_log)

  # --- Check 4: Tracked questions in mapping ---
  if (verbose) cat("  [4/15] Checking tracked questions vs mapping...\n")
  error_log <- check_tracked_questions_in_mapping(tracked_df, mapping_df, error_log)

  # --- Check 5: Question columns in wave data ---
  if (verbose) cat("  [5/15] Checking mapped columns in wave data...\n")
  error_log <- check_question_columns_in_data(mapping_df, wave_data_list, error_log)

  # --- Check 6: TrackingSpecs syntax ---
  if (verbose) cat("  [6/15] Validating TrackingSpecs syntax...\n")
  error_log <- check_tracking_specs_valid(tracked_df, error_log)

  # --- Check 7: Banner variables in data ---
  if (!is.null(banner_df) && is.data.frame(banner_df) && nrow(banner_df) > 0) {
    if (verbose) cat("  [7/15] Checking banner variables in data...\n")
    error_log <- check_banner_variables_in_data(banner_df, wave_data_list, error_log)
  } else {
    if (verbose) cat("  [7/15] Skipping banner checks (no banner defined)\n")
  }

  # --- Check 8: Banner category sizes ---
  if (!is.null(banner_df) && is.data.frame(banner_df) && nrow(banner_df) > 0) {
    if (verbose) cat("  [8/15] Checking banner category sizes...\n")
    error_log <- check_banner_category_sizes(banner_df, wave_data_list, minimum_base, error_log)
  } else {
    if (verbose) cat("  [8/15] Skipping banner category checks (no banner defined)\n")
  }

  # --- Check 9: Baseline wave valid ---
  if (verbose) cat("  [9/15] Checking baseline wave...\n")
  error_log <- check_baseline_wave_valid(config, waves_df, error_log)

  # --- Check 10: Weight variable in waves ---
  if (verbose) cat("  [10/15] Checking weight variables...\n")
  error_log <- check_weight_variable_in_waves(config, waves_df, wave_data_list, error_log)

  # --- Check 11: Minimum wave count ---
  if (verbose) cat("  [11/15] Checking minimum wave count...\n")
  error_log <- check_minimum_wave_count(waves_df, error_log)

  # --- Check 12: NPS question range ---
  if (verbose) cat("  [12/15] Checking NPS question ranges...\n")
  error_log <- check_nps_question_range(tracked_df, mapping_df, wave_data_list, error_log)

  # --- Check 13: Rating question numeric ---
  if (verbose) cat("  [13/15] Checking rating question data types...\n")
  error_log <- check_rating_question_numeric(tracked_df, mapping_df, wave_data_list, error_log)

  # --- Check 14: Structure/config file references ---
  if (verbose) cat("  [14/15] Checking structure/config file references...\n")
  error_log <- check_structure_file_refs(waves_df, config_dir, error_log)

  # --- Check 15: Logo and colours ---
  if (verbose) cat("  [15/15] Checking logo and colour codes...\n")
  error_log <- check_logo_and_colours(config, error_log)

  # --- Summary ---
  n_new <- nrow(error_log) - n_before
  if (verbose) {
    cat("  ----------------------------------------\n")
    if (n_new == 0) {
      cat("  All 15 pre-flight checks passed\n")
    } else {
      n_errors <- sum(error_log$Severity[(n_before + 1):nrow(error_log)] == "Error")
      n_warnings <- sum(error_log$Severity[(n_before + 1):nrow(error_log)] == "Warning")
      n_info <- sum(error_log$Severity[(n_before + 1):nrow(error_log)] == "Info")
      cat(sprintf("  Pre-flight found %d issue(s): %d error(s), %d warning(s), %d info\n",
                  n_new, n_errors, n_warnings, n_info))
    }
    cat("  ========================================\n\n")
  }

  return(error_log)
}
