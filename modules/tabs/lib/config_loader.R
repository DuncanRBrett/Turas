# ==============================================================================
# TURAS>TABS - CONFIGURATION LOADER MODULE
# ==============================================================================
# Purpose: Load and parse crosstab configuration files
# Dependencies: core/validation, shared/data/loader
# Author: Turas Analytics Toolkit
# Version: 1.0.0
# ==============================================================================

#' Load Complete Crosstab Configuration
#' 
#' Main entry point for loading all configuration elements needed for crosstabs
#' 
#' @param config_file Path to Crosstab_Config.xlsx file
#' @param project_root Optional project root directory
#' @return List with config, paths, and validation results
#' @export
#' @examples
#' config <- load_crosstab_configuration("Config.xlsx")
load_crosstab_configuration <- function(config_file, project_root = NULL) {
  
  # Validate config file exists
  if (!file.exists(config_file)) {
    stop(sprintf("Configuration file not found: %s", config_file))
  }
  
  # Determine project root if not provided
  if (is.null(project_root)) {
    project_root <- dirname(config_file)
  }
  
  message("Loading crosstab configuration...")

  
  # Load main settings
  settings <- load_config_settings(config_file)
  
  # Build config object
  config_obj <- build_config_object(settings)
  
  # Resolve file paths
  paths <- resolve_config_paths(settings, project_root)
  
  # Load selection (banner & stub)
  selection <- load_question_selection(config_file)
  
  # Validate configuration
  validation <- validate_configuration(config_obj, paths, selection)
  
  message("Configuration loaded successfully")

  
  return(list(
    config = config_obj,
    paths = paths,
    selection = selection,
    validation = validation,
    project_root = project_root
  ))
}

# ==============================================================================
# SETTINGS LOADING
# ==============================================================================

#' Load Settings Sheet from Config File
#' 
#' Loads the Settings sheet and returns a named list
#' 
#' @param config_file Path to config file
#' @param sheet_name Name of settings sheet (default: "Settings")
#' @return Named list of settings
#' @export
load_config_settings <- function(config_file, sheet_name = "Settings") {
  
  tryCatch({
    # Load sheet
    config_df <- readxl::read_excel(config_file, sheet = sheet_name)
    
    # Validate structure
    if (!all(c("Setting", "Value") %in% names(config_df))) {
      stop(sprintf(
        "Config sheet '%s' must have 'Setting' and 'Value' columns.\nFound: %s",
        sheet_name,
        paste(names(config_df), collapse = ", ")
      ))
    }
    
    # Check for data
    if (nrow(config_df) == 0) {
      warning(sprintf("Config sheet '%s' is empty", sheet_name))
      return(list())
    }
    
    # Check for duplicate settings
    setting_names <- as.character(config_df$Setting)
    setting_names <- setting_names[!is.na(setting_names) & setting_names != ""]
    
    duplicates <- setting_names[duplicated(setting_names)]
    if (length(duplicates) > 0) {
      stop(sprintf(
        "Config sheet '%s' contains duplicate Setting names: %s\nPlease ensure all Setting names are unique.",
        sheet_name,
        paste(unique(duplicates), collapse = ", ")
      ), call. = FALSE)
    }
    
    # Convert to named list
    config_list <- setNames(as.list(config_df$Value), config_df$Setting)
    
    # Remove NA or empty settings
    config_list <- config_list[
      !is.na(names(config_list)) & 
      names(config_list) != "" & 
      !sapply(config_list, function(x) is.null(x) || (length(x) == 1 && is.na(x)))
    ]
    
    return(config_list)
    
  }, error = function(e) {
    stop(sprintf(
      "Failed to load config sheet '%s' from %s\nError: %s",
      sheet_name,
      basename(config_file),
      conditionMessage(e)
    ), call. = FALSE)
  })
}

