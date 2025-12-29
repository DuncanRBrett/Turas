# ==============================================================================
# SEGMENTATION UTILITIES
# ==============================================================================
# Helper functions: config generation, data validation, logging, dependencies
# Part of Turas Segmentation Module
#
# REFACTORED: December 2024
#   - Extracted run_segment_quick() into smaller, testable functions
#   - Integrated shared validation utilities
#   - Improved separation of concerns
#
# CONTENTS:
#   1. Shared Infrastructure (imports)
#   2. Package Dependency Management
#   3. Configuration Template Generation
#   4. Input Data Validation
#   5. Project Initialization
#   6. Seed & RNG Management
#   7. Quick Run Helper Functions (internal)
#   8. Quick Run Main Function (public API)
#
# ==============================================================================


# ==============================================================================
# 1. SHARED INFRASTRUCTURE
# ==============================================================================

# Source shared utilities for validation and data handling
# These provide consistent error handling across all Turas modules

.source_shared_utils <- function() {
  # Determine module root path
  script_dir <- tryCatch({
    if (sys.nframe() > 0) dirname(sys.frame(1)$ofile) else NULL
  }, error = function(e) NULL)

  possible_roots <- c(
    if (!is.null(script_dir)) file.path(script_dir, "../..") else NULL,
    file.path(getwd(), "modules"),
    Sys.getenv("TURAS_HOME", ""),
    Sys.getenv("TURAS_ROOT", getwd())
  )

  for (root in possible_roots) {
    if (is.null(root) || root == "") next
    validation_path <- file.path(root, "shared/lib/validation_utils.R")
    if (file.exists(validation_path)) {
      source(validation_path, local = FALSE)
      return(invisible(TRUE))
    }
  }

  # Fallback: define minimal stubs if shared utils not found
  if (!exists("validate_data_frame", mode = "function")) {
    validate_data_frame <- function(data, ...) invisible(TRUE)
  }
  if (!exists("validate_column_exists", mode = "function")) {
    validate_column_exists <- function(data, col, ...) {
      if (!col %in% names(data)) stop(sprintf("Column '%s' not found", col))
    }
  }
  invisible(FALSE)
}

# Initialize shared utilities on load
.source_shared_utils()


# ==============================================================================
# 2. PACKAGE DEPENDENCY MANAGEMENT
# ==============================================================================
#
# MINIMUM INSTALL (core k-means functionality):
#   - stats      (built-in)  - kmeans clustering
#   - cluster    (CRAN)      - silhouette analysis
#   - readxl     (CRAN)      - read Excel config files
#   - writexl    (CRAN)      - write Excel output files
#
# FULL INSTALL (all features including LCA):
#   - All minimum packages, plus:
#   - poLCA      (CRAN)      - Latent Class Analysis
#   - MASS       (built-in)  - Mahalanobis distance for outliers
#   - rpart      (built-in)  - Decision tree segment rules
#   - psych      (CRAN)      - Factor analysis, reliability
#   - fmsb       (CRAN)      - Radar charts for profiles
#   - ggplot2    (CRAN)      - Enhanced visualizations
#   - randomForest (CRAN)    - Variable importance (optional)
#   - haven      (CRAN)      - SPSS file support (optional)
#
# ==============================================================================

