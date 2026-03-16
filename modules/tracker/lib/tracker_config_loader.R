# ==============================================================================
# TurasTracker - Configuration Loader
# ==============================================================================
#
# Loads and validates tracking configuration files:
#   - tracking_config.xlsx (Waves, Settings, Banner, TrackedQuestions)
#   - question_mapping.xlsx (QuestionMap sheet)
#
# VERSION: 2.0.0 - Phase 3 Update
#
# PHASE 3 UPDATE:
# Shared config utilities NOW AVAILABLE in shared/config_utils.R:
# - read_config_sheet() - Read Excel sheets with error handling
# - parse_settings_to_list() - Convert settings to named list
# - get_setting() - Retrieve settings with defaults
# - validate_required_columns() - Column validation
# - check_duplicates() - Uniqueness validation
#
# This module continues to use its current implementation for backward
# compatibility. New code should use shared/config_utils.R functions.
# ==============================================================================

#' Read Config Sheet (handles styled templates)
#'
#' Reads an Excel sheet, auto-detecting styled template header rows.
#' Styled templates have title/subtitle/legend rows above the actual
#' column headers. This function finds the real header row by looking
#' for a known column name in column 1.
#'
#' @param file_path Character. Path to Excel file.
#' @param sheet_name Character. Sheet name to read.
#' @param expected_col Character. A column name expected in column 1 of the header row.
#' @param ... Additional arguments passed to openxlsx::read.xlsx()
#' @return Data frame with correct column names.
#'
#' @keywords internal
read_config_sheet <- function(file_path, sheet_name, expected_col, ...) {
  df <- openxlsx::read.xlsx(file_path, sheet = sheet_name, ...)
  if (!(expected_col %in% names(df))) {
    # Styled template: scan column 1 for the expected header row
    # Use skipEmptyRows=FALSE so raw row numbers match Excel row numbers
    raw_df <- openxlsx::read.xlsx(file_path, sheet = sheet_name,
                                  colNames = FALSE, skipEmptyRows = FALSE)
    header_row <- which(raw_df[[1]] == expected_col)[1]
    if (!is.na(header_row)) {
      df <- openxlsx::read.xlsx(file_path, sheet = sheet_name,
                                startRow = header_row, ...)
      # Strip help/description rows (start with [REQUIRED] or [Optional])
      if (nrow(df) > 0 && expected_col %in% names(df)) {
        help_rows <- grepl("^\\[REQUIRED\\]|^\\[Optional\\]", df[[expected_col]])
        if (any(help_rows)) {
          df <- df[!help_rows, , drop = FALSE]
          rownames(df) <- NULL
        }
      }
    }
  }
  df
}


