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
    accent_colour = get_config_value(config, "accent_colour", "#CC9900"),
    project_title = get_config_value(config, "project_title", NULL),
    company_name = get_config_value(config, "company_name", "The Research Lamppost"),
    client_name = get_config_value(config, "client_name", NULL),
    researcher_logo_path = get_config_value(config, "researcher_logo_path", NULL),
    client_logo_path = get_config_value(config, "client_logo_path", NULL),
    logo_path = get_config_value(config, "logo_path", NULL),
    chart_bar_colour = get_config_value(config, "chart_bar_colour", NULL),
    chart_palette_preset = get_config_value(config, "chart_palette_preset", "warm"),
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
    dashboard_sort_gauges   = get_config_value(config, "dashboard_sort_gauges", "desc"),

    # V10.4.3 Row descriptors (shown below summary stat rows in HTML crosstabs)
    index_descriptor = get_config_value(config, "index_descriptor", NULL),
    mean_descriptor = get_config_value(config, "mean_descriptor", NULL),
    nps_descriptor = get_config_value(config, "nps_descriptor", NULL),

    # V10.5.0 Inline SVG charts
    show_charts = safe_logical(get_config_value(config, "show_charts", FALSE)),

    # V10.6.0 Report enhancements
    priority_metric = get_config_value(config, "priority_metric", NULL),

    # V10.7.0 Closing section & qualitative content
    analyst_name = get_config_value(config, "analyst_name", NULL),
    analyst_email = get_config_value(config, "analyst_email", NULL),
    analyst_phone = get_config_value(config, "analyst_phone", NULL),
    verbatim_filename = get_config_value(config, "verbatim_filename", NULL),
    closing_notes = get_config_value(config, "closing_notes", NULL)
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

    # Use .read_table_sheet to auto-detect header row (template format support)
    required_cols <- c("QuestionCode", "Comment")
    df <- tryCatch(
      .read_table_sheet(config_file, "Comments", required_cols),
      error = function(e) NULL
    )
    if (is.null(df) || nrow(df) == 0) return(NULL)

    # Require QuestionCode and Comment columns
    if (!all(required_cols %in% names(df))) {
      cat("  [INFO] Comments sheet found but missing QuestionCode/Comment columns - skipped\n")
      return(NULL)
    }

    # Filter valid rows
    df <- df[!is.na(df$QuestionCode) & nzchar(trimws(df$QuestionCode)) &
             !is.na(df$Comment) & nzchar(trimws(df$Comment)), , drop = FALSE]
    if (nrow(df) == 0) return(NULL)

    # Support optional Banner column for multi-banner comments
    has_banner <- "Banner" %in% names(df)

    # Extract special dashboard text entries (V10.8.0)
    # Use _BACKGROUND and _EXECUTIVE_SUMMARY as reserved QuestionCode values
    special_codes <- c("_BACKGROUND", "_EXECUTIVE_SUMMARY")
    background_text <- NULL
    executive_summary <- NULL

    for (i in seq_len(nrow(df))) {
      q_code <- trimws(toupper(df$QuestionCode[i]))
      if (q_code == "_BACKGROUND") {
        background_text <- trimws(df$Comment[i])
      } else if (q_code == "_EXECUTIVE_SUMMARY") {
        executive_summary <- trimws(df$Comment[i])
      }
    }

    # Filter out special rows from question comments
    df <- df[!trimws(toupper(df$QuestionCode)) %in% special_codes, , drop = FALSE]

    # Build structure: comments[[q_code]] = list of list(banner, text)
    comments <- list()
    for (i in seq_len(nrow(df))) {
      q_code <- trimws(df$QuestionCode[i])
      banner <- if (has_banner && !is.na(df$Banner[i]) && nzchar(trimws(df$Banner[i]))) {
        trimws(df$Banner[i])
      } else {
        NA_character_  # Serializes as JSON null (not {} like R NULL)
      }
      entry <- list(banner = banner, text = trimws(df$Comment[i]))
      if (is.null(comments[[q_code]])) {
        comments[[q_code]] <- list(entry)
      } else {
        comments[[q_code]] <- c(comments[[q_code]], list(entry))
      }
    }

    n_total <- if (length(comments) > 0) sum(vapply(comments, length, integer(1))) else 0L
    cat(sprintf("  [INFO] Loaded %d comments for %d questions from Comments sheet\n",
                n_total, length(comments)))

    if (!is.null(background_text)) cat(sprintf("  [INFO] Background text loaded from Comments sheet\n"))
    if (!is.null(executive_summary)) cat(sprintf("  [INFO] Executive summary loaded from Comments sheet\n"))

    # Attach dashboard text as attributes
    attr(comments, "background_text") <- background_text
    attr(comments, "executive_summary") <- executive_summary

    comments
  }, error = function(e) {
    cat(sprintf("  [WARNING] Could not read Comments sheet: %s\n", e$message))
    NULL
  })
}


