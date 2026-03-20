# ==============================================================================
# TURAS PRICING MODULE - CONFIGURATION MANAGEMENT
# ==============================================================================
#
# Purpose: Load and validate Excel configuration for pricing analysis
#          Supports autodetect heading row (header not always in row 1)
# Version: 12.0
# Date: 2026-03-09
#
# ==============================================================================

#' Read a Settings-style Sheet with Autodetect Heading
#'
#' Reads an Excel sheet that has Setting/Value columns, automatically
#' detecting the header row if it's not in row 1 (e.g., template files
#' with title/subtitle rows above the headers).
#'
#' @param config_file Path to Excel configuration file
#' @param sheet_name Name of the sheet to read
#' @param required_cols Column names that must be present (default: Setting, Value)
#'
#' @return Data frame with Setting/Value columns, cleaned of help rows
#' @keywords internal
read_settings_sheet <- function(config_file, sheet_name,
                                required_cols = c("Setting", "Value")) {

  # Attempt 1: Standard read (headers in row 1)
  df <- tryCatch(
    readxl::read_excel(config_file, sheet = sheet_name),
    error = function(e) NULL
  )

  if (!is.null(df) && all(required_cols %in% names(df))) {
    # Headers found in row 1 — clean and return
    return(.clean_settings_df(df))
  }

  # Attempt 2: Autodetect header row by scanning first 10 rows
  raw <- suppressMessages(
    readxl::read_excel(config_file, sheet = sheet_name,
                       col_names = FALSE, n_max = 10)
  )

  header_row <- NULL
  for (r in seq_len(nrow(raw))) {
    row_vals <- tolower(trimws(as.character(unlist(raw[r, ]))))
    if (all(tolower(required_cols) %in% row_vals)) {
      header_row <- r
      break
    }
  }

  if (!is.null(header_row)) {
    df <- readxl::read_excel(config_file, sheet = sheet_name,
                             skip = header_row - 1)
    if (all(required_cols %in% names(df))) {
      return(.clean_settings_df(df))
    }
  }

  # Neither attempt found required columns
  pricing_refuse(
    code = sprintf("CFG_INVALID_%s_FORMAT", toupper(gsub("[^A-Za-z]", "_", sheet_name))),
    title = sprintf("Invalid %s Sheet Format", sheet_name),
    problem = sprintf("%s sheet must have columns: %s",
                      sheet_name, paste(required_cols, collapse = ", ")),
    why_it_matters = "Cannot parse configuration without proper column structure",
    how_to_fix = c(
      sprintf("Ensure %s sheet has columns: %s", sheet_name,
              paste(required_cols, collapse = ", ")),
      "Use generate_pricing_config_template() to create a properly formatted template"
    ),
    observed = if (!is.null(df)) names(df) else "could not read sheet",
    expected = required_cols
  )
}


#' Clean a Settings Data Frame
#'
#' Removes help/description rows (prefixed with [REQUIRED] or [Optional]),
#' section header rows (prefixed with #), and completely empty rows.
#'
#' @param df Data frame with Setting/Value columns
#' @return Cleaned data frame
#' @keywords internal
.clean_settings_df <- function(df) {
  if (nrow(df) == 0) return(df)

  first_col <- as.character(df[[1]])
  second_col <- if (ncol(df) >= 2) as.character(df[[2]]) else rep(NA, nrow(df))

  # Remove help text rows from template
  help_rows <- grepl("^\\[REQUIRED\\]|^\\[Optional\\]", first_col, ignore.case = TRUE)

  # Remove section header rows (from old-style configs with # prefix)
  section_rows <- grepl("^#\\s", first_col)

  # Remove template section headers (setting name in col 1, NA in col 2,
  # typically ALL CAPS — these are merged section dividers from the template)
  section_dividers <- !is.na(first_col) & is.na(second_col) &
    grepl("^[A-Z &/()]+$", first_col, perl = TRUE)

  # Remove completely empty rows
  all_na <- apply(df, 1, function(row) all(is.na(row) | trimws(as.character(row)) == ""))

  keep <- !help_rows & !section_rows & !section_dividers & !all_na
  df <- df[keep, , drop = FALSE]

  rownames(df) <- NULL
  df
}