#' Load Tracking Configuration
#'
#' Loads the main tracking configuration file (tracking_config.xlsx) and
#' returns a structured configuration object.
#'
#' @param config_path Character. Path to tracking_config.xlsx file.
#' @return List containing:
#'   - waves: Data frame of wave definitions
#'   - settings: Named list of configuration settings
#'   - banner: Data frame of banner structure
#'   - tracked_questions: Data frame of questions to track
#'   - config_path: Original config file path
#'
#' @export
load_tracking_config <- function(config_path) {

  # Validate file exists
  if (!file.exists(config_path)) {
    # TRS Refusal: IO_CONFIG_FILE_NOT_FOUND
    tracker_refuse(
      code = "IO_CONFIG_FILE_NOT_FOUND",
      title = "Tracking Configuration File Not Found",
      problem = paste0("Cannot find configuration file: ", basename(config_path)),
      why_it_matters = "Tracker analysis requires configuration to define waves and settings.",
      how_to_fix = c(
        "Check that the config file path is correct",
        "Verify the file exists at the specified location"
      ),
      details = paste0("Expected path: ", config_path)
    )
  }

  cat("Loading tracking configuration from: ", basename(config_path), "\n")

  # SHARED CODE NOTE: This sheet reading pattern is identical to TurasTabs
  # Future: Extract to shared/config_utils.R::read_config_sheet()

  # Load Waves sheet
  waves <- tryCatch({
    read_config_sheet(config_path, "Waves", "WaveID", detectDates = TRUE)
  }, error = function(e) {
    # TRS Refusal: IO_WAVES_SHEET_FAILED
    tracker_refuse(
      code = "IO_WAVES_SHEET_FAILED",
      title = "Failed to Load Waves Sheet",
      problem = "Could not read the Waves sheet from configuration file.",
      why_it_matters = "Wave definitions are required to identify data sources for tracking.",
      how_to_fix = c(
        "Verify the config file has a 'Waves' sheet",
        "Check the file is not corrupted or open in another application"
      ),
      details = e$message
    )
  })

  # Coerce date columns to Date objects (handles multiple input formats)
  for (date_col in c("FieldworkStart", "FieldworkEnd")) {
    if (date_col %in% names(waves)) {
      vals <- waves[[date_col]]
      if (is.numeric(vals)) {
        # Numeric YYYYMMDD format (e.g. 20250916)
        waves[[date_col]] <- as.Date(as.character(as.integer(vals)), format = "%Y%m%d")
      } else if (is.character(vals)) {
        # Try YYYY-MM-DD first, then YYYYMMDD
        parsed <- as.Date(vals, format = "%Y-%m-%d")
        still_na <- is.na(parsed) & !is.na(vals)
        if (any(still_na)) {
          parsed[still_na] <- as.Date(vals[still_na], format = "%Y%m%d")
        }
        waves[[date_col]] <- parsed
      }
    }
  }

  # Validate date ranges
  if ("FieldworkStart" %in% names(waves) && "FieldworkEnd" %in% names(waves)) {
    for (i in seq_len(nrow(waves))) {
      if (!is.na(waves$FieldworkStart[i]) && !is.na(waves$FieldworkEnd[i])) {
        if (waves$FieldworkStart[i] > waves$FieldworkEnd[i]) {
          cat(sprintf("\n[TURAS WARNING] Wave '%s': FieldworkStart (%s) is after FieldworkEnd (%s). Dates may be swapped.\n",
              waves$WaveID[i], waves$FieldworkStart[i], waves$FieldworkEnd[i]))
        }
      }
    }
  }

  # Validate required columns in Waves
  required_wave_cols <- c("WaveID", "WaveName", "DataFile", "FieldworkStart", "FieldworkEnd")
  missing_cols <- setdiff(required_wave_cols, names(waves))
  if (length(missing_cols) > 0) {
    # TRS Refusal: CFG_MISSING_WAVE_COLUMNS
    tracker_refuse(
      code = "CFG_MISSING_WAVE_COLUMNS",
      title = "Missing Columns in Waves Sheet",
      problem = "The Waves sheet is missing required columns.",
      why_it_matters = "All columns are required to properly define each wave of data.",
      how_to_fix = c(
        "Add the missing columns to the Waves sheet",
        "Required: WaveID, WaveName, DataFile, FieldworkStart, FieldworkEnd"
      ),
      expected = required_wave_cols,
      observed = names(waves),
      missing = missing_cols
    )
  }

  # Load Settings sheet (handles both plain and styled template formats)
  settings_df <- tryCatch({
    df <- read_config_sheet(config_path, "Settings", "Setting")
    # Also handle legacy "SettingName" column
    if (!("Setting" %in% names(df)) && !("SettingName" %in% names(df))) {
      df <- read_config_sheet(config_path, "Settings", "SettingName")
    }
    df
  }, error = function(e) {
    # TRS Refusal: IO_SETTINGS_SHEET_FAILED
    tracker_refuse(
      code = "IO_SETTINGS_SHEET_FAILED",
      title = "Failed to Load Settings Sheet",
      problem = "Could not read the Settings sheet from configuration file.",
      why_it_matters = "Settings define analysis parameters like significance testing and decimal places.",
      how_to_fix = c(
        "Verify the config file has a 'Settings' sheet",
        "Check the file format is correct"
      ),
      details = e$message
    )
  })

  # SHARED CODE NOTE: Settings parsing is identical to TurasTabs
  # Future: Extract to shared/config_utils.R::parse_settings()

  # Convert settings dataframe to named list
  # Known settings: project_name, question_mapping_file, output_file, output_dir,
  # report_types, html_report, decimal_places_*, alpha, confidence_level,
  # minimum_base, show_significance, baseline_wave, weight_variable,
  # brand_colour, accent_colour, company_name, researcher_logo_path, etc.
  settings <- parse_settings_to_list(settings_df)

  # Load Banner sheet
  banner <- tryCatch({
    read_config_sheet(config_path, "Banner", "BreakVariable")
  }, error = function(e) {
    # TRS Refusal: IO_BANNER_SHEET_FAILED
    tracker_refuse(
      code = "IO_BANNER_SHEET_FAILED",
      title = "Failed to Load Banner Sheet",
      problem = "Could not read the Banner sheet from configuration file.",
      why_it_matters = "Banner defines segment breakouts for trend analysis.",
      how_to_fix = c(
        "Verify the config file has a 'Banner' sheet",
        "Check the file format is correct"
      ),
      details = e$message
    )
  })

  # Validate banner structure
  required_banner_cols <- c("BreakVariable", "BreakLabel")
  missing_banner_cols <- setdiff(required_banner_cols, names(banner))
  if (length(missing_banner_cols) > 0) {
    # TRS Refusal: CFG_MISSING_BANNER_COLUMNS
    tracker_refuse(
      code = "CFG_MISSING_BANNER_COLUMNS",
      title = "Missing Columns in Banner Sheet",
      problem = "The Banner sheet is missing required columns.",
      why_it_matters = "Banner columns are required to define segment breakouts.",
      how_to_fix = c(
        "Add the missing columns to the Banner sheet",
        "Required: BreakVariable, BreakLabel"
      ),
      expected = required_banner_cols,
      missing = missing_banner_cols
    )
  }

  # Check for duplicate Banner entries
  if (!is.null(banner) && nrow(banner) > 0) {
    banner_key <- paste(banner$BreakVariable, banner$BreakLabel, sep = "||")
    dupe_banners <- banner_key[duplicated(banner_key)]
    if (length(dupe_banners) > 0) {
      cat("\n[TURAS WARNING] Duplicate Banner entries detected: ", paste(unique(dupe_banners), collapse = ", "), "\n")
    }
  }

  # Load TrackedQuestions sheet
  tracked_questions <- tryCatch({
    read_config_sheet(config_path, "TrackedQuestions", "QuestionCode")
  }, error = function(e) {
    # TRS Refusal: IO_TRACKED_QUESTIONS_FAILED
    tracker_refuse(
      code = "IO_TRACKED_QUESTIONS_FAILED",
      title = "Failed to Load TrackedQuestions Sheet",
      problem = "Could not read the TrackedQuestions sheet from configuration file.",
      why_it_matters = "TrackedQuestions defines which metrics to analyze across waves.",
      how_to_fix = c(
        "Verify the config file has a 'TrackedQuestions' sheet",
        "Check the file format is correct"
      ),
      details = e$message
    )
  })

  # Validate tracked questions
  if (!"QuestionCode" %in% names(tracked_questions)) {
    # TRS Refusal: CFG_MISSING_QUESTION_CODE_COLUMN
    tracker_refuse(
      code = "CFG_MISSING_QUESTION_CODE_COLUMN",
      title = "Missing QuestionCode Column",
      problem = "The TrackedQuestions sheet is missing the QuestionCode column.",
      why_it_matters = "QuestionCode is required to identify questions for tracking.",
      how_to_fix = "Add a QuestionCode column to the TrackedQuestions sheet.",
      observed = names(tracked_questions)
    )
  }

  # Check for duplicate QuestionCodes
  dupe_codes <- tracked_questions$QuestionCode[duplicated(tracked_questions$QuestionCode)]
  if (length(dupe_codes) > 0) {
    return(tracker_refuse(
      code = "CFG_DUPLICATE_QUESTION_CODES",
      title = "Duplicate Question Codes in TrackedQuestions",
      problem = sprintf("The following QuestionCode values appear more than once: %s", paste(unique(dupe_codes), collapse = ", ")),
      why_it_matters = "Each QuestionCode must be unique to avoid ambiguous metric mapping.",
      how_to_fix = "Remove or rename duplicate QuestionCode entries in the TrackedQuestions sheet."
    ))
  }

  # Add defaults for optional TrackedQuestions columns
  # TrackingSpecs: analysis-level metric specification (moved from question_mapping)
  if (!"TrackingSpecs" %in% names(tracked_questions)) {
    tracked_questions$TrackingSpecs <- NA_character_
  }
  # MetricLabel: custom display label override
  if (!"MetricLabel" %in% names(tracked_questions)) {
    tracked_questions$MetricLabel <- NA_character_
  }
  # Section: grouping label for report sections (e.g., "Brand Health")
  if (!"Section" %in% names(tracked_questions)) {
    tracked_questions$Section <- NA_character_
  }
  # SortOrder: display ordering within section (defaults to row order)
  if (!"SortOrder" %in% names(tracked_questions)) {
    tracked_questions$SortOrder <- seq_len(nrow(tracked_questions))
  } else {
    # Warn if non-numeric values found
    if ("SortOrder" %in% names(tracked_questions)) {
      non_numeric <- !grepl("^[0-9]+$", as.character(tracked_questions$SortOrder))
      if (any(non_numeric, na.rm = TRUE)) {
        cat("[TURAS WARNING] SortOrder contains non-numeric values; using row order for those entries.\n")
      }
    }
    # Convert to numeric, defaulting to row order for non-numeric values
    tracked_questions$SortOrder <- suppressWarnings(as.numeric(tracked_questions$SortOrder))
    na_rows <- is.na(tracked_questions$SortOrder)
    if (any(na_rows)) {
      tracked_questions$SortOrder[na_rows] <- which(na_rows)
    }
  }

  # Validate TrackingSpecs values
  if ("TrackingSpecs" %in% names(tracked_questions)) {
    valid_spec_types <- c("mean", "nps", "top_box", "top2_box", "top3_box",
                          "bottom_box", "bottom2_box", "bottom3_box",
                          "pct_agree", "pct_disagree", "pct_response",
                          "net_score", "proportion", "composite")
    specs_to_check <- tracked_questions$TrackingSpecs[!is.na(tracked_questions$TrackingSpecs) &
                                                       trimws(tracked_questions$TrackingSpecs) != ""]
    if (length(specs_to_check) > 0) {
      # Parse each spec: extract base type (before any parenthesized arguments)
      spec_base_types <- gsub("\\(.*$", "", trimws(specs_to_check))
      invalid_specs <- spec_base_types[!spec_base_types %in% valid_spec_types]
      if (length(invalid_specs) > 0) {
        cat(sprintf("[TURAS WARNING] Unrecognized TrackingSpecs values: %s. Valid types: %s\n",
            paste(unique(invalid_specs), collapse = ", "),
            paste(valid_spec_types, collapse = ", ")))
      }
    }
  }

  # Default blank MetricLabel to QuestionCode
  if ("MetricLabel" %in% names(tracked_questions)) {
    na_labels <- is.na(tracked_questions$MetricLabel) | tracked_questions$MetricLabel == ""
    if (any(na_labels)) {
      tracked_questions$MetricLabel[na_labels] <- tracked_questions$QuestionCode[na_labels]
      cat(sprintf("[TURAS INFO] %d metrics with blank MetricLabel defaulted to QuestionCode.\n", sum(na_labels)))
    }
  }

  cat(paste0("  Loaded ", nrow(waves), " waves\n"))
  cat(paste0("  Loaded ", nrow(tracked_questions), " tracked questions\n"))
  cat(paste0("  Loaded ", nrow(banner), " banner breakouts\n"))

  # Build configuration object
  config <- list(
    waves = waves,
    settings = settings,
    banner = banner,
    tracked_questions = tracked_questions,
    config_path = config_path
  )

  return(config)
}


