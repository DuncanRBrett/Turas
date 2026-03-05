# ==============================================================================
# TURAS KEY DRIVER - ENHANCED SEGMENT COMPARISON
# ==============================================================================
#
# Purpose: Compare driver importance across customer segments
# Version: Turas v10.1
# Date: 2025-12
#
# Provides:
#   - build_importance_comparison_matrix()  : Wide comparison table across segments
#   - classify_drivers()                    : Universal / Segment-Specific / Mixed / Low Priority
#   - generate_segment_insights()           : Plain-English insight strings
#   - run_segment_importance_comparison()   : End-to-end orchestrator
#
# ==============================================================================


# ==============================================================================
# 1. BUILD IMPORTANCE COMPARISON MATRIX
# ==============================================================================

#' Build Wide Comparison Matrix of Driver Importance Across Segments
#'
#' Takes a named list of per-segment importance data frames and returns a single
#' wide data frame with one row per driver and paired Pct / Rank columns for
#' every segment, sorted by overall mean importance descending.
#'
#' @param results_by_segment A named list where each element is a data.frame
#'   with at least columns \code{Driver} and \code{Importance_Pct}.
#'   Names of the list are used as segment labels.
#'
#' @return A data.frame with columns:
#'   \item{Driver}{Driver variable name}
#'   \item{<Segment>_Pct}{Importance percentage for that segment}
#'   \item{<Segment>_Rank}{Rank within that segment (1 = most important)}
#'   \item{Mean_Pct}{Mean importance across all segments}
#'   Rows are sorted by \code{Mean_Pct} descending.
#'
#' @examples
#' \dontrun{
#'   seg_list <- list(
#'     Premium = data.frame(Driver = c("Price", "Quality"), Importance_Pct = c(35, 25)),
#'     Budget  = data.frame(Driver = c("Price", "Quality"), Importance_Pct = c(45, 15))
#'   )
#'   mat <- build_importance_comparison_matrix(seg_list)
#' }
#'
#' @keywords internal
build_importance_comparison_matrix <- function(results_by_segment) {

  # --- Input validation ---
  if (!is.list(results_by_segment) || length(results_by_segment) == 0) {
    keydriver_refuse(
      code = "DATA_SEGMENT_RESULTS_EMPTY",
      title = "No Segment Results Provided",
      problem = "results_by_segment must be a non-empty named list of data frames.",
      why_it_matters = "Cannot build a comparison matrix without at least one segment.",
      how_to_fix = "Provide a named list where each element is a data.frame with Driver and Importance_Pct columns."
    )
  }

  segment_names <- names(results_by_segment)
  if (is.null(segment_names) || any(!nzchar(segment_names))) {
    keydriver_refuse(
      code = "DATA_SEGMENT_NAMES_MISSING",
      title = "Segment Names Missing",
      problem = "results_by_segment must be a named list (each element needs a name).",
      why_it_matters = "Segment names are used as column labels in the comparison matrix.",
      how_to_fix = "Ensure names(results_by_segment) returns non-empty strings for every element."
    )
  }

  # Collect the universe of drivers across all segments
  all_drivers <- unique(unlist(lapply(results_by_segment, function(df) {
    if (!"Driver" %in% names(df)) return(character(0))
    as.character(df$Driver)
  })))

  if (length(all_drivers) == 0) {
    keydriver_refuse(
      code = "DATA_NO_DRIVERS_IN_SEGMENTS",
      title = "No Drivers Found in Segment Results",
      problem = "None of the segment data frames contain a 'Driver' column with values.",
      why_it_matters = "Cannot compare driver importance without driver names.",
      how_to_fix = "Each segment data.frame must have a 'Driver' column listing driver variable names."
    )
  }

  # Start with the driver column
  result <- data.frame(Driver = all_drivers, stringsAsFactors = FALSE)

  # Append Pct and Rank columns for each segment

  for (seg in segment_names) {
    seg_df <- results_by_segment[[seg]]

    # Look up importance for each driver in this segment
    pct_col <- vapply(all_drivers, function(drv) {
      idx <- match(drv, as.character(seg_df$Driver))
      if (is.na(idx)) NA_real_ else as.numeric(seg_df$Importance_Pct[idx])
    }, numeric(1))

    # Rank within segment (NAs get NA rank)
    rank_col <- rep(NA_real_, length(pct_col))
    valid_idx <- !is.na(pct_col)
    if (any(valid_idx)) {
      rank_col[valid_idx] <- rank(-pct_col[valid_idx], ties.method = "min")
    }

    result[[paste0(seg, "_Pct")]]  <- pct_col
    result[[paste0(seg, "_Rank")]] <- as.integer(rank_col)
  }

  # Mean importance across segments (ignoring NAs)
  pct_cols <- paste0(segment_names, "_Pct")
  result$Mean_Pct <- rowMeans(result[, pct_cols, drop = FALSE], na.rm = TRUE)

  # Sort by mean importance descending
  result <- result[order(-result$Mean_Pct), ]
  rownames(result) <- NULL

  result
}


