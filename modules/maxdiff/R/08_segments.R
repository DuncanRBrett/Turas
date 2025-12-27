# ==============================================================================
# MAXDIFF MODULE - SEGMENT ANALYSIS - TURAS V10.0
# ==============================================================================
# Segment-level analysis for MaxDiff results
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
# Turas v10.1 - Security fix: safe expression evaluation (2024-12)
#
# DEPENDENCIES:
# - utils.R
# ==============================================================================

SEGMENTS_VERSION <- "10.1"

# ==============================================================================
# SAFE EXPRESSION EVALUATION
# ==============================================================================

# Blacklisted function names that could be dangerous
.UNSAFE_FUNCTIONS <- c(

  "system", "system2", "shell", "shell.exec",
  "Sys.setenv", "Sys.unsetenv",
  "file.remove", "file.rename", "unlink", "file.create", "file.copy",
  "download.file", "source", "eval", "parse",
  "library", "require", "loadNamespace", "attachNamespace",
  "assign", "rm", "remove", "get", "exists",
  "writeLines", "writeChar", "writeBin", "write.csv", "write.table",
  "save", "save.image", "saveRDS",
  "setwd", "Sys.chmod", "Sys.umask",
  "options", "Sys.setlocale",
  "q", "quit", "stop", "stopifnot"
)

#' Validate expression for safe evaluation
#'
#' Checks that an R expression only contains safe operations.
#' Prevents code injection by blocking dangerous function calls.
#'
#' @param expr_text Character. Expression text to validate
#' @param allowed_vars Character vector. Variable names allowed in expression
#' @return Logical TRUE if safe, otherwise throws error
#' @keywords internal
validate_safe_expression <- function(expr_text, allowed_vars = NULL) {
  if (is.null(expr_text) || !nzchar(trimws(expr_text))) {
    return(TRUE)
  }


  # Parse the expression to check its structure
  parsed <- tryCatch({
    parse(text = expr_text)
  }, error = function(e) {
    stop(sprintf(
      "Invalid expression syntax: %s\n  Error: %s",
      expr_text, conditionMessage(e)
    ), call. = FALSE)
  })

  # Get all function calls in the expression
  expr_calls <- all.names(parsed, functions = TRUE, unique = TRUE)

  # Check for unsafe function calls
  unsafe_found <- intersect(tolower(expr_calls), tolower(.UNSAFE_FUNCTIONS))
  if (length(unsafe_found) > 0) {
    stop(sprintf(
      "Expression contains unsafe function calls: %s\n  Expression: %s",
      paste(unsafe_found, collapse = ", "), expr_text
    ), call. = FALSE)
  }

  # Check for assignment operators which could be used maliciously
  if (grepl("<-|<<-|->|->>|=(?!=)", expr_text, perl = TRUE)) {
    # Allow == and != but not assignment =
    if (grepl("(?<![=!<>])=(?!=)", expr_text, perl = TRUE)) {
      stop(sprintf(
        "Expression contains assignment operator (use == for comparison): %s",
        expr_text
      ), call. = FALSE)
    }
  }

  # If allowed_vars specified, validate only those variables are used
  if (!is.null(allowed_vars) && length(allowed_vars) > 0) {
    expr_names <- all.names(parsed, functions = FALSE, unique = TRUE)
    # Filter out operators and literals
    expr_vars <- expr_names[!expr_names %in% c(
      "==", "!=", "<", ">", "<=", ">=", "&", "|", "!",
      "+", "-", "*", "/", "^", "%%", "%/%", "%in%",
      "c", "TRUE", "FALSE", "NA", "NULL", "Inf", "NaN",
      "if", "else", "ifelse", "is.na", "is.null",
      "as.character", "as.numeric", "as.integer", "as.logical",
      "toupper", "tolower", "trimws", "nchar", "substr", "paste", "paste0",
      "sum", "mean", "min", "max", "length", "abs", "round", "floor", "ceiling"
    )]

    # Remove numeric literals
    expr_vars <- expr_vars[!grepl("^[0-9.]+$", expr_vars)]
    # Remove quoted strings (they show up as variable names after parsing)
    expr_vars <- expr_vars[!grepl("^['\"].*['\"]$", expr_vars)]

    unknown_vars <- setdiff(expr_vars, allowed_vars)
    if (length(unknown_vars) > 0) {
      stop(sprintf(
        "Expression references unknown variables: %s\n  Available: %s",
        paste(unknown_vars, collapse = ", "),
        paste(head(allowed_vars, 20), collapse = ", ")
      ), call. = FALSE)
    }
  }

  return(TRUE)
}