#' Load Question Mapping Configuration
#'
#' Loads the question mapping file that maps question codes across waves.
#' This handles scenarios where Q10 in Wave1 becomes Q11 in Wave2, etc.
#'
#' @param mapping_path Character. Path to question_mapping.xlsx file.
#' @return Data frame with columns:
#'   - QuestionCode: Standardized question code
#'   - Wave columns (e.g., W1, W2, W3 or Wave1, Wave2, Wave3): Wave-specific question codes
#'   - QuestionText: Question wording
#'   - QuestionType: Type of question (Rating, SingleChoice, etc.)
#'
#' @export
load_question_mapping <- function(mapping_path) {

  # Validate file exists
  if (!file.exists(mapping_path)) {
    # TRS Refusal: IO_MAPPING_FILE_NOT_FOUND
    tracker_refuse(
      code = "IO_MAPPING_FILE_NOT_FOUND",
      title = "Question Mapping File Not Found",
      problem = paste0("Cannot find question mapping file: ", basename(mapping_path)),
      why_it_matters = "Question mapping defines how questions correspond across waves.",
      how_to_fix = c(
        "Check that the mapping file path is correct",
        "Verify the file exists at the specified location"
      ),
      details = paste0("Expected path: ", mapping_path)
    )
  }

  cat("Loading question mapping from: ", basename(mapping_path), "\n")

  # Load QuestionMap sheet
  mapping <- tryCatch({
    read_config_sheet(mapping_path, "QuestionMap", "QuestionCode")
  }, error = function(e) {
    # TRS Refusal: IO_QUESTIONMAP_SHEET_FAILED
    tracker_refuse(
      code = "IO_QUESTIONMAP_SHEET_FAILED",
      title = "Failed to Load QuestionMap Sheet",
      problem = "Could not read the QuestionMap sheet from mapping file.",
      why_it_matters = "Question mapping is required to track questions across waves.",
      how_to_fix = c(
        "Verify the mapping file has a 'QuestionMap' sheet",
        "Check the file format is correct"
      ),
      details = e$message
    )
  })

  # Validate required columns
  required_cols <- c("QuestionCode", "QuestionText", "QuestionType")
  missing_cols <- setdiff(required_cols, names(mapping))
  if (length(missing_cols) > 0) {
    # TRS Refusal: CFG_MISSING_MAPPING_COLUMNS
    tracker_refuse(
      code = "CFG_MISSING_MAPPING_COLUMNS",
      title = "Missing Columns in QuestionMap Sheet",
      problem = "The QuestionMap sheet is missing required columns.",
      why_it_matters = "These columns are required to properly define question mappings.",
      how_to_fix = c(
        "Add the missing columns to the QuestionMap sheet",
        "Required: QuestionCode, QuestionText, QuestionType"
      ),
      expected = required_cols,
      observed = names(mapping),
      missing = missing_cols
    )
  }

  # Find wave columns
  # FIXED: More flexible wave column detection to support W1, W2, W3 or Wave1, Wave2, Wave3
  # Exclude known metadata columns to identify wave columns
  known_metadata_cols <- c("QuestionCode", "QuestionText", "QuestionType", "SourceQuestions", "TrackingSpecs")
  potential_wave_cols <- setdiff(names(mapping), known_metadata_cols)

  # Further filter: wave columns should have mostly non-NA values (question codes)
  wave_cols <- character(0)
  for (col in potential_wave_cols) {
    # If more than 50% of values are non-NA and non-empty, consider it a wave column
    non_empty_count <- sum(!is.na(mapping[[col]]) & trimws(as.character(mapping[[col]])) != "")
    if (non_empty_count > nrow(mapping) * 0.5) {
      wave_cols <- c(wave_cols, col)
    }
  }

  if (length(wave_cols) == 0) {
    # TRS Refusal: CFG_NO_WAVE_COLUMNS
    tracker_refuse(
      code = "CFG_NO_WAVE_COLUMNS",
      title = "No Wave Columns Found",
      problem = "No wave columns found in QuestionMap sheet.",
      why_it_matters = "Wave columns are required to map questions across data waves.",
      how_to_fix = c(
        "Add wave columns (e.g., W1, W2, W3 or Wave1, Wave2, Wave3)",
        "Each wave column should contain the question code for that wave"
      ),
      observed = names(mapping)
    )
  }

  cat(paste0("  Loaded mapping for ", nrow(mapping), " questions across ", length(wave_cols), " waves\n"))

  return(mapping)
}


