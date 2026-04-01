# ==============================================================================
# CONJOINT - PRE-FLIGHT CHECK
# ==============================================================================
#
# Validates that the conjoint module is ready to run before execution.
# Checks file integrity, package availability, JS syntax, and TRS infrastructure.
#
# Version: 1.0
# Date: March 2026
#
# ==============================================================================


#' Conjoint Module Pre-Flight Check
#'
#' Validates that all required files, packages, and infrastructure are in place
#' before running a conjoint analysis. Useful for diagnosing setup issues.
#'
#' @param verbose Logical. If TRUE (default), prints a summary table to console.
#' @param module_dir Character. Path to the conjoint R/ directory. If NULL,
#'   auto-detected from the working directory.
#'
#' @return A TRS-compliant list with:
#'   \item{status}{"PASS" if all checks pass, "REFUSED" if critical checks fail}
#'   \item{checks}{Named list of individual check results}
#'   \item{summary}{Character vector of check outcomes}
#'   \item{message}{Human-readable summary}
#'   \item{code}{TRS error code (only if REFUSED)}
#'   \item{how_to_fix}{Remediation steps (only if REFUSED)}
#'
#' @examples
#' \dontrun{
#'   result <- conjoint_preflight()
#'   if (result$status == "PASS") {
#'     cat("Module is ready to run.\n")
#'   }
#' }
#'
#' @export
conjoint_preflight <- function(verbose = TRUE, module_dir = NULL) {

  # --------------------------------------------------------------------------
  # Resolve module directory
  # --------------------------------------------------------------------------
  if (is.null(module_dir)) {
    module_dir <- .preflight_find_module_dir()
  }

  if (is.null(module_dir) || !dir.exists(module_dir)) {
    msg <- sprintf("Cannot locate conjoint module R/ directory. Tried: %s",
                   if (is.null(module_dir)) "(auto-detect failed)" else module_dir)
    cat("\n=== TURAS PREFLIGHT ERROR ===\n")
    cat("Problem:", msg, "\n")
    cat("Fix: Set working directory to Turas root, or pass module_dir explicitly.\n")
    cat("=============================\n\n")
    return(list(
      status = "REFUSED",
      code = "IO_MODULE_DIR_NOT_FOUND",
      message = msg,
      how_to_fix = "Set working directory to the Turas project root, or supply module_dir parameter."
    ))
  }

  # Base directory (modules/conjoint/)
  base_dir <- dirname(module_dir)

  checks <- list()
  failures <- character(0)

  # --------------------------------------------------------------------------
  # CHECK 1: Required R source files
  # --------------------------------------------------------------------------
  expected_r_files <- c(
    "00_guard.R", "00_main.R", "00_preflight.R",
    "01_config.R", "02_data.R", "03_estimation.R",
    "04_utilities.R", "05_alchemer_import.R", "05_simulator.R",
    "06_interactions.R", "07_output.R", "08_market_simulator.R",
    "09_none_handling.R", "10_best_worst.R", "11_hierarchical_bayes.R",
    "12_config_template.R", "13_latent_class.R", "14_willingness_to_pay.R",
    "15_product_optimizer.R", "99_helpers.R"
  )

  r_present <- vapply(expected_r_files, function(f) {
    file.exists(file.path(module_dir, f))
  }, logical(1))

  r_missing <- expected_r_files[!r_present]

  checks$r_files <- list(
    name = "R source files",
    pass = length(r_missing) == 0,
    expected = length(expected_r_files),
    found = sum(r_present),
    missing = r_missing
  )

  if (length(r_missing) > 0) {
    failures <- c(failures, sprintf("Missing R files: %s", paste(r_missing, collapse = ", ")))
  }

  # --------------------------------------------------------------------------
  # CHECK 2: Required JS files
  # --------------------------------------------------------------------------
  js_dir <- file.path(base_dir, "lib", "html_report", "js")
  expected_js_files <- c(
    "cj_pins.js", "conjoint_charts.js", "conjoint_export.js",
    "conjoint_navigation.js", "simulator_charts.js", "simulator_engine.js",
    "simulator_ui.js"
  )

  js_present <- vapply(expected_js_files, function(f) {
    file.exists(file.path(js_dir, f))
  }, logical(1))

  js_missing <- expected_js_files[!js_present]

  checks$js_files <- list(
    name = "JS files",
    pass = length(js_missing) == 0,
    expected = length(expected_js_files),
    found = sum(js_present),
    missing = js_missing
  )

  if (length(js_missing) > 0) {
    failures <- c(failures, sprintf("Missing JS files: %s", paste(js_missing, collapse = ", ")))
  }

  # --------------------------------------------------------------------------
  # CHECK 3: Required HTML report R files
  # --------------------------------------------------------------------------
  html_dir <- file.path(base_dir, "lib", "html_report")
  expected_html_files <- c(
    "00_html_guard.R", "01_data_transformer.R", "02_table_builder.R",
    "03_page_builder.R", "04_html_writer.R", "05_chart_builder.R",
    "99_html_report_main.R"
  )

  html_present <- vapply(expected_html_files, function(f) {
    file.exists(file.path(html_dir, f))
  }, logical(1))

  html_missing <- expected_html_files[!html_present]

  checks$html_report_files <- list(
    name = "HTML report R files",
    pass = length(html_missing) == 0,
    expected = length(expected_html_files),
    found = sum(html_present),
    missing = html_missing
  )

  if (length(html_missing) > 0) {
    failures <- c(failures, sprintf("Missing HTML report files: %s", paste(html_missing, collapse = ", ")))
  }

  # --------------------------------------------------------------------------
  # CHECK 4: Required packages
  # --------------------------------------------------------------------------
  required_pkgs <- c("mlogit", "survival", "openxlsx", "data.table", "jsonlite")
  optional_pkgs <- c("bayesm")

  pkg_installed <- vapply(required_pkgs, function(p) {
    requireNamespace(p, quietly = TRUE)
  }, logical(1))

  pkg_missing <- required_pkgs[!pkg_installed]

  opt_installed <- vapply(optional_pkgs, function(p) {
    requireNamespace(p, quietly = TRUE)
  }, logical(1))

  opt_missing <- optional_pkgs[!opt_installed]

  checks$packages <- list(
    name = "Required packages",
    pass = length(pkg_missing) == 0,
    expected = length(required_pkgs),
    found = sum(pkg_installed),
    missing = pkg_missing
  )

  checks$optional_packages <- list(
    name = "Optional packages",
    pass = TRUE,  # optional never causes failure
    expected = length(optional_pkgs),
    found = sum(opt_installed),
    missing = opt_missing
  )

  if (length(pkg_missing) > 0) {
    failures <- c(failures, sprintf("Missing packages: %s", paste(pkg_missing, collapse = ", ")))
  }

  # --------------------------------------------------------------------------
  # CHECK 5: JS syntax validation (if node is available)
  # --------------------------------------------------------------------------
  node_available <- nzchar(Sys.which("node"))

  if (node_available && checks$js_files$pass) {
    js_errors <- character(0)
    for (f in expected_js_files) {
      fpath <- file.path(js_dir, f)
      if (file.exists(fpath)) {
        res <- tryCatch({
          system2("node", args = c("--check", fpath),
                  stdout = TRUE, stderr = TRUE)
        }, error = function(e) e$message)

        exit_code <- attr(res, "status")
        if (!is.null(exit_code) && exit_code != 0) {
          js_errors <- c(js_errors, sprintf("%s: %s", f, paste(res, collapse = " ")))
        }
      }
    }

    checks$js_syntax <- list(
      name = "JS syntax validation",
      pass = length(js_errors) == 0,
      expected = sum(js_present),
      found = sum(js_present) - length(js_errors),
      missing = js_errors
    )

    if (length(js_errors) > 0) {
      failures <- c(failures, sprintf("JS syntax errors: %s", paste(js_errors, collapse = "; ")))
    }
  } else {
    checks$js_syntax <- list(
      name = "JS syntax validation",
      pass = TRUE,
      expected = NA,
      found = NA,
      missing = if (!node_available) "Skipped (node not found)" else "Skipped (JS files missing)"
    )
  }

  # --------------------------------------------------------------------------
  # CHECK 6: TRS infrastructure
  # --------------------------------------------------------------------------
  trs_funcs <- c("conjoint_refuse", "conjoint_with_refusal_handler")
  trs_present <- vapply(trs_funcs, function(fn) {
    exists(fn, mode = "function")
  }, logical(1))

  trs_missing <- trs_funcs[!trs_present]

  checks$trs_infrastructure <- list(
    name = "TRS infrastructure",
    pass = length(trs_missing) == 0,
    expected = length(trs_funcs),
    found = sum(trs_present),
    missing = trs_missing
  )

  if (length(trs_missing) > 0) {
    failures <- c(failures, sprintf("Missing TRS functions: %s", paste(trs_missing, collapse = ", ")))
  }

  # --------------------------------------------------------------------------
  # Build result
  # --------------------------------------------------------------------------
  all_pass <- length(failures) == 0
  version <- if (exists("get_conjoint_version", mode = "function")) {
    get_conjoint_version()
  } else {
    "unknown"
  }

  # --------------------------------------------------------------------------
  # Console summary
  # --------------------------------------------------------------------------
  if (verbose) {
    .preflight_print_summary(checks, all_pass, version, failures)
  }

  # --------------------------------------------------------------------------
  # Return TRS-compliant result
  # --------------------------------------------------------------------------
  if (all_pass) {
    return(list(
      status = "PASS",
      message = sprintf("Conjoint module v%s: all pre-flight checks passed.", version),
      checks = checks
    ))
  } else {
    fix_steps <- character(0)
    if (length(checks$r_files$missing) > 0) {
      fix_steps <- c(fix_steps, "Restore missing R source files or re-install the module.")
    }
    if (length(checks$js_files$missing) > 0) {
      fix_steps <- c(fix_steps, "Restore missing JS files in lib/html_report/js/.")
    }
    if (length(checks$html_report_files$missing) > 0) {
      fix_steps <- c(fix_steps, "Restore missing HTML report R files in lib/html_report/.")
    }
    if (length(checks$packages$missing) > 0) {
      fix_steps <- c(fix_steps, sprintf("Install missing packages: install.packages(c(%s))",
                                        paste(sprintf("'%s'", checks$packages$missing), collapse = ", ")))
    }
    if (!is.null(checks$js_syntax) && !checks$js_syntax$pass) {
      fix_steps <- c(fix_steps, "Fix JavaScript syntax errors in the listed files.")
    }
    if (length(checks$trs_infrastructure$missing) > 0) {
      fix_steps <- c(fix_steps, "Source 00_guard.R before running preflight, or source 00_main.R.")
    }

    return(list(
      status = "REFUSED",
      code = "CFG_PREFLIGHT_FAILED",
      message = sprintf("Conjoint preflight failed with %d issue(s).", length(failures)),
      how_to_fix = fix_steps,
      checks = checks,
      failures = failures
    ))
  }
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Auto-detect conjoint module R/ directory
#' @keywords internal
.preflight_find_module_dir <- function() {
  wd <- getwd()
  candidates <- c(
    file.path(wd, "modules", "conjoint", "R"),
    file.path(wd, "R"),  # if cwd is modules/conjoint/
    wd                    # if cwd is modules/conjoint/R/
  )
  for (path in candidates) {
    if (dir.exists(path) && file.exists(file.path(path, "00_main.R"))) {
      return(path)
    }
  }
  return(NULL)
}


#' Print pre-flight summary table to console
#' @keywords internal
.preflight_print_summary <- function(checks, all_pass, version, failures) {
  width <- 64

  cat("\n")
  cat(strrep("-", width), "\n")
  cat(sprintf(" CONJOINT PRE-FLIGHT CHECK  (v%s)\n", version))
  cat(strrep("-", width), "\n")

  for (chk in checks) {
    icon <- if (chk$pass) "PASS" else "FAIL"
    count_str <- if (is.na(chk$expected)) {
      ""
    } else {
      sprintf(" (%d/%d)", chk$found, chk$expected)
    }
    cat(sprintf("  [%s]  %-30s%s\n", icon, chk$name, count_str))

    # Show details for failures or skipped items
    if (!chk$pass && length(chk$missing) > 0) {
      for (m in chk$missing) {
        cat(sprintf("         - %s\n", m))
      }
    } else if (is.character(chk$missing) && length(chk$missing) == 1 &&
               grepl("^Skipped", chk$missing)) {
      cat(sprintf("         %s\n", chk$missing))
    }
  }

  cat(strrep("-", width), "\n")

  if (all_pass) {
    cat("  RESULT: ALL CHECKS PASSED\n")
  } else {
    cat(sprintf("  RESULT: %d ISSUE(S) FOUND\n", length(failures)))
  }

  cat(strrep("-", width), "\n\n")
}
