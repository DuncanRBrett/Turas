# ==============================================================================
# WEIGHTING MODULE - CONFIGURATION LOADER
# ==============================================================================
# Load and validate Weight_Config.xlsx configuration file
# Part of TURAS Weighting Module v3.0
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
  if (exists("guard_config_file", mode = "function")) {
    guard_config_file(config_file)
  } else if (!file.exists(config_file)) {
    weighting_refuse(
      code = "CFG_FILE_NOT_FOUND",
      title = "Configuration file not found",
      problem = sprintf("The specified config file does not exist: %s", config_file),
      why_it_matters = "The weighting module cannot load configuration without the config file",
      how_to_fix = "Check that the file path is correct and the file exists in the specified location"
    )
  }

  project_root <- dirname(normalizePath(config_file, mustWork = TRUE))
  available_sheets <- readxl::excel_sheets(config_file)

  # Validate required sheets
  for (sheet in c("General", "Weight_Specifications")) {
    if (exists("guard_required_sheet", mode = "function")) {
      guard_required_sheet(config_file, sheet, available_sheets)
    } else if (!sheet %in% available_sheets) {
      weighting_refuse(
        code = "CFG_MISSING_SHEET",
        title = "Required configuration sheet missing",
        problem = sprintf("Missing required sheet '%s' in config file", sheet),
        why_it_matters = "All required sheets must be present for proper configuration",
        how_to_fix = sprintf("Add the '%s' sheet to your config file. Found sheets: %s",
                            sheet, paste(available_sheets, collapse = ", "))
      )
    }
  }

  # Load each section via helpers
  general <- load_weighting_general(config_file, project_root, verbose)
  weight_specs_df <- load_weight_specifications(config_file, verbose)

  # Load target sheets conditionally based on weight methods
  design_targets <- load_weighting_target_sheet(
    config_file, available_sheets, weight_specs_df, "design",
    sheet_name = "Design_Targets",
    required_cols = c("weight_name", "stratum_variable", "stratum_category", "population_size"),
    numeric_col = "population_size",
    verbose = verbose
  )

  rim_targets <- load_weighting_target_sheet(
    config_file, available_sheets, weight_specs_df, "rim",
    sheet_name = "Rim_Targets",
    required_cols = c("weight_name", "variable", "category", "target_percent"),
    numeric_col = "target_percent",
    verbose = verbose
  )

  cell_targets <- load_weighting_target_sheet(
    config_file, available_sheets, weight_specs_df, "cell",
    sheet_name = "Cell_Targets",
    required_cols = c("weight_name", "target_percent"),
    numeric_col = "target_percent",
    verbose = verbose
  )

  # Load optional sheets
  advanced_settings <- load_optional_sheet(config_file, "Advanced_Settings", available_sheets, verbose)
  notes <- load_weighting_notes(config_file, available_sheets, verbose)

  # Build config
  config <- list(
    general = general,
    weight_specifications = weight_specs_df,
    design_targets = design_targets,
    rim_targets = rim_targets,
    cell_targets = cell_targets,
    advanced_settings = advanced_settings,
    notes = notes,
    config_file = normalizePath(config_file, mustWork = TRUE)
  )

  if (verbose) {
    message("\n", strrep("-", 70))
    message("Configuration loaded successfully")
    message(strrep("-", 70))
  }

  return(config)
}


# ==============================================================================
# CONFIG LOADER HELPERS
# ==============================================================================

