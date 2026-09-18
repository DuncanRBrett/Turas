# ==============================================================================
# KEY DRIVER CONFIG LOADER
# ==============================================================================
#
# Version: Turas v10.3 (Continuous Key Driver Upgrade)
# Date: 2025-12
#
# NEW IN v10.3:
#   - Explicit driver_type declaration required per driver
#   - aggregation_method support for categorical drivers
#   - Stricter validation per TURAS-KD-CONTINUOUS-UPGRADE-v1.0
#
# NEW IN v10.2:
#   - TRS v1.0 integration: Refusal framework for config errors
#
# NEW IN v10.1:
#   - Support for Segments sheet
#   - Support for StatedImportance sheet
#   - Extended Settings for SHAP and Quadrant configuration
#
# ==============================================================================

#' Load Key Driver Configuration
#'
#' Loads and validates key driver analysis configuration.
#'
#' @param config_file Path to configuration Excel file
#' @param project_root Optional project root directory (defaults to config file directory)
#' @return List with validated configuration
#' @keywords internal
load_keydriver_config <- function(config_file, project_root = NULL) {

  # Guard: config_file must be an actual file, not a directory
  if (dir.exists(config_file) && !file_test("-f", config_file)) {
    keydriver_refuse(
      code = "IO_CONFIG_IS_DIRECTORY",
      title = "Configuration Path Is a Directory",
      problem = sprintf("Expected a .xlsx config file but received a directory: %s", config_file),
      why_it_matters = "Key driver analysis requires a configuration Excel file, not a directory path.",
      how_to_fix = c(
        "Select a specific .xlsx configuration file, not just the project folder",
        "Ensure the config file is properly detected in the selected directory"
      )
    )
  }

  if (!file.exists(config_file)) {
    keydriver_refuse(
      code = "IO_CONFIG_NOT_FOUND",
      title = "Configuration File Not Found",
      problem = paste0("Configuration file does not exist: ", config_file),
      why_it_matters = "Key driver analysis requires a configuration file to define variables and settings.",
      how_to_fix = c(
        "Check that the file path is correct",
        "Ensure the file exists at the specified location"
      )
    )
  }

  # Set project root to config file directory if not specified
  if (is.null(project_root)) {
    project_root <- dirname(config_file)
  }

  # Get available sheets
  available_sheets <- openxlsx::getSheetNames(config_file)

  # Load settings (required)
  if (!"Settings" %in% available_sheets) {
    keydriver_refuse(
      code = "CFG_SETTINGS_SHEET_MISSING",
      title = "Settings Sheet Missing",
      problem = "Required 'Settings' sheet not found in configuration file.",
      why_it_matters = "The Settings sheet defines essential analysis parameters.",
      how_to_fix = c(
        "Add a 'Settings' sheet to your config Excel file",
        "The sheet should have columns: Setting, Value"
      ),
      expected = "Settings",
      observed = available_sheets
    )
  }
  # The generated template puts a title in row 1, a subtitle in row 2, the real
  # column headers in row 3 and per-column help text in row 4. Reading at row 1
  # takes the title as the header, so the module refused its own template. The
  # shared loader reads row 1 first and falls back to scanning for the header
  # row, so hand-built configs (headers in row 1) are unaffected.
  settings <- as.data.frame(load_config_table_sheet(config_file, "Settings",
                                                    required_cols = c("Setting", "Value")))

  # A malformed Settings sheet used to fall through to CFG_DATA_FILE_MISSING,
  # which sends the analyst looking at the wrong thing entirely (review M13).
  if (!all(c("Setting", "Value") %in% names(settings))) {
    keydriver_refuse(
      code = "CFG_SETTINGS_MALFORMED",
      title = "Settings Sheet Has No Setting/Value Columns",
      problem = paste0(
        "The Settings sheet was read but has no 'Setting' and 'Value' columns. ",
        "Columns found: ",
        if (length(names(settings))) paste(names(settings), collapse = ", ") else "none"),
      why_it_matters = paste0(
        "Every path, feature gate and parameter is read from those two ",
        "columns. Without them nothing the config asks for is seen, and the ",
        "first thing to go missing is reported as a missing data file."),
      how_to_fix = c(
        "Give the Settings sheet a header row with the columns Setting and Value",
        "Check the header spelling, which is case sensitive",
        "Or regenerate the template with generate_keydriver_config_template()"
      ),
      expected = c("Setting", "Value"),
      observed = names(settings)
    )
  }

  # A duplicated Setting name silently took the first value, so the run used
  # one figure and the analyst read another off the sheet (review M13).
  setting_names <- trimws(as.character(settings$Setting))
  named <- setting_names[!is.na(setting_names) & nzchar(setting_names)]
  dupes <- unique(named[duplicated(named)])
  if (length(dupes) > 0) {
    keydriver_refuse(
      code = "CFG_SETTINGS_DUPLICATED",
      title = "Duplicate Settings",
      problem = sprintf("%d setting(s) appear more than once on the Settings sheet: %s",
                        length(dupes), paste(dupes, collapse = ", ")),
      why_it_matters = paste0(
        "Only one value can be used. The run took the first and left the ",
        "other on the sheet, so the config a reader sees is not necessarily ",
        "the config that ran."),
      how_to_fix = c(
        "Open the Settings sheet and delete the rows you do not want",
        "Each Setting name may appear only once"
      ),
      observed = dupes
    )
  }

  settings_list <- setNames(as.list(settings$Value), settings$Setting)

  # A typo'd Setting name was ignored without a word, so a config that asked
  # for a feature ran without it and still reported PASS (review M13). Named
  # rather than refused, because an analyst may keep notes on the sheet.
  unknown <- setdiff(named, KD_KNOWN_SETTINGS)
  if (length(unknown) > 0) {
    cat(sprintf(paste0(
      "   [WARNING] %d setting(s) on the Settings sheet are not read by this ",
      "module and were ignored: %s. Check the spelling against the template ",
      "if you expected one of them to do something.\n"),
      length(unknown), paste(unknown, collapse = ", ")))
  }

  # -----------------------------------------------------------------
  # v10.3: Parse on_fail policy for optional features
  # Per TURAS-KD-CONTINUOUS-UPGRADE-v1.0:
  # - Default: on_fail = refuse
  # - Can be set to: refuse, continue_with_flag
  # -----------------------------------------------------------------
  feature_policies <- parse_feature_policies(settings_list)

  # Extract and resolve file paths from settings
  data_file <- settings_list$data_file
  output_file <- settings_list$output_file

  # Resolve relative paths
  if (!is.null(data_file) && !is.na(data_file)) {
    if (!grepl("^(/|[A-Za-z]:)", data_file)) {
      # Relative path - resolve from project root
      data_file <- file.path(project_root, data_file)
    }
    data_file <- normalizePath(data_file, winslash = "/", mustWork = FALSE)
  }

  if (!is.null(output_file) && !is.na(output_file)) {
    if (!grepl("^(/|[A-Za-z]:)", output_file)) {
      # Relative path - resolve from project root
      output_file <- file.path(project_root, output_file)
    }
    output_file <- normalizePath(output_file, winslash = "/", mustWork = FALSE)
  }

  # Load variables definition (required)
  if (!"Variables" %in% available_sheets) {
    keydriver_refuse(
      code = "CFG_VARIABLES_SHEET_MISSING",
      title = "Variables Sheet Missing",
      problem = "Required 'Variables' sheet not found in configuration file.",
      why_it_matters = "The Variables sheet defines which variables are outcomes and drivers.",
      how_to_fix = c(
        "Add a 'Variables' sheet to your config Excel file",
        "The sheet must have columns: VariableName, Type, Label",
        "Set Type='Outcome' for your dependent variable",
        "Set Type='Driver' for independent variables"
      ),
      expected = "Variables",
      observed = available_sheets
    )
  }
  variables <- as.data.frame(load_config_table_sheet(config_file, "Variables",
                                                     required_cols = "VariableName"))

  # Validate variables sheet - base required columns
  required_cols <- c("VariableName", "Type", "Label")
  missing_cols <- setdiff(required_cols, names(variables))
  if (length(missing_cols) > 0) {
    keydriver_refuse(
      code = "CFG_VARIABLES_COLUMNS_MISSING",
      title = "Variables Sheet Missing Required Columns",
      problem = paste0("Variables sheet is missing required columns: ", paste(missing_cols, collapse = ", ")),
      why_it_matters = "These columns are needed to identify variables and their roles.",
      how_to_fix = "Add the missing columns to your Variables sheet.",
      expected = required_cols,
      observed = names(variables),
      missing = missing_cols
    )
  }

  # Extract outcome and driver variables
  outcome_vars <- variables$VariableName[variables$Type == "Outcome"]
  driver_rows <- variables[variables$Type == "Driver", , drop = FALSE]
  driver_vars <- driver_rows$VariableName

  # -----------------------------------------------------------------
  # v10.3: Validate driver configuration per TURAS-KD-CONTINUOUS-UPGRADE-v1.0
  # Each driver MUST have explicit driver_type declaration
  # -----------------------------------------------------------------
  driver_settings <- NULL
  if (length(driver_vars) > 0) {
    driver_settings <- validate_driver_declarations(driver_rows, variables)
  }

  if (length(outcome_vars) == 0) {
    keydriver_refuse(
      code = "CFG_OUTCOME_MISSING",
      title = "No Outcome Variable Defined",
      problem = "No variable has Type='Outcome' in the Variables sheet.",
      why_it_matters = "Key driver analysis requires an outcome (dependent) variable to analyze.",
      how_to_fix = c(
        "Open the Variables sheet in your config file",
        "Set Type='Outcome' for your dependent variable",
        "This should be the variable you want to explain/predict"
      )
    )
  }

  if (length(outcome_vars) > 1) {
    # Warn but don't refuse - use first
    cat(sprintf("   [WARN] Multiple outcome variables found. Using first: %s\n", outcome_vars[1]))
    outcome_vars <- outcome_vars[1]
  }

  if (length(driver_vars) == 0) {
    keydriver_refuse(
      code = "CFG_DRIVERS_MISSING",
      title = "No Driver Variables Defined",
      problem = "No variables have Type='Driver' in the Variables sheet.",
      why_it_matters = "Key driver analysis requires driver (independent) variables to determine importance.",
      how_to_fix = c(
        "Open the Variables sheet in your config file",
        "Set Type='Driver' for each independent variable",
        "You need at least 2 driver variables for meaningful analysis"
      )
    )
  }

  # Extract optional weight variable
  weight_vars <- variables$VariableName[variables$Type == "Weight"]
  weight_var <- if (length(weight_vars) == 0) {
    NULL
  } else {
    if (length(weight_vars) > 1) {
      cat(sprintf("   [WARN] Multiple weight variables found. Using first: %s\n", weight_vars[1]))
    }
    weight_vars[1]
  }

  # -----------------------------------------------------------------
  # NEW v10.1: Load optional Segments sheet
  # TRS v1.0: If sheet is PRESENT but INVALID, must refuse (not warn & continue)
  # -----------------------------------------------------------------
  segments <- NULL
  if ("Segments" %in% available_sheets) {
    # Sheet exists - must load successfully or refuse
    seg_df <- tryCatch(
      as.data.frame(load_config_table_sheet(config_file, "Segments",
                                            required_cols = "segment_name")),
      error = function(e) {
        keydriver_refuse(
          code = "CFG_SEGMENTS_READ_FAILED",
          title = "Cannot Read Segments Sheet",
          problem = paste0("Segments sheet exists but could not be read: ", e$message),
          why_it_matters = "You added a Segments sheet, so analysis expects valid segment definitions.",
          how_to_fix = c(
            "Fix the Segments sheet format",
            "Or remove the Segments sheet if you don't need segment analysis"
          )
        )
      }
    )
    # A sheet with headers and no rows is not an invalid sheet, it is an
    # unused one, and it is exactly what the template ships now that the
    # activating example rows are gone (review M12). Refusing it made an
    # untouched template impossible to run. Only a sheet carrying rows is
    # validated.
    if (nrow(seg_df) == 0) {
      cat("   [NOTE] The Segments sheet is empty, so no segment comparison will run.\n")
    } else {
      validate_segments_sheet(seg_df)  # Will refuse on validation failure
      segments <- seg_df
    }
  }

  # -----------------------------------------------------------------
  # NEW v10.1: Load optional StatedImportance sheet
  # TRS v1.0: If sheet is PRESENT but INVALID, must refuse (not warn & continue)
  # -----------------------------------------------------------------
  stated_importance <- NULL
  if ("StatedImportance" %in% available_sheets) {
    # Sheet exists - must load successfully or refuse
    si_df <- tryCatch(
      as.data.frame(load_config_table_sheet(config_file, "StatedImportance",
                                            required_cols = "driver")),
      error = function(e) {
        keydriver_refuse(
          code = "CFG_STATED_IMPORTANCE_READ_FAILED",
          title = "Cannot Read StatedImportance Sheet",
          problem = paste0("StatedImportance sheet exists but could not be read: ", e$message),
          why_it_matters = "You added a StatedImportance sheet, so analysis expects valid stated importance data.",
          how_to_fix = c(
            "Fix the StatedImportance sheet format",
            "Or remove the StatedImportance sheet if you don't need stated importance analysis"
          )
        )
      }
    )
    # Empty means unused, not invalid (review M12), as for Segments above.
    if (nrow(si_df) == 0) {
      cat(paste0("   [NOTE] The StatedImportance sheet is empty. The quadrant ",
                 "will still run, on derived importance and driver means.\n"))
    } else {
      si_df <- validate_stated_importance_sheet(si_df)  # Will refuse on validation failure, or return renamed df
      stated_importance <- si_df
    }
  }

  # -----------------------------------------------------------------
  # NEW v10.4: Load optional CustomSlides sheet
  # Columns: slide_title, slide_content, image_path (optional)
  # -----------------------------------------------------------------
  custom_slides <- NULL
  if ("CustomSlides" %in% available_sheets) {
    cs_df <- tryCatch(
      as.data.frame(load_config_table_sheet(config_file, "CustomSlides",
                                            required_cols = "slide_title")),
      error = function(e) NULL  # CustomSlides is optional — skip silently on read error
    )
    if (!is.null(cs_df) && nrow(cs_df) > 0) {
      if ("slide_title" %in% names(cs_df) && "slide_content" %in% names(cs_df)) {
        custom_slides <- cs_df
        cat(sprintf("   Loaded %d custom slide(s) from config\n", nrow(cs_df)))
      } else {
        cat("   [WARN] CustomSlides sheet missing required columns (slide_title, slide_content) — skipped\n")
      }
    }
  }

  # -----------------------------------------------------------------
  # NEW v10.4: Load optional Insights sheet
  # Columns: section (required), insight_text (required), image_path (optional)
  # -----------------------------------------------------------------
  insights <- NULL
  if ("Insights" %in% available_sheets) {
    ins_df <- tryCatch(
      as.data.frame(load_config_table_sheet(config_file, "Insights",
                                            required_cols = "section")),
      error = function(e) NULL  # Insights is optional — skip silently on read error
    )
    if (!is.null(ins_df) && nrow(ins_df) > 0) {
      if ("section" %in% names(ins_df) && "insight_text" %in% names(ins_df)) {
        insights <- ins_df
        cat(sprintf("   Loaded %d pre-populated insight(s) from config\n", nrow(ins_df)))
      } else {
        cat("   [WARN] Insights sheet missing required columns (section, insight_text) — skipped\n")
      }
    }
  }

  # -----------------------------------------------------------------
  # Build configuration list
  # -----------------------------------------------------------------
  list(
    config_file = normalizePath(config_file, winslash = "/", mustWork = FALSE),
    settings = settings_list,
    outcome_var = outcome_vars,
    driver_vars = driver_vars,
    weight_var = weight_var,
    variables = variables,
    data_file = data_file,
    output_file = output_file,
    project_root = project_root,
    # NEW v10.1
    segments = segments,
    stated_importance = stated_importance,
    # NEW v10.3: Explicit driver settings per TURAS-KD-CONTINUOUS-UPGRADE-v1.0
    driver_settings = driver_settings,
    # NEW v10.3: Feature policies (on_fail behavior)
    feature_policies = feature_policies,
    # NEW v10.4: Config-driven presentation slides
    custom_slides = custom_slides,
    # NEW v10.4: Config-driven pre-populated insights
    insights = insights
  )
}


