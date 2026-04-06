# ==============================================================================
# GENERATE_CONFIG_TEMPLATES.R - TURAS Key Driver Analysis Module
# ==============================================================================
# Creates professional, hardened Excel config templates with:
#   - Data validation (dropdown lists) for all option fields
#   - Visual formatting (branded colours, section grouping)
#   - Help text descriptors for every field
#   - Required/Optional markers
#   - Protected non-editable areas (headers, descriptors)
#   - Every permutation and option documented
#
# USAGE:
#   source("modules/keydriver/lib/generate_config_templates.R")
#   generate_keydriver_config_template("path/to/output/KeyDriver_Config.xlsx")
#   # Or generate all templates:
#   generate_all_keydriver_templates("path/to/output/")
#
# DEPENDS ON:
#   modules/shared/template_styles.R (write_settings_sheet, write_table_sheet)
#
# ==============================================================================

library(openxlsx)

# ==============================================================================
# SOURCE SHARED TEMPLATE INFRASTRUCTURE
# ==============================================================================

shared_path <- file.path(dirname(dirname(dirname(sys.frame(1)$ofile))), "shared", "template_styles.R")
if (!file.exists(shared_path)) {
  shared_path <- file.path("modules", "shared", "template_styles.R")
}
source(shared_path)


# ==============================================================================
# SETTINGS SHEET DEFINITIONS
# ==============================================================================

