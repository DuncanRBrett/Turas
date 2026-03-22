#!/usr/bin/env Rscript
# ==============================================================================
# TURAS PLATFORM - COMPREHENSIVE SYSTEM CHECK
# ==============================================================================
#
# Runs all test suites across every module + shared infrastructure.
# Shows a clean progress bar in the console, captures ALL verbose output
# to a log file, then prints a summary table at the end.
#
# USAGE (RStudio console):
#   source("tools/run_all_tests.R")
#
# USAGE (command line):
#   Rscript tools/run_all_tests.R
#
# OPTIONS:
#   --module=tabs        Run only one module
#   --log=path.txt       Custom log file path (default: tools/test_results.txt)
#
# OUTPUT:
#   Console:  Progress bar + summary table
#   Log file: Full verbose test output for analysis
#
# ==============================================================================

# --- Parse command-line arguments ---
args <- tryCatch(commandArgs(trailingOnly = TRUE), error = function(e) character(0))
selected_module <- NULL
log_path <- NULL

for (arg in args) {
  if (grepl("^--module=", arg)) {
    selected_module <- sub("^--module=", "", arg)
  } else if (grepl("^--log=", arg)) {
    log_path <- sub("^--log=", "", arg)
  }
}

# --- Resolve Turas root ---
find_turas_root <- function() {
  env_root <- Sys.getenv("TURAS_ROOT", "")
  if (nzchar(env_root) && file.exists(file.path(env_root, "launch_turas.R"))) {
    return(normalizePath(env_root))
  }
  path <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(path, "launch_turas.R"))) return(normalizePath(path))
    path <- dirname(path)
  }
  script_path <- tryCatch(normalizePath(sys.frame(1)$ofile), error = function(e) NULL)
  if (!is.null(script_path)) {
    path <- dirname(script_path)
    for (i in 1:5) {
      if (file.exists(file.path(path, "launch_turas.R"))) return(normalizePath(path))
      path <- dirname(path)
    }
  }
  stop("Cannot find Turas root directory. Run from Turas root or set TURAS_ROOT.")
}

turas_root <- find_turas_root()
setwd(turas_root)
Sys.setenv(TURAS_ROOT = turas_root)

# --- Default log path ---
if (is.null(log_path)) {
  log_path <- file.path(turas_root, "tools", "test_results.txt")
}

# --- Check testthat ---
if (!requireNamespace("testthat", quietly = TRUE)) {
  cat("\n[ERROR] Package 'testthat' is not installed.\n")
  cat("  Install it with: install.packages('testthat')\n\n")
  stop("testthat required")
}
library(testthat)

# ==============================================================================
# MODULE REGISTRY
# ==============================================================================

modules <- list(
  list(name = "Shared Infrastructure", id = "shared",
       test_dir = "tests/testthat",
       description = "TRS refusals, config, validation, formatting, launcher"),
  list(name = "AlchemerParser", id = "AlchemerParser",
       test_dir = "modules/AlchemerParser/tests/testthat",
       description = "Survey parsing, routing detection, error handling"),
  list(name = "Confidence", id = "confidence",
       test_dir = "modules/confidence/tests/testthat",
       description = "Confidence intervals, bootstrap, proportion/mean CIs"),
  list(name = "Conjoint", id = "conjoint",
       test_dir = "modules/conjoint/tests/testthat",
       description = "Choice-based conjoint, HB estimation, WTP, simulators"),
  list(name = "Cat Driver", id = "catdriver",
       test_dir = "modules/catdriver/tests/testthat",
       description = "Categorical driver analysis, SHAP, logistic regression"),
  list(name = "Key Driver", id = "keydriver",
       test_dir = "modules/keydriver/tests/testthat",
       description = "Key driver correlation, effect sizes, quadrant analysis"),
  list(name = "MaxDiff", id = "maxdiff",
       test_dir = "modules/maxdiff/tests/testthat",
       description = "MaxDiff estimation, HB, preference shares, TURF"),
  list(name = "Pricing", id = "pricing",
       test_dir = "modules/pricing/tests/testthat",
       description = "Van Westendorp, Gabor-Granger, elasticity, optimization"),
  list(name = "Segment", id = "segment",
       test_dir = "modules/segment/tests/testthat",
       description = "Clustering, profiling, guard validation"),
  list(name = "Tabs", id = "tabs",
       test_dir = "modules/tabs/tests/testthat",
       description = "Cross-tabulation, significance testing, Excel/HTML output"),
  list(name = "Tracker", id = "tracker",
       test_dir = "modules/tracker/tests/testthat",
       description = "Longitudinal tracking, wave loading, trend analysis"),
  list(name = "Weighting", id = "weighting",
       test_dir = "modules/weighting/tests/testthat",
       description = "Design/cell/rim weighting, diagnostics, trimming"),
  list(name = "Report Hub", id = "report_hub",
       test_dir = "modules/report_hub/tests/testthat",
       description = "Report combination, HTML parsing, page assembly")
)

