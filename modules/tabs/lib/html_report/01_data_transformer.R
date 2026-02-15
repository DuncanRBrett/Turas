# ==============================================================================
# HTML REPORT - DATA TRANSFORMER (V10.3)
# ==============================================================================
# Transforms all_results + banner_info into HTML-ready data structures
# for reactable table rendering.
# ==============================================================================


#' Build Banner Groups Structure
#'
#' Extracts banner group definitions from banner_info into a clean
#' structure mapping group name -> columns, keys, and letters.
#'
#' @param banner_info List from create_banner_structure()
#' @return Named list of banner groups
#' @export
build_banner_groups <- function(banner_info) {
  groups <- list()

  # banner_info$banner_info is a named list keyed by banner question code
  # banner_info$banner_headers has label, start_col, end_col
  # banner_info$internal_keys has all keys in order (first is TOTAL::Total)
  # banner_info$letters has corresponding letters

  all_keys <- banner_info$internal_keys
  all_letters <- banner_info$letters
  all_columns <- banner_info$columns

  for (bq_code in names(banner_info$banner_info)) {
    bq <- banner_info$banner_info[[bq_code]]

    # Get the display label for this group from banner_headers
    group_label <- bq_code  # fallback
    if (!is.null(banner_info$banner_headers)) {
      # Find matching header by position
      for (i in seq_len(nrow(banner_info$banner_headers))) {
        hdr <- banner_info$banner_headers[i, ]
        # Match by checking if this banner's keys fall within the header's column range
        bq_positions <- which(all_keys %in% bq$internal_keys)
        if (length(bq_positions) > 0 && !is.na(hdr$start_col) && !is.na(hdr$end_col)) {
          # banner_headers positions are 1-indexed from the data columns (excluding Total)
          # Check if any of this banner's positions fall in this header's range
          in_range <- bq_positions >= hdr$start_col & bq_positions <= hdr$end_col
          if (any(in_range, na.rm = TRUE)) {
            group_label <- hdr$label
            break
          }
        }
      }
    }

    # If the banner_info sub-element has its own label, use that
    if (!is.null(bq$question) && !is.null(bq$question$question_text)) {
      group_label <- bq$question$question_text
    }

    # Use the label from banner_headers if available, or derive from the question
    # For cleaner display, strip "Q###" prefix patterns
    display_label <- group_label

    groups[[display_label]] <- list(
      banner_code = bq_code,
      internal_keys = bq$internal_keys,
      letters = bq$letters,
      display_labels = if (!is.null(bq$columns)) bq$columns
                       else sapply(bq$internal_keys, function(k) {
                         parts <- strsplit(k, "::")[[1]]
                         if (length(parts) >= 2) parts[2] else k
                       }, USE.NAMES = FALSE)
    )
  }

  groups
}


#' Detect Available Statistics for a Question
#'
#' Scans the RowType column to determine which statistics are present.
#'
#' @param question_table Data.frame from all_results[[q]]$table
#' @return Named list of logicals
#' @export
detect_available_stats <- function(question_table) {
  row_types <- unique(question_table$RowType)

  list(
    has_freq = "Frequency" %in% row_types,
    has_col_pct = "Column %" %in% row_types,
    has_row_pct = "Row %" %in% row_types,
    has_sig = "Sig." %in% row_types,
    has_mean = "Average" %in% row_types,
    has_index = "Index" %in% row_types,
    has_score = "Score" %in% row_types,
    has_sd = any(c("Std Dev", "StdDev") %in% row_types)
  )
}


