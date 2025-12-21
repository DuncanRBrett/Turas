# ==============================================================================
# TURAS ATOMIC WORKBOOK SAVE (TRS v1.0)
# ==============================================================================
#
# Provides atomic file saving with refusal hardening for Excel workbooks.
# Prevents partial/corrupt files from being written on failure.
#
# USAGE:
#   result <- turas_save_workbook_atomic(wb, "output.xlsx", run_result)
#   if (!result$success) { handle error }
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================


#' Atomic Workbook Save with TRS Integration
#'
#' Saves an openxlsx workbook atomically by writing to a temp file first,
#' then renaming. This prevents corrupt/partial files on failure.
#'
#' @param wb The openxlsx workbook object
#' @param file_path The target file path
#' @param run_result Optional TRS run_result object for event logging
#' @param module Module name for logging (default: "TURAS")
#' @param overwrite Logical. Overwrite existing file? (default TRUE)
#' @param verbose Logical. Print progress messages? (default TRUE)
#'
#' @return List with success (logical), file_path, error (if any)
#' @export
turas_save_workbook_atomic <- function(wb,
                                        file_path,
                                        run_result = NULL,
                                        module = "TURAS",
                                        overwrite = TRUE,
                                        verbose = TRUE) {

  # Validate inputs

if (is.null(wb)) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Cannot save NULL workbook", code = paste0(module, "_NULL_WB"))
    }
    return(list(success = FALSE, file_path = file_path, error = "Workbook is NULL"))
  }

  if (!inherits(wb, "Workbook")) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Invalid workbook object", code = paste0(module, "_INVALID_WB"))
    }
    return(list(success = FALSE, file_path = file_path, error = "Object is not an openxlsx Workbook"))
  }

  # Normalize the file path
  file_path <- normalizePath(file_path, mustWork = FALSE)
  dir_path <- dirname(file_path)

  # Ensure directory exists
  if (!dir.exists(dir_path)) {
    tryCatch({
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    }, error = function(e) {
      if (exists("turas_log_refuse", mode = "function")) {
        turas_log_refuse(module, paste("Cannot create directory:", dir_path),
                         code = paste0(module, "_DIR_FAIL"))
      }
      return(list(success = FALSE, file_path = file_path,
                  error = paste("Cannot create directory:", e$message)))
    })
  }

  # Check if file exists and we can't overwrite
  if (file.exists(file_path) && !overwrite) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, paste("File exists and overwrite=FALSE:", basename(file_path)),
                       code = paste0(module, "_FILE_EXISTS"))
    }
    return(list(success = FALSE, file_path = file_path,
                error = "File exists and overwrite is FALSE"))
  }

  # Create temp file path in same directory (for atomic rename)
  temp_file <- paste0(file_path, ".tmp.", format(Sys.time(), "%Y%m%d%H%M%S"), ".", Sys.getpid())

  # Attempt to save to temp file
  save_error <- NULL
  save_success <- tryCatch({
    if (verbose) {
      cat(sprintf("   Writing: %s\n", basename(file_path)))
    }

    # Use openxlsx saveWorkbook
    openxlsx::saveWorkbook(wb, temp_file, overwrite = TRUE)
    TRUE
  }, error = function(e) {
    save_error <<- e$message
    FALSE
  })

  if (!save_success) {
    # Clean up temp file if it exists
    if (file.exists(temp_file)) {
      try(unlink(temp_file), silent = TRUE)
    }

    # Log the failure
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, paste("Failed to write workbook:", save_error),
                       code = paste0(module, "_WRITE_FAIL"))
    }

    # Record in run_result if available
    if (!is.null(run_result) && exists("turas_run_state_event", mode = "function")) {
      turas_run_state_event(run_result, "REFUSE",
                            paste("Workbook write failed:", save_error),
                            code = paste0(module, "_WRITE_FAIL"))
    }

    return(list(success = FALSE, file_path = file_path,
                error = paste("Write failed:", save_error)))
  }

  # Verify temp file was created and has content
  if (!file.exists(temp_file)) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Temp file not created after save",
                       code = paste0(module, "_TEMP_MISSING"))
    }
    return(list(success = FALSE, file_path = file_path,
                error = "Temp file was not created"))
  }

  temp_size <- file.info(temp_file)$size
  if (is.na(temp_size) || temp_size == 0) {
    try(unlink(temp_file), silent = TRUE)
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Temp file is empty",
                       code = paste0(module, "_EMPTY_FILE"))
    }
    return(list(success = FALSE, file_path = file_path,
                error = "Saved file is empty"))
  }

  # Atomic rename: remove old file, rename temp to final
  rename_error <- NULL
  rename_success <- tryCatch({
    # Remove existing file if present
    if (file.exists(file_path)) {
      unlink(file_path)
    }

    # Rename temp to final (atomic on most filesystems)
    file.rename(temp_file, file_path)
  }, error = function(e) {
    rename_error <<- e$message
    FALSE
  })

  if (!rename_success) {
    # Try to clean up
    if (file.exists(temp_file)) {
      try(unlink(temp_file), silent = TRUE)
    }

    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, paste("Failed to rename temp file:", rename_error),
                       code = paste0(module, "_RENAME_FAIL"))
    }

    return(list(success = FALSE, file_path = file_path,
                error = paste("Rename failed:", rename_error)))
  }

  # Final verification
  if (!file.exists(file_path)) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Final file not found after rename",
                       code = paste0(module, "_VERIFY_FAIL"))
    }
    return(list(success = FALSE, file_path = file_path,
                error = "Final file missing after rename"))
  }

  final_size <- file.info(file_path)$size

  # Log success
  if (verbose && exists("turas_log_info", mode = "function")) {
    turas_log_info(module, sprintf("Saved: %s (%s bytes)", basename(file_path), format(final_size, big.mark = ",")))
  }

  # Record success in run_result if available
  if (!is.null(run_result) && exists("turas_run_state_event", mode = "function")) {
    turas_run_state_event(run_result, "INFO",
                          sprintf("Output saved: %s", basename(file_path)),
                          code = paste0(module, "_SAVED"))
  }

  return(list(success = TRUE, file_path = file_path, size = final_size, error = NULL))
}


