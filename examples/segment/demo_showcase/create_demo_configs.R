# ==============================================================================
# TURAS SEGMENTATION DEMO - CREATE CONFIGURATION FILES
# ==============================================================================
# Generates 4 Excel config files for the segmentation demo, showcasing
# different clustering methods and modes:
#
#   1. demo_kmeans_explore.xlsx  - K-means exploration (k = 3 to 6)
#   2. demo_kmeans_final.xlsx    - K-means final solution (k = 4)
#   3. demo_hclust_final.xlsx    - Hierarchical clustering final (k = 4)
#   4. demo_gmm_final.xlsx       - Gaussian Mixture Model final (k = 4)
#
# Each config file has a "Config" sheet with "Setting" and "Value" columns,
# matching the format expected by the Turas segment module.
#
# Usage:
#   source("create_demo_configs.R")
#   # Creates 4 .xlsx files in the same directory
#
# Requires: openxlsx
# Version: 1.0
# ==============================================================================

cat("==============================================================\n")
cat("  TURAS Demo Config Generator - Segmentation Module\n")
cat("==============================================================\n\n")

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')")
}

library(openxlsx)

# --------------------------------------------------------------------------
# Determine script directory for output
# --------------------------------------------------------------------------

script_dir <- tryCatch({
  # Works when called via source()
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  # Fallback: try commandArgs for Rscript execution
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1])))
  } else {
    getwd()
  }
})

cat(sprintf("Output directory: %s\n\n", script_dir))

# --------------------------------------------------------------------------
# Shared Variable Lists
# --------------------------------------------------------------------------

clustering_vars <- paste(
  "overall_satisfaction",
  "service_quality",
  "value_for_money",
  "brand_trust",
  "digital_experience",
  "customer_support",
  "product_range",
  "innovation_perception",
  "ease_of_use",
  "recommendation_likelihood",
  "loyalty_intent",
  "price_sensitivity",
  sep = ","
)

profile_vars <- paste(
  "age_group",
  "gender",
  "region",
  "tenure_years",
  "income_bracket",
  "purchase_frequency",
  "channel_preference",
  "nps_score",
  sep = ","
)


# --------------------------------------------------------------------------
# Helper: Build Config Data Frame
# --------------------------------------------------------------------------
# Creates a two-column data frame (Setting, Value) from a named list.
# Skips NULL entries.

build_config_df <- function(settings) {
  settings <- settings[!sapply(settings, is.null)]
  data.frame(
    Setting = names(settings),
    Value = as.character(unlist(settings)),
    stringsAsFactors = FALSE
  )
}


# --------------------------------------------------------------------------
# Helper: Write Config Workbook
# --------------------------------------------------------------------------
# Creates an Excel workbook with a "Config" sheet, applies basic formatting.

write_config_workbook <- function(config_df, output_path) {
  wb <- createWorkbook()
  addWorksheet(wb, "Config")

  # Branded header style (Turas navy with gold accent border)
  header_style <- createStyle(
    fontName = "Aptos",
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#323367",
    fontColour = "#FFFFFF",
    halign = "left",
    valign = "center",
    border = "Bottom",
    borderColour = "#CC9900",
    borderStyle = "medium",
    wrapText = TRUE
  )

  # Setting name style (left-aligned, medium weight)
  setting_style <- createStyle(
    fontName = "Aptos",
    fontSize = 11,
    halign = "left",
    valign = "center",
    textDecoration = "bold"
  )

  # Value style (left-aligned)
  value_style <- createStyle(
    fontName = "Aptos",
    fontSize = 11,
    halign = "left",
    valign = "center"
  )

  # Alternating row style
  alt_row_style <- createStyle(
    fontName = "Aptos",
    fontSize = 11,
    fgFill = "#F5F7FA",
    halign = "left",
    valign = "center"
  )

  # Write data
  writeData(wb, "Config", config_df, headerStyle = header_style)

  # Apply styles row by row
  for (i in seq_len(nrow(config_df))) {
    row <- i + 1  # +1 for header
    addStyle(wb, "Config", setting_style, rows = row, cols = 1)
    if (i %% 2 == 0) {
      addStyle(wb, "Config", alt_row_style, rows = row, cols = 1:2, gridExpand = TRUE, stack = TRUE)
    } else {
      addStyle(wb, "Config", value_style, rows = row, cols = 2)
    }
  }

  # Set column widths
  setColWidths(wb, "Config", cols = 1, widths = 30)
  setColWidths(wb, "Config", cols = 2, widths = 80)

  # Freeze header
  freezePane(wb, "Config", firstRow = TRUE)

  # Save
  saveWorkbook(wb, output_path, overwrite = TRUE)
  cat(sprintf("  Created: %s (%d settings)\n", basename(output_path), nrow(config_df)))
}


# --------------------------------------------------------------------------
# Common Settings (shared across all configs)
# --------------------------------------------------------------------------
# Returns a named list of settings common to all demo configs.

