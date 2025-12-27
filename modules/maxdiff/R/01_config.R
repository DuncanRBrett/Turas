# ==============================================================================
# MAXDIFF MODULE - CONFIGURATION LOADING - TURAS V10.0
# ==============================================================================
# Configuration loading and validation for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Refactored into modular architecture for maintainability (2025-12)
# Turas v10.0 - Initial release (2025-12)
#
# MODULAR ARCHITECTURE:
# Main orchestration file that coordinates configuration loading across modules:
# - config_loading.R: Sheet loading utilities and basic parsing
# - config_settings.R: Design, survey, segment, and output settings
# - config_validation.R: Cross-reference validation
#
# CONFIGURATION SHEETS:
# 1. PROJECT_SETTINGS - Global project parameters
# 2. ITEMS - Item definitions
# 3. DESIGN_SETTINGS - Design generation parameters (DESIGN mode)
# 4. SURVEY_MAPPING - Column mappings (ANALYSIS mode)
# 5. SEGMENT_SETTINGS - Segment definitions (optional)
# 6. OUTPUT_SETTINGS - Output options (optional)
#
# MAIN FUNCTION:
# - load_maxdiff_config(): Load and validate complete configuration
#
# DEPENDENCIES:
# - openxlsx (Excel reading)
# - shared/config_utils.R
# ==============================================================================

CONFIG_VERSION <- "10.0"


# ==============================================================================
# LOAD SUB-MODULES (NEW IN V10.0)
# ==============================================================================

# Get current script directory
if (!exists("script_dir")) {
  script_dir <- getSrcDirectory(function() {})
  if (script_dir == "") {
    script_dir <- dirname(sys.frame(1)$ofile)
  }
  if (script_dir == "") {
    script_dir <- getwd()
  }
}

message(sprintf("TURAS>MaxDiff config module loading (v%s)...", CONFIG_VERSION))

# Source configuration sub-modules
source(file.path(script_dir, "config_loading.R"), local = TRUE)
source(file.path(script_dir, "config_settings.R"), local = TRUE)
source(file.path(script_dir, "config_validation.R"), local = TRUE)


# ==============================================================================
# MAIN CONFIGURATION LOADER
# ==============================================================================

