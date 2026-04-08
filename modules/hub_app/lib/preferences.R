# ==============================================================================
# TURAS > HUB APP — Preferences Manager
# ==============================================================================
# Purpose: Read/write Hub App preferences from ~/.turas/hub_app_config.json
# Location: modules/hub_app/lib/preferences.R
# ==============================================================================

#' Get Hub App Preferences
#'
#' Reads preferences from ~/.turas/hub_app_config.json. Returns defaults if
#' the file doesn't exist. Creates the directory if needed.
#'
#' @return List of preference values
#' @export
get_hub_preferences <- function() {
  config_path <- get_preferences_path()
  defaults <- default_preferences()

  if (!file.exists(config_path)) {
    return(defaults)
  }

  tryCatch({
    saved <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
    # Merge saved over defaults (so new defaults are always present)
    merged <- defaults
    for (key in names(saved)) {
      if (key %in% names(defaults)) {
        merged[[key]] <- saved[[key]]
      }
    }
    merged
  }, error = function(e) {
    cat("[Hub App] WARNING: Could not read preferences:", e$message, "\n")
    defaults
  })
}


#' Save Hub App Preferences
#'
#' Writes preferences to ~/.turas/hub_app_config.json.
#'
#' @param prefs List of preference key-value pairs
#' @return TRS-compliant list with status
#' @export
save_hub_preferences <- function(prefs) {
  config_path <- get_preferences_path()
  config_dir <- dirname(config_path)

  # Ensure directory exists
  if (!dir.exists(config_dir)) {
    dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Validate and merge with defaults
  defaults <- default_preferences()
  merged <- defaults
  for (key in names(prefs)) {
    if (key %in% names(defaults)) {
      merged[[key]] <- prefs[[key]]
    }
  }

  tryCatch({
    jsonlite::write_json(merged, config_path,
                          auto_unbox = TRUE, pretty = TRUE)
    cat("[Hub App] Preferences saved to:", config_path, "\n")
    list(
      status = "PASS",
      result = list(path = config_path),
      message = "Preferences saved successfully"
    )
  }, error = function(e) {
    cat("\n┌─── TURAS HUB APP ERROR ───────────────────────────────┐\n")
    cat("│ Code: IO_PREFERENCES_WRITE_FAILED\n")
    cat("│ Message:", e$message, "\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    list(
      status = "REFUSED",
      code = "IO_PREFERENCES_WRITE_FAILED",
      message = paste("Failed to save preferences:", e$message),
      how_to_fix = sprintf("Check write permissions for %s", config_dir)
    )
  })
}


#' Get the Preferences File Path
#'
#' @return Character path to ~/.turas/hub_app_config.json
#' @keywords internal
get_preferences_path <- function() {
  home <- Sys.getenv("HOME", path.expand("~"))
  file.path(home, ".turas", "hub_app_config.json")
}


#' Default Preferences
#'
#' @return List of default preference values
#' @keywords internal
default_preferences <- function() {
  list(
    scan_directories = list(),
    exclude_directories = list(),
    recent_views = list(),         # up to 5: {label, include_dirs, exclude_dirs, timestamp}
    brand_colour = "#2563EB",
    accent_colour = "#10B981",
    logo_path = "",
    auto_save_interval = 500,
    theme = "light",
    scan_max_depth = 6
  )
}


#' Detect Cloud Storage Directories
#'
#' Finds OneDrive, Google Drive, and Dropbox directories on the system.
#' Used by the preferences UI to suggest additional scan directories.
#'
#' @return Character vector of detected cloud storage paths
#' @export
detect_cloud_storage <- function() {
  cloud_dirs <- character(0)
  home <- Sys.getenv("HOME", path.expand("~"))

  # macOS: ~/Library/CloudStorage/ contains OneDrive, Google Drive, Dropbox

  cloud_parent <- file.path(home, "Library", "CloudStorage")
  if (dir.exists(cloud_parent)) {
    subdirs <- list.dirs(cloud_parent, recursive = FALSE, full.names = TRUE)
    cloud_dirs <- c(cloud_dirs, subdirs)
  }

  # Windows: OneDrive environment variable
  onedrive <- Sys.getenv("OneDrive", "")
  if (nzchar(onedrive) && dir.exists(onedrive)) {
    cloud_dirs <- c(cloud_dirs, onedrive)
  }

  # Windows: common OneDrive paths
  if (.Platform$OS.type == "windows") {
    userprofile <- Sys.getenv("USERPROFILE", "")
    if (nzchar(userprofile)) {
      od_personal <- file.path(userprofile, "OneDrive")
      od_business <- file.path(userprofile, "OneDrive - *")
      if (dir.exists(od_personal)) cloud_dirs <- c(cloud_dirs, od_personal)
      # Glob for business OneDrive
      od_matches <- Sys.glob(file.path(userprofile, "OneDrive - *"))
      cloud_dirs <- c(cloud_dirs, od_matches[dir.exists(od_matches)])
    }
  }

  unique(cloud_dirs)
}
