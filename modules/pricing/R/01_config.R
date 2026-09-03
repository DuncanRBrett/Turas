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

# ------------------------------------------------------------------------------
# Shared workbook saver
# ------------------------------------------------------------------------------
# turas_saveWorkbook() reconciles worksheet relationships before saving. Without
# it openxlsx leaves every sheet pointing at a drawing part it never writes, and
# Excel reports a problem with the file and offers to repair it -- a repair that
# strips every data-validation dropdown in the template.
#
# This file is designed to be sourced on its own, so it locates the shared
# helper itself rather than assuming the caller has already loaded it.
if (!exists("turas_saveWorkbook", mode = "function")) {
  .turas_saver_rel <- file.path("modules", "shared", "lib", "turas_save_workbook_atomic.R")
  .turas_saver_dir <- getwd()
  while (!file.exists(file.path(.turas_saver_dir, .turas_saver_rel)) &&
         .turas_saver_dir != dirname(.turas_saver_dir)) {
    .turas_saver_dir <- dirname(.turas_saver_dir)
  }
  .turas_saver_path <- file.path(.turas_saver_dir, .turas_saver_rel)
  if (file.exists(.turas_saver_path)) {
    source(.turas_saver_path)
  } else {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Code: IO_SAVER_NOT_FOUND\n")
    cat("│ Message: turas_save_workbook_atomic.R was not found, so templates are\n")
    cat("│          written without part reconciliation and Excel may offer to\n")
    cat("│          repair them, losing their dropdowns.\n")
    cat("│ How to fix: run from the Turas project root, or set the working\n")
    cat("│          directory so that modules/shared/lib is reachable\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    turas_saveWorkbook <- function(wb, file, overwrite = TRUE, ...) {
      openxlsx::saveWorkbook(wb, file, overwrite = overwrite, ...)
    }
  }
  rm(.turas_saver_rel, .turas_saver_dir, .turas_saver_path)
}

#' Parse A Delimited List Setting
#'
#' One parser for every comma- or semicolon-separated list in a pricing
#' config. The template said semicolons for Gabor-Granger prices, the sheet
#' loader split on commas, the Settings fallback split on semicolons and the
#' price ladder on semicolons again (review H2): following the template's own
#' instruction produced an all-NA price sequence. Both separators are accepted
#' everywhere now.
#'
#' @param x A single string, or NULL/NA.
#' @param numeric Logical, coerce the items to numeric.
#' @return A character or numeric vector, zero-length when there is nothing.
#' @keywords internal
.pricing_parse_list <- function(x, numeric = FALSE) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) {
    return(if (numeric) numeric(0) else character(0))
  }
  if (length(x) > 1) {
    items <- as.character(x)
  } else {
    items <- trimws(strsplit(as.character(x), "[,;]")[[1]])
  }
  items <- items[nzchar(items)]
  if (numeric) suppressWarnings(as.numeric(items)) else items
}


#' Map Template-Style Names Onto Internal Names
#'
#' The template writes `Col_Too_Cheap`; the engine reads `col_too_cheap`. The
#' Monadic and Validation loaders had a map like this; the Van Westendorp and
#' Gabor-Granger loaders did not, so a config saved from the shipped template
#' crashed in validation with a message about get1index (review H1). Applies
#' the explicit map first, then a generic lowercase fallback so a Title_Case
#' name with no entry still lands on its lowercase twin.
#'
#' @param settings Named list read from a sheet.
#' @param name_map Named character vector, template name to internal name.
#' @return The list with the internal names present.
#' @keywords internal
.pricing_apply_name_map <- function(settings, name_map) {
  nms <- names(settings)
  for (i in seq_along(nms)) {
    internal <- if (nms[i] %in% names(name_map)) unname(name_map[nms[i]]) else tolower(nms[i])
    if (!identical(internal, nms[i]) && !internal %in% names(settings)) {
      settings[[internal]] <- settings[[nms[i]]]
    }
  }
  settings
}


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

  # Remove template section headers: a name in col 1, nothing in col 2, and
  # the name is a divider (all caps, or all caps with a parenthetical note
  # such as "WIDE FORMAT SETTINGS (use if Data_Format = wide)", which the old
  # all-caps-only pattern let through as a bogus setting; review M6).
  # A real setting with a blank value keeps its underscore-joined Title_Case
  # name, which the divider pattern (no underscore, no lowercase) never
  # matches.
  section_dividers <- !is.na(first_col) & is.na(second_col) &
    grepl("^[A-Z][A-Z0-9 &/]*( \\(.*\\))?$", first_col, perl = TRUE)

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

  # Duplicates refuse (first-value-wins used to hide a second row silently),
  # retired names are answered by name, unknown names warn. Same contract as
  # tabs' config_utils (review M6).
  .pricing_check_setting_names(settings_raw$Setting, "Settings")

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
    "Price_Ceiling" = "price_ceiling",
    "Generate_Stats_Pack" = "generate_stats_pack",
    "Generate_Tabs_Export" = "generate_tabs_export",
    "Tabs_Question_Code" = "tabs_question_code",
    "Export_WTP" = "export_wtp",
    "GG_Stop_Early_Imputation" = "gg_stop_early_imputation",
    "Analyst_Name" = "analyst_name",
    "Research_House" = "research_house",
    "Segment_Vars" = "segment_vars",
    "Anchor" = "anchor",
    "Verbose" = "verbose"
  )

  .pricing_apply_name_map(settings, name_map)
}


