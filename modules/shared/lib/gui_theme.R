# ==============================================================================
# TURAS GUI Theme Helper
# ==============================================================================
# Provides shared header and CSS for all module GUIs.
# Usage:
#   source(file.path(turas_root, "modules/shared/lib/gui_theme.R"))
#   theme <- turas_gui_theme("Tabs", "Cross-tabulation & Statistical Testing")
#   # In UI: theme$head, theme$header
# ==============================================================================

#' Build Turas GUI theme elements
#'
#' Returns a list with $head (tags$head for CSS) and $header (header div).
#'
#' @param module_name Display name for the header (e.g., "Tabs", "Tracker")
#' @param module_subtitle One-line description shown below title
#' @return list with $head and $header
turas_gui_theme <- function(module_name, module_subtitle = NULL) {
  # Locate CSS file
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  css_path <- file.path(turas_root, "modules", "shared", "turas_gui_theme.css")

  # Read CSS as inline style (works across Rscript child launches)
  css_text <- if (file.exists(css_path)) {
    paste(readLines(css_path, warn = FALSE), collapse = "\n")
  } else {
    ""
  }

  # Build header HTML
  header <- shiny::tags$div(class = "turas-header",
    shiny::tags$div(class = "turas-header-inner",
      shiny::tags$div(
        shiny::tags$span(class = "turas-header-title",
          paste0("TURAS > ", toupper(module_name))),
        if (!is.null(module_subtitle)) {
          shiny::tags$div(class = "turas-header-subtitle", module_subtitle)
        }
      ),
      shiny::tags$span(class = "turas-header-meta", "Part of Turas Analytics Toolkit")
    )
  )

  list(
    head = shiny::tags$head(shiny::tags$style(shiny::HTML(css_text))),
    header = header
  )
}


# Maximum number of recent projects to retain per module.
# Single source of truth — change here to affect all modules and the launcher.
TURAS_MAX_RECENTS <- 10L


#' Resolve a Turas path against the projects root
#'
#' Relative paths (no leading / or drive letter) are resolved against
#' TURAS_PROJECTS_ROOT. Absolute paths pass through unchanged. This allows
#' config files to store short portable paths such as "ClientA/data.xlsx"
#' that work on any machine where TURAS_PROJECTS_ROOT is configured.
#'
#' @param path Character. A file or directory path from a config file.
#' @return Character. Normalised absolute path, or the original string if the
#'   root is not set and the path is already relative.
#'
#' @examples
#' \dontrun{
#'   Sys.setenv(TURAS_PROJECTS_ROOT = "/data")
#'   resolve_turas_path("ClientA/Wave1/data.xlsx")
#'   # => "/data/ClientA/Wave1/data.xlsx"
#'   resolve_turas_path("/data/other.xlsx")
#'   # => "/data/other.xlsx"  (absolute, passes through)
#' }
resolve_turas_path <- function(path) {
  if (!nzchar(path)) return(path)
  # Absolute paths (Unix / or Windows drive letter) pass through unchanged
  if (grepl("^/|^[A-Za-z]:", path)) {
    return(normalizePath(path, winslash = "/", mustWork = FALSE))
  }
  root <- Sys.getenv("TURAS_PROJECTS_ROOT", "")
  if (!nzchar(root)) return(path)
  normalizePath(file.path(root, path), winslash = "/", mustWork = FALSE)
}


#' Get the persistent directory for storing module recent-project files
#'
#' Prefers TURAS_PROJECTS_ROOT/.turas/ so that recent project history
#' survives Docker container restarts and syncs between machines via
#' Google Drive. Falls back to TURAS_ROOT when the projects root is not
#' configured (desktop use without the Google Drive setup).
#'
#' @return Character. Path to a writable directory that exists on disk.
turas_recents_dir <- function() {
  root <- Sys.getenv("TURAS_PROJECTS_ROOT", "")
  if (nzchar(root) && dir.exists(root)) {
    meta_dir <- file.path(root, ".turas")
    if (!dir.exists(meta_dir)) {
      tryCatch(
        dir.create(meta_dir, showWarnings = FALSE),
        error = function(e) NULL
      )
    }
    if (dir.exists(meta_dir)) return(meta_dir)
  }
  # Fallback: Turas root (fine on desktop; won't persist across Docker restarts)
  Sys.getenv("TURAS_ROOT", getwd())
}