#' Validate Segments Sheet
#'
#' @param seg_df Segments data frame
#' @keywords internal
validate_segments_sheet <- function(seg_df) {

  required_cols <- c("segment_name", "segment_variable", "segment_values")
  missing_cols <- setdiff(required_cols, names(seg_df))

  if (length(missing_cols) > 0) {
    keydriver_refuse(
      code = "CFG_SEGMENTS_MISSING_COLS",
      title = "Segments Sheet Missing Columns",
      problem = paste0("Segments sheet is missing required columns: ", paste(missing_cols, collapse = ", ")),
      why_it_matters = "Segment analysis requires proper segment definitions.",
      how_to_fix = "Add the missing columns to your Segments sheet: segment_name, segment_variable, segment_values"
    )
  }

  if (nrow(seg_df) == 0) {
    keydriver_refuse(
      code = "CFG_SEGMENTS_EMPTY",
      title = "Segments Sheet Is Empty",
      problem = "Segments sheet has no rows defined.",
      why_it_matters = "Cannot perform segment analysis without segment definitions.",
      how_to_fix = "Add at least one row to the Segments sheet with segment_name, segment_variable, and segment_values."
    )
  }

  invisible(TRUE)
}


#' Validate StatedImportance Sheet
#'
#' @param si_df Stated importance data frame
#' @keywords internal
validate_stated_importance_sheet <- function(si_df) {

  # Must have driver column
  if (!"driver" %in% names(si_df)) {
    keydriver_refuse(
      code = "CFG_STATED_IMPORTANCE_MISSING_DRIVER",
      title = "StatedImportance Missing Driver Column",
      problem = "StatedImportance sheet must have a 'driver' column.",
      why_it_matters = "The driver column identifies which driver variable each importance rating applies to.",
      how_to_fix = "Add a 'driver' column to the StatedImportance sheet listing the driver variable names."
    )
  }

  # Must have numeric importance column
  numeric_cols <- sapply(si_df, is.numeric)
  if (!any(numeric_cols)) {
    keydriver_refuse(
      code = "CFG_STATED_IMPORTANCE_NO_NUMERIC",
      title = "StatedImportance Has No Numeric Column",
      problem = "StatedImportance sheet must have at least one numeric column for importance values.",
      why_it_matters = "Stated importance values must be numeric for comparison with derived importance.",
      how_to_fix = "Add a numeric column (e.g., 'stated_importance') with importance ratings."
    )
  }

  # Standard column name
  if (!"stated_importance" %in% names(si_df)) {
    # Use first numeric column
    num_col <- names(si_df)[numeric_cols][1]
    cat(sprintf("   [INFO] Using '%s' as stated importance column\n", num_col))
    names(si_df)[names(si_df) == num_col] <- "stated_importance"
  }

  # Return the (possibly renamed) data frame so the caller gets the changes
  si_df
}


