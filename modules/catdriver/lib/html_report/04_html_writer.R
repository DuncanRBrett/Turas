# ==============================================================================
# CATDRIVER HTML REPORT - HTML WRITER
# ==============================================================================
# Writes the assembled HTML page to a self-contained file.
# Uses atomic write pattern for safety.
# ==============================================================================

#' Write Catdriver HTML Report to File
#'
#' Saves the complete HTML page as a self-contained .html file.
#'
#' @param page htmltools::browsable tagList from build_cd_html_page()
#' @param output_path Character, full path to write the .html file
#' @return List with status, output_file, file_size_mb
#' @keywords internal
write_cd_html_report <- function(page, output_path) {

  # Validate output path
  if (missing(output_path) || is.null(output_path) || !nzchar(output_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_PATH",
      message = "Output path for HTML report is missing or empty",
      how_to_fix = "Provide a valid output file path ending in .html"
    ))
  }

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir_ok <- tryCatch({
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      TRUE
    }, error = function(e) FALSE)

    if (!dir_ok) {
      return(list(
        status = "REFUSED",
        code = "IO_DIR_CREATE_FAILED",
        message = sprintf("Cannot create output directory: %s", output_dir),
        how_to_fix = "Check directory permissions and path validity"
      ))
    }
  }

  tryCatch({
    # Render htmltools tagList
    html_content <- htmltools::renderTags(page)

    html_doc <- paste0(
      '<!DOCTYPE html>\n<html lang="en">\n<head>\n',
      html_content$head,
      '\n</head>\n<body class="cd-body">\n',
      html_content$html,
      '\n</body>\n</html>'
    )

    # Atomic write: write to temp file first, then rename
    temp_path <- paste0(output_path, ".tmp")
    writeLines(html_doc, temp_path, useBytes = TRUE)

    if (!file.exists(temp_path)) {
      return(list(
        status = "REFUSED",
        code = "IO_WRITE_FAILED",
        message = "Temporary HTML file was not created",
        how_to_fix = "Check disk space and file system permissions"
      ))
    }

    # Rename temp to final
    file.rename(temp_path, output_path)

    if (!file.exists(output_path)) {
      return(list(
        status = "REFUSED",
        code = "IO_WRITE_FAILED",
        message = "HTML file rename failed",
        how_to_fix = "Check disk space and file system permissions"
      ))
    }

    file_size_bytes <- file.info(output_path)$size
    file_size_mb <- file_size_bytes / (1024 * 1024)

    list(
      status = "PASS",
      message = sprintf("HTML report written successfully (%.1f MB)", file_size_mb),
      output_file = output_path,
      file_size_bytes = file_size_bytes,
      file_size_mb = round(file_size_mb, 2)
    )

  }, error = function(e) {
    # Clean up temp file if it exists
    temp_path <- paste0(output_path, ".tmp")
    if (file.exists(temp_path)) unlink(temp_path)

    cat("\n=== TURAS ERROR ===\n")
    cat("Code: IO_HTML_WRITE_FAILED\n")
    cat("Message:", e$message, "\n")
    cat("Output path:", output_path, "\n")
    cat("==================\n\n")

    list(
      status = "REFUSED",
      code = "IO_HTML_WRITE_FAILED",
      message = sprintf("Failed to write HTML report: %s", e$message),
      how_to_fix = "Check disk space, permissions, and that htmltools is installed"
    )
  })
}