#' Safely evaluate expression within data context
#'
#' Evaluates an R expression after validating it for safety.
#'
#' @param expr_text Character. Expression to evaluate
#' @param data Data frame. Context for evaluation
#' @param context Character. Description for error messages
#' @return Result of expression evaluation
#' @keywords internal
safe_eval_expression <- function(expr_text, data, context = "expression") {
  # Validate expression is safe

  validate_safe_expression(expr_text, allowed_vars = names(data))

  # Parse and evaluate in controlled environment
  parsed <- parse(text = expr_text)

  result <- tryCatch({
    eval(parsed, envir = data, enclos = baseenv())
  }, error = function(e) {
    stop(sprintf(
      "Error evaluating %s: %s\n  Expression: %s",
      context, conditionMessage(e), expr_text
    ), call. = FALSE)
  })

  return(result)
}

# ==============================================================================
# MAIN SEGMENT ANALYZER
# ==============================================================================

#' Compute Segment-Level Scores
#'
#' Computes MaxDiff scores for defined segments.
#'
#' @param long_data Data frame. Long format MaxDiff data
#' @param raw_data Data frame. Original survey data with segment variables
#' @param segment_settings Data frame. Segment definitions from config
#' @param items Data frame. Items configuration
#' @param output_settings List. Output settings
#' @param verbose Logical. Print progress messages
#'
#' @return List containing:
#'   - segment_scores: Data frame with segment-level scores
#'   - segment_summary: Summary statistics by segment
#'
#' @export
compute_segment_scores <- function(long_data, raw_data, segment_settings, items,
                                   output_settings, verbose = TRUE) {

  if (is.null(segment_settings) || nrow(segment_settings) == 0) {
    if (verbose) log_message("No segments defined, skipping segment analysis", "INFO", verbose)
    return(NULL)
  }

  if (verbose) log_message("Computing segment-level scores...", "INFO", verbose)

  min_n <- output_settings$Min_Respondents_Per_Segment

  # Get unique respondent data
  resp_data <- unique(long_data[, c("resp_id", "weight")])

  # Get respondent ID variable
  resp_id_var <- names(raw_data)[1]  # Assume first column or need to get from config

  # Match respondent IDs
  if (resp_id_var %in% names(raw_data)) {
    resp_data <- merge(
      resp_data,
      raw_data,
      by.x = "resp_id",
      by.y = resp_id_var,
      all.x = TRUE
    )
  }

  # Process each segment
  all_segment_scores <- list()

  for (i in seq_len(nrow(segment_settings))) {
    seg_id <- segment_settings$Segment_ID[i]
    seg_label <- segment_settings$Segment_Label[i]
    seg_var <- segment_settings$Variable_Name[i]
    seg_def <- segment_settings$Segment_Def[i]
    include <- segment_settings$Include_in_Output[i]

    if (include != 1) next

    if (verbose) {
      log_message(sprintf("Processing segment: %s", seg_label), "INFO", verbose)
    }

    # Get segment values
    segment_results <- compute_single_segment(
      long_data = long_data,
      resp_data = resp_data,
      seg_var = seg_var,
      seg_def = seg_def,
      seg_id = seg_id,
      seg_label = seg_label,
      items = items,
      min_n = min_n,
      verbose = verbose
    )

    if (!is.null(segment_results)) {
      all_segment_scores[[seg_id]] <- segment_results
    }
  }

  if (length(all_segment_scores) == 0) {
    if (verbose) log_message("No valid segments computed", "WARN", verbose)
    return(NULL)
  }

  # Combine all segment scores
  segment_scores <- do.call(rbind, lapply(all_segment_scores, function(x) x$scores))

  # Segment summary
  segment_summary <- do.call(rbind, lapply(all_segment_scores, function(x) x$summary))

  if (verbose) {
    log_message(sprintf(
      "Segment analysis complete: %d segments, %d item-segment combinations",
      nrow(segment_summary), nrow(segment_scores)
    ), "INFO", verbose)
  }

  list(
    segment_scores = segment_scores,
    segment_summary = segment_summary
  )
}


# ==============================================================================
# SINGLE SEGMENT COMPUTATION
# ==============================================================================

