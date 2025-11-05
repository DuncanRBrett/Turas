# ==============================================================================
# TURAS>PARSER - Main Entry Point
# ==============================================================================
# Purpose: Parse Word questionnaires and generate Survey_Structure.xlsx
# Version: 1.0.0 - Modular Turas Implementation
# ==============================================================================

#' Launch Questionnaire Parser
#' 
#' @description
#' Interactive Shiny application that parses Word document questionnaires
#' and generates Survey_Structure.xlsx files for use in Turas>Tabs.
#' 
#' @param port Integer. Port number for Shiny app (default: NULL = auto)
#' @param launch_browser Logical. Open browser automatically? (default: TRUE)
#' 
#' @examples
#' \dontrun{
#' # Launch the parser
#' run_parser()
#' 
#' # Launch on specific port
#' run_parser(port = 3838)
#' }
#' 
#' @export
run_parser <- function(port = NULL, launch_browser = TRUE) {
  
  # Check dependencies
  required_pkgs <- c("shiny", "officer", "openxlsx", "stringr", "DT")
  missing_pkgs <- required_pkgs[!required_pkgs %in% installed.packages()[,"Package"]]
  
  if (length(missing_pkgs) > 0) {
    message("Installing required packages: ", paste(missing_pkgs, collapse = ", "))
    install.packages(missing_pkgs)
  }
  
  # Load Turas core (if available)
  if (file.exists("core/constants.R")) {
    source("core/constants.R")
    if (file.exists("core/logging.R")) {
      source("core/logging.R")
      if (exists("log_info")) {
        log_info("Starting Turas>Parser")
      }
    }
  }
  
  message("Starting Turas>Parser...")
  
  # Load parser modules
  parser_dir <- file.path("modules", "parser")
  lib_dir <- file.path(parser_dir, "lib")
  
  source(file.path(lib_dir, "docx_reader.R"))
  source(file.path(lib_dir, "pattern_parser.R"))
  source(file.path(lib_dir, "structure_parser.R"))
  source(file.path(lib_dir, "type_detector.R"))
  source(file.path(lib_dir, "text_cleaner.R"))
  source(file.path(lib_dir, "bin_detector.R"))
  source(file.path(lib_dir, "output_generator.R"))
  source(file.path(lib_dir, "parse_orchestrator.R"))
  
  # Load Shiny app
  source(file.path(parser_dir, "shiny_app.R"))
  
  # Launch app
  shiny::shinyApp(
    ui = parser_ui(),
    server = parser_server,
    options = list(
      port = port,
      launch.browser = launch_browser
    )
  )
}

# Allow direct execution
if (!interactive()) {
  run_parser()
}
