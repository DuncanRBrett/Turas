# ==============================================================================
# SEGMENTATION UTILITIES - CONFIGURATION TEMPLATES
# ==============================================================================
# Purpose: Configuration file template generation for segmentation projects
# Part of: Turas Segmentation Module
# Version: 1.1.0 (Refactored for maintainability)
# ==============================================================================

#' Generate Configuration Template
#'
#' Creates a template configuration Excel file for a new segmentation project
#'
#' @param data_file Path to survey data file
#' @param output_file Path to save config template
#' @param mode "exploration" or "final"
#' @export
generate_config_template <- function(data_file, output_file, mode = "exploration") {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("GENERATING CONFIGURATION TEMPLATE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Read data to detect variables
  if (grepl("\\.csv$", data_file, ignore.case = TRUE)) {
    data <- read.csv(data_file, nrows = 5)
  } else if (grepl("\\.(xlsx|xls)$", data_file, ignore.case = TRUE)) {
    data <- readxl::read_excel(data_file, n_max = 5)
  } else {
    segment_refuse(
      code = "IO_INVALID_FILE_FORMAT",
      title = "Invalid Data File Format",
      problem = "Data file must be CSV or Excel format.",
      why_it_matters = "The module can only read CSV (.csv) or Excel (.xlsx, .xls) files.",
      how_to_fix = "Convert your data to CSV or Excel format and try again."
    )
  }

  var_names <- names(data)

  cat(sprintf("Detected %d variables in data file\n", length(var_names)))
  cat("Sample variables:", paste(head(var_names, 10), collapse = ", "), "\n\n")

  # Create config template
  config_df <- data.frame(
    Setting = c(
      # Data source
      "data_file",
      "data_sheet",
      "id_variable",
      "",
      # Variables (user must fill in)
      "clustering_vars",
      "profile_vars",
      "question_labels_file",
      "",
      # Model configuration
      "method",
      "k_fixed",
      "k_min",
      "k_max",
      "nstart",
      "seed",
      "",
      # Data handling
      "missing_data",
      "missing_threshold",
      "standardize",
      "min_segment_size_pct",
      "",
      # Outlier detection
      "outlier_detection",
      "outlier_method",
      "outlier_threshold",
      "outlier_min_vars",
      "outlier_handling",
      "outlier_alpha",
      "",
      # Variable selection
      "variable_selection",
      "variable_selection_method",
      "max_clustering_vars",
      "varsel_min_variance",
      "varsel_max_correlation",
      "",
      # Validation
      "k_selection_metrics",
      "",
      # Output
      "output_folder",
      "output_prefix",
      "create_dated_folder",
      "segment_names",
      "save_model",
      "",
      # Metadata
      "project_name",
      "analyst_name",
      "description"
    ),
    Value = c(
      # Data source
      data_file,
      "Data",
      "FILL_IN_ID_VARIABLE",
      "",
      # Variables
      "FILL_IN_CLUSTERING_VARS",
      "",
      "",
      "",
      # Model
      "kmeans",
      if (mode == "exploration") "" else "4",
      "3",
      "6",
      "50",
      "123",
      "",
      # Data handling
      "listwise_deletion",
      "15",
      "TRUE",
      "10",
      "",
      # Outlier detection
      "FALSE",
      "zscore",
      "3.0",
      "1",
      "flag",
      "0.001",
      "",
      # Variable selection
      "FALSE",
      "variance_correlation",
      "10",
      "0.1",
      "0.8",
      "",
      # Validation
      "silhouette,elbow",
      "",
      # Output
      "output/segmentation/",
      "seg_",
      "TRUE",
      "auto",
      "TRUE",
      "",
      # Metadata
      "My Segmentation Project",
      Sys.getenv("USER"),
      "Description of the segmentation project"
    ),
    stringsAsFactors = FALSE
  )

  # Write to Excel
  writexl::write_xlsx(list(Config = config_df), output_file)

  cat(sprintf("✓ Config template saved to: %s\n", output_file))
  cat("\nIMPORTANT: Edit the following required fields:\n")
  cat("  - id_variable: Name of respondent ID column\n")
  cat("  - clustering_vars: Comma-separated list of clustering variables\n")
  cat("  - Review all other settings and adjust as needed\n\n")

  return(invisible(output_file))
}
