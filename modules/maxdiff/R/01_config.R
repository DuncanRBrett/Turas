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
    stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')",
         call. = FALSE)
  }

  # ============================================================================
  # LOAD ALL SHEETS
  # ============================================================================

  # Get available sheets
  available_sheets <- tryCatch({
    openxlsx::getSheetNames(config_path)
  }, error = function(e) {
    stop(sprintf(
      "Cannot read Excel file:\n  Path: %s\n  Error: %s",
      config_path, conditionMessage(e)
    ), call. = FALSE)
  })

  # Required sheets
  required_sheets <- c("PROJECT_SETTINGS", "ITEMS")
  missing_sheets <- setdiff(required_sheets, available_sheets)

  if (length(missing_sheets) > 0) {
    stop(sprintf(
      "Configuration file is missing required sheets:\n  Missing: %s\n  Available: %s",
      paste(missing_sheets, collapse = ", "),
      paste(available_sheets, collapse = ", ")
    ), call. = FALSE)
  }

  # ============================================================================
  # LOAD PROJECT_SETTINGS
  # ============================================================================

  project_settings_raw <- load_config_sheet(config_path, "PROJECT_SETTINGS")
  project_settings <- parse_project_settings(project_settings_raw, project_root)

  # Determine mode
  mode <- toupper(project_settings$Mode)
  if (!mode %in% c("DESIGN", "ANALYSIS")) {
    stop(sprintf(
      "Invalid Mode in PROJECT_SETTINGS: '%s'\n  Must be 'DESIGN' or 'ANALYSIS'",
      project_settings$Mode
    ), call. = FALSE)
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
    stop("DESIGN_SETTINGS sheet is required when Mode = DESIGN", call. = FALSE)
  }

  # ============================================================================
  # LOAD SURVEY_MAPPING (required for ANALYSIS mode)
  # ============================================================================

  survey_mapping <- NULL
  if ("SURVEY_MAPPING" %in% available_sheets) {
    survey_mapping_raw <- load_config_sheet(config_path, "SURVEY_MAPPING")
    survey_mapping <- parse_survey_mapping(survey_mapping_raw)
  } else if (mode == "ANALYSIS") {
    stop("SURVEY_MAPPING sheet is required when Mode = ANALYSIS", call. = FALSE)
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
      warning(sprintf("Sheet '%s' is empty", sheet_name), call. = FALSE)
      return(data.frame())
    }

    return(df)

  }, error = function(e) {
    stop(sprintf(
      "Error reading sheet '%s':\n  File: %s\n  Error: %s",
      sheet_name, basename(config_path), conditionMessage(e)
    ), call. = FALSE)
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
      stop("PROJECT_SETTINGS must have 'Setting_Name' column", call. = FALSE)
    }
  }

  if (!"Value" %in% names(df)) {
    stop("PROJECT_SETTINGS must have 'Value' column", call. = FALSE)
  }

  # Convert to named list
  settings <- as.list(df$Value)
  names(settings) <- df$Setting_Name

  # Required settings
  required <- c("Project_Name", "Mode")
  missing <- setdiff(required, names(settings))
  if (length(missing) > 0) {
    stop(sprintf(
      "PROJECT_SETTINGS missing required settings: %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }

  # Validate Mode
  settings$Mode <- toupper(trimws(as.character(settings$Mode)))
  if (!settings$Mode %in% c("DESIGN", "ANALYSIS")) {
    stop("Mode must be 'DESIGN' or 'ANALYSIS'", call. = FALSE)
  }

  # Clean Project_Name (no spaces)
  settings$Project_Name <- gsub("\\s+", "_", trimws(as.character(settings$Project_Name)))

  # Resolve file paths relative to project root
  path_settings <- c("Raw_Data_File", "Design_File", "Output_Folder")

  for (ps in path_settings) {
    if (ps %in% names(settings) && !is.na(settings[[ps]]) && nzchar(settings[[ps]])) {
      path_val <- settings[[ps]]

      # If relative path, make absolute
      if (!grepl("^(/|[A-Za-z]:)", path_val)) {
        path_val <- file.path(project_root, path_val)
      }

      settings[[ps]] <- normalizePath(path_val, mustWork = FALSE)
    }
  }

  # Set defaults
  if (is.null(settings$Module_Version) || is.na(settings$Module_Version)) {
    settings$Module_Version <- "v1.0"
  }

  if (is.null(settings$Seed) || is.na(settings$Seed)) {
    settings$Seed <- 12345
  } else {
    settings$Seed <- safe_integer(settings$Seed, 12345)
  }

  # Parse Data_File_Sheet
  if (is.null(settings$Data_File_Sheet) || is.na(settings$Data_File_Sheet)) {
    settings$Data_File_Sheet <- 1  # Default to first sheet
  }

  # Parse optional settings
  settings$Weight_Variable <- if (!is.null(settings$Weight_Variable) &&
                                  !is.na(settings$Weight_Variable) &&
                                  nzchar(trimws(settings$Weight_Variable))) {
    trimws(settings$Weight_Variable)
  } else {
    NULL
  }

  settings$Respondent_ID_Variable <- if (!is.null(settings$Respondent_ID_Variable) &&
                                         !is.na(settings$Respondent_ID_Variable) &&
                                         nzchar(trimws(settings$Respondent_ID_Variable))) {
    trimws(settings$Respondent_ID_Variable)
  } else {
    "RespID"  # Default
  }

  # Parse filter expression
  settings$Filter_Expression <- if (!is.null(settings$Filter_Expression) &&
                                    !is.na(settings$Filter_Expression) &&
                                    nzchar(trimws(settings$Filter_Expression))) {
    trimws(settings$Filter_Expression)
  } else {
    NULL
  }

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
    stop(sprintf(
      "ITEMS sheet missing required columns: %s\n  Found: %s",
      paste(missing_cols, collapse = ", "),
      paste(names(df), collapse = ", ")
    ), call. = FALSE)
  }

  # Clean Item_IDs
  df$Item_ID <- sapply(df$Item_ID, clean_item_id)

  # Check for NA Item_IDs
  na_rows <- which(is.na(df$Item_ID))
  if (length(na_rows) > 0) {
    stop(sprintf(
      "ITEMS sheet has empty Item_ID values in rows: %s",
      paste(na_rows + 1, collapse = ", ")  # +1 for header row
    ), call. = FALSE)
  }

  # Check for duplicate Item_IDs
  dup_ids <- df$Item_ID[duplicated(df$Item_ID)]
  if (length(dup_ids) > 0) {
    stop(sprintf(
      "ITEMS sheet has duplicate Item_IDs: %s",
      paste(unique(dup_ids), collapse = ", ")
    ), call. = FALSE)
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
    stop(sprintf(
      "ITEMS sheet must have at least 2 items with Include=1\n  Found: %d included items",
      n_included
    ), call. = FALSE)
  }

  # Validate exactly 0 or 1 anchor item
  n_anchor <- sum(df$Anchor_Item == 1)
  if (n_anchor > 1) {
    stop(sprintf(
      "ITEMS sheet can have at most 1 Anchor_Item\n  Found: %d anchor items",
      n_anchor
    ), call. = FALSE)
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
      stop("DESIGN_SETTINGS must have 'Parameter_Name' column", call. = FALSE)
    }
  }

  value_col <- intersect(c("Value", "Setting_Value"), names(df))[1]
  if (is.na(value_col)) {
    stop("DESIGN_SETTINGS must have 'Value' column", call. = FALSE)
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
    stop(sprintf(
      "Items_Per_Task (%d) cannot exceed number of items (%d)",
      result$Items_Per_Task, n_items
    ), call. = FALSE)
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
    stop(sprintf(
      "Design_Type must be BALANCED, RANDOM, or OPTIMAL\n  Got: '%s'",
      result$Design_Type
    ), call. = FALSE)
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
    stop(sprintf(
      "SURVEY_MAPPING sheet missing required columns: %s\n  Found: %s",
      paste(missing_cols, collapse = ", "),
      paste(names(df), collapse = ", ")
    ), call. = FALSE)
  }

  # Normalize field types
  df$Field_Type <- toupper(trimws(as.character(df$Field_Type)))

  # Valid field types
  valid_types <- c("VERSION", "BEST_CHOICE", "WORST_CHOICE", "SHOWN_ITEMS")

  invalid_types <- setdiff(unique(df$Field_Type), valid_types)
  if (length(invalid_types) > 0) {
    stop(sprintf(
      "SURVEY_MAPPING has invalid Field_Type values: %s\n  Valid types: %s",
      paste(invalid_types, collapse = ", "),
      paste(valid_types, collapse = ", ")
    ), call. = FALSE)
  }

  # Must have VERSION field
  if (!"VERSION" %in% df$Field_Type) {
    stop("SURVEY_MAPPING must include a VERSION field type", call. = FALSE)
  }

  # Must have at least one BEST_CHOICE and one WORST_CHOICE
  if (!"BEST_CHOICE" %in% df$Field_Type) {
    stop("SURVEY_MAPPING must include at least one BEST_CHOICE field type", call. = FALSE)
  }

  if (!"WORST_CHOICE" %in% df$Field_Type) {
    stop("SURVEY_MAPPING must include at least one WORST_CHOICE field type", call. = FALSE)
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
    stop(sprintf(
      "SEGMENT_SETTINGS sheet missing required columns: %s\n  Found: %s",
      paste(missing_cols, collapse = ", "),
      paste(names(df), collapse = ", ")
    ), call. = FALSE)
  }

  # Clean Segment_IDs
  df$Segment_ID <- trimws(as.character(df$Segment_ID))

  # Check for duplicates
  dup_ids <- df$Segment_ID[duplicated(df$Segment_ID)]
  if (length(dup_ids) > 0) {
    stop(sprintf(
      "SEGMENT_SETTINGS has duplicate Segment_IDs: %s",
      paste(unique(dup_ids), collapse = ", ")
    ), call. = FALSE)
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
    stop("OUTPUT_SETTINGS must have 'Option_Name' column", call. = FALSE)
  }

  value_col <- intersect(c("Value", "Setting_Value"), names(df))[1]
  if (is.na(value_col)) {
    stop("OUTPUT_SETTINGS must have 'Value' column", call. = FALSE)
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
    warning(sprintf(
      "Invalid Score_Rescale_Method: '%s'. Using '0_100'.",
      result$Score_Rescale_Method
    ), call. = FALSE)
    result$Score_Rescale_Method <- "0_100"
  }

  # Validate Output_Item_Sort_Order
  result$Output_Item_Sort_Order <- toupper(result$Output_Item_Sort_Order)
  if (!result$Output_Item_Sort_Order %in% c("UTILITY_DESC", "UTILITY_ASC",
                                            "ITEM_ID", "DISPLAY_ORDER")) {
    warning(sprintf(
      "Invalid Output_Item_Sort_Order: '%s'. Using 'UTILITY_DESC'.",
      result$Output_Item_Sort_Order
    ), call. = FALSE)
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
      stop(sprintf(
        "Items_Per_Task (%d) exceeds number of included items (%d)",
        design_settings$Items_Per_Task, n_included
      ), call. = FALSE)
    }

    # Validate Output_Folder
    if (is.null(project_settings$Output_Folder) ||
        is.na(project_settings$Output_Folder) ||
        !nzchar(project_settings$Output_Folder)) {
      stop("Output_Folder is required in PROJECT_SETTINGS", call. = FALSE)
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
      stop("Raw_Data_File is required in PROJECT_SETTINGS for ANALYSIS mode",
           call. = FALSE)
    }

    if (!file.exists(project_settings$Raw_Data_File)) {
      stop(sprintf(
        "Raw_Data_File not found:\n  Path: %s",
        project_settings$Raw_Data_File
      ), call. = FALSE)
    }

    # Validate Design_File
    if (is.null(project_settings$Design_File) ||
        is.na(project_settings$Design_File) ||
        !nzchar(project_settings$Design_File)) {
      stop("Design_File is required in PROJECT_SETTINGS for ANALYSIS mode",
           call. = FALSE)
    }

    if (!file.exists(project_settings$Design_File)) {
      stop(sprintf(
        "Design_File not found:\n  Path: %s",
        project_settings$Design_File
      ), call. = FALSE)
    }

    # Count tasks from survey mapping
    n_best <- sum(survey_mapping$Field_Type == "BEST_CHOICE")
    n_worst <- sum(survey_mapping$Field_Type == "WORST_CHOICE")

    if (n_best != n_worst) {
      stop(sprintf(
        "SURVEY_MAPPING must have equal BEST_CHOICE and WORST_CHOICE entries\n  BEST_CHOICE: %d\n  WORST_CHOICE: %d",
        n_best, n_worst
      ), call. = FALSE)
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
          stop(sprintf(
            "Invalid R expression in Segment_Def for segment '%s':\n  Expression: %s\n  Error: %s",
            segment_settings$Segment_ID[i],
            seg_def,
            conditionMessage(e)
          ), call. = FALSE)
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