#' Check Segmentation Package Dependencies
#'
#' Validates that required packages are installed and reports on optional
#' packages. Returns a structured list of available/missing packages.
#'
#' @param verbose Logical, print detailed output (default: TRUE)
#' @param install_missing Logical, attempt to install missing required packages (default: FALSE)
#' @return List with available, missing_required, missing_optional, and ready status
#' @export
#' @examples
#' # Check dependencies before running segmentation
#' deps <- check_segment_dependencies()
#' if (!deps$ready) {
#'   cat("Missing required packages:", paste(deps$missing_required, collapse = ", "))
#' }
check_segment_dependencies <- function(verbose = TRUE, install_missing = FALSE) {

  # Define package categories
  required_packages <- list(
    cluster = "Silhouette analysis and cluster validation",
    readxl  = "Read Excel configuration files",
    writexl = "Write Excel output files"
  )

  optional_packages <- list(
    poLCA       = "Latent Class Analysis (alternative to k-means)",
    MASS        = "Mahalanobis distance for outlier detection",
    rpart       = "Decision tree classification rules",
    psych       = "Factor analysis and reliability metrics",
    fmsb        = "Radar charts for segment profiles",
    ggplot2     = "Enhanced visualizations",
    randomForest = "Variable importance analysis",
    haven       = "Read SPSS data files"
  )

  builtin_packages <- c("stats", "MASS", "rpart")

  # Check each package
  check_pkg <- function(pkg) {
    if (pkg %in% builtin_packages) {
      # Built-in packages are always available
      return(TRUE)
    }
    requireNamespace(pkg, quietly = TRUE)
  }

  # Check required packages
  required_status <- sapply(names(required_packages), check_pkg)
  missing_required <- names(required_packages)[!required_status]

  # Check optional packages
  optional_status <- sapply(names(optional_packages), check_pkg)
  available_optional <- names(optional_packages)[optional_status]
  missing_optional <- names(optional_packages)[!optional_status]

  # Overall readiness
  ready <- length(missing_required) == 0

  if (verbose) {
    cat("\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("SEGMENTATION MODULE - PACKAGE DEPENDENCIES\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("\n")

    # Required packages
    cat("REQUIRED PACKAGES:\n")
    for (pkg in names(required_packages)) {
      status <- if (required_status[pkg]) "[OK]" else "[MISSING]"
      cat(sprintf("  %s %-12s - %s\n", status, pkg, required_packages[[pkg]]))
    }

    # Optional packages
    cat("\nOPTIONAL PACKAGES:\n")
    for (pkg in names(optional_packages)) {
      status <- if (optional_status[pkg]) "[OK]" else "[--]"
      cat(sprintf("  %s %-12s - %s\n", status, pkg, optional_packages[[pkg]]))
    }

    # Summary
    cat("\n")
    cat(rep("-", 70), "\n", sep = "")
    if (ready) {
      cat("STATUS: Ready for segmentation (all required packages installed)\n")
      if (length(missing_optional) > 0) {
        cat(sprintf("        %d optional package(s) not installed\n", length(missing_optional)))
      }
    } else {
      cat("STATUS: NOT READY - missing required packages\n")
      cat("\nTo install missing required packages, run:\n")
      cat(sprintf("  install.packages(c(%s))\n",
                  paste(sprintf('"%s"', missing_required), collapse = ", ")))
    }
    cat("\n")

    # Feature availability based on packages
    cat("FEATURE AVAILABILITY:\n")
    cat(sprintf("  K-means clustering:      %s\n", if (ready) "Available" else "Unavailable"))
    cat(sprintf("  Latent Class Analysis:   %s\n",
                if ("poLCA" %in% available_optional) "Available" else "Unavailable (install poLCA)"))
    cat(sprintf("  Mahalanobis outliers:    %s\n",
                if (check_pkg("MASS")) "Available" else "Unavailable"))
    cat(sprintf("  Decision tree rules:     %s\n",
                if (check_pkg("rpart")) "Available" else "Unavailable"))
    cat(sprintf("  Radar charts:            %s\n",
                if ("fmsb" %in% available_optional) "Available" else "Unavailable (install fmsb)"))
    cat(sprintf("  Variable importance:     %s\n",
                if ("randomForest" %in% available_optional) "Available" else "Unavailable (install randomForest)"))
    cat("\n")
  }

  # Attempt installation if requested
  if (install_missing && length(missing_required) > 0) {
    cat("Attempting to install missing required packages...\n")
    for (pkg in missing_required) {
      tryCatch({
        install.packages(pkg, quiet = TRUE)
        cat(sprintf("  Installed: %s\n", pkg))
      }, error = function(e) {
        cat(sprintf("  Failed to install: %s (%s)\n", pkg, e$message))
      })
    }
  }

  return(invisible(list(
    ready = ready,
    available = c(names(required_packages)[required_status], available_optional),
    missing_required = missing_required,
    missing_optional = missing_optional,
    features = list(
      kmeans = ready,
      lca = "poLCA" %in% available_optional,
      outlier_mahalanobis = check_pkg("MASS"),
      decision_rules = check_pkg("rpart"),
      radar_charts = "fmsb" %in% available_optional,
      variable_importance = "randomForest" %in% available_optional
    )
  )))
}


#' Get Minimum Install Command
#'
#' Returns the R command to install only required packages for basic
#' k-means segmentation functionality.
#'
#' @return Character string with install.packages() command
#' @export
get_minimum_install_cmd <- function() {
  cmd <- 'install.packages(c("cluster", "readxl", "writexl"))'
  cat("Minimum install (k-means only):\n")
  cat(paste0("  ", cmd, "\n"))
  invisible(cmd)
}


#' Get Full Install Command
#'
#' Returns the R command to install all packages for full segmentation
#' functionality including LCA and advanced features.
#'
#' @return Character string with install.packages() command
#' @export
get_full_install_cmd <- function() {
  cmd <- 'install.packages(c("cluster", "readxl", "writexl", "poLCA", "psych", "fmsb", "ggplot2", "randomForest", "haven"))'
  cat("Full install (all features):\n")
  cat(paste0("  ", cmd, "\n"))
  invisible(cmd)
}

# ==============================================================================
# 3. CONFIGURATION TEMPLATE GENERATION
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


# ==============================================================================
# 4. INPUT DATA VALIDATION
# ==============================================================================

#' Validate Input Data Quality
#'
#' Performs comprehensive validation of input data before segmentation.
#' This function provides detailed diagnostics for data quality issues.
#'
#' @param data Data frame to validate
#' @param id_variable Name of ID variable
#' @param clustering_vars Character vector of clustering variables
#' @return List with validation results (valid, errors, warnings, issues, n_respondents, n_complete)
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


# ==============================================================================
# 5. PROJECT INITIALIZATION
# ==============================================================================

#' Initialize Segmentation Project
#'
#' Sets up a new segmentation project with folder structure and config template
#'
#' @param project_name Name of the project
#' @param data_file Path to survey data
#' @param base_folder Base folder for project (default: "projects/")
#' @return Invisible list with project_folder and config_file paths
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


# ==============================================================================
# 6. SEED & RNG MANAGEMENT
# ==============================================================================

#' Set Seed for Reproducibility
#'
#' DESIGN: Centralized seed management for all random operations
#' ENSURES: Deterministic results across runs with same config
#'
#' @param config Configuration list with optional seed parameter
#' @return The seed value that was set (either from config or auto-generated)
#' @export
set_segmentation_seed <- function(config) {

  # Determine seed value
  if (!is.null(config$seed) && !is.na(config$seed)) {
    # Use seed from config
    seed_value <- as.integer(config$seed)
    seed_source <- "config"
  } else {
    # Generate seed from timestamp for reproducibility
    # Use date + time to ensure uniqueness across runs
    seed_value <- as.integer(format(Sys.time(), "%Y%m%d%H%M%S")) %% .Machine$integer.max
    seed_source <- "auto-generated"
  }

  # Set the seed
  set.seed(seed_value)

  cat(sprintf("🎲 Seed set: %d (%s)\n", seed_value, seed_source))
  cat(sprintf("   Note: Use this seed in config to reproduce results\n\n"))

  return(seed_value)
}


# ==============================================================================
# 7. QUICK RUN HELPER FUNCTIONS (Internal)
# ==============================================================================
# These functions are extracted from run_segment_quick() for better
# testability, maintainability, and separation of concerns.
# ==============================================================================

#' Validate Quick Run Inputs
#'
#' Internal function to validate inputs for run_segment_quick().
#' Checks data structure, variable existence, and parameter validity.
#'
#' @param data Data frame to validate
#' @param id_var ID variable name
#' @param clustering_vars Character vector of clustering variable names
#' @param k Number of clusters (NULL for exploration mode)
#' @param k_range Range of k values for exploration
#' @return Validated k value (possibly coerced to integer)
#' @keywords internal
.validate_quick_inputs <- function(data, id_var, clustering_vars, k, k_range) {


  # Check data is a data frame
  if (!is.data.frame(data)) {
    segment_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Data Type",
      problem = "Data must be a data frame.",
      why_it_matters = "Segmentation requires a properly structured data frame.",
      how_to_fix = "Ensure data parameter is a data.frame object."
    )
  }

  # Check ID variable exists
  if (!id_var %in% names(data)) {
    segment_refuse(
      code = "CFG_ID_VAR_MISSING",
      title = "ID Variable Not Found",
      problem = sprintf("ID variable '%s' not found in data.", id_var),
      why_it_matters = "An ID variable is required to identify respondents.",
      how_to_fix = c(
        "Check that the ID variable name matches your data exactly",
        sprintf("Available columns: %s", paste(head(names(data), 10), collapse = ", "))
      )
    )
  }

  # Check clustering variables exist
  missing_vars <- setdiff(clustering_vars, names(data))
  if (length(missing_vars) > 0) {
    segment_refuse(
      code = "CFG_CLUSTERING_VARS_MISSING",
      title = "Clustering Variables Not Found",
      problem = sprintf("Clustering variables not found in data: %s",
                        paste(missing_vars, collapse = ", ")),
      why_it_matters = "All specified clustering variables must exist in the data.",
      how_to_fix = "Check that variable names match data column names exactly (case-sensitive)."
    )
  }

  # Check clustering variables are numeric
  for (var in clustering_vars) {
    if (!is.numeric(data[[var]])) {
      segment_refuse(
        code = "DATA_NON_NUMERIC_VAR",
        title = "Non-Numeric Clustering Variable",
        problem = sprintf("Clustering variable '%s' must be numeric but is %s.",
                          var, class(data[[var]])[1]),
        why_it_matters = "K-means clustering requires numeric variables.",
        how_to_fix = sprintf("Convert '%s' to numeric or remove it from clustering_vars.", var)
      )
    }
  }

  # Validate k
  if (!is.null(k)) {
    if (!is.numeric(k) || k < 2) {
      segment_refuse(
        code = "CFG_INVALID_K",
        title = "Invalid Number of Clusters",
        problem = sprintf("k must be an integer >= 2 (received: %s).", as.character(k)),
        why_it_matters = "Clustering requires at least 2 segments.",
        how_to_fix = "Set k to an integer value of 2 or greater."
      )
    }
    return(as.integer(k))
  }

  return(k)
}


