# ==============================================================================
# MAXDIFF MODULE - CONFIGURATION LOADING - TURAS V10.0
# ==============================================================================
# Configuration loading and validation for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# CONFIGURATION SHEETS:
# 1. PROJECT_SETTINGS - Global project parameters
# 2. ITEMS - Item definitions
# 3. DESIGN_SETTINGS - Design generation parameters
# 4. SURVEY_MAPPING - Column mappings
# 5. SEGMENT_SETTINGS - Segment definitions
# 6. OUTPUT_SETTINGS - Output options
#
# DEPENDENCIES:
# - openxlsx (Excel reading)
# - shared/config_utils.R
# ==============================================================================

CONFIG_VERSION <- "10.0"

# ==============================================================================
# MAIN CONFIGURATION LOADER
# ==============================================================================

#' Load MaxDiff Configuration
#'
#' Loads and validates complete MaxDiff configuration from Excel workbook.
#' Validates all sheets, cross-references, and file paths.
#'
#' @param config_path Character. Path to configuration Excel file
#' @param project_root Character. Project root directory (for relative paths)
#'
#' @return List with configuration components:
#'   - project_settings: Named list of project settings
#'   - items: Data frame of item definitions
#'   - design_settings: Named list of design parameters
#'   - survey_mapping: Data frame of survey mappings
#'   - segment_settings: Data frame of segment definitions
#'   - output_settings: Named list of output options
#'   - mode: "DESIGN" or "ANALYSIS"
#'   - project_root: Resolved project root path
#'
#' @export
#' @examples
#' config <- load_maxdiff_config("maxdiff_config.xlsx")
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

  return(config)
}


# ==============================================================================
# SHEET LOADING HELPER
# ==============================================================================

#' Load a single config sheet with error handling
#'
#' @param config_path Character. Path to Excel file
#' @param sheet_name Character. Sheet name
#'
#' @return Data frame with sheet contents
#' @keywords internal
load_config_sheet <- function(config_path, sheet_name) {
  tryCatch({
    df <- openxlsx::read.xlsx(
      config_path,
      sheet = sheet_name,
      colNames = TRUE,
      detectDates = TRUE
    )

    if (is.null(df) || nrow(df) == 0) {
      message(sprintf("[TRS INFO] MAXD_EMPTY_SHEET: Sheet '%s' is empty", sheet_name))
      return(data.frame())
    }

    return(df)

  }, error = function(e) {
    maxdiff_refuse(
      code = "IO_CONFIG_SHEET_READ_ERROR",
      title = "Error Reading Configuration Sheet",
      problem = sprintf("Error reading sheet '%s': %s", sheet_name, conditionMessage(e)),
      why_it_matters = "All configuration sheets must be readable",
      how_to_fix = c(
        "Check sheet is not corrupted",
        "Verify sheet has valid structure",
        "Ensure column headers are present",
        "Check for invalid cell formats"
      ),
      details = sprintf("File: %s\nSheet: %s\nError: %s",
                       basename(config_path), sheet_name, conditionMessage(e))
    )
  })
}


# ==============================================================================
# PROJECT_SETTINGS PARSING
# ==============================================================================