#' Get Setting Value with Default
#'
#' Utility to safely extract setting values with fallback.
#'
#' @param settings Settings list
#' @param name Setting name
#' @param default Default value if not found
#' @return Setting value or default
#' @keywords internal
get_setting <- function(settings, name, default = NULL) {
  val <- settings[[name]]
  if (is.null(val) || is.na(val)) {
    return(default)
  }
  val
}


#' Convert Setting to Logical
#'
#' @param value Setting value (may be string, numeric, or logical)
#' @param default Default if NULL/NA
#' @return Logical value
#' @keywords internal
#' The Run's Random Seed, Recorded
#'
#' The bootstrap, xgb.cv, cv.glmnet and the Shapiro subsample all draw at
#' random and none of them was seeded, so two runs of the same config gave
#' different confidence intervals and a different SHAP model (review M3). One
#' seed, from the config when it sets one, applied at every draw and stamped on
#' the provenance so a result can be reproduced.
#'
#' @param config The loaded configuration.
#' @return The integer seed in use.
#' @keywords internal
#' Every Settings key this module reads
#'
#' A typo in a Settings name was ignored without a word, so a config that
#' asked for a feature ran without it and reported PASS (review M13). These
#' are refused if duplicated and named on the console if unrecognised.
#'
#' This list is bound to the config template by a test, so a key added to one
#' and not the other fails the suite rather than drifting quietly.
#' @keywords internal
KD_KNOWN_SETTINGS <- c(
    "accent_colour",
    "analysis_name",
    "Analyst_Name",
    "bootstrap_ci_level",
    "bootstrap_display",
    "bootstrap_iterations",
    "brand_colour",
    "client_logo_path",
    "client_name",
    "colsample_bytree",
    "company_name",
    "correlation_display",
    "data_file",
    "elastic_net_alpha",
    "elastic_net_nfolds",
    "enable_bootstrap",
    "enable_dominance",
    "enable_elastic_net",
    "enable_gam",
    "enable_html_report",
    "enable_nca",
    "enable_quadrant",
    "enable_shap",
    "gam_k",
    "Generate_Stats_Pack",
    "html_show_bootstrap",
    "html_show_correlations",
    "html_show_diagnostics",
    "html_show_effect_sizes",
    "html_show_exec_summary",
    "html_show_guide",
    "html_show_importance",
    "html_show_methods",
    "html_show_quadrant",
    "html_show_segments",
    "html_show_shap",
    "importance_source",
    "importance_top_n",
    "include_interactions",
    "interaction_top_n",
    "label_all_points",
    "label_top_n",
    "learning_rate",
    "max_depth",
    "min_segment_n",
    "n_trees",
    "nca_test_reps",
    "normalize_axes",
    "output_file",
    "Project_Name",
    "quadrant_on_fail",
    "random_seed",
    "report_title",
    "Research_House",
    "researcher_logo_path",
    "researcher_name",
    "shade_quadrants",
    "shap_model",
    "shap_on_fail",
    "shap_sample_size",
    "show_diagonal",
    "subsample",
    "threshold_method",
    "vif_high_threshold",
    "vif_moderate_threshold"
)