#' Compute scores for a single segment
#'
#' @param long_data Data frame. Long format data
#' @param resp_data Data frame. Respondent data with segment variables
#' @param seg_var Character. Segment variable name
#' @param seg_def Character. Segment definition (R expression or empty)
#' @param seg_id Character. Segment ID
#' @param seg_label Character. Segment label
#' @param items Data frame. Items configuration
#' @param min_n Integer. Minimum respondents per segment level
#' @param verbose Logical. Print messages
#'
#' @return List with scores and summary, or NULL if invalid
#' @keywords internal
compute_single_segment <- function(long_data, resp_data, seg_var, seg_def,
                                   seg_id, seg_label, items, min_n, verbose) {

  # Check if segment variable exists
  if (!seg_var %in% names(resp_data)) {
    if (verbose) {
      log_message(sprintf(
        "Segment variable '%s' not found in data, skipping",
        seg_var
      ), "WARN", verbose)
    }
    return(NULL)
  }

  # Apply segment definition if provided
  if (!is.null(seg_def) && !is.na(seg_def) && nzchar(trimws(seg_def))) {
    # Safely evaluate expression to create segment variable
    # Uses validated evaluation to prevent code injection
    resp_data$segment_value <- tryCatch({
      safe_eval_expression(seg_def, resp_data, context = sprintf("segment '%s'", seg_id))
    }, error = function(e) {
      if (verbose) {
        log_message(sprintf(
          "Segment definition error for '%s': %s",
          seg_id, conditionMessage(e)
        ), "WARN", verbose)
      }
      return(NULL)
    })

    if (is.null(resp_data$segment_value)) {
      return(NULL)
    }
  } else {
    # Use raw variable values
    resp_data$segment_value <- resp_data[[seg_var]]
  }

  # Get segment levels
  segment_levels <- unique(resp_data$segment_value)
  segment_levels <- segment_levels[!is.na(segment_levels)]

  if (length(segment_levels) == 0) {
    if (verbose) {
      log_message(sprintf(
        "No valid segment levels for '%s'",
        seg_id
      ), "WARN", verbose)
    }
    return(NULL)
  }

  # Compute scores for each level
  level_scores <- list()
  level_summary <- list()

  for (level in segment_levels) {
    # Get respondents in this level
    level_resp <- resp_data$resp_id[resp_data$segment_value == level]
    level_resp <- level_resp[!is.na(level_resp)]
    n_level <- length(level_resp)

    if (n_level < min_n) {
      if (verbose) {
        log_message(sprintf(
          "  Segment level '%s' has only %d respondents (min: %d), skipping",
          level, n_level, min_n
        ), "INFO", verbose)
      }
      next
    }

    # Filter long data to this segment
    level_data <- long_data[long_data$resp_id %in% level_resp, ]

    if (nrow(level_data) == 0) next

    # Compute count scores for this segment
    level_count_scores <- compute_maxdiff_counts(level_data, items,
                                                  weighted = TRUE, verbose = FALSE)

    # Add segment identifiers
    level_count_scores$Segment_ID <- seg_id
    level_count_scores$Segment_Label <- seg_label
    level_count_scores$Segment_Value <- as.character(level)
    level_count_scores$Segment_N <- n_level

    level_scores[[as.character(level)]] <- level_count_scores

    # Summary for this level
    level_summary[[as.character(level)]] <- data.frame(
      Segment_ID = seg_id,
      Segment_Label = seg_label,
      Segment_Value = as.character(level),
      N = n_level,
      stringsAsFactors = FALSE
    )
  }

  if (length(level_scores) == 0) {
    return(NULL)
  }

  list(
    scores = do.call(rbind, level_scores),
    summary = do.call(rbind, level_summary)
  )
}


# ==============================================================================
# SEGMENT COMPARISON
# ==============================================================================