#' Build Settings sheet definition for Key Driver Analysis
#'
#' Returns a list of section definitions covering file paths, analysis options,
#' feature toggles, SHAP config, quadrant config, bootstrap config, and branding.
#'
#' @return List of section definitions
#' @keywords internal
build_keydriver_settings_def <- function() {
  list(
    # ------------------------------------------------------------------
    # FILE PATHS
    # ------------------------------------------------------------------
    list(
      section_name = "FILE PATHS",
      fields = list(
        list(
          name = "data_file",
          required = TRUE,
          default = "",
          description = "Path to data file (CSV, XLSX, SAV, DTA)",
          valid_values_text = "File path ending in .csv, .xlsx, .sav, or .dta",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "output_file",
          required = TRUE,
          default = "keydriver_results.xlsx",
          description = "Path for the output Excel workbook containing key driver analysis results.",
          valid_values_text = "File path ending in .xlsx",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # ANALYSIS
    # ------------------------------------------------------------------
    list(
      section_name = "ANALYSIS",
      fields = list(
        list(
          name = "analysis_name",
          required = FALSE,
          default = "",
          description = "Display name for report headers",
          valid_values_text = "Free text label",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # FEATURES
    # ------------------------------------------------------------------
    list(
      section_name = "FEATURES",
      fields = list(
        list(
          name = "enable_shap",
          required = FALSE,
          default = "FALSE",
          description = "Enable SHAP ML-based importance analysis",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "shap_on_fail",
          required = FALSE,
          default = "refuse",
          description = "What to do if SHAP fails",
          valid_values_text = "refuse or continue_with_flag",
          dropdown = c("refuse", "continue_with_flag"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "enable_quadrant",
          required = FALSE,
          default = "FALSE",
          description = "Enable Importance-Performance Analysis",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "quadrant_on_fail",
          required = FALSE,
          default = "refuse",
          description = "What to do if quadrant analysis fails",
          valid_values_text = "refuse or continue_with_flag",
          dropdown = c("refuse", "continue_with_flag"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "enable_bootstrap",
          required = FALSE,
          default = "FALSE",
          description = "Enable bootstrap confidence intervals",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "enable_html_report",
          required = FALSE,
          default = "FALSE",
          description = "Enable interactive HTML report generation",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Generate_Stats_Pack",
          required = FALSE,
          default = "Y",
          description = "Generate a diagnostic stats pack workbook alongside main output. The stats pack provides a full audit trail of data received, methods used, assumptions, and reproducibility — designed for advanced partners and research statisticians. Output file is named {output}_stats_pack.xlsx.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N"),
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # SHAP CONFIG
    # ------------------------------------------------------------------
    list(
      section_name = "SHAP CONFIG",
      fields = list(
        list(
          name = "shap_model",
          required = FALSE,
          default = "xgboost",
          description = "Model type for SHAP",
          valid_values_text = "xgboost",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "n_trees",
          required = FALSE,
          default = 100,
          description = "Number of trees in gradient boosted ensemble",
          valid_values_text = "Integer between 10 and 1000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(10, 1000)
        ),
        list(
          name = "max_depth",
          required = FALSE,
          default = 6,
          description = "Maximum tree depth controlling model complexity",
          valid_values_text = "Integer between 1 and 20",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1, 20)
        ),
        list(
          name = "learning_rate",
          required = FALSE,
          default = 0.1,
          description = "Learning rate (shrinkage) for gradient boosting",
          valid_values_text = "Numeric between 0.001 and 1.0",
          dropdown = NULL,
          numeric_range = c(0.001, 1.0),
          integer_range = NULL
        ),
        list(
          name = "subsample",
          required = FALSE,
          default = 0.8,
          description = "Row subsampling ratio per tree",
          valid_values_text = "Numeric between 0.1 and 1.0",
          dropdown = NULL,
          numeric_range = c(0.1, 1.0),
          integer_range = NULL
        ),
        list(
          name = "colsample_bytree",
          required = FALSE,
          default = 0.8,
          description = "Column subsampling ratio per tree",
          valid_values_text = "Numeric between 0.1 and 1.0",
          dropdown = NULL,
          numeric_range = c(0.1, 1.0),
          integer_range = NULL
        ),
        list(
          name = "shap_sample_size",
          required = FALSE,
          default = 1000,
          description = "Number of observations to use for SHAP value computation",
          valid_values_text = "Integer between 100 and 10000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(100, 10000)
        ),
        list(
          name = "include_interactions",
          required = FALSE,
          default = "FALSE",
          description = "Compute SHAP interaction values between driver pairs",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "interaction_top_n",
          required = FALSE,
          default = 5,
          description = "Number of top interaction pairs to display",
          valid_values_text = "Integer between 1 and 20",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1, 20)
        ),
        list(
          name = "importance_top_n",
          required = FALSE,
          default = 15,
          description = "Number of top drivers to display in importance ranking",
          valid_values_text = "Integer between 1 and 50",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1, 50)
        )
      )
    ),

    # ------------------------------------------------------------------
    # QUADRANT CONFIG
    # ------------------------------------------------------------------
    list(
      section_name = "QUADRANT CONFIG",
      fields = list(
        list(
          name = "importance_source",
          required = FALSE,
          default = "auto",
          description = "Source of derived importance scores for quadrant placement",
          valid_values_text = "auto, shapley, relative, beta, or shap",
          dropdown = c("auto", "shapley", "relative", "beta", "shap"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "threshold_method",
          required = FALSE,
          default = "mean",
          description = "Method for calculating quadrant threshold lines",
          valid_values_text = "mean or median",
          dropdown = c("mean", "median"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "normalize_axes",
          required = FALSE,
          default = "TRUE",
          description = "Normalize importance and performance to 0-100 scale",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "shade_quadrants",
          required = FALSE,
          default = "TRUE",
          description = "Apply background shading to quadrant regions",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "label_all_points",
          required = FALSE,
          default = "TRUE",
          description = "Label all driver points on the quadrant plot",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "label_top_n",
          required = FALSE,
          default = 10,
          description = "Number of top drivers to label when label_all_points is FALSE",
          valid_values_text = "Integer between 1 and 30",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1, 30)
        ),
        list(
          name = "show_diagonal",
          required = FALSE,
          default = "FALSE",
          description = "Show diagonal reference line on quadrant plot",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # BOOTSTRAP CONFIG
    # ------------------------------------------------------------------
    list(
      section_name = "BOOTSTRAP CONFIG",
      fields = list(
        list(
          name = "bootstrap_iterations",
          required = FALSE,
          default = 500,
          description = "Number of bootstrap resamples for confidence intervals",
          valid_values_text = "Integer between 50 and 10000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(50, 10000)
        ),
        list(
          name = "bootstrap_ci_level",
          required = FALSE,
          default = 0.95,
          description = "Confidence level for bootstrap intervals",
          valid_values_text = "Numeric between 0.80 and 0.99",
          dropdown = NULL,
          numeric_range = c(0.80, 0.99),
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # BRANDING
    # ------------------------------------------------------------------
    list(
      section_name = "BRANDING",
      fields = list(
        list(
          name = "brand_colour",
          required = FALSE,
          default = "#323367",
          description = "Primary brand colour for report headers and accents (hex format)",
          valid_values_text = "Hex colour code, e.g. #323367",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "accent_colour",
          required = FALSE,
          default = "#f59e0b",
          description = "Secondary accent colour for charts and highlights (hex format)",
          valid_values_text = "Hex colour code, e.g. #f59e0b",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "report_title",
          required = FALSE,
          default = "",
          description = "Custom title for the output report workbook",
          valid_values_text = "Free text label",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # STUDY IDENTIFICATION
    # ------------------------------------------------------------------
    list(
      section_name = "STUDY IDENTIFICATION",
      fields = list(
        list(
          name = "Project_Name",
          required = FALSE,
          default = "",
          description = "Project name — appears in the stats pack Declaration sheet for identification and sign-off purposes. Leave blank if not using stats pack.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Analyst_Name",
          required = FALSE,
          default = "",
          description = "Analyst name — appears in the stats pack Declaration sheet.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Research_House",
          required = FALSE,
          default = "",
          description = "Research organisation name — appears in the stats pack Declaration sheet. Use your company or white-label partner name.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    )
  )
}


# ==============================================================================
# TABLE SHEET DEFINITIONS
# ==============================================================================

#' Build Variables sheet column definitions
#'
#' Returns a list of column definitions for the Variables table sheet.
#'
#' @return List of column definitions
#' @keywords internal
build_variables_columns <- function() {
  list(
    list(
      name = "VariableName",
      width = 22,
      required = TRUE,
      description = "Column name in data file for this variable.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Type",
      width = 14,
      required = TRUE,
      description = "Role of this variable: Outcome (dependent), Driver (predictor), or Weight (survey weight).",
      dropdown = c("Outcome", "Driver", "Weight"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Label",
      width = 35,
      required = TRUE,
      description = "Human-readable label for display in reports and charts.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "DriverType",
      width = 16,
      required = FALSE,
      description = "Scale type for driver variables. Determines analysis method.",
      dropdown = c("continuous", "ordinal", "categorical"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "AggregationMethod",
      width = 22,
      required = FALSE,
      description = "Method for aggregating categorical driver importance.",
      dropdown = c("partial_r2", "grouped_permutation", "grouped_shapley"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "ReferenceLevel",
      width = 20,
      required = FALSE,
      description = "Reference category for categorical/ordinal drivers in regression.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    )
  )
}


#' Build Variables sheet example rows
#'
#' Returns example rows for the Variables table sheet.
#'
#' @return List of named lists
#' @keywords internal
build_variables_examples <- function() {
  list(
    list(
      VariableName = "overall_satisfaction",
      Type = "Outcome",
      Label = "Overall Satisfaction",
      DriverType = "",
      AggregationMethod = "",
      ReferenceLevel = ""
    ),
    list(
      VariableName = "service_quality",
      Type = "Driver",
      Label = "Service Quality",
      DriverType = "continuous",
      AggregationMethod = "",
      ReferenceLevel = ""
    ),
    list(
      VariableName = "value_for_money",
      Type = "Driver",
      Label = "Value for Money",
      DriverType = "continuous",
      AggregationMethod = "",
      ReferenceLevel = ""
    ),
    list(
      VariableName = "ease_of_use",
      Type = "Driver",
      Label = "Ease of Use",
      DriverType = "continuous",
      AggregationMethod = "",
      ReferenceLevel = ""
    ),
    list(
      VariableName = "brand_trust",
      Type = "Driver",
      Label = "Brand Trust",
      DriverType = "categorical",
      AggregationMethod = "partial_r2",
      ReferenceLevel = "Low"
    ),
    list(
      VariableName = "survey_weight",
      Type = "Weight",
      Label = "Survey Weight",
      DriverType = "",
      AggregationMethod = "",
      ReferenceLevel = ""
    )
  )
}


#' Build Segments sheet column definitions
#'
#' Returns a list of column definitions for the Segments table sheet.
#'
#' @return List of column definitions
#' @keywords internal
build_segments_columns <- function() {
  list(
    list(
      name = "segment_name",
      width = 25,
      required = TRUE,
      description = "Descriptive label for this segment.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "segment_variable",
      width = 22,
      required = TRUE,
      description = "Column name in data file used for segment membership.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "segment_values",
      width = 40,
      required = TRUE,
      description = "Comma-separated values defining segment membership",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    )
  )
}


#' Build Segments sheet example rows
#'
#' Returns example rows for the Segments table sheet.
#'
#' @return List of named lists
#' @keywords internal
build_segments_examples <- function() {
  list(
    list(
      segment_name = "Young Adults",
      segment_variable = "age_group",
      segment_values = "18-24,25-34"
    ),
    list(
      segment_name = "Premium Customers",
      segment_variable = "customer_tier",
      segment_values = "Gold,Platinum"
    )
  )
}


#' Build StatedImportance sheet column definitions
#'
#' Returns a list of column definitions for the StatedImportance table sheet.
#'
#' @return List of column definitions
#' @keywords internal
build_stated_importance_columns <- function() {
  list(
    list(
      name = "driver",
      width = 22,
      required = TRUE,
      description = "Must match VariableName from Variables sheet",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "stated_importance",
      width = 20,
      required = TRUE,
      description = "Mean stated importance rating (1-10 scale)",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = c(1, 10)
    )
  )
}


#' Build StatedImportance sheet example rows
#'
#' Returns example rows for the StatedImportance table sheet.
#'
#' @return List of named lists
#' @keywords internal
build_stated_importance_examples <- function() {
  list(
    list(
      driver = "service_quality",
      stated_importance = 8.2
    ),
    list(
      driver = "value_for_money",
      stated_importance = 7.5
    ),
    list(
      driver = "ease_of_use",
      stated_importance = 6.8
    ),
    list(
      driver = "brand_trust",
      stated_importance = 7.1
    )
  )
}


# ==============================================================================
# MAIN TEMPLATE GENERATION FUNCTION
# ==============================================================================

#' Generate Key Driver Analysis Config Template
#'
#' Creates a professional, hardened Excel configuration template for the
#' TURAS key driver analysis module. The template includes data validation,
#' colour-coded required/optional markers, help text, and example data rows.
#'
#' Sheets generated:
#' \itemize{
#'   \item{Settings}{File paths, analysis options, feature toggles, SHAP/quadrant/bootstrap config, branding}
#'   \item{Variables}{Outcome, driver, and weight variable definitions}
#'   \item{Segments}{Segment definitions for sub-group analysis}
#'   \item{StatedImportance}{Stated importance ratings for quadrant analysis}
#' }
#'
#' @param output_path Character. Full path for the output .xlsx file.
#'
#' @return Invisibly returns the output path on success, or a TRS refusal list
#'   if the output directory does not exist.
#'
#' @examples
#' \dontrun{
#'   generate_keydriver_config_template("output/KeyDriver_Config_Template.xlsx")
#' }
#'
#' @export
generate_keydriver_config_template <- function(output_path) {

  # --- Guard: validate output path ---
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    return(list(
      status = "REFUSED",
      code = "IO_OUTPUT_DIR_MISSING",
      message = sprintf("Output directory does not exist: '%s'", output_dir),
      how_to_fix = "Create the output directory first, or provide a valid path.",
      context = list(call = match.call(), output_path = output_path)
    ))
  }

  wb <- createWorkbook()

  # ============================================================
  # SHEET 1: Settings
  # ============================================================
  write_settings_sheet(
    wb = wb,
    sheet_name = "Settings",
    settings_def = build_keydriver_settings_def(),
    title = "TURAS Key Driver Analysis - Settings",
    subtitle = "File paths, analysis parameters, feature toggles, model configuration, and branding"
  )

  # ============================================================
  # SHEET 2: Variables
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "Variables",
    columns_def = build_variables_columns(),
    title = "TURAS Key Driver Analysis - Variables",
    subtitle = "Define outcome, driver, and weight variables for the analysis",
    example_rows = build_variables_examples(),
    num_blank_rows = 30
  )

  # ============================================================
  # SHEET 3: Segments
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "Segments",
    columns_def = build_segments_columns(),
    title = "TURAS Key Driver Analysis - Segments",
    subtitle = "Define sub-group segments for comparative driver analysis (optional)",
    example_rows = build_segments_examples(),
    num_blank_rows = 10
  )

  # ============================================================
  # SHEET 4: StatedImportance
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "StatedImportance",
    columns_def = build_stated_importance_columns(),
    title = "TURAS Key Driver Analysis - Stated Importance",
    subtitle = "Provide stated importance ratings for Importance-Performance (quadrant) analysis (optional)",
    example_rows = build_stated_importance_examples(),
    num_blank_rows = 20
  )

  # ============================================================
  # SAVE
  # ============================================================
  saveWorkbook(wb, output_path, overwrite = TRUE)

  cat(sprintf("[KeyDriver] Config template saved to: %s\n", output_path))
  cat(sprintf("  Sheets: Settings, Variables, Segments, StatedImportance\n"))

  invisible(output_path)
}


# ==============================================================================
# BATCH GENERATION
# ==============================================================================

#' Generate All Key Driver Config Templates
#'
#' Convenience wrapper that generates the key driver config template into
#' the specified output directory with a standard filename.
#'
#' @param output_dir Character. Directory where the template will be saved.
#'
#' @return Invisibly returns the output path on success, or a TRS refusal list
#'   if the output directory does not exist.
#'
#' @examples
#' \dontrun{
#'   generate_all_keydriver_templates("output/templates/")
#' }
#'
#' @export
generate_all_keydriver_templates <- function(output_dir) {

  # --- Guard: validate output directory ---
  if (!dir.exists(output_dir)) {
    return(list(
      status = "REFUSED",
      code = "IO_OUTPUT_DIR_MISSING",
      message = sprintf("Output directory does not exist: '%s'", output_dir),
      how_to_fix = "Create the output directory first, or provide a valid path.",
      context = list(call = match.call(), output_dir = output_dir)
    ))
  }

  output_path <- file.path(output_dir, "KeyDriver_Config_Template.xlsx")

  cat("=== TURAS Key Driver Analysis: Generating Config Templates ===\n")

  result <- generate_keydriver_config_template(output_path)

  if (is.list(result) && identical(result$status, "REFUSED")) {
    cat("\n=== Template generation FAILED ===\n")
    cat("Code:", result$code, "\n")
    cat("Message:", result$message, "\n")
    cat("Fix:", result$how_to_fix, "\n")
    return(result)
  }

  cat("\n=== Template generation complete ===\n")
  cat(sprintf("Output: %s\n", output_path))

  invisible(output_path)
}