#' Parse PROJECT_SETTINGS sheet
#'
#' @param df Data frame from PROJECT_SETTINGS sheet
#' @param project_root Character. Project root path
#'
#' @return Named list of settings
#' @keywords internal
parse_project_settings <- function(df, project_root) {

  # Expect Setting_Name and Value columns
  if (!"Setting_Name" %in% names(df)) {
    # Try alternative column names
    if ("Setting" %in% names(df)) {
      names(df)[names(df) == "Setting"] <- "Setting_Name"
    } else {
      maxdiff_refuse(
        code = "CFG_MISSING_COLUMN",
        title = "Missing Required Column",
        problem = "PROJECT_SETTINGS must have 'Setting_Name' column",
        why_it_matters = "Setting_Name column is required to identify settings",
        how_to_fix = "Add 'Setting_Name' column to PROJECT_SETTINGS sheet"
      )
    }
  }

  if (!"Value" %in% names(df)) {
    maxdiff_refuse(
      code = "CFG_MISSING_COLUMN",
      title = "Missing Required Column",
      problem = "PROJECT_SETTINGS must have 'Value' column",
      why_it_matters = "Value column is required for setting values",
      how_to_fix = "Add 'Value' column to PROJECT_SETTINGS sheet"
    )
  }

  # Convert to named list
  settings <- as.list(df$Value)
  names(settings) <- df$Setting_Name

  # Required settings
  required <- c("Project_Name", "Mode")
  missing <- setdiff(required, names(settings))
  if (length(missing) > 0) {
    maxdiff_refuse(
      code = "CFG_MISSING_SETTINGS",
      title = "Missing Required Settings",
      problem = sprintf("PROJECT_SETTINGS missing required settings: %s", paste(missing, collapse = ", ")),
      why_it_matters = "Required project settings must be defined",
      how_to_fix = "Add missing settings to PROJECT_SETTINGS sheet",
      missing = paste(missing, collapse = ", ")
    )
  }

  # Validate Mode
  settings$Mode <- toupper(trimws(as.character(settings$Mode)))
  if (!settings$Mode %in% c("DESIGN", "ANALYSIS")) {
    maxdiff_refuse(
      code = "CFG_INVALID_MODE",
      title = "Invalid Mode Value",
      problem = sprintf("Mode must be 'DESIGN' or 'ANALYSIS', got: '%s'", settings$Mode),
      why_it_matters = "Valid mode is required to determine workflow",
      how_to_fix = "Set Mode to either 'DESIGN' or 'ANALYSIS'",
      expected = "DESIGN or ANALYSIS",
      observed = settings$Mode
    )
  }

  # Clean Project_Name (no spaces)
  settings$Project_Name <- gsub("\\s+", "_", trimws(as.character(settings$Project_Name)))

  # Resolve file paths relative to project root
  path_settings <- c("Raw_Data_File", "Design_File", "Output_Folder")

  for (ps in path_settings) {
    if (ps %in% names(settings)) {
      path_val <- settings[[ps]]

      # Ensure scalar - take first element if vector
      if (length(path_val) > 1) path_val <- path_val[1]

      # Skip if NA or empty
      if (is.null(path_val) || is.na(path_val) || !nzchar(trimws(as.character(path_val)))) {
        next
      }

      path_val <- as.character(path_val)

      # If relative path, make absolute
      if (!grepl("^(/|[A-Za-z]:)", path_val)) {
        path_val <- file.path(project_root, path_val)
      }

      settings[[ps]] <- normalizePath(path_val, mustWork = FALSE)
    }
  }

  # Helper to safely check if value is missing (handles vectors)
  is_missing <- function(x) {
    is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x[1]))
  }

  # Helper to safely get scalar string value
  get_scalar <- function(x, default = NULL) {
    if (is_missing(x)) return(default)
    val <- as.character(x[1])
    if (is.na(val) || !nzchar(trimws(val))) return(default)
    trimws(val)
  }

  # Set defaults
  if (is_missing(settings$Module_Version)) {
    settings$Module_Version <- "v1.0"
  }

  if (is_missing(settings$Seed)) {
    settings$Seed <- 12345
  } else {
    settings$Seed <- safe_integer(settings$Seed[1], 12345)
  }

  # Parse Data_File_Sheet
  if (is_missing(settings$Data_File_Sheet)) {
    settings$Data_File_Sheet <- 1  # Default to first sheet
  } else {
    settings$Data_File_Sheet <- settings$Data_File_Sheet[1]
  }

  # Parse optional settings
  settings$Weight_Variable <- get_scalar(settings$Weight_Variable, NULL)
  settings$Respondent_ID_Variable <- get_scalar(settings$Respondent_ID_Variable, "RespID")
  settings$Filter_Expression <- get_scalar(settings$Filter_Expression, NULL)

  return(settings)
}


# ==============================================================================
# ITEMS PARSING
# ==============================================================================

