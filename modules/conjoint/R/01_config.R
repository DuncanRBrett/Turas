# ==============================================================================
# CONJOINT CONFIG LOADER - ENHANCED WITH ALCHEMER SUPPORT
# ==============================================================================
#
# Module: Conjoint Analysis - Configuration
# Purpose: Load and validate conjoint study configuration
# Version: 2.1.0 (Phase 1 - Alchemer Integration)
# Date: 2025-12-12
#
# SUPPORTED DATA SOURCES:
#   - alchemer: Direct Alchemer CBC export (ResponseID, SetNumber, etc.)
#   - generic: Standard Turas format (resp_id, choice_set_id, etc.)
#
# ==============================================================================

#' Load Conjoint Configuration
#'
#' Loads and validates conjoint study configuration from Excel file.
#' Supports all Phase 1 features including none option handling.
#'
#' REQUIRED SHEETS:
#'   - Settings: Analysis parameters
#'   - Attributes: Attribute definitions with levels
#'
#' OPTIONAL SHEETS:
#'   - Design: Experimental design matrix
#'
#' @param config_file Path to configuration Excel file (.xlsx)
#' @param project_root Optional project root directory (defaults to config file directory)
#' @param verbose Logical, print detailed progress (default TRUE)
#' @return List with validated configuration
#' @export
load_conjoint_config <- function(config_file, project_root = NULL, verbose = TRUE) {

  # Validate config file exists
  if (!file.exists(config_file)) {
    stop(create_error(
      "CONFIG",
      sprintf("Configuration file not found: %s", config_file),
      "Verify the file path is correct and file exists"
    ), call. = FALSE)
  }

  # Set project root to config file directory if not specified
  if (is.null(project_root)) {
    project_root <- dirname(normalizePath(config_file, winslash = "/"))
  }

  log_verbose(sprintf("Loading configuration from: %s", basename(config_file)), verbose)

  # Load settings sheet
  settings_df <- tryCatch({
    openxlsx::read.xlsx(config_file, sheet = "Settings")
  }, error = function(e) {
    stop(create_error(
      "CONFIG",
      "Failed to load Settings sheet",
      "Verify the Excel file has a sheet named 'Settings' with 'Setting' and 'Value' columns",
      sprintf("File: %s", config_file)
    ), call. = FALSE)
  })

  # Validate Settings sheet structure
  if (!all(c("Setting", "Value") %in% names(settings_df))) {
    stop(create_error(
      "CONFIG",
      "Settings sheet missing required columns",
      "Settings sheet must have 'Setting' and 'Value' columns",
      sprintf("Found columns: %s", paste(names(settings_df), collapse = ", "))
    ), call. = FALSE)
  }

  # Convert to named list
  settings_list <- setNames(as.list(settings_df$Value), settings_df$Setting)

  # Remove NA settings
  settings_list <- settings_list[
    !is.na(names(settings_list)) &
    names(settings_list) != ""
  ]

  # Load attributes sheet
  attributes_df <- tryCatch({
    openxlsx::read.xlsx(config_file, sheet = "Attributes")
  }, error = function(e) {
    stop(create_error(
      "CONFIG",
      "Failed to load Attributes sheet",
      "Verify the Excel file has a sheet named 'Attributes'",
      sprintf("File: %s", config_file)
    ), call. = FALSE)
  })

  # Validate Attributes sheet structure
  required_cols <- c("AttributeName", "NumLevels", "LevelNames")
  missing_cols <- setdiff(required_cols, names(attributes_df))
  if (length(missing_cols) > 0) {
    stop(create_error(
      "CONFIG",
      "Attributes sheet missing required columns",
      sprintf("Add these columns: %s", paste(missing_cols, collapse = ", ")),
      "Required: AttributeName, NumLevels, LevelNames"
    ), call. = FALSE)
  }

  # Parse level names
  attributes_df$levels_list <- lapply(attributes_df$LevelNames, parse_level_names)

  # Validate config
  validation_result <- validate_config(settings_list, attributes_df)

  if (!validation_result$is_valid) {
    error_msg <- create_error(
      "CONFIG",
      "Configuration validation failed",
      paste(validation_result$errors, collapse = "\n → ")
    )
    stop(error_msg, call. = FALSE)
  }

  # Print warnings if any
  if (length(validation_result$warnings) > 0) {
    for (warning_msg in validation_result$warnings) {
      warning(create_warning("CONFIG", warning_msg), call. = FALSE)
    }
  }

  # Extract and resolve file paths
  data_file <- resolve_config_path(
    settings_list$data_file,
    project_root,
    "data_file"
  )

  output_file <- resolve_config_path(
    settings_list$output_file,
    project_root,
    "output_file",
    must_exist = FALSE
  )

  # If no output file specified, use default
  if (is.null(output_file) || is.na(output_file)) {
    output_file <- file.path(project_root, "conjoint_results.xlsx")
  }

  # Load design (if exists)
  design <- NULL
  sheet_names <- openxlsx::getSheetNames(config_file)
  if ("Design" %in% sheet_names) {
    design <- openxlsx::read.xlsx(config_file, sheet = "Design")
    log_verbose("  ✓ Loaded experimental design matrix", verbose)
  }

  # Build final config object
  config <- list(
    # Settings
    settings = settings_list,

    # Attributes
    attributes = attributes_df,

    # Design (optional)
    design = design,

    # Paths
    data_file = data_file,
    output_file = output_file,
    project_root = project_root,
    config_file = normalizePath(config_file, winslash = "/"),

    # Analysis parameters (with defaults)
    analysis_type = settings_list$analysis_type %||% "choice",
    estimation_method = settings_list$estimation_method %||% "auto",
    baseline_handling = settings_list$baseline_handling %||% "first_level_zero",
    confidence_level = safe_numeric(settings_list$confidence_level, 0.95),
    choice_type = settings_list$choice_type %||% "single",

    # =========================================================================
    # ALCHEMER-SPECIFIC SETTINGS (Phase 1)
    # =========================================================================

    # Data source type: 'alchemer' for direct Alchemer CBC export,
    # 'generic' for standard Turas format
    data_source = settings_list$data_source %||% "generic",

    # Whether to clean Alchemer level names (e.g., "Low_071" -> "Low")
    clean_alchemer_levels = safe_logical(
      settings_list$clean_alchemer_levels,
      default = TRUE
    ),

    # Zero-centering method for utilities
    # TRUE = zero-center within each attribute (recommended)
    # FALSE = raw coefficients from model
    zero_center_utilities = safe_logical(
      settings_list$zero_center_utilities,
      default = TRUE
    ),

    # Base level method for dummy coding
    # 'first' = first level is reference (default)
    # 'last' = last level is reference
    # 'effects' = effects coding (sum to zero)
    base_level_method = settings_list$base_level_method %||% "first",

    # =========================================================================
    # COLUMN NAMES (with defaults)
    # =========================================================================

    respondent_id_column = settings_list$respondent_id_column %||% "resp_id",
    choice_set_column = settings_list$choice_set_column %||% "choice_set_id",
    chosen_column = settings_list$chosen_column %||% "chosen",
    alternative_id_column = settings_list$alternative_id_column %||% "alternative_id",
    rating_variable = settings_list$rating_variable %||% "rating",

    # Alchemer-specific column names (used when data_source = 'alchemer')
    alchemer_response_id_column = settings_list$alchemer_response_id_column %||% "ResponseID",
    alchemer_set_number_column = settings_list$alchemer_set_number_column %||% "SetNumber",
    alchemer_card_number_column = settings_list$alchemer_card_number_column %||% "CardNumber",
    alchemer_score_column = settings_list$alchemer_score_column %||% "Score",

    # =========================================================================
    # FEATURE FLAGS
    # =========================================================================

    generate_market_simulator = safe_logical(
      settings_list$generate_market_simulator,
      default = TRUE
    ),
    include_diagnostics = safe_logical(
      settings_list$include_diagnostics,
      default = TRUE
    ),

    # Advanced options
    bootstrap_iterations = safe_numeric(settings_list$bootstrap_iterations, 1000),
    min_responses_per_level = safe_numeric(settings_list$min_responses_per_level, 10),

    # None option handling
    none_as_baseline = safe_logical(settings_list$none_as_baseline, FALSE),
    none_label = settings_list$none_label %||% "None",

    # Validation results
    validation = validation_result
  )

  log_verbose(sprintf("  ✓ Loaded %d attributes with %d total levels",
                     nrow(attributes_df),
                     sum(attributes_df$NumLevels)), verbose)

  config
}


