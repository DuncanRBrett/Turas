# ==============================================================================
# MODULE 13: EXCEL_WRITER.R
# ==============================================================================
#
# PURPOSE:
#   Write crosstab results to Excel workbook with proper formatting
#   Main orchestration module that coordinates sub-modules
#
# FUNCTIONS:
#   - write_crosstab_workbook() - Main writer (orchestration)
#   - get_excel_writer_info() - Module metadata
#
# SUB-MODULES:
#   - excel_styles.R - Style definitions and helpers
#   - excel_headers.R - Banner headers and column letters
#   - excel_tables.R - Question table and base row writing
#   - excel_sheets.R - Additional sheets (summary, error log, composition, index)
#
# DEPENDENCIES:
#   - openxlsx (Excel creation)
#   - /modules/shared/lib/ (formatting, validation, config utilities)
#
# VERSION: 1.3.0 - Refactored into focused sub-modules for maintainability
# DATE: 2025-12-27
# CHANGES: Extracted functionality into excel_styles, excel_headers,
#          excel_tables, and excel_sheets for better organization
# ==============================================================================

# Require openxlsx
if (!requireNamespace("openxlsx", quietly = TRUE)) {
  tabs_refuse(
    code = "PKG_MISSING_DEPENDENCY",
    title = "Missing Required Package: openxlsx",
    problem = "The 'openxlsx' package is not installed. This package is required for Excel output.",
    why_it_matters = "Cannot write crosstab results to Excel format without openxlsx. The excel_writer module cannot function.",
    how_to_fix = c(
      "Install the package: install.packages('openxlsx')",
      "Then reload the Tabs module"
    )
  )
}

# ==============================================================================
# LOAD SHARED UTILITIES
# ==============================================================================

# Load shared utilities from consolidated location
# Only load if not already available (avoid re-sourcing)
if (!exists("find_turas_root", mode = "function")) {
  # Find Turas root by looking for marker files
  .find_root <- function() {
    current_dir <- getwd()
    while (current_dir != dirname(current_dir)) {
      has_launch <- file.exists(file.path(current_dir, "launch_turas.R"))
      has_modules <- dir.exists(file.path(current_dir, "modules"))
      if (has_launch || has_modules) {
        return(current_dir)
      }
      current_dir <- dirname(current_dir)
    }
    tabs_refuse(
      code = "ENV_TURAS_ROOT_NOT_FOUND",
      title = "Cannot Locate Turas Root Directory",
      problem = "Could not find Turas root directory by searching for launch_turas.R or modules/ directory.",
      why_it_matters = "Cannot load shared utilities without locating the Turas root. The excel_writer module cannot initialize.",
      how_to_fix = c(
        "Ensure you are running from within a Turas project directory structure",
        "Verify that launch_turas.R exists in the Turas root",
        "Check that the modules/ directory exists",
        "Run from the correct working directory"
      )
    )
  }

  .turas_root <- .find_root()
  .shared_lib_path <- file.path(.turas_root, "modules", "shared", "lib")

  source(file.path(.shared_lib_path, "validation_utils.R"), local = FALSE)
  source(file.path(.shared_lib_path, "config_utils.R"), local = FALSE)
  source(file.path(.shared_lib_path, "formatting_utils.R"), local = FALSE)

  rm(.turas_root, .shared_lib_path, .find_root)
}

# ==============================================================================
# LOAD SUB-MODULES
# ==============================================================================

# Find the lib directory where this file is located
# Use script_dir which should be set by run_crosstabs.R
.excel_lib_path <- if (exists("script_dir") && !is.null(script_dir) && length(script_dir) > 0 && nzchar(script_dir[1])) {
  script_dir[1]
} else if (exists(".turas_root")) {
  file.path(.turas_root, "modules", "tabs", "lib")
} else {
  # Last resort: assume we're already in lib
  getwd()
}

