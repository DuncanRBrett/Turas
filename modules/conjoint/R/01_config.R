# ==============================================================================
# CONJOINT CONFIG LOADER - ENHANCED WITH AUTODETECT & PHASE 3 SUPPORT
# ==============================================================================
#
# Module: Conjoint Analysis - Configuration
# Purpose: Load and validate conjoint study configuration
# Version: 3.0.0 (Conjoint Upgrade - HB, LC, HTML, Simulator)
# Date: 2026-03-09
#
# SUPPORTED DATA SOURCES:
#   - alchemer: Direct Alchemer CBC export (ResponseID, SetNumber, etc.)
#   - generic: Standard Turas format (resp_id, choice_set_id, etc.)
#
# CONFIG AUTODETECT:
#   Header row is auto-detected by scanning first 20 rows for
#   "Setting"/"Value" columns. Supports branded templates with
#   title/subtitle rows above the header.
#
# ==============================================================================

# ==============================================================================
# CONFIG AUTODETECT HEADING
# ==============================================================================

#' Find Header Row in Config Sheet
#'
#' Scans the first 20 rows of a sheet for the expected column headers.
#' This supports branded templates where title/subtitle rows appear above
#' the actual data header row.
#'
#' @param config_file Path to Excel file
#' @param sheet_name Sheet name to scan
#' @param required_cols Character vector of required column names
#' @param max_scan Integer, maximum rows to scan (default 20)
#' @return Integer row number where header was found, or 1 if not found (fallback)
#' @keywords internal
find_config_header_row <- function(config_file, sheet_name, required_cols,
                                   max_scan = 20) {
  # Read raw data without column names
  raw <- tryCatch({
    openxlsx::read.xlsx(config_file, sheet = sheet_name,
                        colNames = FALSE, rows = 1:max_scan)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(raw) || nrow(raw) == 0) return(1L)

  # Scan each row for the required column names

  for (r in seq_len(nrow(raw))) {
    row_vals <- as.character(unlist(raw[r, ]))
    row_vals <- trimws(row_vals)
    if (all(required_cols %in% row_vals)) {
      return(r)
    }
  }

  # Fallback: assume row 1 is the header
  1L
}


#' Clean Settings Data Frame
#'
#' Removes help/description rows (marked with [REQUIRED], [Optional]),
#' section divider rows (ALL CAPS with NA values), and empty rows
#' from a settings data frame.
#'
#' @param df Data frame with Setting and Value columns
#' @return Cleaned data frame
#' @keywords internal
.clean_settings_df <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(df)

  # Remove help/description rows
  if (any(grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                as.character(df$Setting), ignore.case = TRUE))) {
    df <- df[!grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                     as.character(df$Setting), ignore.case = TRUE), , drop = FALSE]
  }

  # Remove section divider rows (ALL CAPS names with NA in Value column)
  if (nrow(df) > 0) {
    section_dividers <- !is.na(df$Setting) &
                        grepl("^[A-Z][A-Z &]+$", trimws(as.character(df$Setting))) &
                        (is.na(df$Value) | trimws(as.character(df$Value)) == "")
    df <- df[!section_dividers, , drop = FALSE]
  }

  # Remove completely empty rows
  if (nrow(df) > 0) {
    all_na <- apply(df, 1, function(row) all(is.na(row) | trimws(as.character(row)) == ""))
    df <- df[!all_na, , drop = FALSE]
  }

  df
}


