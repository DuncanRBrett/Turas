# ==============================================================================
# HTML REPORT - DASHBOARD TRANSFORMER (V10.4.2)
# ==============================================================================
# Extracts headline metrics from all_results for the summary dashboard.
# Uses config-driven metric selection: dashboard_metrics is a comma-separated
# list of metric types (e.g., "NET POSITIVE, Mean"). Each type creates its
# own section with gauges and heatmap grid.
#
# Supported metric types:
#   "NET POSITIVE" — NET POSITIVE rows (Column %)
#   "NPS"          — NPS Score rows (Score/Average RowType with "NPS" label)
#   "Mean"         — Average/Mean rows (RowType == "Average")
#   "Index"        — Index rows (RowType == "Index")
#   Any label      — matched against RowLabel (e.g., "Good or excellent",
#                     "Very Satisfied (9-10)", "Fully trust")
# ==============================================================================


#' Transform All Results for Dashboard
#'
#' Extracts headline metrics grouped by metric type, metadata, and
#' significance findings from all_results for the summary dashboard.
#'
#' @param all_results List from analysis_runner (keyed by question code)
#' @param banner_info List from create_banner_structure()
#' @param config_obj Configuration object
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{metadata}{List: total_n, fieldwork_dates, n_questions, banner info}
#'   \item{metric_sections}{List of sections, each with type_label and metrics}
#'   \item{sig_findings}{List of significant finding objects}
#'   \item{banner_info}{The original banner_info (passed through for builder)}
#' @export
transform_for_dashboard <- function(all_results, banner_info, config_obj) {

  if (is.null(all_results) || length(all_results) == 0) {
    return(list(
      status = "REFUSED",
      code = "DASH_NO_RESULTS",
      message = "No analysis results available for dashboard",
      how_to_fix = "Ensure at least one question has been processed"
    ))
  }

  # Parse dashboard_metrics config (comma-separated)
  metrics_config <- config_obj$dashboard_metrics %||% "NET POSITIVE"
  requested_types <- trimws(unlist(strsplit(as.character(metrics_config), ",")))
  requested_types <- requested_types[nchar(requested_types) > 0]

  if (length(requested_types) == 0) {
    requested_types <- c("NET POSITIVE")
  }

  # Extract metadata
  metadata <- extract_dashboard_metadata(all_results, banner_info, config_obj)

  # Available internal keys
  all_keys <- banner_info$internal_keys

  # Build sections: one per requested metric type
  metric_sections <- list()
  all_metrics <- list()  # flat list for sig findings

  for (req_type in requested_types) {
    section_metrics <- list()

    for (q_code in names(all_results)) {
      q_result <- all_results[[q_code]]
      metric <- detect_metric_by_type(q_result, req_type, banner_info)
      if (!is.null(metric)) {
        section_metrics[[length(section_metrics) + 1]] <- metric
        all_metrics[[length(all_metrics) + 1]] <- metric
      }
    }

    if (length(section_metrics) > 0) {
      metric_sections[[length(metric_sections) + 1]] <- list(
        type_label = req_type,
        metrics = section_metrics
      )
    } else {
      cat(sprintf("    [Dashboard] No metrics found for type '%s' across %d questions\n",
                  req_type, length(all_results)))
    }
  }

  # Extract significance findings from all metrics
  sig_findings <- list()
  if (isTRUE(config_obj$enable_significance_testing)) {
    sig_findings <- extract_sig_findings(all_metrics, banner_info)
  }

  list(
    status = "PASS",
    metadata = metadata,
    metric_sections = metric_sections,
    headline_metrics = all_metrics,  # flat list (backward compat)
    sig_findings = sig_findings,
    banner_info = banner_info
  )
}


