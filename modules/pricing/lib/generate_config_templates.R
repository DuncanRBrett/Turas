# ==============================================================================
# TURAS PRICING MODULE - CONFIG TEMPLATE GENERATOR
# ==============================================================================
# Generates professional, hardened Excel config templates using the shared
# TURAS template infrastructure (template_styles.R).
#
# USAGE:
#   source("modules/pricing/lib/generate_config_templates.R")
#   generate_pricing_config_template("Pricing_Config_Template.xlsx")
#

# ------------------------------------------------------------------------------
# Shared workbook saver
# ------------------------------------------------------------------------------
# turas_saveWorkbook() reconciles worksheet relationships before saving. Without
# it openxlsx leaves every sheet pointing at a drawing part it never writes, and
# Excel reports a problem with the file and offers to repair it -- a repair that
# strips every data-validation dropdown in the template.
#
# This file is designed to be sourced on its own, so it locates the shared
# helper itself rather than assuming the caller has already loaded it.
if (!exists("turas_saveWorkbook", mode = "function")) {
  .turas_saver_rel <- file.path("modules", "shared", "lib", "turas_save_workbook_atomic.R")
  .turas_saver_dir <- getwd()
  while (!file.exists(file.path(.turas_saver_dir, .turas_saver_rel)) &&
         .turas_saver_dir != dirname(.turas_saver_dir)) {
    .turas_saver_dir <- dirname(.turas_saver_dir)
  }
  .turas_saver_path <- file.path(.turas_saver_dir, .turas_saver_rel)
  if (file.exists(.turas_saver_path)) {
    source(.turas_saver_path)
  } else {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Code: IO_SAVER_NOT_FOUND\n")
    cat("│ Message: turas_save_workbook_atomic.R was not found, so templates are\n")
    cat("│          written without part reconciliation and Excel may offer to\n")
    cat("│          repair them, losing their dropdowns.\n")
    cat("│ How to fix: run from the Turas project root, or set the working\n")
    cat("│          directory so that modules/shared/lib is reachable\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    turas_saveWorkbook <- function(wb, file, overwrite = TRUE, ...) {
      openxlsx::saveWorkbook(wb, file, overwrite = overwrite, ...)
    }
  }
  rm(.turas_saver_rel, .turas_saver_dir, .turas_saver_path)
}

# ==============================================================================

