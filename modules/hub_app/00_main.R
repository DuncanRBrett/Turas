# ==============================================================================
# TURAS > HUB APP — MAIN ENTRY POINT
# ==============================================================================
# Purpose: Launch the Hub App working environment for browsing, pinning,
#          and exporting across multiple Turas HTML reports.
# Location: modules/hub_app/00_main.R
# Usage:
#   source("modules/hub_app/00_main.R")
#   launch_hub_app()
# ==============================================================================

#' Launch Turas Hub App
#'
#' Starts the Hub App Shiny application. This is the main entry point
#' called by the Turas launcher or directly from R console.
#'
#' @param project_dirs Character vector of root directories to scan for
#'   Turas projects. Defaults to Home/Documents and Home/Desktop.
#' @param port Integer port number. Default: auto-select available port.
#' @param open_browser Logical. Open browser on launch? Default: TRUE.
#'
#' @return Shiny app object (invisibly, when run interactively)
#'
#' @examples
#' \dontrun{
#'   launch_hub_app()
#'   launch_hub_app(project_dirs = c("~/Projects", "~/OneDrive/Reports"))
#' }
#'
#' @export
launch_hub_app <- function(project_dirs = NULL,
                           port = NULL,
                           open_browser = TRUE) {

  turas_root <- Sys.getenv("TURAS_ROOT", getwd())

  # Source guard layer
  source(file.path(turas_root, "modules", "hub_app", "00_guard.R"),
         local = TRUE)

  # Validate directories
  guard_result <- guard_hub_app(project_dirs)
  if (guard_result$status == "REFUSED") {
    return(guard_result)
  }

  validated_dirs <- guard_result$result$project_dirs

  # Source the GUI
  source(file.path(turas_root, "modules", "hub_app", "run_hub_app_gui.R"),
         local = TRUE)

  cat("\n[Hub App] Starting with", length(validated_dirs), "root director(ies):\n")
  for (d in validated_dirs) cat("  -", d, "\n")
  cat("\n")

  # Build and return the Shiny app
  run_hub_app_gui(project_dirs = validated_dirs)
}