#' Extract Dashboard Metadata
#'
#' Pulls top-level project metadata for the dashboard metadata strip.
#'
#' @param all_results List from analysis_runner
#' @param banner_info Banner structure
#' @param config_obj Configuration
#' @return List with total_n, fieldwork_dates, n_questions, banner_group_names,
#'         banner_group_count
#' @keywords internal
extract_dashboard_metadata <- function(all_results, banner_info, config_obj) {

  # Total N from first question's TOTAL base
  total_n <- NA_real_
  for (q_code in names(all_results)) {
    q <- all_results[[q_code]]
    if (!is.null(q$bases) && !is.null(q$bases[["TOTAL::Total"]])) {
      if (isTRUE(config_obj$apply_weighting) &&
          !is.null(q$bases[["TOTAL::Total"]]$weighted)) {
        total_n <- q$bases[["TOTAL::Total"]]$weighted
      } else {
        total_n <- q$bases[["TOTAL::Total"]]$unweighted
      }
      break
    }
  }

  # Banner group names
  bg_names <- character(0)
  if (!is.null(banner_info$banner_headers) && nrow(banner_info$banner_headers) > 0) {
    bg_names <- banner_info$banner_headers$label
  } else if (!is.null(banner_info$banner_info)) {
    bg_names <- names(banner_info$banner_info)
  }

  list(
    total_n = total_n,
    fieldwork_dates = config_obj$fieldwork_dates,
    n_questions = length(all_results),
    banner_group_names = bg_names,
    banner_group_count = length(bg_names)
  )
}


#' Detect a Specific Metric Type in a Single Question
#'
#' Searches a question's table for a row matching the requested metric type.
#'
#' @param q_result Single element from all_results
#' @param req_type Character: the requested metric type from config
#' @param banner_info Banner structure
#' @return A metric object list, or NULL if not found
#' @keywords internal
detect_metric_by_type <- function(q_result, req_type, banner_info) {

  table <- q_result$table
  if (is.null(table) || nrow(table) == 0) return(NULL)

  table$RowLabel <- trimws(as.character(table$RowLabel))
  table$RowType <- trimws(as.character(table$RowType))

  all_keys <- banner_info$internal_keys
  available_keys <- intersect(all_keys, names(table))
  if (length(available_keys) == 0) return(NULL)

  req_upper <- toupper(trimws(req_type))

  # --- Match by known types ---

  if (req_upper == "NET POSITIVE") {
    rows <- table[
      grepl("NET POSITIVE", table$RowLabel, ignore.case = TRUE) &
      table$RowType == "Column %",
      , drop = FALSE
    ]
    if (nrow(rows) > 0) {
      return(build_metric_object(q_result, rows[1, , drop = FALSE],
                                  "net_positive", table, available_keys))
    }
    return(NULL)
  }

  if (req_upper %in% c("NPS", "NPS SCORE")) {
    # Match NPS Score rows: RowLabel contains "NPS" with RowType "Score" or "Average"
    # Also match RowType "Score" alone (NPS is the only type producing Score rows)
    rows <- table[
      (grepl("NPS", table$RowLabel, ignore.case = TRUE) |
       table$RowType == "Score") &
      table$RowType %in% c("Score", "Average"),
      , drop = FALSE
    ]
    if (nrow(rows) > 0) {
      return(build_metric_object(q_result, rows[1, , drop = FALSE],
                                  "nps_score", table, available_keys))
    }
    return(NULL)
  }

  if (req_upper == "MEAN" || req_upper == "AVERAGE") {
    rows <- table[table$RowType == "Average", , drop = FALSE]
    if (nrow(rows) > 0) {
      return(build_metric_object(q_result, rows[1, , drop = FALSE],
                                  "average", table, available_keys))
    }
    return(NULL)
  }

  if (req_upper == "INDEX") {
    rows <- table[table$RowType == "Index", , drop = FALSE]
    if (nrow(rows) > 0) {
      return(build_metric_object(q_result, rows[1, , drop = FALSE],
                                  "index", table, available_keys))
    }
    return(NULL)
  }

  # --- Match by RowLabel (custom box-category label) ---
  # e.g., "Good or excellent", "Very Satisfied (9-10)", "Fully trust"
  # Match against Column % rows first, then Frequency
  rows <- table[
    grepl(req_type, table$RowLabel, ignore.case = TRUE) &
    table$RowType == "Column %",
    , drop = FALSE
  ]

  if (nrow(rows) == 0) {
    # Try Frequency
    rows <- table[
      grepl(req_type, table$RowLabel, ignore.case = TRUE) &
      table$RowType == "Frequency",
      , drop = FALSE
    ]
  }

  if (nrow(rows) > 0) {
    return(build_metric_object(q_result, rows[1, , drop = FALSE],
                                "custom", table, available_keys))
  }

  NULL
}


