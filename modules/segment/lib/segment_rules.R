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
    stop("Package 'rpart' required for classification rules.\n",
         "Install with: install.packages('rpart')",
         call. = FALSE)
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
