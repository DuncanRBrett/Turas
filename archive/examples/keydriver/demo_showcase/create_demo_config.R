# ==============================================================================
# KEYDRIVER DEMO - CONFIG FILE GENERATOR
# ==============================================================================
#
# Creates the demo configuration Excel file with all required sheets:
#   - Settings: Analysis parameters and feature toggles
#   - Variables: Variable definitions with DriverType declarations
#   - Segments: Customer segment definitions
#   - StatedImportance: Stated importance values for quadrant analysis
#
# Usage:
#   source("examples/keydriver/demo_showcase/create_demo_config.R")
#
# ==============================================================================

create_demo_config <- function(output_path = NULL) {

  if (is.null(output_path)) {
    output_path <- file.path(dirname(sys.frame(1)$ofile %||% "."),
                              "Demo_KeyDriver_Config.xlsx")
  }

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx package is required. Install with: install.packages('openxlsx')")
  }

  wb <- openxlsx::createWorkbook()

  # ------------------------------------------------------------------
  # Header style
  # ------------------------------------------------------------------
  header_style <- openxlsx::createStyle(
    fontSize = 11, fontColour = "#FFFFFF", fgFill = "#4472C4",
    halign = "left", valign = "center", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )

  # ------------------------------------------------------------------
  # Sheet 1: Settings
  # ------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Settings")

  settings <- data.frame(
    Setting = c(
      "data_file",
      "output_file",
      "enable_shap",
      "enable_quadrant",
      "shap_on_fail",
      "quadrant_on_fail",
      "enable_bootstrap",
      "bootstrap_iterations",
      "bootstrap_ci_level",
      "shap_model",
      "n_trees",
      "max_depth",
      "learning_rate",
      "shap_sample_size",
      "include_interactions",
      "interaction_top_n",
      "importance_source",
      "threshold_method",
      "normalize_axes",
      "shade_quadrants",
      "label_all_points",
      "enable_html_report",
      # HTML report section visibility
      "html_show_exec_summary",
      "html_show_importance",
      "html_show_methods",
      "html_show_effect_sizes",
      "html_show_correlations",
      "html_show_quadrant",
      "html_show_shap",
      "html_show_diagnostics",
      "html_show_bootstrap",
      "html_show_segments",
      "html_show_guide",
      # HTML report display options
      "correlation_display",
      "bootstrap_display",
      # v10.4 features
      "enable_elastic_net",
      "elastic_net_alpha",
      "elastic_net_nfolds",
      "enable_nca",
      "enable_dominance",
      "enable_gam",
      "gam_k",
      # Configurable thresholds
      "vif_moderate_threshold",
      "vif_high_threshold"
    ),
    Value = c(
      "demo_survey_data.csv",
      "Demo_KeyDriver_Results.xlsx",
      "TRUE",
      "TRUE",
      "continue_with_flag",
      "continue_with_flag",
      "TRUE",
      "500",
      "0.95",
      "xgboost",
      "100",
      "6",
      "0.1",
      "500",
      "TRUE",
      "5",
      "auto",
      "mean",
      "TRUE",
      "TRUE",
      "TRUE",
      "TRUE",
      # Section visibility defaults
      "TRUE",   # exec_summary
      "TRUE",   # importance
      "TRUE",   # methods
      "TRUE",   # effect_sizes
      "TRUE",   # correlations
      "TRUE",   # quadrant
      "TRUE",   # shap
      "TRUE",   # diagnostics
      "TRUE",   # bootstrap
      "TRUE",   # segments
      "TRUE",   # guide
      # Display modes
      "heatmap",   # correlation_display
      "summary",   # bootstrap_display
      # v10.4 features
      "TRUE",      # enable_elastic_net
      "0.5",       # elastic_net_alpha (0=ridge, 0.5=elastic net, 1=lasso)
      "10",        # elastic_net_nfolds
      "TRUE",      # enable_nca
      "TRUE",      # enable_dominance
      "TRUE",      # enable_gam
      "5",         # gam_k (basis dimension)
      # Configurable thresholds
      "5",         # vif_moderate_threshold
      "10"         # vif_high_threshold
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Settings", settings, startRow = 1)
  openxlsx::addStyle(wb, "Settings", header_style, rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Settings", cols = 1:2, widths = c(25, 35))

  # ------------------------------------------------------------------
  # Sheet 2: Variables
  # ------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Variables")

  variables <- data.frame(
    VariableName = c(
      "overall_satisfaction",
      "network_reliability",
      "customer_service",
      "value_for_money",
      "data_speed",
      "billing_clarity",
      "coverage_area",
      "app_experience",
      "contract_flexibility",
      "weight"
    ),
    Type = c(
      "Outcome",
      "Driver", "Driver", "Driver", "Driver",
      "Driver", "Driver", "Driver", "Driver",
      "Weight"
    ),
    Label = c(
      "Overall Satisfaction",
      "Network Reliability",
      "Customer Service",
      "Value for Money",
      "Data Speed",
      "Billing Clarity",
      "Coverage Area",
      "App Experience",
      "Contract Flexibility",
      "Survey Weight"
    ),
    DriverType = c(
      NA,
      "continuous", "continuous", "continuous", "continuous",
      "continuous", "continuous", "continuous", "continuous",
      NA
    ),
    AggregationMethod = rep(NA, 10),
    ReferenceLevel = rep(NA, 10),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Variables", variables, startRow = 1)
  openxlsx::addStyle(wb, "Variables", header_style, rows = 1,
                     cols = 1:ncol(variables), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Variables", cols = 1:ncol(variables), widths = "auto")

  # ------------------------------------------------------------------
  # Sheet 3: Segments
  # ------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Segments")

  segments <- data.frame(
    segment_name = c("Business", "Residential", "Premium"),
    segment_variable = rep("customer_type", 3),
    segment_values = c("Business", "Residential", "Premium"),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Segments", segments, startRow = 1)
  openxlsx::addStyle(wb, "Segments", header_style, rows = 1, cols = 1:3, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Segments", cols = 1:3, widths = "auto")

  # ------------------------------------------------------------------
  # Sheet 4: StatedImportance
  # ------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "StatedImportance")

  stated <- data.frame(
    driver = c("network_reliability", "customer_service", "value_for_money",
               "data_speed", "billing_clarity", "coverage_area",
               "app_experience", "contract_flexibility"),
    stated_importance = c(9.2, 8.5, 8.8, 7.5, 6.2, 7.8, 5.5, 4.8),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "StatedImportance", stated, startRow = 1)
  openxlsx::addStyle(wb, "StatedImportance", header_style, rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::setColWidths(wb, "StatedImportance", cols = 1:2, widths = "auto")

  # ------------------------------------------------------------------
  # Sheet 5: CustomSlides (v10.4)
  # ------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "CustomSlides")

  custom_slides <- data.frame(
    slide_title = c(
      "Research Context",
      "Methodology Note"
    ),
    slide_content = c(
      paste0(
        "## Telecom Customer Satisfaction Study\n\n",
        "This key driver analysis examines what drives **overall satisfaction** ",
        "across 800 respondents in three customer segments.\n\n",
        "The study uses 8 service attributes rated on a 1-10 scale."
      ),
      paste0(
        "## Statistical Methodology\n\n",
        "Five complementary methods are used:\n\n",
        "- **Shapley Values** - game-theoretic R-squared decomposition\n",
        "- **Relative Weights** - handles multicollinearity\n",
        "- **Beta Weights** - standardized regression coefficients\n",
        "- **Elastic Net** - penalized variable selection\n",
        "- **GAM** - nonlinear effect detection"
      )
    ),
    slide_image = c(NA, NA),
    slide_order = c(1, 2),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "CustomSlides", custom_slides, startRow = 1)
  openxlsx::addStyle(wb, "CustomSlides", header_style, rows = 1,
                     cols = 1:ncol(custom_slides), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "CustomSlides", cols = 1:ncol(custom_slides), widths = c(20, 50, 20, 12))

  # Sheet 6: Insights (v10.4)
  # Pre-populated analyst insights that appear in the HTML report
  openxlsx::addWorksheet(wb, "Insights")
  insights_df <- data.frame(
    section = c("exec-summary", "importance", "quadrant"),
    insight_text = c(
      "Customer service and product quality are the two strongest drivers of overall satisfaction, together explaining over 40% of the variance. These should be the primary focus of improvement efforts.",
      "The derived importance ranking from Shapley decomposition shows a clear tier structure: the top 3 drivers account for the majority of explained variance, while the bottom 3 contribute marginally.",
      "Three drivers fall in the 'Invest' quadrant (high importance, low performance): Customer Service, Digital Experience, and Communication Quality. These represent the highest-ROI improvement opportunities."
    ),
    image_path = c(NA_character_, NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Insights", insights_df, startRow = 1)
  openxlsx::addStyle(wb, "Insights", header_style, rows = 1,
                     cols = 1:ncol(insights_df), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Insights", cols = 1:ncol(insights_df), widths = c(20, 60, 20))

  # ------------------------------------------------------------------
  # Save
  # ------------------------------------------------------------------
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  cat(sprintf("Config file saved: %s\n", output_path))

  output_path
}

# Run if sourced directly
if (sys.nframe() == 0 || identical(environment(), globalenv())) {
  create_demo_config()
}
