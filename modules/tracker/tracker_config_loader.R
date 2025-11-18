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
    stop(paste0("Configuration file not found: ", config_path))
  }

  message("Loading tracking configuration from: ", basename(config_path))

  # SHARED CODE NOTE: This sheet reading pattern is identical to TurasTabs
  # Future: Extract to shared/config_utils.R::read_config_sheet()

  # Load Waves sheet
  waves <- tryCatch({
    openxlsx::read.xlsx(config_path, sheet = "Waves", detectDates = TRUE)
  }, error = function(e) {
    stop(paste0("Error reading 'Waves' sheet: ", e$message))
  })

  # Validate required columns in Waves
  required_wave_cols <- c("WaveID", "WaveName", "DataFile", "FieldworkStart", "FieldworkEnd")
  missing_cols <- setdiff(required_wave_cols, names(waves))
  if (length(missing_cols) > 0) {
    stop(paste0("Missing required columns in Waves sheet: ", paste(missing_cols, collapse = ", ")))
  }

  # Load Settings sheet
  settings_df <- tryCatch({
    openxlsx::read.xlsx(config_path, sheet = "Settings")
  }, error = function(e) {
    stop(paste0("Error reading 'Settings' sheet: ", e$message))
  })

  # SHARED CODE NOTE: Settings parsing is identical to TurasTabs
  # Future: Extract to shared/config_utils.R::parse_settings()

  # Convert settings dataframe to named list
  settings <- parse_settings_to_list(settings_df)

  # Load Banner sheet
  banner <- tryCatch({
    openxlsx::read.xlsx(config_path, sheet = "Banner")
  }, error = function(e) {
    stop(paste0("Error reading 'Banner' sheet: ", e$message))
  })

  # Validate banner structure
  required_banner_cols <- c("BreakVariable", "BreakLabel")
  missing_banner_cols <- setdiff(required_banner_cols, names(banner))
  if (length(missing_banner_cols) > 0) {
    stop(paste0("Missing required columns in Banner sheet: ", paste(missing_banner_cols, collapse = ", ")))
  }

  # Load TrackedQuestions sheet
  tracked_questions <- tryCatch({
    openxlsx::read.xlsx(config_path, sheet = "TrackedQuestions")
  }, error = function(e) {
    stop(paste0("Error reading 'TrackedQuestions' sheet: ", e$message))
  })

  # Validate tracked questions
  if (!"QuestionCode" %in% names(tracked_questions)) {
    stop("Missing required column 'QuestionCode' in TrackedQuestions sheet")
  }

  message(paste0("  Loaded ", nrow(waves), " waves"))
  message(paste0("  Loaded ", nrow(tracked_questions), " tracked questions"))
  message(paste0("  Loaded ", nrow(banner), " banner breakouts"))

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
#'   - Wave1, Wave2, Wave3, etc.: Wave-specific question codes
#'   - QuestionText: Question wording
#'   - QuestionType: Type of question (Rating, SingleChoice, etc.)
#'
#' @export
load_question_mapping <- function(mapping_path) {

  # Validate file exists
  if (!file.exists(mapping_path)) {
    stop(paste0("Question mapping file not found: ", mapping_path))
  }

  message("Loading question mapping from: ", basename(mapping_path))

  # Load QuestionMap sheet
  mapping <- tryCatch({
    openxlsx::read.xlsx(mapping_path, sheet = "QuestionMap")
  }, error = function(e) {
    stop(paste0("Error reading 'QuestionMap' sheet: ", e$message))
  })

  # Validate required columns
  required_cols <- c("QuestionCode", "QuestionText", "QuestionType")
  missing_cols <- setdiff(required_cols, names(mapping))
  if (length(missing_cols) > 0) {
    stop(paste0("Missing required columns in QuestionMap sheet: ", paste(missing_cols, collapse = ", ")))
  }

  # Find wave columns (Wave1, Wave2, Wave3, etc.)
  wave_cols <- grep("^Wave\\d+$", names(mapping), value = TRUE)
  if (length(wave_cols) == 0) {
    stop("No wave columns found in QuestionMap sheet (expected Wave1, Wave2, etc.)")
  }

  message(paste0("  Loaded mapping for ", nrow(mapping), " questions across ", length(wave_cols), " waves"))

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
    stop("Settings sheet must have 'Setting' (or 'SettingName') and 'Value' columns")
  }

  if (!"Value" %in% names(settings_df)) {
    stop("Settings sheet must have 'Setting' (or 'SettingName') and 'Value' columns")
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

  message("Validating tracking configuration...")

  # Validate wave IDs are unique
  if (any(duplicated(config$waves$WaveID))) {
    stop("Duplicate WaveIDs found in Waves sheet")
  }

  # Validate data files exist (if absolute paths provided)
  for (i in 1:nrow(config$waves)) {
    data_file <- config$waves$DataFile[i]
    # Only validate if absolute path provided (relative paths resolved later)
    if (file.exists(dirname(data_file)) && !file.exists(data_file)) {
      warning(paste0("Data file not found for Wave ", config$waves$WaveID[i], ": ", data_file))
    }
  }

  # Validate fieldwork dates (only check rows where both dates exist)
  valid_date_rows <- !is.na(config$waves$FieldworkStart) & !is.na(config$waves$FieldworkEnd)
  if (any(valid_date_rows)) {
    if (!all(config$waves$FieldworkEnd[valid_date_rows] >= config$waves$FieldworkStart[valid_date_rows])) {
      stop("FieldworkEnd must be >= FieldworkStart for all waves with dates specified")
    }
  }

  # Validate tracked questions exist in mapping
  if (!is.null(question_mapping)) {
    unmapped_questions <- setdiff(
      config$tracked_questions$QuestionCode,
      question_mapping$QuestionCode
    )
    if (length(unmapped_questions) > 0) {
      warning(paste0(
        "Tracked questions not found in question mapping: ",
        paste(unmapped_questions, collapse = ", ")
      ))
    }
  }

  # Validate required settings exist
  required_settings <- c("project_name", "decimal_places_ratings", "show_significance")
  missing_settings <- setdiff(required_settings, names(config$settings))
  if (length(missing_settings) > 0) {
    warning(paste0(
      "Missing recommended settings (defaults will be used): ",
      paste(missing_settings, collapse = ", ")
    ))
  }

  # Validate banner structure
  if (nrow(config$banner) == 0) {
    stop("Banner sheet is empty - at least Total must be defined")
  }

  # Check for "Total" in banner
  if (!"Total" %in% config$banner$BreakVariable &&
      !any(grepl("(?i)total", config$banner$BreakLabel))) {
    warning("No 'Total' found in banner structure")
  }

  message("  Configuration validation passed")

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
  if (setting_name %in% names(config$settings)) {
    return(config$settings[[setting_name]])
  } else {
    return(default)
  }
}
