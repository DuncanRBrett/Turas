# ==============================================================================
# GENERATE_CONFIG_TEMPLATES.R - TURAS Confidence Module
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
#   source("modules/confidence/lib/generate_config_templates.R")
#   generate_confidence_config_template("path/to/output/Confidence_Config.xlsx")
#   # Or generate all templates:
#   generate_all_confidence_templates("path/to/output/")
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
# SHEET DEFINITIONS
# ==============================================================================

#' Build File_Paths sheet definition
#'
#' Returns a list of section definitions for the File_Paths settings sheet.
#'
#' @return List of section definitions
#' @keywords internal
build_file_paths_def <- function() {
  list(
    list(
      section_name = "FILE PATHS",
      fields = list(
        list(
          name = "Data_File",
          required = TRUE,
          default = "",
          description = "Path to your survey data file (CSV or XLSX format). Relative paths are resolved from the config file location.",
          valid_values_text = "File path ending in .csv or .xlsx",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Output_File",
          required = TRUE,
          default = "",
          description = "Path for the output Excel workbook containing confidence interval results.",
          valid_values_text = "File path ending in .xlsx",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Weight_Variable",
          required = FALSE,
          default = "",
          description = "Column name in your data containing survey weights. Leave blank for unweighted analysis.",
          valid_values_text = "Column name from your data file",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "HTML_Output_File",
          required = FALSE,
          default = "",
          description = "Path for an optional HTML report. Only generated if Generate_HTML_Report is set to Y.",
          valid_values_text = "File path ending in .html",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    )
  )
}


#' Build Study_Settings sheet definition
#'
#' Returns a list of section definitions for the Study_Settings settings sheet.
#'
#' @return List of section definitions
#' @keywords internal
build_study_settings_def <- function() {
  list(
    list(
      section_name = "STATISTICAL SETTINGS",
      fields = list(
        list(
          name = "Confidence_Level",
          required = TRUE,
          default = "0.95",
          description = "Confidence level for interval estimation. 0.95 gives 95% confidence intervals.",
          valid_values_text = "0.90, 0.95, or 0.99",
          dropdown = c("0.90", "0.95", "0.99"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Bootstrap_Iterations",
          required = FALSE,
          default = 5000,
          description = "Number of bootstrap resamples. Higher values give more precise intervals but take longer.",
          valid_values_text = "Integer between 1000 and 10000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1000, 10000)
        ),
        list(
          name = "Calculate_Effective_N",
          required = FALSE,
          default = "Y",
          description = "Calculate effective sample size (n_eff) accounting for design effects from weighting.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Multiple_Comparison_Adjustment",
          required = FALSE,
          default = "N",
          description = "Apply p-value adjustment for multiple comparisons across questions.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Multiple_Comparison_Method",
          required = FALSE,
          default = "",
          description = "Method for multiple comparison adjustment. Only used if Multiple_Comparison_Adjustment is Y.",
          valid_values_text = "Bonferroni, Holm, or FDR",
          dropdown = c("Bonferroni", "Holm", "FDR"),
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),
    list(
      section_name = "OUTPUT SETTINGS",
      fields = list(
        list(
          name = "Decimal_Separator",
          required = FALSE,
          default = ".",
          description = "Character used as the decimal separator in output. Use comma for European formatting.",
          valid_values_text = ". or , (period or comma)",
          dropdown = c(".", ","),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Max_Questions",
          required = FALSE,
          default = 200,
          description = "Maximum number of questions to process. Safety limit to prevent runaway processing.",
          valid_values_text = "Integer between 1 and 1000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1, 1000)
        ),
        list(
          name = "Generate_HTML_Report",
          required = FALSE,
          default = "N",
          description = "Generate an interactive HTML report in addition to the Excel output.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Sampling_Method",
          required = FALSE,
          default = "Not_Specified",
          description = "The sampling methodology used. Affects design effect estimation and interpretation notes.",
          valid_values_text = "Sampling approach used for data collection",
          dropdown = c("Random", "Stratified", "Cluster", "Quota", "Online_Panel",
                       "Self_Selected", "Census", "Not_Specified"),
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),
    list(
      section_name = "BRANDING",
      fields = list(
        list(
          name = "Brand_Colour",
          required = FALSE,
          default = "#1e3a5f",
          description = "Primary brand colour for HTML report headers and accents. Use hex format.",
          valid_values_text = "Hex colour code, e.g. #1e3a5f",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Accent_Colour",
          required = FALSE,
          default = "#2aa198",
          description = "Secondary accent colour for HTML report charts and highlights. Use hex format.",
          valid_values_text = "Hex colour code, e.g. #2aa198",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),
    list(
      section_name = "ADVANCED",
      fields = list(
        list(
          name = "random_seed",
          required = FALSE,
          default = "",
          description = "Set a random seed for reproducible bootstrap and Bayesian results. Leave blank for random.",
          valid_values_text = "Any positive integer",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    )
  )
}


#' Build Question_Analysis columns definition
#'
#' Returns a list of column definitions for the Question_Analysis table sheet.
#'
#' @return List of column definitions
#' @keywords internal
build_question_analysis_columns <- function() {
  list(
    list(
      name = "Question_ID",
      width = 22,
      required = TRUE,
      description = "Column name in data that contains responses for this question.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Statistic_Type",
      width = 18,
      required = TRUE,
      description = "Type of statistic to compute: proportion (binary/categorical), mean (continuous), or nps (Net Promoter Score).",
      dropdown = c("proportion", "mean", "nps"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Run_MOE",
      width = 12,
      required = TRUE,
      description = "Calculate margin of error using the normal approximation method.",
      dropdown = c("Y", "N"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Run_Wilson",
      width = 12,
      required = FALSE,
      description = "Calculate Wilson score confidence interval. Recommended for proportions, especially with small samples.",
      dropdown = c("Y", "N"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Run_Bootstrap",
      width = 14,
      required = TRUE,
      description = "Calculate bootstrap confidence interval. Non-parametric method suitable for any statistic type.",
      dropdown = c("Y", "N"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Run_Credible",
      width = 14,
      required = TRUE,
      description = "Calculate Bayesian credible interval. Requires prior specification for informative priors.",
      dropdown = c("Y", "N"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Categories",
      width = 25,
      required = FALSE,
      description = "Comma-separated category codes for proportion. E.g. '1,2' to calculate proportion of responses coded 1 or 2.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Promoter_Codes",
      width = 20,
      required = FALSE,
      description = "Comma-separated codes for NPS promoters. Typically '9,10' on a 0-10 scale.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Detractor_Codes",
      width = 20,
      required = FALSE,
      description = "Comma-separated codes for NPS detractors. Typically '0,1,2,3,4,5,6' on a 0-10 scale.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Prior_Mean",
      width = 14,
      required = FALSE,
      description = "Prior mean for Bayesian credible intervals. For proportions use 0-1 range, for means use expected scale.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Prior_SD",
      width = 12,
      required = FALSE,
      description = "Prior standard deviation for Bayesian credible intervals. Must be greater than 0.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Prior_N",
      width = 12,
      required = FALSE,
      description = "Prior effective sample size for Bayesian credible intervals. Controls how much weight is given to the prior.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    )
  )
}


#' Build Question_Analysis example rows
#'
#' Returns example rows for the Question_Analysis table sheet.
#'
#' @return List of named lists
#' @keywords internal
build_question_analysis_examples <- function() {
  list(
    list(
      Question_ID = "Q1_Awareness",
      Statistic_Type = "proportion",
      Run_MOE = "Y",
      Run_Wilson = "Y",
      Run_Bootstrap = "Y",
      Run_Credible = "N",
      Categories = "1,2",
      Promoter_Codes = "",
      Detractor_Codes = "",
      Prior_Mean = "",
      Prior_SD = "",
      Prior_N = ""
    ),
    list(
      Question_ID = "Q2_Satisfaction",
      Statistic_Type = "mean",
      Run_MOE = "Y",
      Run_Wilson = "N",
      Run_Bootstrap = "Y",
      Run_Credible = "Y",
      Categories = "",
      Promoter_Codes = "",
      Detractor_Codes = "",
      Prior_Mean = 5.5,
      Prior_SD = 2.0,
      Prior_N = ""
    ),
    list(
      Question_ID = "Q3_NPS",
      Statistic_Type = "nps",
      Run_MOE = "Y",
      Run_Wilson = "N",
      Run_Bootstrap = "Y",
      Run_Credible = "N",
      Categories = "",
      Promoter_Codes = "9,10",
      Detractor_Codes = "0,1,2,3,4,5,6",
      Prior_Mean = "",
      Prior_SD = "",
      Prior_N = ""
    )
  )
}


#' Build Population_Margins columns definition
#'
#' Returns a list of column definitions for the Population_Margins table sheet.
#'
#' @return List of column definitions
#' @keywords internal
build_population_margins_columns <- function() {
  list(
    list(
      name = "Variable",
      width = 22,
      required = TRUE,
      description = "Name of the demographic or stratification variable (must match a column name in your data).",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Category_Label",
      width = 25,
      required = TRUE,
      description = "Human-readable label for this category (e.g. 'Male', 'Female', '18-34').",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Category_Code",
      width = 18,
      required = FALSE,
      description = "Numeric or string code used in the data for this category. If blank, Category_Label is used for matching.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "Target_Prop",
      width = 16,
      required = TRUE,
      description = "Target population proportion for this category. All categories within a variable must sum to approximately 1.0.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = c(0, 1)
    ),
    list(
      name = "Include",
      width = 12,
      required = FALSE,
      description = "Include this margin in the representativeness analysis. Set to N to temporarily exclude.",
      dropdown = c("Y", "N"),
      integer_range = NULL,
      numeric_range = NULL
    )
  )
}


#' Build Population_Margins example rows
#'
#' Returns example rows for the Population_Margins table sheet.
#'
#' @return List of named lists
#' @keywords internal
build_population_margins_examples <- function() {
  list(
    list(
      Variable = "Gender",
      Category_Label = "Male",
      Category_Code = 1,
      Target_Prop = 0.485,
      Include = "Y"
    ),
    list(
      Variable = "Gender",
      Category_Label = "Female",
      Category_Code = 2,
      Target_Prop = 0.515,
      Include = "Y"
    ),
    list(
      Variable = "AgeGroup",
      Category_Label = "18-34",
      Category_Code = 1,
      Target_Prop = 0.30,
      Include = "Y"
    ),
    list(
      Variable = "AgeGroup",
      Category_Label = "35-54",
      Category_Code = 2,
      Target_Prop = 0.40,
      Include = "Y"
    )
  )
}


# ==============================================================================
# MAIN TEMPLATE GENERATION FUNCTION
# ==============================================================================

#' Generate Confidence Module Config Template
#'
#' Creates a professional, hardened Excel configuration template for the
#' TURAS confidence module. The template includes data validation, colour-coded
#' required/optional markers, help text, and example data rows.
#'
#' Sheets generated:
#' \itemize{
#'   \item{File_Paths}{Data file and output file paths}
#'   \item{Study_Settings}{Statistical parameters, output formatting, branding}
#'   \item{Question_Analysis}{Per-question CI method configuration}
#'   \item{Population_Margins}{Population proportions for representativeness}
#' }
#'
#' @param output_path Character. Full path for the output .xlsx file.
#'
#' @return Invisibly returns the output path on success, or a TRS refusal list
#'   if the output directory does not exist.
#'
#' @examples
#' \dontrun{
#'   generate_confidence_config_template("output/Confidence_Config_Template.xlsx")
#' }
#'
#' @export
generate_confidence_config_template <- function(output_path) {

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
  # SHEET 1: File_Paths
  # ============================================================
  write_settings_sheet(
    wb = wb,
    sheet_name = "File_Paths",
    settings_def = build_file_paths_def(),
    title = "TURAS Confidence Module - File Paths",
    subtitle = "Configure data input and output file locations"
  )

  # ============================================================
  # SHEET 2: Study_Settings
  # ============================================================
  write_settings_sheet(
    wb = wb,
    sheet_name = "Study_Settings",
    settings_def = build_study_settings_def(),
    title = "TURAS Confidence Module - Study Settings",
    subtitle = "Statistical parameters, output formatting, and branding options"
  )

  # ============================================================
  # SHEET 3: Question_Analysis
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "Question_Analysis",
    columns_def = build_question_analysis_columns(),
    title = "TURAS Confidence Module - Question Analysis",
    subtitle = "Define which questions to analyse and which CI methods to apply",
    example_rows = build_question_analysis_examples(),
    num_blank_rows = 50
  )

  # ============================================================
  # SHEET 4: Population_Margins
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "Population_Margins",
    columns_def = build_population_margins_columns(),
    title = "TURAS Confidence Module - Population Margins",
    subtitle = "Define population proportions for representativeness analysis (optional)",
    example_rows = build_population_margins_examples(),
    num_blank_rows = 30
  )

  # ============================================================
  # SAVE
  # ============================================================
  saveWorkbook(wb, output_path, overwrite = TRUE)

  cat(sprintf("[Confidence] Config template saved to: %s\n", output_path))
  cat(sprintf("  Sheets: File_Paths, Study_Settings, Question_Analysis, Population_Margins\n"))

  invisible(output_path)
}


# ==============================================================================
# BATCH GENERATION
# ==============================================================================

#' Generate All Confidence Config Templates
#'
#' Convenience wrapper that generates the confidence config template into
#' the specified output directory with a standard filename.
#'
#' @param output_dir Character. Directory where the template will be saved.
#'
#' @return Invisibly returns the output path on success, or a TRS refusal list
#'   if the output directory does not exist.
#'
#' @examples
#' \dontrun{
#'   generate_all_confidence_templates("output/templates/")
#' }
#'
#' @export
generate_all_confidence_templates <- function(output_dir) {

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

  output_path <- file.path(output_dir, "Confidence_Config_Template.xlsx")

  cat("=== TURAS Confidence Module: Generating Config Templates ===\n")

  result <- generate_confidence_config_template(output_path)

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