#' Get Configuration Value
#' 
#' Safely retrieve a configuration value with default fallback
#' 
#' @param config_list Named list of config values
#' @param setting_name Name of setting to retrieve
#' @param default_value Default value if not found
#' @param required Stop if setting not found and no default
#' @return Configuration value or default
#' @export
get_config_value <- function(config_list, setting_name, default_value = NULL, 
                              required = FALSE) {
  
  value <- config_list[[setting_name]]
  
  # Handle missing value
  if (is.null(value) || (length(value) == 1 && is.na(value))) {
    if (required && is.null(default_value)) {
      stop(sprintf(
        "Required setting '%s' not found in configuration\n\nAvailable settings:\n  %s",
        setting_name,
        paste(head(names(config_list), 20), collapse = "\n  ")
      ), call. = FALSE)
    }
    return(default_value)
  }
  
  return(value)
}

#' Safe Logical Conversion
#' 
#' Convert various formats to logical (TRUE/FALSE)
#' Handles: Y/N, YES/NO, T/F, 1/0, TRUE/FALSE
#' 
#' @param value Value to convert
#' @param default Default value if conversion fails
#' @return Logical value
#' @export
safe_logical <- function(value, default = FALSE) {
  if (is.null(value) || is.na(value)) return(default)
  
  if (is.logical(value)) return(value)
  
  # Convert to character and check
  char_value <- toupper(trimws(as.character(value)))
  
  if (char_value %in% c("Y", "YES", "T", "TRUE", "1")) {
    return(TRUE)
  } else if (char_value %in% c("N", "NO", "F", "FALSE", "0")) {
    return(FALSE)
  } else {
    return(default)
  }
}

#' Safe Numeric Conversion
#' 
#' Convert to numeric with default fallback
#' 
#' @param value Value to convert
#' @param default Default value if conversion fails
#' @return Numeric value
#' @export
safe_numeric <- function(value, default = NA_real_) {
  if (is.null(value) || is.na(value)) return(default)
  
  numeric_value <- suppressWarnings(as.numeric(value))
  
  if (is.na(numeric_value)) {
    return(default)
  } else {
    return(numeric_value)
  }
}

# ==============================================================================
# CONFIG OBJECT BUILDING
# ==============================================================================