#' Parse ITEMS sheet
#'
#' @param df Data frame from ITEMS sheet
#'
#' @return Data frame of validated items
#' @keywords internal
parse_items_sheet <- function(df) {

  # Required columns
  required_cols <- c("Item_ID", "Item_Label")
  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    maxdiff_refuse(
      code = "CFG_ITEMS_MISSING_COLUMNS",
      title = "ITEMS Sheet Missing Required Columns",
      problem = sprintf("ITEMS sheet missing required columns: %s", paste(missing_cols, collapse = ", ")),
      why_it_matters = "Required columns must exist to define items",
      how_to_fix = "Add missing columns to ITEMS sheet",
      expected = paste(required_cols, collapse = ", "),
      missing = paste(missing_cols, collapse = ", "),
      details = sprintf("Found columns: %s", paste(names(df), collapse = ", "))
    )
  }

  # Clean Item_IDs
  df$Item_ID <- sapply(df$Item_ID, clean_item_id)

  # Check for NA Item_IDs
  na_rows <- which(is.na(df$Item_ID))
  if (length(na_rows) > 0) {
    maxdiff_refuse(
      code = "CFG_ITEMS_EMPTY_ID",
      title = "Empty Item IDs in ITEMS Sheet",
      problem = sprintf("ITEMS sheet has empty Item_ID values in rows: %s", paste(na_rows + 1, collapse = ", ")),
      why_it_matters = "All items must have a unique identifier",
      how_to_fix = "Provide Item_ID values for all rows in ITEMS sheet",
      details = sprintf("Rows with empty Item_ID: %s", paste(na_rows + 1, collapse = ", "))
    )
  }

  # Check for duplicate Item_IDs
  dup_ids <- df$Item_ID[duplicated(df$Item_ID)]
  if (length(dup_ids) > 0) {
    maxdiff_refuse(
      code = "CFG_ITEMS_DUPLICATE_ID",
      title = "Duplicate Item IDs",
      problem = sprintf("ITEMS sheet has duplicate Item_IDs: %s", paste(unique(dup_ids), collapse = ", ")),
      why_it_matters = "Each item must have a unique identifier",
      how_to_fix = "Ensure all Item_ID values are unique in ITEMS sheet",
      details = sprintf("Duplicate IDs: %s", paste(unique(dup_ids), collapse = ", "))
    )
  }

  # Set defaults for optional columns
  if (!"Item_Group" %in% names(df)) {
    df$Item_Group <- ""
  }
  df$Item_Group[is.na(df$Item_Group)] <- ""

  if (!"Include" %in% names(df)) {
    df$Include <- 1
  }
  df$Include <- safe_integer(df$Include, 1)

  if (!"Anchor_Item" %in% names(df)) {
    df$Anchor_Item <- 0
  }
  df$Anchor_Item <- safe_integer(df$Anchor_Item, 0)

  if (!"Display_Order" %in% names(df)) {
    df$Display_Order <- seq_len(nrow(df))
  }
  df$Display_Order <- safe_integer(df$Display_Order, seq_len(nrow(df)))

  if (!"Notes" %in% names(df)) {
    df$Notes <- ""
  }
  df$Notes[is.na(df$Notes)] <- ""

  # Validate at least 2 included items
  n_included <- sum(df$Include == 1)
  if (n_included < 2) {
    maxdiff_refuse(
      code = "CFG_ITEMS_INSUFFICIENT",
      title = "Insufficient Items Included",
      problem = sprintf("ITEMS sheet must have at least 2 items with Include=1, found: %d", n_included),
      why_it_matters = "MaxDiff requires at least 2 items to compare",
      how_to_fix = "Set Include=1 for at least 2 items in ITEMS sheet",
      expected = "At least 2 items with Include=1",
      observed = sprintf("%d items", n_included)
    )
  }

  # Validate exactly 0 or 1 anchor item
  n_anchor <- sum(df$Anchor_Item == 1)
  if (n_anchor > 1) {
    maxdiff_refuse(
      code = "CFG_ITEMS_MULTIPLE_ANCHORS",
      title = "Multiple Anchor Items",
      problem = sprintf("ITEMS sheet can have at most 1 Anchor_Item, found: %d", n_anchor),
      why_it_matters = "Only one item can be designated as the anchor/reference item",
      how_to_fix = "Set Anchor_Item=1 for at most one item",
      expected = "0 or 1 anchor item",
      observed = sprintf("%d anchor items", n_anchor)
    )
  }

  return(df)
}


# ==============================================================================
# DESIGN_SETTINGS PARSING
# ==============================================================================

