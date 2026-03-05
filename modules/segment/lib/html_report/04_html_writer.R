# ==============================================================================
# SEGMENT HTML REPORT - HTML WRITER
# ==============================================================================
# Writes the assembled HTML page to disk using atomic write pattern.
# Write to .tmp then rename to final path for crash safety.
# Version: 11.0
# ==============================================================================


#' Write Segment HTML Report to Disk
#'
#' Renders the htmltools page object to a self-contained HTML file.
#' Uses atomic write: writes to .tmp then renames.
#'
#' @param page htmltools tag list from build_seg_html_page()
#' @param output_path Character, output file path
#' @return List with status, output_file, file_size_mb
#' @keywords internal
write_seg_html_report <- function(page, output_path) {

  if (is.null(output_path) || !nzchar(output_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_OUTPUT_PATH",
      message = "Output path is empty or NULL."
    ))
  }

  # Ensure output directory exists
  out_dir <- dirname(output_path)
  if (!dir.exists(out_dir)) {
    tryCatch({
      dir.create(out_dir, recursive = TRUE)
    }, error = function(e) {
      return(list(
        status = "REFUSED",
        code = "IO_CANNOT_CREATE_DIR",
        message = sprintf("Cannot create output directory: %s - %s", out_dir, e$message)
      ))
    })
  }

  temp_path <- paste0(output_path, ".tmp")

  tryCatch({
    # Render htmltools page
    html_content <- htmltools::renderTags(page)

    # Assemble full document
    html_doc <- paste0(
      '<!DOCTYPE html>\n',
      '<html lang="en">\n',
      '<head>\n',
      html_content$head,
      '\n</head>\n',
      '<body class="seg-body">\n',
      html_content$html,
      '\n</body>\n',
      '</html>'
    )

    # Atomic write: write to temp, then rename
    writeLines(html_doc, temp_path, useBytes = TRUE)
    file.rename(temp_path, output_path)

    # Get file size
    file_size_bytes <- file.info(output_path)$size
    file_size_mb <- round(file_size_bytes / 1024 / 1024, 2)

    cat(sprintf("    HTML report written: %s (%.2f MB)\n", basename(output_path), file_size_mb))

    list(
      status = "PASS",
      output_file = output_path,
      file_size_bytes = file_size_bytes,
      file_size_mb = file_size_mb
    )

  }, error = function(e) {
    # Clean up temp file on error
    if (file.exists(temp_path)) {
      tryCatch(unlink(temp_path), error = function(e2) NULL)
    }

    cat(sprintf("\n=== TURAS ERROR ===\n"))
    cat(sprintf("Context: Segment HTML Report Writer\n"))
    cat(sprintf("Error: %s\n", e$message))
    cat(sprintf("Output path: %s\n", output_path))
    cat(sprintf("===================\n\n"))

    list(
      status = "REFUSED",
      code = "IO_WRITE_FAILED",
      message = sprintf("Failed to write HTML report: %s", e$message),
      how_to_fix = "Check disk space, file permissions, and output path validity."
    )
  })
}
