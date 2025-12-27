# ==============================================================================
# SEGMENTATION UTILITIES - QUICK RUN FUNCTION
# ==============================================================================
# Purpose: Programmatic segmentation execution without config files
# Part of: Turas Segmentation Module
# Version: 1.1.0 (Refactored for maintainability)
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
      problem = sprintf("Clustering variables not found in data: %s", paste(missing_vars, collapse = ", ")),
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
        problem = sprintf("Clustering variable '%s' must be numeric but is %s.", var, class(data[[var]])[1]),
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