#' Build Configuration Object
#' 
#' Builds the complete config object with all settings
#' Applies defaults for missing values
#' 
#' @param settings Named list from load_config_settings()
#' @return Structured configuration object
#' @export
build_config_object <- function(settings) {
  
  # Default constants
  DEFAULT_ALPHA <- 0.05
  DEFAULT_MIN_BASE <- 30
  
  config_obj <- list(
    # Weighting settings
    apply_weighting = safe_logical(get_config_value(settings, "apply_weighting", FALSE)),
    weight_variable = get_config_value(settings, "weight_variable", NULL),
    show_unweighted_n = safe_logical(get_config_value(settings, "show_unweighted_n", TRUE)),
    show_effective_n = safe_logical(get_config_value(settings, "show_effective_n", TRUE)),
    weight_label = get_config_value(settings, "weight_label", "Weighted"),
    
    # Display settings
    decimal_separator = get_config_value(settings, "decimal_separator", "."),
    show_frequency = safe_logical(get_config_value(settings, "show_frequency", TRUE)),
    show_percent_column = safe_logical(get_config_value(settings, "show_percent_column", TRUE)),
    show_percent_row = safe_logical(get_config_value(settings, "show_percent_row", FALSE)),
    
    # Box/Category settings
    boxcategory_frequency = safe_logical(get_config_value(settings, "boxcategory_frequency", FALSE)),
    boxcategory_percent_column = safe_logical(get_config_value(settings, "boxcategory_percent_column", TRUE)),
    boxcategory_percent_row = safe_logical(get_config_value(settings, "boxcategory_percent_row", FALSE)),
    
    # Decimal places
    decimal_places_percent = safe_numeric(get_config_value(settings, "decimal_places_percent", 0)),
    decimal_places_ratings = safe_numeric(get_config_value(settings, "decimal_places_ratings", 1)),
    decimal_places_index = safe_numeric(get_config_value(settings, "decimal_places_index", 1)),
    decimal_places_numeric = safe_numeric(get_config_value(settings, "decimal_places_numeric", 1)),
    
    # Significance testing
    enable_significance_testing = safe_logical(get_config_value(settings, "enable_significance_testing", TRUE)),
    alpha = safe_numeric(get_config_value(settings, "alpha", DEFAULT_ALPHA)),
    significance_min_base = safe_numeric(get_config_value(settings, "significance_min_base", DEFAULT_MIN_BASE)),
    bonferroni_correction = safe_logical(get_config_value(settings, "bonferroni_correction", TRUE)),
    enable_chi_square = safe_logical(get_config_value(settings, "enable_chi_square", FALSE)),
    
    # Advanced features
    show_standard_deviation = safe_logical(get_config_value(settings, "show_standard_deviation", FALSE)),
    test_net_differences = safe_logical(get_config_value(settings, "test_net_differences", FALSE)),
    create_sample_composition = safe_logical(get_config_value(settings, "create_sample_composition", FALSE)),
    show_net_positive = safe_logical(get_config_value(settings, "show_net_positive", FALSE)),
    
    # Numeric question settings
    show_numeric_median = safe_logical(get_config_value(settings, "show_numeric_median", FALSE)),
    show_numeric_mode = safe_logical(get_config_value(settings, "show_numeric_mode", FALSE)),
    show_numeric_outliers = safe_logical(get_config_value(settings, "show_numeric_outliers", TRUE)),
    exclude_outliers_from_stats = safe_logical(get_config_value(settings, "exclude_outliers_from_stats", FALSE)),
    outlier_method = get_config_value(settings, "outlier_method", "IQR"),
    
    # System settings
    enable_checkpointing = safe_logical(get_config_value(settings, "enable_checkpointing", TRUE)),
    zero_division_as_blank = safe_logical(get_config_value(settings, "zero_division_as_blank", TRUE)),
    
    # Output settings
    output_subfolder = get_config_value(settings, "output_subfolder", "Crosstabs"),
    output_filename = get_config_value(settings, "output_filename", "Crosstabs.xlsx")
  )
  
  # Validation
  if (config_obj$alpha <= 0 || config_obj$alpha >= 1) {
    warning("Alpha must be between 0 and 1. Using default 0.05")
    config_obj$alpha <- DEFAULT_ALPHA
  }
  
  if (config_obj$significance_min_base < 1) {
    warning("significance_min_base must be >= 1. Using default 30")
    config_obj$significance_min_base <- DEFAULT_MIN_BASE
  }
  
  return(config_obj)
}

# ==============================================================================
# PATH RESOLUTION
# ==============================================================================

#' Resolve Configuration Paths
#' 
#' Resolves all file paths from configuration
#' 
#' @param settings Named list of settings
#' @param project_root Project root directory
#' @return List of resolved paths
#' @export

resolve_config_paths <- function(settings, project_root) {
  
  # Get structure file path
  structure_file <- get_config_value(settings, "structure_file", required = TRUE)
  structure_path <- resolve_path(project_root, structure_file)
  
  # Validate structure file exists
  if (!file.exists(structure_path)) {
    stop(sprintf("Survey structure file not found: %s", structure_path))
  }
  
  # Read the Project sheet from Survey_Structure to get data_file
  project_info <- readxl::read_excel(structure_path, sheet = "Project")
  data_file_row <- project_info[project_info$Setting == "data_file" & !is.na(project_info$Setting), ]
  
  if (nrow(data_file_row) > 0) {
    data_file <- data_file_row$Value[1]
    survey_data_path <- resolve_path(project_root, data_file)
  } else {
    stop("data_file not found in Survey_Structure.xlsx Project sheet")
  }
  
  # Get output directory
  output_subfolder <- get_config_value(settings, "output_subfolder", "Crosstabs")
  output_dir <- file.path(project_root, output_subfolder)
  
  # Create output directory if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  return(list(
    structure_file = structure_path,
    survey_structure = structure_path,
    survey_data = survey_data_path,
    output_dir = output_dir,
    project_root = project_root
  ))
}