#' Parse Settings Dataframe to Named List
#'
#' Converts a settings dataframe (Setting, Value columns) to a named list.
#' Handles type conversion for common setting types.
#'
#' SHARED CODE NOTE: This is identical to TurasTabs settings parsing
#' Future: Extract to shared/config_utils.R::parse_settings()
#'
#' @param settings_df Data frame with 'Setting' and 'Value' columns
#' @return Named list of settings
#'
#' @keywords internal
parse_settings_to_list <- function(settings_df) {

  # Accept either "Setting" or "SettingName" for backward compatibility
  setting_col <- if ("Setting" %in% names(settings_df)) {
    "Setting"
  } else if ("SettingName" %in% names(settings_df)) {
    "SettingName"
  } else {
    # TRS Refusal: CFG_INVALID_SETTINGS_FORMAT
    tracker_refuse(
      code = "CFG_INVALID_SETTINGS_FORMAT",
      title = "Invalid Settings Sheet Format",
      problem = "Settings sheet must have 'Setting' (or 'SettingName') and 'Value' columns.",
      why_it_matters = "Settings cannot be parsed without proper column structure.",
      how_to_fix = "Add 'Setting' and 'Value' columns to the Settings sheet.",
      observed = names(settings_df)
    )
  }

  if (!"Value" %in% names(settings_df)) {
    # TRS Refusal: CFG_MISSING_VALUE_COLUMN
    tracker_refuse(
      code = "CFG_MISSING_VALUE_COLUMN",
      title = "Missing Value Column in Settings",
      problem = "Settings sheet is missing the 'Value' column.",
      why_it_matters = "Settings cannot be parsed without values.",
      how_to_fix = "Add a 'Value' column to the Settings sheet.",
      observed = names(settings_df)
    )
  }

  # Create named list
  settings <- as.list(settings_df$Value)
  names(settings) <- settings_df[[setting_col]]

  # Convert Y/N to logical
  for (name in names(settings)) {
    val <- settings[[name]]
    if (!is.na(val) && toupper(val) %in% c("Y", "N")) {
      settings[[name]] <- toupper(val) == "Y"
    }
  }

  # Convert numeric strings to numbers where appropriate
  for (name in names(settings)) {
    val <- settings[[name]]
    if (!is.na(val) && grepl("^[0-9.]+$", val)) {
      num_val <- suppressWarnings(as.numeric(val))
      if (!is.na(num_val)) {
        settings[[name]] <- num_val
      }
    }
  }

  return(settings)
}