#' Build Quick Run Configuration
#'
#' Internal function to build a configuration list from quick run parameters.
#' Creates a config structure compatible with the full segmentation pipeline.
#'
#' @param id_var ID variable name
#' @param clustering_vars Clustering variable names
#' @param k Number of clusters (NULL for exploration)
#' @param k_range Range of k values
#' @param profile_vars Profile variable names
#' @param output_folder Output folder path
#' @param seed Random seed
#' @param question_labels Optional question labels
#' @param standardize Whether to standardize data
#' @param nstart Number of random starts
#' @param outlier_detection Whether to detect outliers
#' @param missing_data Missing data handling method
#' @param segment_names Segment naming method
#' @return Configuration list
#' @keywords internal
.build_quick_config <- function(id_var, clustering_vars, k, k_range,
                                 profile_vars, output_folder, seed,
                                 question_labels, standardize, nstart,
                                 outlier_detection, missing_data,
                                 segment_names) {
  list(
    # Data (not file-based)
    data_file = "[in-memory data]",
    data_sheet = "Data",
    id_variable = id_var,

    # Variables
    clustering_vars = clustering_vars,
    profile_vars = profile_vars,

    # Model
    method = "kmeans",
    k_fixed = k,
    k_min = min(k_range),
    k_max = max(k_range),
    nstart = nstart,
    seed = seed,

    # Data handling
    missing_data = missing_data,
    missing_threshold = 15,
    standardize = standardize,
    min_segment_size_pct = 10,

    # Outlier detection
    outlier_detection = outlier_detection,
    outlier_method = "zscore",
    outlier_threshold = 3.0,
    outlier_min_vars = 1,
    outlier_handling = "flag",
    outlier_alpha = 0.001,

    # Variable selection
    variable_selection = FALSE,
    variable_selection_method = "variance_correlation",
    max_clustering_vars = 10,
    varsel_min_variance = 0.1,
    varsel_max_correlation = 0.8,

    # Validation
    k_selection_metrics = c("silhouette", "elbow"),

    # Output
    output_folder = output_folder,
    output_prefix = "quick_seg_",
    create_dated_folder = TRUE,
    segment_names = segment_names,
    save_model = TRUE,

    # Metadata
    project_name = "Quick Segmentation",
    analyst_name = Sys.getenv("USER"),
    description = "Programmatic segmentation run",

    # Question labels
    question_labels_file = NULL,
    question_labels = question_labels,

    # Mode detection
    mode = if (is.null(k)) "exploration" else "final"
  )
}