KD_DEFAULT_SEED <- 20260101L

#' Split a Segments sheet segment_values cell
#'
#' One parser. Pre-flight split on "," alone, the quadrant comparison on
#' ",\\s*" and the pipeline on "[;,|]", so a cell written "18-24; 25-34" built
#' one segment in the pipeline, checked as two different strings in pre-flight
#' and produced a segment the quadrant could not match (review F15). Every
#' consumer reads a cell the same way now: comma, semicolon or pipe, trimmed,
#' empties dropped.
#'
#' @param raw A single segment_values cell
#' @return Character vector of values, possibly empty
#' @keywords internal
kd_split_segment_values <- function(raw) {
  if (is.null(raw) || length(raw) == 0) return(character(0))
  raw <- as.character(raw)[1]
  if (is.na(raw) || !nzchar(trimws(raw))) return(character(0))
  vals <- trimws(unlist(strsplit(raw, "[;,|]")))
  vals[nzchar(vals)]
}


#' The one bootstrap iteration default
#'
#' The run used 500 and the stats pack reported 1000, so the number a client
#' read was not the number that produced their intervals (review M8). One
#' constant, read everywhere the default is needed.
#' @keywords internal
KD_DEFAULT_BOOTSTRAP_ITERATIONS <- 1000L

#' The configured bootstrap iterations, or the default.
#' @keywords internal
kd_bootstrap_iterations <- function(config) {
  raw <- config$settings$bootstrap_iterations %||% config$bootstrap_iterations %||%
    KD_DEFAULT_BOOTSTRAP_ITERATIONS
  n <- suppressWarnings(as.integer(raw))
  if (length(n) != 1 || is.na(n) || n < 1) n <- KD_DEFAULT_BOOTSTRAP_ITERATIONS
  n
}

