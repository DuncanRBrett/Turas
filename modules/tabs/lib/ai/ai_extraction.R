# ==============================================================================
# AI EXTRACTION — Tabs-Specific Data Extraction for AI Insights
# ==============================================================================
#
# Extracts structured data from Turas tabs analytical output (all_results)
# for use as LLM prompt context. Only aggregated outputs are extracted —
# never raw respondent data.
#
# Functions:
#   extract_question_data()         — per-question structured extraction
#   extract_question_data_compact() — reduced payload for exec summary
#   extract_study_context()         — study-level context
#   extract_sig_flags()             — translate sig letters to boolean flags
#
# Dependencies:
#   Uses all_results structure from run_crosstabs_analysis()
#   Uses banner_info structure from create_banner_structure()
#
# Usage:
#   source("modules/tabs/lib/ai/ai_extraction.R")
#   q_data <- extract_question_data(all_results[["Q001"]], banner_info)
#
# ==============================================================================


#' Extract structured data for a single question
#'
#' Transforms a question's analytical output into a clean, structured list
#' suitable for LLM prompt context. Includes response percentages, significance
#' flags (as boolean), base sizes, and priority metrics.
#'
#' @param q_result List. A single question's result from all_results.
#'   Expected fields: question_code, question_text, question_type, table, bases.
#' @param banner_info List. Banner structure from create_banner_structure().
#'   Expected fields: internal_keys, letters, key_to_display, banner_info.
#'
#' @return List with fields: q_code, q_title, q_type, response_labels,
#'   results (named list of column values), significance (list of sig flags),
#'   base_sizes (named list), priority_metric (if detected).
#'   Returns NULL if extraction fails.
extract_question_data <- function(q_result, banner_info) {

  if (is.null(q_result) || is.null(q_result$table)) return(NULL)

  table <- q_result$table
  if (nrow(table) == 0) return(NULL)

  # Identify data columns (internal_keys present in the table)
  all_keys <- banner_info$internal_keys
  available_keys <- intersect(all_keys, names(table))
  if (length(available_keys) == 0) return(NULL)

  # Build display label lookup
  key_to_display <- banner_info$key_to_display
  if (is.null(key_to_display)) {
    key_to_display <- setNames(
      sapply(available_keys, function(k) {
        parts <- strsplit(k, "::")[[1]]
        if (length(parts) >= 2) parts[length(parts)] else k
      }),
      available_keys
    )
  }

  # Extract primary stat rows (Column % preferred, fallback to Frequency)
  primary_type <- detect_primary_stat_type(table)
  primary_rows <- table[!is.na(table$RowType) & table$RowType == primary_type, ,
                        drop = FALSE]

  # Filter out summary/net rows for cleaner extraction
  response_labels <- primary_rows$RowLabel
  if (is.null(response_labels) || length(response_labels) == 0) return(NULL)

  # Build results matrix: each column is a named vector of values
  results <- list()
  for (key in available_keys) {
    display <- key_to_display[[key]] %||% key
    vals <- as.numeric(primary_rows[[key]])
    names(vals) <- response_labels
    results[[display]] <- vals
  }

  # Extract significance flags
  sig_flags <- extract_sig_flags(q_result, banner_info)

  # Extract base sizes
  base_sizes <- extract_base_sizes(q_result, available_keys, key_to_display)

  # Detect priority metric (NPS, Mean, etc.)
  priority_metric <- extract_priority_metric(table, available_keys, key_to_display)

  list(
    q_code          = q_result$question_code,
    q_title         = q_result$question_text,
    q_type          = q_result$question_type,
    response_labels = as.character(response_labels),
    results         = results,
    significance    = sig_flags,
    base_sizes      = base_sizes,
    priority_metric = priority_metric
  )
}


#' Extract compact question data for executive summary
#'
#' Returns a reduced payload: only topline totals, priority metric values,
#' and significant differences. Used when the full payload exceeds context
#' window limits.
#'
#' @param q_result List. A single question's result from all_results.
#' @param banner_info List. Banner structure.
#'
#' @return List with reduced fields, or NULL on failure.
extract_question_data_compact <- function(q_result, banner_info) {

  full <- extract_question_data(q_result, banner_info)
  if (is.null(full)) return(NULL)

  # Keep only Total column results
  total_key <- "Total"
  total_results <- if (total_key %in% names(full$results)) {
    list(Total = full$results[[total_key]])
  } else if (length(full$results) > 0) {
    list(Total = full$results[[1]])
  } else {
    list()
  }

  # Keep only significant flags
  sig_flags <- Filter(function(f) isTRUE(f$significant), full$significance)

  list(
    q_code          = full$q_code,
    q_title         = full$q_title,
    q_type          = full$q_type,
    results         = total_results,
    significance    = sig_flags,
    priority_metric = full$priority_metric
  )
}


#' Extract study-level context for AI prompts
#'
#' Provides study metadata and banner structure information. This context
#' is shared across all per-question prompts.
#'
#' @param all_results Named list. Full analysis results.
#' @param banner_info List. Banner structure.
#' @param config_obj List. Configuration object.
#'
#' @return List with study-level context fields.
extract_study_context <- function(all_results, banner_info, config_obj) {

  # Build banner group summary
  banner_groups <- list()
  if (!is.null(banner_info$banner_info)) {
    for (bq_code in names(banner_info$banner_info)) {
      bq <- banner_info$banner_info[[bq_code]]
      labels <- bq$columns %||% bq$internal_keys

      # Get base sizes for this banner's columns
      bases <- list()
      first_q <- all_results[[1]]
      if (!is.null(first_q) && !is.null(first_q$bases)) {
        for (key in bq$internal_keys) {
          base_entry <- first_q$bases[[key]]
          display <- sub("^.*::", "", key)
          if (!is.null(base_entry)) {
            bases[[display]] <- base_entry$weighted %||% base_entry$unweighted %||%
                                base_entry
          }
        }
      }

      banner_groups[[bq_code]] <- list(
        labels     = labels,
        base_sizes = bases
      )
    }
  }

  list(
    report_title  = config_obj$project_title %||% "Untitled Study",
    total_n       = extract_total_n(all_results),
    weighted      = isTRUE(config_obj$apply_weighting),
    fieldwork     = config_obj$fieldwork_dates %||% "",
    n_questions   = length(all_results),
    banner_groups = banner_groups
  )
}


