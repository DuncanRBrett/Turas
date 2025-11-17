# ==============================================================================
# SEGMENTATION EXCEL EXPORT
# ==============================================================================
# Export segment assignments and reports to Excel
# Part of Turas Segmentation Module
# ==============================================================================

# Source config utilities for label formatting
source("modules/segment/lib/segment_config.R")

#' Export segment assignments file
#'
#' DESIGN: Simple join table (respondent_id, segment, segment_name, outlier_flag)
#' PURPOSE: Easy to merge back with original data
#'
#' @param data Original data frame
#' @param clusters Integer vector, cluster assignments
#' @param segment_names Character vector, segment names
#' @param id_var Character, ID variable name
#' @param output_path Character, output file path
#' @param outlier_flags Logical vector, outlier flags (optional)
#' @export
export_segment_assignments <- function(data, clusters, segment_names, id_var, output_path,
                                      outlier_flags = NULL) {
  cat(sprintf("Exporting segment assignments to: %s\n", basename(output_path)))

  # Create assignments data frame
  assignments <- data.frame(
    respondent_id = data[[id_var]],
    segment = clusters,
    segment_name = segment_names[clusters],
    stringsAsFactors = FALSE
  )

  # Add outlier flags if provided
  if (!is.null(outlier_flags) && length(outlier_flags) > 0) {
    assignments$outlier_flag <- outlier_flags
  }

  # Rename first column to match original ID variable name
  names(assignments)[1] <- id_var

  # Write to Excel
  writexl::write_xlsx(assignments, output_path)

  cat(sprintf("✓ Exported %d segment assignments\n", nrow(assignments)))

  return(invisible(output_path))
}