#' Validate Tracking Configuration
#'
#' Performs comprehensive validation of loaded tracking configuration.
#' Checks for logical consistency, required settings, and valid references.
#'
#' @param config List. Configuration object from load_tracking_config()
#' @param question_mapping Data frame. Question mapping from load_question_mapping()
#' @return Invisible TRUE if validation passes, stops with error otherwise
#'
#' @export
validate_tracking_config <- function(config, question_mapping) {

  cat("Validating tracking configuration...\n")

  # Validate wave IDs are unique
  if (any(duplicated(config$waves$WaveID))) {
    # TRS Refusal: CFG_DUPLICATE_WAVE_IDS
    tracker_refuse(
      code = "CFG_DUPLICATE_WAVE_IDS",
      title = "Duplicate Wave IDs Found",
      problem = "The Waves sheet contains duplicate WaveID values.",
      why_it_matters = "Each wave must have a unique identifier.",
      how_to_fix = "Ensure all WaveID values in the Waves sheet are unique.",
      details = paste0("Duplicated: ", paste(config$waves$WaveID[duplicated(config$waves$WaveID)], collapse = ", "))
    )
  }

  # Validate data files exist (if absolute paths provided)
  for (i in seq_len(nrow(config$waves))) {
    data_file <- config$waves$DataFile[i]
    # Only validate if absolute path provided (relative paths resolved later)
    if (file.exists(dirname(data_file)) && !file.exists(data_file)) {
      cat("[WARNING]", paste0("Data file not found for Wave ", config$waves$WaveID[i], ": ", data_file), "\n")
    }
  }

  # Validate fieldwork dates (only check rows where both dates exist)
  valid_date_rows <- !is.na(config$waves$FieldworkStart) & !is.na(config$waves$FieldworkEnd)
  if (any(valid_date_rows)) {
    if (!all(config$waves$FieldworkEnd[valid_date_rows] >= config$waves$FieldworkStart[valid_date_rows])) {
      # TRS Refusal: CFG_INVALID_FIELDWORK_DATES
      tracker_refuse(
        code = "CFG_INVALID_FIELDWORK_DATES",
        title = "Invalid Fieldwork Date Range",
        problem = "FieldworkEnd is before FieldworkStart for one or more waves.",
        why_it_matters = "Invalid date ranges will cause incorrect wave ordering.",
        how_to_fix = "Ensure FieldworkEnd >= FieldworkStart for all waves."
      )
    }
  }

  # Validate tracked questions exist in mapping
  if (!is.null(question_mapping)) {
    unmapped_questions <- setdiff(
      config$tracked_questions$QuestionCode,
      question_mapping$QuestionCode
    )
    if (length(unmapped_questions) > 0) {
      cat("[WARNING]", paste0(
        "Tracked questions not found in question mapping: ",
        paste(unmapped_questions, collapse = ", ")
      ), "\n")
    }
  }

  # Validate required settings exist
  required_settings <- c("project_name", "decimal_places_ratings", "show_significance")
  missing_settings <- setdiff(required_settings, names(config$settings))
  if (length(missing_settings) > 0) {
    cat("[WARNING]", paste0(
      "Missing recommended settings (defaults will be used): ",
      paste(missing_settings, collapse = ", ")
    ), "\n")
  }

  # Validate banner structure
  if (nrow(config$banner) == 0) {
    # TRS Refusal: CFG_EMPTY_BANNER
    tracker_refuse(
      code = "CFG_EMPTY_BANNER",
      title = "Empty Banner Sheet",
      problem = "The Banner sheet is empty.",
      why_it_matters = "At least a Total banner break must be defined for analysis.",
      how_to_fix = "Add at least one row to the Banner sheet (typically 'Total')."
    )
  }

  # Check for "Total" in banner
  if (!"Total" %in% config$banner$BreakVariable &&
      !any(grepl("(?i)total", config$banner$BreakLabel))) {
    cat("[WARNING] No 'Total' found in banner structure\n")
  }

  cat("  Configuration validation passed\n")

  invisible(TRUE)
}