kd_seed_value <- function(config) {
  raw <- config$settings$random_seed %||% config$random_seed %||% KD_DEFAULT_SEED
  seed <- suppressWarnings(as.integer(raw))
  if (length(seed) != 1 || is.na(seed)) seed <- KD_DEFAULT_SEED
  seed
}

#' Apply the run's seed before a randomised step.
#' @keywords internal
kd_apply_seed <- function(config, context = NULL) {
  seed <- kd_seed_value(config)
  set.seed(seed)
  invisible(seed)
}


as_logical_setting <- function(value, default = FALSE) {
  if (is.null(value) || is.na(value)) {
    return(default)
  }

  if (is.logical(value)) {
    return(value)
  }

  if (is.character(value)) {
    # "Y" and "T" are what an analyst types in a spreadsheet cell, and
    # as.logical() reads both as NA (review M14).
    return(tolower(trimws(value)) %in%
             c("true", "t", "yes", "y", "1", "on", "enabled"))
  }

  if (is.numeric(value)) {
    return(value != 0)
  }

  default
}


#' Convert Setting to Numeric
#'
#' @param value Setting value
#' @param default Default if NULL/NA
#' @return Numeric value
#' @keywords internal
as_numeric_setting <- function(value, default = NA_real_) {
  if (is.null(value) || is.na(value)) {
    return(default)
  }

  if (is.numeric(value)) {
    return(value)
  }

  if (is.character(value)) {
    result <- suppressWarnings(as.numeric(value))
    if (is.na(result)) {
      return(default)
    }
    return(result)
  }

  default
}


