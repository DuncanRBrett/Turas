# ==============================================================================
# TURAS SEGMENTATION MODULE - MAIN ENTRY POINT
# ==============================================================================
# K-means clustering segmentation for survey data
# Part of Turas Analytics Platform
#
# VERSION: Turas v10.0
# DATE: 2025-11-13
# ==============================================================================

# ==============================================================================
# LOAD DEPENDENCIES
# ==============================================================================

# Get Turas root directory
turas_root <- Sys.getenv("TURAS_ROOT", getwd())

# Shared utilities - use absolute paths
source(file.path(turas_root, "modules/shared/lib/validation_utils.R"))
source(file.path(turas_root, "modules/shared/lib/config_utils.R"))
source(file.path(turas_root, "modules/shared/lib/data_utils.R"))
source(file.path(turas_root, "modules/shared/lib/logging_utils.R"))

# Segmentation modules - use absolute paths
source(file.path(turas_root, "modules/segment/lib/segment_utils.R"))
source(file.path(turas_root, "modules/segment/lib/segment_config.R"))
source(file.path(turas_root, "modules/segment/lib/segment_data_prep.R"))
source(file.path(turas_root, "modules/segment/lib/segment_kmeans.R"))
source(file.path(turas_root, "modules/segment/lib/segment_validation.R"))
source(file.path(turas_root, "modules/segment/lib/segment_profile.R"))
source(file.path(turas_root, "modules/segment/lib/segment_export.R"))
source(file.path(turas_root, "modules/segment/lib/segment_outliers.R"))

# Enhanced features (v10.1)
source(file.path(turas_root, "modules/segment/lib/segment_profiling_enhanced.R"))
source(file.path(turas_root, "modules/segment/lib/segment_scoring.R"))
source(file.path(turas_root, "modules/segment/lib/segment_rules.R"))
source(file.path(turas_root, "modules/segment/lib/segment_cards.R"))
source(file.path(turas_root, "modules/segment/lib/segment_lca.R"))

# ==============================================================================
# MAIN SEGMENTATION FUNCTION
# ==============================================================================