#' Load Pricing Configuration from Excel
#'
#' Reads and parses Excel configuration file for pricing analysis.
#' Supports Van Westendorp, Gabor-Granger, and Monadic configurations.
#' Automatically detects header row position (handles template files
#' where headers are not in row 1).
#'
#' @param config_file Path to Excel configuration file
#'
#' @return List containing all configuration parameters organized by section
#'
#' @keywords internal
load_pricing_config <- function(config_file) {

  # Validate config file exists
  if (!file.exists(config_file)) {
    pricing_refuse(
      code = "IO_CONFIG_NOT_FOUND",
      title = "Configuration File Not Found",
      problem = sprintf("Could not locate configuration file at: %s", config_file),
      why_it_matters = "Cannot run analysis without configuration specifying data sources and methods",
      how_to_fix = c(
        "Check the file path is correct",
        "Ensure the configuration file exists",
        "Use generate_pricing_config_template() to generate a template if needed"
      )
    )
  }

  # Check for readxl
  if (!requireNamespace("readxl", quietly = TRUE)) {
    pricing_refuse(
      code = "PKG_READXL_MISSING",
      title = "Required Package Missing",
      problem = "Package 'readxl' is not installed",
      why_it_matters = "Cannot read Excel configuration files without readxl package",
      how_to_fix = "Install the package: install.packages('readxl')"
    )
  }

  # Get available sheets
  sheets <- readxl::excel_sheets(config_file)

  if (!"Settings" %in% sheets) {
    pricing_refuse(
      code = "CFG_MISSING_SETTINGS_SHEET",
      title = "Missing Settings Sheet",
      problem = "Configuration file does not contain required 'Settings' sheet",
      why_it_matters = "The Settings sheet contains core configuration needed for analysis",
      how_to_fix = c(
        "Add a 'Settings' sheet to your configuration file",
        "Use generate_pricing_config_template() to generate a properly formatted template"
      ),
      observed = sheets,
      expected = "Settings"
    )
  }

  # Read Settings sheet with autodetect heading
  settings_raw <- read_settings_sheet(config_file, "Settings")

  # Convert to named list (case-insensitive setting name matching)
  settings <- setNames(
    as.list(settings_raw$Value),
    settings_raw$Setting
  )

  # Normalize setting names: allow both old-style (lowercase) and template-style (Title_Case)
  settings <- .normalize_setting_names(settings)

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

  if (analysis_method == "monadic") {
    if ("Monadic" %in% sheets) {
      settings$monadic <- load_monadic_config(config_file)
    } else {
      pricing_refuse(
        code = "CFG_MISSING_MONADIC_SHEET",
        title = "Missing Monadic Sheet",
        problem = "Analysis method is 'monadic' but no Monadic sheet found in config",
        why_it_matters = "Monadic analysis requires column mappings and model settings",
        how_to_fix = c(
          "Add a 'Monadic' sheet to your configuration file",
          "Use generate_pricing_config_template() to create a template with all sheets"
        ),
        observed = sheets,
        expected = "Monadic"
      )
    }
  }

  # Load simulator scenarios if present
  if ("Simulator" %in% sheets) {
    settings$simulator_scenarios <- load_simulator_config(config_file)
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

  # Load insights from config (optional Comments/Insights sheet)
  settings$insights <- tryCatch({
    load_insights_config(config_file)
  }, error = function(e) list())

  # Load added slides (optional AddedSlides sheet)
  settings$added_slides <- tryCatch({
    load_added_slides(config_file)
  }, error = function(e) NULL)

  return(settings)
}


#' Normalize Setting Names
#'
#' Maps template-style Title_Case names to internal lowercase names.
#' Supports both styles so old and new configs both work.
#'
#' @param settings Named list of settings
#' @return Settings with normalized names
#' @keywords internal
.normalize_setting_names <- function(settings) {
  # Map template names to internal names
  name_map <- c(
    "Project_Name" = "project_name",
    "Analysis_Method" = "analysis_method",
    "Data_File" = "data_file",
    "Output_File" = "output_file",
    "ID_Variable" = "id_var",
    "Weight_Variable" = "weight_var",
    "Currency_Symbol" = "currency_symbol",
    "Unit_Cost" = "unit_cost",
    "DK_Codes" = "dk_codes",
    "Generate_HTML_Report" = "generate_html_report",
    "Generate_Simulator" = "generate_simulator",
    "Brand_Colour" = "brand_colour",
    "VW_Monotonicity_Behavior" = "vw_monotonicity_behavior",
    "GG_Monotonicity_Behavior" = "gg_monotonicity_behavior",
    "Segment_Column" = "segment_column",
    "Min_Segment_N" = "min_segment_n",
    "Include_Total" = "include_total",
    "N_Tiers" = "n_tiers",
    "Tier_Names" = "tier_names",
    "Min_Gap_Pct" = "min_gap_pct",
    "Max_Gap_Pct" = "max_gap_pct",
    "Round_To" = "round_to",
    "Price_Floor" = "price_floor",
    "Price_Ceiling" = "price_ceiling"
  )

  nms <- names(settings)
  for (i in seq_along(nms)) {
    if (nms[i] %in% names(name_map)) {
      # Only add the normalized name if the internal name doesn't already exist
      internal <- name_map[nms[i]]
      if (!internal %in% nms) {
        settings[[internal]] <- settings[[nms[i]]]
      }
    }
  }
  settings
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
    pricing_refuse(
      code = "CFG_MISSING_REQUIRED",
      title = "Missing Required Configuration Settings",
      problem = sprintf("Required setting(s) not found: %s", paste(missing, collapse = ", ")),
      why_it_matters = "Cannot run analysis without essential configuration parameters",
      how_to_fix = c(
        "Add the missing settings to your Settings sheet:",
        sprintf("  - %s", paste(missing, collapse = "\n  - "))
      ),
      missing = missing,
      expected = required
    )
  }

  # Validate analysis_method value
  valid_methods <- c("van_westendorp", "gabor_granger", "monadic", "both")
  if (!tolower(settings$analysis_method) %in% valid_methods) {
    pricing_refuse(
      code = "CFG_INVALID_METHOD",
      title = "Invalid Analysis Method",
      problem = sprintf("Analysis method '%s' is not recognized", settings$analysis_method),
      why_it_matters = "Cannot run analysis without specifying a valid methodology",
      how_to_fix = c(
        "Set Analysis_Method in Settings sheet to one of:",
        "  - 'van_westendorp' for price sensitivity meter",
        "  - 'gabor_granger' for demand curve analysis",
        "  - 'monadic' for randomized cell monadic testing",
        "  - 'both' for combined VW + GG analysis"
      ),
      observed = settings$analysis_method,
      expected = valid_methods
    )
  }
}