# ==============================================================================
# v10.3: FEATURE POLICY PARSING
# ==============================================================================
# Per TURAS-KD-CONTINUOUS-UPGRADE-v1.0:
# - Optional features must declare on_fail policy
# - Default: refuse (if enabled and fails, refuse to produce output)
# - Alternative: continue_with_flag (produce PARTIAL output)

#' Parse Feature Policies from Settings
#'
#' Extracts on_fail policies for optional features from settings.
#'
#' Valid policies:
#' - refuse: If feature fails, refuse to produce any output (default)
#' - continue_with_flag: If feature fails, produce PARTIAL output with banner
#'
#' Settings keys (case-insensitive):
#' - shap_on_fail: Policy for SHAP analysis
#' - quadrant_on_fail: Policy for Quadrant analysis
#'
#' @param settings_list Named list of settings
#' @return List with feature policies
#' @keywords internal
parse_feature_policies <- function(settings_list) {

  valid_policies <- c("refuse", "continue_with_flag")

  # Parse SHAP policy
  shap_on_fail <- tolower(trimws(settings_list$shap_on_fail %||% "refuse"))
  if (!shap_on_fail %in% valid_policies) {
    shap_on_fail <- "refuse"  # Default to safer option
  }

  # Parse Quadrant policy
  quadrant_on_fail <- tolower(trimws(settings_list$quadrant_on_fail %||% "refuse"))
  if (!quadrant_on_fail %in% valid_policies) {
    quadrant_on_fail <- "refuse"
  }

  list(
    shap = list(
      enabled = as_logical_setting(settings_list$enable_shap, FALSE),
      on_fail = shap_on_fail
    ),
    quadrant = list(
      enabled = as_logical_setting(settings_list$enable_quadrant, FALSE),
      on_fail = quadrant_on_fail
    )
  )
}


