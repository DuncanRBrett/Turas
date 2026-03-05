# ==============================================================================
# SEGMENT HTML REPORT - INPUT GUARD
# ==============================================================================
# Validates inputs before HTML report generation.
# Version: 11.0
# ==============================================================================


#' Validate Segment HTML Report Inputs
#'
#' Checks that all required data is present and the output path is valid.
#'
#' @param results List with segmentation results
#' @param config Configuration list
#' @param output_path Character, output file path
#' @return List with status = "PASS" or "REFUSED"
#' @keywords internal
validate_segment_html_inputs <- function(results, config, output_path) {

  # Check htmltools
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_HTMLTOOLS_MISSING",
      message = "Package 'htmltools' is required for HTML report generation but is not installed.",
      how_to_fix = "Install htmltools: install.packages('htmltools')"
    ))
  }

  # Check results
  if (is.null(results) || !is.list(results)) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID_RESULTS",
      message = "Results object is NULL or not a list.",
      how_to_fix = "Ensure segmentation analysis completed successfully."
    ))
  }

  # Check mode
  mode <- results$mode %||% "final"
  if (!(mode %in% c("final", "exploration"))) {
    return(list(
      status = "REFUSED",
      code = "CFG_INVALID_MODE",
      message = sprintf("Invalid report mode: '%s'. Expected 'final' or 'exploration'.", mode),
      how_to_fix = "Set results$mode to 'final' or 'exploration'."
    ))
  }

  # Mode-specific field checks
  if (mode == "final") {
    required_fields <- c("cluster_result", "validation_metrics", "profile_result", "segment_names")
    for (field in required_fields) {
      if (is.null(results[[field]])) {
        return(list(
          status = "REFUSED",
          code = "DATA_MISSING_FIELD",
          message = sprintf("Required field '%s' is missing from results.", field),
          how_to_fix = sprintf("Ensure results$%s is populated before generating HTML report.", field)
        ))
      }
    }
  } else {
    required_fields <- c("exploration_result", "metrics_result", "recommendation")
    for (field in required_fields) {
      if (is.null(results[[field]])) {
        return(list(
          status = "REFUSED",
          code = "DATA_MISSING_FIELD",
          message = sprintf("Required field '%s' is missing from exploration results.", field),
          how_to_fix = sprintf("Ensure results$%s is populated before generating HTML report.", field)
        ))
      }
    }
  }

  # Check config
  if (is.null(config) || !is.list(config)) {
    return(list(
      status = "REFUSED",
      code = "CFG_INVALID_CONFIG",
      message = "Config is NULL or not a list.",
      how_to_fix = "Provide a valid configuration list."
    ))
  }

  # Check output path
  if (is.null(output_path) || !nzchar(output_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_OUTPUT_PATH",
      message = "Output path is empty or NULL.",
      how_to_fix = "Provide a valid output file path ending in .html."
    ))
  }

  # Create output directory if needed
  out_dir <- dirname(output_path)
  if (!dir.exists(out_dir)) {
    tryCatch({
      dir.create(out_dir, recursive = TRUE)
    }, error = function(e) {
      return(list(
        status = "REFUSED",
        code = "IO_CANNOT_CREATE_DIR",
        message = sprintf("Cannot create output directory: %s", out_dir),
        how_to_fix = "Check directory permissions and path validity."
      ))
    })
  }

  list(status = "PASS", message = "Segment HTML report inputs validated successfully.")
}
