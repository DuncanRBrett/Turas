# ==============================================================================
# SEGMENTATION UTILITIES
# ==============================================================================
# Helper functions: config generation, data validation, logging
# Part of Turas Segmentation Module
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
    stop("Data file must be CSV or Excel format", call. = FALSE)
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
      "25",
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


#' Validate Input Data Quality
#'
#' Performs comprehensive validation of input data before segmentation
#'
#' @param data Data frame to validate
#' @param id_variable Name of ID variable
#' @param clustering_vars Character vector of clustering variables
#' @return List with validation results
#' @export
validate_input_data <- function(data, id_variable, clustering_vars) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("DATA QUALITY VALIDATION\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  issues <- list()
  warnings_count <- 0
  errors_count <- 0

  # 1. Check ID variable
  cat("1. Validating ID variable...\n")
  
  if (!id_variable %in% names(data)) {
    issues <- c(issues, sprintf("ERROR: ID variable '%s' not found in data", id_variable))
    errors_count <- errors_count + 1
  } else {
    # Check for duplicates
    n_duplicates <- sum(duplicated(data[[id_variable]]))
    if (n_duplicates > 0) {
      issues <- c(issues, sprintf("ERROR: %d duplicate IDs found", n_duplicates))
      errors_count <- errors_count + 1
    }
    
    # Check for missing IDs
    n_missing_ids <- sum(is.na(data[[id_variable]]))
    if (n_missing_ids > 0) {
      issues <- c(issues, sprintf("ERROR: %d missing IDs", n_missing_ids))
      errors_count <- errors_count + 1
    }
  }

  # 2. Check clustering variables
  cat("2. Validating clustering variables...\n")
  
  missing_vars <- setdiff(clustering_vars, names(data))
  if (length(missing_vars) > 0) {
    issues <- c(issues, sprintf("ERROR: Missing clustering variables: %s",
                               paste(missing_vars, collapse = ", ")))
    errors_count <- errors_count + 1
  }

  # 3. Check data types
  cat("3. Checking variable types...\n")
  
  for (var in intersect(clustering_vars, names(data))) {
    if (!is.numeric(data[[var]])) {
      issues <- c(issues, sprintf("ERROR: Variable '%s' is not numeric", var))
      errors_count <- errors_count + 1
    }
  }

  # 4. Check missing data
  cat("4. Analyzing missing data patterns...\n")
  
  for (var in intersect(clustering_vars, names(data))) {
    n_missing <- sum(is.na(data[[var]]))
    pct_missing <- 100 * n_missing / nrow(data)
    
    if (pct_missing > 50) {
      issues <- c(issues, sprintf("ERROR: Variable '%s' has %.1f%% missing data",
                                 var, pct_missing))
      errors_count <- errors_count + 1
    } else if (pct_missing > 20) {
      issues <- c(issues, sprintf("WARNING: Variable '%s' has %.1f%% missing data",
                                 var, pct_missing))
      warnings_count <- warnings_count + 1
    }
  }

  # 5. Check variance
  cat("5. Checking variable variance...\n")
  
  for (var in intersect(clustering_vars, names(data))) {
    var_data <- data[[var]][!is.na(data[[var]])]
    if (length(var_data) > 0) {
      var_variance <- var(var_data)
      if (var_variance == 0) {
        issues <- c(issues, sprintf("ERROR: Variable '%s' has zero variance (constant)",
                                   var))
        errors_count <- errors_count + 1
      } else if (var_variance < 0.01) {
        issues <- c(issues, sprintf("WARNING: Variable '%s' has very low variance (%.4f)",
                                   var, var_variance))
        warnings_count <- warnings_count + 1
      }
    }
  }

  # 6. Check sample size
  cat("6. Checking sample size...\n")
  
  n_complete <- sum(complete.cases(data[, intersect(clustering_vars, names(data))]))
  
  if (n_complete < 100) {
    issues <- c(issues, sprintf("WARNING: Only %d complete cases (recommend 100+)",
                               n_complete))
    warnings_count <- warnings_count + 1
  }

  # Summary
  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("VALIDATION SUMMARY\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  if (length(issues) == 0) {
    cat("✓ All validation checks passed!\n")
    cat(sprintf("  Total respondents: %d\n", nrow(data)))
    cat(sprintf("  Complete cases: %d\n", n_complete))
    cat(sprintf("  Clustering variables: %d\n", length(clustering_vars)))
  } else {
    cat(sprintf("Found %d issue(s):\n", length(issues)))
    cat(sprintf("  Errors: %d\n", errors_count))
    cat(sprintf("  Warnings: %d\n", warnings_count))
    cat("\n")
    
    for (issue in issues) {
      cat(paste0("  ", issue, "\n"))
    }
  }

  cat("\n")

  return(list(
    valid = errors_count == 0,
    errors = errors_count,
    warnings = warnings_count,
    issues = issues,
    n_respondents = nrow(data),
    n_complete = n_complete
  ))
}


#' Initialize Segmentation Project
#'
#' Sets up a new segmentation project with folder structure and config template
#'
#' @param project_name Name of the project
#' @param data_file Path to survey data
#' @param base_folder Base folder for project (default: "projects/")
#' @export
initialize_segmentation_project <- function(project_name, data_file, 
                                            base_folder = "projects/") {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("INITIALIZING SEGMENTATION PROJECT\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Create project folder structure
  project_folder <- file.path(base_folder, project_name)
  
  folders <- c(
    project_folder,
    file.path(project_folder, "config"),
    file.path(project_folder, "output"),
    file.path(project_folder, "data"),
    file.path(project_folder, "reports")
  )

  for (folder in folders) {
    if (!dir.exists(folder)) {
      dir.create(folder, recursive = TRUE)
      cat(sprintf("Created: %s\n", folder))
    }
  }

  # Generate config template
  config_file <- file.path(project_folder, "config", "segmentation_config.xlsx")
  generate_config_template(data_file, config_file, mode = "exploration")

  # Create README
  readme_file <- file.path(project_folder, "README.txt")
  readme_content <- sprintf("
SEGMENTATION PROJECT: %s
Created: %s

FOLDER STRUCTURE:
  config/   - Configuration files
  output/   - Segmentation results
  data/     - Input data files
  reports/  - Final reports and visualizations

NEXT STEPS:
  1. Edit config/segmentation_config.xlsx
  2. Fill in required fields (id_variable, clustering_vars)
  3. Run segmentation using Turas launcher
  4. Review results in output/ folder

DATA FILE:
  %s
", project_name, Sys.time(), data_file)

  writeLines(readme_content, readme_file)

  cat(sprintf("\n✓ Project initialized: %s\n", project_folder))
  cat("\nNext steps:\n")
  cat(sprintf("  1. Edit %s\n", config_file))
  cat("  2. Fill in required configuration fields\n")
  cat("  3. Run segmentation\n\n")

  return(invisible(list(
    project_folder = project_folder,
    config_file = config_file
  )))
}