#' Get the path to a module's recent-projects RDS file
#'
#' @param module_key Character. Short identifier for the module,
#'   e.g. "tabs", "tracker", "keydriver".
#' @return Character. Full path to the .rds file.
turas_recent_file <- function(module_key) {
  file.path(turas_recents_dir(), paste0(".recent_", module_key, ".rds"))
}


#' Load recent projects for a module (character-vector format)
#'
#' Used by modules that store a plain vector of paths (tabs, confidence,
#' segment, weighting, report_hub, alchemerparser). Modules that store
#' named lists (tracker, conjoint, etc.) manage their own serialisation
#' and use turas_recent_file() directly.
#'
#' @param module_key Character. Short identifier for the module.
#' @return Character vector of recent paths. Empty on missing or corrupt file.
turas_load_recents <- function(module_key) {
  path <- turas_recent_file(module_key)
  if (!file.exists(path)) return(character(0))
  tryCatch(
    {
      data <- readRDS(path)
      if (is.character(data)) data else character(0)
    },
    error = function(e) character(0)
  )
}


#' Save recent projects for a module (character-vector format)
#'
#' @param module_key Character. Short identifier for the module.
#' @param recents Character vector of recent paths.
turas_save_recents <- function(module_key, recents) {
  path <- turas_recent_file(module_key)
  tryCatch(saveRDS(recents, path), error = function(e) NULL)
}


#' Add a project path to a module's recent list
#'
#' Inserts path at the front, deduplicates, and trims to TURAS_MAX_RECENTS.
#' For modules that store named lists rather than plain paths, call
#' turas_recent_file() directly and manage serialisation in the module.
#'
#' @param module_key Character. Short identifier for the module.
#' @param project_path Character. Path to prepend to the recent list.
turas_add_recent <- function(module_key, project_path) {
  recents <- turas_load_recents(module_key)
  recents <- unique(c(project_path, recents))
  recents <- recents[seq_len(min(TURAS_MAX_RECENTS, length(recents)))]
  turas_save_recents(module_key, recents)
}


#' Get file browser volumes for Shiny directory chooser
#'
#' When TURAS_PROJECTS_ROOT is set and the directory exists, returns only
#' that root (labelled "Projects") so the file browser opens directly
#' inside the shared projects folder and config paths stay short and
#' portable. Falls back to context-appropriate defaults otherwise.
#'
#' In Docker without TURAS_PROJECTS_ROOT: returns /data and /app.
#' On desktop without TURAS_PROJECTS_ROOT: returns Home/Documents/Desktop.
#'
#' @return Named character vector of root directories for shinyDirChoose /
#'   shinyFileChoose.
turas_gui_volumes <- function() {
  projects_root <- Sys.getenv("TURAS_PROJECTS_ROOT", "")

  in_docker <- nzchar(Sys.getenv("TURAS_DOCKER", "")) ||
    file.exists("/.dockerenv")

  if (in_docker) {
    # In Docker the projects root IS the only meaningful location.
    # Other host paths are not accessible inside the container.
    if (nzchar(projects_root) && dir.exists(projects_root)) {
      return(c(Projects = projects_root))
    }
    vols <- c(Data = "/data", App = "/app")
    vols <- vols[dir.exists(vols)]
    if (length(vols) == 0) vols <- c(Root = "/")
    return(vols)
  }

  # Desktop: put Projects first (opens there by default) but keep all other
  # roots so legacy OneDrive projects remain accessible during transition.
  home <- Sys.getenv("HOME", path.expand("~"))
  vols <- c(
    Home      = home,
    Documents = file.path(home, "Documents"),
    Desktop   = file.path(home, "Desktop")
  )
  vols <- vols[dir.exists(vols)]

  if (nzchar(projects_root) && dir.exists(projects_root)) {
    # Prepend Projects so the browser opens there, but Home/etc. remain
    vols <- c(c(Projects = projects_root), vols)
  }

  vols
}


#' Check if module was launched from the Turas hub
#'
#' Returns TRUE when TURAS_LAUNCHED_FROM_HUB env var is set.
#' Modules should use this to hide their recent projects section
#' since the launcher already provides that functionality.
#'
#' @return logical
turas_hide_recents <- function() {
  val <- Sys.getenv("TURAS_LAUNCHED_FROM_HUB", "")
  if (nzchar(val)) {
    Sys.unsetenv("TURAS_LAUNCHED_FROM_HUB")
    return(TRUE)
  }
  FALSE
}
