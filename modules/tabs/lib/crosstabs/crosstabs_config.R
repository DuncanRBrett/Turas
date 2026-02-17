# ==============================================================================
# CROSSTABS_CONFIG.R - TURAS V10.2 (Phase 4 Refactoring)
# ==============================================================================
# Extracted from run_crosstabs.R for better modularity
#
# PURPOSE: Configuration loading and config object building
#
# FUNCTIONS:
#   - validate_config_file() - Validate config file exists
#   - load_crosstabs_settings() - Load settings from config file
#   - build_config_object() - Build the config_obj with all settings
#   - load_output_settings() - Load output path settings
#
# DEPENDENCIES:
#   - config_utils.R (for load_config_sheet, get_config_value)
#   - type_utils.R (for safe_logical, safe_numeric)
#   - path_utils.R (for resolve_path, get_project_root)
#   - 00_guard.R (for tabs_refuse)
#   - logging_utils.R (for log_message)
#
# ==============================================================================

# Default constants (should match run_crosstabs.R)
.DEFAULT_ALPHA <- 0.05
.DEFAULT_MIN_BASE <- 30

# ==============================================================================
# VALIDATION
# ==============================================================================

#' Validate Config File Exists
#'
#' Checks that the config_file variable is defined and the file exists.
#'
#' @param config_file Character, path to config file (or NULL if undefined)
#' @return Invisible TRUE if valid
#' @export
validate_config_file <- function(config_file = NULL) {
  # Check if config_file is defined
  if (is.null(config_file) || !exists("config_file", envir = parent.frame())) {
    tabs_refuse(
      code = "CFG_NO_CONFIG_FILE",
      title = "Configuration File Not Defined",
      problem = "The config_file variable is not defined.",
      why_it_matters = "Analysis requires a configuration file to specify data sources and settings.",
      how_to_fix = c(
        "Run this script from the Jupyter notebook entry point",
        "Or set config_file variable before sourcing this script"
      )
    )
  }

  invisible(TRUE)
}