# ==============================================================================
# SETTING NAME REGISTRY (review M6)
# ==============================================================================

#' Settings the pricing module reads, by sheet. Template names; matching is
#' case-insensitive and tolerant of the lowercase internal spelling.
PRICING_KNOWN_SETTINGS <- list(
  Settings = c(
    "Project_Name", "Analysis_Method", "Data_File", "Output_File", "ID_Variable",
    "Weight_Variable", "Currency_Symbol", "Unit_Cost", "DK_Codes",
    "Generate_HTML_Report", "Generate_Simulator", "Brand_Colour",
    "Generate_Stats_Pack", "Generate_Tabs_Export", "Tabs_Question_Code",
    "Export_WTP", "VW_Monotonicity_Behavior", "GG_Monotonicity_Behavior",
    "GG_Stop_Early_Imputation", "Segment_Column", "Min_Segment_N", "Include_Total",
    "N_Tiers", "Tier_Names", "Min_Gap_Pct", "Max_Gap_Pct", "Round_To", "Anchor",
    "Price_Floor", "Price_Ceiling", "Analyst_Name", "Research_House",
    "Segment_Vars", "Verbose",
    # Flat-Settings fallbacks for a config without method sheets.
    "vw_col_too_cheap", "vw_col_cheap", "vw_col_expensive", "vw_col_too_expensive",
    "vw_col_pi_cheap", "vw_col_pi_expensive", "vw_validate_monotonicity",
    "vw_exclude_violations", "vw_violation_threshold", "vw_calculate_confidence",
    "vw_confidence_level", "vw_bootstrap_iterations", "vw_price_decimals",
    "gg_data_format", "gg_price_sequence", "gg_response_columns", "gg_price_column",
    "gg_response_column", "gg_respondent_column", "gg_response_type",
    "gg_scale_threshold", "gg_binary_coding", "gg_smoothing_method",
    "gg_check_monotonicity", "gg_calculate_elasticity", "gg_revenue_optimization",
    "gg_confidence_intervals", "gg_bootstrap_iterations", "gg_confidence_level",
    "gg_run_simulation", "gg_market_size", "gg_unit_cost"
  ),
  VanWestendorp = c(
    "Col_Too_Cheap", "Col_Cheap", "Col_Expensive", "Col_Too_Expensive",
    "Col_PI_Cheap", "Col_PI_Expensive", "PI_Scale", "Calculate_Confidence",
    "Confidence_Level", "Bootstrap_Iterations", "Validate_Monotonicity",
    "Exclude_Violations", "Violation_Threshold", "Price_Decimals"
  ),
  GaborGranger = c(
    "Data_Format", "Price_Sequence", "Response_Columns", "Price_Column",
    "Response_Column", "Respondent_Column", "Response_Type", "Scale_Threshold",
    "Binary_Coding", "Smoothing_Method", "Calculate_Elasticity",
    "Revenue_Optimization", "Confidence_Intervals", "Bootstrap_Iterations",
    "Confidence_Level", "Check_Monotonicity", "Run_Simulation", "Market_Size",
    "Unit_Cost"
  ),
  Monadic = c(
    "Price_Column", "Intent_Column", "Intent_Type", "Scale_Threshold",
    "Model_Type", "Min_Cell_Size", "Prediction_Points", "Confidence_Intervals",
    "Bootstrap_Iterations", "Confidence_Level"
  ),
  Validation = c("Min_Completeness", "Min_Sample", "Price_Min", "Price_Max")
)

