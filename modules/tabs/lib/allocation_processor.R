# ==============================================================================
# ALLOCATION_PROCESSOR.R
# ==============================================================================
#
# PURPOSE:
#   Process constant-sum / budget-allocation questions (Variable_Type = "Allocation").
#   One numeric column per option ({code}_1 … {code}_N). Reports mean allocation
#   per option, cross-tabbed by banner, with optional significance testing.
#
# DESIGN NOTES:
#   - Zero allocation is meaningful data — never filter it out.
#   - Output is means (not percentages); downstream formatting handles display.
#   - Significance testing: one row per option, comparing means across banner segs.
#
# FUNCTIONS:
#   - process_allocation_question()     Main entry point
#   - build_allocation_labels()         Resolve option display labels
#   - collect_allocation_values()       Extract per-banner numeric values
#   - build_allocation_mean_row()       Construct one result row of means
#   - compute_allocation_weighted_mean() Weighted or unweighted mean helper
#   - build_allocation_sig_row()        Significance test row for one option
#
# DEPENDENCIES:
#   - shared_functions.R  (batch_rbind)
#   - cell_calculator.R   (format_output_value)
#   - run_crosstabs.R     (add_significance_row)
#
# VERSION: 1.0.0
# DATE: 2026-05-05
# ==============================================================================

# Row type constant (reuse the AVERAGE type shared with numeric_processor)
ALLOCATION_AVERAGE_ROW_TYPE <- "Average"
ALLOCATION_TOTAL_COLUMN     <- "Total"

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Process Allocation Question
#'
#' Produces one output row per allocation option, each containing the weighted
#' or unweighted mean allocation across banner segments. Appends a significance
#' row after each option when significance testing is enabled.
#'
#' @param data Data frame, full survey data
#' @param question_info Data frame row, question metadata from Survey_Structure
#' @param question_options Data frame, option rows for this question (labels)
#' @param banner_info List, banner structure from create_banner_structure()
#' @param banner_row_indices List, row indices per banner key
#' @param master_weights Numeric vector, weights for all data rows
#' @param banner_bases List, base sizes per banner key
#' @param config List, configuration object
#' @param is_weighted Logical, whether weighting is applied
#' @return Data frame with one mean row (+ optional sig row) per option, or NULL
#' @export
process_allocation_question <- function(data, question_info, question_options,
                                        banner_info, banner_row_indices,
                                        master_weights, banner_bases,
                                        config, is_weighted) {

  code          <- question_info$QuestionCode
  n_cols        <- suppressWarnings(as.integer(question_info$Columns))
  internal_keys <- banner_info$internal_keys

  if (is.na(n_cols) || n_cols < 1L) {
    log_message(
      sprintf("Allocation: invalid Columns for %s — skipping", code),
      level = "WARNING",
      verbose = config$verbose
    )
    return(NULL)
  }

  option_labels <- build_allocation_labels(question_options, code, n_cols)
  results_list  <- list()

  for (i in seq_len(n_cols)) {
    col_name    <- paste0(code, "_", i)
    label       <- option_labels[i]
    value_sets  <- collect_allocation_values(data, col_name, banner_row_indices)
    weight_sets <- collect_allocation_weights(master_weights, banner_row_indices)

    mean_row <- build_allocation_mean_row(
      label, value_sets, weight_sets, internal_keys, config, is_weighted
    )
    results_list[[length(results_list) + 1]] <- mean_row

    if (isTRUE(config$enable_significance_testing)) {
      sig_row <- build_allocation_sig_row(
        value_sets, weight_sets, banner_info, internal_keys, config, is_weighted
      )
      if (!is.null(sig_row)) {
        results_list[[length(results_list) + 1]] <- sig_row
      }
    }
  }

  if (length(results_list) == 0) return(NULL)
  batch_rbind(results_list)
}

# ==============================================================================
# HELPERS
# ==============================================================================

#' Build Option Labels for Allocation Question
#'
#' Returns a character vector of length n_cols using OptionText (or DisplayText
#' if present and non-blank). Falls back to "{code}_{i}" when options are sparse.
#'
#' @param question_options Data frame, options rows for this question
#' @param code Character, question code
#' @param n_cols Integer, expected number of columns
#' @return Character vector, one label per option
#' @export
build_allocation_labels <- function(question_options, code, n_cols) {
  labels <- character(n_cols)

  for (i in seq_len(n_cols)) {
    if (!is.null(question_options) && nrow(question_options) >= i) {
      opt <- question_options[i, ]

      use_display <- "DisplayText" %in% names(opt) &&
                     !is.na(opt$DisplayText) &&
                     nzchar(trimws(opt$DisplayText))

      labels[i] <- if (use_display) {
        trimws(opt$DisplayText)
      } else if ("OptionText" %in% names(opt) &&
                 !is.na(opt$OptionText) && nzchar(trimws(opt$OptionText))) {
        trimws(opt$OptionText)
      } else {
        paste0(code, "_", i)
      }
    } else {
      labels[i] <- paste0(code, "_", i)
    }
  }

  labels
}