#' Export exploration mode k selection report
#'
#' DESIGN: Multi-tab Excel with metrics comparison and profiles
#' TABS: Metrics_Comparison, Profile_K3, Profile_K4, etc.
#'
#' @param exploration_result Result from run_kmeans_exploration()
#' @param metrics_result Result from calculate_exploration_metrics()
#' @param recommendation Result from recommend_k()
#' @param output_path Character, output file path
#' @export
export_exploration_report <- function(exploration_result, metrics_result,
                                      recommendation, output_path) {
  cat(sprintf("Exporting exploration report to: %s\n", basename(output_path)))

  data_list <- exploration_result$data_list
  config <- data_list$config
  k_range <- exploration_result$k_range

  # Prepare metrics comparison sheet
  metrics_df <- metrics_result$metrics_df

  # Add recommendation column
  metrics_df$Recommendation <- ""
  rec_idx <- which(metrics_df$k == recommendation$recommended_k)
  if (length(rec_idx) > 0) {
    # Get silhouette from metrics_df
    rec_silhouette <- metrics_df$avg_silhouette_width[rec_idx]
    metrics_df$Recommendation[rec_idx] <- sprintf("← Best silhouette (%.3f)", rec_silhouette)
  }
  
  # Check for warnings
  for (i in 1:nrow(metrics_df)) {
    if (metrics_df$min_segment_pct[i] < config$min_segment_size_pct) {
      if (nchar(metrics_df$Recommendation[i]) > 0) {
        metrics_df$Recommendation[i] <- paste(metrics_df$Recommendation[i],
                                              "⚠ Small segment")
      } else {
        metrics_df$Recommendation[i] <- "⚠ Small segment"
      }
    }
  }
  
  # Round numeric columns for readability
  metrics_df$avg_silhouette_width <- round(metrics_df$avg_silhouette_width, 3)
  metrics_df$tot.withinss <- round(metrics_df$tot.withinss, 1)
  metrics_df$betweenss_totss <- round(metrics_df$betweenss_totss, 3)
  metrics_df$min_segment_pct <- round(metrics_df$min_segment_pct, 1)
  
  # Prepare profiles for each k
  profile_sheets <- list()
  profile_sheets[["Metrics_Comparison"]] <- metrics_df

  for (k in k_range) {
    cat(sprintf("  Creating profile for k=%d...\n", k))

    model <- exploration_result$models[[as.character(k)]]
    clusters <- model$cluster

    # Create profile
    profile <- create_full_segment_profile(
      data = data_list$data,
      clusters = clusters,
      clustering_vars = config$clustering_vars,
      profile_vars = config$profile_vars
    )

    # Format profile for export
    profile_export <- profile$clustering_profile

    # Apply question labels to Variable column if available
    if (!is.null(config$question_labels)) {
      profile_export$Variable <- format_variable_label(profile_export$Variable,
                                                       config$question_labels)
    }

    # Round numeric columns
    num_cols <- sapply(profile_export, is.numeric)
    profile_export[num_cols] <- lapply(profile_export[num_cols], function(x) round(x, 2))

    # Add segment sizes as last rows
    size_row <- data.frame(
      Variable = "Segment_size_n",
      stringsAsFactors = FALSE
    )
    pct_row <- data.frame(
      Variable = "Segment_size_pct",
      stringsAsFactors = FALSE
    )

    for (col in names(profile_export)[-1]) {  # Skip Variable column
      size_row[[col]] <- NA
      pct_row[[col]] <- NA
    }

    # Set segment size values
    seg_sizes <- profile$segment_sizes
    for (i in 1:nrow(seg_sizes)) {
      seg_col <- paste0("Segment_", seg_sizes$Segment[i])
      if (seg_col %in% names(size_row)) {
        size_row[[seg_col]] <- seg_sizes$Count[i]
        pct_row[[seg_col]] <- round(seg_sizes$Percentage[i], 1)
      }
    }

    # Set overall size
    size_row$Overall <- nrow(data_list$data)
    pct_row$Overall <- 100.0

    profile_export <- rbind(profile_export, size_row, pct_row)

    # Store with sheet name
    sheet_name <- sprintf("Profile_K%d", k)
    profile_sheets[[sheet_name]] <- profile_export
  }

  # Add outlier analysis sheet if outliers were detected
  if (config$outlier_detection && !is.null(data_list$outlier_result)) {
    cat("  Creating outlier analysis sheet...\n")

    # Source outlier module for create_outlier_report function
    source("modules/segment/lib/segment_outliers.R")

    outlier_report <- create_outlier_report(
      outlier_result = data_list$outlier_result,
      data = data_list$data,
      id_var = config$id_variable,
      standardized_data = as.data.frame(data_list$scaled_data),
      clustering_vars = config$clustering_vars
    )

    if (nrow(outlier_report) > 0) {
      profile_sheets[["Outliers"]] <- outlier_report
    }
  }

  # Add variable selection sheets if variable selection was performed
  if (config$variable_selection && !is.null(data_list$variable_selection_result)) {
    cat("  Creating variable selection sheets...\n")

    varsel <- data_list$variable_selection_result

    # Selected variables sheet with labels
    selected_df <- data.frame(
      Variable = varsel$selected_vars,
      Status = "Selected",
      stringsAsFactors = FALSE
    )

    # Add labels column if available
    if (!is.null(config$question_labels)) {
      selected_df$Label <- sapply(varsel$selected_vars, function(v) {
        if (v %in% names(config$question_labels)) {
          config$question_labels[v]
        } else {
          ""
        }
      }, USE.NAMES = FALSE)
    }

    profile_sheets[["VarSel_Selected"]] <- selected_df

    # Variable statistics sheet with labels
    if (!is.null(varsel$selection_log$variance)) {
      var_stats <- varsel$selection_log$variance$variance_df
      var_stats$selected <- var_stats$variable %in% varsel$selected_vars
      var_stats$variance <- round(var_stats$variance, 4)
      var_stats$sd <- round(var_stats$sd, 4)

      # Add labels column if available
      if (!is.null(config$question_labels)) {
        var_stats$label <- sapply(var_stats$variable, function(v) {
          if (v %in% names(config$question_labels)) {
            config$question_labels[v]
          } else {
            ""
          }
        }, USE.NAMES = FALSE)
        # Reorder columns to put label after variable
        var_stats <- var_stats[, c("variable", "label", setdiff(names(var_stats), c("variable", "label")))]
      }

      profile_sheets[["VarSel_Statistics"]] <- var_stats
    }
  }

  # Write all sheets to Excel
  writexl::write_xlsx(profile_sheets, output_path)

  cat(sprintf("✓ Exported exploration report with %d sheets\n", length(profile_sheets)))

  return(invisible(output_path))
}