# ==============================================================================
# 2. CLASSIFY DRIVERS
# ==============================================================================

#' Classify Drivers by Cross-Segment Importance Pattern
#'
#' Examines the comparison matrix and assigns each driver to one of four
#' categories based on how consistently important it is across segments.
#'
#' @param comparison_matrix A data.frame produced by
#'   \code{\link{build_importance_comparison_matrix}}.
#' @param top_n Integer. A driver must be within the top \code{top_n} ranks
#'   in a segment to be considered "important" there. Default 3.
#' @param rank_diff_threshold Integer. Minimum rank difference between the
#'   best and worst segment rank for a driver to qualify as "Segment-Specific".
#'   Default 3.
#'
#' @return A data.frame with columns:
#'   \item{Driver}{Driver variable name}
#'   \item{Classification}{One of "Universal", "Segment-Specific", "Mixed",
#'     or "Low Priority"}
#'   \item{Description}{Plain-English explanation of the classification}
#'
#' @examples
#' \dontrun{
#'   classes <- classify_drivers(comparison_matrix, top_n = 3)
#' }
#'
#' @keywords internal
classify_drivers <- function(comparison_matrix,
                             top_n = 3,
                             rank_diff_threshold = 3) {

  if (!is.data.frame(comparison_matrix) || nrow(comparison_matrix) == 0) {
    keydriver_refuse(
      code = "DATA_COMPARISON_MATRIX_EMPTY",
      title = "Empty Comparison Matrix",
      problem = "comparison_matrix must be a non-empty data.frame.",
      why_it_matters = "Cannot classify drivers without comparison data.",
      how_to_fix = "Run build_importance_comparison_matrix() first and pass the result here."
    )
  }

  # Identify rank columns
  rank_cols <- grep("_Rank$", names(comparison_matrix), value = TRUE)
  if (length(rank_cols) == 0) {
    keydriver_refuse(
      code = "DATA_NO_RANK_COLUMNS",
      title = "No Rank Columns in Comparison Matrix",
      problem = "comparison_matrix has no columns ending in '_Rank'.",
      why_it_matters = "Classification depends on per-segment rank columns.",
      how_to_fix = "Ensure comparison_matrix was produced by build_importance_comparison_matrix()."
    )
  }

  n_segments <- length(rank_cols)
  n_drivers  <- nrow(comparison_matrix)
  # Half-way point for Low Priority threshold
  half_n <- ceiling(n_drivers / 2)

  classifications <- character(n_drivers)
  descriptions    <- character(n_drivers)

  for (i in seq_len(n_drivers)) {
    drv   <- comparison_matrix$Driver[i]
    ranks <- as.integer(comparison_matrix[i, rank_cols])
    ranks_valid <- ranks[!is.na(ranks)]

    if (length(ranks_valid) == 0) {
      classifications[i] <- "Low Priority"
      descriptions[i]    <- sprintf("%s has no valid rank data across segments", drv)
      next
    }

    best_rank  <- min(ranks_valid)
    worst_rank <- max(ranks_valid)
    rank_diff  <- worst_rank - best_rank

    in_top_n     <- ranks_valid <= top_n
    all_top_n    <- all(in_top_n)
    any_top_n    <- any(in_top_n)
    all_bottom   <- all(ranks_valid > half_n)

    if (all_top_n) {
      # Universal: top N in every segment
      rank_str <- paste(ranks_valid, collapse = ", ")
      classifications[i] <- "Universal"
      descriptions[i] <- sprintf(
        "%s is a universal driver (ranked %s across all %d segments)",
        drv, rank_str, n_segments
      )

    } else if (any_top_n && rank_diff >= rank_diff_threshold) {
      # Segment-Specific: top N in at least one segment, big rank spread
      best_seg  <- sub("_Rank$", "", rank_cols[which.min(ranks)])
      worst_seg <- sub("_Rank$", "", rank_cols[which.max(ranks)])
      classifications[i] <- "Segment-Specific"
      descriptions[i] <- sprintf(
        "%s matters most for %s (rank #%d) but less for %s (rank #%d)",
        drv, best_seg, best_rank, worst_seg, worst_rank
      )

    } else if (all_bottom) {
      # Low Priority: bottom half in all segments
      classifications[i] <- "Low Priority"
      descriptions[i] <- sprintf(
        "%s ranks in the bottom half across all segments (ranks: %s)",
        drv, paste(ranks_valid, collapse = ", ")
      )

    } else {
      # Mixed: moderate importance, not clearly universal or specific
      classifications[i] <- "Mixed"
      descriptions[i] <- sprintf(
        "%s shows moderate importance across segments (ranks: %s)",
        drv, paste(ranks_valid, collapse = ", ")
      )
    }
  }

  data.frame(
    Driver         = comparison_matrix$Driver,
    Classification = classifications,
    Description    = descriptions,
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# 3. GENERATE SEGMENT INSIGHTS
# ==============================================================================

#' Generate Plain-English Insights from Segment Comparison
#'
#' Produces a character vector of human-readable insight strings summarising
#' the segment comparison results.
#'
#' @param comparison_matrix Data.frame from
#'   \code{\link{build_importance_comparison_matrix}}.
#' @param classifications Data.frame from \code{\link{classify_drivers}}.
#'
#' @return Character vector of insight strings.
#'
#' @examples
#' \dontrun{
#'   insights <- generate_segment_insights(comparison_matrix, classifications)
#'   cat(paste(insights, collapse = "\n"))
#' }
#'
#' @keywords internal
generate_segment_insights <- function(comparison_matrix, classifications) {

  insights <- character(0)

  rank_cols <- grep("_Rank$", names(comparison_matrix), value = TRUE)
  pct_cols  <- grep("_Pct$",  names(comparison_matrix), value = TRUE)
  segment_names <- sub("_Rank$", "", rank_cols)
  n_segments <- length(segment_names)

  # --- Insight 1: Universal drivers that are #1 across all segments ---
  for (i in seq_len(nrow(comparison_matrix))) {
    drv   <- comparison_matrix$Driver[i]
    ranks <- as.integer(comparison_matrix[i, rank_cols])
    ranks_valid <- ranks[!is.na(ranks)]

    if (length(ranks_valid) == n_segments && all(ranks_valid == 1L)) {
      insights <- c(insights, sprintf(
        "%s is the #1 driver across all %d segments (Universal)",
        drv, n_segments
      ))
    }
  }

  # --- Insight 2: Top universal drivers (top 3, all segments) ---
  universal_drivers <- classifications$Driver[classifications$Classification == "Universal"]
  # Only mention those not already covered by the #1 insight
  already_mentioned <- character(0)
  for (ins in insights) {
    m <- regmatches(ins, regexpr("^[^ ]+", ins))
    if (length(m)) already_mentioned <- c(already_mentioned, m)
  }
  remaining_universal <- setdiff(universal_drivers, already_mentioned)
  for (drv in remaining_universal) {
    idx <- match(drv, comparison_matrix$Driver)
    ranks <- as.integer(comparison_matrix[idx, rank_cols])
    rank_str <- paste(sprintf("#%d", ranks), collapse = ", ")
    insights <- c(insights, sprintf(
      "%s is consistently important across all segments (ranks: %s) (Universal)",
      drv, rank_str
    ))
  }

  # --- Insight 3: Segment-specific drivers ---
  seg_specific <- classifications$Driver[classifications$Classification == "Segment-Specific"]
  for (drv in seg_specific) {
    idx <- match(drv, comparison_matrix$Driver)
    ranks <- as.integer(comparison_matrix[idx, rank_cols])

    best_idx  <- which.min(ranks)
    worst_idx <- which.max(ranks)
    best_seg  <- segment_names[best_idx]
    worst_seg <- segment_names[worst_idx]

    insights <- c(insights, sprintf(
      "%s matters most for %s customers (rank #%d) but less for %s (rank #%d)",
      drv, best_seg, ranks[best_idx], worst_seg, ranks[worst_idx]
    ))
  }

  # --- Insight 4: Consistency summary ---
  n_universal  <- sum(classifications$Classification == "Universal")
  n_specific   <- sum(classifications$Classification == "Segment-Specific")
  n_mixed      <- sum(classifications$Classification == "Mixed")
  n_low        <- sum(classifications$Classification == "Low Priority")
  n_total      <- nrow(classifications)

  n_consistent <- n_universal + n_mixed
  insights <- c(insights, sprintf(
    "%d out of %d drivers show consistent importance across segments",
    n_consistent, n_total
  ))

  # --- Insight 5: Classification summary line ---
  insights <- c(insights, sprintf(
    "%d universal drivers, %d segment-specific, %d mixed, %d low priority",
    n_universal, n_specific, n_mixed, n_low
  ))

  insights
}


# ==============================================================================
# 4. MAIN ENTRY POINT
# ==============================================================================

#' Run Segment Importance Comparison
#'
#' End-to-end orchestrator that splits data by a segment variable, runs
#' standardised-beta importance analysis per segment, then builds the
#' comparison matrix, classifies drivers, and generates plain-English insights.
#'
#' @param data A data.frame of respondent-level data containing the outcome,
#'   driver columns, and the segment variable.
#' @param outcome Character string naming the outcome (dependent) variable.
#' @param drivers Character vector of driver (independent) variable names.
#' @param segment_var Character string naming the segment variable in \code{data}.
#' @param segment_values Optional character vector of segment values to include.
#'   If \code{NULL} (default), all unique non-NA values of \code{segment_var}
#'   are used.
#' @param config Optional list of configuration overrides:
#'   \describe{
#'     \item{top_n}{Integer; top-N threshold for classification (default 3)}
#'     \item{rank_diff_threshold}{Integer; minimum rank spread for
#'       "Segment-Specific" (default 3)}
#'     \item{min_segment_n}{Integer; minimum observations per segment
#'       (default 30)}
#'   }
#'
#' @return A list with:
#'   \item{comparison_matrix}{Wide data.frame from
#'     \code{\link{build_importance_comparison_matrix}}}
#'   \item{classifications}{Data.frame from \code{\link{classify_drivers}}}
#'   \item{insights}{Character vector from
#'     \code{\link{generate_segment_insights}}}
#'   \item{segment_results}{Named list of per-segment importance data.frames}
#'
#' @examples
#' \dontrun{
#'   result <- run_segment_importance_comparison(
#'     data = survey_data,
#'     outcome = "overall_satisfaction",
#'     drivers = c("price", "quality", "service", "convenience", "brand"),
#'     segment_var = "customer_type"
#'   )
#'   cat(paste(result$insights, collapse = "\n"))
#' }
#'
#' @export
run_segment_importance_comparison <- function(data,
                                              outcome,
                                              drivers,
                                              segment_var,
                                              segment_values = NULL,
                                              config = list()) {

  # --- Config defaults ---
  top_n               <- config$top_n               %||% 3L
  rank_diff_threshold <- config$rank_diff_threshold  %||% 3L
  min_segment_n       <- config$min_segment_n        %||% 30L

  # --- Input validation ---
  if (!is.data.frame(data) || nrow(data) == 0) {
    keydriver_refuse(
      code = "DATA_MISSING",
      title = "Data Not Provided",
      problem = "Parameter 'data' must be a non-empty data.frame.",
      why_it_matters = "Segment comparison requires respondent-level data.",
      how_to_fix = "Pass a valid data.frame containing the outcome, drivers, and segment variable."
    )
  }

  if (is.null(outcome) || !nzchar(outcome) || !outcome %in% names(data)) {
    keydriver_refuse(
      code = "DATA_OUTCOME_NOT_FOUND",
      title = "Outcome Variable Not Found",
      problem = sprintf("Outcome variable '%s' is not in the data.", outcome %||% "<NULL>"),
      why_it_matters = "Cannot run importance analysis without the outcome variable.",
      how_to_fix = "Ensure the outcome variable name matches a column in the data."
    )
  }

  missing_drivers <- setdiff(drivers, names(data))
  if (length(missing_drivers) > 0) {
    keydriver_refuse(
      code = "DATA_DRIVERS_NOT_FOUND",
      title = "Driver Variables Not Found",
      problem = sprintf("%d driver(s) not found in data: %s",
                        length(missing_drivers), paste(missing_drivers, collapse = ", ")),
      why_it_matters = "Cannot calculate importance for missing drivers.",
      how_to_fix = "Check that all driver names match column names in the data exactly."
    )
  }

  if (is.null(segment_var) || !nzchar(segment_var) || !segment_var %in% names(data)) {
    keydriver_refuse(
      code = "DATA_SEGMENT_VAR_NOT_FOUND",
      title = "Segment Variable Not Found",
      problem = sprintf("Segment variable '%s' is not in the data.", segment_var %||% "<NULL>"),
      why_it_matters = "Cannot split data into segments without the segment variable.",
      how_to_fix = "Ensure segment_var names a column in the data."
    )
  }

  # --- Determine segment values ---
  if (is.null(segment_values)) {
    segment_values <- sort(unique(data[[segment_var]][!is.na(data[[segment_var]])]))
  }

  if (length(segment_values) < 2) {
    keydriver_refuse(
      code = "DATA_INSUFFICIENT_SEGMENTS",
      title = "Insufficient Segments",
      problem = sprintf("Only %d segment value(s) found. Need at least 2 for comparison.",
                        length(segment_values)),
      why_it_matters = "Segment comparison requires at least two distinct segments.",
      how_to_fix = c(
        "Check that segment_var contains at least 2 distinct values",
        "If using segment_values, provide at least 2 values"
      )
    )
  }

  # --- Console header ---
  cat("\nSegment Comparison Analysis\n")
  cat(sprintf("- Analyzing %d segments: %s\n",
              length(segment_values), paste(segment_values, collapse = ", ")))

  # --- Run importance per segment ---
  results_by_segment <- list()

  for (seg_val in segment_values) {
    seg_label <- as.character(seg_val)
    seg_data  <- data[data[[segment_var]] == seg_val & !is.na(data[[segment_var]]), , drop = FALSE]

    if (nrow(seg_data) < min_segment_n) {
      cat(sprintf("- Segment '%s': n=%d (below minimum %d, skipping)\n",
                  seg_label, nrow(seg_data), min_segment_n))
      next
    }

    # Ensure complete cases on outcome + drivers
    analysis_vars <- c(outcome, drivers)
    complete_idx  <- complete.cases(seg_data[, analysis_vars, drop = FALSE])
    seg_data      <- seg_data[complete_idx, , drop = FALSE]

    if (nrow(seg_data) < min_segment_n) {
      cat(sprintf("- Segment '%s': n=%d after listwise deletion (below minimum %d, skipping)\n",
                  seg_label, nrow(seg_data), min_segment_n))
      next
    }

    # Fit linear model and extract standardised betas
    formula_str <- paste(outcome, "~", paste(drivers, collapse = " + "))
    model <- tryCatch(
      stats::lm(stats::as.formula(formula_str), data = seg_data),
      error = function(e) {
        cat(sprintf("- Segment '%s': model fitting failed (%s), skipping\n",
                    seg_label, e$message))
        NULL
      }
    )

    if (is.null(model)) next

    # Standardised betas
    coefs <- stats::coef(model)
    coefs <- coefs[names(coefs) != "(Intercept)"]

    # Map coefficients back to driver names (handles factor expansion)
    sd_y <- stats::sd(seg_data[[outcome]], na.rm = TRUE)

    importance_pct <- vapply(drivers, function(drv) {
      coef_val <- coefs[drv]
      if (is.na(coef_val)) return(0)
      sd_x <- stats::sd(seg_data[[drv]], na.rm = TRUE)
      if (sd_x == 0 || sd_y == 0) return(0)
      abs(coef_val * (sd_x / sd_y))
    }, numeric(1))

    # Normalise to percentages
    total <- sum(importance_pct)
    if (total > 0) {
      importance_pct <- (importance_pct / total) * 100
    }

    seg_importance <- data.frame(
      Driver         = drivers,
      Importance_Pct = as.numeric(importance_pct),
      stringsAsFactors = FALSE
    )

    # Top driver for console output
    top_driver <- seg_importance$Driver[which.max(seg_importance$Importance_Pct)]
    cat(sprintf("- Segment '%s': n=%d, top driver = %s\n",
                seg_label, nrow(seg_data), top_driver))

    results_by_segment[[seg_label]] <- seg_importance
  }

  # --- Post-segment validation ---
  if (length(results_by_segment) < 2) {
    keydriver_refuse(
      code = "DATA_INSUFFICIENT_VALID_SEGMENTS",
      title = "Insufficient Valid Segments",
      problem = sprintf("Only %d segment(s) had enough data. Need at least 2 for comparison.",
                        length(results_by_segment)),
      why_it_matters = "Segment comparison requires at least two segments with sufficient sample size.",
      how_to_fix = c(
        sprintf("Increase sample size per segment (current minimum: %d)", min_segment_n),
        "Reduce the number of segments",
        "Lower min_segment_n in config (not recommended below 30)"
      )
    )
  }

  # --- Build comparison matrix ---
  comparison_matrix <- build_importance_comparison_matrix(results_by_segment)

  # --- Classify drivers ---
  classifications <- classify_drivers(
    comparison_matrix,
    top_n = top_n,
    rank_diff_threshold = rank_diff_threshold
  )

  # --- Generate insights ---
  insights <- generate_segment_insights(comparison_matrix, classifications)

  # --- Classification summary to console ---
  class_table <- table(classifications$Classification)
  class_parts <- vapply(names(class_table), function(cls) {
    sprintf("%d %s", class_table[[cls]], cls)
  }, character(1))
  cat(sprintf("- Classification: %s\n", paste(class_parts, collapse = ", ")))

  list(
    comparison_matrix = comparison_matrix,
    classifications   = classifications,
    insights          = insights,
    segment_results   = results_by_segment
  )
}


# ==============================================================================
# NULL-COALESCING OPERATOR (guarded)
# ==============================================================================

#' Null-coalescing operator
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