common_settings <- function() {
  list(
    data_file          = "demo_customer_data.csv",
    id_variable        = "id",
    clustering_vars    = clustering_vars,
    profile_vars       = profile_vars,
    # Data handling
    missing_data       = "median_imputation",
    missing_threshold  = "30",
    standardize        = "TRUE",
    # Outlier detection
    outlier_detection  = "TRUE",
    outlier_method     = "mahalanobis",
    outlier_handling   = "flag",
    # Variable selection
    variable_selection = "FALSE",
    # Output
    output_folder      = "output",
    create_dated_folder = "FALSE",
    # Segment naming and features
    segment_names      = "auto",
    auto_name_style    = "descriptive",
    generate_rules     = "TRUE",
    generate_action_cards = "TRUE",
    run_stability_check = "FALSE",
    scale_max          = "10",
    save_model         = "TRUE",
    # HTML report
    html_report        = "TRUE",
    brand_colour       = "#323367",
    accent_colour      = "#CC9900",
    # Metadata
    project_name       = "Telecom Customer Segmentation Demo",
    analyst_name       = "Turas Analytics",
    description        = "Sales demo: 800-respondent synthetic telecom/retail customer dataset"
  )
}


# ==========================================================================
# CONFIG 1: K-means Exploration (k = 3 to 6)
# ==========================================================================

cat("Generating config files...\n")

config1 <- common_settings()
config1$mode           <- NULL
config1$method         <- "kmeans"
config1$k_min          <- "3"
config1$k_max          <- "6"
config1$k_fixed        <- NULL
config1$nstart         <- "50"
config1$seed           <- "123"
config1$output_prefix  <- "demo_kmeans_explore_"
config1$report_title   <- "Customer Segmentation - K Selection"
# Exploration does not need fixed segment names
config1$segment_names  <- "auto"
# Rules/cards not applicable in exploration mode
config1$generate_rules <- "FALSE"
config1$generate_action_cards <- "FALSE"

config1_df <- build_config_df(config1)
write_config_workbook(config1_df,
  file.path(script_dir, "demo_kmeans_explore.xlsx"))


# ==========================================================================
# CONFIG 2: K-means Final (k = 4)
# ==========================================================================

config2 <- common_settings()
config2$method         <- "kmeans"
config2$k_fixed        <- "4"
config2$nstart         <- "50"
config2$seed           <- "123"
config2$output_prefix  <- "demo_kmeans_final_"
config2$report_title   <- "Customer Segmentation Analysis"

config2_df <- build_config_df(config2)
write_config_workbook(config2_df,
  file.path(script_dir, "demo_kmeans_final.xlsx"))


# ==========================================================================
# CONFIG 3: Hierarchical Clustering Final (k = 4)
# ==========================================================================

config3 <- common_settings()
config3$method         <- "hclust"
config3$k_fixed        <- "4"
config3$linkage_method <- "ward.D2"
config3$seed           <- "123"
config3$output_prefix  <- "demo_hclust_final_"
config3$report_title   <- "Customer Segmentation (Hierarchical)"

config3_df <- build_config_df(config3)
write_config_workbook(config3_df,
  file.path(script_dir, "demo_hclust_final.xlsx"))


# ==========================================================================
# CONFIG 4: GMM Final (k = 4)
# ==========================================================================

config4 <- common_settings()
config4$method         <- "gmm"
config4$k_fixed        <- "4"
config4$gmm_model_type <- "VVV"
config4$seed           <- "123"
config4$output_prefix  <- "demo_gmm_final_"
config4$report_title   <- "Customer Segmentation (GMM)"

config4_df <- build_config_df(config4)
write_config_workbook(config4_df,
  file.path(script_dir, "demo_gmm_final.xlsx"))


# ==========================================================================
# CONFIG 5: Combined Multi-Method Comparison
# ==========================================================================
# Runs K-means, Hierarchical, and GMM simultaneously and produces
# a side-by-side comparison report. Useful for method validation.

config5 <- common_settings()
config5$method         <- "kmeans,hclust,gmm"
config5$k_fixed        <- "4"
config5$nstart         <- "50"
config5$linkage_method <- "ward.D2"
config5$gmm_model_type <- "VVV"
config5$seed           <- "123"
config5$output_prefix  <- "demo_combined_"
config5$report_title   <- "Customer Segmentation - Multi-Method Comparison"

config5_df <- build_config_df(config5)
write_config_workbook(config5_df,
  file.path(script_dir, "demo_combined_config.xlsx"))


# ==========================================================================
# Summary
# ==========================================================================

cat("\n==============================================================\n")
cat("  Config generation complete. 5 files created:\n")
cat("  1. demo_kmeans_explore.xlsx   (exploration, k=3-6)\n")
cat("  2. demo_kmeans_final.xlsx     (k-means, k=4)\n")
cat("  3. demo_hclust_final.xlsx     (hierarchical, k=4)\n")
cat("  4. demo_gmm_final.xlsx        (GMM, k=4)\n")
cat("  5. demo_combined_config.xlsx  (multi-method comparison, k=4)\n")
cat("==============================================================\n")
