# ==============================================================================
# MAXDIFF MODULE - CONFIGURATION VALIDATION - TURAS V10.0
# ==============================================================================
# Cross-reference validation for MaxDiff configuration
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Refactored from 01_config.R for maintainability (2025-12)
#
# FUNCTIONS:
# - validate_config_cross_references(): Validate cross-references between sheets
#
# VALIDATION AREAS:
# - Design mode: Items per task, output folder
# - Analysis mode: Data files, design file, survey mapping consistency
# - Segments: Expression syntax validation
#
# DEPENDENCIES:
# - TRS error handling (maxdiff_refuse)
# ==============================================================================

CONFIG_VALIDATION_VERSION <- "10.0"


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
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("  - config_validation.R loaded (v%s)", CONFIG_VALIDATION_VERSION))