#' Parse DESIGN_SETTINGS sheet
#'
#' @param df Data frame from DESIGN_SETTINGS sheet
#' @param n_items Integer. Number of items
#'
#' @return Named list of design settings
#' @keywords internal
parse_design_settings <- function(df, n_items) {

  # Expect Parameter_Name and Value columns (or similar)
  if (!"Parameter_Name" %in% names(df)) {
    if ("Setting_Name" %in% names(df)) {
      names(df)[names(df) == "Setting_Name"] <- "Parameter_Name"
    } else if ("Parameter" %in% names(df)) {
      names(df)[names(df) == "Parameter"] <- "Parameter_Name"
    } else {
      maxdiff_refuse(
        code = "CFG_MISSING_COLUMN",
        title = "Missing Required Column",
        problem = "DESIGN_SETTINGS must have 'Parameter_Name' column",
        why_it_matters = "Parameter_Name column is required to identify settings",
        how_to_fix = "Add 'Parameter_Name' column to DESIGN_SETTINGS sheet"
      )
    }
  }

  value_col <- intersect(c("Value", "Setting_Value"), names(df))[1]
  if (is.na(value_col)) {
    maxdiff_refuse(
      code = "CFG_MISSING_COLUMN",
      title = "Missing Required Column",
      problem = "DESIGN_SETTINGS must have 'Value' column",
      why_it_matters = "Value column is required for parameter values",
      how_to_fix = "Add 'Value' column to DESIGN_SETTINGS sheet"
    )
  }

  # Convert to named list
  settings <- as.list(df[[value_col]])
  names(settings) <- df$Parameter_Name

  # Parse and validate each setting
  result <- list()

  # Items_Per_Task (required, typically 4-5)
  result$Items_Per_Task <- validate_positive_integer(
    settings$Items_Per_Task %||% 4,
    "Items_Per_Task",
    min_val = 2
  )
  if (result$Items_Per_Task > n_items) {
    maxdiff_refuse(
      code = "CFG_ITEMS_PER_TASK_TOO_LARGE",
      title = "Items Per Task Exceeds Total Items",
      problem = sprintf("Items_Per_Task (%d) cannot exceed number of items (%d)",
                       result$Items_Per_Task, n_items),
      why_it_matters = "Cannot show more items per task than total items available",
      how_to_fix = sprintf("Set Items_Per_Task to %d or less", n_items),
      expected = sprintf("<= %d", n_items),
      observed = sprintf("%d", result$Items_Per_Task)
    )
  }

  # Tasks_Per_Respondent (required)
  result$Tasks_Per_Respondent <- validate_positive_integer(
    settings$Tasks_Per_Respondent %||% 12,
    "Tasks_Per_Respondent",
    min_val = 1
  )

  # Num_Versions
  result$Num_Versions <- validate_positive_integer(
    settings$Num_Versions %||% 1,
    "Num_Versions",
    min_val = 1
  )

  # Design_Type
  result$Design_Type <- toupper(settings$Design_Type %||% "BALANCED")
  if (!result$Design_Type %in% c("BALANCED", "RANDOM", "OPTIMAL")) {
    maxdiff_refuse(
      code = "CFG_INVALID_DESIGN_TYPE",
      title = "Invalid Design Type",
      problem = sprintf("Design_Type must be BALANCED, RANDOM, or OPTIMAL, got: '%s'",
                       result$Design_Type),
      why_it_matters = "Valid design type is required for design generation",
      how_to_fix = "Set Design_Type to BALANCED, RANDOM, or OPTIMAL",
      expected = "BALANCED, RANDOM, or OPTIMAL",
      observed = result$Design_Type
    )
  }

  # Boolean settings
  result$Allow_Item_Repeat_Per_Respondent <- parse_yes_no(
    settings$Allow_Item_Repeat_Per_Respondent, TRUE
  )

  result$Max_Item_Repeats <- validate_positive_integer(
    settings$Max_Item_Repeats %||% 5,
    "Max_Item_Repeats",
    min_val = 1
  )

  result$Force_Min_Pair_Balance <- parse_yes_no(
    settings$Force_Min_Pair_Balance, TRUE
  )

  result$Randomise_Task_Order <- parse_yes_no(
    settings$Randomise_Task_Order, TRUE
  )

  result$Randomise_Item_Order_Within_Task <- parse_yes_no(
    settings$Randomise_Item_Order_Within_Task, TRUE
  )

  # Efficiency threshold
  result$Design_Efficiency_Threshold <- validate_numeric_range(
    safe_numeric(settings$Design_Efficiency_Threshold, 0.90),
    "Design_Efficiency_Threshold",
    min_val = 0.5, max_val = 1.0
  )

  # Max iterations
  result$Max_Design_Iterations <- validate_positive_integer(
    settings$Max_Design_Iterations %||% 10000,
    "Max_Design_Iterations",
    min_val = 100
  )

  return(result)
}


# ==============================================================================
# SURVEY_MAPPING PARSING
# ==============================================================================

