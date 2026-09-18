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
# SOURCE SHARED TEMPLATE INFRASTRUCTURE
# ==============================================================================

# sys.frame(1)$ofile is only set when this file is sourced from inside another
# sourced file. Sourcing it directly — the way the USAGE block above says to —
# leaves it NULL, and dirname(NULL) raises "a character vector argument
# expected" before the working-directory fallback below is ever reached.
.tpl_ofile <- sys.frame(1)$ofile
shared_path <- if (is.character(.tpl_ofile) && length(.tpl_ofile) == 1L) {
  file.path(dirname(dirname(dirname(.tpl_ofile))), "shared", "template_styles.R")
} else {
  ""
}
if (!nzchar(shared_path) || !file.exists(shared_path)) {
  shared_path <- file.path("modules", "shared", "template_styles.R")
}
# Last resort: walk up from the working directory. A testthat run starts in the
# module's tests/testthat, where neither of the paths above resolves.
if (!file.exists(shared_path)) {
  .tpl_dir <- getwd()
  for (.i in 1:10) {
    .try <- file.path(.tpl_dir, "modules", "shared", "template_styles.R")
    if (file.exists(.try)) { shared_path <- .try; break }
    .tpl_dir <- dirname(.tpl_dir)
  }
  rm(list = intersect(c(".tpl_dir", ".i", ".try"), ls()))
}
# Already loaded by the caller is a perfectly good answer.
if (!exists("write_table_sheet", mode = "function") || file.exists(shared_path)) {
  source(shared_path)
}
rm(.tpl_ofile)


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
          name = "enable_elastic_net",
          required = FALSE,
          default = "FALSE",
          description = "Enable elastic net regularised regression (v10.4). Requires the glmnet package.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "enable_nca",
          required = FALSE,
          default = "FALSE",
          description = "Enable Necessary Condition Analysis (v10.4). Requires the NCA package.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "enable_dominance",
          required = FALSE,
          default = "FALSE",
          description = "Enable dominance analysis, the full LMG decomposition (v10.4). Requires the domir package.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "enable_gam",
          required = FALSE,
          default = "FALSE",
          description = "Enable GAM nonlinear effects analysis (v10.4). Requires the mgcv package.",
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
          description = "Generate a diagnostic stats pack workbook alongside main output. The stats pack provides a full audit trail of data received, methods used, assumptions, and reproducibility, designed for advanced partners and research statisticians. Output file is named {output}_stats_pack.xlsx.",
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
          description = paste0(
            "Source of derived importance scores for quadrant placement. ",
            "'auto' means the Shapley decomposition, which is also what the ",
            "importance table is ranked by, so the quadrant and the table ",
            "agree about which driver is biggest. It stays Shapley even when ",
            "SHAP has run: set 'shap' explicitly to plot SHAP importance. ",
            "Whichever source is asked for, the one actually used is written ",
            "to the Run_Status sheet and to the interactive report."),
          # These are the values the engine actually handles. The dropdown used
          # to offer shapley, relative and beta, none of which it understood,
          # so choosing one silently fell back to auto (review H11).
          valid_values_text = "auto, shap, relative_weights, regression, or correlation",
          dropdown = c("auto", "shap", "relative_weights", "regression", "correlation"),
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
          # Was 500 here while the code's default was 1000, a fourth place
          # for the two-defaults problem review M8 was about to hide in.
          default = 1000,
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
    # ADVANCED METHOD CONFIG (v10.4)
    # ------------------------------------------------------------------
    list(
      section_name = "ADVANCED METHOD CONFIG",
      fields = list(
        list(
          name = "elastic_net_alpha",
          required = FALSE,
          default = 0.5,
          description = "Elastic net mixing parameter. 0 is ridge, 1 is lasso, 0.5 is elastic net.",
          valid_values_text = "Numeric between 0 and 1",
          dropdown = NULL,
          numeric_range = c(0, 1),
          integer_range = NULL
        ),
        list(
          name = "elastic_net_nfolds",
          required = FALSE,
          default = 10,
          description = "Cross-validation folds for the elastic net.",
          valid_values_text = "Integer between 3 and 20",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(3, 20)
        ),
        list(
          name = "gam_k",
          required = FALSE,
          default = 5,
          description = "Basis dimension for the GAM smooth terms. Five suits survey scales.",
          valid_values_text = "Integer between 3 and 20",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(3, 20)
        ),
        list(
          name = "nca_test_reps",
          required = FALSE,
          default = 100,
          description = "Permutation replications for the NCA significance test. Zero skips the test.",
          valid_values_text = "Integer between 0 and 10000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(0, 10000)
        ),
        list(
          name = "min_segment_n",
          required = FALSE,
          default = 30,
          description = "Minimum respondents a segment needs before it is compared.",
          valid_values_text = "Integer between 10 and 1000",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(10, 1000)
        ),
        list(
          name = "vif_moderate_threshold",
          required = FALSE,
          default = 5,
          description = "VIF above this is flagged as moderate multicollinearity.",
          valid_values_text = "Numeric between 2 and 20",
          dropdown = NULL,
          numeric_range = c(2, 20),
          integer_range = NULL
        ),
        list(
          name = "vif_high_threshold",
          required = FALSE,
          default = 10,
          description = "VIF above this is flagged as severe multicollinearity.",
          valid_values_text = "Numeric between 2 and 50",
          dropdown = NULL,
          numeric_range = c(2, 50),
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # REPORT SECTIONS
    # ------------------------------------------------------------------
    list(
      section_name = "REPORT SECTIONS",
      fields = list(
        list(
          name = "correlation_display",
          required = FALSE,
          default = "heatmap",
          description = "How the correlation section is shown in the HTML report.",
          valid_values_text = "heatmap, table or both",
          dropdown = c("heatmap", "table", "both"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "bootstrap_display",
          required = FALSE,
          default = "summary",
          description = "How the bootstrap section is shown in the HTML report.",
          valid_values_text = "summary, table or full",
          dropdown = c("summary", "table", "full"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_exec_summary",
          required = FALSE,
          default = "TRUE",
          description = "Show the Executive Summary section in the HTML report.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_importance",
          required = FALSE,
          default = "TRUE",
          description = "Show the Importance section.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_methods",
          required = FALSE,
          default = "TRUE",
          description = "Show the Method Comparison section.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_effect_sizes",
          required = FALSE,
          default = "TRUE",
          description = "Show the Effect Sizes section.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_correlations",
          required = FALSE,
          default = "TRUE",
          description = "Show the Correlations section.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_diagnostics",
          required = FALSE,
          default = "TRUE",
          description = "Show the Model Diagnostics section.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_segments",
          required = FALSE,
          default = "TRUE",
          description = "Show the Segment Comparison section.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_shap",
          required = FALSE,
          default = "TRUE",
          description = "Show the SHAP section, when SHAP has run.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_quadrant",
          required = FALSE,
          default = "TRUE",
          description = "Show the Quadrant section, when the quadrant has run.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_bootstrap",
          required = FALSE,
          default = "TRUE",
          description = "Show the Bootstrap Intervals section, when the bootstrap has run.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "html_show_guide",
          required = FALSE,
          default = "TRUE",
          description = "Show the Interpretation Guide section.",
          valid_values_text = "TRUE or FALSE",
          dropdown = c("TRUE", "FALSE"),
          numeric_range = NULL,
          integer_range = NULL
        )
      )
    ),

    # ------------------------------------------------------------------
    # REPRODUCIBILITY
    # ------------------------------------------------------------------
    list(
      section_name = "REPRODUCIBILITY",
      fields = list(
        list(
          name = "random_seed",
          required = FALSE,
          default = 20260101,
          description = "Seed for every randomised step: the bootstrap, the SHAP model and its sampling. The same seed gives the same numbers twice, and the seed used is written to the Run_Status sheet.",
          valid_values_text = "Any whole number",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = c(1, 2147483647)
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
          name = "company_name",
          required = FALSE,
          default = "",
          description = "Your organisation's name, shown in the HTML report footer. Defaults to The Research LampPost (Pty) Ltd.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "client_name",
          required = FALSE,
          default = "",
          description = "The client's name, shown in the HTML report footer when set.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "researcher_name",
          required = FALSE,
          default = "",
          description = "The researcher's name, shown in the HTML report header when set.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "researcher_logo_path",
          required = FALSE,
          default = "",
          description = "Path to your logo image for the HTML report header. Relative paths resolve from the config file's folder.",
          valid_values_text = "File path to a png, jpg or svg",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "client_logo_path",
          required = FALSE,
          default = "",
          description = "Path to the client's logo image for the HTML report header.",
          valid_values_text = "File path to a png, jpg or svg",
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
          description = "Project name. Appears in the stats pack Declaration sheet for identification and sign-off purposes. Leave blank if not using stats pack.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Analyst_Name",
          required = FALSE,
          default = "",
          description = "Analyst name. Appears in the stats pack Declaration sheet.",
          valid_values_text = "Free text",
          dropdown = NULL,
          numeric_range = NULL,
          integer_range = NULL
        ),
        list(
          name = "Research_House",
          required = FALSE,
          default = "",
          description = "Research organisation name. Appears in the stats pack Declaration sheet. Use your company or white-label partner name.",
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
      ReferenceLevel = ""
    ),
    list(
      VariableName = "service_quality",
      Type = "Driver",
      Label = "Service Quality",
      DriverType = "continuous",
      ReferenceLevel = ""
    ),
    list(
      VariableName = "value_for_money",
      Type = "Driver",
      Label = "Value for Money",
      DriverType = "continuous",
      ReferenceLevel = ""
    ),
    list(
      VariableName = "ease_of_use",
      Type = "Driver",
      Label = "Ease of Use",
      DriverType = "continuous",
      ReferenceLevel = ""
    ),
    list(
      VariableName = "brand_trust",
      Type = "Driver",
      Label = "Brand Trust",
      DriverType = "categorical",
      ReferenceLevel = "Low"
    ),
    list(
      VariableName = "survey_weight",
      Type = "Weight",
      Label = "Survey Weight",
      DriverType = "",
      ReferenceLevel = ""
    )
  )
}


#' Build CustomSlides sheet column definitions
#'
#' @return List of column definitions
#' @keywords internal
build_custom_slides_columns <- function() {
  list(
    list(
      name = "slide_title",
      width = 34,
      required = TRUE,
      description = "Heading for the slide, shown on the card in the Added Slides tab.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "slide_content",
      width = 60,
      required = TRUE,
      description = "Commentary for the slide. Plain text or markdown. Editable in the report.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "image_path",
      width = 40,
      required = FALSE,
      description = "Optional image for the slide. Relative paths resolve from the config file's folder.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    )
  )
}


#' Build Insights sheet column definitions
#'
#' @return List of column definitions
#' @keywords internal
build_insights_columns <- function() {
  list(
    list(
      name = "section",
      width = 24,
      required = TRUE,
      description = "Report section to pre-fill: exec-summary, importance, method-comparison, effect-sizes, correlations, diagnostics, segment-comparison, shap, quadrant or bootstrap.",
      dropdown = c("exec-summary", "importance", "method-comparison",
                   "effect-sizes", "correlations", "diagnostics",
                   "segment-comparison", "shap", "quadrant", "bootstrap"),
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "insight_text",
      width = 70,
      required = TRUE,
      description = "Commentary to place in that section's insight box. Editable in the report.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
    ),
    list(
      name = "image_path",
      width = 40,
      required = FALSE,
      description = "Optional image for the insight box. Relative paths resolve from the config file's folder.",
      dropdown = NULL,
      integer_range = NULL,
      numeric_range = NULL
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
  # Deliberately empty. A row on this sheet is not an example, it is an
  # instruction: the pipeline reads the sheet and runs a segment comparison on
  # whatever variable it names. An untouched template asked for a comparison
  # on "age_group", a column no real study has (review M12). The shape an
  # analyst needs is in the column descriptions and the sheet subtitle.
  list()
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
  # Deliberately empty, for the same reason as the Segments sheet. Rows here
  # feed the quadrant's dual-importance comparison, and driver names that do
  # not match the Variables sheet are dropped without a word, so an untouched
  # template fed the quadrant five fictional ratings (review M12).
  list()
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
  # SHEET 5: CustomSlides
  # ============================================================
  # The loader has read this sheet since v10.4 and the template has never
  # offered it, so the feature was undiscoverable from the template an analyst
  # actually opens (review M11). No example rows, for the same reason as
  # Segments: a row here is an instruction, not an illustration.
  write_table_sheet(
    wb = wb,
    sheet_name = "CustomSlides",
    columns_def = build_custom_slides_columns(),
    title = "TURAS Key Driver Analysis - Custom Slides",
    subtitle = "Commentary slides written into the report's Added Slides tab (optional). One row per slide.",
    example_rows = NULL,
    num_blank_rows = 15
  )

  # ============================================================
  # SHEET 6: Insights
  # ============================================================
  write_table_sheet(
    wb = wb,
    sheet_name = "Insights",
    columns_def = build_insights_columns(),
    title = "TURAS Key Driver Analysis - Insights",
    subtitle = "Commentary pre-filled into a section's insight box (optional). One row per section.",
    example_rows = NULL,
    num_blank_rows = 15
  )

  # ============================================================
  # SAVE
  # ============================================================
  turas_saveWorkbook(wb, output_path, overwrite = TRUE)

  cat(sprintf("[KeyDriver] Config template saved to: %s\n", output_path))
  cat(sprintf("  Sheets: Settings, Variables, Segments, StatedImportance, CustomSlides, Insights\n"))

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