#' Run segmentation analysis from configuration file
#'
#' DESIGN: Main orchestrator function
#' MODES: Automatically detects exploration vs final based on k_fixed
#' OUTPUTS: Excel files with results
#'
#' @param config_file Character, path to segmentation config Excel file
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return List with segmentation results
#' @export
#' @examples
#' # Exploration mode
#' result <- turas_segment_from_config("segment_config.xlsx")
#'
#' # Final run mode (after setting k_fixed in config)
#' result <- turas_segment_from_config("segment_config.xlsx")
turas_segment_from_config <- function(config_file, verbose = TRUE) {
  # Start timer
  start_time <- Sys.time()

  # ===========================================================================
  # HEADER
  # ===========================================================================

  print_toolkit_header("Segmentation Analysis", version = "10.0")

  cat(sprintf("Configuration file: %s\n", basename(config_file)))
  cat(sprintf("Start time: %s\n", format(start_time, "%Y-%m-%d %H:%M:%S")))
  cat("\n")

  # ===========================================================================
  # PHASE 1: CONFIGURATION & DATA LOADING
  # ===========================================================================

  cat("PHASE 1: CONFIGURATION & DATA PREPARATION\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  # Read and validate configuration
  config_raw <- read_segment_config(config_file)
  config <- validate_segment_config(config_raw)

  # Set seed for reproducibility
  seed_used <- set_segmentation_seed(config)

  # Prepare data
  data_list <- prepare_segment_data(config)

  # ===========================================================================
  # PHASE 2: CLUSTERING
  # ===========================================================================

  cat("\n")
  cat("PHASE 2: CLUSTERING\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")

  if (config$mode == "exploration") {
    # =========================================================================
    # EXPLORATION MODE
    # =========================================================================

    cat("\nMode: EXPLORATION (k_fixed not specified)\n")

    # Run clustering for multiple k values
    exploration_result <- run_kmeans_exploration(data_list)

    # Calculate validation metrics
    metrics_result <- calculate_exploration_metrics(exploration_result)

    # Recommend optimal k
    recommendation <- recommend_k(metrics_result$metrics_df,
                                   config$min_segment_size_pct)

    # ===========================================================================
    # PHASE 3: OUTPUT
    # ===========================================================================

    cat("\n")
    cat("PHASE 3: GENERATING OUTPUTS\n")
    cat(paste(rep("=", 80), collapse = ""), "\n\n")

    # Create output folder
    output_folder <- create_output_folder(config$output_folder,
                                           config$create_dated_folder)

    # Export exploration report
    report_filename <- paste0(config$output_prefix, "k_selection_report.xlsx")
    report_path <- file.path(output_folder, report_filename)

    export_exploration_report(
      exploration_result = exploration_result,
      metrics_result = metrics_result,
      recommendation = recommendation,
      output_path = report_path
    )

    # ===========================================================================
    # COMPLETION
    # ===========================================================================

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

    cat("\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat("EXPLORATION COMPLETE\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat(sprintf("✓ Analysis complete in %s\n", format_seconds(elapsed)))
    cat("\nOutputs:\n")
    cat(sprintf("  K selection report: %s\n", report_path))
    cat("\nNext steps:\n")
    cat(sprintf("  1. Review the k selection report\n"))
    cat(sprintf("  2. Choose optimal k (recommended: k=%d)\n", recommendation$recommended_k))
    cat(sprintf("  3. Update config file: set k_fixed = %d\n", recommendation$recommended_k))
    cat(sprintf("  4. Re-run: turas_segment_from_config(\"%s\")\n", basename(config_file)))
    cat("\n")

    # Return results
    return(invisible(list(
      mode = "exploration",
      recommendation = recommendation,
      metrics = metrics_result,
      models = exploration_result$models,
      output_files = list(
        report = report_path
      ),
      config = config
    )))

  } else {
    # =========================================================================
    # FINAL RUN MODE
    # =========================================================================

    cat("\nMode: FINAL RUN (k_fixed = ", config$k_fixed, ")\n", sep = "")

    # Run clustering with fixed k
    final_result <- run_kmeans_final(data_list)

    # ===========================================================================
    # PHASE 3: PROFILING & VALIDATION
    # ===========================================================================

    cat("\n")
    cat("PHASE 3: PROFILING & VALIDATION\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")

    # Calculate validation metrics
    validation_metrics <- calculate_validation_metrics(
      data = data_list$scaled_data,
      model = final_result$model,
      k = final_result$k,
      calculate_gap = FALSE  # Skip gap for final run
    )

    cat(sprintf("\nValidation metrics:\n"))
    cat(sprintf("  Average silhouette: %.3f\n", validation_metrics$avg_silhouette))
    cat(sprintf("  Between/Total SS: %.3f\n", validation_metrics$betweenss_totss))

    # Create segment profiles
    profile_result <- create_full_segment_profile(
      data = data_list$data,
      clusters = final_result$clusters,
      clustering_vars = data_list$config$clustering_vars,  # Use selected vars
      profile_vars = data_list$config$profile_vars  # Use updated config
    )

    # Generate segment names
    if (identical(config$segment_names, "auto")) {
      segment_names <- generate_segment_names(final_result$k, method = "simple")
    } else {
      segment_names <- config$segment_names
    }

    # ===========================================================================
    # PHASE 4: OUTPUT
    # ===========================================================================

    cat("\n")
    cat("PHASE 4: GENERATING OUTPUTS\n")
    cat(paste(rep("=", 80), collapse = ""), "\n\n")

    # Create output folder
    output_folder <- create_output_folder(config$output_folder,
                                           config$create_dated_folder)

    # Export segment assignments
    assignments_filename <- paste0(config$output_prefix, "segment_assignments.xlsx")
    assignments_path <- file.path(output_folder, assignments_filename)

    export_segment_assignments(
      data = data_list$data,
      clusters = final_result$clusters,
      segment_names = segment_names,
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
    if (config$save_model) {
      model_filename <- paste0(config$output_prefix, "model.rds")
      model_path <- file.path(output_folder, model_filename)

      # Get segment distribution
      segment_dist <- table(final_result$clusters)

      model_object <- list(
        model = final_result$model,
        k = final_result$k,
        clusters = final_result$clusters,
        centers = final_result$model$centers,  # Add centers for scoring
        segment_names = segment_names,
        clustering_vars = data_list$config$clustering_vars,  # Use selected vars, not original
        id_variable = config$id_variable,
        scale_params = data_list$scale_params,
        imputation_params = data_list$imputation_params,  # Add for scoring consistency
        original_distribution = segment_dist,  # Add for drift monitoring
        seed = seed_used,  # Add for reproducibility
        config = data_list$config,  # Use updated config with selected vars
        timestamp = Sys.time(),
        date_created = Sys.time(),
        turas_version = "1.0"
      )

      saveRDS(model_object, model_path)
      cat(sprintf("Saved model object to: %s\n", basename(model_path)))
    }

    # ===========================================================================
    # COMPLETION
    # ===========================================================================

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

    cat("\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat("SEGMENTATION COMPLETE\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat(sprintf("✓ Analysis complete in %s\n", format_seconds(elapsed)))
    cat("\nOutputs:\n")
    cat(sprintf("  Segment assignments: %s\n", assignments_path))
    cat(sprintf("  Full report: %s\n", report_path))
    if (config$save_model) {
      cat(sprintf("  Model object: %s\n", basename(model_path)))
    }
    cat("\nSegmentation summary:\n")
    cat(sprintf("  Number of segments: %d\n", final_result$k))
    cat(sprintf("  Average silhouette: %.3f\n", validation_metrics$avg_silhouette))
    cat(sprintf("  Observations: %d\n", nrow(data_list$data)))
    cat("\n")

    # Return results
    return(invisible(list(
      mode = "final",
      k = final_result$k,
      model = final_result$model,
      clusters = final_result$clusters,
      segment_names = segment_names,
      validation = validation_metrics,
      profiles = profile_result,
      output_files = list(
        assignments = assignments_path,
        report = report_path,
        model = if (config$save_model) model_path else NULL
      ),
      config = config
    )))
  }
}

# ==============================================================================
# COMMAND LINE EXECUTION
# ==============================================================================

# If running as a script (not sourced), execute main function
# Use sys.nframe() == 0 to detect if run directly (not sourced)
if (!interactive() && sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) == 0) {
    cat("Usage: Rscript run_segment.R <config_file.xlsx>\n")
    cat("Example: Rscript run_segment.R segment_config.xlsx\n")
    quit(status = 1)
  }

  config_file <- args[1]

  if (!file.exists(config_file)) {
    cat(sprintf("Error: Config file not found: %s\n", config_file))
    quit(status = 1)
  }

  # Run segmentation
  result <- turas_segment_from_config(config_file)

  quit(status = 0)
}

# ==============================================================================
# END OF RUN_SEGMENT.R
# ==============================================================================
