# ==============================================================================
# WEIGHTING MODULE - CONFIGURATION LOADER
# ==============================================================================
# Load and validate Weight_Config.xlsx configuration file
# Part of TURAS Weighting Module v1.0
# ==============================================================================

#' Load Weighting Configuration
#'
#' Loads and validates the complete weighting configuration from Excel file.
#'
#' @param config_file Character, path to Weight_Config.xlsx
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return List with parsed configuration
#' @export
load_weighting_config <- function(config_file, verbose = TRUE) {

  if (verbose) {
    message("\n", strrep("=", 70))
    message("LOADING WEIGHTING CONFIGURATION")
    message(strrep("=", 70))
    message("Config file: ", basename(config_file))
  }

  # Validate file exists
  if (!file.exists(config_file)) {
    stop(sprintf(
      "\nConfig file not found: %s\n\nPlease check:\n  1. File path is correct\n  2. File exists in specified location",
      config_file
    ), call. = FALSE)
  }

  # Get project root (directory containing config file)
  project_root <- dirname(normalizePath(config_file, mustWork = TRUE))

  # Required sheets
  required_sheets <- c("General", "Weight_Specifications")
  available_sheets <- readxl::excel_sheets(config_file)

  missing_sheets <- setdiff(required_sheets, available_sheets)
  if (length(missing_sheets) > 0) {
    stop(sprintf(
      "\nMissing required sheets in config file: %s\n\nFound sheets: %s\n\nPlease add the missing sheets to your config file.",
      paste(missing_sheets, collapse = ", "),
      paste(available_sheets, collapse = ", ")
    ), call. = FALSE)
  }

  # ============================================================================
  # Load General Settings
  # ============================================================================
  if (verbose) message("\nLoading General settings...")

  general_df <- tryCatch({
    readxl::read_excel(config_file, sheet = "General")
  }, error = function(e) {
    stop(sprintf(
      "Failed to read 'General' sheet: %s",
      conditionMessage(e)
    ), call. = FALSE)
  })

  # Parse General sheet (Setting | Value format)
  general <- parse_settings_sheet(general_df)

  # Validate required general settings
  if (is.null(general$project_name) || is.na(general$project_name)) {
    stop("'project_name' is required in General settings", call. = FALSE)
  }

  if (is.null(general$data_file) || is.na(general$data_file)) {
    stop("'data_file' is required in General settings", call. = FALSE)
  }

  # Resolve data file path relative to config location
  general$data_file_resolved <- resolve_config_path(general$data_file, project_root)

  # Resolve output file path if specified
  if (!is.null(general$output_file) && !is.na(general$output_file) && general$output_file != "") {
    general$output_file_resolved <- resolve_config_path(general$output_file, project_root)
  } else {
    general$output_file_resolved <- NULL
  }

  # Resolve diagnostics file path if specified
  save_diag <- !is.null(general$save_diagnostics) &&
               !is.na(general$save_diagnostics) &&
               toupper(general$save_diagnostics) == "Y"

  if (save_diag) {
    if (is.null(general$diagnostics_file) || is.na(general$diagnostics_file)) {
      stop("'diagnostics_file' required when save_diagnostics = Y", call. = FALSE)
    }
    general$diagnostics_file_resolved <- resolve_config_path(general$diagnostics_file, project_root)
  } else {
    general$diagnostics_file_resolved <- NULL
  }

  general$save_diagnostics <- save_diag
  general$project_root <- project_root

  if (verbose) {
    message("  Project: ", general$project_name)
    message("  Data file: ", basename(general$data_file))
  }

  # ============================================================================
  # Load Weight Specifications
  # ============================================================================
  if (verbose) message("\nLoading Weight Specifications...")

  weight_specs_df <- tryCatch({
    readxl::read_excel(config_file, sheet = "Weight_Specifications")
  }, error = function(e) {
    stop(sprintf(
      "Failed to read 'Weight_Specifications' sheet: %s",
      conditionMessage(e)
    ), call. = FALSE)
  })

  if (nrow(weight_specs_df) == 0) {
    stop("Weight_Specifications sheet is empty. At least one weight must be defined.", call. = FALSE)
  }

  # Validate required columns
  required_cols <- c("weight_name", "method")
  missing_cols <- setdiff(required_cols, names(weight_specs_df))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "Weight_Specifications missing required columns: %s\nFound: %s",
      paste(missing_cols, collapse = ", "),
      paste(names(weight_specs_df), collapse = ", ")
    ), call. = FALSE)
  }

  # Check for duplicate weight names
  weight_names <- weight_specs_df$weight_name
  if (any(duplicated(weight_names))) {
    dups <- unique(weight_names[duplicated(weight_names)])
    stop(sprintf(
      "Duplicate weight names in Weight_Specifications: %s",
      paste(dups, collapse = ", ")
    ), call. = FALSE)
  }

  # Validate each weight specification
  for (i in seq_len(nrow(weight_specs_df))) {
    spec <- as.list(weight_specs_df[i, ])
    validation <- validate_weight_spec(spec)
    if (!validation$valid) {
      stop(sprintf(
        "\nInvalid weight specification for '%s':\n  %s",
        spec$weight_name,
        paste(validation$errors, collapse = "\n  ")
      ), call. = FALSE)
    }
  }

  if (verbose) {
    message("  Found ", nrow(weight_specs_df), " weight specification(s):")
    for (i in seq_len(nrow(weight_specs_df))) {
      message("    - ", weight_specs_df$weight_name[i], " (", weight_specs_df$method[i], ")")
    }
  }

  # ============================================================================
  # Load Design Targets (if any design weights specified)
  # ============================================================================
  has_design <- any(tolower(weight_specs_df$method) == "design")
  design_targets <- NULL

  if (has_design) {
    if (!"Design_Targets" %in% available_sheets) {
      design_weights <- weight_specs_df$weight_name[tolower(weight_specs_df$method) == "design"]
      stop(sprintf(
        "\nDesign_Targets sheet required for design weight(s): %s\n\nPlease add a Design_Targets sheet to your config file.",
        paste(design_weights, collapse = ", ")
      ), call. = FALSE)
    }

    if (verbose) message("\nLoading Design Targets...")

    design_targets <- tryCatch({
      readxl::read_excel(config_file, sheet = "Design_Targets")
    }, error = function(e) {
      stop(sprintf(
        "Failed to read 'Design_Targets' sheet: %s",
        conditionMessage(e)
      ), call. = FALSE)
    })

    # Validate required columns
    required_cols <- c("weight_name", "stratum_variable", "stratum_category", "population_size")
    missing_cols <- setdiff(required_cols, names(design_targets))
    if (length(missing_cols) > 0) {
      stop(sprintf(
        "Design_Targets missing required columns: %s\nFound: %s",
        paste(missing_cols, collapse = ", "),
        paste(names(design_targets), collapse = ", ")
      ), call. = FALSE)
    }

    # Ensure population_size is numeric
    design_targets$population_size <- suppressWarnings(as.numeric(design_targets$population_size))

    if (verbose) {
      message("  Loaded ", nrow(design_targets), " design target rows")
    }
  }

  # ============================================================================
  # Load Rim Targets (if any rim weights specified)
  # ============================================================================
  has_rim <- any(tolower(weight_specs_df$method) == "rim")
  rim_targets <- NULL

  if (has_rim) {
    if (!"Rim_Targets" %in% available_sheets) {
      rim_weights <- weight_specs_df$weight_name[tolower(weight_specs_df$method) == "rim"]
      stop(sprintf(
        "\nRim_Targets sheet required for rim weight(s): %s\n\nPlease add a Rim_Targets sheet to your config file.",
        paste(rim_weights, collapse = ", ")
      ), call. = FALSE)
    }

    if (verbose) message("\nLoading Rim Targets...")

    rim_targets <- tryCatch({
      readxl::read_excel(config_file, sheet = "Rim_Targets")
    }, error = function(e) {
      stop(sprintf(
        "Failed to read 'Rim_Targets' sheet: %s",
        conditionMessage(e)
      ), call. = FALSE)
    })

    # Validate required columns
    required_cols <- c("weight_name", "variable", "category", "target_percent")
    missing_cols <- setdiff(required_cols, names(rim_targets))
    if (length(missing_cols) > 0) {
      stop(sprintf(
        "Rim_Targets missing required columns: %s\nFound: %s",
        paste(missing_cols, collapse = ", "),
        paste(names(rim_targets), collapse = ", ")
      ), call. = FALSE)
    }

    # Ensure target_percent is numeric
    rim_targets$target_percent <- suppressWarnings(as.numeric(rim_targets$target_percent))

    if (verbose) {
      message("  Loaded ", nrow(rim_targets), " rim target rows")
      rim_vars <- unique(rim_targets$variable)
      message("  Variables: ", paste(rim_vars, collapse = ", "))
    }
  }

  # ============================================================================
  # Load Advanced Settings (optional)
  # ============================================================================
  advanced_settings <- NULL

  if ("Advanced_Settings" %in% available_sheets) {
    if (verbose) message("\nLoading Advanced Settings...")

    advanced_settings <- tryCatch({
      readxl::read_excel(config_file, sheet = "Advanced_Settings")
    }, error = function(e) {
      warning(sprintf(
        "Failed to read 'Advanced_Settings' sheet: %s\nUsing defaults.",
        conditionMessage(e)
      ), call. = FALSE)
      NULL
    })

    if (!is.null(advanced_settings) && nrow(advanced_settings) > 0) {
      if (verbose) {
        message("  Loaded advanced settings for ", nrow(advanced_settings), " weight(s)")
      }
    }
  }

  # ============================================================================
  # Build Configuration Object
  # ============================================================================
  config <- list(
    general = general,
    weight_specifications = weight_specs_df,
    design_targets = design_targets,
    rim_targets = rim_targets,
    advanced_settings = advanced_settings,
    config_file = normalizePath(config_file, mustWork = TRUE)
  )

  if (verbose) {
    message("\n", strrep("-", 70))
    message("Configuration loaded successfully")
    message(strrep("-", 70))
  }

  return(config)
}

