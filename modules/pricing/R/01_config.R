# ==============================================================================
# TURAS PRICING MODULE - CONFIGURATION MANAGEMENT
# ==============================================================================
#
# Purpose: Load and validate Excel configuration for pricing analysis
# Version: 1.0.0
# Date: 2025-11-18
#
# ==============================================================================

#' Load Pricing Configuration from Excel
#'
#' Reads and parses Excel configuration file for pricing analysis.
#' Supports both Van Westendorp and Gabor-Granger configurations.
#'
#' @param config_file Path to Excel configuration file
#'
#' @return List containing all configuration parameters organized by section
#'
#' @keywords internal
load_pricing_config <- function(config_file) {

  # Validate config file exists
  if (!file.exists(config_file)) {
    stop(sprintf("Configuration file not found: %s", config_file), call. = FALSE)
  }

  # Load Settings sheet
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required. Install with: install.packages('readxl')", call. = FALSE)
  }

  # Get available sheets
  sheets <- readxl::excel_sheets(config_file)

  if (!"Settings" %in% sheets) {
    stop("Configuration file must contain a 'Settings' sheet", call. = FALSE)
  }

  # Read Settings sheet
  settings_raw <- readxl::read_excel(config_file, sheet = "Settings")

  # Validate Settings sheet structure
  if (!all(c("Setting", "Value") %in% names(settings_raw))) {
    stop("Settings sheet must contain 'Setting' and 'Value' columns", call. = FALSE)
  }

  # Convert to named list
  settings <- setNames(
    as.list(settings_raw$Value),
    settings_raw$Setting
  )

  # Store project root (directory containing config file)
  config_dir <- dirname(normalizePath(config_file))
  settings$project_root <- config_dir

  # Resolve data_file path relative to config directory
  if (!is.null(settings$data_file) && !is.na(settings$data_file)) {
    # If not an absolute path, make it relative to config directory
    if (!grepl("^(/|[A-Za-z]:|\\.\\./|\\./)", settings$data_file)) {
      # Relative path - resolve to absolute path
      settings$data_file <- normalizePath(
        file.path(config_dir, settings$data_file),
        winslash = "/",
        mustWork = FALSE
      )
    } else if (file.exists(settings$data_file)) {
      # Already absolute and exists - normalize it
      settings$data_file <- normalizePath(settings$data_file, winslash = "/")
    }
  }

  # Resolve output_file path relative to config directory
  if (!is.null(settings$output_file) && !is.na(settings$output_file)) {
    if (!grepl("^(/|[A-Za-z]:)", settings$output_file)) {
      # Relative path - make it relative to config directory
      settings$output_file <- file.path(config_dir, settings$output_file)
    }
  }

  # Set default analysis method if not specified
  if (is.null(settings$analysis_method) || is.na(settings$analysis_method)) {
    settings$analysis_method <- "van_westendorp"
  }

  # Validate required settings
  validate_required_settings(settings)

  # Load method-specific configuration
  analysis_method <- tolower(settings$analysis_method)

  if (analysis_method %in% c("van_westendorp", "both")) {
    if ("VanWestendorp" %in% sheets) {
      settings$van_westendorp <- load_van_westendorp_config(config_file)
    } else {
      # Try to extract from Settings
      settings$van_westendorp <- extract_vw_settings(settings)
    }
  }

  if (analysis_method %in% c("gabor_granger", "both")) {
    if ("GaborGranger" %in% sheets) {
      settings$gabor_granger <- load_gabor_granger_config(config_file)
    } else {
      # Try to extract from Settings
      settings$gabor_granger <- extract_gg_settings(settings)
    }
  }

  # Load validation settings if present
  if ("Validation" %in% sheets) {
    settings$validation <- load_validation_config(config_file)
  } else {
    settings$validation <- get_default_validation()
  }

  # Load visualization settings if present
  if ("Visualization" %in% sheets) {
    settings$visualization <- load_visualization_config(config_file)
  } else {
    settings$visualization <- get_default_visualization()
  }

  # Apply defaults for missing optional settings
  settings <- apply_pricing_defaults(settings)

  return(settings)
}


