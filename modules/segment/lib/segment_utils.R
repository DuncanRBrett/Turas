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


# ==============================================================================
# REPRODUCIBILITY & SEED MANAGEMENT
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
# FEATURE 1: QUICK RUN FUNCTION
# ==============================================================================

#' Run Segmentation Without Excel Config File
#'
#' Convenience function to run segmentation programmatically without needing
#' to create an Excel configuration file. Useful for quick analysis and scripting.
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
#' @return Same structure as turas_segment_from_config()
#' @export
#' @examples
#' # Exploration mode
#' result <- run_segment_quick(
#'   data = survey_data,
#'   id_var = "respondent_id",
#'   clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
#'   k = NULL,  # exploration mode
#'   k_range = 3:6
#' )
#'
#' # Final mode with fixed k
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

  # ===========================================================================
  # VALIDATE INPUTS
  # ===========================================================================

  cat("Validating inputs...\n")

  # Check data is a data frame
  if (!is.data.frame(data)) {
    stop("data must be a data frame", call. = FALSE)
  }

  # Check ID variable exists
  if (!id_var %in% names(data)) {
    stop(sprintf("ID variable '%s' not found in data. Available columns: %s",
                 id_var, paste(head(names(data), 10), collapse = ", ")),
         call. = FALSE)
  }

  # Check clustering variables exist
  missing_vars <- setdiff(clustering_vars, names(data))
  if (length(missing_vars) > 0) {
    stop(sprintf("Clustering variables not found in data: %s",
                 paste(missing_vars, collapse = ", ")),
         call. = FALSE)
  }

  # Check clustering variables are numeric
  for (var in clustering_vars) {
    if (!is.numeric(data[[var]])) {
      stop(sprintf("Clustering variable '%s' must be numeric", var),
           call. = FALSE)
    }
  }

  # Validate k
  if (!is.null(k)) {
    if (!is.numeric(k) || k < 2) {
      stop("k must be an integer >= 2", call. = FALSE)
    }
    k <- as.integer(k)
  }

  cat(sprintf("✓ Input validation passed\n"))
  cat(sprintf("  Respondents: %d\n", nrow(data)))
  cat(sprintf("  Clustering variables: %d\n", length(clustering_vars)))
  cat(sprintf("  Mode: %s\n", if (is.null(k)) "Exploration" else "Final"))
  cat("\n")

  # ===========================================================================
  # BUILD CONFIG LIST
  # ===========================================================================

  config <- list(
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

  # ===========================================================================
  # PREPARE DATA
  # ===========================================================================

  cat("Preparing data...\n")

  # Set seed
  set.seed(seed)
  cat(sprintf("🎲 Seed set: %d\n", seed))

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
    stop(sprintf("Only %d valid rows remaining. Need at least 50.", nrow(data)),
         call. = FALSE)
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
  if (is.null(profile_vars)) {
    all_numeric_vars <- names(data)[sapply(data, is.numeric)]
    profile_vars <- setdiff(all_numeric_vars, c(id_var, clustering_vars))
    if (length(profile_vars) > 0) {
      cat(sprintf("  Auto-detected %d profile variables\n", length(profile_vars)))
    }
    config$profile_vars <- profile_vars
  }

  cat("✓ Data preparation complete\n\n")

  # Build data_list structure
  data_list <- list(
    data = data,
    scaled_data = scaled_data,
    clustering_data = clustering_data,
    config = config,
    scale_params = scale_params,
    imputation_params = NULL,
    n_original = n_original,
    outlier_flags = NULL,
    outlier_result = NULL,
    outlier_handling = NULL
  )

  # ===========================================================================
  # RUN CLUSTERING
  # ===========================================================================

  # Create output folder
  output_folder <- create_output_folder(config$output_folder,
                                         config$create_dated_folder)

  if (is.null(k)) {
    # =========================================================================
    # EXPLORATION MODE
    # =========================================================================

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

    return(invisible(list(
      mode = "exploration",
      recommendation = recommendation,
      metrics = metrics_result,
      models = exploration_result$models,
      output_files = list(report = report_path),
      config = config
    )))

  } else {
    # =========================================================================
    # FINAL MODE
    # =========================================================================

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

    # Create segment profiles
    profile_result <- create_full_segment_profile(
      data = data_list$data,
      clusters = final_result$clusters,
      clustering_vars = config$clustering_vars,
      profile_vars = config$profile_vars
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

    return(invisible(list(
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
    )))
  }
}


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