#' Build Metric Object from a Detected Row
#'
#' Extracts numeric values and significance flags for a headline metric row.
#'
#' @param q_result Full question result
#' @param metric_row Single-row data frame (the detected metric)
#' @param metric_type Character: "net_positive", "nps_score", "average",
#'        "index", or "custom"
#' @param table Full question table
#' @param available_keys Character vector of internal keys present in table
#' @return Metric object list
#' @keywords internal
build_metric_object <- function(q_result, metric_row, metric_type, table,
                                 available_keys) {

  label <- metric_row$RowLabel[1]

  # Extract numeric values for each key
  values <- list()
  for (key in available_keys) {
    raw_val <- metric_row[[key]][1]
    num_val <- suppressWarnings(as.numeric(as.character(raw_val)))
    values[[key]] <- if (!is.na(num_val)) num_val else NA_real_
  }

  # Find corresponding significance row (same RowLabel, RowType == "Sig.")
  sig_flags <- list()
  sig_rows <- table[
    !is.na(table$RowLabel) & table$RowLabel == label &
    table$RowType == "Sig.",
    , drop = FALSE
  ]

  # If no exact match, try the sig row immediately after
  if (nrow(sig_rows) == 0) {
    metric_idx <- which(table$RowLabel == label &
                        table$RowType == metric_row$RowType[1])
    if (length(metric_idx) > 0) {
      next_idx <- metric_idx[1] + 1
      while (next_idx <= nrow(table)) {
        if (table$RowType[next_idx] == "Sig.") {
          sig_rows <- table[next_idx, , drop = FALSE]
          break
        }
        if (!is.na(table$RowLabel[next_idx]) &&
            nzchar(table$RowLabel[next_idx]) &&
            table$RowLabel[next_idx] != label) {
          break
        }
        next_idx <- next_idx + 1
      }
    }
  }

  for (key in available_keys) {
    if (nrow(sig_rows) > 0) {
      sig_val <- as.character(sig_rows[[key]][1])
      sig_flags[[key]] <- if (!is.na(sig_val)) sig_val else ""
    } else {
      sig_flags[[key]] <- ""
    }
  }

  list(
    q_code = q_result$question_code,
    question_text = q_result$question_text %||% q_result$question_code,
    metric_type = metric_type,
    metric_label = label,
    values = values,
    sig_flags = sig_flags
  )
}


