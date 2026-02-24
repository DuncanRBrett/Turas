#' Report Hub — Main Orchestration
#'
#' Combines multiple Turas HTML reports into a single unified report.
#' Entry point: combine_reports()

# Source module files
hub_dir <- file.path("modules", "report_hub")
source(file.path(hub_dir, "00_guard.R"))
source(file.path(hub_dir, "01_html_parser.R"))
source(file.path(hub_dir, "02_namespace_rewriter.R"))
source(file.path(hub_dir, "03_front_page_builder.R"))
source(file.path(hub_dir, "04_navigation_builder.R"))
source(file.path(hub_dir, "07_page_assembler.R"))
source(file.path(hub_dir, "08_html_writer.R"))

#' Combine Multiple Turas HTML Reports
#'
#' Reads a config Excel file specifying which reports to combine,
#' parses each HTML report, namespaces their DOM/JS to avoid conflicts,
#' and assembles a single unified HTML report with two-tier navigation,
#' a front page, and unified pinned views.
#'
#' @param config_file Path to the Report Hub config Excel file
#'   containing Settings, Reports, and optionally CrossRef sheets.
#' @param output_file Path for the combined HTML output.
#'   If NULL, auto-generated from project title + date.
#' @param auto_cross_ref Logical. Attempt fuzzy matching of questions
#'   in addition to any explicit CrossRef mappings? Default FALSE.
#'
#' @return TRS-compliant list with:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSED"}
#'   \item{result}{List with output_path and diagnostics}
#'   \item{message}{Description of outcome}
#'
#' @examples
#' \dontrun{
#'   result <- combine_reports(
#'     config_file = "path/to/Combined_Config.xlsx",
#'     output_file = "Combined_Report.html"
#'   )
#'   if (result$status == "PASS") {
#'     browseURL(result$result$output_path)
#'   }
#' }
#'
#' @export
combine_reports <- function(config_file, output_file = NULL, auto_cross_ref = FALSE) {

  cat("\n=== Turas Report Hub ===\n")
  cat("Config:", config_file, "\n")

  # --- Step 1: Validate config ---
  cat("Step 1: Validating configuration...\n")
  guard_result <- guard_validate_hub_config(config_file)

  if (guard_result$status == "REFUSED") {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", guard_result$code, "\n")
    cat("Message:", guard_result$message, "\n")
    cat("Fix:", guard_result$how_to_fix, "\n")
    cat("==================\n\n")
    return(guard_result)
  }

  config <- guard_result$result
  warnings <- guard_result$warnings %||% character(0)

  cat(sprintf("  Found %d reports to combine\n", length(config$reports)))

  # --- Step 2: Generate output file path if not provided ---
  if (is.null(output_file)) {
    # Use config settings if available, otherwise auto-generate
    if (!is.null(config$settings$output_file)) {
      output_file <- config$settings$output_file
    } else {
      safe_title <- gsub("[^a-zA-Z0-9_-]", "_", config$settings$project_title)
      output_file <- sprintf("%s_Combined_%s.html",
                             safe_title, format(Sys.Date(), "%Y%m%d"))
    }

    # Prepend output_dir if configured and output_file is just a filename
    if (!is.null(config$settings$output_dir) && !grepl(.Platform$file.sep, output_file, fixed = TRUE)) {
      output_file <- file.path(config$settings$output_dir, output_file)
    }
  }

  # --- Step 3: Parse each report ---
  cat("Step 2: Parsing source reports...\n")
  parsed_reports <- list()

  for (report in config$reports) {
    cat(sprintf("  Parsing: %s (%s)\n", report$label, basename(report$path)))
    parsed <- parse_html_report(report$path, report$key)

    if (parsed$status == "REFUSED") {
      cat("\n=== TURAS ERROR ===\n")
      cat("Failed to parse:", report$label, "\n")
      cat("Code:", parsed$code, "\n")
      cat("Message:", parsed$message, "\n")
      cat("==================\n\n")
      return(parsed)
    }

    # Override type from config if specified
    if (!is.null(report$type)) {
      parsed$result$report_type <- report$type
    }

    cat(sprintf("    Type: %s, Panels: %d, JS blocks: %d\n",
                parsed$result$report_type,
                length(parsed$result$content_panels),
                length(parsed$result$js_blocks)))

    parsed_reports <- c(parsed_reports, list(parsed$result))
  }

  # --- Step 4: Namespace rewrite ---
  cat("Step 3: Namespacing for conflict resolution...\n")
  for (i in seq_along(parsed_reports)) {
    cat(sprintf("  Rewriting: %s\n", parsed_reports[[i]]$report_key))
    parsed_reports[[i]] <- rewrite_for_hub(parsed_reports[[i]])
  }

  # --- Step 5: Build navigation ---
  cat("Step 4: Building navigation...\n")
  navigation_html <- build_navigation(parsed_reports, config$reports)

  # --- Step 6: Build front page ---
  cat("Step 5: Building overview page...\n")
  overview_html <- build_front_page(config, parsed_reports)

  # --- Step 7: Assemble final HTML ---
  cat("Step 6: Assembling combined report...\n")
  final_html <- assemble_hub_html(config, parsed_reports, overview_html, navigation_html)

  # --- Step 8: Write output ---
  cat(sprintf("Step 7: Writing output: %s\n", output_file))
  write_result <- write_hub_html(final_html, output_file)

  if (write_result$status == "REFUSED") {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", write_result$code, "\n")
    cat("Message:", write_result$message, "\n")
    cat("==================\n\n")
    return(write_result)
  }

  # --- Done ---
  cat(sprintf("\nDone! Combined report: %s (%s)\n",
              write_result$result$output_path,
              write_result$result$size_label))
  cat("========================\n\n")

  status <- if (length(warnings) > 0) "PARTIAL" else "PASS"

  return(list(
    status = status,
    result = list(
      output_path = write_result$result$output_path,
      file_size = write_result$result$file_size,
      n_reports = length(parsed_reports),
      report_keys = sapply(parsed_reports, function(p) p$report_key)
    ),
    warnings = warnings,
    message = sprintf("Combined %d reports into %s (%s)",
                      length(parsed_reports),
                      basename(output_file),
                      write_result$result$size_label)
  ))
}

#' Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x