#' Validate Structure File Exists
#'
#' Checks that the survey structure file exists at the specified path.
#'
#' @param structure_file_path Character, path to structure file
#' @return Invisible TRUE if valid
validate_structure_file <- function(structure_file_path) {
  if (!file.exists(structure_file_path)) {
    tabs_refuse(
      code = "IO_STRUCTURE_FILE_NOT_FOUND",
      title = "Survey Structure File Not Found",
      problem = paste0("Cannot find survey structure file: ", basename(structure_file_path)),
      why_it_matters = "The survey structure defines questions and options needed for crosstabs.",
      how_to_fix = c(
        "Check that the structure_file path in Settings is correct",
        "Verify Survey_Structure.xlsx exists in your project folder"
      ),
      details = paste0("Expected path: ", structure_file_path)
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# CONFIG LOADING
# ==============================================================================

#' Load Crosstabs Settings from Config File
#'
#' Loads the Settings sheet from the config file and extracts key paths.
#'
#' @param config_file Character, path to config file
#' @param project_root Character, project root directory
#' @return List with config data frame and paths
#' @export
load_crosstabs_settings <- function(config_file, project_root) {
  log_message("Loading configuration...", "INFO")

  # Load settings sheet
  config <- load_config_sheet(config_file, "Settings")

  # Get structure file path
  structure_file <- get_config_value(config, "structure_file", required = TRUE)
  structure_file_path <- resolve_path(project_root, structure_file)

  # Validate structure file exists
  validate_structure_file(structure_file_path)

  # Get output settings
  output_subfolder <- get_config_value(config, "output_subfolder", "Crosstabs")
  output_filename <- get_config_value(config, "output_filename", "Crosstabs.xlsx")

  log_message("Configuration loaded", "INFO")

  list(
    config = config,
    structure_file_path = structure_file_path,
    output_subfolder = output_subfolder,
    output_filename = output_filename
  )
}


#' Build Configuration Object
#'
#' Builds the config_obj list with all analysis settings.
#' Uses safe_logical and safe_numeric for type conversion.
#'
#' @param config Data frame, loaded settings
#' @param default_alpha Numeric, default alpha value (default: 0.05)
#' @param default_min_base Integer, default minimum base (default: 30)
#' @return List, configuration object
#' @export
build_config_object <- function(config, default_alpha = .DEFAULT_ALPHA,
                                 default_min_base = .DEFAULT_MIN_BASE) {
  list(
    # Weighting settings
    apply_weighting = safe_logical(get_config_value(config, "apply_weighting", FALSE)),
    weight_variable = get_config_value(config, "weight_variable", NULL),
    show_unweighted_n = safe_logical(get_config_value(config, "show_unweighted_n", TRUE)),
    show_effective_n = safe_logical(get_config_value(config, "show_effective_n", TRUE)),
    weight_label = get_config_value(config, "weight_label", "Weighted"),

    # Display settings
    decimal_separator = get_config_value(config, "decimal_separator", "."),
    show_frequency = safe_logical(get_config_value(config, "show_frequency", TRUE)),
    show_percent_column = safe_logical(get_config_value(config, "show_percent_column", TRUE)),
    show_percent_row = safe_logical(get_config_value(config, "show_percent_row", FALSE)),

    # Box category settings
    boxcategory_frequency = safe_logical(get_config_value(config, "boxcategory_frequency", FALSE)),
    boxcategory_percent_column = safe_logical(get_config_value(config, "boxcategory_percent_column", TRUE)),
    boxcategory_percent_row = safe_logical(get_config_value(config, "boxcategory_percent_row", FALSE)),

    # Decimal places
    decimal_places_percent = safe_numeric(get_config_value(config, "decimal_places_percent", 0)),
    decimal_places_ratings = safe_numeric(get_config_value(config, "decimal_places_ratings", 1)),
    decimal_places_index = safe_numeric(get_config_value(config, "decimal_places_index", 1)),
    decimal_places_numeric = safe_numeric(get_config_value(config, "decimal_places_numeric", 1)),

    # Significance testing
    enable_significance_testing = safe_logical(get_config_value(config, "enable_significance_testing", TRUE)),
    alpha = safe_numeric(get_config_value(config, "alpha", default_alpha)),
    significance_min_base = safe_numeric(get_config_value(config, "significance_min_base", default_min_base)),
    bonferroni_correction = safe_logical(get_config_value(config, "bonferroni_correction", TRUE)),

    # Checkpointing
    enable_checkpointing = safe_logical(get_config_value(config, "enable_checkpointing", TRUE)),

    # Output formatting
    zero_division_as_blank = safe_logical(get_config_value(config, "zero_division_as_blank", TRUE)),

    # V9.9.5 features
    show_standard_deviation = safe_logical(get_config_value(config, "show_standard_deviation", FALSE)),
    test_net_differences = safe_logical(get_config_value(config, "test_net_differences", FALSE)),
    create_sample_composition = safe_logical(get_config_value(config, "create_sample_composition", FALSE)),
    enable_chi_square = safe_logical(get_config_value(config, "enable_chi_square", FALSE)),
    show_net_positive = safe_logical(get_config_value(config, "show_net_positive", FALSE)),

    # V10.0.0 numeric question settings
    show_numeric_median = safe_logical(get_config_value(config, "show_numeric_median", FALSE)),
    show_numeric_mode = safe_logical(get_config_value(config, "show_numeric_mode", FALSE)),
    show_numeric_outliers = safe_logical(get_config_value(config, "show_numeric_outliers", TRUE)),
    exclude_outliers_from_stats = safe_logical(get_config_value(config, "exclude_outliers_from_stats", FALSE)),
    outlier_method = get_config_value(config, "outlier_method", "IQR"),

    # V10.3 HTML Report settings
    html_report = safe_logical(get_config_value(config, "html_report", FALSE)),
    brand_colour = get_config_value(config, "brand_colour", "#323367"),
    project_title = get_config_value(config, "project_title", NULL),
    embed_frequencies = safe_logical(get_config_value(config, "embed_frequencies", TRUE)),

    # V10.4 Summary Dashboard settings
    include_summary = safe_logical(get_config_value(config, "include_summary", TRUE)),
    fieldwork_dates = get_config_value(config, "fieldwork_dates", NULL),
    dashboard_metrics = get_config_value(config, "dashboard_metrics", "NET POSITIVE"),

    # V10.4.2 Dashboard colour breaks & scales (all optional, sensible defaults)
    dashboard_scale_mean    = safe_numeric(get_config_value(config, "dashboard_scale_mean", 10)),
    dashboard_scale_index   = safe_numeric(get_config_value(config, "dashboard_scale_index", 10)),
    dashboard_green_net     = safe_numeric(get_config_value(config, "dashboard_green_net", 30)),
    dashboard_amber_net     = safe_numeric(get_config_value(config, "dashboard_amber_net", 0)),
    dashboard_green_mean    = safe_numeric(get_config_value(config, "dashboard_green_mean", 7)),
    dashboard_amber_mean    = safe_numeric(get_config_value(config, "dashboard_amber_mean", 5)),
    dashboard_green_index   = safe_numeric(get_config_value(config, "dashboard_green_index", 7)),
    dashboard_amber_index   = safe_numeric(get_config_value(config, "dashboard_amber_index", 5)),
    dashboard_green_custom  = safe_numeric(get_config_value(config, "dashboard_green_custom", 60)),
    dashboard_amber_custom  = safe_numeric(get_config_value(config, "dashboard_amber_custom", 40)),

    # V10.4.3 Index descriptor (shown below Index row in HTML crosstabs)
    index_descriptor = get_config_value(config, "index_descriptor", NULL),

    # V10.5.0 Inline SVG charts
    show_charts = safe_logical(get_config_value(config, "show_charts", FALSE)),

    # V10.6.0 Report enhancements
    priority_metric = get_config_value(config, "priority_metric", NULL),
    company_name = get_config_value(config, "company_name", "The Research Lamppost")
  )
}


#' Get Output Path
#'
#' Constructs the full output file path.
#'
#' @param project_root Character, project root directory
#' @param output_subfolder Character, output subfolder name
#' @param output_filename Character, output file name
#' @return Character, full output path
#' @export
get_output_path <- function(project_root, output_subfolder, output_filename) {
  resolve_path(project_root, file.path(output_subfolder, output_filename))
}


# ==============================================================================
# COMMENTS SHEET LOADER (V10.6.0)
# ==============================================================================

#' Load Optional Comments Sheet from Config Excel
#'
#' Reads a "Comments" sheet from the config workbook if it exists.
#' Expected columns: QuestionCode, Comment.
#' Returns a named list (keyed by question code) or NULL if sheet is absent.
#'
#' @param config_file Character, path to config Excel file
#' @return Named list of comments keyed by QuestionCode, or NULL
#' @keywords internal
load_comments_sheet <- function(config_file) {
  tryCatch({
    sheets <- openxlsx::getSheetNames(config_file)
    if (!"Comments" %in% sheets) return(NULL)

    df <- openxlsx::read.xlsx(config_file, sheet = "Comments")
    if (is.null(df) || nrow(df) == 0) return(NULL)

    # Require QuestionCode and Comment columns
    if (!all(c("QuestionCode", "Comment") %in% names(df))) {
      cat("  [INFO] Comments sheet found but missing QuestionCode/Comment columns - skipped\n")
      return(NULL)
    }

    # Filter valid rows
    df <- df[!is.na(df$QuestionCode) & nzchar(trimws(df$QuestionCode)) &
             !is.na(df$Comment) & nzchar(trimws(df$Comment)), , drop = FALSE]
    if (nrow(df) == 0) return(NULL)

    # Support optional Banner column for multi-banner comments
    has_banner <- "Banner" %in% names(df)

    # Build structure: comments[[q_code]] = list of list(banner, text)
    comments <- list()
    for (i in seq_len(nrow(df))) {
      q_code <- trimws(df$QuestionCode[i])
      banner <- if (has_banner && !is.na(df$Banner[i]) && nzchar(trimws(df$Banner[i]))) {
        trimws(df$Banner[i])
      } else {
        NULL
      }
      entry <- list(banner = banner, text = trimws(df$Comment[i]))
      if (is.null(comments[[q_code]])) {
        comments[[q_code]] <- list(entry)
      } else {
        comments[[q_code]] <- c(comments[[q_code]], list(entry))
      }
    }

    n_total <- sum(sapply(comments, length))
    cat(sprintf("  [INFO] Loaded %d comments for %d questions from Comments sheet\n",
                n_total, length(comments)))
    comments
  }, error = function(e) {
    cat(sprintf("  [WARNING] Could not read Comments sheet: %s\n", e$message))
    NULL
  })
}


# ==============================================================================
# FULL CONFIGURATION LOADER
# ==============================================================================

#' Load Complete Crosstabs Configuration
#'
#' Main entry point for loading all configuration.
#' Loads settings, builds config object, and returns all needed paths.
#'
#' @param config_file Character, path to config file
#' @return List with all configuration components
#' @export
load_crosstabs_config <- function(config_file) {
  # Get project root

  project_root <- get_project_root(config_file)
  log_message(sprintf("Project root: %s", project_root), "INFO")

  # Load settings
  settings <- load_crosstabs_settings(config_file, project_root)

  # Build config object
  config_obj <- build_config_object(settings$config)

  # Load optional Comments sheet (V10.6.0)
  config_obj$comments <- load_comments_sheet(config_file)

  # Resolve logo_path against project root so HTML report gets an absolute path
  if (!is.null(config_obj$logo_path) && nzchar(config_obj$logo_path)) {
    logo_raw <- config_obj$logo_path
    if (!file.exists(logo_raw)) {
      # Try relative to project root, then config file directory
      candidates <- c(
        file.path(project_root, logo_raw),
        file.path(dirname(config_file), logo_raw),
        file.path(project_root, basename(logo_raw)),
        file.path(dirname(config_file), basename(logo_raw))
      )
      for (cand in candidates) {
        if (file.exists(cand)) {
          config_obj$logo_path <- normalizePath(cand)
          cat(sprintf("  Logo: resolved to %s\n", config_obj$logo_path))
          break
        }
      }
    } else {
      config_obj$logo_path <- normalizePath(logo_raw)
    }
    if (!file.exists(config_obj$logo_path)) {
      cat(sprintf("  [WARNING] Logo file not found: %s\n", logo_raw))
      cat(sprintf("  Searched in: %s, %s\n", project_root, dirname(config_file)))
    }
  }

  # Build output path
  output_path <- get_output_path(
    project_root,
    settings$output_subfolder,
    settings$output_filename
  )

  list(
    project_root = project_root,
    config_file = config_file,
    config_obj = config_obj,
    structure_file_path = settings$structure_file_path,
    output_subfolder = settings$output_subfolder,
    output_filename = settings$output_filename,
    output_path = output_path
  )
}
