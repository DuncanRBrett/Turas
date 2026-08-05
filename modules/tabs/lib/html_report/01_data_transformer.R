# ==============================================================================
# HTML REPORT - DATA TRANSFORMER (V10.3)
# ==============================================================================
# Transforms all_results + banner_info into HTML-ready data structures
# for plain HTML table rendering.
# ==============================================================================


# The row/banner shape helpers that used to live here (build_banner_groups,
# detect_available_stats, classify_row_labels, normalize_question_table) moved
# to lib/report_shared.R — the v2 data layer uses them too.



#' Transform a Single Question for HTML Display
#'
#' Converts a question's table data.frame into a flat data.frame
#' suitable for HTML table rendering, with hidden columns for sig/freq/base data.
#'
#' @param q_result Single element from all_results
#' @param banner_info Banner structure
#' @param config_obj Configuration object
#' @return List with:
#'   \item{q_code}{Question code}
#'   \item{question_text}{Full question text}
#'   \item{question_type}{Question type}
#'   \item{base_filter}{Filter expression or NA}
#'   \item{filter_label}{Human-readable filter label or NA}
#'   \item{stats}{Available statistics (from detect_available_stats)}
#'   \item{table_data}{Data.frame for HTML table builder}
#' @export
transform_single_question <- function(q_result, banner_info, config_obj) {

  table <- q_result$table
  bases <- q_result$bases
  stats <- detect_available_stats(table)

  # Trim + forward-fill RowLabel/RowSource (shared with the JSON data-layer
  # writer so both paths classify rows from an identical table shape).
  table <- normalize_question_table(table)

  # Get all internal keys (columns in the table beyond RowLabel/RowType)
  all_keys <- banner_info$internal_keys
  # Only keep keys that exist as columns in this question's table
  available_keys <- intersect(all_keys, names(table))

  if (length(available_keys) == 0) {
    return(NULL)
  }

  # Classify row labels
  classifications <- classify_row_labels(table, q_result$question_type)

  # Determine primary statistic to display
  primary_stat <- if (stats$has_col_pct) "Column %"
                  else if (stats$has_row_pct) "Row %"
                  else if (stats$has_freq) "Frequency"
                  else if (stats$has_mean) "Average"
                  else "Frequency"

  # Get unique display labels (excluding those that only appear as mean/summary)
  display_labels <- names(classifications)

  # Build base row
  base_values <- sapply(available_keys, function(key) {
    if (!is.null(bases[[key]])) {
      # Use weighted base if weighting applied, else unweighted
      if (isTRUE(config_obj$apply_weighting) && !is.null(bases[[key]]$weighted)) {
        bases[[key]]$weighted
      } else {
        bases[[key]]$unweighted
      }
    } else {
      NA_real_
    }
  })

  # Initialize output rows as a list of lists
  rows <- list()

  # Add base row
  base_row <- list(.row_type = "base", .row_label = "Base (n=)", .is_net = FALSE)
  for (key in available_keys) {
    base_row[[key]] <- base_values[key]
  }
  rows[[length(rows) + 1]] <- base_row

  # Process each unique label
  for (lbl in display_labels) {
    label_class <- classifications[lbl]

    if (label_class == "mean") {
      # Mean/summary row - get the value directly
      mean_rows <- table[!is.na(table$RowLabel) & table$RowLabel == lbl, , drop = FALSE]
      row <- list(
        .row_type = "mean",
        .row_label = lbl,
        .is_net = FALSE
      )
      # Use the first matching row type for display
      for (key in available_keys) {
        row[[key]] <- if (nrow(mean_rows) > 0) mean_rows[1, key] else NA
      }
      rows[[length(rows) + 1]] <- row
      next
    }

    # Category or NET row
    row <- list(
      .row_type = label_class,
      .row_label = lbl,
      .is_net = (label_class == "net")
    )

    # Get primary stat values — fall back through stat types if primary not available
    primary_rows <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                          table$RowLabel == lbl & table$RowType == primary_stat, , drop = FALSE]
    used_stat <- primary_stat

    # If no rows for primary stat, try fallback order
    if (nrow(primary_rows) == 0) {
      fallback_stats <- c("Column %", "Row %", "Frequency")
      for (fb in fallback_stats) {
        if (fb == primary_stat) next
        primary_rows <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                              table$RowLabel == lbl & table$RowType == fb, , drop = FALSE]
        if (nrow(primary_rows) > 0) {
          used_stat <- fb
          break
        }
      }
    }

    # Track the stat type used for this row (so table builder knows whether to add %)
    row[[".stat_type"]] <- used_stat

    for (key in available_keys) {
      row[[key]] <- if (nrow(primary_rows) > 0) primary_rows[1, key] else NA
    }

    # Get frequency values (for hidden columns)
    if (stats$has_freq && isTRUE(config_obj$embed_frequencies)) {
      freq_rows <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                         table$RowLabel == lbl & table$RowType == "Frequency", , drop = FALSE]
      for (key in available_keys) {
        freq_col <- paste0(".freq_", key)
        row[[freq_col]] <- if (nrow(freq_rows) > 0) freq_rows[1, key] else NA
      }
    }

    # Get significance values (for hidden columns)
    if (stats$has_sig) {
      sig_rows <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                        table$RowLabel == lbl & table$RowType == "Sig.", , drop = FALSE]
      for (key in available_keys) {
        sig_col <- paste0(".sig_", key)
        row[[sig_col]] <- if (nrow(sig_rows) > 0) {
          val <- sig_rows[1, key]
          if (is.na(val) || val == "" || val == "-") "" else as.character(val)
        } else {
          ""
        }
      }
    }

    # Get secondary significance values (dual-alpha feature, V10.10)
    if (stats$has_sig2) {
      sig2_rows <- table[!is.na(table$RowLabel) & !is.na(table$RowType) &
                         table$RowLabel == lbl & table$RowType == "Sig.2", , drop = FALSE]
      for (key in available_keys) {
        sig2_col <- paste0(".sig2_", key)
        row[[sig2_col]] <- if (nrow(sig2_rows) > 0) {
          val <- sig2_rows[1, key]
          if (is.na(val) || val == "" || val == "-") "" else as.character(val)
        } else {
          ""
        }
      }
    }

    # Add base sizes per row (for JS low-base dimming)
    for (key in available_keys) {
      base_col <- paste0(".base_", key)
      row[[base_col]] <- base_values[key]
    }

    rows[[length(rows) + 1]] <- row
  }

  # Convert list of lists to data.frame
  # Use rbindlist-like approach for safety
  if (length(rows) == 0) return(NULL)

  # Get all column names across all rows
  all_col_names <- unique(unlist(lapply(rows, names)))

  # Build data.frame row by row
  df_list <- lapply(rows, function(row) {
    # Fill missing columns with NA
    filled <- lapply(all_col_names, function(cn) {
      if (cn %in% names(row)) row[[cn]] else NA
    })
    names(filled) <- all_col_names
    as.data.frame(filled, stringsAsFactors = FALSE, check.names = FALSE)
  })

  table_data <- do.call(rbind, df_list)

  # Determine primary stat label for display
  primary_stat_label <- switch(primary_stat,
    "Column %" = "Column %",
    "Row %" = "Row %",
    "Frequency" = "Frequency",
    "Average" = "Average",
    primary_stat
  )

  # Row descriptors — annotation text shown below summary stat rows
  # Each descriptor is set via config and shown when the matching row type exists
  q_type <- q_result$question_type %||% "Unknown"

  # Index descriptor (for Likert questions with an Index row)
  index_description <- NULL
  has_index_row <- any(table_data$.row_type == "mean" &
                       grepl("^Index$", table_data$.row_label, ignore.case = TRUE))
  if (has_index_row && q_type == "Likert") {
    if (!is.null(config_obj$index_descriptor) && nzchar(config_obj$index_descriptor)) {
      index_description <- config_obj$index_descriptor
    }
  }

  # Mean descriptor (for Rating/Likert questions with a Mean row)
  mean_description <- NULL
  has_mean_row <- any(table_data$.row_type == "mean" &
                      grepl("^Mean$", table_data$.row_label, ignore.case = TRUE))
  if (has_mean_row && q_type %in% c("Rating", "Likert")) {
    if (!is.null(config_obj$mean_descriptor) && nzchar(config_obj$mean_descriptor)) {
      mean_description <- config_obj$mean_descriptor
    }
  }

  # NPS descriptor (for NPS questions with an NPS Score row)
  nps_description <- NULL
  has_nps_row <- any(table_data$.row_type == "mean" &
                     grepl("NPS", table_data$.row_label, ignore.case = TRUE))
  if (has_nps_row && q_type == "NPS") {
    if (!is.null(config_obj$nps_descriptor) && nzchar(config_obj$nps_descriptor)) {
      nps_description <- config_obj$nps_descriptor
    }
  }

  list(
    q_code = q_result$question_code,
    question_text = q_result$question_text %||% "",
    question_type = q_type,
    base_filter = q_result$base_filter,
    filter_label = q_result$filter_label %||% NA_character_,
    category = q_result$category %||% NA_character_,
    category_order = q_result$category_order %||% NA_character_,
    stats = stats,
    primary_stat = primary_stat_label,
    table_data = table_data,
    index_description = index_description,
    mean_description = mean_description,
    nps_description = nps_description
  )
}