#' Validate Required Settings
#'
#' @param settings List of settings
#' @keywords internal
validate_required_settings <- function(settings) {

  required <- c("analysis_method")

  missing <- required[!required %in% names(settings) |
                       sapply(settings[required], function(x) is.null(x) || is.na(x))]

  if (length(missing) > 0) {
    stop(sprintf("Missing required settings: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }

  # Validate analysis_method value
  valid_methods <- c("van_westendorp", "gabor_granger", "both")
  if (!tolower(settings$analysis_method) %in% valid_methods) {
    stop(sprintf("Invalid analysis_method: '%s'. Must be one of: %s",
                 settings$analysis_method, paste(valid_methods, collapse = ", ")),
         call. = FALSE)
  }
}


#' Load Van Westendorp Configuration
#'
#' @param config_file Path to config file
#' @return List of Van Westendorp settings
#' @keywords internal
load_van_westendorp_config <- function(config_file) {

  vw_raw <- readxl::read_excel(config_file, sheet = "VanWestendorp")

  if (!all(c("Setting", "Value") %in% names(vw_raw))) {
    stop("VanWestendorp sheet must contain 'Setting' and 'Value' columns", call. = FALSE)
  }

  vw <- setNames(as.list(vw_raw$Value), vw_raw$Setting)

  # Convert numeric fields
  numeric_fields <- c("violation_threshold", "confidence_level", "bootstrap_iterations",
                      "price_decimals")
  for (field in numeric_fields) {
    if (field %in% names(vw) && !is.na(vw[[field]])) {
      vw[[field]] <- as.numeric(vw[[field]])
    }
  }

  # Convert logical fields
  logical_fields <- c("validate_monotonicity", "exclude_violations", "calculate_confidence")
  for (field in logical_fields) {
    if (field %in% names(vw) && !is.na(vw[[field]])) {
      vw[[field]] <- as.logical(vw[[field]])
    }
  }

  return(vw)
}


#' Load Gabor-Granger Configuration
#'
#' @param config_file Path to config file
#' @return List of Gabor-Granger settings
#' @keywords internal
load_gabor_granger_config <- function(config_file) {

  gg_raw <- readxl::read_excel(config_file, sheet = "GaborGranger")

  if (!all(c("Setting", "Value") %in% names(gg_raw))) {
    stop("GaborGranger sheet must contain 'Setting' and 'Value' columns", call. = FALSE)
  }

  gg <- setNames(as.list(gg_raw$Value), gg_raw$Setting)

  # Parse price sequence if present
  if (!is.null(gg$price_sequence) && !is.na(gg$price_sequence)) {
    gg$price_sequence <- as.numeric(strsplit(as.character(gg$price_sequence), ",")[[1]])
  }

  # Parse response columns if present
  if (!is.null(gg$response_columns) && !is.na(gg$response_columns)) {
    gg$response_columns <- trimws(strsplit(as.character(gg$response_columns), ",")[[1]])
  }

  # Convert numeric fields
  numeric_fields <- c("scale_threshold", "bootstrap_iterations", "confidence_level",
                      "market_size", "unit_cost", "simulation_iterations")
  for (field in numeric_fields) {
    if (field %in% names(gg) && !is.na(gg[[field]])) {
      gg[[field]] <- as.numeric(gg[[field]])
    }
  }

  # Convert logical fields
  logical_fields <- c("check_monotonicity", "calculate_elasticity", "revenue_optimization",
                      "confidence_intervals", "run_simulation")
  for (field in logical_fields) {
    if (field %in% names(gg) && !is.na(gg[[field]])) {
      gg[[field]] <- as.logical(gg[[field]])
    }
  }

  return(gg)
}


#' Extract Van Westendorp Settings from Main Settings
#'
#' @param settings Main settings list
#' @return Van Westendorp configuration
#' @keywords internal
extract_vw_settings <- function(settings) {
  vw <- list()

  # Column mappings
  vw$col_too_cheap <- settings$vw_col_too_cheap %||% settings$col_too_cheap
  vw$col_cheap <- settings$vw_col_cheap %||% settings$col_cheap
  vw$col_expensive <- settings$vw_col_expensive %||% settings$col_expensive
  vw$col_too_expensive <- settings$vw_col_too_expensive %||% settings$col_too_expensive

  # Settings
  vw$validate_monotonicity <- as.logical(settings$vw_validate_monotonicity %||% TRUE)
  vw$exclude_violations <- as.logical(settings$vw_exclude_violations %||% FALSE)
  vw$violation_threshold <- as.numeric(settings$vw_violation_threshold %||% 0.1)
  vw$interpolation_method <- settings$vw_interpolation_method %||% "linear"
  vw$calculate_confidence <- as.logical(settings$vw_calculate_confidence %||% FALSE)
  vw$confidence_level <- as.numeric(settings$vw_confidence_level %||% 0.95)
  vw$bootstrap_iterations <- as.numeric(settings$vw_bootstrap_iterations %||% 1000)
  vw$price_decimals <- as.numeric(settings$vw_price_decimals %||% 2)

  return(vw)
}


#' Extract Gabor-Granger Settings from Main Settings
#'
#' @param settings Main settings list
#' @return Gabor-Granger configuration
#' @keywords internal
extract_gg_settings <- function(settings) {
  gg <- list()

  # Data format
  gg$data_format <- settings$gg_data_format %||% "wide"

  # Wide format settings
  if (!is.null(settings$gg_price_sequence) && !is.na(settings$gg_price_sequence)) {
    gg$price_sequence <- as.numeric(strsplit(as.character(settings$gg_price_sequence), ";")[[1]])
  }
  if (!is.null(settings$gg_response_columns) && !is.na(settings$gg_response_columns)) {
    gg$response_columns <- trimws(strsplit(as.character(settings$gg_response_columns), ";")[[1]])
  }

  # Long format settings
  gg$price_column <- settings$gg_price_column
  gg$response_column <- settings$gg_response_column
  gg$respondent_column <- settings$gg_respondent_column

  # Response coding
  gg$response_type <- settings$gg_response_type %||% "binary"
  gg$scale_threshold <- as.numeric(settings$gg_scale_threshold %||% 3)

  # Analysis options
  gg$check_monotonicity <- as.logical(settings$gg_check_monotonicity %||% TRUE)
  gg$calculate_elasticity <- as.logical(settings$gg_calculate_elasticity %||% TRUE)
  gg$revenue_optimization <- as.logical(settings$gg_revenue_optimization %||% TRUE)
  gg$confidence_intervals <- as.logical(settings$gg_confidence_intervals %||% FALSE)
  gg$bootstrap_iterations <- as.numeric(settings$gg_bootstrap_iterations %||% 1000)
  gg$confidence_level <- as.numeric(settings$gg_confidence_level %||% 0.95)

  # Simulation
  gg$run_simulation <- as.logical(settings$gg_run_simulation %||% FALSE)
  gg$market_size <- as.numeric(settings$gg_market_size %||% 10000)
  gg$unit_cost <- as.numeric(settings$gg_unit_cost %||% 0)

  return(gg)
}


#' Load Validation Configuration
#'
#' @param config_file Path to config file
#' @return Validation settings
#' @keywords internal
load_validation_config <- function(config_file) {
  val_raw <- readxl::read_excel(config_file, sheet = "Validation")
  setNames(as.list(val_raw$Value), val_raw$Setting)
}


#' Load Visualization Configuration
#'
#' @param config_file Path to config file
#' @return Visualization settings
#' @keywords internal
load_visualization_config <- function(config_file) {
  viz_raw <- readxl::read_excel(config_file, sheet = "Visualization")
  setNames(as.list(viz_raw$Value), viz_raw$Setting)
}


#' Get Default Validation Settings
#'
#' @return Default validation configuration
#' @keywords internal
get_default_validation <- function() {
  list(
    min_completeness = 0.8,
    price_min = 0,
    price_max = 10000,
    flag_outliers = TRUE,
    outlier_method = "iqr",
    outlier_threshold = 3
  )
}


#' Get Default Visualization Settings
#'
#' @return Default visualization configuration
#' @keywords internal
get_default_visualization <- function() {
  list(
    plot_theme = "minimal",
    color_palette = "default",
    font_family = "sans",
    base_font_size = 12,
    show_points = TRUE,
    show_range = TRUE,
    export_format = "png",
    plot_width = 10,
    plot_height = 7,
    plot_dpi = 300
  )
}


#' Apply Default Values for Missing Settings
#'
#' @param settings Current settings list
#' @return Settings with defaults applied
#' @keywords internal
apply_pricing_defaults <- function(settings) {

  # Project defaults
  settings$project_name <- settings$project_name %||% "Pricing Analysis"
  settings$currency_symbol <- settings$currency_symbol %||% "$"
  settings$verbose <- as.logical(settings$verbose %||% TRUE)

  # Weighting and segmentation
  settings$weight_var <- settings$weight_var %||% NA_character_
  if (!is.na(settings$weight_var) && settings$weight_var == "") {
    settings$weight_var <- NA_character_
  }

  # Segment variables (comma-separated list)
  if (!is.null(settings$segment_vars) && !is.na(settings$segment_vars)) {
    settings$segment_vars <- trimws(strsplit(as.character(settings$segment_vars), ",")[[1]])
    settings$segment_vars <- settings$segment_vars[settings$segment_vars != ""]
  } else {
    settings$segment_vars <- character(0)
  }

  # Cost for profit calculations
  settings$unit_cost <- if (!is.null(settings$unit_cost) && !is.na(settings$unit_cost)) {
    as.numeric(settings$unit_cost)
  } else {
    NA_real_
  }

  # Monotonicity behavior
  settings$vw_monotonicity_behavior <- settings$vw_monotonicity_behavior %||% "flag_only"
  valid_vw_mono <- c("drop", "fix", "flag_only")
  if (!settings$vw_monotonicity_behavior %in% valid_vw_mono) {
    warning(sprintf("Invalid vw_monotonicity_behavior: '%s'. Using 'flag_only'.",
                    settings$vw_monotonicity_behavior))
    settings$vw_monotonicity_behavior <- "flag_only"
  }

  settings$gg_monotonicity_behavior <- settings$gg_monotonicity_behavior %||% "smooth"
  valid_gg_mono <- c("diagnostic_only", "smooth")
  if (!settings$gg_monotonicity_behavior %in% valid_gg_mono) {
    warning(sprintf("Invalid gg_monotonicity_behavior: '%s'. Using 'smooth'.",
                    settings$gg_monotonicity_behavior))
    settings$gg_monotonicity_behavior <- "smooth"
  }

  # Don't know codes (comma-separated list of numeric codes)
  if (!is.null(settings$dk_codes) && !is.na(settings$dk_codes)) {
    dk_vals <- trimws(strsplit(as.character(settings$dk_codes), ",")[[1]])
    settings$dk_codes <- as.numeric(dk_vals)
    settings$dk_codes <- settings$dk_codes[!is.na(settings$dk_codes)]
  } else {
    settings$dk_codes <- numeric(0)
  }

  # ID variable for respondent-level operations
  settings$id_var <- settings$id_var %||% NA_character_
  if (!is.na(settings$id_var) && settings$id_var == "") {
    settings$id_var <- NA_character_
  }

  # --------------------------------------------------------------------------
  # NMS Extension Settings (Van Westendorp)
  # --------------------------------------------------------------------------
  if (is.null(settings$van_westendorp)) {
    settings$van_westendorp <- list()
  }

  # NMS purchase intent columns (optional)
  settings$van_westendorp$col_pi_cheap <- settings$vw_col_pi_cheap %||%
                                          settings$van_westendorp$col_pi_cheap %||%
                                          NA_character_
  settings$van_westendorp$col_pi_expensive <- settings$vw_col_pi_expensive %||%
                                               settings$van_westendorp$col_pi_expensive %||%
                                               NA_character_

  # --------------------------------------------------------------------------
  # Segmentation Settings
  # --------------------------------------------------------------------------
  settings$segmentation <- list(
    segment_column = settings$segment_column %||% NA_character_,
    min_segment_n = as.numeric(settings$min_segment_n %||% 50),
    include_total = as.logical(settings$include_total %||% TRUE)
  )

  # Clean up empty segment_column
  if (!is.na(settings$segmentation$segment_column) &&
      settings$segmentation$segment_column == "") {
    settings$segmentation$segment_column <- NA_character_
  }

  # --------------------------------------------------------------------------
  # Price Ladder Settings
  # --------------------------------------------------------------------------
  settings$price_ladder <- list(
    n_tiers = as.integer(settings$n_tiers %||% 3),
    tier_names = settings$tier_names %||% "Value;Standard;Premium",
    min_gap_pct = as.numeric(settings$min_gap_pct %||% 15),
    max_gap_pct = as.numeric(settings$max_gap_pct %||% 50),
    round_to = settings$round_to %||% "0.99",
    anchor = settings$anchor %||% "Standard"
  )

  # --------------------------------------------------------------------------
  # Synthesis Settings
  # --------------------------------------------------------------------------
  settings$synthesis <- list(
    price_floor = if (!is.null(settings$price_floor) && !is.na(settings$price_floor)) {
      as.numeric(settings$price_floor)
    } else NA_real_,
    price_ceiling = if (!is.null(settings$price_ceiling) && !is.na(settings$price_ceiling)) {
      as.numeric(settings$price_ceiling)
    } else NA_real_
  )

  return(settings)
}


#' Create Pricing Configuration Template
#'
#' Generates an Excel configuration template for pricing analysis.
#'
#' @param output_file Path where template should be saved
#' @param method Type of analysis: "van_westendorp", "gabor_granger", or "both"
#' @param overwrite Logical. Overwrite existing file?
#'
#' @return Invisible path to created file
#'
#' @export
create_pricing_config <- function(output_file = "pricing_config.xlsx",
                                  method = "van_westendorp",
                                  overwrite = FALSE) {

  if (file.exists(output_file) && !overwrite) {
    stop(sprintf("File already exists: %s. Use overwrite=TRUE to replace.", output_file),
         call. = FALSE)
  }

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')",
         call. = FALSE)
  }

  wb <- openxlsx::createWorkbook()

  # Header style
  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF",
    fgFill = "#003D5C",
    halign = "left",
    textDecoration = "bold"
  )

  # --------------------------------------------------------------------------
  # Settings Sheet
  # --------------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Settings")

  settings_data <- data.frame(
    Setting = c(
      "project_name",
      "analysis_method",
      "data_file",
      "output_file",
      "id_var",
      "weight_var",
      "unit_cost",
      "currency_symbol",
      "vw_monotonicity_behavior",
      "gg_monotonicity_behavior",
      "dk_codes",
      "verbose",
      "",
      "# SEGMENTATION",
      "segment_column",
      "min_segment_n",
      "include_total",
      "",
      "# PRICE LADDER",
      "n_tiers",
      "tier_names",
      "min_gap_pct",
      "max_gap_pct",
      "round_to",
      "anchor",
      "",
      "# CONSTRAINTS",
      "price_floor",
      "price_ceiling"
    ),
    Value = c(
      "My Pricing Study",
      method,
      "data/survey_data.csv",
      "pricing_results.xlsx",
      "respondent_id",
      "",
      "",
      "$",
      "flag_only",
      "smooth",
      "",
      "TRUE",
      "",
      "",
      "",
      "50",
      "TRUE",
      "",
      "",
      "3",
      "Value;Standard;Premium",
      "15",
      "50",
      "0.99",
      "Standard",
      "",
      "",
      "",
      ""
    ),
    Description = c(
      "Project name for reports",
      "van_westendorp, gabor_granger, or both",
      "Path to data file (relative to config)",
      "Path for output file",
      "Respondent ID column name",
      "Weight column name (optional)",
      "Unit cost for profit calculations (optional)",
      "Currency symbol for display",
      "VW monotonicity: drop, fix, or flag_only",
      "GG monotonicity: diagnostic_only or smooth",
      "Don't know codes (comma-separated, e.g., 98,99)",
      "Show progress messages",
      "",
      "Settings for segment-level analysis",
      "Column containing segment labels (optional)",
      "Minimum sample size per segment",
      "Include total sample in comparison",
      "",
      "Settings for Good/Better/Best tier generation",
      "Number of price tiers (2-4)",
      "Tier names (semicolon-separated)",
      "Minimum gap between tiers (%)",
      "Maximum gap between tiers (%)",
      "Price rounding: 0.99, 0.95, 0.00, none",
      "Which tier anchors to optimal price",
      "",
      "Price constraints for recommendation",
      "Minimum price constraint (optional)",
      "Maximum price constraint (optional)"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Settings", settings_data, headerStyle = header_style)
  openxlsx::setColWidths(wb, "Settings", cols = 1:3, widths = c(25, 30, 40))

  # --------------------------------------------------------------------------
  # Van Westendorp Sheet
  # --------------------------------------------------------------------------
  if (method %in% c("van_westendorp", "both")) {
    openxlsx::addWorksheet(wb, "VanWestendorp")

    vw_data <- data.frame(
      Setting = c(
        "col_too_cheap",
        "col_cheap",
        "col_expensive",
        "col_too_expensive",
        "validate_monotonicity",
        "exclude_violations",
        "violation_threshold",
        "interpolation_method",
        "calculate_confidence",
        "confidence_level",
        "bootstrap_iterations",
        "price_decimals",
        "",
        "# NMS EXTENSION (Optional)",
        "col_pi_cheap",
        "col_pi_expensive"
      ),
      Value = c(
        "q1_too_cheap",
        "q2_cheap",
        "q3_expensive",
        "q4_too_expensive",
        "TRUE",
        "FALSE",
        "0.1",
        "linear",
        "TRUE",
        "0.95",
        "1000",
        "2",
        "",
        "",
        "",
        ""
      ),
      Description = c(
        "Column: 'At what price too cheap?'",
        "Column: 'At what price a bargain?'",
        "Column: 'At what price getting expensive?'",
        "Column: 'At what price too expensive?'",
        "Check price sequence logic",
        "Remove cases with violations",
        "Max allowed violation rate (0-1)",
        "linear or spline",
        "Calculate bootstrap confidence intervals",
        "Confidence level (0-1)",
        "Number of bootstrap iterations",
        "Decimal places for price display",
        "",
        "Newton-Miller-Smith purchase intent calibration",
        "Purchase intent at 'bargain' price (0-100 scale)",
        "Purchase intent at 'expensive' price (0-100 scale)"
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "VanWestendorp", vw_data, headerStyle = header_style)
    openxlsx::setColWidths(wb, "VanWestendorp", cols = 1:3, widths = c(25, 25, 40))
  }

  # --------------------------------------------------------------------------
  # Gabor-Granger Sheet
  # --------------------------------------------------------------------------
  if (method %in% c("gabor_granger", "both")) {
    openxlsx::addWorksheet(wb, "GaborGranger")

    gg_data <- data.frame(
      Setting = c(
        "data_format",
        "price_sequence",
        "response_columns",
        "price_column",
        "response_column",
        "respondent_column",
        "response_type",
        "scale_threshold",
        "check_monotonicity",
        "calculate_elasticity",
        "revenue_optimization",
        "confidence_intervals",
        "bootstrap_iterations",
        "confidence_level"
      ),
      Value = c(
        "wide",
        "4.99;6.99;8.99;10.99;12.99",
        "buy_499;buy_699;buy_899;buy_1099;buy_1299",
        "price",
        "purchase_intent",
        "respondent_id",
        "binary",
        "3",
        "TRUE",
        "TRUE",
        "TRUE",
        "FALSE",
        "1000",
        "0.95"
      ),
      Description = c(
        "Data format: wide or long",
        "Price points (semicolon-separated) for wide format",
        "Response column names (semicolon-separated) for wide format",
        "Price column name for long format",
        "Response column name for long format",
        "Respondent ID column for long format",
        "binary, scale, or auto",
        "Top-box threshold if scale response",
        "Check for monotonic demand",
        "Calculate price elasticity",
        "Find revenue-maximizing price",
        "Calculate bootstrap confidence intervals",
        "Number of bootstrap iterations",
        "Confidence level (0-1)"
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "GaborGranger", gg_data, headerStyle = header_style)
    openxlsx::setColWidths(wb, "GaborGranger", cols = 1:3, widths = c(25, 35, 40))
  }

  # --------------------------------------------------------------------------
  # Validation Sheet
  # --------------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Validation")

  validation_data <- data.frame(
    Setting = c(
      "min_completeness",
      "price_min",
      "price_max",
      "flag_outliers",
      "outlier_method",
      "outlier_threshold"
    ),
    Value = c(
      "0.8",
      "0",
      "10000",
      "TRUE",
      "iqr",
      "3"
    ),
    Description = c(
      "Minimum response completeness (0-1)",
      "Minimum valid price value",
      "Maximum valid price value",
      "Flag statistical outliers",
      "iqr, zscore, or percentile",
      "Outlier detection threshold"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Validation", validation_data, headerStyle = header_style)
  openxlsx::setColWidths(wb, "Validation", cols = 1:3, widths = c(25, 20, 40))

  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = overwrite)

  cat(sprintf("Configuration template created: %s\n", output_file))
  cat(sprintf("Edit this file to configure your %s analysis.\n", method))

  invisible(output_file)
}