#' Parse SURVEY_MAPPING sheet
#'
#' @param df Data frame from SURVEY_MAPPING sheet
#'
#' @return Data frame of survey mappings
#' @keywords internal
parse_survey_mapping <- function(df) {

  # Required columns
  required_cols <- c("Field_Type", "Field_Name")
  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    maxdiff_refuse(
      code = "CFG_SURVEY_MAPPING_MISSING_COLUMNS",
      title = "SURVEY_MAPPING Missing Required Columns",
      problem = sprintf("SURVEY_MAPPING sheet missing required columns: %s", paste(missing_cols, collapse = ", ")),
      why_it_matters = "Required columns must exist to map survey fields",
      how_to_fix = "Add missing columns to SURVEY_MAPPING sheet",
      expected = paste(required_cols, collapse = ", "),
      missing = paste(missing_cols, collapse = ", "),
      details = sprintf("Found columns: %s", paste(names(df), collapse = ", "))
    )
  }

  # Normalize field types
  df$Field_Type <- toupper(trimws(as.character(df$Field_Type)))

  # Valid field types
  valid_types <- c("VERSION", "BEST_CHOICE", "WORST_CHOICE", "SHOWN_ITEMS")

  invalid_types <- setdiff(unique(df$Field_Type), valid_types)
  if (length(invalid_types) > 0) {
    maxdiff_refuse(
      code = "CFG_SURVEY_MAPPING_INVALID_TYPE",
      title = "Invalid Field Type in SURVEY_MAPPING",
      problem = sprintf("SURVEY_MAPPING has invalid Field_Type values: %s", paste(invalid_types, collapse = ", ")),
      why_it_matters = "Field_Type must be one of the recognized types",
      how_to_fix = sprintf("Use only valid Field_Type values: %s", paste(valid_types, collapse = ", ")),
      expected = paste(valid_types, collapse = ", "),
      observed = paste(invalid_types, collapse = ", ")
    )
  }

  # Must have VERSION field
  if (!"VERSION" %in% df$Field_Type) {
    maxdiff_refuse(
      code = "CFG_SURVEY_MAPPING_NO_VERSION",
      title = "Missing VERSION Field in SURVEY_MAPPING",
      problem = "SURVEY_MAPPING must include a VERSION field type",
      why_it_matters = "VERSION field is required to map design versions to survey data",
      how_to_fix = "Add a row with Field_Type = VERSION in SURVEY_MAPPING sheet"
    )
  }

  # Must have at least one BEST_CHOICE and one WORST_CHOICE
  if (!"BEST_CHOICE" %in% df$Field_Type) {
    maxdiff_refuse(
      code = "CFG_SURVEY_MAPPING_NO_BEST",
      title = "Missing BEST_CHOICE Field in SURVEY_MAPPING",
      problem = "SURVEY_MAPPING must include at least one BEST_CHOICE field type",
      why_it_matters = "BEST_CHOICE fields are required to identify best choices in survey data",
      how_to_fix = "Add rows with Field_Type = BEST_CHOICE in SURVEY_MAPPING sheet for each task"
    )
  }

  if (!"WORST_CHOICE" %in% df$Field_Type) {
    maxdiff_refuse(
      code = "CFG_SURVEY_MAPPING_NO_WORST",
      title = "Missing WORST_CHOICE Field in SURVEY_MAPPING",
      problem = "SURVEY_MAPPING must include at least one WORST_CHOICE field type",
      why_it_matters = "WORST_CHOICE fields are required to identify worst choices in survey data",
      how_to_fix = "Add rows with Field_Type = WORST_CHOICE in SURVEY_MAPPING sheet for each task"
    )
  }

  # Add Task_Number column if missing
  if (!"Task_Number" %in% names(df)) {
    df$Task_Number <- NA_integer_
  }

  # Parse task numbers for BEST/WORST choices
  for (i in seq_len(nrow(df))) {
    if (df$Field_Type[i] %in% c("BEST_CHOICE", "WORST_CHOICE", "SHOWN_ITEMS")) {
      if (is.na(df$Task_Number[i])) {
        # Try to extract from field name
        task_match <- regmatches(df$Field_Name[i],
                                 regexec("(\\d+)$", df$Field_Name[i]))[[1]]
        if (length(task_match) > 1) {
          df$Task_Number[i] <- as.integer(task_match[2])
        }
      }
    }
  }

  # Add Notes column if missing
  if (!"Notes" %in% names(df)) {
    df$Notes <- ""
  }

  return(df)
}


# ==============================================================================
# SEGMENT_SETTINGS PARSING
# ==============================================================================

