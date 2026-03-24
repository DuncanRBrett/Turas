#!/usr/bin/env Rscript
# ==============================================================================
# TURAS SAFE PACKAGE UPDATE SCRIPT
# ==============================================================================
#
# Updates R packages safely with automatic rollback on test failure.
#
# Usage:
#   Rscript tools/safe_package_update.R <package_name>   # Update one package
#   Rscript tools/safe_package_update.R --all             # Update all packages
#   Rscript tools/safe_package_update.R --check           # Check for updates only
#
# What it does:
#   1. Backs up current renv.lock
#   2. Updates the package(s)
#   3. Runs the full test suite
#   4. If tests pass: snapshots the new state
#   5. If tests fail: rolls back to the backup
#
# ==============================================================================

cat("
================================================================================
TURAS SAFE PACKAGE UPDATE
================================================================================
\n")

# --- Parse arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  cat("Usage:\n")
  cat("  Rscript tools/safe_package_update.R <package_name>   Update one package\n")
  cat("  Rscript tools/safe_package_update.R --all             Update all packages\n")
  cat("  Rscript tools/safe_package_update.R --check           Check for available updates\n")
  cat("\nExamples:\n")
  cat("  Rscript tools/safe_package_update.R domir\n")
  cat("  Rscript tools/safe_package_update.R ggplot2 dplyr     Update multiple packages\n")
  quit(status = 0)
}

# --- Ensure we're in the project root ----------------------------------------
turas_root <- getwd()
if (!file.exists(file.path(turas_root, "launch_turas.R"))) {
  # Try to find it
  candidate <- Sys.getenv("TURAS_ROOT", unset = "")
  if (nzchar(candidate) && file.exists(file.path(candidate, "launch_turas.R"))) {
    turas_root <- candidate
    setwd(turas_root)
  } else {
    stop("Must be run from Turas project root (where launch_turas.R is)")
  }
}

lock_file <- file.path(turas_root, "renv.lock")
backup_file <- file.path(turas_root, "renv.lock.backup")

# --- Check-only mode ---------------------------------------------------------
if ("--check" %in% args) {
  cat("Checking for available package updates...\n\n")
  tryCatch({
    status <- renv::status()
    cat("\nUse 'Rscript tools/safe_package_update.R <package>' to update safely.\n")
  }, error = function(e) {
    cat("Error checking status:", e$message, "\n")
  })
  quit(status = 0)
}

# --- Determine packages to update --------------------------------------------
update_all <- "--all" %in% args
packages <- args[!grepl("^--", args)]

if (!update_all && length(packages) == 0) {
  stop("No packages specified. Use --all or provide package names.")
}

# --- Step 1: Record current versions -----------------------------------------
cat("Step 1: Recording current package versions...\n")

if (update_all) {
  cat("  Mode: Update ALL packages\n")
} else {
  cat(sprintf("  Packages to update: %s\n", paste(packages, collapse = ", ")))

  # Show current versions
  for (pkg in packages) {
    ver <- tryCatch(
      as.character(packageVersion(pkg)),
      error = function(e) "NOT INSTALLED"
    )
    cat(sprintf("  - %s: current version = %s\n", pkg, ver))
  }
}

# --- Step 2: Backup renv.lock ------------------------------------------------
cat("\nStep 2: Backing up renv.lock...\n")
if (file.exists(lock_file)) {
  file.copy(lock_file, backup_file, overwrite = TRUE)
  cat(sprintf("  Backup saved to: %s\n", backup_file))
} else {
  cat("  WARNING: No renv.lock found. Will create one after update.\n")
}

# --- Step 3: Update packages -------------------------------------------------
cat("\nStep 3: Updating packages...\n")
update_success <- tryCatch({
  if (update_all) {
    renv::update(prompt = FALSE)
  } else {
    for (pkg in packages) {
      cat(sprintf("  Updating %s...\n", pkg))
      renv::update(pkg, prompt = FALSE)
    }
  }
  TRUE
}, error = function(e) {
  cat(sprintf("  ERROR during update: %s\n", e$message))
  FALSE
})

if (!update_success) {
  cat("\n  Update failed. Rolling back...\n")
  if (file.exists(backup_file)) {
    file.copy(backup_file, lock_file, overwrite = TRUE)
    renv::restore(prompt = FALSE)
    cat("  Rolled back to previous state.\n")
  }
  quit(status = 1)
}

# Show new versions
if (!update_all) {
  for (pkg in packages) {
    ver <- tryCatch(
      as.character(packageVersion(pkg)),
      error = function(e) "NOT INSTALLED"
    )
    cat(sprintf("  - %s: new version = %s\n", pkg, ver))
  }
}

# --- Step 4: Run tests -------------------------------------------------------
cat("\nStep 4: Running full test suite...\n")
cat("  This may take 5-10 minutes...\n\n")

test_result <- tryCatch({
  # Source and run the test runner
  source(file.path(turas_root, "tools", "run_all_tests.R"), local = TRUE)
  TRUE
}, error = function(e) {
  cat(sprintf("\n  Test runner error: %s\n", e$message))
  FALSE
})

# Check test results file for failures
results_file <- file.path(turas_root, "tools", "test_results.txt")
tests_passed <- FALSE

if (file.exists(results_file)) {
  results_text <- readLines(results_file, warn = FALSE)
  # Find the PLATFORM STATUS line
  status_line <- grep("PLATFORM STATUS:", results_text, value = TRUE)
  if (length(status_line) > 0) {
    if (grepl("ALL TESTS PASSED", status_line[length(status_line)])) {
      tests_passed <- TRUE
    } else {
      # Extract failure count
      fail_match <- regmatches(status_line[length(status_line)],
                               regexpr("\\d+ TEST\\(S\\) FAILED", status_line[length(status_line)]))
      if (length(fail_match) > 0) {
        cat(sprintf("\n  TEST RESULT: %s\n", fail_match))
      }
    }
  }
}

# --- Step 5: Snapshot or rollback ---------------------------------------------
if (tests_passed) {
  cat("\n")
  cat("================================================================================\n")
  cat("  ALL TESTS PASSED - Snapshotting new package state\n")
  cat("================================================================================\n")

  renv::snapshot(prompt = FALSE)

  # Remove backup
  if (file.exists(backup_file)) {
    file.remove(backup_file)
  }

  cat("\n  renv.lock updated successfully.\n")
  cat("  Remember to commit renv.lock to git:\n")
  cat("    git add renv.lock\n")
  cat("    git commit -m \"chore: update packages\"\n\n")

} else {
  cat("\n")
  cat("================================================================================\n")
  cat("  TESTS FAILED - Rolling back package update\n")
  cat("================================================================================\n")

  if (file.exists(backup_file)) {
    file.copy(backup_file, lock_file, overwrite = TRUE)
    tryCatch({
      renv::restore(prompt = FALSE)
      cat("  Rolled back to previous package versions.\n")
    }, error = function(e) {
      cat(sprintf("  Rollback error: %s\n", e$message))
      cat("  Manual recovery: copy renv.lock.backup to renv.lock, then renv::restore()\n")
    })
  } else {
    cat("  No backup file found for rollback.\n")
    cat("  Manual recovery: git checkout renv.lock && renv::restore()\n")
  }

  cat("\n  The package update was reverted because tests failed.\n")
  cat("  Review the test output above to understand what broke.\n")
  cat("  Options:\n")
  cat("    1. Fix the code to work with the new package version\n")
  cat("    2. Pin the package to the older version\n")
  cat("    3. Skip that package update\n\n")

  quit(status = 1)
}

cat("Done.\n")