#' Load General Settings from Config File
#' @keywords internal
load_weighting_general <- function(config_file, project_root, verbose = TRUE) {
  if (verbose) message("\nLoading General settings...")

  general_df <- tryCatch({
    readxl::read_excel(config_file, sheet = "General")
  }, error = function(e) {
    weighting_refuse(
      code = "IO_SHEET_READ_ERROR",
      title = "Failed to read General sheet",
      problem = sprintf("Could not read 'General' sheet: %s", conditionMessage(e)),
      why_it_matters = "The General sheet contains essential configuration settings",
      how_to_fix = "Check that the General sheet is not corrupted and is properly formatted"
    )
  })

  general <- parse_settings_sheet(general_df)

  # Validate required settings
  for (setting in c("project_name", "data_file")) {
    if (is.null(general[[setting]]) || is.na(general[[setting]])) {
      weighting_refuse(
        code = "CFG_MISSING_SETTING",
        title = sprintf("Missing required setting: %s", setting),
        problem = sprintf("The '%s' setting is missing or empty in the General sheet", setting),
        why_it_matters = sprintf("'%s' is required for the weighting module", setting),
        how_to_fix = sprintf("Add a row with Setting = '%s' and a valid Value", setting)
      )
    }
  }

  # Resolve file paths
  general$data_file_resolved <- resolve_config_path(general$data_file, project_root)

  general$id_column <- if (!is.null(general$id_column) && !is.na(general$id_column) &&
                           nzchar(trimws(general$id_column))) trimws(general$id_column) else NULL

  general$output_file_resolved <- if (!is.null(general$output_file) && !is.na(general$output_file) &&
                                      general$output_file != "") {
    resolve_config_path(general$output_file, project_root)
  } else NULL

  # Diagnostics
  save_diag <- !is.null(general$save_diagnostics) && !is.na(general$save_diagnostics) &&
               toupper(general$save_diagnostics) == "Y"
  if (save_diag) {
    if (is.null(general$diagnostics_file) || is.na(general$diagnostics_file)) {
      weighting_refuse(
        code = "CFG_MISSING_SETTING",
        title = "Missing required setting: diagnostics_file",
        problem = "The 'diagnostics_file' setting is missing but save_diagnostics = Y",
        why_it_matters = "A file path is required when diagnostics are enabled",
        how_to_fix = "Add 'diagnostics_file' to General sheet, or set save_diagnostics = N"
      )
    }
    general$diagnostics_file_resolved <- resolve_config_path(general$diagnostics_file, project_root)
  } else {
    general$diagnostics_file_resolved <- NULL
  }
  general$save_diagnostics <- save_diag
  general$project_root <- project_root

  # Optional text fields
  for (field in c("researcher_name", "client_name")) {
    val <- general[[field]]
    general[[field]] <- if (!is.null(val) && !is.na(val) && nzchar(trimws(val))) trimws(val) else NULL
  }

  # Logo
  if (!is.null(general$logo_file) && !is.na(general$logo_file) && nzchar(trimws(general$logo_file))) {
    general$logo_file_resolved <- resolve_config_path(trimws(general$logo_file), project_root)
    if (!file.exists(general$logo_file_resolved)) {
      warning(sprintf("Logo file not found: %s (will use default logo)", general$logo_file_resolved))
      general$logo_file_resolved <- NULL
    }
  } else {
    general$logo_file_resolved <- NULL
  }

  # Colour settings
  for (field in c("brand_colour", "accent_colour")) {
    val <- general[[field]]
    general[[field]] <- if (!is.null(val) && !is.na(val) && nzchar(trimws(val))) trimws(val) else NULL
  }

  # HTML report
  general$html_report <- !is.null(general$html_report) && !is.na(general$html_report) &&
                          toupper(general$html_report) == "Y"
  if (general$html_report) {
    if (is.null(general$html_report_file) || is.na(general$html_report_file) ||
        general$html_report_file == "") {
      general$html_report_file_resolved <- if (!is.null(general$diagnostics_file_resolved)) {
        sub("\\.[^.]+$", ".html", general$diagnostics_file_resolved)
      } else if (!is.null(general$output_file_resolved)) {
        sub("\\.[^.]+$", "_report.html", general$output_file_resolved)
      } else {
        file.path(project_root, "Weighting_Report.html")
      }
    } else {
      general$html_report_file_resolved <- resolve_config_path(general$html_report_file, project_root)
    }
  } else {
    general$html_report_file_resolved <- NULL
  }

  if (verbose) {
    message("  Project: ", general$project_name)
    message("  Data file: ", basename(general$data_file))
  }

  general
}


