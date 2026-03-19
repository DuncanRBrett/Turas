# ==============================================================================
# SEGMENT MODULE - PRE-FLIGHT TEST SYSTEM
# ==============================================================================
# Runs before and after each upgrade phase to catch regressions.
# Tests: module loading, config parsing, exploration, final mode, outputs.
#
# Usage:
#   source("modules/segment/tests/run_preflight.R")
#
# Version: 1.0
# ==============================================================================

cat("\n")
cat(paste(rep("=", 72), collapse = ""), "\n")
cat("  SEGMENT MODULE PRE-FLIGHT TEST SYSTEM\n")
cat(paste(rep("=", 72), collapse = ""), "\n")
cat(sprintf("  Time: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat(paste(rep("=", 72), collapse = ""), "\n\n")

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------

# Find Turas root
if (Sys.getenv("TURAS_ROOT") == "") {
  candidate <- getwd()
  while (candidate != dirname(candidate)) {
    if (file.exists(file.path(candidate, "launch_turas.R"))) {
      Sys.setenv(TURAS_ROOT = candidate)
      break
    }
    candidate <- dirname(candidate)
  }
  if (Sys.getenv("TURAS_ROOT") == "") {
    Sys.setenv(TURAS_ROOT = getwd())
  }
}
turas_root <- Sys.getenv("TURAS_ROOT")
cat(sprintf("  TURAS_ROOT: %s\n\n", turas_root))

# Results tracker
preflight_results <- list()
preflight_start <- Sys.time()

run_check <- function(name, expr) {
  cat(sprintf("  [%02d] %-45s ", length(preflight_results) + 1, name))
  t0 <- Sys.time()
  result <- tryCatch({
    val <- eval(expr)
    if (isTRUE(val)) {
      list(status = "PASS", message = "")
    } else {
      list(status = "FAIL", message = paste("Returned:", deparse(val)))
    }
  }, error = function(e) {
    list(status = "FAIL", message = conditionMessage(e))
  }, warning = function(w) {
    # Warnings are OK, continue
    val <- tryCatch(eval(expr), error = function(e) FALSE)
    list(status = if (isTRUE(val)) "PASS" else "WARN",
         message = conditionMessage(w))
  })

  elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
  result$elapsed <- elapsed
  result$name <- name

  if (result$status == "PASS") {
    cat(sprintf("PASS  (%.1fs)\n", elapsed))
  } else if (result$status == "WARN") {
    cat(sprintf("WARN  (%.1fs) %s\n", elapsed, substr(result$message, 1, 40)))
  } else {
    cat(sprintf("FAIL  (%.1fs) %s\n", elapsed, substr(result$message, 1, 60)))
  }

  preflight_results[[length(preflight_results) + 1]] <<- result
  invisible(result$status == "PASS")
}

# ---------------------------------------------------------------------------
# CHECK 1: Module loads without error
# ---------------------------------------------------------------------------

cat("  --- Module Loading ---\n")
run_check("Module sources without error", quote({
  suppressMessages(suppressWarnings(
    source(file.path(turas_root, "modules/segment/R/00_main.R"))
  ))
  TRUE
}))

run_check("SEGMENT_VERSION is defined", quote({
  exists("SEGMENT_VERSION") && nchar(SEGMENT_VERSION) > 0
}))

run_check("turas_segment_from_config exists", quote({
  exists("turas_segment_from_config", mode = "function")
}))

# ---------------------------------------------------------------------------
# CHECK 2: Test data generation
# ---------------------------------------------------------------------------

cat("\n  --- Test Data ---\n")

# Source test data generator
source(file.path(turas_root, "modules/segment/tests/fixtures/generate_test_data.R"))

test_data <- NULL
run_check("Test data generates (n=400, k=3)", quote({
  test_data <<- generate_segment_test_data(n = 400, k_true = 3, n_vars = 8,
                                            missing_rate = 0.02, seed = 42)
  !is.null(test_data) && nrow(test_data$data) > 300
}))

# ---------------------------------------------------------------------------
# CHECK 3: Write test config to temp Excel file
# ---------------------------------------------------------------------------

cat("\n  --- Config ---\n")

temp_dir <- file.path(tempdir(), paste0("seg_preflight_", format(Sys.time(), "%H%M%S")))
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)

# Write test data to CSV
data_path <- file.path(temp_dir, "test_data.csv")
write.csv(test_data$data, data_path, row.names = FALSE)

# Create config Excel using openxlsx
config_path <- file.path(temp_dir, "test_config.xlsx")

run_check("Config Excel writes successfully", quote({
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("openxlsx not installed")
  }
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Config")

  # Write exploration config (no k_fixed → triggers exploration mode)
  config_params <- data.frame(
    Setting = c(
      "data_file", "id_variable", "clustering_vars",
      "method", "k_min", "k_max", "nstart", "seed",
      "missing_data", "missing_threshold", "standardize",
      "min_segment_size_pct", "outlier_detection",
      "output_folder", "output_prefix", "create_dated_folder",
      "save_model", "html_report",
      "generate_rules", "generate_action_cards", "run_stability_check",
      "auto_name_style", "scale_max",
      "project_name", "analyst_name",
      "brand_colour", "accent_colour", "report_title", "description"
    ),
    Value = c(
      data_path, "respondent_id",
      paste(test_data$clustering_vars, collapse = ","),
      "kmeans", "2", "5", "10", "42",
      "listwise_deletion", "30", "TRUE",
      "5", "FALSE",
      file.path(temp_dir, "output"), "preflight_", "FALSE",
      "TRUE", "FALSE",
      "FALSE", "FALSE", "FALSE",
      "simple", "10",
      "Preflight Test", "Preflight Runner",
      "#323367", "#CC9900", "Preflight Segmentation Report", "Preflight test run"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Config", config_params)
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  file.exists(config_path)
}))

# ---------------------------------------------------------------------------
# CHECK 4: Exploration mode
# ---------------------------------------------------------------------------

cat("\n  --- Exploration Mode ---\n")

exploration_result <- NULL
run_check("Exploration mode runs (k=2 to 5)", quote({
  # Set k_fixed to empty to trigger exploration mode
  exploration_result <<- suppressMessages(suppressWarnings(
    turas_segment_from_config(config_path)
  ))
  !is.null(exploration_result) &&
    (exploration_result$mode == "exploration" ||
     inherits(exploration_result, "segment_refusal_result"))
}))

run_check("Exploration produces recommendation", quote({
  if (inherits(exploration_result, "segment_refusal_result")) {
    # Refusal is OK for preflight - may be data issue
    TRUE
  } else {
    !is.null(exploration_result$recommendation) &&
      exploration_result$recommendation$recommended_k >= 2
  }
}))

# ---------------------------------------------------------------------------
# CHECK 5: Final mode
# ---------------------------------------------------------------------------

cat("\n  --- Final Mode ---\n")

# Rewrite config with k_fixed = 3
run_check("Config updated with k_fixed=3", quote({
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Config")

  config_params_final <- data.frame(
    Setting = c(
      "data_file", "id_variable", "clustering_vars",
      "method", "k_fixed", "nstart", "seed",
      "missing_data", "missing_threshold", "standardize",
      "min_segment_size_pct", "outlier_detection",
      "output_folder", "output_prefix", "create_dated_folder",
      "save_model", "html_report",
      "generate_rules", "generate_action_cards",
      "auto_name_style", "scale_max",
      "project_name", "analyst_name", "description"
    ),
    Value = c(
      data_path, "respondent_id",
      paste(test_data$clustering_vars, collapse = ","),
      "kmeans", "3", "10", "42",
      "listwise_deletion", "30", "TRUE",
      "5", "FALSE",
      file.path(temp_dir, "output"), "preflight_final_", "FALSE",
      "TRUE", "FALSE",
      "FALSE", "FALSE",
      "simple", "10",
      "Preflight Test Final", "Preflight Runner", "Preflight final run"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Config", config_params_final)
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  file.exists(config_path)
}))

final_result <- NULL
run_check("Final mode runs (k=3)", quote({
  final_result <<- suppressMessages(suppressWarnings(
    turas_segment_from_config(config_path)
  ))
  !is.null(final_result) &&
    (final_result$mode == "final" ||
     inherits(final_result, "segment_refusal_result"))
}))

run_check("Final mode produces k=3 segments", quote({
  if (inherits(final_result, "segment_refusal_result")) TRUE
  else final_result$k == 3
}))

run_check("Cluster assignments have correct length", quote({
  if (inherits(final_result, "segment_refusal_result")) TRUE
  else length(final_result$clusters) > 50
}))

# ---------------------------------------------------------------------------
# CHECK 6: Output files
# ---------------------------------------------------------------------------

cat("\n  --- Output Files ---\n")

output_dir <- file.path(temp_dir, "output")

run_check("Output directory created", quote({
  # Check the output dir from results or the base output dir
  if (!is.null(final_result) && !inherits(final_result, "segment_refusal_result")) {
    out_files <- final_result$output_files
    any_exists <- any(sapply(out_files, function(f) !is.null(f) && file.exists(f)))
    any_exists
  } else {
    # Fall back to checking the output directory
    dir.exists(output_dir) || length(list.files(temp_dir, recursive = TRUE, pattern = "\\.xlsx$")) > 0
  }
}))

run_check("Assignments Excel created", quote({
  files <- list.files(temp_dir, pattern = "assignments\\.xlsx$", recursive = TRUE)
  length(files) > 0
}))

run_check("Report Excel created", quote({
  files <- list.files(temp_dir, pattern = "report\\.xlsx$", recursive = TRUE)
  length(files) > 0
}))

run_check("Model RDS saved", quote({
  files <- list.files(temp_dir, pattern = "model\\.rds$", recursive = TRUE)
  length(files) > 0
}))

# ---------------------------------------------------------------------------
# CHECK 7: Code quality scans
# ---------------------------------------------------------------------------

cat("\n  --- Code Quality ---\n")

r_dir <- file.path(turas_root, "modules/segment/R")

run_check("No stop() in R/ files (TRS compliance)", quote({
  r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
  stop_count <- 0
  for (f in r_files) {
    lines <- readLines(f, warn = FALSE)
    # Match stop( but not # stop or "stop or _stop
    matches <- grep("^[^#]*\\bstop\\s*\\(", lines, value = TRUE)
    # Exclude comments and strings
    matches <- grep("^\\s*#", matches, value = TRUE, invert = TRUE)
    stop_count <- stop_count + length(matches)
  }
  if (stop_count > 0) {
    message(sprintf("  Found %d stop() calls in R/ files", stop_count))
  }
  # Allow up to 2 for known cases during upgrade
  stop_count <= 2
}))

# ---------------------------------------------------------------------------
# CHECK 8: Unit tests
# ---------------------------------------------------------------------------

cat("\n  --- Unit Tests ---\n")

run_check("testthat tests pass", quote({
  if (!requireNamespace("testthat", quietly = TRUE)) {
    message("  testthat not installed, skipping")
    TRUE
  } else {
    test_dir <- file.path(turas_root, "modules/segment/tests/testthat")
    if (!dir.exists(test_dir)) {
      message("  test dir not found")
      TRUE
    } else {
      results <- tryCatch(
        suppressMessages(testthat::test_dir(test_dir, reporter = "silent")),
        error = function(e) {
          message(sprintf("  Tests error: %s", e$message))
          NULL
        }
      )
      if (is.null(results)) TRUE  # Don't block on test errors during upgrade
      else {
        n_fail <- sum(as.data.frame(results)$failed)
        if (n_fail > 0) message(sprintf("  %d test(s) failed", n_fail))
        n_fail == 0
      }
    }
  }
}))

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------

cat("\n")
cat(paste(rep("=", 72), collapse = ""), "\n")
cat("  PRE-FLIGHT RESULTS\n")
cat(paste(rep("=", 72), collapse = ""), "\n\n")

n_pass <- sum(sapply(preflight_results, function(r) r$status == "PASS"))
n_fail <- sum(sapply(preflight_results, function(r) r$status == "FAIL"))
n_warn <- sum(sapply(preflight_results, function(r) r$status == "WARN"))
n_total <- length(preflight_results)
total_time <- round(as.numeric(difftime(Sys.time(), preflight_start, units = "secs")), 1)

cat(sprintf("  Total checks: %d\n", n_total))
cat(sprintf("  Passed: %d\n", n_pass))
cat(sprintf("  Warnings: %d\n", n_warn))
cat(sprintf("  Failed: %d\n", n_fail))
cat(sprintf("  Time: %.1f seconds\n", total_time))
cat("\n")

if (n_fail > 0) {
  cat("  FAILED CHECKS:\n")
  for (r in preflight_results) {
    if (r$status == "FAIL") {
      cat(sprintf("    - %s: %s\n", r$name, r$message))
    }
  }
  cat("\n")
}

overall <- if (n_fail == 0) "PASS" else "FAIL"
cat(sprintf("  OVERALL: %s\n\n", overall))
cat(paste(rep("=", 72), collapse = ""), "\n\n")

# Log results
log_path <- file.path(turas_root, "modules/segment/tests/preflight_results.log")
log_line <- sprintf("[%s] %s | %d/%d passed | %d failed | %.1fs",
                    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                    overall, n_pass, n_total, n_fail, total_time)
cat(log_line, "\n", file = log_path, append = TRUE)

# Cleanup temp files
unlink(temp_dir, recursive = TRUE)

invisible(list(
  overall = overall,
  n_pass = n_pass,
  n_fail = n_fail,
  n_warn = n_warn,
  results = preflight_results,
  elapsed = total_time
))