#' Load Van Westendorp Configuration
#'
#' @param config_file Path to config file
#' @return List of Van Westendorp settings
#' @keywords internal
load_van_westendorp_config <- function(config_file) {

  vw_raw <- read_settings_sheet(config_file, "VanWestendorp")
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

  gg_raw <- read_settings_sheet(config_file, "GaborGranger")
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
  val_raw <- read_settings_sheet(config_file, "Validation")
  settings <- setNames(as.list(val_raw$Value), val_raw$Setting)
  # Normalize template names
  name_map <- c(
    "Min_Completeness" = "min_completeness",
    "Min_Sample" = "min_sample",
    "Price_Min" = "price_min",
    "Price_Max" = "price_max",
    "Flag_Outliers" = "flag_outliers",
    "Outlier_Method" = "outlier_method",
    "Outlier_Threshold" = "outlier_threshold"
  )
  nms <- names(settings)
  for (i in seq_along(nms)) {
    if (nms[i] %in% names(name_map) && !name_map[nms[i]] %in% nms) {
      settings[[name_map[nms[i]]]] <- settings[[nms[i]]]
    }
  }
  settings
}


#' Load Visualization Configuration
#'
#' @param config_file Path to config file
#' @return Visualization settings
#' @keywords internal
load_visualization_config <- function(config_file) {
  viz_raw <- read_settings_sheet(config_file, "Visualization")
  setNames(as.list(viz_raw$Value), viz_raw$Setting)
}


