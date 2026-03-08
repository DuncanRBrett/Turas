# ==============================================================================
# CONFIDENCE HTML REPORT - FILE WRITER
# ==============================================================================
# Writes the assembled HTML page to disk as a self-contained file.
# ==============================================================================

#' Write Confidence HTML Report to Disk
#'
#' Renders the htmltools page object to a string and writes it as a
#' self-contained HTML file.
#'
#' @param page Character string. Complete HTML content
#' @param output_path Character. File path for the output .html file
#' @return List with status, output_file, file_size_bytes, file_size_mb
#' @keywords internal
write_confidence_html_report <- function(page, output_path) {
  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir_result <- tryCatch({
      dir.create(output_dir, recursive = TRUE)
      NULL  # Success — no error to report
    }, error = function(e) {
      cat("\n=== TURAS ERROR ===\n")
      cat("Code: IO_DIR_CREATE_FAILED\n")
      cat("Message:", e$message, "\n")
      cat("==================\n\n")
      list(
        status = "REFUSED",
        code = "IO_DIR_CREATE_FAILED",
        message = sprintf("Cannot create output directory: %s", output_dir),
        how_to_fix = "Check that the parent directory exists and is writable"
      )
    })
    # If dir creation failed, return the error (tryCatch return fix)
    if (!is.null(dir_result)) return(dir_result)
  }

  # Write the HTML file
  tryCatch({
    writeLines(page, output_path)

    file_size <- file.info(output_path)$size

    list(
      status = "PASS",
      output_file = normalizePath(output_path),
      file_size_bytes = file_size,
      file_size_mb = round(file_size / (1024 * 1024), 2)
    )
  }, error = function(e) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: IO_WRITE_FAILED\n")
    cat("Message:", e$message, "\n")
    cat("==================\n\n")
    list(
      status = "REFUSED",
      code = "IO_WRITE_FAILED",
      message = sprintf("Failed to write HTML file: %s", e$message),
      how_to_fix = "Check file path and disk permissions"
    )
  })
}
