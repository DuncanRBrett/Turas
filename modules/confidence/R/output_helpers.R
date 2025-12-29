# ==============================================================================
# OUTPUT HELPERS - TURAS V10.1 (Phase 1 Refactoring)
# ==============================================================================
# Common output building patterns extracted from 07_output.R
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Refactoring release (2025-12-29)
#          - Extracted common dataframe building patterns
#          - Unified result row construction
#          - Common CI field handling
#
# EXTRACTED FUNCTIONS:
# - build_base_result_row() - Create base row with common fields
# - add_ci_fields_to_row() - Add CI-specific fields to result row
# - combine_result_rows() - Combine rows handling mismatched columns
# - build_results_dataframe() - Generic results dataframe builder
#
# DEPENDENCIES:
# - None (base R only)
# ==============================================================================

OUTPUT_HELPERS_VERSION <- "10.1"

# ==============================================================================
# RESULT ROW BUILDING
# ==============================================================================

#' Build base result row for any analysis type
#'
#' Creates a base row list with question ID and common statistics fields.
#' This is the foundation for all result row building.
#'
#' @param q_id Character. Question ID
#' @param base_fields Named list. Base fields to include (e.g., proportion, mean)
#'
#' @return Named list representing a row
#'
#' @keywords internal
build_base_result_row <- function(q_id, base_fields) {
  row <- list(Question_ID = q_id)

  for (name in names(base_fields)) {
    value <- base_fields[[name]]
    row[[name]] <- if (!is.null(value)) value else NA
  }

  return(row)
}


#' Add CI fields to a result row
#'
#' Adds confidence interval fields from a CI result to a row.
#' Handles different CI types (MOE, Wilson, Bootstrap, Bayesian).
#'
#' @param row Named list. Existing row to add fields to
#' @param ci_result List. CI result with lower/upper bounds
#' @param prefix Character. Prefix for field names (e.g., "MOE", "Wilson")
#' @param extra_fields Character vector. Additional fields to extract beyond lower/upper
#'
#' @return Named list with added CI fields
#'
#' @keywords internal
add_ci_fields_to_row <- function(row, ci_result, prefix, extra_fields = NULL) {
  if (is.null(ci_result)) {
    return(row)
  }

  # Add lower and upper bounds
  row[[paste0(prefix, "_Lower")]] <- ci_result$lower
  row[[paste0(prefix, "_Upper")]] <- ci_result$upper

  # Add any extra fields requested
  if (!is.null(extra_fields)) {
    for (field in extra_fields) {
      if (!is.null(ci_result[[field]])) {
        row[[paste0(prefix, "_", field)]] <- ci_result[[field]]
      }
    }
  }

  return(row)
}


# ==============================================================================
# RESULT DATAFRAME BUILDING
# ==============================================================================

#' Combine result rows into a data frame
#'
#' Combines a list of result rows into a data frame, handling
#' mismatched columns by filling missing values with NA.
#' Uses dplyr::bind_rows if available, otherwise falls back to base R.
#'
#' @param rows_list List. List of named lists representing rows
#'
#' @return Data frame with all rows combined
#'
#' @keywords internal
combine_result_rows <- function(rows_list) {
  if (length(rows_list) == 0) {
    return(data.frame())
  }

  # Try dplyr for better performance
  if (requireNamespace("dplyr", quietly = TRUE)) {
    return(dplyr::bind_rows(rows_list))
  }

  # Fallback: find all unique column names and fill missing with NA
  all_cols <- unique(unlist(lapply(rows_list, names)))

  rows_list_filled <- lapply(rows_list, function(row) {
    missing_cols <- setdiff(all_cols, names(row))
    for (col in missing_cols) {
      row[[col]] <- NA
    }
    return(row[all_cols])  # Reorder to match all_cols
  })

  do.call(rbind, lapply(rows_list_filled, function(x) {
    as.data.frame(x, stringsAsFactors = FALSE)
  }))
}