#' Classify Row Labels as Category, NET, or Mean
#'
#' Determines whether each unique RowLabel is a regular category,
#' a NET/box-category summary, or a mean/summary statistic.
#'
#' @param question_table Data.frame from question result
#' @param question_type Character, question type (e.g., "Single_Choice")
#' @return Named character vector: RowLabel -> "category"|"net"|"mean"
#' @export
classify_row_labels <- function(question_table, question_type = "Single_Choice") {

  # Get all unique labels and their associated row types
  labels <- unique(question_table$RowLabel)
  # Remove NA labels
  labels <- labels[!is.na(labels) & labels != ""]
  label_types <- sapply(labels, function(lbl) {
    unique(question_table$RowType[!is.na(question_table$RowLabel) & question_table$RowLabel == lbl])
  }, simplify = FALSE)

  classification <- character(length(labels))
  names(classification) <- labels

  # Common NET/box-category patterns (case-insensitive)
  net_patterns <- c(
    "^NET\\b", "^NET ", "\\bNET\\b",
    "^TOP BOX", "^BOTTOM BOX", "^TOP 2", "^BOTTOM 2",
    "^TOP 3", "^BOTTOM 3",
    "NET POSITIVE", "NET NEGATIVE",
    "^Promoter", "^Detractor", "^Passive",
    "^NPS\\b", "NPS \\(",
    "^Good or ", "^Terrible or ",
    "^Agree or ", "^Disagree or ",
    "Fully trust", "Some trust", "Do not trust",
    "^Satisfied or ", "^Dissatisfied or ",
    "^Average$",
    # Box-category labels with parenthetical ranges e.g. "Dissatisfied (1-5)"
    "\\(\\d+-\\d+\\)",
    # Common exclusion/composite categories
    "^DK\\s*/\\s*NA$", "^DK/NA$", "^Don't know\\s*/", "^Refused\\s*/"
  )

  for (lbl in labels) {
    types <- label_types[[lbl]]

    # Mean/summary statistics - always classified as "mean"
    if (any(types %in% c("Average", "Index", "Score", "Std Dev", "StdDev", "ChiSquare"))) {
      classification[lbl] <- "mean"
      next
    }

    # Check against NET patterns
    is_net <- FALSE
    for (pat in net_patterns) {
      match_result <- tryCatch(grepl(pat, lbl, ignore.case = TRUE), error = function(e) FALSE)
      if (isTRUE(match_result)) {
        is_net <- TRUE
        break
      }
    }

    if (is_net) {
      classification[lbl] <- "net"
    } else {
      classification[lbl] <- "category"
    }
  }

  classification
}


#' Transform a Single Question for HTML Display
#'
#' Converts a question's table data.frame into a flat data.frame
#' suitable for reactable, with hidden columns for sig/freq/base data.
#'
#' @param q_result Single element from all_results
#' @param banner_info Banner structure
#' @param config_obj Configuration object
#' @return List with:
#'   \item{q_code}{Question code}
#'   \item{question_text}{Full question text}
#'   \item{question_type}{Question type}
#'   \item{base_filter}{Filter text or NA}
#'   \item{stats}{Available statistics (from detect_available_stats)}
#'   \item{table_data}{Data.frame for reactable}
#' @export
transform_single_question <- function(q_result, banner_info, config_obj) {

  table <- q_result$table
  bases <- q_result$bases
  stats <- detect_available_stats(table)

  # Coerce RowLabel to character and trim whitespace to avoid matching issues
  table$RowLabel <- trimws(as.character(table$RowLabel))
  table$RowType <- trimws(as.character(table$RowType))

  # Forward-fill RowLabel: the source data only sets RowLabel on the first
  # RowType for each item (typically Frequency), leaving Column %, Sig., etc.
  # with empty labels. Propagate each non-empty label downward.
  last_label <- ""
  for (i in seq_len(nrow(table))) {
    if (!is.na(table$RowLabel[i]) && nzchar(table$RowLabel[i])) {
      last_label <- table$RowLabel[i]
    } else {
      table$RowLabel[i] <- last_label
    }
  }

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

  list(
    q_code = q_result$question_code,
    question_text = q_result$question_text %||% "",
    question_type = q_result$question_type %||% "Unknown",
    base_filter = q_result$base_filter,
    stats = stats,
    primary_stat = primary_stat_label,
    table_data = table_data
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
      total_n <- base_row[1, "TOTAL::Total"]
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


# Null-coalescing operator (if not already defined)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
