# ==============================================================================
# TURAS > HUB APP — Single-File Hub Generator
# ==============================================================================
# Purpose: Auto-generate a Report Hub config and call combine_reports() to
#          produce a self-contained HTML deliverable from a project's reports.
# Location: modules/hub_app/lib/hub_generator.R
# ==============================================================================

#' Generate Single-File Hub from a Project
#'
#' Auto-generates a Report Hub Excel config file from the reports discovered
#' in a project directory, then calls the report_hub module's combine_reports()
#' to produce a self-contained combined HTML file.
#'
#' @param project_path Path to the project directory containing HTML reports
#' @param project_name Display name for the combined report title
#' @param output_dir Directory to write the combined HTML file. Defaults to project_path.
#' @param output_filename Optional explicit filename. If NULL, auto-generated.
#'
#' @return TRS-compliant list with status, result (output_path), message.
#'
#' @export
generate_hub_from_project <- function(project_path,
                                       project_name = NULL,
                                       output_dir = NULL,
                                       output_filename = NULL) {

  `%||%` <- function(a, b) if (is.null(a)) b else a
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())

  # --- Guard: project_path ---
  if (is.null(project_path) || !nzchar(trimws(project_path))) {
    cat("\n┌─── TURAS HUB APP ERROR ───────────────────────────────┐\n")
    cat("│ Code: IO_PROJECT_PATH_EMPTY\n")
    cat("│ Message: Project path is empty or NULL\n")
    cat("│ Fix: Provide a valid project directory path\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(list(
      status = "REFUSED",
      code = "IO_PROJECT_PATH_EMPTY",
      message = "Project path is empty or NULL",
      how_to_fix = "Provide a valid project directory path"
    ))
  }

  if (!dir.exists(project_path)) {
    cat("\n┌─── TURAS HUB APP ERROR ───────────────────────────────┐\n")
    cat("│ Code: IO_PROJECT_NOT_FOUND\n")
    cat("│ Message: Project directory does not exist:", project_path, "\n")
    cat("│ Fix: Check the project path\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(list(
      status = "REFUSED",
      code = "IO_PROJECT_NOT_FOUND",
      message = sprintf("Project directory does not exist: %s", project_path),
      how_to_fix = "Check the project path and ensure the directory exists"
    ))
  }

  # --- Guard: openxlsx ---
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    cat("\n┌─── TURAS HUB APP ERROR ───────────────────────────────┐\n")
    cat("│ Code: PKG_MISSING_DEPENDENCY\n")
    cat("│ Missing: openxlsx\n")
    cat("│ Fix: install.packages('openxlsx')\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(list(
      status = "REFUSED",
      code = "PKG_MISSING_DEPENDENCY",
      message = "The 'openxlsx' package is required to generate hub config files",
      how_to_fix = "Install with: install.packages('openxlsx')"
    ))
  }

  # --- Discover reports ---
  source(file.path(turas_root, "modules", "hub_app", "lib", "project_scanner.R"),
         local = TRUE)

  report_result <- get_project_reports(project_path)
  if (report_result$status == "REFUSED") {
    return(report_result)
  }

  reports <- report_result$result$reports
  if (length(reports) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_NO_REPORTS",
      message = "No Turas HTML reports found in the project directory",
      how_to_fix = sprintf("Ensure %s contains Turas HTML reports", project_path)
    ))
  }

  project_name <- project_name %||% report_result$result$project_name
  output_dir <- output_dir %||% project_path

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  cat("[Hub App] Generating combined hub for:", project_name, "\n")
  cat("[Hub App] Found", length(reports), "report(s)\n")

  # --- Build config Excel ---
  tryCatch({
    config_path <- file.path(output_dir,
      paste0(gsub("[^a-zA-Z0-9_ -]", "", project_name),
             "_Auto_Hub_Config.xlsx"))

    wb <- openxlsx::createWorkbook()

    # Settings sheet
    openxlsx::addWorksheet(wb, "Settings")
    settings_data <- data.frame(
      Setting = c("project_title", "subtitle", "company_name",
                   "primary_colour", "output_dir"),
      Value = c(project_name, paste("Combined Report -", format(Sys.Date(), "%B %Y")),
                "", "#2563EB", output_dir),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Settings", settings_data)

    # Reports sheet
    openxlsx::addWorksheet(wb, "Reports")
    reports_data <- data.frame(
      key = vapply(reports, function(r) {
        tools::file_path_sans_ext(r$filename)
      }, character(1)),
      label = vapply(reports, function(r) r$label %||% r$filename, character(1)),
      path = vapply(reports, function(r) r$path, character(1)),
      type = vapply(reports, function(r) r$type %||% "", character(1)),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Reports", reports_data)

    openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
    cat("[Hub App] Config written:", config_path, "\n")

    # --- Source and call combine_reports ---
    cat("[Hub App] Running combine_reports()...\n")

    # Source report_hub module
    source(file.path(turas_root, "modules", "report_hub", "00_main.R"),
           local = TRUE)

    # Determine output file path
    if (!is.null(output_filename)) {
      out_path <- file.path(output_dir, output_filename)
    } else {
      out_path <- NULL  # Let combine_reports auto-generate
    }

    result <- combine_reports(
      config_file = config_path,
      output_file = out_path
    )

    # Clean up auto-generated config (it was just a means to an end)
    if (file.exists(config_path)) {
      unlink(config_path)
      cat("[Hub App] Cleaned up auto-generated config\n")
    }

    if (result$status %in% c("PASS", "PARTIAL")) {
      cat("[Hub App] Combined hub generated:", result$result$output_path, "\n")
      return(list(
        status = result$status,
        result = list(
          output_path = result$result$output_path,
          file_size = result$result$file_size,
          n_reports = result$result$n_reports
        ),
        warnings = result$warnings %||% character(0),
        message = sprintf("Generated combined hub with %d reports: %s",
                           result$result$n_reports,
                           basename(result$result$output_path))
      ))
    } else {
      return(result)
    }

  }, error = function(e) {
    cat("\n┌─── TURAS HUB APP ERROR ───────────────────────────────┐\n")
    cat("│ Code: CALC_HUB_GENERATION_FAILED\n")
    cat("│ Message:", e$message, "\n")
    cat("│ Fix: Check the R console for details\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(list(
      status = "REFUSED",
      code = "CALC_HUB_GENERATION_FAILED",
      message = paste("Hub generation failed:", e$message),
      how_to_fix = "Check the R console for detailed error output"
    ))
  })
}
