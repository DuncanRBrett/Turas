# ==============================================================================
# KEYDRIVER HTML REPORT - GUARD LAYER
# ==============================================================================
# Validates inputs before HTML report generation.
# Returns TRS refusals on invalid input, never uses stop().
# ==============================================================================

# Null-coalescing operator
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

#' Validate Inputs for Keydriver HTML Report
#'
#' Checks all required inputs before generating the HTML report.
#' Uses TRS refusal pattern - returns structured error list on failure.
#'
#' @param results Analysis results from run_keydriver_analysis()
#' @param config Configuration list
#' @param output_path Character, path for the output .html file
#' @return List with status = "PASS" on success, or TRS refusal
#' @keywords internal
validate_keydriver_html_inputs <- function(results, config, output_path) {

  # Check required packages
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_HTMLTOOLS_MISSING",
      message = "Package 'htmltools' is required for HTML report generation",
      how_to_fix = "Install htmltools: renv::install('htmltools')"
    ))
  }

  # Check results object
  if (missing(results) || is.null(results) || !is.list(results)) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING",
      message = "Required parameter 'results' is missing or not a list",
      how_to_fix = "Provide analysis results from run_keydriver_analysis()"
    ))
  }

  # Check required result components
  # Accept either 'model' (lm object) or 'model_summary' (pre-computed)
  required_fields <- c("importance", "correlations")
  missing_fields <- setdiff(required_fields, names(results))
  if (is.null(results$model) && is.null(results$model_summary)) {
    missing_fields <- c(missing_fields, "model or model_summary")
  }

  if (length(missing_fields) > 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = sprintf("Results missing required fields: %s",
                        paste(missing_fields, collapse = ", ")),
      how_to_fix = "Ensure analysis completed successfully before generating HTML report"
    ))
  }

  # Check importance is a data frame with rows
  if (!is.data.frame(results$importance) || nrow(results$importance) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = "Results$importance must be a non-empty data frame",
      how_to_fix = "Ensure driver importance analysis completed successfully"
    ))
  }

  # Check config
  if (missing(config) || is.null(config) || !is.list(config)) {
    return(list(
      status = "REFUSED",
      code = "CFG_INVALID",
      message = "Required parameter 'config' is missing or not a list",
      how_to_fix = "Provide configuration list from load_keydriver_config()"
    ))
  }

  # Check output path
  if (missing(output_path) || is.null(output_path) || !nzchar(output_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_PATH",
      message = "Output path for HTML report is missing or empty",
      how_to_fix = "Provide a valid output file path ending in .html"
    ))
  }

  # Check output directory is writable
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

  list(status = "PASS", message = "Keydriver HTML report inputs validated successfully")
}