# ==============================================================================
# ADDED SLIDES SHEET LOADER (V10.8.0, renamed from Qualitative)
# ==============================================================================

#' Load Optional AddedSlides Sheet from Config Excel
#'
#' Reads an "AddedSlides" sheet from the config workbook if it exists.
#' Also checks for legacy "Qualitative" sheet name for backward compatibility.
#' Expected columns: slide_title, content (markdown), display_order (optional).
#' Returns a list of slide objects or NULL if sheet is absent.
#'
#' @param config_file Character, path to config Excel file
#' @return List of slide objects, or NULL
#' @keywords internal
load_qualitative_sheet <- function(config_file) {
  tryCatch({
    sheets <- openxlsx::getSheetNames(config_file)

    # V10.8.0: Check for "AddedSlides" first, fall back to legacy "Qualitative"
    sheet_name <- if ("AddedSlides" %in% sheets) "AddedSlides"
                  else if ("Qualitative" %in% sheets) "Qualitative"
                  else return(NULL)

    # Use .read_table_sheet to auto-detect header row (template format support)
    required_cols <- c("slide_title", "content")
    df <- tryCatch(
      .read_table_sheet(config_file, sheet_name, required_cols),
      error = function(e) NULL
    )
    if (is.null(df) || nrow(df) == 0) return(NULL)

    if (!"slide_title" %in% names(df) || !"content" %in% names(df)) {
      cat(sprintf("  [INFO] %s sheet found but missing slide_title/content columns - skipped\n", sheet_name))
      return(NULL)
    }

    # Filter valid rows
    df <- df[!is.na(df$slide_title) & nzchar(trimws(df$slide_title)), , drop = FALSE]
    if (nrow(df) == 0) return(NULL)

    # Add display_order if not present
    if (!"display_order" %in% names(df)) {
      df$display_order <- seq_len(nrow(df))
    }
    df <- df[order(df$display_order), , drop = FALSE]

    # V10.8.0: Resolve image_path relative to config file directory
    config_dir <- dirname(normalizePath(config_file, mustWork = FALSE))
    has_image_col <- "image_path" %in% names(df)

    slides <- lapply(seq_len(nrow(df)), function(i) {
      slide <- list(
        id = sprintf("qual-slide-%d", i),
        title = trimws(df$slide_title[i]),
        content = trimws(df$content[i] %||% ""),
        order = i,
        image_data = NULL
      )

      # Embed image as base64 if image_path is provided
      if (has_image_col && !is.na(df$image_path[i]) && nzchar(trimws(df$image_path[i]))) {
        img_path <- trimws(df$image_path[i])
        # Resolve relative paths against config directory
        if (!file.exists(img_path)) {
          img_path <- file.path(config_dir, img_path)
        }
        if (file.exists(img_path) && requireNamespace("base64enc", quietly = TRUE)) {
          tryCatch({
            raw <- readBin(img_path, "raw", file.info(img_path)$size)
            ext <- tolower(tools::file_ext(img_path))
            mime <- switch(ext,
              png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg",
              gif = "image/gif", webp = "image/webp", svg = "image/svg+xml",
              "image/png"  # fallback
            )
            slide$image_data <- sprintf("data:%s;base64,%s",
              mime, base64enc::base64encode(raw))
            cat(sprintf("  [INFO] Embedded image for slide '%s' (%s, %dKB)\n",
              slide$title, basename(img_path), round(length(raw) / 1024)))
          }, error = function(e) {
            cat(sprintf("  [WARNING] Could not embed image '%s': %s\n", img_path, e$message))
          })
        } else {
          cat(sprintf("  [WARNING] Image file not found for slide '%s': %s\n",
            slide$title, img_path))
        }
      }

      slide
    })

    cat(sprintf("  [INFO] Loaded %d added slides from %s sheet\n", length(slides), sheet_name))
    slides
  }, error = function(e) {
    cat(sprintf("  [WARNING] Could not read AddedSlides/Qualitative sheet: %s\n", e$message))
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

  # Check for unrecognised settings — typos are silently ignored otherwise
  .KNOWN_SETTINGS <- c(
    # Weighting
    "apply_weighting", "weight_variable", "show_unweighted_n", "show_effective_n", "weight_label",
    "default_weight", "weight_column_exists",
    "weight_na_threshold", "weight_zero_threshold", "weight_deff_warning",
    # Display — frequencies and percentages
    "decimal_separator", "show_frequency", "show_percent_column", "show_percent_row",
    "boxcategory_frequency", "boxcategory_percent_column", "boxcategory_percent_row",
    "decimal_places", "decimal_places_percent", "decimal_places_ratings",
    "decimal_places_index", "decimal_places_numeric",
    # Statistics
    "show_standard_deviation", "show_net_positive", "show_numeric_median",
    "show_numeric_mode", "show_numeric_outliers", "exclude_outliers_from_stats", "outlier_method",
    "test_net_differences", "zero_division_as_blank",
    # Significance testing
    "enable_significance_testing", "alpha", "significance_level",
    "significance_min_base", "bonferroni_correction", "enable_chi_square",
    # Checkpointing
    "enable_checkpointing",
    # Sample composition & index summary
    "create_sample_composition", "create_index_summary",
    "index_summary_show_sections", "index_summary_show_base_sizes",
    "index_summary_show_composites", "index_summary_decimal_places",
    # HTML report
    "html_report", "brand_colour", "accent_colour", "project_title", "project_name",
    "company_name", "client_name",
    "researcher_logo_path", "client_logo_path", "logo_path",
    "chart_bar_colour", "chart_palette_preset", "embed_frequencies",
    "include_summary", "fieldwork_dates", "show_charts",
    # Dashboard
    "dashboard_metrics", "dashboard_scale_mean", "dashboard_scale_index",
    "dashboard_green_net", "dashboard_amber_net",
    "dashboard_green_mean", "dashboard_amber_mean",
    "dashboard_green_index", "dashboard_amber_index",
    "dashboard_green_custom", "dashboard_amber_custom", "dashboard_sort_gauges",
    "priority_metric",
    # Descriptors
    "index_descriptor", "mean_descriptor", "nps_descriptor",
    # Analyst / report metadata
    "analyst_name", "analyst_email", "analyst_phone", "verbatim_filename", "closing_notes",
    # Ranking
    "ranking_completeness_threshold_pct", "ranking_gap_threshold_pct", "ranking_tie_threshold_pct",
    "ranking_min_base",
    # File path settings (loaded separately but may appear in Settings sheet)
    "data_file", "structure_file", "output_file", "output_filename",
    "output_format", "output_folder", "output_subfolder"
  )
  user_settings <- names(settings$config)
  unknown_settings <- setdiff(tolower(trimws(user_settings)), .KNOWN_SETTINGS)
  if (length(unknown_settings) > 0) {
    cat("\n  WARNING: Unrecognised settings in config (may be typos):\n")
    for (us in unknown_settings) {
      cat("    -", us, "\n")
    }
    cat("  These settings will be ignored. Check spelling against the template.\n\n")
  }

  # Load optional Comments sheet (V10.6.0)
  config_obj$comments <- load_comments_sheet(config_file)

  # Extract dashboard text from Comments sheet (V10.8.0)
  if (!is.null(config_obj$comments)) {
    config_obj$background_text <- attr(config_obj$comments, "background_text")
    config_obj$executive_summary <- attr(config_obj$comments, "executive_summary")
  }

  # Load optional AddedSlides sheet (V10.8.0, renamed from Qualitative)
  config_obj$qualitative_slides <- load_qualitative_sheet(config_file)

  # Resolve logo paths against project root so HTML report gets absolute paths
  # Helper: resolve a single logo path, trying multiple candidate locations
  resolve_logo_path <- function(raw_path, label) {
    if (is.null(raw_path) || !nzchar(raw_path)) return(NULL)
    if (file.exists(raw_path)) {
      resolved <- normalizePath(raw_path)
      cat(sprintf("  %s: %s\n", label, basename(resolved)))
      return(resolved)
    }
    candidates <- c(
      file.path(project_root, raw_path),
      file.path(dirname(config_file), raw_path),
      file.path(project_root, basename(raw_path)),
      file.path(dirname(config_file), basename(raw_path))
    )
    for (cand in candidates) {
      if (file.exists(cand)) {
        resolved <- normalizePath(cand)
        cat(sprintf("  %s: resolved to %s\n", label, resolved))
        return(resolved)
      }
    }
    cat(sprintf("  [WARNING] %s not found: %s\n", label, raw_path))
    cat(sprintf("  Searched in: %s, %s\n", project_root, dirname(config_file)))
    return(raw_path)
  }

  config_obj$researcher_logo_path <- resolve_logo_path(
    config_obj$researcher_logo_path, "Researcher logo")
  config_obj$client_logo_path <- resolve_logo_path(
    config_obj$client_logo_path, "Client logo")
  # Legacy single logo_path: used as researcher logo fallback
  config_obj$logo_path <- resolve_logo_path(
    config_obj$logo_path, "Logo")

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