#' Build a results dataframe from a results list
#'
#' Generic function to build a dataframe from analysis results.
#' Handles different result types (proportions, means, NPS).
#'
#' @param results List. Named list of results (keyed by question ID)
#' @param result_type Character. Type of result: "proportion", "mean", or "nps"
#'
#' @return Data frame with all results
#'
#' @keywords internal
build_results_dataframe <- function(results, result_type) {
  if (length(results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(results)) {
    q_result <- results[[q_id]]

    if (is.null(q_result)) next

    # Build base row based on result type
    row <- switch(result_type,
      "proportion" = build_proportion_result_row(q_id, q_result),
      "mean" = build_mean_result_row(q_id, q_result),
      "nps" = build_nps_result_row(q_id, q_result),
      build_base_result_row(q_id, q_result)  # fallback
    )

    rows_list[[length(rows_list) + 1]] <- row
  }

  combine_result_rows(rows_list)
}


# ==============================================================================
# TYPE-SPECIFIC ROW BUILDERS
# ==============================================================================

#' Build proportion result row
#' @keywords internal
build_proportion_result_row <- function(q_id, q_result) {
  # Base fields
  row <- build_base_result_row(q_id, list(
    Category = q_result$category %||% "Total",
    Proportion = q_result$proportion,
    Sample_Size = q_result$n,
    Effective_n = q_result$n_eff
  ))

  # Add MOE CI fields
  if (!is.null(q_result$moe)) {
    row <- add_ci_fields_to_row(row, q_result$moe, "MOE_Normal",
                                 extra_fields = c("moe"))
  }

  # Handle moe_normal for backward compatibility
  if (!is.null(q_result$moe_normal)) {
    row <- add_ci_fields_to_row(row, q_result$moe_normal, "MOE_Normal",
                                 extra_fields = c("moe"))
  }

  # Add Wilson CI fields
  if (!is.null(q_result$wilson)) {
    row <- add_ci_fields_to_row(row, q_result$wilson, "Wilson")
  }

  # Add Bootstrap CI fields
  if (!is.null(q_result$bootstrap)) {
    row <- add_ci_fields_to_row(row, q_result$bootstrap, "Bootstrap")
  }

  # Add Bayesian CI fields
  if (!is.null(q_result$bayesian)) {
    row <- add_ci_fields_to_row(row, q_result$bayesian, "Bayesian")
  }

  return(row)
}


#' Build mean result row
#' @keywords internal
build_mean_result_row <- function(q_id, q_result) {
  # Base fields
  row <- build_base_result_row(q_id, list(
    Mean = q_result$mean,
    SD = q_result$sd,
    Sample_Size = q_result$n,
    Effective_n = q_result$n_eff
  ))

  # Add t-distribution CI fields
  if (!is.null(q_result$t_dist)) {
    row$tDist_Lower <- q_result$t_dist$lower
    row$tDist_Upper <- q_result$t_dist$upper
    row$SE <- q_result$t_dist$se
    row$DF <- q_result$t_dist$df
  }

  # Add Bootstrap CI fields
  if (!is.null(q_result$bootstrap)) {
    row <- add_ci_fields_to_row(row, q_result$bootstrap, "Bootstrap")
  }

  # Add Bayesian CI fields
  if (!is.null(q_result$bayesian)) {
    row <- add_ci_fields_to_row(row, q_result$bayesian, "Bayesian",
                                 extra_fields = c("post_mean"))
    # Rename for clarity
    if (!is.null(row$Bayesian_post_mean)) {
      row$Bayesian_Mean <- row$Bayesian_post_mean
      row$Bayesian_post_mean <- NULL
    }
  }

  return(row)
}


#' Build NPS result row
#' @keywords internal
build_nps_result_row <- function(q_id, q_result) {
  # Base fields
  row <- build_base_result_row(q_id, list(
    NPS_Score = q_result$nps_score,
    Pct_Promoters = q_result$pct_promoters,
    Pct_Detractors = q_result$pct_detractors,
    Sample_Size = q_result$n,
    Effective_n = q_result$n_eff
  ))

  # Add Normal CI fields
  if (!is.null(q_result$normal_ci)) {
    row$Normal_Lower <- q_result$normal_ci$lower
    row$Normal_Upper <- q_result$normal_ci$upper
    row$SE <- q_result$normal_ci$se
  }

  # Handle moe_normal for consistency with NPS processing
  if (!is.null(q_result$moe_normal)) {
    row$Normal_Lower <- q_result$moe_normal$lower
    row$Normal_Upper <- q_result$moe_normal$upper
    row$SE <- q_result$moe_normal$se
  }

  # Add Bootstrap CI fields
  if (!is.null(q_result$bootstrap)) {
    row <- add_ci_fields_to_row(row, q_result$bootstrap, "Bootstrap")
  }

  # Add Bayesian CI fields
  if (!is.null(q_result$bayesian)) {
    row <- add_ci_fields_to_row(row, q_result$bayesian, "Bayesian",
                                 extra_fields = c("post_mean"))
    # Rename for clarity
    if (!is.null(row$Bayesian_post_mean)) {
      row$Bayesian_Mean <- row$Bayesian_post_mean
      row$Bayesian_post_mean <- NULL
    }
  }

  return(row)
}


# ==============================================================================
# SHEET STYLING HELPERS
# ==============================================================================

#' Create standard header style for Excel sheets
#'
#' Creates a consistent header style for Excel output sheets.
#'
#' @return openxlsx style object
#'
#' @keywords internal
create_header_style <- function() {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(NULL)
  }

  openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
}


#' Create standard title style for Excel sheets
#'
#' Creates a consistent title style for Excel output sheets.
#'
#' @param font_size Integer. Font size (default 14)
#'
#' @return openxlsx style object
#'
#' @keywords internal
create_title_style <- function(font_size = 14) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(NULL)
  }

  openxlsx::createStyle(
    fontSize = font_size,
    textDecoration = "bold"
  )
}


#' Write data with standard formatting to Excel sheet
#'
#' Writes a data frame to an Excel sheet with consistent formatting.
#' Includes title, header styling, and auto-sized columns.
#'
#' @param wb Workbook object
#' @param sheet_name Character. Name of the sheet
#' @param title Character. Title text
#' @param data Data frame. Data to write
#' @param start_row Integer. Row to start data (after title)
#' @param decimal_sep Character. Decimal separator for number formatting
#'
#' @return Integer. Next available row after data
#'
#' @keywords internal
write_formatted_data <- function(wb, sheet_name, title, data, start_row = 1,
                                  decimal_sep = ".") {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(start_row)
  }

  # Write title
  openxlsx::writeData(wb, sheet_name, title, startCol = 1, startRow = start_row)
  openxlsx::addStyle(wb, sheet_name, create_title_style(),
                     rows = start_row, cols = 1)

  # Write data
  data_row <- start_row + 2
  openxlsx::writeData(wb, sheet_name, data, startCol = 1, startRow = data_row,
                      colNames = TRUE, rowNames = FALSE)

  # Apply header style
  openxlsx::addStyle(wb, sheet_name, create_header_style(),
                     rows = data_row, cols = 1:ncol(data), gridExpand = TRUE)

  # Apply numeric formatting
  if (exists("apply_numeric_formatting", mode = "function")) {
    apply_numeric_formatting(wb, sheet_name, data_row + 1, 1, data, decimal_sep)
  }

  # Auto-size columns
  openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(data), widths = "auto")

  # Return next available row
  return(data_row + nrow(data) + 2)
}


# ==============================================================================
# NULL-COALESCING OPERATOR (if not already defined)
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