#' Load Monadic Configuration
#'
#' @param config_file Path to config file
#' @return Monadic settings list
#' @keywords internal
load_monadic_config <- function(config_file) {
  mon_raw <- read_settings_sheet(config_file, "Monadic")
  mon <- setNames(as.list(mon_raw$Value), mon_raw$Setting)

  # Normalize template names to internal names
  name_map <- c(
    "Price_Column" = "price_column",
    "Intent_Column" = "intent_column",
    "Intent_Type" = "intent_type",
    "Scale_Threshold" = "scale_threshold",
    "Model_Type" = "model_type",
    "Min_Cell_Size" = "min_cell_size",
    "Prediction_Points" = "prediction_points",
    "Confidence_Intervals" = "confidence_intervals",
    "Bootstrap_Iterations" = "bootstrap_iterations",
    "Confidence_Level" = "confidence_level"
  )
  nms <- names(mon)
  for (i in seq_along(nms)) {
    if (nms[i] %in% names(name_map) && !name_map[nms[i]] %in% nms) {
      mon[[name_map[nms[i]]]] <- mon[[nms[i]]]
    }
  }

  # Convert numeric fields
  numeric_fields <- c("scale_threshold", "min_cell_size", "prediction_points",
                       "bootstrap_iterations", "confidence_level")
  for (field in numeric_fields) {
    if (field %in% names(mon) && !is.na(mon[[field]])) {
      mon[[field]] <- as.numeric(mon[[field]])
    }
  }

  # Convert logical fields
  logical_fields <- c("confidence_intervals")
  for (field in logical_fields) {
    if (field %in% names(mon) && !is.na(mon[[field]])) {
      mon[[field]] <- as.logical(mon[[field]])
    }
  }

  # Apply defaults
  mon$intent_type <- mon$intent_type %||% "binary"
  mon$model_type <- mon$model_type %||% "logistic"
  mon$min_cell_size <- mon$min_cell_size %||% 30
  mon$prediction_points <- mon$prediction_points %||% 100
  mon$confidence_intervals <- mon$confidence_intervals %||% TRUE
  mon$bootstrap_iterations <- mon$bootstrap_iterations %||% 1000
  mon$confidence_level <- mon$confidence_level %||% 0.95

  mon
}