#' Prepare Data for Quick Run
#'
#' Internal function to prepare data for clustering. Handles missing data,
#' standardization, and builds the data_list structure.
#'
#' @param data Data frame
#' @param config Configuration list
#' @param seed Random seed
#' @return List with prepared data (data_list structure)
#' @keywords internal
.prepare_quick_data <- function(data, config, seed) {

  cat("Preparing data...\n")

  # Set seed
  set.seed(seed)
  cat(sprintf("🎲 Seed set: %d\n", seed))

  clustering_vars <- config$clustering_vars
  missing_data <- config$missing_data
  standardize <- config$standardize
  id_var <- config$id_variable

  # Handle missing data
  n_original <- nrow(data)
  n_missing <- sum(!complete.cases(data[, clustering_vars]))

  if (n_missing > 0) {
    cat(sprintf("  Missing data: %d rows (%.1f%%)\n",
                n_missing, 100 * n_missing / n_original))

    if (missing_data == "listwise_deletion") {
      complete_rows <- complete.cases(data[, clustering_vars])
      data <- data[complete_rows, ]
      cat(sprintf("  Applied listwise deletion: %d rows retained\n", nrow(data)))
    } else if (missing_data == "mean_imputation") {
      for (var in clustering_vars) {
        na_idx <- is.na(data[[var]])
        if (any(na_idx)) {
          data[[var]][na_idx] <- mean(data[[var]], na.rm = TRUE)
        }
      }
      cat("  Applied mean imputation\n")
    } else if (missing_data == "median_imputation") {
      for (var in clustering_vars) {
        na_idx <- is.na(data[[var]])
        if (any(na_idx)) {
          data[[var]][na_idx] <- median(data[[var]], na.rm = TRUE)
        }
      }
      cat("  Applied median imputation\n")
    }
  }

  if (nrow(data) < 50) {
    segment_refuse(
      code = "DATA_INSUFFICIENT_SAMPLE",
      title = "Insufficient Sample Size",
      problem = sprintf("Only %d valid rows remaining. Need at least 50.", nrow(data)),
      why_it_matters = "Small samples produce unreliable clustering results.",
      how_to_fix = c(
        "Increase sample size",
        "Review missing data handling strategy",
        "Check data quality and filtering"
      )
    )
  }

  # Standardize data
  clustering_data <- data[, clustering_vars, drop = FALSE]

  if (standardize) {
    scaled_data <- scale(clustering_data)
    scale_params <- list(
      center = attr(scaled_data, "scaled:center"),
      scale = attr(scaled_data, "scaled:scale")
    )
    cat("  Data standardized\n")
  } else {
    scaled_data <- as.matrix(clustering_data)
    scale_params <- NULL
  }

  # Auto-detect profile variables if not specified
  profile_vars <- config$profile_vars
  if (is.null(profile_vars)) {
    all_numeric_vars <- names(data)[sapply(data, is.numeric)]
    profile_vars <- setdiff(all_numeric_vars, c(id_var, clustering_vars))
    if (length(profile_vars) > 0) {
      cat(sprintf("  Auto-detected %d profile variables\n", length(profile_vars)))
    }
  }

  cat("✓ Data preparation complete\n\n")

  # Build data_list structure
  list(
    data = data,
    scaled_data = scaled_data,
    clustering_data = clustering_data,
    config = config,
    profile_vars = profile_vars,
    scale_params = scale_params,
    imputation_params = NULL,
    n_original = n_original,
    outlier_flags = NULL,
    outlier_result = NULL,
    outlier_handling = NULL
  )
}


