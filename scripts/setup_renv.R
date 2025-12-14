#!/usr/bin/env Rscript
# ==============================================================================
# Turas renv Setup Script
# ==============================================================================
# Run this script ONCE after setting up renv to create the initial lockfile.
#
# Usage:
#   Rscript scripts/setup_renv.R
#
# Or in R console:
#   source("scripts/setup_renv.R")
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("TURAS - renv Setup\n")
cat("================================================================================\n\n")

# Check if we're in Turas root
if (!file.exists("launch_turas.R") && !dir.exists("modules/shared")) {
  stop("Please run this script from the Turas root directory")
}

# Install renv if not available
if (!requireNamespace("renv", quietly = TRUE)) {
  cat("Installing renv package...\n")
  install.packages("renv", repos = "https://cloud.r-project.org")
}

library(renv)

# Check if renv.lock already exists
if (file.exists("renv.lock")) {
  cat("renv.lock already exists.\n")
  cat("\nOptions:\n")
  cat("  1. Run renv::restore() to install packages from lockfile\n")
  cat("  2. Run renv::snapshot() to update lockfile with current packages\n")
  cat("  3. Delete renv.lock and re-run this script to start fresh\n\n")
} else {
  cat("Creating initial renv.lock...\n\n")

  # Detect currently installed packages used by Turas
  cat("Scanning project for dependencies...\n")

  # Provide consent for renv to modify project files
  # (This bypasses the interactive prompt)
  renv::consent(provided = TRUE)

  # Initialize renv (creates renv.lock)
  renv::init(
    project = getwd(),
    bare = FALSE,        # Install discovered dependencies
    restart = FALSE      # Don't restart R
  )

  cat("\n")
  cat("================================================================================\n")
  cat("Setup Complete!\n")
  cat("================================================================================\n")
  cat("\n")
  cat("renv.lock has been created with your current package versions.\n")
  cat("\n")
  cat("Next steps:\n")
  cat("  1. Review renv.lock to ensure all dependencies are captured\n")
  cat("  2. Commit the lockfile: git add renv.lock && git commit -m 'Add renv.lock'\n")
  cat("  3. Share with team - they run: renv::restore()\n")
  cat("\n")
}

# Show status
cat("Current renv status:\n")
cat("--------------------\n")
renv::status()

cat("\n")
