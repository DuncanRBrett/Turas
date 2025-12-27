# ==============================================================================
# MAXDIFF MODULE - CONFIGURATION LOADING UTILITIES - TURAS V10.0
# ==============================================================================
# Sheet loading and basic parsing utilities for MaxDiff configuration
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Refactored from 01_config.R for maintainability (2025-12)
#
# FUNCTIONS:
# - load_config_sheet(): Load individual Excel sheet with error handling
# - parse_project_settings(): Parse PROJECT_SETTINGS sheet
# - parse_items_sheet(): Parse ITEMS sheet
# - clean_item_id(): Clean and validate item IDs
# - %||%: Null coalesce operator
#
# DEPENDENCIES:
# - openxlsx (Excel reading)
# - shared/config_utils.R
# ==============================================================================

CONFIG_LOADING_VERSION <- "10.0"


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


#' Clean and validate item ID
#'
#' @param id Item ID to clean
#'
#' @return Cleaned item ID or NA
#' @keywords internal
clean_item_id <- function(id) {
  if (is.null(id) || is.na(id)) return(NA_character_)
  id <- trimws(as.character(id))
  if (!nzchar(id)) return(NA_character_)
  # Remove special characters except underscore
  id <- gsub("[^A-Za-z0-9_]", "_", id)
  return(id)
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

message(sprintf("  - config_loading.R loaded (v%s)", CONFIG_LOADING_VERSION))