#' Compare utilities across segments
#'
#' Computes differences and significance tests between segment levels.
#'
#' @param segment_scores Data frame. Segment-level scores
#' @param segment_id Character. Segment ID to compare
#' @param items Data frame. Items configuration
#'
#' @return Data frame with comparison results
#' @export
compare_segment_utilities <- function(segment_scores, segment_id, items) {

  # Filter to specified segment
  seg_data <- segment_scores[segment_scores$Segment_ID == segment_id, ]

  if (nrow(seg_data) == 0) {
    return(NULL)
  }

  # Get segment levels
  levels <- unique(seg_data$Segment_Value)

  if (length(levels) < 2) {
    return(NULL)
  }

  included_items <- items$Item_ID[items$Include == 1]

  # Compare all pairs of levels
  comparisons <- list()

  for (i in 1:(length(levels) - 1)) {
    for (j in (i + 1):length(levels)) {
      level_a <- levels[i]
      level_b <- levels[j]

      # Get scores for each level
      scores_a <- seg_data[seg_data$Segment_Value == level_a, ]
      scores_b <- seg_data[seg_data$Segment_Value == level_b, ]

      for (item_id in included_items) {
        row_a <- scores_a[scores_a$Item_ID == item_id, ]
        row_b <- scores_b[scores_b$Item_ID == item_id, ]

        if (nrow(row_a) == 0 || nrow(row_b) == 0) next

        # Calculate difference
        diff <- row_a$Net_Score - row_b$Net_Score

        # Approximate SE of difference (assuming independence)
        # Would need bootstrap for proper SE
        se_diff <- NA_real_

        comparisons[[length(comparisons) + 1]] <- data.frame(
          Segment_ID = segment_id,
          Item_ID = item_id,
          Level_A = level_a,
          Level_B = level_b,
          Score_A = row_a$Net_Score,
          Score_B = row_b$Net_Score,
          Difference = diff,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(comparisons) == 0) {
    return(NULL)
  }

  do.call(rbind, comparisons)
}


# ==============================================================================
# SEGMENT SIGNIFICANCE TESTING
# ==============================================================================

#' Test significance of segment differences
#'
#' Uses bootstrap resampling to test if item utilities differ by segment.
#'
#' @param long_data Data frame. Long format data
#' @param resp_data Data frame. Respondent data with segments
#' @param segment_var Character. Segment variable
#' @param items Data frame. Items configuration
#' @param n_boot Integer. Bootstrap iterations
#' @param conf_level Numeric. Confidence level
#'
#' @return Data frame with test results
#' @export
test_segment_differences <- function(long_data, resp_data, segment_var, items,
                                     n_boot = 1000, conf_level = 0.95) {

  # Get segment levels
  segment_levels <- unique(resp_data[[segment_var]])
  segment_levels <- segment_levels[!is.na(segment_levels)]

  if (length(segment_levels) != 2) {
    # Only support two-group comparison for now
    return(NULL)
  }

  level_a <- segment_levels[1]
  level_b <- segment_levels[2]

  included_items <- items$Item_ID[items$Include == 1]

  # Bootstrap
  boot_diffs <- matrix(NA, nrow = n_boot, ncol = length(included_items))
  colnames(boot_diffs) <- included_items

  resp_a <- resp_data$resp_id[resp_data[[segment_var]] == level_a]
  resp_b <- resp_data$resp_id[resp_data[[segment_var]] == level_b]

  for (b in seq_len(n_boot)) {
    # Bootstrap sample within each group
    boot_resp_a <- sample(resp_a, length(resp_a), replace = TRUE)
    boot_resp_b <- sample(resp_b, length(resp_b), replace = TRUE)

    # Calculate scores for each group
    data_a <- long_data[long_data$resp_id %in% boot_resp_a, ]
    data_b <- long_data[long_data$resp_id %in% boot_resp_b, ]

    for (item_id in included_items) {
      # Group A
      item_a <- data_a[data_a$item_id == item_id, ]
      if (nrow(item_a) > 0) {
        best_a <- 100 * mean(item_a$is_best)
        worst_a <- 100 * mean(item_a$is_worst)
        score_a <- best_a - worst_a
      } else {
        score_a <- NA
      }

      # Group B
      item_b <- data_b[data_b$item_id == item_id, ]
      if (nrow(item_b) > 0) {
        best_b <- 100 * mean(item_b$is_best)
        worst_b <- 100 * mean(item_b$is_worst)
        score_b <- best_b - worst_b
      } else {
        score_b <- NA
      }

      boot_diffs[b, item_id] <- score_a - score_b
    }
  }

  # Calculate CIs and p-values
  alpha <- 1 - conf_level
  results <- data.frame(
    Item_ID = included_items,
    stringsAsFactors = FALSE
  )

  for (item_id in included_items) {
    diffs <- boot_diffs[, item_id]
    diffs <- diffs[!is.na(diffs)]

    if (length(diffs) > 0) {
      results$Difference_Mean[results$Item_ID == item_id] <- mean(diffs)
      results$Difference_SE[results$Item_ID == item_id] <- sd(diffs)
      results$CI_Lower[results$Item_ID == item_id] <- quantile(diffs, alpha / 2)
      results$CI_Upper[results$Item_ID == item_id] <- quantile(diffs, 1 - alpha / 2)

      # P-value (proportion of bootstrap samples crossing zero)
      p_value <- 2 * min(mean(diffs > 0), mean(diffs < 0))
      results$P_Value[results$Item_ID == item_id] <- p_value

      results$Significant[results$Item_ID == item_id] <-
        results$CI_Lower[results$Item_ID == item_id] > 0 |
        results$CI_Upper[results$Item_ID == item_id] < 0
    }
  }

  results$Level_A <- level_a
  results$Level_B <- level_b

  return(results)
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff segments module loaded (v%s)", SEGMENTS_VERSION))