#' Load and Validate Weight Specifications
#' @keywords internal
load_weight_specifications <- function(config_file, verbose = TRUE) {
  if (verbose) message("\nLoading Weight Specifications...")

  weight_specs_df <- tryCatch({
    readxl::read_excel(config_file, sheet = "Weight_Specifications")
  }, error = function(e) {
    weighting_refuse(
      code = "IO_SHEET_READ_ERROR",
      title = "Failed to read Weight_Specifications sheet",
      problem = sprintf("Could not read 'Weight_Specifications' sheet: %s", conditionMessage(e)),
      why_it_matters = "This sheet defines which weights to calculate",
      how_to_fix = "Check the sheet is not corrupted and is properly formatted"
    )
  })

  if (nrow(weight_specs_df) == 0) {
    weighting_refuse(
      code = "CFG_EMPTY_SHEET",
      title = "Weight_Specifications sheet is empty",
      problem = "No weight definitions found",
      why_it_matters = "At least one weight must be defined",
      how_to_fix = "Add at least one row with weight_name and method columns"
    )
  }

  required_cols <- c("weight_name", "method")
  missing_cols <- setdiff(required_cols, names(weight_specs_df))
  if (length(missing_cols) > 0) {
    weighting_refuse(
      code = "CFG_MISSING_COLUMNS",
      title = "Weight_Specifications missing required columns",
      problem = sprintf("Missing: %s", paste(missing_cols, collapse = ", ")),
      why_it_matters = "These columns are essential for weight definitions",
      how_to_fix = sprintf("Found: %s. Required: %s",
                          paste(names(weight_specs_df), collapse = ", "),
                          paste(required_cols, collapse = ", "))
    )
  }

  weight_names <- weight_specs_df$weight_name
  if (any(duplicated(weight_names))) {
    dups <- unique(weight_names[duplicated(weight_names)])
    weighting_refuse(
      code = "DATA_DUPLICATE_VALUES",
      title = "Duplicate weight names found",
      problem = sprintf("Duplicates: %s", paste(dups, collapse = ", ")),
      why_it_matters = "Each weight must have a unique name",
      how_to_fix = "Remove or rename duplicate weight entries"
    )
  }

  for (i in seq_len(nrow(weight_specs_df))) {
    spec <- as.list(weight_specs_df[i, ])
    validation <- validate_weight_spec(spec)
    if (!validation$valid) {
      weighting_refuse(
        code = "DATA_INVALID_SPEC",
        title = "Invalid weight specification",
        problem = sprintf("Weight '%s' has errors", spec$weight_name),
        why_it_matters = "All specs must be valid for correct weight calculation",
        how_to_fix = sprintf("Fix:\n  %s", paste(validation$errors, collapse = "\n  "))
      )
    }
  }

  if (verbose) {
    message("  Found ", nrow(weight_specs_df), " weight specification(s):")
    for (i in seq_len(nrow(weight_specs_df))) {
      message("    - ", weight_specs_df$weight_name[i], " (", weight_specs_df$method[i], ")")
    }
  }

  weight_specs_df
}


#' Load a Target Sheet (Design, Rim, or Cell Targets)
#'
#' Generic loader for method-specific target sheets. Only loads if
#' any weight specification uses the given method.
#'
#' @param config_file Path to config Excel file
#' @param available_sheets Character vector of available sheet names
#' @param weight_specs_df Weight specifications data frame
#' @param method_name Target method name (e.g. "design", "rim", "cell")
#' @param sheet_name Expected sheet name
#' @param required_cols Character vector of required columns
#' @param numeric_col Name of column to convert to numeric
#' @param verbose Logical
#' @return Data frame of targets, or NULL if method not used
#' @keywords internal
load_weighting_target_sheet <- function(config_file, available_sheets, weight_specs_df,
                                         method_name, sheet_name, required_cols,
                                         numeric_col, verbose = TRUE) {

  has_method <- any(tolower(weight_specs_df$method) == method_name)
  if (!has_method) return(NULL)

  if (!sheet_name %in% available_sheets) {
    method_weights <- weight_specs_df$weight_name[tolower(weight_specs_df$method) == method_name]
    weighting_refuse(
      code = "CFG_MISSING_SHEET",
      title = sprintf("%s sheet required", sheet_name),
      problem = sprintf("%s sheet is missing but required for %s weight(s): %s",
                       sheet_name, method_name, paste(method_weights, collapse = ", ")),
      why_it_matters = sprintf("%s weights require targets defined in the %s sheet",
                              tools::toTitleCase(method_name), sheet_name),
      how_to_fix = sprintf("Add a %s sheet with columns: %s",
                          sheet_name, paste(required_cols, collapse = ", "))
    )
  }

  if (verbose) message(sprintf("\nLoading %s...", sheet_name))

  targets <- tryCatch({
    readxl::read_excel(config_file, sheet = sheet_name)
  }, error = function(e) {
    weighting_refuse(
      code = "IO_SHEET_READ_ERROR",
      title = sprintf("Failed to read %s sheet", sheet_name),
      problem = sprintf("Could not read '%s': %s", sheet_name, conditionMessage(e)),
      why_it_matters = sprintf("The %s sheet contains targets needed for %s weights",
                              sheet_name, method_name),
      how_to_fix = "Check that the sheet is not corrupted and is properly formatted"
    )
  })

  missing_cols <- setdiff(required_cols, names(targets))
  if (length(missing_cols) > 0) {
    weighting_refuse(
      code = "CFG_MISSING_COLUMNS",
      title = sprintf("%s missing required columns", sheet_name),
      problem = sprintf("Missing: %s", paste(missing_cols, collapse = ", ")),
      why_it_matters = "These columns are essential for target definitions",
      how_to_fix = sprintf("Found: %s. Required: %s",
                          paste(names(targets), collapse = ", "),
                          paste(required_cols, collapse = ", "))
    )
  }

  targets[[numeric_col]] <- suppressWarnings(as.numeric(targets[[numeric_col]]))

  if (verbose) message("  Loaded ", nrow(targets), " ", method_name, " target rows")

  targets
}