#' Transform All Results for HTML Report
#'
#' Main transformation function that converts all_results and banner_info
#' into the complete data structure needed for HTML rendering.
#'
#' @param all_results List of question results from analysis_runner
#' @param banner_info List from create_banner_structure
#' @param config_obj Configuration object
#' @return List with:
#'   \item{questions}{Named list of transformed question data}
#'   \item{banner_groups}{Banner group structure}
#'   \item{total_n}{Total respondents}
#'   \item{n_questions}{Number of questions}
#' @export
transform_for_html <- function(all_results, banner_info, config_obj) {

  # Build banner groups
  banner_groups <- build_banner_groups(banner_info)

  # Transform each question
  questions <- list()
  for (q_code in names(all_results)) {
    q_result <- all_results[[q_code]]

    # Skip questions with no table or empty table
    if (is.null(q_result$table) || !is.data.frame(q_result$table) || nrow(q_result$table) == 0) {
      next
    }

    # Skip if required columns missing
    if (!all(c("RowLabel", "RowType") %in% names(q_result$table))) {
      next
    }

    transformed <- transform_single_question(q_result, banner_info, config_obj)
    if (!is.null(transformed)) {
      questions[[q_code]] <- transformed
    }
  }

  # Get total N from first question's base
  total_n <- NA
  if (length(questions) > 0) {
    first_q <- questions[[1]]
    base_row <- first_q$table_data[first_q$table_data$.row_type == "base", , drop = FALSE]
    if (nrow(base_row) > 0 && "TOTAL::Total" %in% names(base_row)) {
      total_n <- suppressWarnings(as.numeric(base_row[1, "TOTAL::Total"]))
    }
  }

  list(
    questions = questions,
    banner_groups = banner_groups,
    total_n = total_n,
    n_questions = length(questions),
    internal_keys = banner_info$internal_keys,
    key_to_display = if (!is.null(banner_info$key_to_display)) banner_info$key_to_display
                     else setNames(banner_info$columns, banner_info$internal_keys)
  )
}