#' Extract Significant Findings from Headline Metrics
#'
#' Scans headline metrics for non-empty significance flags and produces
#' structured finding objects for the dashboard. Resolves sig letter codes
#' (e.g., "B", "BCD") to actual column display names and their values.
#'
#' @param headline_metrics List of metric objects
#' @param banner_info Banner structure
#' @return List of finding objects with resolved_comparisons
#' @keywords internal
extract_sig_findings <- function(headline_metrics, banner_info) {

  findings <- list()

  key_to_display <- if (!is.null(banner_info$key_to_display)) {
    banner_info$key_to_display
  } else {
    stats::setNames(banner_info$internal_keys, banner_info$internal_keys)
  }

  key_to_group <- character(0)

  # Build banner code to display label mapping from banner_headers
  banner_code_to_label <- character(0)
  if (!is.null(banner_info$banner_headers) && nrow(banner_info$banner_headers) > 0 &&
      !is.null(banner_info$banner_info)) {
    grp_codes <- names(banner_info$banner_info)
    for (i in seq_along(grp_codes)) {
      if (i <= nrow(banner_info$banner_headers)) {
        banner_code_to_label[grp_codes[i]] <- banner_info$banner_headers$label[i]
      }
    }
  }

  if (!is.null(banner_info$banner_info)) {
    for (grp_name in names(banner_info$banner_info)) {
      grp <- banner_info$banner_info[[grp_name]]
      # Use display label (e.g. "Campus") instead of code (e.g. "Q002")
      display_label <- if (grp_name %in% names(banner_code_to_label)) {
        banner_code_to_label[grp_name]
      } else {
        grp_name
      }
      if (!is.null(grp$internal_keys)) {
        for (k in grp$internal_keys) {
          key_to_group[k] <- display_label
        }
      }
    }
  }

  # Build letter-to-key, letter-to-display, and letter-to-group mappings
  # banner_info$letters is parallel with banner_info$internal_keys
  letter_to_key <- list()
  letter_to_display <- list()
  letter_to_group <- list()
  if (!is.null(banner_info$letters) && !is.null(banner_info$internal_keys)) {
    for (i in seq_along(banner_info$letters)) {
      ltr <- banner_info$letters[i]
      if (!is.null(ltr) && !is.na(ltr) && ltr != "-" && nchar(ltr) > 0) {
        k <- banner_info$internal_keys[i]
        letter_to_key[[ltr]] <- k
        letter_to_display[[ltr]] <- if (k %in% names(key_to_display)) {
          key_to_display[[k]]
        } else {
          sub("^[^:]+::", "", k)
        }
        # Track which banner group this letter belongs to
        letter_to_group[[ltr]] <- if (k %in% names(key_to_group)) {
          key_to_group[[k]]
        } else {
          "Unknown"
        }
      }
    }
  }

  for (metric in headline_metrics) {
    for (key in names(metric$sig_flags)) {
      sig_val <- metric$sig_flags[[key]]

      if (is.null(sig_val) || is.na(sig_val) || sig_val == "" || sig_val == "-") {
        next
      }

      col_label <- if (key %in% names(key_to_display)) {
        key_to_display[[key]]
      } else {
        sub("^[^:]+::", "", key)
      }

      grp_name <- if (key %in% names(key_to_group)) {
        key_to_group[[key]]
      } else {
        "Unknown"
      }

      val <- metric$values[[key]]

      # Get Total value for comparison context
      total_val <- metric$values[["TOTAL::Total"]]
      if (is.null(total_val)) total_val <- NA_real_

      # Resolve sig letter codes to column names and values
      # sig_val might be "B" or "BCD" or "B C D" — split into individual letters
      sig_letters_clean <- gsub("[^A-Za-z]", "", sig_val)
      individual_letters <- strsplit(sig_letters_clean, "")[[1]]

      # Only show comparisons from the SAME banner group as this column.
      # Sig tests run across ALL columns, but comparing Campus vs Age
      # is misleading in the dashboard context.
      resolved_comparisons <- list()
      cross_group_comparisons <- list()
      for (ltr in individual_letters) {
        ltr_upper <- toupper(ltr)
        comp_name <- letter_to_display[[ltr_upper]] %||% ltr_upper
        comp_key <- letter_to_key[[ltr_upper]]
        comp_val <- if (!is.null(comp_key)) {
          metric$values[[comp_key]]
        } else {
          NA_real_
        }
        if (is.null(comp_val)) comp_val <- NA_real_

        comp_group <- letter_to_group[[ltr_upper]] %||% "Unknown"
        comp_entry <- list(
          letter = ltr_upper,
          name = comp_name,
          value = comp_val,
          group = comp_group
        )

        if (comp_group == grp_name) {
          # Same banner group — include in main comparisons
          resolved_comparisons[[length(resolved_comparisons) + 1]] <- comp_entry
        } else {
          # Different banner group — track separately
          cross_group_comparisons[[length(cross_group_comparisons) + 1]] <- comp_entry
        }
      }

      # Skip findings that have no same-group comparisons (all cross-group)
      if (length(resolved_comparisons) == 0) next

      findings[[length(findings) + 1]] <- list(
        metric_label = metric$metric_label,
        q_code = metric$q_code,
        question_text = metric$question_text,
        column_label = col_label,
        column_key = key,
        sig_letters = sig_val,
        value = val,
        total_value = total_val,
        banner_group = grp_name,
        metric_type = metric$metric_type,
        resolved_comparisons = resolved_comparisons,
        cross_group_comparisons = cross_group_comparisons
      )
    }
  }

  findings
}


# Null-coalescing operator (if not already defined)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