#' Load Simulator Scenarios Configuration
#'
#' Reads the Simulator sheet (table format) containing preset scenarios
#' for the interactive pricing simulator.
#'
#' @param config_file Path to config file
#' @return List of scenario definitions
#' @keywords internal
load_simulator_config <- function(config_file) {

  # Read raw — table format, so headers should be column names
  raw <- tryCatch(
    readxl::read_excel(config_file, sheet = "Simulator"),
    error = function(e) NULL
  )

  if (is.null(raw)) return(list())

  # Autodetect header row for table sheets
  required_col <- "Scenario_Name"
  if (!required_col %in% names(raw)) {
    # Scan first 10 rows
    raw_scan <- suppressMessages(
      readxl::read_excel(config_file, sheet = "Simulator",
                         col_names = FALSE, n_max = 10)
    )
    header_row <- NULL
    for (r in seq_len(nrow(raw_scan))) {
      row_vals <- trimws(as.character(unlist(raw_scan[r, ])))
      if (required_col %in% row_vals) {
        header_row <- r
        break
      }
    }
    if (!is.null(header_row)) {
      raw <- readxl::read_excel(config_file, sheet = "Simulator",
                                skip = header_row - 1)
    }
  }

  if (!required_col %in% names(raw)) return(list())

  # Filter out help rows and empty rows
  first_col <- as.character(raw[[1]])
  help_rows <- grepl("^\\[REQUIRED\\]|^\\[Optional\\]", first_col, ignore.case = TRUE)
  all_na <- apply(raw, 1, function(row) all(is.na(row) | trimws(as.character(row)) == ""))
  raw <- raw[!help_rows & !all_na, , drop = FALSE]

  if (nrow(raw) == 0) return(list())

  # Convert to list of scenarios
  scenarios <- lapply(seq_len(nrow(raw)), function(i) {
    row <- as.list(raw[i, ])
    # Clean NAs
    row <- lapply(row, function(x) if (is.na(x)) NULL else x)
    row
  })

  scenarios
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

  # Output options
  settings$generate_html_report <- as.logical(settings$generate_html_report %||% TRUE)
  settings$generate_simulator <- as.logical(settings$generate_simulator %||% FALSE)
  settings$brand_colour <- settings$brand_colour %||% "#1e3a5f"

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


#' Load Insights from Config Excel
#'
#' Reads the "Insights" (or "Comments") sheet from the config file.
#' Expects columns: Section, Insight_Text
#'
#' @param config_file Path to the Excel config file
#' @return Named list of insight text keyed by section name
#' @keywords internal
load_insights_config <- function(config_file) {
  sheets <- readxl::excel_sheets(config_file)

  sheet_name <- NULL
  for (s in c("Insights", "Comments", "insights", "comments")) {
    if (s %in% sheets) { sheet_name <- s; break }
  }
  if (is.null(sheet_name)) return(list())

  df <- tryCatch(
    readxl::read_excel(config_file, sheet = sheet_name),
    error = function(e) NULL
  )
  if (is.null(df) || nrow(df) == 0) return(list())

  # Normalize column names
  names(df) <- tolower(trimws(names(df)))

  section_col <- NULL
  text_col <- NULL
  for (n in names(df)) {
    if (grepl("section", n)) section_col <- n
    if (grepl("insight|text|comment", n)) text_col <- n
  }
  if (is.null(section_col) || is.null(text_col)) return(list())

  result <- list()
  for (i in seq_len(nrow(df))) {
    sec <- tolower(trimws(as.character(df[[section_col]][i])))
    txt <- trimws(as.character(df[[text_col]][i]))
    if (nzchar(sec) && nzchar(txt) && !is.na(txt)) {
      result[[sec]] <- txt
    }
  }
  result
}


#' Load Optional AddedSlides Sheet from Config Excel
#'
#' Reads an "AddedSlides" sheet from the pricing config workbook if it exists.
#' Expected columns: slide_title, content (markdown), image_path (optional),
#' display_order (optional, auto-sequenced if missing).
#' Images are embedded as base64 data URIs for self-contained HTML reports.
#'
#' @param config_file Character, path to config Excel file
#' @return List of slide objects, or NULL if sheet is absent
#' @keywords internal
load_added_slides <- function(config_file) {
  sheets <- readxl::excel_sheets(config_file)

  sheet_name <- if ("AddedSlides" %in% sheets) "AddedSlides"
                else if ("Added_Slides" %in% sheets) "Added_Slides"
                else return(NULL)

  df <- tryCatch(
    readxl::read_excel(config_file, sheet = sheet_name),
    error = function(e) NULL
  )

  # Auto-detect header row if not in row 1

  if (!is.null(df) && !all(c("slide_title", "content") %in% tolower(names(df)))) {
    raw <- suppressMessages(
      readxl::read_excel(config_file, sheet = sheet_name,
                         col_names = FALSE, n_max = 10)
    )
    header_row <- NULL
    for (r in seq_len(nrow(raw))) {
      row_vals <- tolower(trimws(as.character(unlist(raw[r, ]))))
      if ("slide_title" %in% row_vals && "content" %in% row_vals) {
        header_row <- r
        break
      }
    }
    if (!is.null(header_row)) {
      df <- readxl::read_excel(config_file, sheet = sheet_name,
                               skip = header_row - 1)
    }
  }

  if (is.null(df) || nrow(df) == 0) return(NULL)

  # Normalize column names
  names(df) <- tolower(trimws(names(df)))

  if (!"slide_title" %in% names(df) || !"content" %in% names(df)) {
    cat("  [INFO] AddedSlides sheet found but missing slide_title/content columns - skipped\n")
    return(NULL)
  }

  # Filter valid rows
  df <- df[!is.na(df$slide_title) & nzchar(trimws(as.character(df$slide_title))), , drop = FALSE]
  if (nrow(df) == 0) return(NULL)

  # Add display_order if not present
  if (!"display_order" %in% names(df)) {
    df$display_order <- seq_len(nrow(df))
  }
  df <- df[order(df$display_order), , drop = FALSE]

  # Resolve image_path relative to config file directory

  config_dir <- dirname(normalizePath(config_file, mustWork = FALSE))
  has_image_col <- "image_path" %in% names(df)

  slides <- lapply(seq_len(nrow(df)), function(i) {
    slide <- list(
      id = sprintf("added-slide-%d", i),
      title = trimws(as.character(df$slide_title[i])),
      content = trimws(as.character(df$content[i] %||% "")),
      order = i,
      image_data = NULL
    )

    # Embed image as base64 if image_path is provided
    if (has_image_col && !is.na(df$image_path[i]) && nzchar(trimws(as.character(df$image_path[i])))) {
      img_path <- trimws(as.character(df$image_path[i]))
      # Resolve relative paths against config directory
      if (!file.exists(img_path)) {
        img_path <- file.path(config_dir, img_path)
      }
      if (file.exists(img_path) && requireNamespace("base64enc", quietly = TRUE)) {
        tryCatch({
          raw_bytes <- readBin(img_path, "raw", file.info(img_path)$size)
          ext <- tolower(tools::file_ext(img_path))
          mime <- switch(ext,
            png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg",
            gif = "image/gif", webp = "image/webp", svg = "image/svg+xml",
            "image/png"
          )
          slide$image_data <- sprintf("data:%s;base64,%s",
            mime, base64enc::base64encode(raw_bytes))
          cat(sprintf("  [INFO] Embedded image for slide '%s' (%s, %dKB)\n",
            slide$title, basename(img_path), round(length(raw_bytes) / 1024)))
        }, error = function(e) {
          cat(sprintf("  [WARNING] Could not embed image '%s': %s\n", img_path, e$message))
        })
      } else if (!file.exists(img_path)) {
        cat(sprintf("  [WARNING] Image file not found for slide '%s': %s\n",
          slide$title, img_path))
      }
    }

    slide
  })

  cat(sprintf("  [INFO] Loaded %d added slides from %s sheet\n", length(slides), sheet_name))
  slides
}


#' Create Pricing Configuration Template
#'
#' Generates an Excel configuration template for pricing analysis.
#' This is a convenience wrapper around the full template generator.
#'
#' @param output_file Path where template should be saved
#' @param method Type of analysis: "van_westendorp", "gabor_granger", "monadic", or "both"
#' @param overwrite Logical. Overwrite existing file?
#'
#' @return Invisible path to created file
#'
#' @export
create_pricing_config <- function(output_file = "pricing_config.xlsx",
                                  method = "van_westendorp",
                                  overwrite = FALSE) {

  if (file.exists(output_file) && !overwrite) {
    pricing_refuse(
      code = "IO_FILE_EXISTS",
      title = "Output File Already Exists",
      problem = sprintf("File already exists at: %s", output_file),
      why_it_matters = "Will not overwrite existing file without explicit permission",
      how_to_fix = "Set overwrite=TRUE to replace the existing file, or specify a different output_file path"
    )
  }

  # Try to use the polished generator if available
  generator_path <- file.path(dirname(sys.frame(1)$ofile %||% "."),
                               "..", "lib", "generate_config_templates.R")
  if (!file.exists(generator_path)) {
    generator_path <- file.path(getwd(), "modules", "pricing", "lib",
                                 "generate_config_templates.R")
  }

  if (file.exists(generator_path)) {
    source(generator_path)
    generate_pricing_config_template(
      output_path = output_file,
      include_monadic = method %in% c("monadic", "both"),
      include_simulator = TRUE,
      overwrite = overwrite
    )
  } else {
    # Fallback: basic template if generator not found
    if (!requireNamespace("openxlsx", quietly = TRUE)) {
      pricing_refuse(
        code = "PKG_OPENXLSX_MISSING",
        title = "Required Package Missing",
        problem = "Package 'openxlsx' is not installed",
        why_it_matters = "Cannot create Excel configuration template without openxlsx package",
        how_to_fix = "Install the package: install.packages('openxlsx')"
      )
    }
    message("[INFO] Full template generator not found. Creating basic template.")
    message("  For the polished template, source modules/pricing/lib/generate_config_templates.R")

    wb <- openxlsx::createWorkbook()
    header_style <- openxlsx::createStyle(
      fontColour = "#FFFFFF", fgFill = "#323367",
      halign = "left", textDecoration = "bold"
    )

    openxlsx::addWorksheet(wb, "Settings")
    settings_data <- data.frame(
      Setting = c("Project_Name", "Analysis_Method", "Data_File", "Output_File",
                  "Currency_Symbol", "Generate_HTML_Report"),
      Value = c("My Pricing Study", method, "", "pricing_results.xlsx", "$", "TRUE"),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Settings", settings_data, headerStyle = header_style)
    openxlsx::setColWidths(wb, "Settings", cols = 1:2, widths = c(30, 30))
    openxlsx::saveWorkbook(wb, output_file, overwrite = overwrite)
  }

  cat(sprintf("Configuration template created: %s\n", output_file))
  invisible(output_file)
}