#' Translate significance letter notation to boolean flags
#'
#' Turas stores significance as letter codes in "Sig." rows. Each letter
#' corresponds to a column (via banner_info$letters). This function extracts
#' significant differences as a flat list of boolean-flag records.
#'
#' @param q_result List. A single question's result from all_results.
#' @param banner_info List. Banner structure with letters mapping.
#'
#' @return List of significance flag records, each with:
#'   measure, column, value, direction, vs_columns, significant.
extract_sig_flags <- function(q_result, banner_info) {

  table <- q_result$table
  if (is.null(table) || nrow(table) == 0) return(list())

  # Find Sig. rows
  sig_mask <- !is.na(table$RowType) & table$RowType == "Sig."
  if (!any(sig_mask)) return(list())

  sig_rows <- table[sig_mask, , drop = FALSE]

  # Build letter-to-column lookup
  all_keys <- banner_info$internal_keys
  all_letters <- banner_info$letters
  key_to_display <- banner_info$key_to_display

  if (is.null(all_letters) || length(all_letters) == 0) return(list())

  letter_to_display <- setNames(
    sapply(all_keys, function(k) {
      if (!is.null(key_to_display) && k %in% names(key_to_display)) {
        key_to_display[[k]]
      } else {
        sub("^.*::", "", k)
      }
    }),
    all_letters
  )

  available_keys <- intersect(all_keys, names(table))
  flags <- list()

  for (row_idx in seq_len(nrow(sig_rows))) {
    measure <- sig_rows$RowLabel[row_idx]
    if (is.na(measure)) next

    for (key in available_keys) {
      sig_val <- sig_rows[row_idx, key]
      if (is.na(sig_val) || !is.character(sig_val) && !is.factor(sig_val)) next

      sig_str <- as.character(sig_val)
      if (!nzchar(sig_str) || sig_str == "-") next

      # Each letter in the sig string indicates significance vs that column
      sig_letters <- strsplit(sig_str, "")[[1]]
      vs_columns <- unname(sapply(sig_letters, function(l) {
        letter_to_display[[l]] %||% l
      }))

      col_display <- if (!is.null(key_to_display) && key %in% names(key_to_display)) {
        key_to_display[[key]]
      } else {
        sub("^.*::", "", key)
      }

      flags[[length(flags) + 1]] <- list(
        measure     = measure,
        column      = col_display,
        direction   = "higher",
        vs_columns  = vs_columns,
        significant = TRUE
      )
    }
  }

  flags
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Detect the primary statistic type in a table
#' @keywords internal
detect_primary_stat_type <- function(table) {
  row_types <- unique(table$RowType)
  if ("Column %" %in% row_types) return("Column %")
  if ("Row %" %in% row_types) return("Row %")
  if ("Frequency" %in% row_types) return("Frequency")
  row_types[1]
}


#' Extract base sizes from a question result
#' @keywords internal
extract_base_sizes <- function(q_result, available_keys, key_to_display) {
  bases <- list()

  if (!is.null(q_result$bases)) {
    for (key in available_keys) {
      display <- key_to_display[[key]] %||% sub("^.*::", "", key)
      base_entry <- q_result$bases[[key]]

      if (is.list(base_entry)) {
        bases[[display]] <- base_entry$weighted %||% base_entry$unweighted %||% NA
      } else if (is.numeric(base_entry)) {
        bases[[display]] <- base_entry
      }
    }
  }

  bases
}


#' Extract priority metric (NPS, Mean, Index, etc.)
#' @keywords internal
extract_priority_metric <- function(table, available_keys, key_to_display) {
  # Look for summary rows: Average, NPS Score, NET POSITIVE, Index
  priority_types <- c("Average", "Score", "Index")
  priority_labels <- c("Mean", "NPS Score", "NET POSITIVE", "NET NEGATIVE",
                       "Average", "Index")

  for (lbl in priority_labels) {
    match_rows <- table[!is.na(table$RowLabel) & table$RowLabel == lbl, , drop = FALSE]
    if (nrow(match_rows) > 0) {
      values <- list()
      for (key in available_keys) {
        display <- key_to_display[[key]] %||% sub("^.*::", "", key)
        val <- match_rows[1, key]
        if (!is.na(val)) values[[display]] <- as.numeric(val)
      }
      if (length(values) > 0) {
        return(list(label = lbl, values = values))
      }
    }
  }

  NULL
}


#' Extract total sample size from first question's bases
#' @keywords internal
extract_total_n <- function(all_results) {
  if (length(all_results) == 0) return(NA)

  first_q <- all_results[[1]]
  if (is.null(first_q) || is.null(first_q$bases)) return(NA)

  total_base <- first_q$bases[["TOTAL::Total"]]
  if (is.list(total_base)) {
    return(total_base$weighted %||% total_base$unweighted %||% NA)
  }
  if (is.numeric(total_base)) return(total_base)
  NA
}