#' Parse SEGMENT_SETTINGS sheet
#'
#' @param df Data frame from SEGMENT_SETTINGS sheet
#'
#' @return Data frame of segment settings
#' @keywords internal
parse_segment_settings <- function(df) {

  if (nrow(df) == 0) {
    return(NULL)
  }

  # Required columns
  required_cols <- c("Segment_ID", "Segment_Label", "Variable_Name")
  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    maxdiff_refuse(
      code = "CFG_SEGMENT_SETTINGS_MISSING_COLUMNS",
      title = "SEGMENT_SETTINGS Missing Required Columns",
      problem = sprintf("SEGMENT_SETTINGS sheet missing required columns: %s", paste(missing_cols, collapse = ", ")),
      why_it_matters = "Required columns must exist to define segments",
      how_to_fix = "Add missing columns to SEGMENT_SETTINGS sheet",
      expected = paste(required_cols, collapse = ", "),
      missing = paste(missing_cols, collapse = ", "),
      details = sprintf("Found columns: %s", paste(names(df), collapse = ", "))
    )
  }

  # Clean Segment_IDs
  df$Segment_ID <- trimws(as.character(df$Segment_ID))

  # Check for duplicates
  dup_ids <- df$Segment_ID[duplicated(df$Segment_ID)]
  if (length(dup_ids) > 0) {
    maxdiff_refuse(
      code = "CFG_SEGMENT_DUPLICATE_ID",
      title = "Duplicate Segment IDs",
      problem = sprintf("SEGMENT_SETTINGS has duplicate Segment_IDs: %s", paste(unique(dup_ids), collapse = ", ")),
      why_it_matters = "Each segment must have a unique identifier",
      how_to_fix = "Ensure all Segment_ID values are unique in SEGMENT_SETTINGS sheet",
      details = sprintf("Duplicate IDs: %s", paste(unique(dup_ids), collapse = ", "))
    )
  }

  # Set defaults for optional columns
  if (!"Segment_Def" %in% names(df)) {
    df$Segment_Def <- ""
  }
  df$Segment_Def[is.na(df$Segment_Def)] <- ""

  if (!"Include_in_Output" %in% names(df)) {
    df$Include_in_Output <- 1
  }
  df$Include_in_Output <- safe_integer(df$Include_in_Output, 1)

  return(df)
}


# ==============================================================================
# OUTPUT_SETTINGS PARSING
# ==============================================================================

#' Parse OUTPUT_SETTINGS sheet
#'
#' @param df Data frame from OUTPUT_SETTINGS sheet
#'
#' @return Named list of output settings
#' @keywords internal
parse_output_settings <- function(df) {

  # Expect Option_Name and Value columns (or similar)
  name_col <- intersect(c("Option_Name", "Setting_Name", "Option"), names(df))[1]
  if (is.na(name_col)) {
    maxdiff_refuse(
      code = "CFG_MISSING_COLUMN",
      title = "Missing Required Column",
      problem = "OUTPUT_SETTINGS must have 'Option_Name' column",
      why_it_matters = "Option_Name column is required to identify output settings",
      how_to_fix = "Add 'Option_Name' column to OUTPUT_SETTINGS sheet"
    )
  }

  value_col <- intersect(c("Value", "Setting_Value"), names(df))[1]
  if (is.na(value_col)) {
    maxdiff_refuse(
      code = "CFG_MISSING_COLUMN",
      title = "Missing Required Column",
      problem = "OUTPUT_SETTINGS must have 'Value' column",
      why_it_matters = "Value column is required for output setting values",
      how_to_fix = "Add 'Value' column to OUTPUT_SETTINGS sheet"
    )
  }

  # Convert to named list
  settings <- as.list(df[[value_col]])
  names(settings) <- df[[name_col]]

  # Parse with defaults
  result <- get_default_output_settings()

  # Override with provided values
  for (name in names(settings)) {
    if (name %in% names(result)) {
      val <- settings[[name]]

      # Boolean settings
      if (name %in% c("Generate_Design_File", "Generate_Count_Scores",
                      "Generate_Aggregate_Logit", "Generate_HB_Model",
                      "Generate_Segment_Tables", "Generate_Charts",
                      "Export_Individual_Utils")) {
        result[[name]] <- parse_yes_no(val, result[[name]])
      }
      # Integer settings
      else if (name %in% c("HB_Iterations", "HB_Warmup", "HB_Chains",
                           "Min_Respondents_Per_Segment")) {
        result[[name]] <- safe_integer(val, result[[name]])
      }
      # String settings
      else {
        result[[name]] <- trimws(as.character(val))
      }
    }
  }

  # Validate Score_Rescale_Method
  result$Score_Rescale_Method <- toupper(result$Score_Rescale_Method)
  if (!result$Score_Rescale_Method %in% c("RAW", "0_100", "PROBABILITY")) {
    message(sprintf(
      "[TRS INFO] MAXD_INVALID_RESCALE: Invalid Score_Rescale_Method: '%s' - using '0_100'",
      result$Score_Rescale_Method
    ))
    result$Score_Rescale_Method <- "0_100"
  }

  # Validate Output_Item_Sort_Order
  result$Output_Item_Sort_Order <- toupper(result$Output_Item_Sort_Order)
  if (!result$Output_Item_Sort_Order %in% c("UTILITY_DESC", "UTILITY_ASC",
                                            "ITEM_ID", "DISPLAY_ORDER")) {
    message(sprintf(
      "[TRS INFO] MAXD_INVALID_SORT: Invalid Output_Item_Sort_Order: '%s' - using 'UTILITY_DESC'",
      result$Output_Item_Sort_Order
    ))
    result$Output_Item_Sort_Order <- "UTILITY_DESC"
  }

  return(result)
}