#' Load MaxDiff Configuration
#'
#' Loads and validates complete MaxDiff configuration from Excel workbook.
#' Validates all sheets, cross-references, and file paths.
#'
#' This is the main entry point for configuration loading. It orchestrates
#' the loading of all configuration sheets, validates their contents, and
#' returns a comprehensive configuration object.
#'
#' @param config_path Character. Path to configuration Excel file
#' @param project_root Character. Project root directory (for relative paths)
#'
#' @return List with configuration components:
#'   \item{project_settings}{Named list of project settings}
#'   \item{items}{Data frame of item definitions}
#'   \item{design_settings}{Named list of design parameters (DESIGN mode)}
#'   \item{survey_mapping}{Data frame of survey mappings (ANALYSIS mode)}
#'   \item{segment_settings}{Data frame of segment definitions (optional)}
#'   \item{output_settings}{Named list of output options}
#'   \item{mode}{Character. "DESIGN" or "ANALYSIS"}
#'   \item{project_root}{Character. Resolved project root path}
#'   \item{config_path}{Character. Path to configuration file}
#'
#' @section Configuration Sheets:
#' \describe{
#'   \item{PROJECT_SETTINGS}{Required. Global project parameters including Mode}
#'   \item{ITEMS}{Required. Item definitions with IDs and labels}
#'   \item{DESIGN_SETTINGS}{Required for DESIGN mode. Design generation parameters}
#'   \item{SURVEY_MAPPING}{Required for ANALYSIS mode. Survey column mappings}
#'   \item{SEGMENT_SETTINGS}{Optional. Segment definitions for subgroup analysis}
#'   \item{OUTPUT_SETTINGS}{Optional. Output options (uses defaults if missing)}
#' }
#'
#' @section Mode-Specific Requirements:
#' \describe{
#'   \item{DESIGN}{Requires DESIGN_SETTINGS sheet and Output_Folder setting}
#'   \item{ANALYSIS}{Requires SURVEY_MAPPING sheet, Raw_Data_File, and Design_File}
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' # Load configuration for design generation
#' config <- load_maxdiff_config("maxdiff_design_config.xlsx")
#'
#' # Load configuration for analysis
#' config <- load_maxdiff_config("maxdiff_analysis_config.xlsx")
#'
#' # Access configuration components
#' mode <- config$mode
#' items <- config$items
#' project_name <- config$project_settings$Project_Name
#' }
load_maxdiff_config <- function(config_path, project_root = NULL) {

  # ============================================================================
  # VALIDATE CONFIG FILE EXISTS
  # ============================================================================

  config_path <- validate_file_path(
    config_path,
    "config_path",
    must_exist = TRUE,
    extensions = c("xlsx", "xls")
  )

  # Determine project root
  if (is.null(project_root)) {
    project_root <- dirname(config_path)
  }
  project_root <- normalizePath(project_root, mustWork = FALSE)

  # ============================================================================
  # CHECK REQUIRED PACKAGES
  # ============================================================================

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    maxdiff_refuse(
      code = "PKG_OPENXLSX_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'openxlsx' is required but not installed",
      why_it_matters = "Configuration loading requires openxlsx to read Excel files",
      how_to_fix = "Install the openxlsx package: install.packages('openxlsx')"
    )
  }

  # ============================================================================
  # LOAD ALL SHEETS
  # ============================================================================

  # Get available sheets
  available_sheets <- tryCatch({
    openxlsx::getSheetNames(config_path)
  }, error = function(e) {
    maxdiff_refuse(
      code = "IO_CONFIG_FILE_READ_ERROR",
      title = "Cannot Read Configuration File",
      problem = sprintf("Error reading Excel configuration file: %s", conditionMessage(e)),
      why_it_matters = "Configuration file must be readable to load settings",
      how_to_fix = c(
        "Check file is not corrupted",
        "Verify file is valid Excel format (.xlsx, .xls)",
        "Ensure file is not locked or open in Excel",
        "Check file has correct permissions"
      ),
      details = sprintf("Path: %s\nError: %s", config_path, conditionMessage(e))
    )
  })

  # Required sheets
  required_sheets <- c("PROJECT_SETTINGS", "ITEMS")
  missing_sheets <- setdiff(required_sheets, available_sheets)

  if (length(missing_sheets) > 0) {
    maxdiff_refuse(
      code = "CFG_MISSING_SHEETS",
      title = "Missing Required Configuration Sheets",
      problem = sprintf("Configuration file missing required sheets: %s", paste(missing_sheets, collapse = ", ")),
      why_it_matters = "Required sheets must exist in configuration workbook",
      how_to_fix = c(
        "Add missing sheets to configuration file",
        "Use template configuration file",
        "Check sheet names are spelled correctly (case-sensitive)"
      ),
      expected = paste(required_sheets, collapse = ", "),
      missing = paste(missing_sheets, collapse = ", "),
      details = sprintf("Available sheets: %s", paste(available_sheets, collapse = ", "))
    )
  }

  # ============================================================================
  # LOAD PROJECT_SETTINGS
  # ============================================================================

  project_settings_raw <- load_config_sheet(config_path, "PROJECT_SETTINGS")
  project_settings <- parse_project_settings(project_settings_raw, project_root)

  # Determine mode
  mode <- toupper(project_settings$Mode)
  if (!mode %in% c("DESIGN", "ANALYSIS")) {
    maxdiff_refuse(
      code = "CFG_INVALID_MODE",
      title = "Invalid Mode Setting",
      problem = sprintf("Invalid Mode in PROJECT_SETTINGS: '%s'", project_settings$Mode),
      why_it_matters = "Mode must be either DESIGN or ANALYSIS",
      how_to_fix = "Set Mode to 'DESIGN' or 'ANALYSIS' in PROJECT_SETTINGS sheet",
      expected = "DESIGN or ANALYSIS",
      observed = project_settings$Mode
    )
  }

  # ============================================================================
  # LOAD ITEMS
  # ============================================================================

  items_raw <- load_config_sheet(config_path, "ITEMS")
  items <- parse_items_sheet(items_raw)

  # ============================================================================
  # LOAD DESIGN_SETTINGS (required for DESIGN mode)
  # ============================================================================

  design_settings <- NULL
  if ("DESIGN_SETTINGS" %in% available_sheets) {
    design_settings_raw <- load_config_sheet(config_path, "DESIGN_SETTINGS")
    design_settings <- parse_design_settings(design_settings_raw, nrow(items))
  } else if (mode == "DESIGN") {
    maxdiff_refuse(
      code = "CFG_DESIGN_SETTINGS_MISSING",
      title = "DESIGN_SETTINGS Sheet Missing",
      problem = "DESIGN_SETTINGS sheet is required when Mode = DESIGN",
      why_it_matters = "Design generation requires design parameters",
      how_to_fix = c(
        "Add DESIGN_SETTINGS sheet to configuration file",
        "Use template configuration for design mode",
        "Or change Mode to ANALYSIS if not generating design"
      )
    )
  }

  # ============================================================================
  # LOAD SURVEY_MAPPING (required for ANALYSIS mode)
  # ============================================================================

  survey_mapping <- NULL
  if ("SURVEY_MAPPING" %in% available_sheets) {
    survey_mapping_raw <- load_config_sheet(config_path, "SURVEY_MAPPING")
    survey_mapping <- parse_survey_mapping(survey_mapping_raw)
  } else if (mode == "ANALYSIS") {
    maxdiff_refuse(
      code = "CFG_SURVEY_MAPPING_MISSING",
      title = "SURVEY_MAPPING Sheet Missing",
      problem = "SURVEY_MAPPING sheet is required when Mode = ANALYSIS",
      why_it_matters = "Analysis requires mapping of survey columns to MaxDiff fields",
      how_to_fix = c(
        "Add SURVEY_MAPPING sheet to configuration file",
        "Use template configuration for analysis mode",
        "Define field mappings for survey columns"
      )
    )
  }

  # ============================================================================
  # LOAD SEGMENT_SETTINGS (optional)
  # ============================================================================

  segment_settings <- NULL
  if ("SEGMENT_SETTINGS" %in% available_sheets) {
    segment_settings_raw <- load_config_sheet(config_path, "SEGMENT_SETTINGS")
    segment_settings <- parse_segment_settings(segment_settings_raw)
  }

  # ============================================================================
  # LOAD OUTPUT_SETTINGS (optional with defaults)
  # ============================================================================

  output_settings <- NULL
  if ("OUTPUT_SETTINGS" %in% available_sheets) {
    output_settings_raw <- load_config_sheet(config_path, "OUTPUT_SETTINGS")
    output_settings <- parse_output_settings(output_settings_raw)
  } else {
    output_settings <- get_default_output_settings()
  }

  # ============================================================================
  # VALIDATE CROSS-REFERENCES
  # ============================================================================

  validate_config_cross_references(
    project_settings = project_settings,
    items = items,
    design_settings = design_settings,
    survey_mapping = survey_mapping,
    segment_settings = segment_settings,
    mode = mode
  )

  # ============================================================================
  # RETURN CONFIGURATION
  # ============================================================================

  config <- list(
    project_settings = project_settings,
    items = items,
    design_settings = design_settings,
    survey_mapping = survey_mapping,
    segment_settings = segment_settings,
    output_settings = output_settings,
    mode = mode,
    project_root = project_root,
    config_path = config_path
  )

  class(config) <- c("maxdiff_config", "list")

  message(sprintf("[TRS INFO] MAXD_CONFIG_LOADED: Configuration loaded successfully (%s mode)",
                 mode))

  return(config)
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff config module loaded (v%s) - Modular architecture", CONFIG_VERSION))