#' Parse Settings Sheet (Setting | Value format)
#'
#' Converts a two-column Settings/Value sheet to a named list.
#'
#' @param df Data frame with Setting and Value columns
#' @return Named list
#' @keywords internal
parse_settings_sheet <- function(df) {
  # Handle different possible column names
  setting_col <- NULL
  value_col <- NULL

  for (col in c("Setting", "setting", "SETTING")) {
    if (col %in% names(df)) {
      setting_col <- col
      break
    }
  }

  for (col in c("Value", "value", "VALUE")) {
    if (col %in% names(df)) {
      value_col <- col
      break
    }
  }

  if (is.null(setting_col) || is.null(value_col)) {
    stop(sprintf(
      "General sheet must have 'Setting' and 'Value' columns.\nFound: %s",
      paste(names(df), collapse = ", ")
    ), call. = FALSE)
  }

  # Convert to named list
  settings <- as.list(df[[value_col]])
  names(settings) <- df[[setting_col]]

  # Remove NA entries
  settings <- settings[!is.na(names(settings)) & names(settings) != ""]

  return(settings)
}

#' Resolve Path Relative to Config Location
#'
#' Resolves a relative path from the config file location.
#'
#' @param path Character, path (relative or absolute)
#' @param base_path Character, base directory (config file location)
#' @return Character, resolved absolute path
#' @keywords internal
resolve_config_path <- function(path, base_path) {
  if (is.null(path) || is.na(path) || path == "") {
    return(NULL)
  }

  # Expand home directory (~)
  path <- path.expand(path)

  # Remove leading ./ if present
  path <- gsub("^\\./", "", path)

  # Check if already absolute
  if (grepl("^/|^[A-Za-z]:", path)) {
    return(normalizePath(path, mustWork = FALSE))
  }

  # Resolve relative to base path
  full_path <- file.path(base_path, path)
  return(normalizePath(full_path, winslash = "/", mustWork = FALSE))
}

