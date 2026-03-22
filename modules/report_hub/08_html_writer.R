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

  # Write file as raw UTF-8 bytes.
  # Using writeBin(charToRaw(enc2utf8(...))) instead of writeLines() ensures
  # correct encoding on Windows (where R's native encoding may be Latin-1).
  result <- tryCatch({
    con <- file(output_file, open = "wb")
    tryCatch(
      writeBin(charToRaw(enc2utf8(html)), con),
      finally = close(con)
    )
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

  # normalizePath can throw on symlinks or edge-case paths — protect it
  norm_path <- tryCatch(
    normalizePath(output_file, mustWork = FALSE),
    error = function(e) output_file
  )

  return(list(
    status = "PASS",
    result = list(
      output_path = norm_path,
      file_size = file_size,
      size_label = size_label
    ),
    message = sprintf("Combined report written: %s (%s)", basename(output_file), size_label)
  ))
}