# Source shared template infrastructure
.find_shared_template_styles <- function() {
  candidates <- c(
    file.path(getwd(), "modules", "shared", "template_styles.R"),
    file.path(dirname(sys.frame(1)$ofile %||% ""), "..", "..", "shared", "template_styles.R"),
    file.path(getwd(), "..", "shared", "template_styles.R")
  )
  for (p in candidates) {
    np <- tryCatch(normalizePath(p, mustWork = TRUE), error = function(e) NULL)
    if (!is.null(np)) return(np)
  }
  msg <- "[PRICING] Cannot locate modules/shared/template_styles.R, template generation requires shared infrastructure"
  cat("\n", msg, "\n")
  stop(msg, call. = FALSE)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x


# ==============================================================================
# SETTINGS SHEET DEFINITIONS
# ==============================================================================

build_settings_def <- function() {
  list(
    list(
      section_name = "FILE PATHS & PROJECT",
      fields = list(
        list(
          name = "Project_Name",
          required = TRUE,
          default = "My Pricing Study",
          description = "Project name shown in reports and output files.",
          valid_values_text = "Any descriptive text",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Analysis_Method",
          required = TRUE,
          default = "van_westendorp",
          description = "Which pricing methodology to run. Use 'both' to run VW + GG together.",
          valid_values_text = "van_westendorp, gabor_granger, monadic, both",
          dropdown = c("van_westendorp", "gabor_granger", "monadic", "both"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Data_File",
          required = TRUE,
          default = "",
          description = "Path to survey data file. Relative paths resolve from config file location.",
          valid_values_text = "File path (.csv, .xlsx, .sav, .dta, .rds)",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Output_File",
          required = FALSE,
          default = "pricing_results.xlsx",
          description = "Output Excel file path. Defaults to config directory if relative.",
          valid_values_text = "File path ending in .xlsx",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "ID_Variable",
          required = FALSE,
          default = "",
          description = "Column name for respondent IDs. Used for tracking exclusions.",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Weight_Variable",
          required = FALSE,
          default = "",
          description = "Column name for case weights. Leave blank for unweighted analysis.",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Currency_Symbol",
          required = FALSE,
          default = "$",
          description = "Currency symbol for price display in reports.",
          valid_values_text = "$, R, \u00A3, \u20AC, etc.",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Unit_Cost",
          required = FALSE,
          default = "",
          description = "Cost per unit for profit calculations. Leave blank to skip profit analysis.",
          valid_values_text = "Positive number",
          dropdown = NULL, numeric_range = c(0, 999999), integer_range = NULL
        ),
        list(
          name = "DK_Codes",
          required = FALSE,
          default = "98,99",
          description = "Don't Know / Refused codes in the data (comma-separated). Recoded to NA.",
          valid_values_text = "Comma-separated numbers (e.g., 98,99)",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "OUTPUT OPTIONS",
      fields = list(
        list(
          name = "Generate_HTML_Report",
          required = FALSE,
          default = "TRUE",
          description = "Generate an interactive HTML report alongside Excel output.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Generate_Simulator",
          required = FALSE,
          default = "FALSE",
          description = "Generate a standalone HTML pricing simulator dashboard for clients.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Brand_Colour",
          required = FALSE,
          default = "#323367",
          description = "Primary brand colour for HTML reports and simulator (hex code).",
          valid_values_text = "Hex colour code (e.g., #323367)",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Generate_Stats_Pack",
          required = FALSE,
          default = "Y",
          description = "Generate a diagnostic stats pack workbook alongside main output. The stats pack provides a full audit trail of data received, methods used, assumptions, and reproducibility, for advanced partners and research statisticians. Output file is named {output}_stats_pack.xlsx.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Generate_Tabs_Export",
          required = FALSE,
          default = "N",
          description = "Write {output}_tabs_pricing.xlsx: the Gabor-Granger acceptance grid as 0/1 columns a tabs (crosstab) project can read as a Multi_Mention question, with a QuestionMap snippet and a METHOD sheet. Needs ID_Variable.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Tabs_Question_Code",
          required = FALSE,
          default = "GGACC",
          description = "QuestionCode for the exported acceptance grid ({code}_1 .. {code}_k).",
          valid_values_text = "Letters, digits and underscores",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Export_WTP",
          required = FALSE,
          default = "N",
          description = "Also export a per-respondent willingness-to-pay column (midpoint of the Van Westendorp cheap and expensive answers), stamped as derived on the METHOD sheet.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "MONOTONICITY HANDLING",
      fields = list(
        list(
          name = "VW_Monotonicity_Behavior",
          required = FALSE,
          default = "drop",
          description = "Respondents whose four answers are not strictly increasing (too cheap < cheap < expensive < too expensive). 'drop' = exclude them (default; the analysed base is reported), 'flag_only' = keep them in the curves and disclose the count, 'fix' = re-sort their answers (a strong transformation).",
          valid_values_text = "drop, fix, flag_only",
          dropdown = c("drop", "fix", "flag_only"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "GG_Monotonicity_Behavior",
          required = FALSE,
          default = "smooth",
          description = "How to handle non-monotonic GG demand curves. 'smooth' = enforce with Smoothing_Method (GaborGranger sheet), 'diagnostic_only' = warn.",
          valid_values_text = "smooth, diagnostic_only",
          dropdown = c("smooth", "diagnostic_only"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "GG_Stop_Early_Imputation",
          required = FALSE,
          default = "NONE",
          description = "For a ladder that stopped after a respondent's first No. NONE (default): the run refuses when the rungs have different bases. NO_AFTER_STOP: unanswered rungs above a respondent's first No are coded No, and the stats pack says so.",
          valid_values_text = "NONE or NO_AFTER_STOP",
          dropdown = c("NONE", "NO_AFTER_STOP"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "SEGMENTATION",
      fields = list(
        list(
          name = "Segment_Column",
          required = FALSE,
          default = "",
          description = "Column name for segment labels. Leave blank to skip segmentation.",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Min_Segment_N",
          required = FALSE,
          default = "50",
          description = "Minimum sample size per segment. Segments below this are flagged.",
          valid_values_text = "Positive integer (recommended: 50+)",
          dropdown = NULL, numeric_range = NULL, integer_range = c(10, 10000)
        ),
        list(
          name = "Include_Total",
          required = FALSE,
          default = "TRUE",
          description = "Include total sample alongside segments in comparison tables.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "PRICE LADDER (GOOD/BETTER/BEST)",
      fields = list(
        list(
          name = "N_Tiers",
          required = FALSE,
          default = "3",
          description = "Number of price tiers to generate.",
          valid_values_text = "2, 3, or 4",
          dropdown = c("2", "3", "4"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Tier_Names",
          required = FALSE,
          default = "Value;Standard;Premium",
          description = "Tier names (semicolon-separated). Must match N_Tiers count.",
          valid_values_text = "Semicolon-separated names",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Min_Gap_Pct",
          required = FALSE,
          default = "15",
          description = "Minimum percentage gap between adjacent tiers.",
          valid_values_text = "5 to 50",
          dropdown = NULL, numeric_range = c(5, 50), integer_range = NULL
        ),
        list(
          name = "Max_Gap_Pct",
          required = FALSE,
          default = "50",
          description = "Maximum percentage gap between adjacent tiers.",
          valid_values_text = "20 to 100",
          dropdown = NULL, numeric_range = c(20, 100), integer_range = NULL
        ),
        list(
          name = "Round_To",
          required = FALSE,
          default = "0.99",
          description = "Rounding strategy for tier prices.",
          valid_values_text = "0.99, 0.95, 0.00, none",
          dropdown = c("0.99", "0.95", "0.00", "none"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "PRICE CONSTRAINTS",
      fields = list(
        list(
          name = "Price_Floor",
          required = FALSE,
          default = "",
          description = "Hard minimum price constraint for recommendations. Leave blank for no floor.",
          valid_values_text = "Positive number or blank",
          dropdown = NULL, numeric_range = c(0, 999999), integer_range = NULL
        ),
        list(
          name = "Price_Ceiling",
          required = FALSE,
          default = "",
          description = "Hard maximum price constraint for recommendations. Leave blank for no ceiling.",
          valid_values_text = "Positive number or blank",
          dropdown = NULL, numeric_range = c(0, 999999), integer_range = NULL
        )
      )
    ),
    list(
      section_name = "STUDY IDENTIFICATION",
      fields = list(
        list(
          name = "Analyst_Name",
          required = FALSE,
          default = "",
          description = "Analyst name, shown in the stats pack Declaration sheet.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Research_House",
          required = FALSE,
          default = "",
          description = "Research organisation name, shown in the stats pack Declaration sheet. Use your company or white-label partner name.",
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
# VAN WESTENDORP SHEET DEFINITION
# ==============================================================================

build_vw_settings_def <- function() {
  list(
    list(
      section_name = "COLUMN MAPPINGS",
      fields = list(
        list(
          name = "Col_Too_Cheap",
          required = TRUE,
          default = "",
          description = "Column: 'At what price would you consider this product so cheap that you would question its quality?'",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Col_Cheap",
          required = TRUE,
          default = "",
          description = "Column: 'At what price would you consider this product a bargain / good value?'",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Col_Expensive",
          required = TRUE,
          default = "",
          description = "Column: 'At what price would you say this product is getting expensive?'",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Col_Too_Expensive",
          required = TRUE,
          default = "",
          description = "Column: 'At what price would you say this product is too expensive to consider?'",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "NMS EXTENSION (OPTIONAL)",
      fields = list(
        list(
          name = "Col_PI_Cheap",
          required = FALSE,
          default = "",
          description = "Purchase intent at 'bargain' price (0-100 or 1-5 scale). Enables NMS revenue optimization.",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Col_PI_Expensive",
          required = FALSE,
          default = "",
          description = "Purchase intent at 'expensive' price (0-100 or 1-5 scale). Required if Col_PI_Cheap is set.",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "PI_Scale",
          required = FALSE,
          default = "5",
          description = "Scale used for purchase intent questions. Used to normalize to 0-1 probability.",
          valid_values_text = "5 (1-5 scale) or 100 (0-100 scale)",
          dropdown = c("5", "100"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "ANALYSIS SETTINGS",
      fields = list(
        list(
          name = "Calculate_Confidence",
          required = FALSE,
          default = "TRUE",
          description = "Calculate bootstrap confidence intervals for price points.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Confidence_Level",
          required = FALSE,
          default = "0.95",
          description = "Confidence level for interval estimation.",
          valid_values_text = "0.90, 0.95, or 0.99",
          dropdown = c("0.90", "0.95", "0.99"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Bootstrap_Iterations",
          required = FALSE,
          default = "1000",
          description = "Number of bootstrap resamples. Higher = more precise CIs but slower.",
          valid_values_text = "500 to 10000",
          dropdown = NULL, numeric_range = NULL, integer_range = c(500, 10000)
        )
      )
    )
  )
}


# ==============================================================================
# GABOR-GRANGER SHEET DEFINITION
# ==============================================================================

build_gg_settings_def <- function() {
  list(
    list(
      section_name = "DATA FORMAT",
      fields = list(
        list(
          name = "Data_Format",
          required = TRUE,
          default = "wide",
          description = "Wide: one purchase intent column per price. Long: price + response columns with respondent ID.",
          valid_values_text = "wide or long",
          dropdown = c("wide", "long"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "WIDE FORMAT SETTINGS (use if Data_Format = wide)",
      fields = list(
        list(
          name = "Price_Sequence",
          required = FALSE,
          default = "",
          description = "Price points tested, in the order they were presented, separated by semicolons or commas. Must match the order of Response_Columns.",
          valid_values_text = "Numbers separated by ; or , (e.g. 60; 80; 100)",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Response_Columns",
          required = FALSE,
          default = "",
          description = "Column names for purchase intent at each price, one per rung, separated by semicolons or commas.",
          valid_values_text = "Column names separated by ; or ,",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "LONG FORMAT SETTINGS (use if Data_Format = long)",
      fields = list(
        list(
          name = "Price_Column",
          required = FALSE,
          default = "",
          description = "Column containing the price shown to respondent.",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Response_Column",
          required = FALSE,
          default = "",
          description = "Column containing purchase intent response.",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Respondent_Column",
          required = FALSE,
          default = "",
          description = "Column containing respondent ID (for long format).",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "RESPONSE CODING",
      fields = list(
        list(
          name = "Response_Type",
          required = FALSE,
          default = "binary",
          description = "How purchase intent is coded. Binary: 0/1 or yes/no (see Binary_Coding for 1/2 data). Scale: top-box from a Likert scale.",
          valid_values_text = "binary or scale",
          dropdown = c("binary", "scale"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Scale_Threshold",
          required = FALSE,
          default = "3",
          description = "Top-box threshold if Response_Type = scale. Values >= this count as 'would buy'.",
          valid_values_text = "Integer (e.g., 3 on a 5-point scale)",
          dropdown = NULL, numeric_range = NULL, integer_range = c(1, 10)
        ),
        list(
          name = "Binary_Coding",
          required = FALSE,
          default = "ZERO_ONE",
          description = "For Response_Type = binary: ZERO_ONE means 1 = would buy, 0 = would not. ONE_TWO means 1 = would buy, 2 = would not (the usual survey export). Any other value refuses.",
          valid_values_text = "ZERO_ONE or ONE_TWO",
          dropdown = c("ZERO_ONE", "ONE_TWO"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    ),
    list(
      section_name = "ANALYSIS OPTIONS",
      fields = list(
        list(
          name = "Smoothing_Method",
          required = FALSE,
          default = "isotonic",
          description = "How a demand curve that rises with price is corrected before revenue is computed (applies when GG_Monotonicity_Behavior = smooth). Isotonic pools adjacent violators; cummax only raises values.",
          valid_values_text = "isotonic, cummax, loess, none",
          dropdown = c("isotonic", "cummax", "loess", "none"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Calculate_Elasticity",
          required = FALSE,
          default = "TRUE",
          description = "Calculate arc price elasticity between consecutive price points.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Revenue_Optimization",
          required = FALSE,
          default = "TRUE",
          description = "Find the revenue-maximizing price from the demand curve.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Confidence_Intervals",
          required = FALSE,
          default = "TRUE",
          description = "Calculate bootstrap CIs for demand curve and optimal price.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Bootstrap_Iterations",
          required = FALSE,
          default = "1000",
          description = "Number of bootstrap resamples for confidence intervals.",
          valid_values_text = "500 to 10000",
          dropdown = NULL, numeric_range = NULL, integer_range = c(500, 10000)
        ),
        list(
          name = "Confidence_Level",
          required = FALSE,
          default = "0.95",
          description = "Confidence level for interval estimation.",
          valid_values_text = "0.90, 0.95, or 0.99",
          dropdown = c("0.90", "0.95", "0.99"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    )
  )
}


# ==============================================================================
# MONADIC SHEET DEFINITION
# ==============================================================================

build_monadic_settings_def <- function() {
  list(
    list(
      section_name = "COLUMN MAPPINGS",
      fields = list(
        list(
          name = "Price_Column",
          required = TRUE,
          default = "",
          description = "Column containing the price shown to each respondent (randomly assigned).",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Intent_Column",
          required = TRUE,
          default = "",
          description = "Column containing purchase intent response (binary yes/no or scale).",
          valid_values_text = "Column name in data file",
          dropdown = NULL, numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Intent_Type",
          required = FALSE,
          default = "binary",
          description = "How intent is coded. Binary: 0/1 or yes/no. Scale: top-box from Likert.",
          valid_values_text = "binary or scale",
          dropdown = c("binary", "scale"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Scale_Threshold",
          required = FALSE,
          default = "4",
          description = "Top-box threshold if Intent_Type = scale. Values >= this count as 'would buy'.",
          valid_values_text = "Integer on intent scale",
          dropdown = NULL, numeric_range = NULL, integer_range = c(1, 10)
        )
      )
    ),
    list(
      section_name = "MODEL SETTINGS",
      fields = list(
        list(
          name = "Model_Type",
          required = FALSE,
          default = "logistic",
          description = "Regression model for demand curve. Logistic is standard; log-logistic for asymmetric curves.",
          valid_values_text = "logistic or log_logistic",
          dropdown = c("logistic", "log_logistic"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Min_Cell_Size",
          required = FALSE,
          default = "30",
          description = "Minimum respondents per price cell. Cells below this are flagged.",
          valid_values_text = "Positive integer (recommended: 30+)",
          dropdown = NULL, numeric_range = NULL, integer_range = c(10, 1000)
        ),
        list(
          name = "Prediction_Points",
          required = FALSE,
          default = "100",
          description = "Number of points for the predicted demand curve (higher = smoother).",
          valid_values_text = "50 to 500",
          dropdown = NULL, numeric_range = NULL, integer_range = c(50, 500)
        ),
        list(
          name = "Confidence_Intervals",
          required = FALSE,
          default = "TRUE",
          description = "Calculate bootstrap CIs for demand curve and optimal price.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL, integer_range = NULL
        ),
        list(
          name = "Bootstrap_Iterations",
          required = FALSE,
          default = "1000",
          description = "Number of bootstrap resamples for confidence intervals.",
          valid_values_text = "500 to 10000",
          dropdown = NULL, numeric_range = NULL, integer_range = c(500, 10000)
        ),
        list(
          name = "Confidence_Level",
          required = FALSE,
          default = "0.95",
          description = "Confidence level for interval estimation.",
          valid_values_text = "0.90, 0.95, or 0.99",
          dropdown = c("0.90", "0.95", "0.99"),
          numeric_range = NULL, integer_range = NULL
        )
      )
    )
  )
}


# ==============================================================================
# SIMULATOR SHEET DEFINITION (TABLE FORMAT)
# ==============================================================================

build_simulator_columns_def <- function() {
  list(
    list(
      name = "Scenario_Name",
      width = 22,
      required = TRUE,
      description = "Display name for this scenario preset (e.g., 'Budget Launcher', 'Premium Pro')."
    ),
    list(
      name = "Product_Price",
      width = 16,
      required = TRUE,
      description = "Product price for this scenario.",
      numeric_range = c(0, 999999)
    ),
    list(
      name = "Competitor_1_Price",
      width = 18,
      required = FALSE,
      description = "Competitor 1 price. Leave blank if not applicable."
    ),
    list(
      name = "Competitor_2_Price",
      width = 18,
      required = FALSE,
      description = "Competitor 2 price. Leave blank if not applicable."
    ),
    list(
      name = "Competitor_3_Price",
      width = 18,
      required = FALSE,
      description = "Competitor 3 price. Leave blank if not applicable."
    ),
    list(
      name = "Description",
      width = 40,
      required = FALSE,
      description = "Brief description shown on scenario card in the simulator."
    )
  )
}


# ==============================================================================
# VALIDATION SHEET DEFINITION
# ==============================================================================

build_validation_settings_def <- function() {
  list(
    list(
      section_name = "DATA QUALITY THRESHOLDS",
      fields = list(
        list(
          name = "Min_Completeness",
          required = FALSE,
          default = "0.80",
          description = "Minimum response completeness rate (0-1). Respondents below this are excluded.",
          valid_values_text = "0.50 to 1.00",
          dropdown = NULL, numeric_range = c(0.5, 1.0), integer_range = NULL
        ),
        list(
          name = "Min_Sample",
          required = FALSE,
          default = "30",
          description = "Minimum valid sample size to proceed with analysis. Below this triggers REFUSE.",
          valid_values_text = "Positive integer",
          dropdown = NULL, numeric_range = NULL, integer_range = c(10, 10000)
        ),
        list(
          name = "Price_Min",
          required = FALSE,
          default = "0",
          description = "Minimum valid price value. Responses below this are treated as invalid.",
          valid_values_text = "Number (0 or higher)",
          dropdown = NULL, numeric_range = c(0, 999999), integer_range = NULL
        ),
        list(
          name = "Price_Max",
          required = FALSE,
          default = "10000",
          description = "Maximum valid price value. Responses above this are treated as invalid.",
          valid_values_text = "Number",
          dropdown = NULL, numeric_range = c(0, 999999), integer_range = NULL
        )
      )
    )
  )
}


# ==============================================================================
# MAIN GENERATOR FUNCTION
# ==============================================================================

#' Generate Pricing Configuration Template
#'
#' Creates a professional, hardened Excel configuration template for the
#' Turas Pricing module. Uses shared template infrastructure for consistent
#' look and feel across all Turas modules.
#'
#' @param output_path Path for the output Excel file
#' @param include_monadic Include the Monadic sheet (default TRUE)
#' @param include_simulator Include the Simulator Scenarios sheet (default TRUE)
#' @param overwrite Overwrite existing file (default TRUE)
#'
#' @return Invisibly returns the output path
#' @export
generate_pricing_config_template <- function(output_path,
                                              include_monadic = TRUE,
                                              include_simulator = TRUE,
                                              overwrite = TRUE) {

  cat("\n=== TURAS Pricing Module: Generating Config Template ===\n")

  # Source shared infrastructure
  tryCatch({
    source(.find_shared_template_styles())
    cat("  Loaded shared template infrastructure\n")
  }, error = function(e) {
    stop(sprintf("Failed to load template infrastructure: %s", e$message))
  })

  wb <- createWorkbook()

  # --------------------------------------------------------------------------
  # Sheet 1: Settings
  # --------------------------------------------------------------------------
  cat("  [1/7] Settings sheet...\n")
  settings_def <- build_settings_def()
  write_settings_sheet(wb, "Settings", settings_def,
                       title = "TURAS Pricing Module - Configuration",
                       subtitle = "Edit the Value column to configure your pricing analysis. See Description for guidance.")

  # --------------------------------------------------------------------------
  # Sheet 2: Van Westendorp
  # --------------------------------------------------------------------------
  cat("  [2/7] VanWestendorp sheet...\n")
  vw_def <- build_vw_settings_def()
  write_settings_sheet(wb, "VanWestendorp", vw_def,
                       title = "Van Westendorp Price Sensitivity Meter",
                       subtitle = "Map your survey columns and configure VW analysis settings. NMS extension requires purchase intent columns.")

  # --------------------------------------------------------------------------
  # Sheet 3: Gabor-Granger
  # --------------------------------------------------------------------------
  cat("  [3/7] GaborGranger sheet...\n")
  gg_def <- build_gg_settings_def()
  write_settings_sheet(wb, "GaborGranger", gg_def,
                       title = "Gabor-Granger Demand Curve Analysis",
                       subtitle = "Configure data format (wide or long) and analysis options. Complete only the relevant format section.")

  # --------------------------------------------------------------------------
  # Sheet 4: Monadic
  # --------------------------------------------------------------------------
  if (include_monadic) {
    cat("  [4/7] Monadic sheet...\n")
    monadic_def <- build_monadic_settings_def()
    write_settings_sheet(wb, "Monadic", monadic_def,
                         title = "Monadic Price Testing",
                         subtitle = "Configure monadic analysis where each respondent sees a single randomly-assigned price.")
  } else {
    cat("  [4/7] Monadic sheet... SKIPPED\n")
  }

  # --------------------------------------------------------------------------
  # Sheet 5: Simulator Scenarios
  # --------------------------------------------------------------------------
  if (include_simulator) {
    cat("  [5/7] Simulator sheet...\n")
    sim_cols <- build_simulator_columns_def()
    example_scenarios <- list(
      list(Scenario_Name = "[Example] Budget Launcher", Product_Price = 9.99,
           Competitor_1_Price = 12.99, Competitor_2_Price = 14.99,
           Competitor_3_Price = "", Description = "Aggressive entry-level pricing"),
      list(Scenario_Name = "[Example] Market Match", Product_Price = 12.99,
           Competitor_1_Price = 12.99, Competitor_2_Price = 14.99,
           Competitor_3_Price = "", Description = "Price parity with main competitor"),
      list(Scenario_Name = "[Example] Premium Pro", Product_Price = 16.99,
           Competitor_1_Price = 12.99, Competitor_2_Price = 14.99,
           Competitor_3_Price = "", Description = "Premium positioning with value story")
    )
    write_table_sheet(wb, "Simulator", sim_cols,
                      title = "Pricing Simulator - Preset Scenarios",
                      subtitle = "Define preset scenarios for the interactive simulator dashboard. Each row becomes a clickable scenario card.",
                      example_rows = example_scenarios,
                      num_blank_rows = 10)
  } else {
    cat("  [5/7] Simulator sheet... SKIPPED\n")
  }

  # --------------------------------------------------------------------------
  # Sheet 6: Validation
  # --------------------------------------------------------------------------
  cat("  [6/7] Validation sheet...\n")
  val_def <- build_validation_settings_def()
  write_settings_sheet(wb, "Validation", val_def,
                       title = "Data Quality & Validation Settings",
                       subtitle = "Configure thresholds for data quality checks and the minimum sample size.")

  # --------------------------------------------------------------------------
  # Sheet 7: Reference (read-only)
  # --------------------------------------------------------------------------
  cat("  [7/7] Reference sheet...\n")
  addWorksheet(wb, "Reference", gridLines = FALSE)
  setColWidths(wb, "Reference", cols = 1:2, widths = c(30, 60))

  writeData(wb, "Reference", x = "TURAS Pricing Module - Quick Reference",
            startRow = 1, startCol = 1)
  addStyle(wb, "Reference", make_title_style(), rows = 1, cols = 1)
  mergeCells(wb, "Reference", cols = 1:2, rows = 1)

  ref_data <- data.frame(
    Topic = c(
      "Analysis Methods",
      "",
      "",
      "",
      "",
      "Survey Requirements",
      "",
      "",
      "",
      "Sample Size Guidance",
      "",
      "",
      "",
      "Key Outputs",
      "",
      "",
      "",
      ""
    ),
    Details = c(
      "Van Westendorp PSM: Finds acceptable price range via 4 price perception questions",
      "  + NMS Extension: Adds purchase intent calibration for revenue-optimal pricing",
      "Gabor-Granger: Constructs demand curve from sequential purchase intent at fixed prices",
      "Monadic: Gold standard unbiased method - each respondent sees ONE random price",
      "Combined: Run VW + GG together for triangulated recommendation",
      "VW: 4 open-ended price questions (too cheap, bargain, expensive, too expensive)",
      "VW+NMS: Add 2 purchase intent questions at bargain and expensive prices",
      "GG: Purchase intent at each tested price point (binary or scale)",
      "Monadic: Random price assignment + purchase intent (binary or scale)",
      "VW: Minimum 100 respondents (200+ recommended for stable CIs)",
      "GG: Minimum 30 respondents per price point tested",
      "Monadic: Minimum 150 per price cell (30+ cells recommended)",
      "Segmentation: 50+ per segment minimum",
      "Excel workbook with method-specific sheets + diagnostics",
      "HTML report with interactive charts and plain-English callouts",
      "Pricing simulator (standalone HTML) with What-If scenarios",
      "Price ladder (Good/Better/Best tier structure)",
      "Executive recommendation with confidence assessment"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Reference", ref_data, startRow = 3, headerStyle = make_header_style())
  addStyle(wb, "Reference", make_help_style(), rows = 4:21, cols = 1:2, gridExpand = TRUE)

  # --------------------------------------------------------------------------
  # Insights Sheet (optional pre-filled insights for HTML report)
  # --------------------------------------------------------------------------
  addWorksheet(wb, "Insights", gridLines = FALSE)

  insights_data <- data.frame(
    Section = c("summary", "van_westendorp", "gabor_granger", "monadic",
                "segments", "recommendation", "simulator"),
    Insight_Text = c(
      "",  # summary
      "",  # van_westendorp
      "",  # gabor_granger
      "",  # monadic
      "",  # segments
      "",  # recommendation
      ""   # simulator
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Insights", insights_data, startRow = 1, headerStyle = make_header_style())
  addStyle(wb, "Insights", make_help_style(), rows = 2:8, cols = 1:2, gridExpand = TRUE)

  # --------------------------------------------------------------------------
  # AddedSlides Sheet (optional narrative slides for HTML report)
  # --------------------------------------------------------------------------
  addWorksheet(wb, "AddedSlides", gridLines = FALSE)

  slides_data <- data.frame(
    slide_title = c("[Example] Slide", ""),
    content = c("Rows whose title starts with [Example] are never loaded. Replace the title and this text with your narrative. Supports **bold**, *italic*, ## headings, - bullets, > quotes.", ""),
    image_path = c("", ""),
    display_order = c(1, 2),
    stringsAsFactors = FALSE
  )

  writeData(wb, "AddedSlides", slides_data, startRow = 1, headerStyle = make_header_style())
  addStyle(wb, "AddedSlides", make_help_style(), rows = 2:3, cols = 1:4, gridExpand = TRUE)
  setColWidths(wb, "AddedSlides", cols = 1:4, widths = c(25, 60, 30, 15))

  # --------------------------------------------------------------------------
  # Save
  # --------------------------------------------------------------------------
  turas_saveWorkbook(wb, output_path, overwrite = overwrite)
  cat(sprintf("\n  Config template saved: %s\n", output_path))
  cat("  Open in Excel and fill in the Value column for each sheet.\n\n")

  invisible(output_path)
}
