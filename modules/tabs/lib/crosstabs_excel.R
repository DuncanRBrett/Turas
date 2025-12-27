# ==============================================================================
# MODULE: crosstabs_excel.R
# ==============================================================================
# Purpose: Excel writing utilities and checkpoint management
#
# This module provides:
# - Fast Excel table writing with significance overlay
# - Checkpoint save/load for long-running analyses
# - Proper handling of numeric data and significance strings
#
# Version: 10.0
# TRS Compliance: v1.0
# ==============================================================================

# ==============================================================================
# EXCEL TABLE WRITING
# ==============================================================================

#' Write question table to Excel with significance overlay
#'
#' ORDER: Matrix first, then sig strings overlaid (prevents erasure)
#' SAFEGUARDS: Skip Total column, skip empty strings
#'
#' This function writes question results efficiently by:
#' 1. Writing labels and types
#' 2. Writing numeric matrix
#' 3. Overlaying significance strings
#' 4. Applying cell styles
#'
#' @param wb Workbook object
#' @param sheet Character, sheet name
#' @param data_table Data frame with question results
#' @param banner_info List, banner structure
#' @param internal_keys Character vector, column internal keys
#' @param styles List, cell styles
#' @param current_row Integer, starting row
#' @return Integer, next available row
#' @export
write_question_table_fast <- function(wb, sheet, data_table, banner_info,
                                      internal_keys, styles, current_row) {
  if (is.null(data_table) || nrow(data_table) == 0) return(current_row)

  n_rows <- nrow(data_table)
  n_data_cols <- length(banner_info$columns)

  label_col <- as.character(data_table$RowLabel)
  type_col <- as.character(data_table$RowType)

  data_matrix <- matrix(NA_real_, nrow = n_rows, ncol = n_data_cols)

  sig_cells <- list()

  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  total_col_idx <- which(internal_keys == total_key)

  for (i in seq_along(internal_keys)) {
    internal_key <- internal_keys[i]
    if (internal_key %in% names(data_table)) {
      col_data <- data_table[[internal_key]]

      if (any(type_col == SIG_ROW_TYPE)) {
        sig_indices <- which(type_col == SIG_ROW_TYPE)
        for (sig_idx in sig_indices) {
          sig_val <- col_data[sig_idx]

          # SAFEGUARDS: Skip Total column, skip empty strings
          if (!is.na(sig_val) && is.character(sig_val) && nchar(sig_val) > 0) {
            if (length(total_col_idx) == 0 || i != total_col_idx) {
              sig_cells[[length(sig_cells) + 1]] <- list(
                row = current_row + sig_idx - 1,
                col = i + 2,
                value = sig_val
              )
            }
          }
          col_data[sig_idx] <- NA
        }
      }

      data_matrix[, i] <- suppressWarnings(as.numeric(col_data))
    }
  }

  # STEP 1: Write labels and types
  openxlsx::writeData(wb, sheet, label_col,
                     startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::writeData(wb, sheet, type_col,
                     startRow = current_row, startCol = 2, colNames = FALSE)

  # STEP 2: Write numeric matrix FIRST
  openxlsx::writeData(wb, sheet, data_matrix,
                     startRow = current_row, startCol = 3, colNames = FALSE)

  # STEP 3: Overlay sig strings (after matrix write)
  for (sig_cell in sig_cells) {
    openxlsx::writeData(wb, sheet, sig_cell$value,
                       startRow = sig_cell$row, startCol = sig_cell$col,
                       colNames = FALSE)
  }

  # STEP 4: Apply styles (Uses get_row_style for correct mapping)
  for (row_idx in seq_len(n_rows)) {
    row_type <- type_col[row_idx]
    style <- get_row_style(row_type, styles)

    openxlsx::addStyle(wb, sheet, style,
                      rows = current_row + row_idx - 1,
                      cols = 3:(2 + n_data_cols), gridExpand = TRUE)
  }

  return(current_row + n_rows)
}

# ==============================================================================
# CHECKPOINT SYSTEM
# ==============================================================================

#' Save checkpoint to disk
#'
#' Saves current processing state to allow resuming if interrupted.
#' Creates checkpoint directory if it doesn't exist.
#'
#' @param checkpoint_file Character, path to checkpoint file
#' @param all_results List, processed results
#' @param processed_questions Character vector, question codes processed
#' @return Invisible NULL
#' @export
save_checkpoint <- function(checkpoint_file, all_results, processed_questions) {
  # Ensure checkpoint directory exists
  checkpoint_dir <- dirname(checkpoint_file)
  if (!dir.exists(checkpoint_dir)) {
    dir.create(checkpoint_dir, recursive = TRUE)
  }

  checkpoint_data <- list(
    results = all_results,
    processed = processed_questions,
    timestamp = Sys.time()
  )
  saveRDS(checkpoint_data, checkpoint_file)
}

#' Load checkpoint from disk
#'
#' Attempts to load saved checkpoint. Returns NULL if checkpoint
#' doesn't exist or can't be loaded.
#'
#' @param checkpoint_file Character, path to checkpoint file
#' @return List with results and processed questions, or NULL
#' @export
load_checkpoint <- function(checkpoint_file) {
  # Check if directory exists first (important for OneDrive paths)
  checkpoint_dir <- dirname(checkpoint_file)
  if (!dir.exists(checkpoint_dir)) return(NULL)

  # Check if file exists
  if (!file.exists(checkpoint_file)) return(NULL)

  tryCatch({
    checkpoint_data <- readRDS(checkpoint_file)
    log_message(sprintf("Checkpoint loaded: %d questions already processed",
                       length(checkpoint_data$processed)), "INFO")
    return(checkpoint_data)
  }, error = function(e) {
    # TRS v1.0: Make checkpoint load failure visible (not output-affecting, just informational)
    message(sprintf("[TRS INFO] Checkpoint file exists but could not be loaded: %s\n  Starting fresh instead.", conditionMessage(e)))
    return(NULL)
  })
}

# ==============================================================================
# END OF MODULE: crosstabs_excel.R
# ==============================================================================