#' Settings the module no longer reads, each with the sentence a config that
#' still carries it is answered with. Follows the tabs and conjoint pattern:
#' a retired name is refused by name, never mistaken for a typo.
PRICING_RETIRED_SETTINGS <- c(
  "Interpolation_Method" = paste0(
    "Interpolation_Method was never read: pricesensitivitymeter interpolates ",
    "the curves linearly and offers nothing else. Remove the row."),
  "Flag_Outliers" = paste0(
    "Flag_Outliers had no implementation behind it; nothing was ever flagged. ",
    "Remove the row."),
  "Outlier_Method" = "Outlier_Method had no implementation behind it. Remove the row.",
  "Outlier_Threshold" = "Outlier_Threshold had no implementation behind it. Remove the row."
)
names(PRICING_RETIRED_SETTINGS) <- tolower(names(PRICING_RETIRED_SETTINGS))

#' Check A Sheet's Setting Names
#'
#' Refuses on a duplicated name (the second row used to be silently ignored),
#' refuses on a retired name with its own sentence, and prints a warning for
#' a name the module does not read so a typo cannot pass as a setting.
#'
#' @param setting_names Character vector of names as read from the sheet.
#' @param sheet The sheet name, for the message and the known list.
#' @return Invisibly TRUE.
#' @keywords internal
.pricing_check_setting_names <- function(setting_names, sheet) {
  nms <- trimws(as.character(setting_names))
  nms <- nms[!is.na(nms) & nzchar(nms)]
  lower <- tolower(nms)

  dup <- unique(nms[duplicated(lower)])
  if (length(dup) > 0) {
    pricing_refuse(
      code = "CFG_DUPLICATE_SETTING",
      title = "A Setting Appears More Than Once",
      problem = sprintf("The %s sheet lists %s more than once.", sheet,
                        paste(dup, collapse = ", ")),
      why_it_matters = paste0("Only one row can win, and the run would use whichever came ",
                              "first without saying so."),
      how_to_fix = "Keep one row per setting and delete the duplicates."
    )
  }

  retired <- lower[lower %in% names(PRICING_RETIRED_SETTINGS)]
  if (length(retired) > 0) {
    pricing_refuse(
      code = "CFG_RETIRED_SETTING",
      title = "A Retired Setting Is Still In The Config",
      problem = paste(unname(PRICING_RETIRED_SETTINGS[retired]), collapse = " "),
      why_it_matters = "The setting does nothing, and leaving it in suggests it does.",
      how_to_fix = sprintf("Remove the row(s) from the %s sheet: %s.", sheet,
                           paste(nms[lower %in% names(PRICING_RETIRED_SETTINGS)],
                                 collapse = ", "))
    )
  }

  known <- tolower(PRICING_KNOWN_SETTINGS[[sheet]] %||% character(0))
  unknown <- nms[!lower %in% known]
  if (length(unknown) > 0) {
    cat(sprintf(paste0("  [WARNING] %s sheet: %d setting name(s) the pricing module does ",
                       "not read and will ignore: %s\n"),
                sheet, length(unknown), paste(unknown, collapse = ", ")))
  }
  invisible(TRUE)
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
  .pricing_check_setting_names(vw_raw$Setting, "VanWestendorp")
  vw <- setNames(as.list(vw_raw$Value), vw_raw$Setting)

  # Template names onto the internal names the engine reads (review H1).
  vw <- .pricing_apply_name_map(vw, c(
    "Col_Too_Cheap" = "col_too_cheap",
    "Col_Cheap" = "col_cheap",
    "Col_Expensive" = "col_expensive",
    "Col_Too_Expensive" = "col_too_expensive",
    "Col_PI_Cheap" = "col_pi_cheap",
    "Col_PI_Expensive" = "col_pi_expensive",
    "PI_Scale" = "pi_scale",
    "Calculate_Confidence" = "calculate_confidence",
    "Confidence_Level" = "confidence_level",
    "Bootstrap_Iterations" = "bootstrap_iterations",
    "Validate_Monotonicity" = "validate_monotonicity",
    "Exclude_Violations" = "exclude_violations",
    "Violation_Threshold" = "violation_threshold",
    "Price_Decimals" = "price_decimals"
  ))
  # A blank optional column is no column.
  for (field in c("col_pi_cheap", "col_pi_expensive")) {
    if (!is.null(vw[[field]]) && (is.na(vw[[field]]) || !nzchar(trimws(vw[[field]])))) {
      vw[[field]] <- NA_character_
    }
  }

  # Convert numeric fields
  numeric_fields <- c("violation_threshold", "confidence_level", "bootstrap_iterations",
                      "price_decimals", "pi_scale")
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
  .pricing_check_setting_names(gg_raw$Setting, "GaborGranger")
  gg <- setNames(as.list(gg_raw$Value), gg_raw$Setting)

  # Template names onto the internal names the engine reads (review H1).
  gg <- .pricing_apply_name_map(gg, c(
    "Data_Format" = "data_format",
    "Price_Sequence" = "price_sequence",
    "Response_Columns" = "response_columns",
    "Price_Column" = "price_column",
    "Response_Column" = "response_column",
    "Respondent_Column" = "respondent_column",
    "Response_Type" = "response_type",
    "Scale_Threshold" = "scale_threshold",
    "Binary_Coding" = "binary_coding",
    "Smoothing_Method" = "smoothing_method",
    "Calculate_Elasticity" = "calculate_elasticity",
    "Revenue_Optimization" = "revenue_optimization",
    "Confidence_Intervals" = "confidence_intervals",
    "Bootstrap_Iterations" = "bootstrap_iterations",
    "Confidence_Level" = "confidence_level",
    "Check_Monotonicity" = "check_monotonicity",
    "Run_Simulation" = "run_simulation",
    "Market_Size" = "market_size",
    "Unit_Cost" = "unit_cost"
  ))
  gg$data_format <- tolower(trimws(as.character(gg$data_format %||% "wide")))
  for (field in c("price_column", "response_column", "respondent_column")) {
    if (!is.null(gg[[field]]) && (is.na(gg[[field]]) || !nzchar(trimws(gg[[field]])))) {
      gg[[field]] <- NA_character_
    }
  }

  # Lists accept commas or semicolons (review H2).
  gg$price_sequence <- .pricing_parse_list(gg$price_sequence, numeric = TRUE)
  gg$response_columns <- .pricing_parse_list(gg$response_columns)
  if (length(gg$price_sequence) == 0) gg$price_sequence <- NULL
  if (length(gg$response_columns) == 0) gg$response_columns <- NULL
  if (!is.null(gg$price_sequence) && any(is.na(gg$price_sequence))) {
    pricing_refuse(
      code = "CFG_GG_PRICE_SEQUENCE",
      title = "Price_Sequence Is Not A List Of Numbers",
      problem = sprintf("Price_Sequence on the GaborGranger sheet reads '%s'.",
                        as.character(gg_raw$Value[tolower(gg_raw$Setting) == "price_sequence"][1])),
      why_it_matters = "Every rung of the ladder needs a price the demand curve can be plotted against.",
      how_to_fix = "Write the prices as numbers separated by commas or semicolons, e.g. 60; 80; 100."
    )
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

  # Wide format settings; lists accept commas or semicolons (review H2).
  ps <- .pricing_parse_list(settings$gg_price_sequence, numeric = TRUE)
  if (length(ps) > 0) gg$price_sequence <- ps
  rc <- .pricing_parse_list(settings$gg_response_columns)
  if (length(rc) > 0) gg$response_columns <- rc

  # Long format settings
  gg$price_column <- settings$gg_price_column
  gg$response_column <- settings$gg_response_column
  gg$respondent_column <- settings$gg_respondent_column

  # Response coding
  gg$response_type <- settings$gg_response_type %||% "binary"
  gg$scale_threshold <- as.numeric(settings$gg_scale_threshold %||% 3)
  gg$binary_coding <- settings$gg_binary_coding %||% "ZERO_ONE"
  gg$smoothing_method <- settings$gg_smoothing_method %||% "isotonic"

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
  .pricing_check_setting_names(val_raw$Setting, "Validation")
  settings <- setNames(as.list(val_raw$Value), val_raw$Setting)
  # Normalize template names. The outlier settings are retired (review M7):
  # nothing ever read them.
  settings <- .pricing_apply_name_map(settings, c(
    "Min_Completeness" = "min_completeness",
    "Min_Sample" = "min_sample",
    "Price_Min" = "price_min",
    "Price_Max" = "price_max"
  ))
  for (field in c("min_completeness", "min_sample", "price_min", "price_max")) {
    if (!is.null(settings[[field]]) && !is.na(settings[[field]])) {
      settings[[field]] <- suppressWarnings(as.numeric(settings[[field]]))
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
  .pricing_check_setting_names(mon_raw$Setting, "Monadic")
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

  # Filter out help rows, the template's own example rows and empty rows.
  # The example scenarios used to load as real presets from an unedited
  # template (review M11); they are now titled "[Example] ..." and skipped.
  first_col <- as.character(raw[[1]])
  help_rows <- grepl("^\\[REQUIRED\\]|^\\[Optional\\]|^\\[Example\\]", first_col, ignore.case = TRUE)
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
  # One definition, shared with 02_validation.R (the outlier settings are
  # retired; nothing ever read them, review M7).
  list(
    min_completeness = 0.8,
    min_sample = 30,
    price_min = 0,
    price_max = 10000
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
  settings$brand_colour <- settings$brand_colour %||% "#323367"
  settings$generate_stats_pack <- settings$generate_stats_pack %||% "Y"
  settings$generate_tabs_export <- toupper(substr(as.character(
    settings$generate_tabs_export %||% "N"), 1, 1)) %in% c("Y", "T")
  settings$tabs_question_code <- settings$tabs_question_code %||% "GGACC"
  settings$export_wtp <- toupper(substr(as.character(settings$export_wtp %||% "N"), 1, 1)) %in% c("Y", "T")

  # Stop-early Gabor-Granger ladders (review C2): refuse by default when the
  # per-rung bases differ; NO_AFTER_STOP is the explicit opt-in.
  settings$gg_stop_early_imputation <- toupper(trimws(as.character(
    settings$gg_stop_early_imputation %||% "NONE")))
  if (!settings$gg_stop_early_imputation %in% c("NONE", "NO_AFTER_STOP")) {
    pricing_refuse(
      code = "CFG_GG_STOP_EARLY_IMPUTATION",
      title = "GG_Stop_Early_Imputation Has An Unknown Value",
      problem = sprintf("GG_Stop_Early_Imputation reads '%s'.", settings$gg_stop_early_imputation),
      why_it_matters = "It decides whether unanswered rungs after a No count as No, which moves the demand curve.",
      how_to_fix = "Use NONE (default, refuse when rung bases differ) or NO_AFTER_STOP."
    )
  }

  # Weighting and segmentation
  settings$weight_var <- settings$weight_var %||% NA_character_
  if (!is.na(settings$weight_var) && settings$weight_var == "") {
    settings$weight_var <- NA_character_
  }

  # Segment variables (comma- or semicolon-separated list)
  settings$segment_vars <- .pricing_parse_list(settings$segment_vars)

  # Cost for profit calculations
  settings$unit_cost <- if (!is.null(settings$unit_cost) && !is.na(settings$unit_cost)) {
    as.numeric(settings$unit_cost)
  } else {
    NA_real_
  }

  # Monotonicity behavior. Default is "drop" (review H3, handover ruling R1):
  # the honest name for what the module always did, since psm_analysis ran
  # with validate = TRUE whatever the setting said. "flag_only" now really
  # keeps the intransitive respondents in the curves.
  settings$vw_monotonicity_behavior <- tolower(trimws(as.character(
    settings$vw_monotonicity_behavior %||% "drop")))
  valid_vw_mono <- c("drop", "fix", "flag_only")
  if (!settings$vw_monotonicity_behavior %in% valid_vw_mono) {
    pricing_refuse(
      code = "CFG_VW_MONOTONICITY_BEHAVIOR",
      title = "VW_Monotonicity_Behavior Has An Unknown Value",
      problem = sprintf("VW_Monotonicity_Behavior reads '%s'.", settings$vw_monotonicity_behavior),
      why_it_matters = "It decides whether respondents with illogical price answers are excluded, kept or re-sorted, which moves the price points.",
      how_to_fix = "Use drop (exclude them, the default), flag_only (keep them, disclosed) or fix (re-sort their four answers, a strong transformation)."
    )
  }

  settings$gg_monotonicity_behavior <- settings$gg_monotonicity_behavior %||% "smooth"
  valid_gg_mono <- c("diagnostic_only", "smooth")
  if (!settings$gg_monotonicity_behavior %in% valid_gg_mono) {
    warning(sprintf("Invalid gg_monotonicity_behavior: '%s'. Using 'smooth'.",
                    settings$gg_monotonicity_behavior))
    settings$gg_monotonicity_behavior <- "smooth"
  }

  # Don't know codes (comma- or semicolon-separated list of numeric codes)
  settings$dk_codes <- .pricing_parse_list(settings$dk_codes, numeric = TRUE)
  settings$dk_codes <- settings$dk_codes[!is.na(settings$dk_codes)]

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
    # Kept as one string for the ladder's own parser, which now accepts
    # commas as well as semicolons (review H2).
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

  # Filter valid rows. A title starting with [Example] is the template's own
  # illustration and never becomes a client-facing slide (review M11).
  df <- df[!is.na(df$slide_title) & nzchar(trimws(as.character(df$slide_title))), , drop = FALSE]
  df <- df[!grepl("^\\[Example\\]", trimws(as.character(df$slide_title)), ignore.case = TRUE), , drop = FALSE]
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
    turas_saveWorkbook(wb, output_file, overwrite = overwrite)
  }

  cat(sprintf("Configuration template created: %s\n", output_file))
  invisible(output_file)
}