#' Export final segmentation report
#'
#' DESIGN: Comprehensive multi-tab report for final solution
#' TABS: Summary, Segment_Profiles, Validation, Assignments
#'
#' @param final_result Result from run_kmeans_final()
#' @param profile_result Result from create_full_segment_profile()
#' @param validation_metrics Validation metrics list
#' @param output_path Character, output file path
#' @export
export_final_report <- function(final_result, profile_result, validation_metrics,
                                 output_path) {
  cat(sprintf("Exporting final segmentation report to: %s\n", basename(output_path)))

  data_list <- final_result$data_list
  config <- data_list$config
  k <- final_result$k
  model <- final_result$model

  # Prepare all sheets
  sheets <- list()

  # ===========================================================================
  # SHEET 1: Summary
  # ===========================================================================

  # Format clustering variables with labels
  clustering_vars_display <- if (!is.null(config$question_labels)) {
    paste(format_variable_label(config$clustering_vars, config$question_labels), collapse = ", ")
  } else {
    paste(config$clustering_vars, collapse = ", ")
  }

  summary_text <- c(
    "SEGMENTATION SUMMARY",
    "====================",
    "",
    sprintf("Project: %s", config$project_name),
    sprintf("Date: %s", Sys.Date()),
    sprintf("Analyst: %s", config$analyst_name),
    "",
    "DATA OVERVIEW",
    "-------------",
    sprintf("Total respondents: %d", data_list$n_original),
    sprintf("Valid responses: %d", nrow(data_list$data)),
    sprintf("Clustering variables: %s", clustering_vars_display),
    sprintf("Number of segments: %d", k)
  )

  # Add variable selection information if enabled
  if (config$variable_selection && !is.null(data_list$variable_selection_result)) {
    varsel <- data_list$variable_selection_result

    # Format selected variables with labels
    selected_vars_display <- if (!is.null(config$question_labels)) {
      paste(format_variable_label(varsel$selected_vars, config$question_labels), collapse = ", ")
    } else {
      paste(varsel$selected_vars, collapse = ", ")
    }

    summary_text <- c(
      summary_text,
      "",
      "VARIABLE SELECTION",
      "------------------",
      sprintf("Method: %s", varsel$method),
      sprintf("Original variables: %d", varsel$n_original),
      sprintf("Selected variables: %d", varsel$n_selected),
      sprintf("Selected: %s", selected_vars_display)
    )
  }

  # Add outlier information if enabled
  if (config$outlier_detection && !is.null(data_list$outlier_handling)) {
    summary_text <- c(
      summary_text,
      "",
      "OUTLIER DETECTION",
      "-----------------",
      sprintf("Method: %s", config$outlier_method),
      sprintf("Outliers detected: %d (%.1f%%)",
              data_list$outlier_handling$n_outliers,
              data_list$outlier_handling$pct_outliers),
      sprintf("Handling strategy: %s", config$outlier_handling)
    )
  }

  summary_text <- c(
    summary_text,
    "",
    "SEGMENTATION QUALITY",
    "--------------------",
    sprintf("Method: K-means clustering"),
    sprintf("Average silhouette: %.3f", validation_metrics$avg_silhouette),
    sprintf("Between/Total SS ratio: %.3f", validation_metrics$betweenss_totss),
    "",
    "SEGMENTS IDENTIFIED",
    "-------------------"
  )

  # Add segment summaries
  for (i in 1:k) {
    seg_name <- if (is.character(config$segment_names) && length(config$segment_names) >= i) {
      config$segment_names[i]
    } else {
      paste0("Segment ", i)
    }

    summary_text <- c(
      summary_text,
      "",
      sprintf("Segment %d: %s (%.1f%%, n=%d)",
              i, seg_name,
              profile_result$segment_sizes$Percentage[i],
              profile_result$segment_sizes$Count[i])
    )
  }

  sheets[["Summary"]] <- data.frame(Content = summary_text, stringsAsFactors = FALSE)

  # ===========================================================================
  # SHEET 2: Segment Profiles
  # ===========================================================================

  profile_export <- profile_result$clustering_profile

  # Apply question labels to Variable column if available
  if (!is.null(config$question_labels)) {
    profile_export$Variable <- format_variable_label(profile_export$Variable,
                                                     config$question_labels)
  }

  # Round numeric columns
  num_cols <- sapply(profile_export, is.numeric)
  profile_export[num_cols] <- lapply(profile_export[num_cols], function(x) round(x, 2))

  # Add segment sizes
  size_row <- data.frame(Variable = "Segment_size_n", stringsAsFactors = FALSE)
  pct_row <- data.frame(Variable = "Segment_size_pct", stringsAsFactors = FALSE)

  for (col in names(profile_export)[-1]) {
    size_row[[col]] <- NA
    pct_row[[col]] <- NA
  }

  for (i in 1:k) {
    seg_col <- paste0("Segment_", i)
    if (seg_col %in% names(size_row)) {
      size_row[[seg_col]] <- profile_result$segment_sizes$Count[i]
      pct_row[[seg_col]] <- round(profile_result$segment_sizes$Percentage[i], 1)
    }
  }

  size_row$Overall <- nrow(data_list$data)
  pct_row$Overall <- 100.0

  profile_export <- rbind(profile_export, size_row, pct_row)

  sheets[["Segment_Profiles"]] <- profile_export

  # ===========================================================================
  # SHEET 3: Validation Metrics
  # ===========================================================================

  validation_df <- data.frame(
    Metric = c(
      "Average Silhouette",
      "Total Within-cluster SS",
      "Total Between-cluster SS",
      "Between/Total SS ratio"
    ),
    Value = c(
      round(validation_metrics$avg_silhouette, 3),
      round(validation_metrics$tot_withinss, 1),
      round(validation_metrics$betweenss, 1),
      round(validation_metrics$betweenss_totss, 3)
    ),
    stringsAsFactors = FALSE
  )

  sheets[["Validation"]] <- validation_df

  # ===========================================================================
  # SHEET 4 (option# Restart R if needed (Session -> Restart R)
  setwd("/Users/duncan/Documents/Turas")
 
  # ===========================================================================

  if (config$outlier_detection && !is.null(data_list$outlier_result)) {
    # Source outlier module for create_outlier_report function
    source("modules/segment/lib/segment_outliers.R")

    outlier_report <- create_outlier_report(
      outlier_result = data_list$outlier_result,
      data = data_list$data,
      id_var = config$id_variable,
      standardized_data = as.data.frame(data_list$scaled_data),
      clustering_vars = config$clustering_vars
    )

    if (nrow(outlier_report) > 0) {
      sheets[["Outliers"]] <- outlier_report
    }
  }

  # ===========================================================================
  # SHEET 5 (optional): Variable Selection
  # ===========================================================================

  if (config$variable_selection && !is.null(data_list$variable_selection_result)) {
    varsel <- data_list$variable_selection_result

    # Selected variables sheet with labels
    selected_df <- data.frame(
      Variable = varsel$selected_vars,
      Status = "Selected",
      stringsAsFactors = FALSE
    )

    # Add labels column if available
    if (!is.null(config$question_labels)) {
      selected_df$Label <- sapply(varsel$selected_vars, function(v) {
        if (v %in% names(config$question_labels)) {
          config$question_labels[v]
        } else {
          ""
        }
      }, USE.NAMES = FALSE)
    }

    sheets[["VarSel_Selected"]] <- selected_df

    # Variable statistics sheet with labels
    if (!is.null(varsel$selection_log$variance)) {
      var_stats <- varsel$selection_log$variance$variance_df
      var_stats$selected <- var_stats$variable %in% varsel$selected_vars
      var_stats$variance <- round(var_stats$variance, 4)
      var_stats$sd <- round(var_stats$sd, 4)

      # Add labels column if available
      if (!is.null(config$question_labels)) {
        var_stats$label <- sapply(var_stats$variable, function(v) {
          if (v %in% names(config$question_labels)) {
            config$question_labels[v]
          } else {
            ""
          }
        }, USE.NAMES = FALSE)
        # Reorder columns to put label after variable
        var_stats <- var_stats[, c("variable", "label", setdiff(names(var_stats), c("variable", "label")))]
      }

      sheets[["VarSel_Statistics"]] <- var_stats
    }
  }

  # Write to Excel
  writexl::write_xlsx(sheets, output_path)

  cat(sprintf("✓ Exported final report with %d sheets\n", length(sheets)))

  return(invisible(output_path))
}

#' Create output folder with optional date stamping
#'
#' DESIGN: Creates output directory, optionally with date subfolder
#' RETURNS: Final output path to use
#'
#' @param base_folder Character, base output folder
#' @param create_dated_folder Logical, create date subfolder
#' @return Character, final output folder path
#' @export
create_output_folder <- function(base_folder, create_dated_folder = TRUE) {
  if (create_dated_folder) {
    date_str <- format(Sys.Date(), "%Y-%m-%d")
    output_folder <- file.path(base_folder, date_str)
  } else {
    output_folder <- base_folder
  }

  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
    cat(sprintf("Created output folder: %s\n", output_folder))
  }

  return(output_folder)
}
