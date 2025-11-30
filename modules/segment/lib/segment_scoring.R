# ==============================================================================
# SEGMENTATION MODEL SCORING
# ==============================================================================
# Apply saved segmentation models to new data
# Part of Turas Segmentation Module
# ==============================================================================

#' Score New Data with Saved Segmentation Model
#'
#' Applies a saved k-means model to new respondents, assigning them to segments
#'
#' DESIGN: Loads saved model, validates new data, assigns segments
#' USE CASE: Score ongoing survey responses with existing segmentation
#'
#' @param model_file Path to saved .rds model file
#' @param new_data Data frame with new respondents to score
#' @param id_variable Name of respondent ID variable
#' @param output_file Optional path to save scoring results
#' @return List with segment assignments and metadata
#' @export
score_new_data <- function(model_file, new_data, id_variable, output_file = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("SEGMENTATION MODEL SCORING\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # ===========================================================================
  # LOAD MODEL
  # ===========================================================================

  cat(sprintf("Loading model from: %s\n", basename(model_file)))

  if (!file.exists(model_file)) {
    stop(sprintf("Model file not found: %s", model_file), call. = FALSE)
  }

  model_data <- readRDS(model_file)

  # Validate model structure
  required_elements <- c("model", "config", "centers", "clustering_vars")
  missing <- setdiff(required_elements, names(model_data))
  if (length(missing) > 0) {
    stop(sprintf("Invalid model file. Missing elements: %s",
                paste(missing, collapse = ", ")), call. = FALSE)
  }

  config <- model_data$config
  clustering_vars <- model_data$clustering_vars
  centers <- model_data$centers
  segment_names <- model_data$segment_names
  scale_params <- model_data$scale_params
  imputation_params <- model_data$imputation_params

  cat(sprintf("✓ Model loaded successfully\n"))
  cat(sprintf("  Segments: %d\n", nrow(centers)))
  cat(sprintf("  Variables: %d\n", length(clustering_vars)))
  cat(sprintf("  Model created: %s\n",
              ifelse(!is.null(model_data$timestamp), model_data$timestamp, "Unknown")))

  # ===========================================================================
  # VALIDATE NEW DATA
  # ===========================================================================

  cat("\nValidating new data...\n")

  # Check ID variable exists
  if (!id_variable %in% names(new_data)) {
    stop(sprintf("ID variable '%s' not found in new data", id_variable), call. = FALSE)
  }

  # Check clustering variables exist
  missing_vars <- setdiff(clustering_vars, names(new_data))
  if (length(missing_vars) > 0) {
    stop(sprintf("Missing clustering variables in new data: %s",
                paste(missing_vars, collapse = ", ")), call. = FALSE)
  }

  cat(sprintf("✓ New data validated\n"))
  cat(sprintf("  Respondents: %d\n", nrow(new_data)))

  # ===========================================================================
  # PREPARE DATA
  # ===========================================================================

  cat("\nPreparing data for scoring...\n")

  # Extract clustering data
  scoring_data <- new_data[, clustering_vars, drop = FALSE]

  # Check for missing values
  missing_counts <- colSums(is.na(scoring_data))
  vars_with_missing <- names(missing_counts[missing_counts > 0])

  if (length(vars_with_missing) > 0) {
    cat(sprintf("⚠ Warning: Missing values detected in %d variables\n",
                length(vars_with_missing)))

    for (var in vars_with_missing) {
      pct_missing <- 100 * missing_counts[var] / nrow(scoring_data)
      cat(sprintf("    %s: %d (%.1f%%)\n", var, missing_counts[var], pct_missing))
    }

    # Handle missing data based on original config
    missing_method <- config$missing_data
    cat(sprintf("\nApplying missing data strategy: %s\n", missing_method))

    if (missing_method == "listwise_deletion") {
      rows_before <- nrow(scoring_data)
      complete_rows <- complete.cases(scoring_data)
      scoring_data <- scoring_data[complete_rows, ]
      new_data <- new_data[complete_rows, ]
      cat(sprintf("  Removed %d incomplete cases\n", rows_before - nrow(scoring_data)))

    } else if (missing_method == "mean_imputation") {
      # Use saved training means for consistency
      if (!is.null(imputation_params) && !is.null(imputation_params$means)) {
        cat(sprintf("  Using training data means for imputation\n"))
        for (var in vars_with_missing) {
          if (var %in% names(imputation_params$means)) {
            mean_val <- imputation_params$means[[var]]
            scoring_data[[var]][is.na(scoring_data[[var]])] <- mean_val
            cat(sprintf("    %s: mean = %.3f\n", var, mean_val))
          } else {
            warning(sprintf("No saved mean for variable '%s', using current batch mean", var),
                   call. = FALSE)
            mean_val <- mean(scoring_data[[var]], na.rm = TRUE)
            scoring_data[[var]][is.na(scoring_data[[var]])] <- mean_val
          }
        }
      } else {
        # Fallback to batch means (with warning)
        warning("Model does not contain saved imputation parameters. Using current batch means.",
               call. = FALSE)
        for (var in vars_with_missing) {
          mean_val <- mean(scoring_data[[var]], na.rm = TRUE)
          scoring_data[[var]][is.na(scoring_data[[var]])] <- mean_val
        }
        cat(sprintf("  Imputed missing values with batch means\n"))
      }

    } else if (missing_method == "median_imputation") {
      # Use saved training medians for consistency
      if (!is.null(imputation_params) && !is.null(imputation_params$medians)) {
        cat(sprintf("  Using training data medians for imputation\n"))
        for (var in vars_with_missing) {
          if (var %in% names(imputation_params$medians)) {
            median_val <- imputation_params$medians[[var]]
            scoring_data[[var]][is.na(scoring_data[[var]])] <- median_val
            cat(sprintf("    %s: median = %.3f\n", var, median_val))
          } else {
            warning(sprintf("No saved median for variable '%s', using current batch median", var),
                   call. = FALSE)
            median_val <- median(scoring_data[[var]], na.rm = TRUE)
            scoring_data[[var]][is.na(scoring_data[[var]])] <- median_val
          }
        }
      } else {
        # Fallback to batch medians (with warning)
        warning("Model does not contain saved imputation parameters. Using current batch medians.",
               call. = FALSE)
        for (var in vars_with_missing) {
          median_val <- median(scoring_data[[var]], na.rm = TRUE)
          scoring_data[[var]][is.na(scoring_data[[var]])] <- median_val
        }
        cat(sprintf("  Imputed missing values with batch medians\n"))
      }
    }
  }

  if (nrow(scoring_data) == 0) {
    stop("No valid cases remaining after missing data handling", call. = FALSE)
  }

  # Standardize if model was standardized
  if (config$standardize) {
    cat("\nStandardizing variables...\n")

    # CRITICAL: Use saved training scale parameters, not batch parameters
    if (is.null(scale_params) ||
        is.null(scale_params$center) ||
        is.null(scale_params$scale)) {
      stop("Model was standardized, but no scale parameters were found in the saved model.",
           call. = FALSE)
    }

    # Align scale parameters with clustering variables
    scale_center <- scale_params$center[clustering_vars]
    scale_scale <- scale_params$scale[clustering_vars]

    # Safety check for missing parameters
    if (any(is.na(scale_center)) || any(is.na(scale_scale))) {
      stop("Scale parameters are missing for one or more clustering variables.",
           call. = FALSE)
    }

    # Apply training standardization parameters to new data
    scoring_data_scaled <- scale(
      scoring_data,
      center = scale_center,
      scale = scale_scale
    )

    cat("✓ Variables standardized using training scale parameters\n")
  } else {
    scoring_data_scaled <- as.matrix(scoring_data)
  }

  # ===========================================================================
  # ASSIGN SEGMENTS
  # ===========================================================================

  cat("\nAssigning segments...\n")

  # Calculate distances to each center
  distances <- matrix(NA, nrow = nrow(scoring_data_scaled), ncol = nrow(centers))

  for (i in 1:nrow(centers)) {
    center_vec <- centers[i, ]
    distances[, i] <- sqrt(rowSums((scoring_data_scaled -
                                    matrix(center_vec, nrow = nrow(scoring_data_scaled),
                                          ncol = ncol(scoring_data_scaled), byrow = TRUE))^2))
  }

  # Assign to nearest center
  assignments <- apply(distances, 1, which.min)

  # Get minimum distances (for confidence scoring)
  min_distances <- apply(distances, 1, min)

  # Calculate assignment confidence (inverse of distance, normalized)
  confidence <- 1 / (1 + min_distances)

  cat(sprintf("✓ Assigned %d respondents to %d segments\n",
              length(assignments), nrow(centers)))

  # ===========================================================================
  # CREATE RESULTS
  # ===========================================================================

  # Build results data frame
  results <- data.frame(
    respondent_id = new_data[[id_variable]],
    segment = assignments,
    segment_name = if (!is.null(segment_names)) segment_names[assignments] else paste0("Segment_", assignments),
    distance_to_center = round(min_distances, 3),
    assignment_confidence = round(confidence, 3),
    stringsAsFactors = FALSE
  )

  # Add segment sizes
  segment_counts <- table(assignments)
  cat("\nSegment distribution:\n")
  for (seg in sort(unique(assignments))) {
    seg_name <- if (!is.null(segment_names)) segment_names[seg] else paste0("Segment ", seg)
    seg_count <- segment_counts[as.character(seg)]
    seg_pct <- 100 * seg_count / nrow(results)
    cat(sprintf("  %s: %d (%.1f%%)\n", seg_name, seg_count, seg_pct))
  }

  # ===========================================================================
  # EXPORT RESULTS
  # ===========================================================================

  if (!is.null(output_file)) {
    cat(sprintf("\nExporting results to: %s\n", basename(output_file)))

    # Determine file type
    if (grepl("\\.xlsx$", output_file, ignore.case = TRUE)) {
      # Excel export
      writexl::write_xlsx(list(Assignments = results), output_file)
    } else if (grepl("\\.csv$", output_file, ignore.case = TRUE)) {
      # CSV export
      write.csv(results, output_file, row.names = FALSE)
    } else {
      warning("Unsupported output format. Use .xlsx or .csv", call. = FALSE)
    }

    cat("✓ Results exported\n")
  }

  # ===========================================================================
  # RETURN
  # ===========================================================================

  cat("\n✓ Scoring complete\n\n")

  return(list(
    assignments = results,
    segment_counts = as.data.frame(segment_counts),
    model_info = list(
      model_file = model_file,
      n_segments = nrow(centers),
      clustering_vars = clustering_vars,
      timestamp = model_data$timestamp
    ),
    scoring_info = list(
      n_scored = nrow(results),
      scoring_date = Sys.time()
    )
  ))
}


#' Compare Segment Distributions
#'
#' Compares segment distributions between original model and new scoring
#' Useful for monitoring segment drift over time
#'
#' @param model_file Path to saved model file
#' @param scoring_result Result from score_new_data()
#' @return Data frame comparing distributions
#' @export
compare_segment_distributions <- function(model_file, scoring_result) {

  # Load original model
  model_data <- readRDS(model_file)

  if (is.null(model_data$original_distribution)) {
    warning("Original segment distribution not saved in model file", call. = FALSE)
    return(NULL)
  }

  # Get original distribution
  orig_dist <- model_data$original_distribution

  # Get new distribution
  new_dist <- table(scoring_result$assignments$segment)
  new_pct <- 100 * new_dist / sum(new_dist)

  # Combine
  comparison <- data.frame(
    Segment = names(orig_dist),
    Original_N = as.numeric(orig_dist),
    Original_Pct = round(100 * orig_dist / sum(orig_dist), 1),
    New_N = as.numeric(new_dist[names(orig_dist)]),
    New_Pct = round(as.numeric(new_pct[names(orig_dist)]), 1),
    stringsAsFactors = FALSE
  )

  comparison$Difference_Pct <- comparison$New_Pct - comparison$Original_Pct

  cat("\nSegment Distribution Comparison:\n")
  print(comparison)

  return(comparison)
}
