# ==============================================================================
# BRAND MODULE - CONFIG LOADER
# ==============================================================================
# Loads and validates Brand_Config.xlsx and Survey_Structure.xlsx into
# structured lists used by all analytical elements.
#
# VERSION: 1.0
#
# DEPENDENCIES:
# - openxlsx
# - modules/shared/lib/config_utils.R
# - modules/brand/R/00_guard.R
# ==============================================================================

BRAND_CONFIG_LOADER_VERSION <- "1.0"


#' Parse a Y/N config value to logical
#'
#' Handles Y, N, YES, NO, TRUE, FALSE, 1, 0 (case-insensitive).
#'
#' @param val Value to parse.
#' @param default Default if NULL or empty.
#'
#' @return Logical.
#'
#' @keywords internal
.parse_yn <- function(val, default = FALSE) {
  if (is.null(val) || length(val) == 0 || is.na(val)) return(default)
  if (is.logical(val)) return(val)
  val <- toupper(trimws(as.character(val)))
  if (val %in% c("Y", "YES", "TRUE", "1")) return(TRUE)
  if (val %in% c("N", "NO", "FALSE", "0")) return(FALSE)
  default
}


#' Load Brand_Config.xlsx
#'
#' Reads the brand config Excel file and returns a structured list with
#' all settings, categories, and DBA assets. All guard validations are
#' applied during loading.
#'
#' @param config_path Character. Path to Brand_Config.xlsx.
#' @param project_root Character. Project root directory. If NULL, derived
#'   from config_path location.
#'
#' @return List with all config settings, categories, and DBA assets.
#'   Returns a TRS refusal if validation fails.
#'
#' @export
load_brand_config <- function(config_path, project_root = NULL) {

  # Validate file exists
  if (!file.exists(config_path)) {
    brand_refuse(
      code = "IO_CONFIG_NOT_FOUND",
      title = "Config File Not Found",
      problem = sprintf("Brand_Config.xlsx not found at: %s", config_path),
      why_it_matters = "Cannot run brand analysis without configuration",
      how_to_fix = c(
        "Check the file path",
        "Generate a template with generate_brand_config_template()"
      )
    )
  }

  if (is.null(project_root)) {
    project_root <- dirname(config_path)
  }

  # Load Settings sheet
  settings_raw <- tryCatch(
    openxlsx::read.xlsx(config_path, sheet = "Settings", colNames = FALSE),
    error = function(e) {
      brand_refuse(
        code = "IO_CONFIG_READ_FAILED",
        title = "Cannot Read Config File",
        problem = sprintf("Failed to read Brand_Config.xlsx: %s", e$message),
        why_it_matters = "Config file may be corrupted or in wrong format",
        how_to_fix = c("Check the file is a valid .xlsx file",
                       "Regenerate with generate_brand_config_template()")
      )
    }
  )

  # Parse settings into named list (skip header/section rows)
  config <- list()
  if (!is.null(settings_raw) && nrow(settings_raw) > 0) {
    for (i in seq_len(nrow(settings_raw))) {
      setting_name <- as.character(settings_raw[i, 1])
      setting_value <- settings_raw[i, 2]

      # Skip NA, blank, and non-setting rows
      if (is.na(setting_name) || trimws(setting_name) == "") next

      # Skip known header/meta rows
      if (setting_name %in% c("Setting", "Legend:", "Value",
                               "Required?", "Description",
                               "Valid Values / Notes")) next
      if (grepl("^TURAS|^Edit the", setting_name)) next

      # Skip section header rows (all-caps words/spaces/symbols, no value)
      if (grepl("^[A-Z &(),/=]+$", setting_name) &&
          (is.na(setting_value) || trimws(as.character(setting_value)) == "")) next

      config[[trimws(setting_name)]] <- setting_value
    }
  }

  # Parse element toggles to logical
  element_fields <- c("element_funnel", "element_mental_avail", "element_cep_turf",
                       "element_repertoire", "element_dba", "element_portfolio",
                       "element_wom", "element_drivers_barriers")
  for (ef in element_fields) {
    config[[ef]] <- .parse_yn(config[[ef]], default = (ef != "element_dba"))
  }

  # Parse other Y/N fields
  yn_fields <- c("cross_category_awareness", "cross_category_pen_light",
                  "db_use_catdriver", "output_html", "output_excel",
                  "output_csv", "tracker_ids", "show_about_section")
  for (yf in yn_fields) {
    config[[yf]] <- .parse_yn(config[[yf]], default = TRUE)
  }

  # Parse numeric fields
  numeric_fields <- c("wave", "alpha", "alpha_secondary", "min_base_size",
                       "low_base_warning", "dba_fame_threshold",
                       "dba_uniqueness_threshold")
  for (nf in numeric_fields) {
    if (!is.null(config[[nf]]) && !is.na(config[[nf]])) {
      config[[nf]] <- suppressWarnings(as.numeric(config[[nf]]))
    }
  }

  # Set defaults for missing optional settings
  config$study_type <- config$study_type %||% "cross-sectional"
  config$focal_assignment <- config$focal_assignment %||% "balanced"
  config$wave <- config$wave %||% 1
  config$alpha <- config$alpha %||% 0.05
  config$min_base_size <- config$min_base_size %||% 30
  config$low_base_warning <- config$low_base_warning %||% 75
  config$dba_scope <- config$dba_scope %||% "brand"
  config$dba_fame_threshold <- config$dba_fame_threshold %||% 0.50
  config$dba_uniqueness_threshold <- config$dba_uniqueness_threshold %||% 0.50
  config$dba_attribution_type <- config$dba_attribution_type %||% "open"
  config$wom_timeframe <- config$wom_timeframe %||% "3 months"
  config$target_timeframe_months <- as.integer(
    config$target_timeframe_months %||% 3L)
  config$longer_timeframe_months <- as.integer(
    config$longer_timeframe_months %||% 12L)
  config$db_importance_method <- config$db_importance_method %||% "differential"
  config$decimal_places <- as.integer(config$decimal_places %||% 0L)
  config$colour_focal <- config$colour_focal %||% "#1A5276"
  config$colour_focal_accent <- config$colour_focal_accent %||% "#2E86C1"
  config$colour_competitor <- config$colour_competitor %||% "#B0B0B0"
  config$colour_category_avg <- config$colour_category_avg %||% "#808080"
  config$respondent_id_col <- config$respondent_id_col %||% "Respondent_ID"
  config$report_title <- config$report_title %||% "Brand Health Report"

  # Store project root and resolve all file paths
  # All paths in config are relative to the config file's directory.
  # This ensures configs work when synced via OneDrive/Dropbox across machines.
  config$project_root <- project_root
  config$config_path <- config_path

  # Resolve data_file path
  if (!is.null(config$data_file) && nchar(trimws(config$data_file)) > 0) {
    if (exists("resolve_path", mode = "function")) {
      config$data_file_resolved <- resolve_path(project_root, config$data_file)
    } else {
      config$data_file_resolved <- file.path(project_root, config$data_file)
    }
  }

  # Resolve structure_file path
  if (!is.null(config$structure_file) && nchar(trimws(config$structure_file)) > 0) {
    if (exists("resolve_path", mode = "function")) {
      config$structure_file_resolved <- resolve_path(project_root, config$structure_file)
    } else {
      config$structure_file_resolved <- file.path(project_root, config$structure_file)
    }
  }

  # Resolve output_dir path
  if (!is.null(config$output_dir) && nchar(trimws(config$output_dir)) > 0) {
    if (exists("resolve_path", mode = "function")) {
      config$output_dir_resolved <- resolve_path(project_root, config$output_dir)
    } else {
      config$output_dir_resolved <- file.path(project_root, config$output_dir)
    }
  }

  # Load Categories sheet (auto-detect format: template with title rows, or simple)
  categories <- tryCatch({
    # Try simple format first (headers in row 1) - most reliable
    cats <- openxlsx::read.xlsx(config_path, sheet = "Categories", startRow = 1)
    # If "Category" column not found in row-1 read, the sheet has title/description
    # rows — scan startRow 2, 3, 4 until we find the real headers
    if (!is.null(cats) && !"Category" %in% names(cats)) {
      for (.sr in 2:4) {
        cats2 <- tryCatch(
          openxlsx::read.xlsx(config_path, sheet = "Categories", startRow = .sr),
          error = function(e) NULL)
        if (!is.null(cats2) && "Category" %in% names(cats2)) { cats <- cats2; break }
      }
    }
    cats
  }, error = function(e) {
    brand_refuse(
      code = "IO_CATEGORIES_READ_FAILED",
      title = "Cannot Read Categories Sheet",
      problem = sprintf("Failed to read Categories sheet: %s", e$message),
      why_it_matters = "Category definitions are required",
      how_to_fix = "Check Brand_Config.xlsx has a valid Categories sheet"
    )
  })

  # Filter out help text rows and blank rows
  if (!is.null(categories) && nrow(categories) > 0) {
    categories <- categories[
      !is.na(categories$Category) &
      trimws(categories$Category) != "" &
      !grepl("^\\[", categories$Category),
    , drop = FALSE]
  }
  config$categories <- categories

  # Load DBA_Assets sheet if DBA is enabled
  if (isTRUE(config$element_dba)) {
    dba_assets <- tryCatch(
      openxlsx::read.xlsx(config_path, sheet = "DBA_Assets", startRow = 3),
      error = function(e) NULL
    )
    if (!is.null(dba_assets) && nrow(dba_assets) > 0) {
      dba_assets <- dba_assets[
        !is.na(dba_assets$AssetCode) &
        trimws(dba_assets$AssetCode) != "" &
        !grepl("^\\[", dba_assets$AssetCode),
      , drop = FALSE]
    }
    config$dba_assets <- dba_assets
  }

  # Validate
  guard_result <- guard_validate_brand_config(config)
  if (!is.null(guard_result) && guard_result$status == "REFUSED") {
    return(guard_result)
  }

  cat_result <- guard_validate_categories(config$categories, config)
  if (!is.null(cat_result) && cat_result$status == "REFUSED") {
    return(cat_result)
  }

  config
}


