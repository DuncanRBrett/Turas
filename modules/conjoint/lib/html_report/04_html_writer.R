# ==============================================================================
# CONJOINT HTML REPORT - WRITER
# ==============================================================================
# Writes the assembled HTML to disk
# ==============================================================================

#' Write Conjoint HTML Report to Disk
#'
#' @param page Complete HTML string
#' @param output_path File path for output
#' @return TRS status list
#' @keywords internal
write_conjoint_html_report <- function(page, output_path) {

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  tryCatch({
    writeLines(page, output_path, useBytes = TRUE)

    file_size <- file.size(output_path)
    file_size_mb <- round(file_size / (1024 * 1024), 2)

    cat(sprintf("\n  [HTML REPORT] Written to: %s (%.2f MB)\n", output_path, file_size_mb))

    list(
      status = "PASS",
      output_path = output_path,
      file_size_bytes = file_size,
      file_size_mb = file_size_mb
    )
  }, error = function(e) {
    cat(sprintf("\n  [HTML REPORT ERROR] Failed to write: %s\n", conditionMessage(e)))

    list(
      status = "REFUSED",
      code = "IO_HTML_WRITE_FAILED",
      message = sprintf("Failed to write HTML report: %s", conditionMessage(e)),
      how_to_fix = c(
        "Check that the output directory exists and is writable",
        "Ensure the file is not open in a browser",
        sprintf("Attempted path: %s", output_path)
      )
    )
  })
}
