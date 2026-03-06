# ==============================================================================
# TURAS SEGMENTATION MODULE - CLASSIFICATION RULES
# ==============================================================================
# Feature 4: Generate plain-English rules for segment membership
# Part of Turas Segmentation Module
# ==============================================================================

#' Generate Segment Classification Rules
#'
#' Creates plain-English decision rules for segment membership using
#' recursive partitioning (decision tree). Useful for explaining segmentation
#' logic to non-technical stakeholders.
#'
#' @param data Data frame with all variables
#' @param clusters Integer vector of segment assignments
#' @param clustering_vars Character vector of clustering variable names
#' @param question_labels Named vector of question labels (optional)
#' @param max_depth Integer, maximum tree depth (default: 3)
#' @param segment_names Character vector of segment names (optional)
#'
#' @return List with tree, rules_text, rules_df, accuracy
#' @export
#' @examples
#' rules <- generate_segment_rules(
#'   data = survey_data,
#'   clusters = result$clusters,
#'   clustering_vars = config$clustering_vars,
#'   max_depth = 3
#' )
#' print_segment_rules(rules)
generate_segment_rules <- function(data, clusters, clustering_vars,
                                    question_labels = NULL, max_depth = 3,
                                    segment_names = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("GENERATING SEGMENT CLASSIFICATION RULES\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # ===========================================================================
  # CHECK RPART PACKAGE
  # ===========================================================================

  if (!requireNamespace("rpart", quietly = TRUE)) {
    segment_refuse(
      code = "PKG_RPART_MISSING",
      title = "Package rpart Required",
      problem = "Package 'rpart' is not installed.",
      why_it_matters = "The rpart package is required for generating classification rules using decision trees.",
      how_to_fix = "Install the package with: install.packages('rpart')"
    )
  }

  # ===========================================================================
  # PREPARE DATA
  # ===========================================================================

  # Create analysis data frame
  analysis_data <- data[, clustering_vars, drop = FALSE]
  analysis_data$segment <- as.factor(clusters)

  # Remove rows with missing values
  complete_rows <- complete.cases(analysis_data)
  analysis_data <- analysis_data[complete_rows, ]

  k <- length(unique(analysis_data$segment))

  cat(sprintf("Building decision tree (max depth: %d)...\n", max_depth))
  cat(sprintf("  Respondents: %d\n", nrow(analysis_data)))
  cat(sprintf("  Variables: %d\n", length(clustering_vars)))
  cat(sprintf("  Segments: %d\n\n", k))

  # ===========================================================================
  # BUILD DECISION TREE
  # ===========================================================================

  # Build formula
  formula_str <- paste("segment ~", paste(clustering_vars, collapse = " + "))
  tree_formula <- as.formula(formula_str)

  # Fit decision tree
  tree <- rpart::rpart(
    tree_formula,
    data = analysis_data,
    method = "class",
    control = rpart::rpart.control(
      maxdepth = max_depth,
      minsplit = 20,
      cp = 0.01
    )
  )

  # ===========================================================================
  # CALCULATE ACCURACY
  # ===========================================================================

  predictions <- predict(tree, analysis_data, type = "class")
  accuracy <- mean(predictions == analysis_data$segment)

  cat(sprintf("✓ Decision tree built\n"))
  cat(sprintf("  Overall classification accuracy: %.1f%%\n\n", accuracy * 100))

  # ===========================================================================
  # EXTRACT RULES
  # ===========================================================================

  rules_list <- extract_rules_from_tree(tree, question_labels, segment_names)

  # Create rules data frame
  rules_df <- create_rules_dataframe(tree, analysis_data, segment_names)

  # ===========================================================================
  # RETURN RESULTS
  # ===========================================================================

  return(list(
    tree = tree,
    rules_text = rules_list$rules_text,
    rules_df = rules_df,
    accuracy = accuracy,
    segment_accuracy = rules_list$segment_accuracy,
    n_respondents = nrow(analysis_data)
  ))
}


#' Extract Rules from Decision Tree
#'
#' Internal function to convert rpart tree to text rules
#'
#' @param tree rpart tree object
#' @param question_labels Named vector of question labels
#' @param segment_names Character vector of segment names
#' @return List with rules_text and segment_accuracy
#' @keywords internal
extract_rules_from_tree <- function(tree, question_labels = NULL,
                                     segment_names = NULL) {

  # Get tree frame
  frame <- tree$frame
  leaves <- frame[frame$var == "<leaf>", ]

  rules_text <- character(0)
  segment_accuracy <- numeric(0)

  # For each leaf, trace path back to root
  leaf_indices <- which(frame$var == "<leaf>")

  for (i in seq_along(leaf_indices)) {
    leaf_idx <- leaf_indices[i]

    # Get predicted class for this leaf
    predicted_class <- which.max(frame$yval2[leaf_idx, paste0("nodeprob.", 1:ncol(frame$yval2))])

    # Get segment name
    if (!is.null(segment_names) && length(segment_names) >= predicted_class) {
      seg_name <- segment_names[predicted_class]
    } else {
      seg_name <- paste0("Segment ", predicted_class)
    }

    # Get path to this leaf
    path <- get_path_to_node(tree, leaf_idx)

    # Format rule
    if (length(path) > 0) {
      rule_conditions <- format_rule_conditions(path, question_labels)
      rule_text <- sprintf("IF %s THEN %s", rule_conditions, seg_name)
    } else {
      rule_text <- sprintf("DEFAULT: %s", seg_name)
    }

    # Get accuracy for this rule (proportion correctly classified at leaf)
    leaf_n <- frame$n[leaf_idx]
    class_probs <- frame$yval2[leaf_idx, ]
    max_prob <- max(class_probs[grep("^prob", names(class_probs))], na.rm = TRUE)
    leaf_accuracy <- max_prob

    rules_text <- c(rules_text, rule_text)
    segment_accuracy <- c(segment_accuracy, leaf_accuracy)
    names(segment_accuracy)[length(segment_accuracy)] <- seg_name
  }

  return(list(
    rules_text = rules_text,
    segment_accuracy = segment_accuracy
  ))
}


#' Get Path to Node in Tree
#'
#' Internal function to trace path from root to specified node
#'
#' @param tree rpart tree object
#' @param node_idx Index of target node
#' @return List of path conditions
#' @keywords internal
get_path_to_node <- function(tree, node_idx) {
  # Use rpart's path.rpart function if available
  frame <- tree$frame
  splits <- tree$splits

  # Simple approach: just return the variable and split info at parent nodes
  # This is a simplified version - full path extraction is complex

  path <- list()
  current <- node_idx
  rownames_frame <- as.integer(rownames(frame))
  current_row <- rownames_frame[current]

  while (current_row > 1) {
    # Find parent
    parent_row <- current_row %/% 2
    parent_idx <- which(rownames_frame == parent_row)

    if (length(parent_idx) == 0) break

    var_name <- as.character(frame$var[parent_idx])
    if (var_name == "<leaf>") break

    # Determine direction (left or right child)
    is_left_child <- (current_row %% 2 == 0)

    # Get split value from splits matrix
    split_info <- splits[splits[, "count"] > 0, , drop = FALSE]
    var_splits <- split_info[rownames(split_info) == var_name, , drop = FALSE]

    if (nrow(var_splits) > 0) {
      split_value <- var_splits[1, "index"]
      if (is_left_child) {
        path <- c(path, list(list(var = var_name, direction = "<", value = split_value)))
      } else {
        path <- c(path, list(list(var = var_name, direction = ">=", value = split_value)))
      }
    }

    current_row <- parent_row
    current_idx <- parent_idx
  }

  return(rev(path))
}


#' Format Rule Conditions
#'
#' Convert path conditions to readable text
#'
#' @param path List of path conditions
#' @param question_labels Named vector of question labels
#' @return Character string of formatted conditions
#' @keywords internal
format_rule_conditions <- function(path, question_labels = NULL) {
  if (length(path) == 0) return("TRUE")

  conditions <- sapply(path, function(p) {
    var_display <- if (!is.null(question_labels) && p$var %in% names(question_labels)) {
      paste0(p$var, " (", substr(question_labels[p$var], 1, 30), ")")
    } else {
      p$var
    }
    sprintf("%s %s %.1f", var_display, p$direction, p$value)
  })

  paste(conditions, collapse = " AND ")
}


#' Create Rules Data Frame
#'
#' Create a data frame summarizing rules for export
#'
#' @param tree rpart tree object
#' @param data Analysis data
#' @param segment_names Character vector of segment names
#' @return Data frame with rule summaries
#' @keywords internal
create_rules_dataframe <- function(tree, data, segment_names = NULL) {

  # Get predictions
  predictions <- predict(tree, data, type = "class")

  # Create summary
  k <- length(unique(data$segment))

  rules_df <- data.frame(
    Segment = integer(0),
    Segment_Name = character(0),
    N = integer(0),
    Pct = numeric(0),
    Accuracy = numeric(0),
    stringsAsFactors = FALSE
  )

  for (seg in 1:k) {
    actual_seg <- data$segment == seg
    predicted_seg <- predictions == seg

    n_segment <- sum(actual_seg)
    pct_segment <- 100 * n_segment / nrow(data)
    seg_accuracy <- sum(actual_seg & predicted_seg) / sum(actual_seg)

    seg_name <- if (!is.null(segment_names) && length(segment_names) >= seg) {
      segment_names[seg]
    } else {
      paste0("Segment ", seg)
    }

    rules_df <- rbind(rules_df, data.frame(
      Segment = seg,
      Segment_Name = seg_name,
      N = n_segment,
      Pct = round(pct_segment, 1),
      Accuracy = round(seg_accuracy * 100, 1),
      stringsAsFactors = FALSE
    ))
  }

  return(rules_df)
}


#' Print Segment Rules
#'
#' Pretty-print classification rules to console
#'
#' @param rules_result Result from generate_segment_rules()
#' @export
print_segment_rules <- function(rules_result) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("SEGMENT CLASSIFICATION RULES\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Print each segment's summary
  rules_df <- rules_result$rules_df

  for (i in 1:nrow(rules_df)) {
    seg_name <- rules_df$Segment_Name[i]
    n <- rules_df$N[i]
    pct <- rules_df$Pct[i]
    acc <- rules_df$Accuracy[i]

    cat(sprintf("%s: %.0f%% of respondents\n", seg_name, pct))
    cat(sprintf("  n = %d, Classification accuracy: %.0f%%\n\n", n, acc))
  }

  cat(sprintf("Overall rule accuracy: %.0f%%\n", rules_result$accuracy * 100))
  cat("\n")

  # Print rules text if available
  if (length(rules_result$rules_text) > 0) {
    cat("Decision Rules:\n")
    for (rule in rules_result$rules_text) {
      cat(sprintf("  %s\n", rule))
    }
    cat("\n")
  }
}


#' Format Single Rule to Plain English
#'
#' Convert a rule condition to readable format
#'
#' @param rule Rule string
#' @param question_labels Named vector of question labels
#' @return Formatted rule string
#' @export
format_rule_text <- function(rule, question_labels = NULL) {
  # Replace variable names with labels if available
  if (!is.null(question_labels)) {
    for (var in names(question_labels)) {
      if (grepl(var, rule)) {
        label <- question_labels[var]
        rule <- gsub(var, paste0(var, " (", substr(label, 1, 30), ")"), rule)
      }
    }
  }
  return(rule)
}


#' Export Rules to Text File
#'
#' Save classification rules to a text file
#'
#' @param rules_result Result from generate_segment_rules()
#' @param output_path Path to save text file
#' @export
export_rules_text <- function(rules_result, output_path) {

  lines <- c(
    "SEGMENT CLASSIFICATION RULES",
    paste(rep("=", 60), collapse = ""),
    "",
    sprintf("Generated: %s", Sys.time()),
    sprintf("Overall Accuracy: %.1f%%", rules_result$accuracy * 100),
    "",
    paste(rep("-", 60), collapse = ""),
    "SEGMENT SUMMARY",
    paste(rep("-", 60), collapse = ""),
    ""
  )

  # Add segment summaries
  for (i in 1:nrow(rules_result$rules_df)) {
    row <- rules_result$rules_df[i, ]
    lines <- c(lines,
               sprintf("%s: %.0f%% of respondents (n=%d)",
                       row$Segment_Name, row$Pct, row$N),
               sprintf("  Classification accuracy: %.0f%%", row$Accuracy),
               ""
    )
  }

  # Add rules
  lines <- c(lines,
             paste(rep("-", 60), collapse = ""),
             "DECISION RULES",
             paste(rep("-", 60), collapse = ""),
             ""
  )

  for (rule in rules_result$rules_text) {
    lines <- c(lines, rule, "")
  }

  # Write file
  writeLines(lines, output_path)
  cat(sprintf("✓ Rules exported to: %s\n", output_path))
}


# ==============================================================================
# GOLDEN QUESTIONS - RANDOM FOREST VARIABLE IMPORTANCE
# ==============================================================================

#' Identify Golden Questions for Segment Prediction
#'
#' Uses Random Forest to identify the top N survey questions that most
#' accurately predict segment membership. These "golden questions" can be
#' used in short-form surveys or at point-of-sale to classify new
#' respondents into segments without a full survey.
#'
#' @param data Data frame of original (unscaled) survey variables used in clustering
#' @param clusters Integer vector of segment assignments
#' @param segment_names Named character vector of segment labels
#' @param n_top Integer, number of top questions to return (default 5)
#' @param n_trees Integer, number of trees in Random Forest (default 500)
#' @return List with:
#'   \item{status}{"PASS", "PARTIAL", or "SKIPPED"}
#'   \item{top_questions}{Data frame with variable, importance, rank}
#'   \item{accuracy}{Overall OOB classification accuracy}
#'   \item{confusion_matrix}{Confusion matrix from OOB predictions}
#'   \item{per_segment_accuracy}{Per-segment classification accuracy}
#'   \item{n_trees}{Number of trees used}
#' @keywords internal
identify_golden_questions <- function(data,
                                      clusters,
                                      segment_names = NULL,
                                      n_top = 5,
                                      n_trees = 500) {

  # ===========================================================================
  # CHECK RANDOMFOREST PACKAGE
  # ===========================================================================

  if (!requireNamespace("randomForest", quietly = TRUE)) {
    cat("\n")
    cat("  [SKIPPED] Golden Questions: Package 'randomForest' not installed.\n")
    cat("  Install with: install.packages('randomForest')\n\n")
    return(list(
      status = "SKIPPED",
      message = "Package 'randomForest' not installed. Install with: install.packages('randomForest')"
    ))
  }

  cat("\n")
  cat("  Golden Questions (Random Forest Variable Importance)\n")
  cat("  ", rep("\u2500", 53), "\n", sep = "")

  # ===========================================================================
  # VALIDATE INPUTS
  # ===========================================================================

  if (!is.data.frame(data) && !is.matrix(data)) {
    segment_refuse(
      code = "DATA_GOLDEN_INVALID_DATA",
      title = "Invalid data for Golden Questions",
      problem = "Parameter 'data' must be a data frame or matrix.",
      why_it_matters = "Random Forest requires a rectangular data structure of predictor variables.",
      how_to_fix = "Pass the original (unscaled) data frame used for clustering."
    )
  }

  if (is.null(clusters) || length(clusters) != nrow(data)) {
    segment_refuse(
      code = "DATA_GOLDEN_CLUSTER_MISMATCH",
      title = "Cluster vector length mismatch",
      problem = sprintf(
        "Length of 'clusters' (%s) does not match nrow(data) (%d).",
        if (is.null(clusters)) "NULL" else as.character(length(clusters)),
        nrow(data)
      ),
      why_it_matters = "Each row in the data must have a corresponding segment assignment.",
      how_to_fix = "Ensure 'clusters' is an integer vector with one entry per row of 'data'."
    )
  }

  if (length(unique(clusters)) < 2) {
    segment_refuse(
      code = "DATA_GOLDEN_TOO_FEW_SEGMENTS",
      title = "Too few segments for Golden Questions",
      problem = sprintf("Only %d unique segment(s) found. Need at least 2.", length(unique(clusters))),
      why_it_matters = "Classification requires at least two distinct classes to discriminate.",
      how_to_fix = "Provide a cluster solution with 2 or more segments."
    )
  }

  # ===========================================================================
  # PREPARE DATA
  # ===========================================================================

  # Coerce to data frame if matrix
  if (is.matrix(data)) {
    data <- as.data.frame(data)
  }

  # Convert clusters to factor for classification
  cluster_factor <- as.factor(clusters)

  # Remove rows with NA in data or clusters

  complete_mask <- complete.cases(data) & !is.na(clusters)
  n_removed <- sum(!complete_mask)
  n_total <- length(clusters)
  pct_removed <- 100 * n_removed / n_total

  if (n_removed > 0) {
    cat(sprintf("  Removed %d rows with NA values (%.1f%% of data)\n", n_removed, pct_removed))
  }

  if (pct_removed > 10) {
    cat("  WARNING: >10% of rows removed due to missing values.\n")
    cat("  Consider imputing missing data before running Golden Questions.\n")
  }

  clean_data <- data[complete_mask, , drop = FALSE]
  clean_clusters <- cluster_factor[complete_mask]

  # Drop any factor levels that no longer exist after NA removal
  clean_clusters <- droplevels(clean_clusters)

  if (nrow(clean_data) < 10) {
    segment_refuse(
      code = "DATA_GOLDEN_TOO_FEW_ROWS",
      title = "Too few complete rows for Random Forest",
      problem = sprintf("Only %d complete rows remain after removing NAs.", nrow(clean_data)),
      why_it_matters = "Random Forest needs sufficient data to estimate variable importance reliably.",
      how_to_fix = "Provide a dataset with at least 10 complete rows, or impute missing values."
    )
  }

  # Cap n_top at number of variables
  n_vars <- ncol(clean_data)
  n_top <- min(n_top, n_vars)

  cat(sprintf("  Respondents: %d\n", nrow(clean_data)))
  cat(sprintf("  Variables: %d\n", n_vars))
  cat(sprintf("  Segments: %d\n", length(levels(clean_clusters))))
  cat(sprintf("  Trees: %d\n", n_trees))
  cat(sprintf("  Top questions requested: %d\n\n", n_top))

  # ===========================================================================
  # TRAIN RANDOM FOREST
  # ===========================================================================

  rf_result <- tryCatch({

    model <- randomForest::randomForest(
      x = clean_data,
      y = clean_clusters,
      ntree = n_trees,
      importance = TRUE
    )

    # =========================================================================
    # EXTRACT IMPORTANCE
    # =========================================================================

    imp_matrix <- randomForest::importance(model)
    mean_decrease_accuracy <- imp_matrix[, "MeanDecreaseAccuracy"]

    # Sort descending
    sorted_idx <- order(mean_decrease_accuracy, decreasing = TRUE)
    top_idx <- sorted_idx[seq_len(n_top)]

    # Total importance for normalization
    total_importance <- sum(mean_decrease_accuracy)

    top_questions <- data.frame(
      variable = names(mean_decrease_accuracy)[top_idx],
      importance = round(mean_decrease_accuracy[top_idx], 4),
      pct_of_total = if (total_importance > 0) {
        round(100 * mean_decrease_accuracy[top_idx] / total_importance, 1)
      } else {
        rep(0, n_top)
      },
      rank = seq_len(n_top),
      stringsAsFactors = FALSE
    )

    # =========================================================================
    # CALCULATE OOB ACCURACY
    # =========================================================================

    # model$confusion has rows = actual, cols = predicted, plus a class.error column
    confusion_full <- model$confusion
    # Separate class.error column from the confusion counts
    class_error_col <- confusion_full[, "class.error"]
    confusion_counts <- confusion_full[, -ncol(confusion_full), drop = FALSE]

    # Overall OOB accuracy
    correct <- sum(diag(confusion_counts))
    total <- sum(confusion_counts)
    oob_accuracy <- correct / total

    # Per-segment accuracy (1 - class.error)
    per_segment_accuracy <- 1 - class_error_col

    # Apply segment names if provided
    if (!is.null(segment_names)) {
      seg_levels <- levels(clean_clusters)
      name_map <- character(length(seg_levels))
      for (i in seq_along(seg_levels)) {
        lvl <- seg_levels[i]
        if (lvl %in% names(segment_names)) {
          name_map[i] <- segment_names[lvl]
        } else if (i <= length(segment_names)) {
          name_map[i] <- segment_names[i]
        } else {
          name_map[i] <- paste0("Segment ", lvl)
        }
      }
      names(per_segment_accuracy) <- name_map
    }

    # =========================================================================
    # BUILD RESULT
    # =========================================================================

    list(
      status = "PASS",
      top_questions = top_questions,
      accuracy = round(oob_accuracy, 4),
      confusion_matrix = confusion_counts,
      per_segment_accuracy = round(per_segment_accuracy, 4),
      n_trees = n_trees,
      n_respondents = nrow(clean_data),
      n_removed = n_removed,
      all_importance = sort(mean_decrease_accuracy, decreasing = TRUE)
    )

  }, error = function(e) {

    cat(sprintf("  WARNING: Random Forest failed: %s\n", conditionMessage(e)))
    cat("  Returning partial result.\n\n")

    list(
      status = "PARTIAL",
      message = sprintf("Random Forest model fitting failed: %s", conditionMessage(e)),
      top_questions = NULL,
      accuracy = NULL,
      confusion_matrix = NULL,
      per_segment_accuracy = NULL,
      n_trees = n_trees,
      n_respondents = nrow(clean_data),
      n_removed = n_removed
    )

  })

  # ===========================================================================
  # CONSOLE SUMMARY
  # ===========================================================================

  if (rf_result$status == "PASS") {
    cat(sprintf("  Overall OOB accuracy: %.1f%%\n\n", rf_result$accuracy * 100))
    format_golden_questions_summary(rf_result, segment_names)
  }

  return(rf_result)
}


#' Format Golden Questions Summary for Console
#'
#' Prints a clean, tabular summary of golden question results to the console.
#' Designed for use in the Shiny console output where users review analysis
#' results.
#'
#' @param golden_result Result list from \code{identify_golden_questions()}
#' @param segment_names Named character vector of segment labels (optional)
#' @return Invisible NULL. Called for side-effect (console output).
#' @keywords internal
format_golden_questions_summary <- function(golden_result, segment_names = NULL) {

  if (is.null(golden_result) || golden_result$status == "SKIPPED") {
    cat("  Golden Questions: skipped (see message above)\n")
    return(invisible(NULL))
  }

  if (golden_result$status == "PARTIAL") {
    cat("  Golden Questions: partial result (Random Forest failed)\n")
    if (!is.null(golden_result$message)) {
      cat(sprintf("  Reason: %s\n", golden_result$message))
    }
    return(invisible(NULL))
  }

  # ---------------------------------------------------------------------------
  # Top questions table
  # ---------------------------------------------------------------------------

  tq <- golden_result$top_questions

  # Calculate column widths
  max_var_width <- max(nchar(tq$variable), nchar("Variable"))
  max_var_width <- min(max_var_width, 35)  # cap at 35 chars

  header <- sprintf("  %-4s  %-*s  %10s   %10s",
                     "Rank", max_var_width, "Variable", "Importance", "% of Total")
  separator <- paste0("  ", paste(rep("\u2500", nchar(header) - 2), collapse = ""))

  cat(header, "\n")
  cat(separator, "\n")

  for (i in seq_len(nrow(tq))) {
    var_display <- tq$variable[i]
    if (nchar(var_display) > max_var_width) {
      var_display <- paste0(substr(var_display, 1, max_var_width - 3), "...")
    }
    cat(sprintf("  %4d  %-*s  %10.2f   %9.1f%%\n",
                tq$rank[i], max_var_width, var_display,
                tq$importance[i], tq$pct_of_total[i]))
  }

  cat("\n")

  # ---------------------------------------------------------------------------
  # Per-segment accuracy
  # ---------------------------------------------------------------------------

  if (!is.null(golden_result$per_segment_accuracy)) {
    cat("  Per-Segment OOB Accuracy:\n")

    psa <- golden_result$per_segment_accuracy
    seg_labels <- names(psa)
    if (is.null(seg_labels)) {
      seg_labels <- paste0("Segment ", seq_along(psa))
    }

    max_label_width <- max(nchar(seg_labels), nchar("Segment"))

    for (i in seq_along(psa)) {
      cat(sprintf("    %-*s  %.1f%%\n", max_label_width, seg_labels[i], psa[i] * 100))
    }
    cat("\n")
  }

  return(invisible(NULL))
}