#' Get Advanced Setting for Weight
#'
#' Retrieves an advanced setting for a specific weight, with default fallback.
#'
#' @param config List, full configuration object
#' @param weight_name Character, name of weight
#' @param setting_name Character, name of setting
#' @param default Default value if not specified
#' @return Setting value or default
#' @export
get_advanced_setting <- function(config, weight_name, setting_name, default = NULL) {
  if (is.null(config$advanced_settings)) {
    return(default)
  }

  adv <- config$advanced_settings
  weight_row <- adv[adv$weight_name == weight_name, , drop = FALSE]

  if (nrow(weight_row) == 0) {
    return(default)
  }

  if (!setting_name %in% names(weight_row)) {
    return(default)
  }

  value <- weight_row[[setting_name]][1]

  if (is.na(value)) {
    return(default)
  }

  return(value)
}

#' Get Weight Specification by Name
#'
#' Retrieves the specification for a specific weight.
#'
#' @param config List, full configuration object
#' @param weight_name Character, name of weight
#' @return Named list with weight specification
#' @export
get_weight_spec <- function(config, weight_name) {
  specs <- config$weight_specifications
  spec_row <- specs[specs$weight_name == weight_name, , drop = FALSE]

  if (nrow(spec_row) == 0) {
    stop(sprintf(
      "Weight '%s' not found in specifications.\nAvailable: %s",
      weight_name,
      paste(specs$weight_name, collapse = ", ")
    ), call. = FALSE)
  }

  return(as.list(spec_row[1, ]))
}

#' Get Design Targets for Weight
#'
#' Retrieves design targets for a specific weight.
#'
#' @param config List, full configuration object
#' @param weight_name Character, name of weight
#' @return Data frame of design targets
#' @export
get_design_targets <- function(config, weight_name) {
  if (is.null(config$design_targets)) {
    return(NULL)
  }

  targets <- config$design_targets[config$design_targets$weight_name == weight_name, , drop = FALSE]
  return(targets)
}

#' Get Rim Targets for Weight
#'
#' Retrieves rim targets for a specific weight.
#'
#' @param config List, full configuration object
#' @param weight_name Character, name of weight
#' @return Data frame of rim targets
#' @export
get_rim_targets <- function(config, weight_name) {
  if (is.null(config$rim_targets)) {
    return(NULL)
  }

  targets <- config$rim_targets[config$rim_targets$weight_name == weight_name, , drop = FALSE]
  return(targets)
}