#' Get Setting Value with Default
#'
#' Safely retrieves a setting value with a default fallback.
#'
#' SHARED CODE NOTE: Identical pattern to TurasTabs
#' Future: Extract to shared/config_utils.R::get_setting()
#'
#' @param config List. Configuration object
#' @param setting_name Character. Name of setting to retrieve
#' @param default Default value if setting not found
#' @return Setting value or default
#'
#' @export
get_setting <- function(config, setting_name, default = NULL) {
  if (is.null(config) || is.null(config$settings)) return(default)
  if (setting_name %in% names(config$settings)) {
    val <- config$settings[[setting_name]]
    # Treat NA or empty string as "not set" — return default
    if (is.null(val) || (length(val) == 1 && is.na(val))) {
      return(default)
    }
    if (is.character(val) && length(val) == 1 && trimws(val) == "") {
      return(default)
    }
    return(val)
  } else {
    return(default)
  }
}


#' Get Baseline Wave ID
#'
#' Returns the baseline wave for "vs Baseline" comparisons in tracking reports.
#' Uses the `baseline_wave` setting if specified, otherwise defaults to the
#' first wave in the Waves sheet.
#'
#' @param config List. Configuration object from load_tracking_config()
#' @return Character. WaveID of the baseline wave
#'
#' @export
get_baseline_wave <- function(config) {
  baseline <- get_setting(config, "baseline_wave", default = NULL)
  if (is.null(baseline) || is.na(baseline) || trimws(as.character(baseline)) == "") {
    return(config$waves$WaveID[1])
  }
  baseline <- trimws(as.character(baseline))

  # If exact match found, use it
  if (baseline %in% config$waves$WaveID) {
    return(baseline)
  }

  # Try auto-correcting: prepend "W" if not already present
  if (!grepl("^W", baseline)) {
    candidate <- paste0("W", baseline)
    if (candidate %in% config$waves$WaveID) {
      cat("  NOTE: baseline_wave '", baseline, "' auto-corrected to '", candidate, "'\n", sep = "")
      return(candidate)
    }
  }

  # No match found — return as-is (will be caught by guard/validator)
  return(baseline)
}