#' Load Conjoint Configuration
#'
#' Loads and validates conjoint study configuration from Excel file.
#' Supports autodetect heading (header can be in any of the first 20 rows),
#' all Phase 1-3 features including HB, latent class, WTP, and HTML output.
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
    conjoint_refuse(
      code = "IO_CONFIG_FILE_NOT_FOUND",
      title = "Configuration File Not Found",
      problem = sprintf("Configuration file not found: %s", config_file),
      why_it_matters = "The configuration file defines the conjoint study design, attributes, and analysis settings.",
      how_to_fix = c(
        "Verify the file path is correct",
        "Check that the file exists at the specified location",
        sprintf("Expected file: %s", config_file)
      )
    )
  }

  # Set project root to config file directory if not specified
  if (is.null(project_root)) {
    project_root <- dirname(normalizePath(config_file, winslash = "/"))
  }

  log_verbose(sprintf("Loading configuration from: %s", basename(config_file)), verbose)

  # =========================================================================
  # LOAD SETTINGS SHEET WITH AUTODETECT HEADING
  # =========================================================================

  # Check sheet exists
  sheet_names <- tryCatch({
    openxlsx::getSheetNames(config_file)
  }, error = function(e) {
    conjoint_refuse(
      code = "IO_CONFIG_FILE_INVALID",
      title = "Invalid Configuration File",
      problem = sprintf("Cannot read Excel file: %s", e$message),
      why_it_matters = "The configuration file must be a valid .xlsx Excel file.",
      how_to_fix = c(
        "Verify the file is a valid .xlsx file (not .xls or other format)",
        "Check the file is not corrupted or locked by another application",
        sprintf("File: %s", config_file)
      )
    )
  })

  if (!"Settings" %in% sheet_names) {
    conjoint_refuse(
      code = "CFG_SETTINGS_SHEET_MISSING",
      title = "Settings Sheet Not Found",
      problem = "Configuration file does not contain a 'Settings' sheet.",
      why_it_matters = "The Settings sheet contains essential analysis parameters like data file paths and estimation method.",
      how_to_fix = c(
        "Add a sheet named 'Settings' to your configuration file",
        "Use generate_conjoint_config_template() to create a properly formatted template",
        sprintf("Available sheets: %s", paste(sheet_names, collapse = ", "))
      )
    )
  }

  # Autodetect header row
  settings_header_row <- find_config_header_row(
    config_file, "Settings",
    required_cols = c("Setting", "Value")
  )

  if (settings_header_row > 1) {
    log_verbose(sprintf("  ℹ Settings header detected at row %d", settings_header_row), verbose)
  }

  # Load Settings sheet starting at detected header row
  settings_df <- tryCatch({
    openxlsx::read.xlsx(config_file, sheet = "Settings",
                        startRow = settings_header_row)
  }, error = function(e) {
    conjoint_refuse(
      code = "CFG_SETTINGS_READ_FAILED",
      title = "Failed to Read Settings Sheet",
      problem = sprintf("Error reading Settings sheet: %s", e$message),
      why_it_matters = "The Settings sheet contains essential analysis parameters.",
      how_to_fix = c(
        "Verify the Excel file has a sheet named 'Settings'",
        "Ensure the sheet has 'Setting' and 'Value' columns",
        sprintf("File: %s", config_file)
      )
    )
  })

  # Validate Settings sheet structure
  if (!all(c("Setting", "Value") %in% names(settings_df))) {
    conjoint_refuse(
      code = "CFG_SETTINGS_INVALID_FORMAT",
      title = "Settings Sheet Format Invalid",
      problem = "Settings sheet missing required columns.",
      why_it_matters = "The Settings sheet must follow the standard format to be parsed correctly.",
      how_to_fix = c(
        "Settings sheet must have 'Setting' and 'Value' columns",
        sprintf("Found columns: %s", paste(names(settings_df), collapse = ", ")),
        "Use generate_conjoint_config_template() to create a properly formatted template"
      )
    )
  }

  # Clean settings: remove help rows, section dividers, empty rows
  settings_df <- .clean_settings_df(settings_df)

  # Convert to named list
  settings_list <- setNames(as.list(settings_df$Value), settings_df$Setting)

  # Remove NA settings
  settings_list <- settings_list[
    !is.na(names(settings_list)) &
    names(settings_list) != ""
  ]

  # =========================================================================
  # LOAD ATTRIBUTES SHEET WITH AUTODETECT HEADING
  # =========================================================================

  if (!"Attributes" %in% sheet_names) {
    conjoint_refuse(
      code = "CFG_ATTRIBUTES_SHEET_MISSING",
      title = "Attributes Sheet Not Found",
      problem = "Configuration file does not contain an 'Attributes' sheet.",
      why_it_matters = "The Attributes sheet defines the product features and levels that will be tested in the conjoint study.",
      how_to_fix = c(
        "Add a sheet named 'Attributes' to your configuration file",
        "This sheet should contain columns: AttributeName, NumLevels, LevelNames",
        "Use generate_conjoint_config_template() to create a properly formatted template"
      )
    )
  }

  # Autodetect header row for Attributes sheet
  attr_header_row <- find_config_header_row(
    config_file, "Attributes",
    required_cols = c("AttributeName", "NumLevels", "LevelNames")
  )

  if (attr_header_row > 1) {
    log_verbose(sprintf("  ℹ Attributes header detected at row %d", attr_header_row), verbose)
  }

  attributes_df <- tryCatch({
    openxlsx::read.xlsx(config_file, sheet = "Attributes",
                        startRow = attr_header_row)
  }, error = function(e) {
    conjoint_refuse(
      code = "CFG_ATTRIBUTES_READ_FAILED",
      title = "Failed to Read Attributes Sheet",
      problem = sprintf("Error reading Attributes sheet: %s", e$message),
      why_it_matters = "The Attributes sheet defines the product features and levels for the conjoint study.",
      how_to_fix = c(
        "Verify the Attributes sheet has columns: AttributeName, NumLevels, LevelNames",
        sprintf("File: %s", config_file)
      )
    )
  })

  # Validate Attributes sheet structure
  required_cols <- c("AttributeName", "NumLevels", "LevelNames")
  missing_cols <- setdiff(required_cols, names(attributes_df))
  if (length(missing_cols) > 0) {
    conjoint_refuse(
      code = "CFG_ATTRIBUTES_INVALID_FORMAT",
      title = "Attributes Sheet Format Invalid",
      problem = sprintf("Attributes sheet missing required columns: %s", paste(missing_cols, collapse = ", ")),
      why_it_matters = "All three columns are required to properly define the conjoint study attributes and their levels.",
      how_to_fix = c(
        sprintf("Add these columns: %s", paste(missing_cols, collapse = ", ")),
        "Required columns: AttributeName, NumLevels, LevelNames",
        "Refer to the configuration template for the correct format"
      )
    )
  }

  # Parse level names
  attributes_df$levels_list <- lapply(attributes_df$LevelNames, parse_level_names)

  # Validate config
  validation_result <- validate_config(settings_list, attributes_df)

  if (!validation_result$is_valid) {
    conjoint_refuse(
      code = "CFG_VALIDATION_FAILED",
      title = "Configuration Validation Failed",
      problem = "Configuration contains errors that prevent analysis.",
      why_it_matters = "Invalid configuration will lead to incorrect or failed analysis.",
      how_to_fix = c(
        "Review and fix the following errors:",
        validation_result$errors
      ),
      details = paste(validation_result$errors, collapse = "; ")
    )
  }

  # Print warnings if any
  if (length(validation_result$warnings) > 0) {
    for (warning_msg in validation_result$warnings) {
      message(sprintf("[TRS INFO] CONJ_CONFIG_WARNING: %s", warning_msg))
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

    # =========================================================================
    # HIERARCHICAL BAYES SETTINGS (Phase 3 Upgrade)
    # =========================================================================

    hb_iterations = safe_numeric(settings_list$hb_iterations, 10000),
    hb_burnin = safe_numeric(settings_list$hb_burnin, 5000),
    hb_thin = safe_numeric(settings_list$hb_thin, 1),
    hb_ncomp = safe_numeric(settings_list$hb_ncomp, 1),
    hb_prior_variance = safe_numeric(settings_list$hb_prior_variance, 2),

    # =========================================================================
    # LATENT CLASS SETTINGS (Phase 3 Upgrade)
    # =========================================================================

    latent_class_min = safe_numeric(settings_list$latent_class_min, 2),
    latent_class_max = safe_numeric(settings_list$latent_class_max, 5),
    latent_class_criterion = settings_list$latent_class_criterion %||% "bic",

    # =========================================================================
    # SIMULATION SETTINGS (Phase 3 Upgrade)
    # =========================================================================

    simulation_method = settings_list$simulation_method %||% "logit",
    rfc_draws = safe_numeric(settings_list$rfc_draws, 1000),

    # =========================================================================
    # WILLINGNESS TO PAY SETTINGS (Phase 3 Upgrade)
    # =========================================================================

    wtp_price_attribute = settings_list$wtp_price_attribute %||% NA_character_,
    wtp_method = settings_list$wtp_method %||% "marginal",

    # =========================================================================
    # HTML OUTPUT SETTINGS (Phase 3 Upgrade)
    # =========================================================================

    generate_html_report = safe_logical(settings_list$generate_html_report, FALSE),
    generate_html_simulator = safe_logical(settings_list$generate_html_simulator, FALSE),
    brand_colour = settings_list$brand_colour %||% "#323367",
    accent_colour = settings_list$accent_colour %||% "#CC9900",

    # =========================================================================
    # HTML REPORT SETTINGS
    # =========================================================================

    project_name = settings_list$project_name %||% "Conjoint Analysis",
    insight_overview = settings_list$insight_overview %||% "",
    insight_utilities = settings_list$insight_utilities %||% "",
    insight_diagnostics = settings_list$insight_diagnostics %||% "",
    insight_simulator = settings_list$insight_simulator %||% "",
    insight_wtp = settings_list$insight_wtp %||% "",

    # =========================================================================
    # ABOUT PAGE SETTINGS
    # =========================================================================

    analyst_name = settings_list$analyst_name %||% "",
    analyst_email = settings_list$analyst_email %||% "",
    analyst_phone = settings_list$analyst_phone %||% "",
    client_name = settings_list$client_name %||% "",
    company_name = settings_list$company_name %||% "",
    closing_notes = settings_list$closing_notes %||% "",
    researcher_logo_base64 = settings_list$researcher_logo_base64 %||% "",

    # =========================================================================
    # PRODUCT OPTIMIZER SETTINGS (Phase 3 Upgrade)
    # =========================================================================

    optimizer_method = settings_list$optimizer_method %||% "exhaustive",
    optimizer_max_products = safe_numeric(settings_list$optimizer_max_products, 5),

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
  valid_methods <- c("auto", "mlogit", "clogit", "hb", "latent_class")
  if (!estimation_method %in% valid_methods) {
    errors <- c(errors, sprintf(
      "estimation_method must be one of: %s (got: %s)",
      paste(valid_methods, collapse = ", "),
      estimation_method
    ))
  }

  # Validate HB settings (if HB selected)
  if (estimation_method == "hb") {
    hb_iter <- safe_numeric(settings_list$hb_iterations, 10000)
    hb_burn <- safe_numeric(settings_list$hb_burnin, 5000)
    if (hb_burn >= hb_iter) {
      errors <- c(errors, sprintf(
        "hb_burnin (%d) must be less than hb_iterations (%d)",
        hb_burn, hb_iter
      ))
    }
    if (hb_iter < 1000) {
      warnings <- c(warnings,
        "hb_iterations < 1000 may produce unreliable estimates. Recommend 10000+"
      )
    }
  }

  # Validate latent class settings (if LC selected)
  if (estimation_method == "latent_class") {
    lc_min <- safe_numeric(settings_list$latent_class_min, 2)
    lc_max <- safe_numeric(settings_list$latent_class_max, 5)
    if (lc_min < 2) {
      errors <- c(errors, "latent_class_min must be at least 2")
    }
    if (lc_max > 6) {
      warnings <- c(warnings,
        "latent_class_max > 6 may be slow and risk over-fitting"
      )
    }
    if (lc_min > lc_max) {
      errors <- c(errors, sprintf(
        "latent_class_min (%d) must be <= latent_class_max (%d)",
        lc_min, lc_max
      ))
    }
  }

  # Validate simulation_method
  sim_method <- settings_list$simulation_method %||% "logit"
  valid_sim <- c("logit", "first_choice", "rfc")
  if (!sim_method %in% valid_sim) {
    errors <- c(errors, sprintf(
      "simulation_method must be one of: %s (got: %s)",
      paste(valid_sim, collapse = ", "),
      sim_method
    ))
  }

  # Validate optimizer_method
  opt_method <- settings_list$optimizer_method %||% "exhaustive"
  if (!opt_method %in% c("exhaustive", "genetic")) {
    errors <- c(errors, sprintf(
      "optimizer_method must be 'exhaustive' or 'genetic' (got: %s)",
      opt_method
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
    conjoint_refuse(
      code = "IO_CONFIG_PATH_NOT_FOUND",
      title = "Configuration File Path Invalid",
      problem = sprintf("File specified in '%s' not found", setting_name),
      why_it_matters = "The configuration references a file that doesn't exist, preventing the analysis from loading required data.",
      how_to_fix = c(
        "Verify the file path is correct in your config",
        sprintf("Looking for: %s", resolved_path),
        "Check if the path is relative (resolved from config directory) or absolute"
      )
    )
  }

  resolved_path
}