#' Load an Optional Sheet (Advanced Settings)
#' @keywords internal
load_optional_sheet <- function(config_file, sheet_name, available_sheets, verbose = TRUE) {
  if (!sheet_name %in% available_sheets) return(NULL)
  if (verbose) message(sprintf("\nLoading %s...", sheet_name))

  result <- tryCatch({
    readxl::read_excel(config_file, sheet = sheet_name)
  }, error = function(e) {
    warning(sprintf("Failed to read '%s' sheet: %s\nUsing defaults.", sheet_name, conditionMessage(e)),
            call. = FALSE)
    NULL
  })

  if (!is.null(result) && nrow(result) > 0 && verbose) {
    message("  Loaded ", nrow(result), " row(s)")
  }
  result
}


#' Load Notes/Assumptions Sheet
#' @keywords internal
load_weighting_notes <- function(config_file, available_sheets, verbose = TRUE) {
  if (!"Notes" %in% available_sheets) return(NULL)
  if (verbose) message("\nLoading Notes/Assumptions...")

  notes <- tryCatch({
    readxl::read_excel(config_file, sheet = "Notes")
  }, error = function(e) {
    warning(sprintf("Failed to read 'Notes' sheet: %s", conditionMessage(e)), call. = FALSE)
    NULL
  })

  if (is.null(notes) || nrow(notes) == 0) return(NULL)

  if (!all(c("Section", "Note") %in% names(notes))) {
    names(notes) <- tolower(names(notes))
    if (!all(c("section", "note") %in% names(notes))) {
      warning("Notes sheet should have 'Section' and 'Note' columns. Ignoring.", call. = FALSE)
      return(NULL)
    }
    names(notes)[names(notes) == "section"] <- "Section"
    names(notes)[names(notes) == "note"] <- "Note"
  }

  notes <- notes[!is.na(notes$Note) & notes$Note != "", , drop = FALSE]
  if (verbose && nrow(notes) > 0) {
    message("  Loaded ", nrow(notes), " note(s) in sections: ",
            paste(unique(notes$Section), collapse = ", "))
  }
  notes
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
    weighting_refuse(
      code = "CFG_MISSING_COLUMNS",
      title = "General sheet missing required columns",
      problem = "General sheet must have 'Setting' and 'Value' columns",
      why_it_matters = "The General sheet uses a Setting/Value format to define configuration",
      how_to_fix = sprintf("Add 'Setting' and 'Value' columns to the General sheet. Found columns: %s", paste(names(df), collapse = ", "))
    )
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
    weighting_refuse(
      code = "CFG_WEIGHT_NOT_FOUND",
      title = "Weight specification not found",
      problem = sprintf("Weight '%s' not found in Weight_Specifications sheet", weight_name),
      why_it_matters = "Cannot retrieve specification for a weight that is not defined",
      how_to_fix = sprintf("Use one of the available weights: %s. Or add '%s' to the Weight_Specifications sheet",
                          paste(specs$weight_name, collapse = ", "),
                          weight_name)
    )
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

#' Get Cell Targets for Weight
#'
#' Retrieves cell/interlocked targets for a specific weight.
#'
#' @param config List, full configuration object
#' @param weight_name Character, name of weight
#' @return Data frame of cell targets (without weight_name column)
#' @export
get_cell_targets <- function(config, weight_name) {
  if (is.null(config$cell_targets)) {
    return(NULL)
  }

  targets <- config$cell_targets[config$cell_targets$weight_name == weight_name, , drop = FALSE]

  # Remove weight_name column (not needed downstream)
  targets$weight_name <- NULL

  return(targets)
}
