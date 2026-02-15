# ==============================================================================
# HTML REPORT - GUARD LAYER (V10.3.2)
# ==============================================================================
# Validates inputs before HTML report generation.
# Returns TRS refusals on invalid input, never uses stop().
# No external dependencies required beyond htmltools (base R ecosystem).
# ==============================================================================

#' Validate Inputs for HTML Report Generation
#'
#' Checks all required inputs before generating the HTML crosstab report.
#' Uses TRS refusal pattern - returns structured error list on failure.
#'
#' @param all_results List of question results from analysis_runner
#' @param banner_info List from create_banner_structure
#' @param config_obj List, configuration object
#' @return List with status = "PASS" on success, or TRS refusal
#' @export
validate_html_report_inputs <- function(all_results, banner_info, config_obj) {

  # Check htmltools is available
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    return(list(
      status = "REFUSED",
      code = "PKG_HTMLTOOLS_MISSING",
      message = "Package 'htmltools' is required for HTML report generation",
      how_to_fix = "Install htmltools: renv::install('htmltools')",
      context = list(call = match.call())
    ))
  }

  # Check all_results
  if (missing(all_results) || is.null(all_results)) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING",
      message = "Required parameter 'all_results' is missing or NULL",
      how_to_fix = "Provide analysis results from run_crosstabs_analysis()",
      context = list(call = match.call())
    ))
  }

  if (!is.list(all_results) || length(all_results) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = "Parameter 'all_results' must be a non-empty named list",
      how_to_fix = "Ensure analysis completed successfully and produced results",
      context = list(type = class(all_results), length = length(all_results))
    ))
  }

  if (is.null(names(all_results))) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = "Parameter 'all_results' must be a named list (keyed by question code)",
      how_to_fix = "Ensure all_results has names corresponding to question codes",
      context = list(call = match.call())
    ))
  }

  # Validate question structure - find first non-empty question
  first_q <- NULL
  first_q_name <- NULL
  for (qname in names(all_results)) {
    q <- all_results[[qname]]
    if (is.list(q) && is.data.frame(q$table) && nrow(q$table) > 0) {
      first_q <- q
      first_q_name <- qname
      break
    }
  }

  if (is.null(first_q)) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = "No questions in all_results have non-empty tables",
      how_to_fix = "Check that analysis completed successfully and produced results",
      context = list(n_questions = length(all_results))
    ))
  }

  required_cols <- c("RowLabel", "RowType")
  missing_cols <- setdiff(required_cols, names(first_q$table))
  if (length(missing_cols) > 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = sprintf("Question table missing required columns: %s",
                        paste(missing_cols, collapse = ", ")),
      how_to_fix = "Ensure analysis produced tables with RowLabel and RowType columns",
      context = list(available_cols = names(first_q$table),
                     checked_question = first_q_name)
    ))
  }

  # Check banner_info
  if (missing(banner_info) || is.null(banner_info)) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING",
      message = "Required parameter 'banner_info' is missing or NULL",
      how_to_fix = "Provide banner structure from create_banner_structure()",
      context = list(call = match.call())
    ))
  }

  required_banner_fields <- c("banner_info", "internal_keys", "columns", "letters")
  missing_fields <- setdiff(required_banner_fields, names(banner_info))
  if (length(missing_fields) > 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID",
      message = sprintf("banner_info missing required fields: %s",
                        paste(missing_fields, collapse = ", ")),
      how_to_fix = "Ensure banner structure was created correctly by create_banner_structure()",
      context = list(available_fields = names(banner_info))
    ))
  }

  # Check config_obj
  if (missing(config_obj) || is.null(config_obj) || !is.list(config_obj)) {
    return(list(
      status = "REFUSED",
      code = "CFG_INVALID",
      message = "Required parameter 'config_obj' is missing, NULL, or not a list",
      how_to_fix = "Provide configuration object from build_config_object()",
      context = list(call = match.call())
    ))
  }

  # All checks passed
  list(status = "PASS", message = "HTML report inputs validated successfully")
}