#' Collect Allocation Values per Banner Segment
#'
#' Returns a named list (keyed by banner internal key) of numeric vectors.
#' Zeros are retained; only NA values are excluded per observation.
#'
#' @param data Data frame, survey data
#' @param col_name Character, column to extract (e.g. "BrandPen_1")
#' @param banner_row_indices List, row indices per banner key
#' @return Named list of numeric vectors (NAs already removed)
#' @export
collect_allocation_values <- function(data, col_name, banner_row_indices) {
  raw_col <- if (col_name %in% names(data)) data[[col_name]] else NULL

  lapply(banner_row_indices, function(row_idx) {
    if (is.null(raw_col) || length(row_idx) == 0L) return(numeric(0))
    vals <- suppressWarnings(as.numeric(raw_col[row_idx]))
    vals[!is.na(vals)]
  })
}

#' Collect Weights per Banner Segment (Aligned to Valid Values)
#'
#' Returns a named list of weight vectors aligned to each banner segment's
#' full row index (NA alignment is done later alongside the values).
#'
#' @param master_weights Numeric vector, weights for all rows
#' @param banner_row_indices List, row indices per banner key
#' @return Named list of weight vectors
#' @export
collect_allocation_weights <- function(master_weights, banner_row_indices) {
  lapply(banner_row_indices, function(row_idx) {
    if (length(row_idx) == 0L) return(numeric(0))
    master_weights[row_idx]
  })
}

#' Compute Weighted or Unweighted Mean
#'
#' @param values Numeric vector, already NA-filtered
#' @param weights Numeric vector, same length as values
#' @param is_weighted Logical
#' @return Single numeric mean, or NA_real_ if no data
#' @export
compute_allocation_weighted_mean <- function(values, weights, is_weighted) {
  if (length(values) == 0L) return(NA_real_)
  if (!is_weighted || all(weights == 1)) return(mean(values))
  total_w <- sum(weights)
  if (total_w == 0) return(NA_real_)
  sum(values * weights) / total_w
}

#' Build Mean Row for One Allocation Option
#'
#' @param label Character, display label for this option
#' @param value_sets Named list of numeric vectors per banner key
#' @param weight_sets Named list of raw weight vectors per banner key
#' @param internal_keys Character vector, banner key names
#' @param config List, configuration object
#' @param is_weighted Logical
#' @return Single-row data frame
#' @export
build_allocation_mean_row <- function(label, value_sets, weight_sets,
                                      internal_keys, config, is_weighted) {
  row <- data.frame(
    RowLabel  = label,
    RowType   = ALLOCATION_AVERAGE_ROW_TYPE,
    RowSource = "individual",
    stringsAsFactors = FALSE
  )

  for (key in internal_keys) {
    values  <- value_sets[[key]]
    weights <- weight_sets[[key]]

    # Align weights to valid (non-NA) positions
    if (length(weights) > length(values)) {
      weights <- weights[seq_along(values)]
    }

    mean_val <- compute_allocation_weighted_mean(values, weights, is_weighted)
    row[[key]] <- format_output_value(
      mean_val,
      "numeric",
      decimal_places_numeric = config$decimal_places_numeric
    )
  }

  row
}

#' Build Significance Row for One Allocation Option
#'
#' Compares means across banner segments using the same t-test / z-test
#' approach as the numeric processor.
#'
#' @param value_sets Named list of numeric vectors per banner key
#' @param weight_sets Named list of raw weight vectors per banner key
#' @param banner_info List, banner structure
#' @param internal_keys Character vector, banner key names
#' @param config List, configuration object
#' @param is_weighted Logical
#' @return Single-row data frame or NULL
#' @export
build_allocation_sig_row <- function(value_sets, weight_sets, banner_info,
                                     internal_keys, config, is_weighted) {
  total_key <- paste0("TOTAL::", ALLOCATION_TOTAL_COLUMN)
  test_data <- list()

  for (key in internal_keys) {
    if (key == total_key) next
    values  <- value_sets[[key]]
    weights <- weight_sets[[key]]

    if (length(values) == 0L) next
    if (length(weights) > length(values)) weights <- weights[seq_along(values)]

    test_data[[key]] <- list(values = values, weights = weights)
  }

  if (length(test_data) < 2L) return(NULL)

  add_significance_row(
    test_data,
    banner_info,
    "rating",
    internal_keys,
    alpha              = config$alpha,
    bonferroni         = config$bonferroni_correction,
    min_base           = config$significance_min_base,
    is_weighted        = is_weighted,
    alpha_secondary    = config$alpha_secondary
  )
}

# ==============================================================================
# MODULE INFO
# ==============================================================================

#' Get Allocation Processor Module Information
#'
#' @return List with module metadata
#' @export
get_allocation_processor_info <- function() {
  list(
    module      = "allocation_processor",
    version     = "1.0.0",
    date        = "2026-05-05",
    description = "Constant-sum / budget-allocation question processor",
    functions   = c(
      "process_allocation_question",
      "build_allocation_labels",
      "collect_allocation_values",
      "collect_allocation_weights",
      "compute_allocation_weighted_mean",
      "build_allocation_mean_row",
      "build_allocation_sig_row",
      "get_allocation_processor_info"
    ),
    dependencies = c("shared_functions.R", "cell_calculator.R", "run_crosstabs.R")
  )
}

message("[OK] Turas>Tabs allocation_processor module loaded")

# ==============================================================================
# END OF ALLOCATION_PROCESSOR.R
# ==============================================================================