# Source sub-modules
source(file.path(.excel_lib_path, "excel_styles.R"), local = FALSE)
source(file.path(.excel_lib_path, "excel_headers.R"), local = FALSE)
source(file.path(.excel_lib_path, "excel_tables.R"), local = FALSE)
source(file.path(.excel_lib_path, "excel_sheets.R"), local = FALSE)

rm(.excel_lib_path)

# ==============================================================================
# MAIN EXCEL WRITER
# ==============================================================================

#' Write Crosstab Workbook
#'
#' Creates complete Excel workbook with crosstab results.
#' Main orchestration function that coordinates sub-modules.
#'
#' @param output_file Character, output file path
#' @param all_results List, all question results
#' @param banner_info List, banner structure
#' @param config List, configuration
#' @param project_info List, project metadata
#' @return TRUE if successful
#' @export
write_crosstab_workbook <- function(output_file, all_results, banner_info,
                                   config, project_info = NULL) {

  log_message("Creating Excel workbook...", level = "INFO", verbose = config$verbose)

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Create styles (from excel_styles.R)
  styles <- create_excel_styles(
    decimal_separator = config$decimal_separator,
    decimal_places_percent = config$decimal_places_percent,
    decimal_places_ratings = config$decimal_places_ratings,
    decimal_places_index = config$decimal_places_index,
    decimal_places_numeric = config$decimal_places_numeric
  )

  # Add main results sheet
  sheet_name <- "Crosstabs"
  openxlsx::addWorksheet(wb, sheet_name)

  # Write banner headers (from excel_headers.R)
  current_row <- write_banner_headers(wb, sheet_name, banner_info, styles)

  # Write each question (from excel_tables.R)
  for (i in seq_along(all_results)) {
    result <- all_results[[i]]

    if (!is.null(result$table) && nrow(result$table) > 0) {
      current_row <- write_question_table(
        wb, sheet_name, result, banner_info, styles, current_row, config
      )
      current_row <- current_row + 2  # Add spacing
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 40)
  openxlsx::setColWidths(wb, sheet_name, cols = 2, widths = 10)
  openxlsx::setColWidths(wb, sheet_name,
                        cols = 3:(3 + length(banner_info$internal_keys) - 1),
                        widths = 12)

  # Save workbook
  safe_execute(
    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE),
    default = FALSE,
    error_msg = sprintf("Failed to save Excel file: %s", output_file)
  )

  log_message(
    sprintf("Excel file created: %s", output_file),
    level = "INFO",
    verbose = config$verbose
  )

  return(TRUE)
}

# ==============================================================================
# MODULE INFO
# ==============================================================================

#' Get Excel Writer Module Information
#'
#' Returns metadata about the excel_writer module.
#'
#' @return List with module information
#' @export
get_excel_writer_info <- function() {
  list(
    module = "excel_writer",
    version = "1.3.0",
    date = "2025-12-27",
    description = "Excel workbook writer for crosstab results (refactored into sub-modules)",
    main_functions = c(
      "write_crosstab_workbook",
      "get_excel_writer_info"
    ),
    submodules = list(
      excel_styles = c(
        "create_excel_styles",
        "get_row_style"
      ),
      excel_headers = c(
        "write_banner_headers",
        "write_column_letters"
      ),
      excel_tables = c(
        "write_question_table",
        "write_base_rows"
      ),
      excel_sheets = c(
        "create_summary_sheet",
        "add_question_list",
        "write_error_log_sheet",
        "create_sample_composition_sheet",
        "write_index_summary_sheet"
      )
    ),
    dependencies = c(
      "openxlsx",
      "modules/shared/lib/validation_utils.R",
      "modules/shared/lib/config_utils.R",
      "modules/shared/lib/formatting_utils.R"
    )
  )
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs excel_writer module loaded (refactored)")

# ==============================================================================
# END OF MODULE 13: EXCEL_WRITER.R
# ==============================================================================
