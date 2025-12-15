# ==============================================================================
# Turas Project R Profile
# ==============================================================================
# This file is automatically sourced when R starts in the Turas directory.
# It activates renv for reproducible package management.
#
# IMPORTANT: After cloning Turas, run: renv::restore()
# ==============================================================================

# Activate renv for package management (unless TURAS_SKIP_RENV is set for GUI modules)
# GUIs don't need renv - skipping it speeds up launch time from 15s to 2-3s
if (Sys.getenv("TURAS_SKIP_RENV") != "1") {
  source("renv/activate.R")
}

# Optional: Set default CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Optional: Turas-specific startup message
if (interactive()) {
  message("\n")
  message("=======================================================")
  message("  TURAS Analytics Platform")
  message("=======================================================")
  message("  renv is active - packages are managed per-project")
  message("")
  message("  Quick commands:")
  message("    renv::status()    - Check package sync status")
  message("    renv::restore()   - Install packages from lockfile")
  message("    renv::snapshot()  - Update lockfile after changes")
  message("=======================================================")
  message("\n")
}
