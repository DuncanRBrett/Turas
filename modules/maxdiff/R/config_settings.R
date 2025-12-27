# ==============================================================================
# MAXDIFF MODULE - CONFIGURATION SETTINGS PARSING - TURAS V10.0
# ==============================================================================
# Parsing functions for design, survey, segment, and output settings
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Refactored from 01_config.R for maintainability (2025-12)
#
# FUNCTIONS:
# - parse_design_settings(): Parse DESIGN_SETTINGS sheet
# - parse_survey_mapping(): Parse SURVEY_MAPPING sheet
# - parse_segment_settings(): Parse SEGMENT_SETTINGS sheet
# - parse_output_settings(): Parse OUTPUT_SETTINGS sheet
# - get_default_output_settings(): Return default output settings
#
# DEPENDENCIES:
# - shared/config_utils.R (for validation functions)
# ==============================================================================

CONFIG_SETTINGS_VERSION <- "10.0"


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
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("  - config_settings.R loaded (v%s)", CONFIG_SETTINGS_VERSION))
