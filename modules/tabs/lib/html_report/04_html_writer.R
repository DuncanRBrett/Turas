# ==============================================================================
# HTML REPORT - HTML WRITER (V10.3.2)
# ==============================================================================
# Writes the assembled HTML page to a self-contained file.
# Plain HTML tables — no external JS/CSS dependencies to inline.
# ==============================================================================


#' Write HTML Report to File
#'
#' Saves the complete HTML page as a self-contained .html file.
#' Since we use plain HTML tables (no htmlwidgets/reactable), the output
#' is already self-contained — no dependency inlining needed.
#'
#' @param page htmltools::browsable tagList from build_html_page()
#' @param output_path Character, full path to write the .html file
#' @return List with status = "PASS" and file details, or TRS refusal
#' @export
write_html_report <- function(page, output_path) {

  # Validate output path
  if (missing(output_path) || is.null(output_path) || !nzchar(output_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_PATH",
      message = "Output path for HTML report is missing or empty",
      how_to_fix = "Provide a valid output file path ending in .html",
      context = list(output_path = output_path)
    ))
  }

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir_result <- tryCatch({
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      NULL
    }, error = function(e) {
      list(
        status = "REFUSED",
        code = "IO_DIR_CREATE_FAILED",
        message = sprintf("Cannot create output directory: %s", output_dir),
        how_to_fix = "Check directory permissions and path validity",
        context = list(error = e$message)
      )
    })
    if (!is.null(dir_result)) return(dir_result)
  }

  # Write the HTML file
  tryCatch({
    # Render the htmltools tagList to a character string
    html_content <- htmltools::renderTags(page)

    # Build a complete HTML document
    html_doc <- paste0(
      '<!DOCTYPE html>\n<html lang="en">\n<head>\n',
      html_content$head,
      '\n</head>\n<body style="background:#f8f7f5">\n',
      html_content$html,
      '\n</body>\n</html>'
    )

    # Write directly — no temp dir, no dependency inlining needed
    writeLines(html_doc, output_path, useBytes = TRUE)

    # Verify file was written
    if (!file.exists(output_path)) {
      return(list(
        status = "REFUSED",
        code = "IO_WRITE_FAILED",
        message = "HTML file was not created despite no error",
        how_to_fix = "Check disk space and file system permissions",
        context = list(output_path = output_path)
      ))
    }

    # Get file size
    file_size_bytes <- file.info(output_path)$size
    file_size_mb <- file_size_bytes / (1024 * 1024)

    # Warn if file is large
    if (file_size_mb > 5) {
      cat(sprintf("\n  [WARNING] HTML report is %.1f MB. Consider setting embed_frequencies = FALSE in config to reduce size.\n",
                  file_size_mb))
    }

    list(
      status = "PASS",
      message = sprintf("HTML report written successfully (%.1f MB)", file_size_mb),
      output_file = output_path,
      file_size_bytes = file_size_bytes,
      file_size_mb = round(file_size_mb, 2)
    )

  }, error = function(e) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: IO_HTML_WRITE_FAILED\n")
    cat("Message:", e$message, "\n")
    cat("Output path:", output_path, "\n")
    cat("==================\n\n")

    list(
      status = "REFUSED",
      code = "IO_HTML_WRITE_FAILED",
      message = sprintf("Failed to write HTML report: %s", e$message),
      how_to_fix = "Check disk space, permissions, and that htmltools is installed",
      context = list(error = e$message, output_path = output_path)
    )
  })
}