#' Resolve Relative Path
#' 
#' Convert relative path to absolute path from base
#' 
#' @param base_path Base directory
#' @param relative_path Path relative to base
#' @return Absolute normalized path
#' @export
resolve_path <- function(base_path, relative_path) {
  
  if (is.null(base_path) || is.na(base_path) || base_path == "") {
    stop("base_path cannot be empty", call. = FALSE)
  }
  
  if (is.null(relative_path) || is.na(relative_path) || relative_path == "") {
    stop("relative_path cannot be empty", call. = FALSE)
  }
  
  # Handle absolute paths
  if (substring(relative_path, 1, 1) == "/" || 
      (nchar(relative_path) >= 2 && substring(relative_path, 2, 2) == ":")) {
    return(normalizePath(relative_path, mustWork = FALSE))
  }
  
  # Remove ./ prefix if present
  if (substring(relative_path, 1, 2) == "./") {
    relative_path <- substring(relative_path, 3)
  }
  
  # Combine and normalize
  full_path <- file.path(base_path, relative_path)
  return(normalizePath(full_path, mustWork = FALSE))
}

# ==============================================================================
# QUESTION SELECTION LOADING
# ==============================================================================

#' Load Question Selection
#' 
#' Loads the Selection sheet which defines banner and stub questions
#' 
#' @param config_file Path to config file
#' @return List with banner and stub question definitions
#' @export
load_question_selection <- function(config_file) {
  
  tryCatch({
    selection_df <- readxl::read_excel(config_file, sheet = "Selection")
    
    # Validate required columns
    required_cols <- c("QuestionCode")
    missing_cols <- setdiff(required_cols, names(selection_df))
    
    if (length(missing_cols) > 0) {
      stop(sprintf(
        "Selection sheet missing required columns: %s",
        paste(missing_cols, collapse = ", ")
      ))
    }
    
    # Apply defaults for optional columns
    if (!"Include" %in% names(selection_df)) {
      selection_df$Include <- "N"
    }
    if (!"UseBanner" %in% names(selection_df)) {
      selection_df$UseBanner <- "N"
    }
    if (!"BannerBoxCategory" %in% names(selection_df)) {
      selection_df$BannerBoxCategory <- "N"
    }
    if (!"CreateIndex" %in% names(selection_df)) {
      selection_df$CreateIndex <- "N"
    }
    
    # Fill NAs with defaults
    selection_df$Include[is.na(selection_df$Include)] <- "N"
    selection_df$UseBanner[is.na(selection_df$UseBanner)] <- "N"
    selection_df$BannerBoxCategory[is.na(selection_df$BannerBoxCategory)] <- "N"
    selection_df$CreateIndex[is.na(selection_df$CreateIndex)] <- "N"
    
    # Extract banner questions
    banner_questions <- selection_df[selection_df$UseBanner == "Y", ]
    
    # Extract stub questions (questions to analyze)
    stub_questions <- selection_df[selection_df$Include == "Y", ]
    
    if (nrow(banner_questions) == 0) {
      stop("No banner questions selected (UseBanner='Y')")
    }
    
    if (nrow(stub_questions) == 0) {
      stop("No stub questions selected (Include='Y')")
    }
    
    cat(sprintf("  Found %d banner questions\n", nrow(banner_questions)))
    cat(sprintf("  Found %d stub questions\n", nrow(stub_questions)))
    
    return(list(
      all = selection_df,
      banner = banner_questions,
      stub = stub_questions
    ))
    
  }, error = function(e) {
    stop(sprintf(
      "Failed to load Selection sheet: %s",
      conditionMessage(e)
    ), call. = FALSE)
  })
}