#' Atomic Save for writexl (Non-openxlsx Workbooks)
#'
#' For modules using writexl instead of openxlsx, provides similar atomic
#' save functionality for data frame lists.
#'
#' @param sheets Named list of data frames (sheet_name = data.frame)
#' @param file_path The target file path
#' @param run_result Optional TRS run_result object
#' @param module Module name for logging (default: "TURAS")
#' @param verbose Logical. Print progress messages? (default TRUE)
#'
#' @return List with success (logical), file_path, error (if any)
#' @export
turas_save_writexl_atomic <- function(sheets,
                                       file_path,
                                       run_result = NULL,
                                       module = "TURAS",
                                       verbose = TRUE) {

  # Validate inputs
  if (!is.list(sheets) || length(sheets) == 0) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Sheets must be a non-empty named list",
                       code = paste0(module, "_INVALID_SHEETS"))
    }
    return(list(success = FALSE, file_path = file_path, error = "Invalid sheets input"))
  }

  # Check writexl is available
  if (!requireNamespace("writexl", quietly = TRUE)) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "writexl package not available",
                       code = paste0(module, "_NO_WRITEXL"))
    }
    return(list(success = FALSE, file_path = file_path, error = "writexl not installed"))
  }

  # Normalize the file path
  file_path <- normalizePath(file_path, mustWork = FALSE)
  dir_path <- dirname(file_path)

  # Ensure directory exists
  if (!dir.exists(dir_path)) {
    tryCatch({
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    }, error = function(e) {
      return(list(success = FALSE, file_path = file_path,
                  error = paste("Cannot create directory:", e$message)))
    })
  }

  # Create temp file path
  temp_file <- paste0(file_path, ".tmp.", format(Sys.time(), "%Y%m%d%H%M%S"), ".", Sys.getpid())

  # Attempt to save
  save_error <- NULL
  save_success <- tryCatch({
    if (verbose) {
      cat(sprintf("   Writing: %s\n", basename(file_path)))
    }
    writexl::write_xlsx(sheets, temp_file)
    TRUE
  }, error = function(e) {
    save_error <<- e$message
    FALSE
  })

  if (!save_success) {
    if (file.exists(temp_file)) {
      try(unlink(temp_file), silent = TRUE)
    }

    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, paste("writexl save failed:", save_error),
                       code = paste0(module, "_WRITEXL_FAIL"))
    }

    return(list(success = FALSE, file_path = file_path,
                error = paste("Write failed:", save_error)))
  }

  # Verify and rename
  if (!file.exists(temp_file) || file.info(temp_file)$size == 0) {
    try(unlink(temp_file), silent = TRUE)
    return(list(success = FALSE, file_path = file_path, error = "Temp file empty or missing"))
  }

  # Atomic rename
  rename_success <- tryCatch({
    if (file.exists(file_path)) unlink(file_path)
    file.rename(temp_file, file_path)
  }, error = function(e) {
    FALSE
  })

  if (!rename_success) {
    try(unlink(temp_file), silent = TRUE)
    return(list(success = FALSE, file_path = file_path, error = "Rename failed"))
  }

  final_size <- file.info(file_path)$size

  if (verbose && exists("turas_log_info", mode = "function")) {
    turas_log_info(module, sprintf("Saved: %s (%s bytes)", basename(file_path), format(final_size, big.mark = ",")))
  }

  return(list(success = TRUE, file_path = file_path, size = final_size, error = NULL))
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

if (interactive()) {
  message("[TRS INFO] Atomic workbook save helper loaded (turas_save_workbook_atomic v1.0)")
}
