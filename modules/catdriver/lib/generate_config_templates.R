# ==============================================================================
# GENERATE_CONFIG_TEMPLATES.R - TURAS Catdriver Module
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
#   source("modules/catdriver/lib/generate_config_templates.R")
#   generate_catdriver_config_template("path/to/output/Catdriver_Config.xlsx")
#   # Or generate all templates:
#   generate_all_catdriver_templates("path/to/output/")
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
# SETTINGS SHEET DEFINITION
# ==============================================================================

#' Build Settings sheet definition for catdriver
#'
#' Returns a list of section definitions for the Settings sheet covering
#' file paths, analysis parameters, multinomial options, reference categories,
#' rare level handling, quality controls, output options, HTML report branding,
#' and subgroup analysis.
#'
#' @return List of section definitions
#' @keywords internal
build_catdriver_settings_def <- function() {
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
          default = "",
          description = "Path for output Excel results file",
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
          default = "Categorical Key Driver Analysis",
          description = "Name for this analysis run (used in output headers)",
          valid_values_text = "Free text label",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "outcome_type",
          required = TRUE,
          default = "",
          description = "Type of categorical outcome variable",
          valid_values_text = "binary, ordinal, or multinomial",
          dropdown = c("binary", "ordinal", "multinomial"),
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # MULTINOMIAL
    # ------------------------------------------------------------------
    list(
      section_name = "MULTINOMIAL",
      fields = list(
        list(
          name = "multinomial_mode",
          required = FALSE,
          default = "",
          description = "Required if outcome_type=multinomial. Determines how multinomial outcomes are modelled.",
          valid_values_text = "baseline_category, all_pairwise, one_vs_all, or per_outcome",
          dropdown = c("baseline_category", "all_pairwise", "one_vs_all", "per_outcome"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "target_outcome_level",
          required = FALSE,
          default = "",
          description = "Required if multinomial_mode=one_vs_all. The specific outcome level to compare against all others.",
          valid_values_text = "A value that appears in the outcome variable",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # REFERENCE
    # ------------------------------------------------------------------
    list(
      section_name = "REFERENCE",
      fields = list(
        list(
          name = "reference_category",
          required = FALSE,
          default = "",
          description = "Reference/baseline category for comparisons. If blank, the most frequent category is used.",
          valid_values_text = "A value that appears in the outcome variable",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "allow_missing_reference",
          required = FALSE,
          default = "FALSE",
          description = "If TRUE, allows analysis to proceed when reference_category is not found in data (falls back to auto-detect).",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # RARE LEVELS
    # ------------------------------------------------------------------
    list(
      section_name = "RARE LEVELS",
      fields = list(
        list(
          name = "rare_level_policy",
          required = FALSE,
          default = "warn_only",
          description = "How to handle driver categories with very few observations.",
          valid_values_text = "warn_only, collapse_to_other, drop_level, or error",
          dropdown = c("warn_only", "collapse_to_other", "drop_level", "error"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "rare_level_threshold",
          required = FALSE,
          default = 10,
          description = "Minimum count per driver category. Categories below this threshold trigger the rare_level_policy.",
          valid_values_text = "Integer between 1 and 100",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1, 100)
        ),
        list(
          name = "rare_cell_threshold",
          required = FALSE,
          default = 5,
          description = "Minimum count per outcome x driver cross-tabulation cell. Cells below this may cause model instability.",
          valid_values_text = "Integer between 1 and 50",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1, 50)
        )
      )
    ),

    # ------------------------------------------------------------------
    # QUALITY
    # ------------------------------------------------------------------
    list(
      section_name = "QUALITY",
      fields = list(
        list(
          name = "min_sample_size",
          required = FALSE,
          default = 30,
          description = "Minimum total sample size required to run the analysis.",
          valid_values_text = "Integer between 10 and 10000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(10, 10000)
        ),
        list(
          name = "confidence_level",
          required = FALSE,
          default = 0.95,
          description = "Confidence level for statistical tests and intervals.",
          valid_values_text = "Decimal between 0.80 and 0.99",
          dropdown = NULL,
          numeric_range = c(0.80, 0.99),
          integer_range = NULL
        ),
        list(
          name = "missing_threshold",
          required = FALSE,
          default = 50,
          description = "Maximum allowable missing data percentage per variable. Variables exceeding this are flagged.",
          valid_values_text = "Number between 0 and 100 (percentage)",
          dropdown = NULL,
          numeric_range = c(0, 100),
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # OUTPUT
    # ------------------------------------------------------------------
    list(
      section_name = "OUTPUT",
      fields = list(
        list(
          name = "detailed_output",
          required = FALSE,
          default = "TRUE",
          description = "Include detailed coefficient tables and per-driver sheets in Excel output.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "bootstrap_ci",
          required = FALSE,
          default = "FALSE",
          description = "Calculate bootstrap confidence intervals for driver importance scores.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "bootstrap_reps",
          required = FALSE,
          default = 200,
          description = "Number of bootstrap resamples. Higher values give more precise intervals but take longer.",
          valid_values_text = "Integer between 50 and 10000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(50, 10000)
        )
      )
    ),

    # ------------------------------------------------------------------
    # HTML REPORT
    # ------------------------------------------------------------------
    list(
      section_name = "HTML REPORT",
      fields = list(
        list(
          name = "html_report",
          required = FALSE,
          default = "TRUE",
          description = "Generate an interactive HTML report alongside the Excel output.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Generate_Stats_Pack",
          required = FALSE,
          default = "N",
          description = "Generate a diagnostic stats pack workbook alongside main output. The stats pack provides a full audit trail of data received, methods used, assumptions, and reproducibility — designed for advanced partners and research statisticians. Output file is named {output}_stats_pack.xlsx.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "probability_lifts",
          required = FALSE,
          default = "TRUE",
          description = "Include probability lift charts in the HTML report showing how each driver shifts outcome probabilities.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "brand_colour",
          required = FALSE,
          default = "#323367",
          description = "Primary brand colour for HTML report headers and chart accents. Use hex format.",
          valid_values_text = "Hex colour code, e.g. #323367",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "accent_colour",
          required = FALSE,
          default = "#CC9900",
          description = "Secondary accent colour for HTML report highlights and chart elements. Use hex format.",
          valid_values_text = "Hex colour code, e.g. #CC9900",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "report_title",
          required = FALSE,
          default = "",
          description = "Custom title for the HTML report header. If blank, uses the analysis_name.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "researcher_logo_path",
          required = FALSE,
          default = "",
          description = "Path to researcher/agency logo image for the HTML report header.",
          valid_values_text = "File path to PNG, JPG, or SVG image",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "client_logo_path",
          required = FALSE,
          default = "",
          description = "Path to client logo image for the HTML report header.",
          valid_values_text = "File path to PNG, JPG, or SVG image",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "researcher_name",
          required = FALSE,
          default = "",
          description = "Researcher or agency name displayed in the HTML report footer.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "slide_image_dir",
          required = FALSE,
          default = "",
          description = "Directory containing slide images. Helps resolve relative image paths in the Slides sheet.",
          valid_values_text = "Directory path (absolute or relative to config file)",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "custom_disclaimer",
          required = FALSE,
          default = "",
          description = "Custom text for the report footer disclaimer. Replaces the default disclaimer if provided.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "custom_footer",
          required = FALSE,
          default = "",
          description = "Custom footer text displayed at the bottom of the HTML report.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # SUBGROUP
    # ------------------------------------------------------------------
    list(
      section_name = "SUBGROUP",
      fields = list(
        list(
          name = "subgroup_var",
          required = FALSE,
          default = "",
          description = "Column name for subgroup comparison. Runs the analysis separately per subgroup and compares results.",
          valid_values_text = "Column name from your data file (not outcome or driver)",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "subgroup_min_n",
          required = FALSE,
          default = 30,
          description = "Minimum sample size per subgroup. Subgroups below this threshold are excluded from analysis.",
          valid_values_text = "Integer between 10 and 10000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(10, 10000)
        ),
        list(
          name = "subgroup_include_total",
          required = FALSE,
          default = "TRUE",
          description = "Include the total (all subgroups combined) analysis alongside subgroup-specific results.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
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
# VARIABLES SHEET DEFINITION
# ==============================================================================

#' Build Variables table columns definition
#'
#' Returns a list of column definitions for the Variables table sheet.
#'
#' @return List of column definitions
#' @keywords internal
build_catdriver_variables_columns <- function() {
  list(
    list(
      name = "VariableName",
      width = 22,
      required = TRUE,
      description = "Column name in your data file. Must match exactly (case-sensitive).",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Type",
      width = 14,
      required = TRUE,
      description = "Role of this variable: Outcome (dependent variable), Driver (independent variable), or Weight (survey weight).",
      dropdown = c("Outcome", "Driver", "Weight"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Label",
      width = 35,
      required = TRUE,
      description = "Human-readable label for reports and output tables.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Order",
      width = 40,
      required = FALSE,
      description = "Semicolon-separated category order for ordinal variables (LOW to HIGH). Leave blank for nominal.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    )
  )
}


#' Build Variables example rows
#'
#' Returns example rows for the Variables table sheet demonstrating
#' outcome, driver, and weight variable definitions.
#'
#' @return List of named lists
#' @keywords internal
build_catdriver_variables_examples <- function() {
  list(
    list(
      VariableName = "satisfaction",
      Type = "Outcome",
      Label = "Customer Satisfaction",
      Order = "Low;Medium;High"
    ),
    list(
      VariableName = "service_quality",
      Type = "Driver",
      Label = "Service Quality",
      Order = "Poor;Fair;Good;Excellent"
    ),
    list(
      VariableName = "price_perception",
      Type = "Driver",
      Label = "Price Perception",
      Order = "Too Expensive;Fair;Good Value"
    ),
    list(
      VariableName = "support_experience",
      Type = "Driver",
      Label = "Support Experience",
      Order = "Negative;Neutral;Positive"
    ),
    list(
      VariableName = "survey_weight",
      Type = "Weight",
      Label = "Survey Weight",
      Order = ""
    )
  )
}


# ==============================================================================
# DRIVER_SETTINGS SHEET DEFINITION
# ==============================================================================

#' Build Driver_Settings table columns definition
#'
#' Returns a list of column definitions for the Driver_Settings table sheet,
#' which provides per-driver configuration for type, ordering, reference levels,
#' and handling policies.
#'
#' @return List of column definitions
#' @keywords internal
build_catdriver_driver_settings_columns <- function() {
  list(
    list(
      name = "driver",
      width = 22,
      required = TRUE,
      description = "Driver variable name. Must match a VariableName with Type=Driver in the Variables sheet.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "type",
      width = 16,
      required = TRUE,
      description = "Statistical type: ordinal (ordered categories), nominal (unordered categories), categorical (generic), control_only (included as covariate, not reported as driver).",
      dropdown = c("ordinal", "nominal", "categorical", "control_only"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "levels_order",
      width = 40,
      required = FALSE,
      description = "Semicolon-separated level order LOW to HIGH for ordinal drivers. Required when type=ordinal.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "reference_level",
      width = 20,
      required = FALSE,
      description = "Reference/baseline level for regression contrasts. If blank, first level (or alphabetical) is used.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "missing_strategy",
      width = 20,
      required = FALSE,
      description = "How to handle missing values for this driver.",
      dropdown = c("drop_row", "missing_as_level", "error_if_missing"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "rare_level_policy",
      width = 22,
      required = FALSE,
      description = "Override global rare_level_policy for this driver. Leave blank to use global setting.",
      dropdown = c("warn_only", "collapse_to_other", "drop_level", "error"),
      integer_range = NULL,
      numeric_range = NULL
    )
  )
}


#' Build Driver_Settings example rows
#'
#' Returns example rows for the Driver_Settings table sheet.
#'
#' @return List of named lists
#' @keywords internal
build_catdriver_driver_settings_examples <- function() {
  list(
    list(
      driver = "service_quality",
      type = "ordinal",
      levels_order = "Poor;Fair;Good;Excellent",
      reference_level = "Poor",
      missing_strategy = "drop_row",
      rare_level_policy = ""
    ),
    list(
      driver = "price_perception",
      type = "ordinal",
      levels_order = "Too Expensive;Fair;Good Value",
      reference_level = "Too Expensive",
      missing_strategy = "drop_row",
      rare_level_policy = ""
    ),
    list(
      driver = "support_experience",
      type = "ordinal",
      levels_order = "Negative;Neutral;Positive",
      reference_level = "Negative",
      missing_strategy = "drop_row",
      rare_level_policy = ""
    )
  )
}


# ==============================================================================
# SLIDES SHEET DEFINITION
# ==============================================================================

#' Build Slides table columns definition
#'
#' Returns a list of column definitions for the Slides table sheet,
#' which allows users to define custom presentation slides for the
#' HTML report output.
#'
#' @return List of column definitions
#' @keywords internal
build_catdriver_slides_columns <- function() {
  list(
    list(
      name = "slide_order",
      width = 14,
      required = TRUE,
      description = "Order of the slide in the presentation (1, 2, 3...). Must be a whole number >= 1.",
      dropdown = NULL,
      integer_range = c(1, 999),
      numeric_range = NULL
    ),
    list(
      name = "slide_title",
      width = 30,
      required = TRUE,
      description = "Title displayed on the slide card. Keep concise for best appearance.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "slide_content",
      width = 60,
      required = FALSE,
      description = "Markdown content for the slide body. Supports **bold**, *italic*, ## heading, - bullet, > quote.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "slide_image_path",
      width = 40,
      required = FALSE,
      description = "Path to an image file (PNG, JPG) to embed in the slide. Will be base64 encoded. Relative paths resolved against slide_image_dir.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    )
  )
}


#' Build Slides example rows
#'
#' Returns example rows for the Slides table sheet demonstrating
#' title-only slides, content slides with markdown, and image slides.
#'
#' @return List of named lists
#' @keywords internal
build_catdriver_slides_examples <- function() {
  list(
    list(
      slide_order = 1,
      slide_title = "Executive Summary",
      slide_content = "## Key Findings\n\n- **Service quality** is the strongest driver of satisfaction\n- Price perception has a *moderate* positive effect\n\n> Overall model explains 72% of variance",
      slide_image_path = ""
    ),
    list(
      slide_order = 2,
      slide_title = "Methodology",
      slide_content = "The analysis uses categorical key driver modelling with:\n\n- Ordinal logistic regression\n- Type II Wald chi-square importance ranking\n- Bootstrap confidence intervals (n=500)",
      slide_image_path = "images/methodology_diagram.png"
    )
  )
}


# ==============================================================================
# MAIN TEMPLATE GENERATION FUNCTION
# ==============================================================================

#' Generate Catdriver Config Template
#'
#' Creates a professional, hardened Excel configuration template for the
#' TURAS catdriver module. The template includes data validation, colour-coded
#' required/optional markers, help text, and example data rows.
#'
#' Sheets generated:
#' \itemize{
#'   \item{Settings}{Analysis parameters, file paths, quality controls, output options}
#'   \item{Variables}{Outcome, driver, and weight variable definitions}
#'   \item{Driver_Settings}{Per-driver type, ordering, reference levels, and policies}
#'   \item{Slides}{Custom presentation slides for the HTML report}
#' }
#'
#' @param output_path Character. Full path for the output .xlsx file.
#'
#' @return Invisibly returns the output path on success, or a TRS refusal list
#'   if the output directory does not exist.
#'
#' @examples
#' \dontrun{
#'   generate_catdriver_config_template("output/Catdriver_Config_Template.xlsx")
#' }
#'
#' @export
generate_catdriver_config_template <- function(output_path) {

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
    settings_def = build_catdriver_settings_def(),
    title = "TURAS Catdriver Module - Settings",
    subtitle = "Configure file paths, analysis parameters, quality controls, output options, and subgroup analysis"
  )

  # ============================================================
  # SHEET 2: Variables
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "Variables",
    columns_def = build_catdriver_variables_columns(),
    title = "TURAS Catdriver Module - Variables",
    subtitle = "Define outcome, driver, and weight variables for analysis",
    example_rows = build_catdriver_variables_examples(),
    num_blank_rows = 30
  )

  # ============================================================
  # SHEET 3: Driver_Settings
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "Driver_Settings",
    columns_def = build_catdriver_driver_settings_columns(),
    title = "TURAS Catdriver Module - Driver Settings",
    subtitle = "Per-driver configuration for statistical type, level ordering, reference categories, and handling policies",
    example_rows = build_catdriver_driver_settings_examples(),
    num_blank_rows = 20
  )

  # ============================================================
  # SHEET 4: Slides
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "Slides",
    columns_def = build_catdriver_slides_columns(),
    title = "TURAS Catdriver Module - Slides",
    subtitle = "Define custom presentation slides for the HTML report. Supports markdown content and embedded images.",
    example_rows = build_catdriver_slides_examples(),
    num_blank_rows = 20
  )

  # ============================================================
  # SAVE
  # ============================================================
  saveWorkbook(wb, output_path, overwrite = TRUE)

  cat(sprintf("[Catdriver] Config template saved to: %s\n", output_path))
  cat(sprintf("  Sheets: Settings, Variables, Driver_Settings, Slides\n"))

  invisible(output_path)
}


# ==============================================================================
# BATCH GENERATION
# ==============================================================================

#' Generate All Catdriver Config Templates
#'
#' Convenience wrapper that generates the catdriver config template into
#' the specified output directory with a standard filename.
#'
#' @param output_dir Character. Directory where the template will be saved.
#'
#' @return Invisibly returns the output path on success, or a TRS refusal list
#'   if the output directory does not exist.
#'
#' @examples
#' \dontrun{
#'   generate_all_catdriver_templates("output/templates/")
#' }
#'
#' @export
generate_all_catdriver_templates <- function(output_dir) {

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

  output_path <- file.path(output_dir, "Catdriver_Config_Template.xlsx")

  cat("=== TURAS Catdriver Module: Generating Config Templates ===\n")

  result <- generate_catdriver_config_template(output_path)

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