#' Parse Banner Structure
#' 
#' Extracts banner definition from selection
#' 
#' @param selection Selection list from load_question_selection()
#' @return Data frame with banner structure
#' @export
parse_banner_structure <- function(selection) {
  
  banner_df <- selection$banner
  
  # Add display order if not present
  if (!"BannerOrder" %in% names(banner_df)) {
    banner_df$BannerOrder <- seq_len(nrow(banner_df))
  }
  
  # Sort by order
  banner_df <- banner_df[order(banner_df$BannerOrder), ]
  
  return(banner_df)
}

#' Parse Stub Structure
#' 
#' Extracts stub (questions to analyze) from selection
#' 
#' @param selection Selection list from load_question_selection()
#' @return Data frame with stub structure
#' @export
parse_stub_structure <- function(selection) {
  
  stub_df <- selection$stub
  
  # Add display order if not present
  if (!"QuestionOrder" %in% names(stub_df)) {
    stub_df$QuestionOrder <- seq_len(nrow(stub_df))
  }
  
  # Sort by order
  stub_df <- stub_df[order(stub_df$QuestionOrder), ]
  
  return(stub_df)
}

# ==============================================================================
# CONFIGURATION VALIDATION
# ==============================================================================

#' Validate Configuration
#' 
#' Validates the complete configuration for consistency
#' 
#' @param config_obj Configuration object
#' @param paths Resolved paths
#' @param selection Question selection
#' @return List with validation results
#' @export
validate_configuration <- function(config_obj, paths, selection) {
  
  issues <- list()
  warnings <- list()
  
  # Check file paths exist
  if (!file.exists(paths$structure_file)) {
    issues <- append(issues, sprintf("Structure file not found: %s", paths$structure_file))
  }
  
  # Check output directory is writable
  if (!dir.exists(paths$output_dir)) {
    if (!dir.create(paths$output_dir, recursive = TRUE, showWarnings = FALSE)) {
      issues <- append(issues, sprintf("Cannot create output directory: %s", paths$output_dir))
    }
  }
  
  # Check for valid alpha
  if (config_obj$alpha <= 0 || config_obj$alpha >= 1) {
    warnings <- append(warnings, "Alpha should be between 0 and 1")
  }
  
  # Check weighting configuration
  if (config_obj$apply_weighting && is.null(config_obj$weight_variable)) {
    issues <- append(issues, "apply_weighting is TRUE but weight_variable is not specified")
  }
  
  # Check selection has data
  if (nrow(selection$banner) == 0) {
    issues <- append(issues, "No banner questions selected")
  }
  
  if (nrow(selection$stub) == 0) {
    issues <- append(issues, "No stub questions selected")
  }
  
  # Return validation results
  valid <- length(issues) == 0
  
  if (length(warnings) > 0) {
    cat("⚠️  Configuration warnings:")

    for (w in warnings) {
      cat(sprintf("  - %s\n", w))
    }
  }
  
  if (!valid) {
    cat("âŒ Configuration errors:")

    for (i in issues) {
      cat(sprintf("  - %s\n", i))
    }
    stop("Configuration validation failed", call. = FALSE)
  }
  
  return(list(
    valid = valid,
    issues = issues,
    warnings = warnings
  ))
}

# ==============================================================================
# MODULE METADATA
# ==============================================================================

#' Get Module Version
#' @export
get_config_loader_version <- function() {
  return("1.0.0")
}

#' Get Module Info
#' @export
get_config_loader_info <- function() {
  cat("")

  cat("================================================")

  cat("TURAS>TABS Configuration Loader Module")

  cat("================================================")

  cat("Version:", get_config_loader_version(), "")

  cat("Purpose: Load and parse crosstab configurations")

  cat("")

  cat("Main Functions:")

  cat("  - load_crosstab_configuration()")

  cat("  - load_config_settings()")

  cat("  - build_config_object()")

  cat("  - load_question_selection()")

  cat("  - parse_banner_structure()")

  cat("  - parse_stub_structure()")

  cat("  - validate_configuration()")

  cat("================================================\n")

}

# Module loaded message
message("Turas>Tabs config_loader module loaded")