#' Load Survey_Structure.xlsx for brand module
#'
#' Reads the survey structure Excel file and returns a structured list
#' with questions, options, brands, CEPs, attributes, and DBA assets.
#'
#' @param structure_path Character. Path to Survey_Structure.xlsx.
#'
#' @return List with brands, ceps, attributes, questions, options, dba_assets.
#'
#' @export
load_brand_survey_structure <- function(structure_path) {

  if (!file.exists(structure_path)) {
    brand_refuse(
      code = "IO_STRUCTURE_NOT_FOUND",
      title = "Survey Structure File Not Found",
      problem = sprintf("Survey_Structure.xlsx not found at: %s", structure_path),
      why_it_matters = "Cannot map data columns without survey structure",
      how_to_fix = c(
        "Check structure_file path in Brand_Config.xlsx",
        "Generate a template with generate_brand_survey_structure_template()"
      )
    )
  }

  structure <- list()

  # Helper to load a table sheet, filtering out help text and blanks
  # Auto-detects format: template (startRow=3) vs simple (startRow=1)
  .load_table <- function(sheet_name) {
    tryCatch({
      # Try simple format first (headers in row 1) - most reliable
      df <- openxlsx::read.xlsx(structure_path, sheet = sheet_name,
                                startRow = 1)
      # If the first column name looks like a title/description row, scan for
      # real headers at startRow 2, 3, 4
      .looks_like_data_header <- function(d) {
        any(c("BrandCode", "Category", "QuestionCode", "CEPCode", "AttrCode",
              "AssetCode", "Role", "Scale") %in% names(d))
      }
      if (!is.null(df) && !.looks_like_data_header(df)) {
        for (.sr in 2:4) {
          df2 <- tryCatch(
            openxlsx::read.xlsx(structure_path, sheet = sheet_name, startRow = .sr),
            error = function(e) NULL)
          if (!is.null(df2) && .looks_like_data_header(df2)) { df <- df2; break }
        }
      }
      if (!is.null(df) && nrow(df) > 0 && ncol(df) > 0) {
        first_col <- df[[1]]
        keep <- !is.na(first_col) &
                trimws(as.character(first_col)) != "" &
                !grepl("^\\[", as.character(first_col))
        df <- df[keep, , drop = FALSE]
      }
      df
    }, error = function(e) {
      NULL
    })
  }

  # Load all sheets
  structure$questions <- .load_table("Questions")
  structure$options <- .load_table("Options")
  structure$brands <- .load_table("Brands")
  structure$ceps <- .load_table("CEPs")
  structure$attributes <- .load_table("Attributes")
  structure$dba_assets <- .load_table("DBA_Assets")

  # Role-registry sheets (new architecture; see ROLE_REGISTRY.md §11).
  # Optional here: not every element has migrated yet, so projects with
  # only legacy Questions/Options remain loadable. Elements that require a
  # role map (funnel in v1) refuse loud via load_role_map() if missing.
  structure$questionmap <- .load_table("QuestionMap")
  structure$optionmap   <- .load_table("OptionMap")

  # Load project settings
  project_raw <- tryCatch(
    openxlsx::read.xlsx(structure_path, sheet = "Project", colNames = FALSE),
    error = function(e) NULL
  )
  if (!is.null(project_raw)) {
    project <- list()
    for (i in seq_len(nrow(project_raw))) {
      key <- project_raw[i, 1]
      val <- project_raw[i, 2]
      if (!is.na(key) && trimws(key) != "" &&
          !key %in% c("Setting", "Legend:") &&
          !grepl("^TURAS|^Shared|^PROJECT", key)) {
        project[[trimws(key)]] <- val
      }
    }
    structure$project <- project
  }

  structure
}