#' Validate Configuration
#'
#' Validates configuration settings and attributes
#'
#' @param settings_list Named list of settings
#' @param attributes_df Data frame of attributes
#' @return List with is_valid, errors, warnings
#' @keywords internal
validate_config <- function(settings_list, attributes_df) {

  errors <- character()
  warnings <- character()

  # ===== ATTRIBUTE VALIDATION =====

  # Check minimum number of attributes
  n_attributes <- nrow(attributes_df)
  if (n_attributes < 2) {
    errors <- c(errors, "Minimum 2 attributes required for conjoint analysis")
  }

  # Check maximum number of attributes (warning only)
  if (n_attributes > 6) {
    warnings <- c(warnings,
                 sprintf("You have %d attributes. More than 6 may overwhelm respondents and reduce data quality",
                        n_attributes))
  }

  # Validate each attribute
  for (i in seq_len(nrow(attributes_df))) {
    attr_name <- attributes_df$AttributeName[i]
    num_levels <- attributes_df$NumLevels[i]
    level_names <- attributes_df$levels_list[[i]]

    # Check attribute name is not empty
    if (is.na(attr_name) || attr_name == "") {
      errors <- c(errors, sprintf("Row %d: Attribute name is empty", i))
      next
    }

    # Check number of levels matches
    actual_levels <- length(level_names)
    if (actual_levels != num_levels) {
      errors <- c(errors, sprintf(
        "Attribute '%s': Expected %d levels but found %d in LevelNames",
        attr_name, num_levels, actual_levels
      ))
    }

    # Check minimum levels
    if (num_levels < 2) {
      errors <- c(errors, sprintf(
        "Attribute '%s': Minimum 2 levels required (found %d)",
        attr_name, num_levels
      ))
    }

    # Check maximum levels (warning)
    if (num_levels > 6) {
      warnings <- c(warnings, sprintf(
        "Attribute '%s': %d levels may reduce statistical power (6 or fewer recommended)",
        attr_name, num_levels
      ))
    }

    # Check for duplicate level names
    if (length(level_names) != length(unique(level_names))) {
      duplicates <- level_names[duplicated(level_names)]
      errors <- c(errors, sprintf(
        "Attribute '%s': Duplicate level names: %s",
        attr_name, paste(unique(duplicates), collapse = ", ")
      ))
    }

    # Check for empty level names
    if (any(level_names == "" | is.na(level_names))) {
      errors <- c(errors, sprintf(
        "Attribute '%s': Some level names are empty",
        attr_name
      ))
    }
  }

  # Check for duplicate attribute names
  if (length(attributes_df$AttributeName) != length(unique(attributes_df$AttributeName))) {
    duplicates <- attributes_df$AttributeName[duplicated(attributes_df$AttributeName)]
    errors <- c(errors, sprintf(
      "Duplicate attribute names: %s",
      paste(unique(duplicates), collapse = ", ")
    ))
  }

  # ===== SETTINGS VALIDATION =====

  # Validate analysis_type
  analysis_type <- settings_list$analysis_type %||% "choice"
  if (!analysis_type %in% c("choice", "rating")) {
    errors <- c(errors, sprintf(
      "analysis_type must be 'choice' or 'rating', got: %s",
      analysis_type
    ))
  }

  # Validate estimation_method
  estimation_method <- settings_list$estimation_method %||% "auto"
  valid_methods <- c("auto", "mlogit", "clogit", "hb")
  if (!estimation_method %in% valid_methods) {
    errors <- c(errors, sprintf(
      "estimation_method must be one of: %s (got: %s)",
      paste(valid_methods, collapse = ", "),
      estimation_method
    ))
  }

  # Validate baseline_handling
  baseline_handling <- settings_list$baseline_handling %||% "first_level_zero"
  if (!baseline_handling %in% c("first_level_zero", "all_levels_explicit")) {
    errors <- c(errors, sprintf(
      "baseline_handling must be 'first_level_zero' or 'all_levels_explicit', got: %s",
      baseline_handling
    ))
  }

  # Validate confidence_level
  conf_level <- safe_numeric(settings_list$confidence_level, 0.95)
  if (conf_level < 0.80 || conf_level > 0.99) {
    warnings <- c(warnings, sprintf(
      "confidence_level = %.2f is unusual (typical range: 0.80 to 0.99)",
      conf_level
    ))
  }

  # Validate choice_type
  choice_type <- settings_list$choice_type %||% "single"
  valid_choice_types <- c("single", "single_with_none", "best_worst", "continuous_sum")
  if (!choice_type %in% valid_choice_types) {
    errors <- c(errors, sprintf(
      "choice_type must be one of: %s (got: %s)",
      paste(valid_choice_types, collapse = ", "),
      choice_type
    ))
  }

  # Check Phase 2 features
  if (choice_type %in% c("best_worst", "continuous_sum")) {
    warnings <- c(warnings, sprintf(
      "choice_type = '%s' is a Phase 2 feature and may not be fully implemented yet",
      choice_type
    ))
  }

  # ===== ALCHEMER-SPECIFIC VALIDATION =====

  # Validate data_source
  data_source <- settings_list$data_source %||% "generic"
  if (!data_source %in% c("alchemer", "generic")) {
    errors <- c(errors, sprintf(
      "data_source must be 'alchemer' or 'generic', got: %s",
      data_source
    ))
  }

  # Validate base_level_method
  base_level_method <- settings_list$base_level_method %||% "first"
  if (!base_level_method %in% c("first", "last", "effects")) {
    errors <- c(errors, sprintf(
      "base_level_method must be 'first', 'last', or 'effects', got: %s",
      base_level_method
    ))
  }

  # Info message for Alchemer source

  if (data_source == "alchemer") {
    warnings <- c(warnings,
      "data_source = 'alchemer': Data will be transformed from Alchemer CBC format"
    )
  }

  # Validate data_file is specified
  if (is.null(settings_list$data_file) || is.na(settings_list$data_file)) {
    errors <- c(errors, "data_file must be specified in Settings sheet")
  }

  # Return validation result
  list(
    is_valid = length(errors) == 0,
    errors = errors,
    warnings = warnings
  )
}


#' Resolve configuration file path
#'
#' Handles relative and absolute paths
#'
#' @param path Character, path from config
#' @param base_path Character, base path for resolving relative paths
#' @param setting_name Character, name of setting (for error messages)
#' @param must_exist Logical, whether file must exist (default TRUE)
#' @return Character, resolved absolute path
#' @keywords internal
resolve_config_path <- function(path, base_path, setting_name, must_exist = TRUE) {

  if (is.null(path) || is.na(path)) {
    return(NULL)
  }

  path <- as.character(path)

  # Check if absolute path
  is_absolute <- grepl("^(/|[A-Za-z]:)", path)

  if (is_absolute) {
    resolved_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  } else {
    # Relative path - resolve from base_path
    resolved_path <- file.path(base_path, path)
    resolved_path <- normalizePath(resolved_path, winslash = "/", mustWork = FALSE)
  }

  # Check file exists if required
  if (must_exist && !file.exists(resolved_path)) {
    stop(create_error(
      "CONFIG",
      sprintf("File specified in '%s' not found", setting_name),
      "Verify the file path is correct",
      sprintf("Looking for: %s", resolved_path)
    ), call. = FALSE)
  }

  resolved_path
}
