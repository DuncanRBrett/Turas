# ==============================================================================
# TurasTracker HTML Report - Guard Layer
# ==============================================================================
# Validates inputs before HTML report generation.
# VERSION: 1.0.0
# ==============================================================================


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(a, b) if (!is.null(a)) a else b


#' Validate Tracker HTML Report Inputs
#'
#' Checks that crosstab_data, config, and required packages are valid
#' before HTML generation proceeds.
#'
#' @param crosstab_data List. Output from build_tracking_crosstab()
#' @param config List. Tracker configuration object
#' @return List with status "PASS" or TRS refusal
#' @export
validate_tracker_html_inputs <- function(crosstab_data, config) {

  # Check required packages
  for (pkg in c("htmltools", "jsonlite")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      return(list(
        status = "REFUSED",
        code = "PKG_MISSING",
        message = sprintf("Required package '%s' is not installed", pkg),
        how_to_fix = sprintf("Install the package: install.packages('%s')", pkg),
        context = list(package = pkg)
      ))
    }
  }

  # Validate crosstab_data is a list

if (!is.list(crosstab_data)) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = "crosstab_data must be a list",
      how_to_fix = "Provide the output from build_tracking_crosstab()",
      context = list(class = class(crosstab_data))
    ))
  }

  # Required fields
  required_fields <- c("metrics", "waves", "wave_labels", "banner_segments",
                        "baseline_wave", "sections", "metadata")
  missing_fields <- setdiff(required_fields, names(crosstab_data))
  if (length(missing_fields) > 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING_FIELDS",
      message = sprintf("crosstab_data is missing required fields: %s",
                        paste(missing_fields, collapse = ", ")),
      how_to_fix = "Ensure crosstab_data is the output of build_tracking_crosstab()",
      context = list(missing = missing_fields)
    ))
  }

  # Validate metrics is a non-empty list
  if (!is.list(crosstab_data$metrics) || length(crosstab_data$metrics) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_EMPTY_METRICS",
      message = "crosstab_data$metrics is empty or not a list",
      how_to_fix = "Ensure tracked questions are configured and trend results are available",
      context = list(n_metrics = length(crosstab_data$metrics))
    ))
  }

  # Validate waves match wave_labels
  if (length(crosstab_data$waves) != length(crosstab_data$wave_labels)) {
    return(list(
      status = "REFUSED",
      code = "DATA_WAVE_MISMATCH",
      message = "waves and wave_labels have different lengths",
      how_to_fix = "Check configuration - each wave needs a label",
      context = list(
        n_waves = length(crosstab_data$waves),
        n_labels = length(crosstab_data$wave_labels)
      )
    ))
  }

  # Validate config
  if (!is.list(config)) {
    return(list(
      status = "REFUSED",
      code = "CFG_INVALID",
      message = "config must be a list",
      how_to_fix = "Provide a valid tracker configuration object",
      context = list(class = class(config))
    ))
  }

  list(status = "PASS", message = "HTML report inputs validated successfully")
}