#' Run Quick Exploration Mode
#'
#' Internal function to run exploration mode clustering.
#' Tests multiple k values and recommends optimal k.
#'
#' @param data_list Prepared data list
#' @param config Configuration list
#' @param output_folder Output folder path
#' @param id_var ID variable name (for output message)
#' @return List with exploration results
#' @keywords internal
.run_quick_exploration <- function(data_list, config, output_folder, id_var) {

  k_range <- config$k_min:config$k_max

  cat("EXPLORATION MODE\n")
  cat(rep("-", 40), "\n", sep = "")
  cat(sprintf("Testing k = %d to %d\n\n", min(k_range), max(k_range)))

  # Run clustering for multiple k values
  exploration_result <- run_kmeans_exploration(data_list)

  # Calculate validation metrics
  metrics_result <- calculate_exploration_metrics(exploration_result)

  # Recommend optimal k
  recommendation <- recommend_k(metrics_result$metrics_df,
                                 config$min_segment_size_pct)

  # Export exploration report
  report_filename <- paste0(config$output_prefix, "k_selection_report.xlsx")
  report_path <- file.path(output_folder, report_filename)

  export_exploration_report(
    exploration_result = exploration_result,
    metrics_result = metrics_result,
    recommendation = recommendation,
    output_path = report_path
  )

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("EXPLORATION COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat(sprintf("✓ Recommended k: %d\n", recommendation$recommended_k))
  cat(sprintf("  Output: %s\n", report_path))
  cat(sprintf("\nTo run final segmentation:\n"))
  cat(sprintf("  result <- run_segment_quick(data, \"%s\", clustering_vars, k = %d)\n",
              id_var, recommendation$recommended_k))
  cat("\n")

  list(
    mode = "exploration",
    recommendation = recommendation,
    metrics = metrics_result,
    models = exploration_result$models,
    output_files = list(report = report_path),
    config = config
  )
}


#' Run Quick Final Mode
#'
#' Internal function to run final mode clustering with a fixed k.
#' Creates segments, profiles, and exports results.
#'
#' @param data_list Prepared data list
#' @param config Configuration list
#' @param k Number of clusters
#' @param segment_names Segment naming method or vector
#' @param output_folder Output folder path
#' @param seed Random seed
#' @return List with final segmentation results
#' @keywords internal
.run_quick_final <- function(data_list, config, k, segment_names,
                              output_folder, seed) {

  cat("FINAL MODE\n")
  cat(rep("-", 40), "\n", sep = "")
  cat(sprintf("Running with k = %d\n\n", k))

  # Run clustering with fixed k
  final_result <- run_kmeans_final(data_list)

  # Calculate validation metrics
  validation_metrics <- calculate_validation_metrics(
    data = data_list$scaled_data,
    model = final_result$model,
    k = final_result$k,
    calculate_gap = FALSE
  )

  # Get profile vars from data_list (may have been auto-detected)
  profile_vars <- data_list$profile_vars
  if (is.null(profile_vars)) {
    profile_vars <- config$profile_vars
  }

  # Create segment profiles
  profile_result <- create_full_segment_profile(
    data = data_list$data,
    clusters = final_result$clusters,
    clustering_vars = config$clustering_vars,
    profile_vars = profile_vars
  )

  # Generate segment names
  if (identical(segment_names, "auto")) {
    segment_names_final <- generate_segment_names(final_result$k, method = "simple")
  } else {
    segment_names_final <- segment_names
  }

  # Export segment assignments
  assignments_filename <- paste0(config$output_prefix, "segment_assignments.xlsx")
  assignments_path <- file.path(output_folder, assignments_filename)

  export_segment_assignments(
    data = data_list$data,
    clusters = final_result$clusters,
    segment_names = segment_names_final,
    id_var = config$id_variable,
    output_path = assignments_path,
    outlier_flags = data_list$outlier_flags
  )

  # Export full report
  report_filename <- paste0(config$output_prefix, "segmentation_report.xlsx")
  report_path <- file.path(output_folder, report_filename)

  export_final_report(
    final_result = final_result,
    profile_result = profile_result,
    validation_metrics = validation_metrics,
    output_path = report_path
  )

  # Save model object
  model_filename <- paste0(config$output_prefix, "model.rds")
  model_path <- file.path(output_folder, model_filename)

  segment_dist <- table(final_result$clusters)

  model_object <- list(
    model = final_result$model,
    k = final_result$k,
    clusters = final_result$clusters,
    centers = final_result$model$centers,
    segment_names = segment_names_final,
    clustering_vars = config$clustering_vars,
    id_variable = config$id_variable,
    scale_params = data_list$scale_params,
    imputation_params = NULL,
    original_distribution = segment_dist,
    seed = seed,
    config = config,
    timestamp = Sys.time(),
    date_created = Sys.time(),
    turas_version = "1.0",
    method = "kmeans"
  )

  saveRDS(model_object, model_path)

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("SEGMENTATION COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat(sprintf("✓ Created %d segments\n", final_result$k))
  cat(sprintf("  Silhouette: %.3f\n", validation_metrics$avg_silhouette))
  cat(sprintf("  Assignments: %s\n", assignments_path))
  cat(sprintf("  Report: %s\n", report_path))
  cat(sprintf("  Model: %s\n", model_path))
  cat("\n")

  list(
    mode = "final",
    k = final_result$k,
    model = final_result$model,
    clusters = final_result$clusters,
    segment_names = segment_names_final,
    validation = validation_metrics,
    profiles = profile_result,
    output_files = list(
      assignments = assignments_path,
      report = report_path,
      model = model_path
    ),
    config = config
  )
}


# ==============================================================================
# 8. QUICK RUN MAIN FUNCTION (Public API)
# ==============================================================================

#' Run Segmentation Without Excel Config File
#'
#' Convenience function to run segmentation programmatically without needing
#' to create an Excel configuration file. Useful for quick analysis and scripting.
#'
#' This function orchestrates the segmentation workflow by delegating to
#' specialized helper functions for validation, configuration, data preparation,
#' and execution.
#'
#' @param data Data frame (already loaded)
#' @param id_var Character, ID column name
#' @param clustering_vars Character vector of clustering variable names
#' @param k Integer or NULL. If NULL, runs exploration mode. If integer, runs final mode.
#' @param k_range Integer vector for exploration mode (default: 3:6)
#' @param profile_vars Character vector or NULL (auto-detect if NULL)
#' @param output_folder Character, path for outputs (default: "output/")
#' @param seed Integer, random seed (default: 123)
#' @param question_labels Named vector of question labels or NULL
#' @param standardize Logical, standardize data before clustering (default: TRUE)
#' @param nstart Integer, number of random starts for k-means (default: 50)
#' @param outlier_detection Logical, enable outlier detection (default: FALSE)
#' @param missing_data Character, missing data handling method (default: "listwise_deletion")
#' @param segment_names Character vector of segment names or "auto"
#'
#' @return List with segmentation results. Structure depends on mode:
#'   - Exploration: mode, recommendation, metrics, models, output_files, config
#'   - Final: mode, k, model, clusters, segment_names, validation, profiles, output_files, config
#' @export
#' @examples
#' # Exploration mode - find optimal k
#' result <- run_segment_quick(
#'   data = survey_data,
#'   id_var = "respondent_id",
#'   clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
#'   k = NULL,
#'   k_range = 3:6
#' )
#'
#' # Final mode - run with fixed k
#' result <- run_segment_quick(
#'   data = survey_data,
#'   id_var = "respondent_id",
#'   clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
#'   k = 4
#' )
run_segment_quick <- function(data, id_var, clustering_vars, k = NULL,
                               k_range = 3:6, profile_vars = NULL,
                               output_folder = "output/", seed = 123,
                               question_labels = NULL, standardize = TRUE,
                               nstart = 50, outlier_detection = FALSE,
                               missing_data = "listwise_deletion",
                               segment_names = "auto") {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS QUICK SEGMENTATION\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Step 1: Validate inputs
  cat("Validating inputs...\n")
  k <- .validate_quick_inputs(data, id_var, clustering_vars, k, k_range)
  cat(sprintf("✓ Input validation passed\n"))
  cat(sprintf("  Respondents: %d\n", nrow(data)))
  cat(sprintf("  Clustering variables: %d\n", length(clustering_vars)))
  cat(sprintf("  Mode: %s\n", if (is.null(k)) "Exploration" else "Final"))
  cat("\n")

  # Step 2: Build configuration
  config <- .build_quick_config(
    id_var = id_var,
    clustering_vars = clustering_vars,
    k = k,
    k_range = k_range,
    profile_vars = profile_vars,
    output_folder = output_folder,
    seed = seed,
    question_labels = question_labels,
    standardize = standardize,
    nstart = nstart,
    outlier_detection = outlier_detection,
    missing_data = missing_data,
    segment_names = segment_names
  )

  # Step 3: Prepare data
  data_list <- .prepare_quick_data(data, config, seed)

  # Update config with auto-detected profile vars
  config$profile_vars <- data_list$profile_vars
  data_list$config <- config

  # Step 4: Create output folder
  output_folder_path <- create_output_folder(config$output_folder,
                                              config$create_dated_folder)

  # Step 5: Run appropriate mode
  if (is.null(k)) {
    result <- .run_quick_exploration(data_list, config, output_folder_path, id_var)
  } else {
    result <- .run_quick_final(data_list, config, k, segment_names,
                                output_folder_path, seed)
  }

  return(invisible(result))
}


# ==============================================================================
# 9. RNG STATE UTILITIES
# ==============================================================================

#' Get Current RNG State
#'
#' Captures current random number generator state for later restoration
#'
#' @return The current .Random.seed value
#' @export
get_rng_state <- function() {
  if (exists(".Random.seed", envir = .GlobalEnv)) {
    return(get(".Random.seed", envir = .GlobalEnv))
  } else {
    return(NULL)
  }
}


#' Restore RNG State
#'
#' Restores a previously saved random number generator state
#'
#' @param rng_state The saved RNG state from get_rng_state()
#' @export
restore_rng_state <- function(rng_state) {
  if (!is.null(rng_state)) {
    assign(".Random.seed", rng_state, envir = .GlobalEnv)
  }
}


#' Validate Seed Reproducibility
#'
#' Tests that a given seed produces reproducible results
#'
#' @param seed Seed value to test
#' @param test_data Sample data for testing
#' @param k Number of clusters for testing
#' @return TRUE if reproducible, FALSE otherwise
#' @export
validate_seed_reproducibility <- function(seed, test_data, k = 3) {

  # Run 1
  set.seed(seed)
  result1 <- kmeans(test_data, centers = k, nstart = 10)

  # Run 2 with same seed
  set.seed(seed)
  result2 <- kmeans(test_data, centers = k, nstart = 10)

  # Check if results are identical
  clusters_match <- identical(result1$cluster, result2$cluster)
  centers_match <- all.equal(result1$centers, result2$centers, tolerance = 1e-10)

  if (clusters_match && isTRUE(centers_match)) {
    cat(sprintf("✓ Seed %d produces reproducible results\n", seed))
    return(TRUE)
  } else {
    warning(sprintf("Seed %d does NOT produce reproducible results", seed), call. = FALSE)
    return(FALSE)
  }
}