#' Get default output settings
#'
#' @return Named list of default output settings
#' @keywords internal
get_default_output_settings <- function() {
  list(
    Generate_Design_File = TRUE,
    Generate_Count_Scores = TRUE,
    Generate_Aggregate_Logit = TRUE,
    Generate_HB_Model = TRUE,
    HB_Iterations = 5000,
    HB_Warmup = 2000,
    HB_Chains = 4,
    Generate_Segment_Tables = TRUE,
    Generate_Charts = TRUE,
    Score_Rescale_Method = "0_100",
    Min_Respondents_Per_Segment = 50,
    Output_Item_Sort_Order = "UTILITY_DESC",
    Export_Individual_Utils = TRUE
  )
}


# ==============================================================================
# CROSS-REFERENCE VALIDATION
# ==============================================================================

#' Validate cross-references between config sheets
#'
#' @param project_settings Project settings list
#' @param items Items data frame
#' @param design_settings Design settings list (may be NULL)
#' @param survey_mapping Survey mapping data frame (may be NULL)
#' @param segment_settings Segment settings data frame (may be NULL)
#' @param mode Character. "DESIGN" or "ANALYSIS"
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_config_cross_references <- function(project_settings, items,
                                             design_settings, survey_mapping,
                                             segment_settings, mode) {

  # Get included items
  included_items <- items$Item_ID[items$Include == 1]
  n_included <- length(included_items)

  # ============================================================================
  # DESIGN MODE VALIDATIONS
  # ============================================================================

  if (mode == "DESIGN") {
    # Check Items_Per_Task
    if (design_settings$Items_Per_Task > n_included) {
      maxdiff_refuse(
        code = "CFG_ITEMS_PER_TASK_EXCEEDS_TOTAL",
        title = "Items Per Task Exceeds Available Items",
        problem = sprintf("Items_Per_Task (%d) exceeds number of included items (%d)",
                         design_settings$Items_Per_Task, n_included),
        why_it_matters = "Cannot show more items per task than are included in study",
        how_to_fix = c(
          sprintf("Reduce Items_Per_Task to %d or less", n_included),
          "Or include more items in ITEMS sheet (set Include=1)"
        ),
        expected = sprintf("<= %d", n_included),
        observed = sprintf("%d", design_settings$Items_Per_Task)
      )
    }

    # Validate Output_Folder
    if (is.null(project_settings$Output_Folder) ||
        is.na(project_settings$Output_Folder) ||
        !nzchar(project_settings$Output_Folder)) {
      maxdiff_refuse(
        code = "CFG_OUTPUT_FOLDER_MISSING",
        title = "Output Folder Not Specified",
        problem = "Output_Folder is required in PROJECT_SETTINGS for DESIGN mode",
        why_it_matters = "Output folder must be specified to save design file",
        how_to_fix = "Add Output_Folder setting to PROJECT_SETTINGS sheet"
      )
    }
  }

  # ============================================================================
  # ANALYSIS MODE VALIDATIONS
  # ============================================================================

  if (mode == "ANALYSIS") {
    # Validate Raw_Data_File
    if (is.null(project_settings$Raw_Data_File) ||
        is.na(project_settings$Raw_Data_File) ||
        !nzchar(project_settings$Raw_Data_File)) {
      maxdiff_refuse(
        code = "CFG_RAW_DATA_FILE_MISSING",
        title = "Raw Data File Not Specified",
        problem = "Raw_Data_File is required in PROJECT_SETTINGS for ANALYSIS mode",
        why_it_matters = "Survey data file must be specified for analysis",
        how_to_fix = "Add Raw_Data_File setting to PROJECT_SETTINGS sheet with path to survey data"
      )
    }

    if (!file.exists(project_settings$Raw_Data_File)) {
      maxdiff_refuse(
        code = "IO_RAW_DATA_FILE_NOT_FOUND",
        title = "Raw Data File Not Found",
        problem = "Raw_Data_File not found at specified path",
        why_it_matters = "Survey data file must exist to perform analysis",
        how_to_fix = c(
          "Check file path is correct",
          "Verify file exists at specified location",
          "Use absolute path or path relative to configuration file"
        ),
        details = sprintf("Path: %s", project_settings$Raw_Data_File)
      )
    }

    # Validate Design_File
    if (is.null(project_settings$Design_File) ||
        is.na(project_settings$Design_File) ||
        !nzchar(project_settings$Design_File)) {
      maxdiff_refuse(
        code = "CFG_DESIGN_FILE_MISSING",
        title = "Design File Not Specified",
        problem = "Design_File is required in PROJECT_SETTINGS for ANALYSIS mode",
        why_it_matters = "Design file must be specified to map survey structure",
        how_to_fix = "Add Design_File setting to PROJECT_SETTINGS sheet with path to design file"
      )
    }

    if (!file.exists(project_settings$Design_File)) {
      maxdiff_refuse(
        code = "IO_DESIGN_FILE_NOT_FOUND",
        title = "Design File Not Found",
        problem = "Design_File not found at specified path",
        why_it_matters = "Design file must exist to perform analysis",
        how_to_fix = c(
          "Check file path is correct",
          "Verify file exists at specified location",
          "Generate design file first if in DESIGN mode",
          "Use absolute path or path relative to configuration file"
        ),
        details = sprintf("Path: %s", project_settings$Design_File)
      )
    }

    # Count tasks from survey mapping
    n_best <- sum(survey_mapping$Field_Type == "BEST_CHOICE")
    n_worst <- sum(survey_mapping$Field_Type == "WORST_CHOICE")

    if (n_best != n_worst) {
      maxdiff_refuse(
        code = "CFG_SURVEY_MAPPING_UNEQUAL_CHOICES",
        title = "Unequal Best and Worst Choice Mappings",
        problem = sprintf("SURVEY_MAPPING must have equal BEST_CHOICE and WORST_CHOICE entries (BEST: %d, WORST: %d)",
                         n_best, n_worst),
        why_it_matters = "Each task must have both best and worst choice fields",
        how_to_fix = "Ensure SURVEY_MAPPING has same number of BEST_CHOICE and WORST_CHOICE rows",
        expected = "Equal number of BEST_CHOICE and WORST_CHOICE",
        observed = sprintf("BEST: %d, WORST: %d", n_best, n_worst)
      )
    }
  }

  # ============================================================================
  # SEGMENT VALIDATIONS (if segments defined)
  # ============================================================================

  if (!is.null(segment_settings) && nrow(segment_settings) > 0) {
    # Validate segment definitions are valid R expressions
    for (i in seq_len(nrow(segment_settings))) {
      seg_def <- segment_settings$Segment_Def[i]

      if (!is.null(seg_def) && !is.na(seg_def) && nzchar(trimws(seg_def))) {
        tryCatch({
          parse(text = seg_def)
        }, error = function(e) {
          maxdiff_refuse(
            code = "CFG_SEGMENT_INVALID_EXPRESSION",
            title = "Invalid Segment Definition Expression",
            problem = sprintf("Invalid R expression in Segment_Def for segment '%s'",
                             segment_settings$Segment_ID[i]),
            why_it_matters = "Segment definition must be valid R code",
            how_to_fix = c(
              "Check segment definition syntax",
              "Ensure balanced parentheses and quotes",
              "Use valid R operators"
            ),
            details = sprintf("Segment: %s\nExpression: %s\nError: %s",
                             segment_settings$Segment_ID[i], seg_def, conditionMessage(e))
          )
        })
      }
    }
  }

  invisible(TRUE)
}


# ==============================================================================
# NULL COALESCE OPERATOR
# ==============================================================================

#' Null coalesce operator
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff config module loaded (v%s)", CONFIG_VERSION))
