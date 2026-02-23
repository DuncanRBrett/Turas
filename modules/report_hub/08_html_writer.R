#' HTML Writer
#'
#' Writes the assembled HTML to a file.

#' Write Combined Report HTML to File
#'
#' @param html Complete HTML string
#' @param output_file Output file path
#' @return TRS-compliant result
write_hub_html <- function(html, output_file) {
  # Ensure output directory exists
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(output_dir)) {
      return(list(
        status = "REFUSED",
        code = "IO_DIR_CREATE_FAILED",
        message = sprintf("Cannot create output directory: %s", output_dir),
        how_to_fix = "Check write permissions for the output directory."
      ))
    }
  }

  # Write file
  result <- tryCatch({
    writeLines(html, output_file, useBytes = TRUE)
    TRUE
  }, error = function(e) {
    e$message
  })

  if (is.character(result)) {
    return(list(
      status = "REFUSED",
      code = "IO_WRITE_FAILED",
      message = sprintf("Failed to write output file: %s", result),
      how_to_fix = "Check write permissions and available disk space."
    ))
  }

  file_size <- file.info(output_file)$size
  size_label <- if (file_size > 1024 * 1024) {
    sprintf("%.1f MB", file_size / (1024 * 1024))
  } else {
    sprintf("%.0f KB", file_size / 1024)
  }

  return(list(
    status = "PASS",
    result = list(
      output_path = normalizePath(output_file),
      file_size = file_size,
      size_label = size_label
    ),
    message = sprintf("Combined report written: %s (%s)", basename(output_file), size_label)
  ))
}