#' Handle Feature Failure Per Policy
#'
#' Handles a feature failure according to the configured policy.
#'
#' @param feature_name Name of the feature (e.g., "SHAP", "Quadrant")
#' @param policy Policy string: "refuse" or "continue_with_flag"
#' @param error_message Error message from the failure
#' @param guard Guard state for tracking
#' @return Updated guard state (if continue) or refuses (if refuse policy)
#' @export
handle_feature_failure <- function(feature_name, policy, error_message, guard) {

  if (policy == "refuse") {
    # Refuse to continue - this is a hard stop
    keydriver_refuse(
      code = paste0("FEATURE_", toupper(feature_name), "_FAILED"),
      title = paste0(feature_name, " Analysis Failed"),
      problem = paste0(feature_name, " analysis failed: ", error_message),
      why_it_matters = paste0(
        "The ", feature_name, " feature is enabled with on_fail='refuse' policy. ",
        "Analysis cannot continue without successful completion of this feature."
      ),
      how_to_fix = c(
        paste0("Fix the underlying ", feature_name, " error (see message above)"),
        paste0("Or set ", tolower(feature_name), "_on_fail='continue_with_flag' in Settings"),
        paste0("Or disable ", feature_name, " by setting enable_", tolower(feature_name), "=FALSE")
      )
    )
  } else {
    # continue_with_flag - record as degradation
    guard <- guard_warn(guard, paste0(feature_name, " failed: ", error_message), tolower(feature_name))

    # Print prominent banner
    cat("\n")
    cat("================================================================================\n")
    cat(sprintf("  [WARNING] %s ANALYSIS FAILED - CONTINUING WITH PARTIAL OUTPUT\n", toupper(feature_name)))
    cat("================================================================================\n")
    cat(sprintf("  Error: %s\n", error_message))
    cat("  The analysis will continue but some outputs will be missing.\n")
    cat("================================================================================\n\n")

    guard
  }
}


# ==============================================================================
# v10.3: DRIVER DECLARATION VALIDATION
# ==============================================================================
# Per TURAS-KD-CONTINUOUS-UPGRADE-v1.0:
# - Each driver MUST have explicit driver_type declaration
# - Inference is forbidden
# - aggregation_method required for categorical drivers

