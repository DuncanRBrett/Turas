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
    segment_refuse(
      code = "IO_MODEL_FILE_MISSING",
      title = "Model File Not Found",
      problem = sprintf("Model file not found: %s", model_file),
      why_it_matters = "Cannot score new data without a saved model file.",
      how_to_fix = c(
        "Check that the model file path is correct",
        "Ensure the model was saved with save_model=TRUE",
        "Verify the file has not been moved or deleted"
      )
    )
  }

  model_data <- readRDS(model_file)

  # Validate model structure
  required_elements <- c("model", "config", "centers", "clustering_vars")
  missing <- setdiff(required_elements, names(model_data))
  if (length(missing) > 0) {
    segment_refuse(
      code = "DATA_INVALID_MODEL",
      title = "Invalid Model File",
      problem = sprintf("Model file is missing required elements: %s", paste(missing, collapse = ", ")),
      why_it_matters = "A complete model file is required for scoring.",
      how_to_fix = c(
        "Re-run the segmentation to generate a new model file",
        "Ensure the model file was not corrupted"
      )
    )
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
    segment_refuse(
      code = "CFG_ID_VAR_MISSING",
      title = "ID Variable Not Found",
      problem = sprintf("ID variable '%s' not found in new data.", id_variable),
      why_it_matters = "An ID variable is required to identify scored respondents.",
      how_to_fix = sprintf("Ensure new_data contains a column named '%s'.", id_variable)
    )
  }

  # Check clustering variables exist
  missing_vars <- setdiff(clustering_vars, names(new_data))
  if (length(missing_vars) > 0) {
    segment_refuse(
      code = "DATA_MISSING_VARIABLES",
      title = "Missing Clustering Variables",
      problem = sprintf("Missing clustering variables in new data: %s", paste(missing_vars, collapse = ", ")),
      why_it_matters = "All clustering variables from the model are required to score respondents.",
      how_to_fix = sprintf("Ensure new_data contains: %s", paste(missing_vars, collapse = ", "))
    )
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
            # TRS PARTIAL: Fallback to batch mean for this variable (may differ from training)
            message(sprintf("[TRS PARTIAL] SEG_IMPUTE_FALLBACK: No saved mean for variable '%s' - using current batch mean", var))
            mean_val <- mean(scoring_data[[var]], na.rm = TRUE)
            scoring_data[[var]][is.na(scoring_data[[var]])] <- mean_val
          }
        }
      } else {
        # Fallback to batch means
        # TRS PARTIAL: Using batch means instead of training parameters (may affect consistency)
        message("[TRS PARTIAL] SEG_IMPUTE_NO_PARAMS: Model does not contain saved imputation parameters - using current batch means")
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
            # TRS PARTIAL: Fallback to batch median for this variable (may differ from training)
            message(sprintf("[TRS PARTIAL] SEG_IMPUTE_FALLBACK: No saved median for variable '%s' - using current batch median", var))
            median_val <- median(scoring_data[[var]], na.rm = TRUE)
            scoring_data[[var]][is.na(scoring_data[[var]])] <- median_val
          }
        }
      } else {
        # Fallback to batch medians
        # TRS PARTIAL: Using batch medians instead of training parameters (may affect consistency)
        message("[TRS PARTIAL] SEG_IMPUTE_NO_PARAMS: Model does not contain saved imputation parameters - using current batch medians")
        for (var in vars_with_missing) {
          median_val <- median(scoring_data[[var]], na.rm = TRUE)
          scoring_data[[var]][is.na(scoring_data[[var]])] <- median_val
        }
        cat(sprintf("  Imputed missing values with batch medians\n"))
      }
    }
  }

  if (nrow(scoring_data) == 0) {
    segment_refuse(
      code = "DATA_NO_VALID_CASES",
      title = "No Valid Cases Remaining",
      problem = "No valid cases remaining after missing data handling.",
      why_it_matters = "Cannot score respondents if all cases have missing data.",
      how_to_fix = c(
        "Check for excessive missing data in new_data",
        "Consider using mean or median imputation instead of listwise deletion",
        "Ensure new data is properly formatted"
      )
    )
  }

  # Standardize if model was standardized
  if (config$standardize) {
    cat("\nStandardizing variables...\n")

    # CRITICAL: Use saved training scale parameters, not batch parameters
    if (is.null(scale_params) ||
        is.null(scale_params$center) ||
        is.null(scale_params$scale)) {
      segment_refuse(
        code = "DATA_MISSING_SCALE_PARAMS",
        title = "Missing Scale Parameters",
        problem = "Model was standardized, but no scale parameters were found in the saved model.",
        why_it_matters = "Cannot apply correct standardization without training scale parameters.",
        how_to_fix = "Re-run the segmentation to generate a model with scale parameters."
      )
    }

    # Align scale parameters with clustering variables
    scale_center <- scale_params$center[clustering_vars]
    scale_scale <- scale_params$scale[clustering_vars]

    # Safety check for missing parameters
    if (any(is.na(scale_center)) || any(is.na(scale_scale))) {
      segment_refuse(
        code = "DATA_INCOMPLETE_SCALE_PARAMS",
        title = "Incomplete Scale Parameters",
        problem = "Scale parameters are missing for one or more clustering variables.",
        why_it_matters = "All clustering variables need scale parameters for consistent scoring.",
        how_to_fix = "Re-run the segmentation to generate complete scale parameters."
      )
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
      # TRS INFO: Unsupported format, skip export
      message("[TRS INFO] Unsupported output format - use .xlsx or .csv. Export skipped.")
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
    # TRS INFO: Comparison not possible without original distribution
    message("[TRS INFO] Original segment distribution not saved in model file - comparison not available")
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


# ==============================================================================
# FEATURE 2: RESPONDENT TYPING TOOL
# ==============================================================================

#' Type a Single Respondent to a Segment
#'
#' Classifies a single respondent (or small batch) using a saved segmentation model.
#' Returns segment assignment with confidence score and distances to all centers.
#'
#' @param answers Named vector c(q1=8, q2=7, q3=9) OR single-row data frame
#' @param model_file Path to saved .rds model file
#'
#' @return List with segment, segment_name, confidence, distances
#' @export
#' @examples
#' # Single respondent
#' result <- type_respondent(
#'   answers = c(q1 = 8, q2 = 7, q3 = 9, q4 = 8, q5 = 9),
#'   model_file = "output/seg_model.rds"
#' )
type_respondent <- function(answers, model_file) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("RESPONDENT TYPING\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # ===========================================================================
  # LOAD MODEL
  # ===========================================================================

  if (!file.exists(model_file)) {
    segment_refuse(
      code = "IO_MODEL_FILE_MISSING",
      title = "Model File Not Found",
      problem = sprintf("Model file not found: %s", model_file),
      why_it_matters = "Cannot type respondent without a saved model file.",
      how_to_fix = c(
        "Check that the model file path is correct",
        "Ensure the model was saved with save_model=TRUE",
        "Verify the file has not been moved or deleted"
      )
    )
  }

  model_data <- readRDS(model_file)

  # Check if this is a k-means model
  method <- model_data$method
  if (is.null(method)) method <- "kmeans"

  if (method == "lca") {
    segment_refuse(
      code = "MODEL_TYPE_MISMATCH",
      title = "Wrong Model Type",
      problem = "This is an LCA model.",
      why_it_matters = "type_respondent() only works with k-means models.",
      how_to_fix = "Use type_respondent_lca() for LCA models instead."
    )
  }

  # Extract required components
  centers <- model_data$centers
  clustering_vars <- model_data$clustering_vars
  segment_names <- model_data$segment_names
  scale_params <- model_data$scale_params
  k <- model_data$k

  cat(sprintf("Typing respondent against %d-segment model...\n", k))

  # ===========================================================================
  # VALIDATE ANSWERS
  # ===========================================================================

  # Convert named vector to data frame if needed
  if (is.vector(answers) && !is.data.frame(answers)) {
    answers <- as.data.frame(t(answers))
  }

  # Validate all clustering variables are present
  missing_vars <- setdiff(clustering_vars, names(answers))
  if (length(missing_vars) > 0) {
    segment_refuse(
      code = "DATA_MISSING_VARIABLES",
      title = "Missing Variables in Answers",
      problem = sprintf("Missing variables in answers: %s", paste(missing_vars, collapse = ", ")),
      why_it_matters = "All clustering variables are required to type the respondent.",
      how_to_fix = sprintf("Provide values for all variables: %s", paste(clustering_vars, collapse = ", "))
    )
  }

  # Extract and order answers to match clustering variables
  answer_values <- as.numeric(answers[1, clustering_vars])
  names(answer_values) <- clustering_vars

  # Check for missing values
  if (any(is.na(answer_values))) {
    missing <- clustering_vars[is.na(answer_values)]
    segment_refuse(
      code = "DATA_MISSING_VALUES",
      title = "Missing Values in Answers",
      problem = sprintf("Missing values for: %s", paste(missing, collapse = ", ")),
      why_it_matters = "All clustering variables need values to type the respondent.",
      how_to_fix = sprintf("Provide numeric values for: %s", paste(missing, collapse = ", "))
    )
  }

  # ===========================================================================
  # STANDARDIZE USING MODEL PARAMETERS
  # ===========================================================================

  if (!is.null(scale_params) &&
      !is.null(scale_params$center) &&
      !is.null(scale_params$scale)) {

    # Standardize using training parameters
    standardized_values <- (answer_values - scale_params$center[clustering_vars]) /
                           scale_params$scale[clustering_vars]
    cat("  Standardized using model parameters\n")
  } else {
    standardized_values <- answer_values
    cat("  Using raw values (model was not standardized)\n")
  }

  # ===========================================================================
  # CALCULATE DISTANCES TO EACH CENTER
  # ===========================================================================

  distances <- numeric(k)
  for (i in 1:k) {
    center_vec <- centers[i, ]
    distances[i] <- sqrt(sum((standardized_values - center_vec)^2))
  }

  names(distances) <- if (!is.null(segment_names)) segment_names else paste0("Segment_", 1:k)

  # ===========================================================================
  # DETERMINE ASSIGNMENT AND CONFIDENCE
  # ===========================================================================

  assigned_segment <- which.min(distances)
  min_distance <- distances[assigned_segment]

  # Calculate confidence (inverse of relative distance)
  # Higher confidence = respondent is much closer to assigned segment than others
  # Using softmax-like approach: confidence = exp(-d_min) / sum(exp(-d_all))
  exp_neg_distances <- exp(-distances)
  confidence <- exp_neg_distances[assigned_segment] / sum(exp_neg_distances)

  # Get segment name
  if (!is.null(segment_names) && length(segment_names) >= assigned_segment) {
    assigned_name <- segment_names[assigned_segment]
  } else {
    assigned_name <- paste0("Segment ", assigned_segment)
  }

  # ===========================================================================
  # OUTPUT RESULTS
  # ===========================================================================

  cat(sprintf("\n✓ Assigned to Segment %d: %s\n", assigned_segment, assigned_name))
  cat(sprintf("  Confidence: %.0f%%\n", confidence * 100))
  cat("\n  Distance to centers:\n")
  for (i in 1:k) {
    seg_label <- names(distances)[i]
    marker <- if (i == assigned_segment) " ← ASSIGNED" else ""
    cat(sprintf("    %s: %.2f%s\n", seg_label, distances[i], marker))
  }
  cat("\n")

  return(list(
    segment = assigned_segment,
    segment_name = assigned_name,
    confidence = confidence,
    distances = distances,
    standardized_values = standardized_values
  ))
}


#' Type Multiple Respondents in Batch
#'
#' Wrapper for type_respondent() to classify multiple respondents at once.
#'
#' @param data Data frame with multiple respondents
#' @param model_file Path to saved .rds model file
#' @param id_var Name of ID variable in data
#'
#' @return Data frame with id, segment, segment_name, confidence
#' @export
#' @examples
#' results <- type_respondents_batch(
#'   data = new_respondents,
#'   model_file = "output/seg_model.rds",
#'   id_var = "respondent_id"
#' )
type_respondents_batch <- function(data, model_file, id_var) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("BATCH RESPONDENT TYPING\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # ===========================================================================
  # LOAD MODEL
  # ===========================================================================

  if (!file.exists(model_file)) {
    segment_refuse(
      code = "IO_MODEL_FILE_MISSING",
      title = "Model File Not Found",
      problem = sprintf("Model file not found: %s", model_file),
      why_it_matters = "Cannot type respondents without a saved model file.",
      how_to_fix = c(
        "Check that the model file path is correct",
        "Ensure the model was saved with save_model=TRUE",
        "Verify the file has not been moved or deleted"
      )
    )
  }

  model_data <- readRDS(model_file)

  # Check method
  method <- model_data$method
  if (is.null(method)) method <- "kmeans"

  if (method == "lca") {
    segment_refuse(
      code = "MODEL_TYPE_MISMATCH",
      title = "Wrong Model Type",
      problem = "This is an LCA model.",
      why_it_matters = "type_respondents_batch() only works with k-means models.",
      how_to_fix = "Use type_respondents_batch_lca() for LCA models instead."
    )
  }

  # Extract required components
  centers <- model_data$centers
  clustering_vars <- model_data$clustering_vars
  segment_names <- model_data$segment_names
  scale_params <- model_data$scale_params
  k <- model_data$k

  cat(sprintf("Model: %d segments, %d variables\n", k, length(clustering_vars)))
  cat(sprintf("Respondents to type: %d\n\n", nrow(data)))

  # ===========================================================================
  # VALIDATE DATA
  # ===========================================================================

  # Check ID variable
  if (!id_var %in% names(data)) {
    segment_refuse(
      code = "CFG_ID_VAR_MISSING",
      title = "ID Variable Not Found",
      problem = sprintf("ID variable '%s' not found in data.", id_var),
      why_it_matters = "An ID variable is required to identify typed respondents.",
      how_to_fix = sprintf("Ensure data contains a column named '%s'.", id_var)
    )
  }

  # Check clustering variables
  missing_vars <- setdiff(clustering_vars, names(data))
  if (length(missing_vars) > 0) {
    segment_refuse(
      code = "DATA_MISSING_VARIABLES",
      title = "Missing Clustering Variables",
      problem = sprintf("Missing variables in data: %s", paste(missing_vars, collapse = ", ")),
      why_it_matters = "All clustering variables are required to type respondents.",
      how_to_fix = sprintf("Ensure data contains: %s", paste(missing_vars, collapse = ", "))
    )
  }

  # ===========================================================================
  # PROCESS EACH RESPONDENT
  # ===========================================================================

  results <- data.frame(
    id = data[[id_var]],
    segment = integer(nrow(data)),
    segment_name = character(nrow(data)),
    confidence = numeric(nrow(data)),
    distance_to_center = numeric(nrow(data)),
    stringsAsFactors = FALSE
  )

  # Add distance columns for each segment
  for (i in 1:k) {
    seg_col <- paste0("dist_seg_", i)
    results[[seg_col]] <- numeric(nrow(data))
  }

  n_processed <- 0
  n_errors <- 0

  for (row_idx in 1:nrow(data)) {
    if (row_idx %% 100 == 0) {
      cat(sprintf("  Processing respondent %d/%d...\n", row_idx, nrow(data)))
    }

    tryCatch({
      # Get answer values
      answer_values <- as.numeric(data[row_idx, clustering_vars])
      names(answer_values) <- clustering_vars

      # Skip if any missing values
      if (any(is.na(answer_values))) {
        results$segment[row_idx] <- NA
        results$segment_name[row_idx] <- NA
        results$confidence[row_idx] <- NA
        results$distance_to_center[row_idx] <- NA
        n_errors <- n_errors + 1
        next
      }

      # Standardize
      if (!is.null(scale_params) &&
          !is.null(scale_params$center) &&
          !is.null(scale_params$scale)) {
        standardized_values <- (answer_values - scale_params$center[clustering_vars]) /
                               scale_params$scale[clustering_vars]
      } else {
        standardized_values <- answer_values
      }

      # Calculate distances
      distances <- numeric(k)
      for (i in 1:k) {
        center_vec <- centers[i, ]
        distances[i] <- sqrt(sum((standardized_values - center_vec)^2))
      }

      # Assign segment
      assigned_segment <- which.min(distances)
      min_distance <- distances[assigned_segment]

      # Calculate confidence
      exp_neg_distances <- exp(-distances)
      confidence <- exp_neg_distances[assigned_segment] / sum(exp_neg_distances)

      # Get segment name
      if (!is.null(segment_names) && length(segment_names) >= assigned_segment) {
        assigned_name <- segment_names[assigned_segment]
      } else {
        assigned_name <- paste0("Segment ", assigned_segment)
      }

      # Store results
      results$segment[row_idx] <- assigned_segment
      results$segment_name[row_idx] <- assigned_name
      results$confidence[row_idx] <- round(confidence, 3)
      results$distance_to_center[row_idx] <- round(min_distance, 3)

      for (i in 1:k) {
        results[[paste0("dist_seg_", i)]][row_idx] <- round(distances[i], 3)
      }

      n_processed <- n_processed + 1

    }, error = function(e) {
      results$segment[row_idx] <- NA
      results$segment_name[row_idx] <- NA
      results$confidence[row_idx] <- NA
      n_errors <- n_errors + 1
    })
  }

  # ===========================================================================
  # SUMMARY
  # ===========================================================================

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TYPING COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat(sprintf("✓ Successfully typed: %d respondents\n", n_processed))
  if (n_errors > 0) {
    cat(sprintf("⚠ Errors (missing data): %d respondents\n", n_errors))
  }

  # Segment distribution
  cat("\nSegment distribution:\n")
  seg_table <- table(results$segment, useNA = "ifany")
  for (seg in sort(unique(results$segment[!is.na(results$segment)]))) {
    seg_name <- if (!is.null(segment_names) && length(segment_names) >= seg) {
      segment_names[seg]
    } else {
      paste0("Segment ", seg)
    }
    seg_count <- sum(results$segment == seg, na.rm = TRUE)
    seg_pct <- 100 * seg_count / n_processed
    cat(sprintf("  %s: %d (%.1f%%)\n", seg_name, seg_count, seg_pct))
  }

  # Confidence summary
  cat(sprintf("\nConfidence scores:\n"))
  cat(sprintf("  Mean: %.1f%%\n", mean(results$confidence, na.rm = TRUE) * 100))
  cat(sprintf("  Min:  %.1f%%\n", min(results$confidence, na.rm = TRUE) * 100))
  cat(sprintf("  Max:  %.1f%%\n", max(results$confidence, na.rm = TRUE) * 100))

  # Flag low confidence
  low_conf_threshold <- 0.5
  n_low_conf <- sum(results$confidence < low_conf_threshold, na.rm = TRUE)
  if (n_low_conf > 0) {
    cat(sprintf("\n⚠ %d respondents (%.1f%%) have confidence < %.0f%%\n",
                n_low_conf, 100 * n_low_conf / n_processed, low_conf_threshold * 100))
  }

  cat("\n")

  # Rename ID column to match input
  names(results)[1] <- id_var

  return(results)
}