# Filter to selected module
if (!is.null(selected_module)) {
  modules <- Filter(function(m) m$id == selected_module, modules)
  if (length(modules) == 0) {
    cat(sprintf("\n[ERROR] Module '%s' not found.\n", selected_module))
    cat("Available: shared, AlchemerParser, confidence, conjoint, catdriver,\n")
    cat("  keydriver, maxdiff, pricing, segment, tabs, tracker, weighting, report_hub\n\n")
    stop("Module not found")
  }
}

# ==============================================================================
# PROGRESS BAR HELPERS
# ==============================================================================

progress_bar <- function(current, total, module_name, width = 40) {
  pct <- current / total
  filled <- round(pct * width)
  empty <- width - filled
  bar <- paste0("[",
                paste(rep("#", filled), collapse = ""),
                paste(rep("-", empty), collapse = ""),
                "]")
  # \r returns cursor to start of line — overwrites previous progress
  msg <- sprintf("\r  %s %3.0f%%  %s", bar, pct * 100, module_name)
  # Pad to overwrite any leftover chars from longer module names
  cat(sprintf("%-75s", msg))
  flush.console()
}

# ==============================================================================
# HEADER (console)
# ==============================================================================

timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
r_version <- paste0(R.version$major, ".", R.version$minor)
n_modules <- length(modules)

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat("  TURAS ANALYTICS PLATFORM - COMPREHENSIVE SYSTEM CHECK\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat(sprintf("  Date:       %s\n", timestamp))
cat(sprintf("  R Version:  %s\n", r_version))
cat(sprintf("  Modules:    %d\n", n_modules))
cat(sprintf("  Log file:   %s\n", log_path))
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# ==============================================================================
# OPEN LOG FILE
# ==============================================================================

log_con <- file(log_path, open = "wt")
writeLines(paste(rep("=", 80), collapse = ""), log_con)
writeLines("TURAS ANALYTICS PLATFORM - COMPREHENSIVE SYSTEM CHECK", log_con)
writeLines(paste(rep("=", 80), collapse = ""), log_con)
writeLines(sprintf("Date:       %s", timestamp), log_con)
writeLines(sprintf("R Version:  %s", r_version), log_con)
writeLines(sprintf("Root:       %s", turas_root), log_con)
writeLines(paste(rep("=", 80), collapse = ""), log_con)
writeLines("", log_con)

# ==============================================================================
# RUN TESTS
# ==============================================================================

results <- list()
overall_start <- proc.time()

for (i in seq_along(modules)) {
  mod <- modules[[i]]
  test_path <- file.path(turas_root, mod$test_dir)

  # Update progress bar
  progress_bar(i - 1, n_modules, mod$name)

  # --- Check test directory exists ---
  if (!dir.exists(test_path)) {
    results[[mod$id]] <- list(
      name = mod$name, status = "SKIP", reason = "Test directory not found",
      passed = 0, failed = 0, skipped = 0, warnings = 0,
      n_files = 0, duration = 0, errors_detail = character(0)
    )
    writeLines(sprintf("[SKIP] %s — test directory not found", mod$name), log_con)
    writeLines("", log_con)
    next
  }

  # --- Count test files ---
  test_files <- list.files(test_path, pattern = "^test.*\\.R$", full.names = TRUE)
  n_files <- length(test_files)

  if (n_files == 0) {
    results[[mod$id]] <- list(
      name = mod$name, status = "SKIP", reason = "No test files found",
      passed = 0, failed = 0, skipped = 0, warnings = 0,
      n_files = 0, duration = 0, errors_detail = character(0)
    )
    writeLines(sprintf("[SKIP] %s — no test files", mod$name), log_con)
    writeLines("", log_con)
    next
  }

  # --- Write module header to log ---
  writeLines(paste(rep("-", 80), collapse = ""), log_con)
  writeLines(sprintf("MODULE: %s (%d test files)", mod$name, n_files), log_con)
  writeLines(sprintf("Path:   %s", test_path), log_con)
  writeLines(paste(rep("-", 80), collapse = ""), log_con)
  writeLines("", log_con)

  mod_start <- proc.time()

  # --- Capture ALL output and run tests ---
  # Run in a separate process to prevent session crashes from taking down RStudio
  test_result <- NULL
  captured_output <- character(0)

  # Try in-process first with robust error handling
  captured_output <- tryCatch({
    utils::capture.output({
      test_result <<- tryCatch(
        testthat::test_dir(
          test_path,
          reporter = "silent",
          stop_on_failure = FALSE
        ),
        error = function(e) {
          cat(sprintf("\n[ERROR] Test suite crashed: %s\n", conditionMessage(e)))
          NULL
        },
        warning = function(w) {
          invokeRestart("muffleWarning")
        }
      )
    }, type = "output")
  }, error = function(e) {
    paste("[CAPTURE ERROR]", conditionMessage(e))
  })

  mod_duration <- (proc.time() - mod_start)["elapsed"]

  # Write captured output to log and flush immediately
  writeLines(captured_output, log_con)
  writeLines("", log_con)
  flush(log_con)

  # --- Extract results ---
  if (is.null(test_result)) {
    results[[mod$id]] <- list(
      name = mod$name, status = "ERROR", reason = "Test suite crashed",
      passed = 0, failed = 0, skipped = 0, warnings = 0,
      n_files = n_files, duration = mod_duration, errors_detail = character(0)
    )
    writeLines(sprintf("[ERROR] %s — test suite crashed (%.1fs)", mod$name, mod_duration), log_con)
  } else {
    df <- as.data.frame(test_result)
    n_passed <- sum(df$passed, na.rm = TRUE)
    n_failed <- sum(df$failed, na.rm = TRUE)
    n_skipped <- sum(df$skipped, na.rm = TRUE)
    n_warnings <- sum(df$warning, na.rm = TRUE)
    status <- if (n_failed == 0) "PASS" else "FAIL"

    # Collect failure details for the log
    errors_detail <- character(0)
    if (n_failed > 0) {
      failed_rows <- df[df$failed > 0, , drop = FALSE]
      for (j in seq_len(nrow(failed_rows))) {
        row <- failed_rows[j, ]
        detail <- sprintf("  FAIL in %s / %s: %d failure(s)",
                          row$file, row$context, row$failed)
        errors_detail <- c(errors_detail, detail)
      }
      writeLines("", log_con)
      writeLines("FAILURES IN THIS MODULE:", log_con)
      writeLines(errors_detail, log_con)
    }

    writeLines(sprintf("\n[%s] %s — %d passed, %d failed, %d skipped (%.1fs)",
                       status, mod$name, n_passed, n_failed, n_skipped, mod_duration), log_con)

    results[[mod$id]] <- list(
      name = mod$name, status = status,
      passed = n_passed, failed = n_failed, skipped = n_skipped,
      warnings = n_warnings, n_files = n_files, duration = mod_duration,
      errors_detail = errors_detail
    )
  }

  writeLines("", log_con)
  flush(log_con)
}

# Final progress bar
progress_bar(n_modules, n_modules, "Complete!")
cat("\n\n")

overall_duration <- (proc.time() - overall_start)["elapsed"]

# ==============================================================================
# SUMMARY TABLE (console + log)
# ==============================================================================

write_summary <- function(dest = "console") {
  out <- function(msg) {
    if (dest == "console") cat(msg) else writeLines(trimws(msg, which = "right"), log_con)
  }

  out(paste(rep("=", 70), collapse = ""))
  out("\n")
  out("  SYSTEM CHECK RESULTS\n")
  out(paste(rep("=", 70), collapse = ""))
  out("\n\n")

  out(sprintf("  %-22s  %6s  %6s  %6s  %6s  %6s  %6s\n",
              "Module", "Status", "Pass", "Fail", "Skip", "Warn", "Time"))
  out(sprintf("  %-22s  %6s  %6s  %6s  %6s  %6s  %6s\n",
              paste(rep("-", 22), collapse = ""),
              "------", "------", "------", "------", "------", "------"))

  total_passed <- 0; total_failed <- 0; total_skipped <- 0
  total_warnings <- 0; total_files <- 0

  for (mod_id in names(results)) {
    r <- results[[mod_id]]
    status_str <- switch(r$status,
      "PASS" = " PASS", "FAIL" = " FAIL", "SKIP" = " SKIP", "ERROR" = "ERROR", " ??? ")
    time_str <- if (r$duration > 0) sprintf("%.1fs", r$duration) else "-"
    out(sprintf("  %-22s  [%s]  %5d  %6d  %6d  %6d  %6s\n",
                r$name, status_str, r$passed, r$failed, r$skipped, r$warnings, time_str))
    total_passed <- total_passed + r$passed
    total_failed <- total_failed + r$failed
    total_skipped <- total_skipped + r$skipped
    total_warnings <- total_warnings + r$warnings
    total_files <- total_files + r$n_files
  }

  out(sprintf("  %-22s  %6s  %6s  %6s  %6s  %6s  %6s\n",
              paste(rep("-", 22), collapse = ""),
              "------", "------", "------", "------", "------", "------"))
  out(sprintf("  %-22s  %6s  %5d  %6d  %6d  %6d  %5.1fs\n",
              "TOTALS", "", total_passed, total_failed, total_skipped,
              total_warnings, overall_duration))

  out("\n")
  out(paste(rep("=", 70), collapse = ""))
  out("\n")

  total_tests <- total_passed + total_failed
  pass_rate <- if (total_tests > 0) round(100 * total_passed / total_tests, 1) else 0

  modules_failed <- sum(sapply(results, function(r) r$status == "FAIL"))
  modules_errored <- sum(sapply(results, function(r) r$status == "ERROR"))

  if (total_failed == 0 && modules_errored == 0) {
    out("  PLATFORM STATUS:  ALL TESTS PASSED\n")
  } else {
    out(sprintf("  PLATFORM STATUS:  %d TEST(S) FAILED across %d module(s)\n",
                total_failed, modules_failed + modules_errored))
  }

  out(sprintf("  Pass Rate:        %s%% (%d/%d tests)\n", pass_rate, total_passed, total_tests))
  out(sprintf("  Test Files:       %d across %d modules\n", total_files, length(results)))
  out(sprintf("  Total Duration:   %.1f seconds\n", overall_duration))
  out(paste(rep("=", 70), collapse = ""))
  out("\n")

  # List failed modules with details
  failed_mods <- Filter(function(r) r$status %in% c("FAIL", "ERROR"), results)
  if (length(failed_mods) > 0) {
    out("\n  MODULES WITH FAILURES:\n")
    for (r in failed_mods) {
      out(sprintf("\n    %s (%d failures):\n", r$name, r$failed))
      if (length(r$errors_detail) > 0) {
        for (detail in r$errors_detail) {
          out(sprintf("      %s\n", detail))
        }
      }
    }
  }

  skipped_mods <- Filter(function(r) r$status == "SKIP", results)
  if (length(skipped_mods) > 0) {
    out("\n  SKIPPED MODULES:\n")
    for (r in skipped_mods) {
      out(sprintf("    - %s: %s\n", r$name, r$reason))
    }
  }

  out("\n")
}

# Write summary to console
write_summary("console")

# Write summary to log
writeLines("", log_con)
write_summary("log")

# Close log file
close(log_con)

cat(sprintf("  Full test output saved to:\n  %s\n\n", log_path))
cat("  Share this file to review failures in detail.\n\n")