#' Validate Driver Declarations
#'
#' Validates that each driver has required explicit declarations per
#' TURAS-KD-CONTINUOUS-UPGRADE-v1.0 specification.
#'
#' Required fields per driver:
#' - driver_name (from VariableName)
#' - driver_type ∈ {continuous, ordinal, categorical}
#' - source_column (from VariableName, must match data column)
#' - aggregation_method (required only if categorical)
#'
#' @param driver_rows Data frame subset of Variables sheet with Type='Driver'
#' @param variables Full variables data frame
#' @return Data frame with validated driver settings
#' @keywords internal
validate_driver_declarations <- function(driver_rows, variables) {

  # Valid driver types per spec
  valid_driver_types <- c("continuous", "ordinal", "categorical")

  # Valid aggregation methods per spec

  # Check if DriverType column exists
  has_driver_type <- "DriverType" %in% names(driver_rows)

  if (!has_driver_type) {
    # v10.3 UPGRADE: DriverType column is now required
    # Provide helpful migration message
    keydriver_refuse(
      code = "CFG_DRIVER_TYPE_MISSING",
      title = "Driver Type Column Required",
      problem = "The Variables sheet is missing the required 'DriverType' column.",
      why_it_matters = paste0(
        "Per TURAS-KD-CONTINUOUS-UPGRADE-v1.0, each driver must have an explicit ",
        "driver_type declaration. Type inference is no longer permitted to ensure ",
        "reproducible results and prevent silent failures."
      ),
      how_to_fix = c(
        "Add a 'DriverType' column to the Variables sheet",
        "For each driver row, set DriverType to one of: continuous, ordinal, categorical",
        "continuous: for numeric predictors with no natural ordering breaks",
        "ordinal: for ordered categories (will be treated as numeric by default)",
        "categorical: for unordered categories (requires aggregation)"
      ),
      expected = "DriverType column with values: continuous, ordinal, categorical",
      observed = names(driver_rows)
    )
  }

  # Check if AggregationMethod column exists (needed for categorical)
  has_agg_method <- "AggregationMethod" %in% names(driver_rows)

  # Build driver settings data frame
  n_drivers <- nrow(driver_rows)
  driver_settings <- data.frame(
    driver = driver_rows$VariableName,
    driver_type = tolower(trimws(as.character(driver_rows$DriverType))),
    aggregation_method = if (has_agg_method) {
      tolower(trimws(as.character(driver_rows$AggregationMethod)))
    } else {
      rep(NA_character_, n_drivers)
    },
    reference_level = if ("ReferenceLevel" %in% names(driver_rows)) {
      as.character(driver_rows$ReferenceLevel)
    } else {
      rep(NA_character_, n_drivers)
    },
    stringsAsFactors = FALSE
  )

  # Validate each driver
  invalid_types <- character(0)
  configured_agg <- character(0)

  for (i in seq_len(n_drivers)) {
    drv <- driver_settings$driver[i]
    drv_type <- driver_settings$driver_type[i]
    agg_method <- driver_settings$aggregation_method[i]

    # Check driver_type is valid
    if (is.na(drv_type) || !drv_type %in% valid_driver_types) {
      invalid_types <- c(invalid_types, paste0(drv, " (got: '", drv_type, "')"))
    }

    # AggregationMethod is recorded only so the note below can mention it.
    if (!is.na(agg_method) && nzchar(agg_method)) {
      configured_agg <- c(configured_agg, drv)
    }
  }

  # Report invalid driver types
  if (length(invalid_types) > 0) {
    keydriver_refuse(
      code = "CFG_INVALID_DRIVER_TYPE",
      title = "Invalid Driver Type Declaration",
      problem = paste0(length(invalid_types), " driver(s) have invalid or missing DriverType."),
      why_it_matters = paste0(
        "Driver type determines how the variable is encoded and how importance ",
        "scores are calculated. Invalid types cannot be processed."
      ),
      how_to_fix = c(
        "Set DriverType to one of: continuous, ordinal, categorical",
        "Check for typos or extra spaces in DriverType values"
      ),
      expected = paste(valid_driver_types, collapse = ", "),
      missing = invalid_types
    )
  }

  # AggregationMethod is not validated any more, and the column decides
  # nothing. It refused a run over a value that no code path read: the only
  # consumer was the v10.3 engine, which nothing called and which is now
  # deleted (review H3). A config that still carries the column is told once
  # rather than refused, because the analysis it asks for is unaffected.
  if (length(configured_agg) > 0) {
    cat(sprintf(paste0(
      "   [NOTE] The Drivers sheet sets AggregationMethod for %d driver(s). ",
      "That setting is withdrawn and nothing reads it: importance is computed ",
      "by Shapley decomposition, with a categorical driver's model terms ",
      "aggregated by the term mapping. You can delete the column.\n"),
      length(configured_agg)))
  }

  driver_settings
}


#' Get Driver Type for a Variable
#'
#' Retrieves the declared driver type from config settings.
#'
#' @param driver_name Driver variable name
#' @param driver_settings Driver settings data frame from config
#' @return Driver type string or NULL if not found
#' @export
get_driver_type <- function(driver_name, driver_settings) {
  if (is.null(driver_settings) || !is.data.frame(driver_settings)) {
    return(NULL)
  }
  idx <- match(driver_name, driver_settings$driver)
  if (is.na(idx)) {
    return(NULL)
  }
  driver_settings$driver_type[idx]
}


#' Get Aggregation Method for a Driver
#'
#' Retrieves the aggregation method for categorical drivers.
#'
#' @param driver_name Driver variable name
#' @param driver_settings Driver settings data frame from config
#' @return Aggregation method string or NULL if not applicable
#' @export
get_aggregation_method <- function(driver_name, driver_settings) {
  if (is.null(driver_settings) || !is.data.frame(driver_settings)) {
    return(NULL)
  }
  idx <- match(driver_name, driver_settings$driver)
  if (is.na(idx)) {
    return(NULL)
  }
  agg <- driver_settings$aggregation_method[idx]
  if (is.na(agg) || !nzchar(agg)) {
    return(NULL)
  }
  agg
}
