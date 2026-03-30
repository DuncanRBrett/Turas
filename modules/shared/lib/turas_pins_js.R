# ==============================================================================
# TurasPins Shared Pin Library — JavaScript Loader
# ==============================================================================
#
# Reads and concatenates the shared TurasPins JavaScript files from
# modules/shared/js/. Called by each module's page builder to embed
# the shared library before the module's own pin wrapper JS.
#
# Usage:
#   js_code <- turas_pins_js()
#   # Embed in <script> block before module-specific pin JS
# ==============================================================================

#' Load TurasPins Shared JavaScript Library
#'
#' Reads all TurasPins JS files from modules/shared/js/ in the correct
#' dependency order and returns them as a single concatenated string
#' for embedding in HTML reports.
#'
#' @return Character string containing all shared pin JS code.
#'   Returns empty string with console warning if files not found.
#'
#' @examples
#' \dontrun{
#'   shared_js <- turas_pins_js()
#'   html <- sprintf("<script>%s</script>", shared_js)
#' }
turas_pins_js <- function() {
  # Resolve shared JS directory via TURAS_ROOT or relative path
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()

  js_dir <- file.path(turas_root, "modules", "shared", "js")
  if (!dir.exists(js_dir)) {
    js_dir <- file.path("modules", "shared", "js")
  }

  if (!dir.exists(js_dir)) {
    cat("\n=== TURAS WARNING ===\n")
    cat("TurasPins shared JS directory not found.\n")
    cat("Searched:", js_dir, "\n")
    cat("Pin functionality will not be available.\n")
    cat("=====================\n\n")
    return("")
  }

  # Files in dependency order — utils first, then core, then features
  js_files <- c(
    "turas_pins_utils.js",
    "turas_pins.js",
    "turas_pins_render.js",
    "turas_pins_drag.js",
    "turas_pins_insight_svg.js",
    "turas_pins_table.js",
    "turas_pins_export.js"
  )

  parts <- character(0)
  for (jf in js_files) {
    jpath <- file.path(js_dir, jf)
    if (file.exists(jpath)) {
      parts <- c(parts, paste(readLines(jpath, warn = FALSE), collapse = "\n"))
    }
  }

  paste(parts, collapse = "\n\n")
}