#' Get brands for a specific category
#'
#' @param structure List. Loaded survey structure.
#' @param category Character. Category name.
#'
#' @return Data frame of brands for the category.
#'
#' @export
get_brands_for_category <- function(structure, category) {
  if (is.null(structure$brands)) return(data.frame())
  brands <- structure$brands[structure$brands$Category == category, , drop = FALSE]
  if ("DisplayOrder" %in% names(brands)) {
    brands <- brands[order(brands$DisplayOrder), , drop = FALSE]
  }
  brands
}


#' Get CEPs for a specific category
#'
#' @param structure List. Loaded survey structure.
#' @param category Character. Category name.
#'
#' @return Data frame of CEPs for the category.
#'
#' @export
get_ceps_for_category <- function(structure, category) {
  if (is.null(structure$ceps)) return(data.frame())
  ceps <- structure$ceps[structure$ceps$Category == category, , drop = FALSE]
  if ("DisplayOrder" %in% names(ceps)) {
    ceps <- ceps[order(ceps$DisplayOrder), , drop = FALSE]
  }
  ceps
}


#' Get attributes for a specific category
#'
#' @param structure List. Loaded survey structure.
#' @param category Character. Category name.
#'
#' @return Data frame of attributes for the category.
#'
#' @export
get_attributes_for_category <- function(structure, category) {
  if (is.null(structure$attributes)) return(data.frame())
  attrs <- structure$attributes[structure$attributes$Category == category, , drop = FALSE]
  if ("DisplayOrder" %in% names(attrs)) {
    attrs <- attrs[order(attrs$DisplayOrder), , drop = FALSE]
  }
  attrs
}


#' Get questions for a specific battery and category
#'
#' @param structure List. Loaded survey structure.
#' @param battery Character. Battery code (e.g., "cep_matrix", "awareness").
#' @param category Character. Category name, or "ALL" for brand-level.
#'
#' @return Data frame of questions matching the battery and category.
#'
#' @export
get_questions_for_battery <- function(structure, battery, category = NULL) {
  if (is.null(structure$questions)) return(data.frame())
  qs <- structure$questions[structure$questions$Battery == battery, , drop = FALSE]
  if (!is.null(category)) {
    qs <- qs[qs$Category %in% c(category, "ALL"), , drop = FALSE]
  }
  qs
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand config loader loaded (v%s)",
                  BRAND_CONFIG_LOADER_VERSION))
}
