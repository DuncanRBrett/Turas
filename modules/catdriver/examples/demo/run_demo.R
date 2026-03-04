# ==============================================================================
# CATDRIVER DEMO RUNNER
# ==============================================================================
#
# Demonstrates all three outcome types using the synthetic customer survey.
# Run this from the Turas project root:
#
#   source("modules/catdriver/examples/demo/run_demo.R")
#
# Or run a single analysis:
#
#   source("modules/catdriver/examples/demo/run_demo.R")
#   result <- run_demo("binary")   # or "ordinal" or "multinomial"
#
# Prerequisites:
#   - Working directory is the Turas project root
#   - Run generate_demo.R first (or this script will run it for you)
#
# ==============================================================================

# --- Paths ---
project_root <- getwd()
demo_dir     <- file.path(project_root, "modules", "catdriver", "examples", "demo")
module_dir   <- file.path(project_root, "modules", "catdriver")

# --- Generate demo data if not present ---
data_file <- file.path(demo_dir, "demo_customer_survey.csv")
if (!file.exists(data_file)) {
  cat("Demo data not found. Generating...\n")
  demo_output_dir <- demo_dir
  source(file.path(demo_dir, "generate_demo.R"), local = TRUE)
}

# --- Source catdriver module ---
cat("\n=== Loading CatDriver Module ===\n\n")

# Shared utilities - source individual files (skip import_all.R which uses
# sys.frame(1)$ofile and resolves to the wrong path when nested-sourced)
shared_lib <- file.path(project_root, "modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  shared_files <- list.files(shared_lib, pattern = "\\.R$", full.names = TRUE)
  shared_files <- shared_files[!grepl("import_all\\.R$", shared_files)]
  for (f in shared_files) {
    source(f, local = FALSE)
  }
}

# CatDriver R files (in order)
r_dir <- file.path(module_dir, "R")
r_files <- sort(list.files(r_dir, pattern = "^\\d{2}.*\\.R$", full.names = TRUE))
for (f in r_files) {
  source(f, local = FALSE)
}

# HTML report pipeline - set lib dir so 99_html_report_main.R can find submodules
assign(".catdriver_lib_dir", file.path(module_dir, "lib"), envir = globalenv())
html_main <- file.path(module_dir, "lib", "html_report", "99_html_report_main.R")
if (file.exists(html_main)) {
  tryCatch(source(html_main, local = FALSE), error = function(e) {
    cat("  [WARN] Could not load HTML report pipeline:", conditionMessage(e), "\n")
  })
}

cat("CatDriver module loaded.\n\n")

# ==============================================================================
# DEMO RUNNER FUNCTION
# ==============================================================================

#' Run a single demo analysis
#'
#' @param outcome_type One of "binary", "ordinal", "multinomial"
#' @param open_html If TRUE, opens the HTML report in the default browser
#' @return The analysis result list
run_demo <- function(outcome_type = "binary", open_html = FALSE) {

  config_file <- file.path(demo_dir, paste0("demo_config_", outcome_type, ".xlsx"))

  if (!file.exists(config_file)) {
    cat("Config file not found:", config_file, "\n")
    cat("Run generate_demo.R first.\n")
    return(invisible(NULL))
  }

  cat("\n")
  cat("================================================================\n")
  cat("  CATDRIVER DEMO:", toupper(outcome_type), "OUTCOME\n")
  cat("================================================================\n\n")

  result <- run_categorical_keydriver(
    config_file = config_file
  )

  # Print summary
  cat("\n--- Result Summary ---\n")
  cat("Run status:", as.character(result$run_status), "\n")

  if (isTRUE(result$degraded)) {
    cat("Degraded: YES\n")
    cat("Reasons:", paste(result$degraded_reasons, collapse = "; "), "\n")
  }

  if (!is.null(result$importance)) {
    cat("\nTop Drivers (by importance):\n")
    imp <- result$importance
    if (is.data.frame(imp) && nrow(imp) > 0) {
      top <- head(imp[order(-imp$importance_pct), ], 5)
      for (i in seq_len(nrow(top))) {
        cat(sprintf("  %d. %s (%.1f%%)\n",
                    i, top$label[i], top$importance_pct[i]))
      }
    }
  }

  if (!is.null(result$output_file) && file.exists(result$output_file)) {
    cat("\nExcel output:", result$output_file, "\n")
  }

  if (!is.null(result$html_report_file) && file.exists(result$html_report_file)) {
    cat("HTML report:", result$html_report_file, "\n")
    if (open_html) {
      browseURL(result$html_report_file)
    }
  }

  cat("\n")
  return(invisible(result))
}

# ==============================================================================
# UNIFIED (COMBINED) REPORT
# ==============================================================================

#' Run multiple analyses and generate a unified tabbed HTML report
#'
#' @param outcome_types Character vector of outcome types to include
#' @param open_html If TRUE, opens the report in the default browser
#' @return The unified report result list
run_demo_unified <- function(outcome_types = c("binary", "ordinal", "multinomial"),
                             open_html = FALSE) {

  cat("\n")
  cat("================================================================\n")
  cat("  CATDRIVER DEMO: UNIFIED REPORT\n")
  cat("================================================================\n\n")

  # Run each analysis and collect results
  analyses <- list()
  for (ot in outcome_types) {
    cat("Running", ot, "analysis...\n")
    result <- run_demo(ot)
    if (!is.null(result) && !identical(result$run_status, "REFUSE")) {
      analyses[[ot]] <- list(
        results = result,
        config  = result$config,
        label   = paste0(tools::toTitleCase(ot), " Outcome")
      )
    } else {
      cat("  [SKIP]", ot, "analysis failed or was refused.\n")
    }
  }

  if (length(analyses) < 1) {
    cat("No analyses succeeded. Cannot generate unified report.\n")
    return(invisible(NULL))
  }

  # Generate unified report
  unified_path <- file.path(demo_dir, "results_unified.html")

  if (!exists("generate_catdriver_unified_report", mode = "function")) {
    cat("Unified report function not loaded. Check HTML pipeline.\n")
    return(invisible(NULL))
  }

  report_result <- generate_catdriver_unified_report(
    analyses     = analyses,
    output_path  = unified_path,
    report_title = "CatDriver Demo: Multi-Outcome Analysis"
  )

  if (!is.null(report_result$output_file) && file.exists(report_result$output_file)) {
    cat("\nUnified HTML report:", report_result$output_file, "\n")
    if (open_html) browseURL(report_result$output_file)
  }

  cat("\n")
  return(invisible(report_result))
}

# ==============================================================================
# RUN ALL THREE IF SOURCED DIRECTLY
# ==============================================================================

if (!interactive() || identical(Sys.getenv("RUN_DEMO_ALL"), "TRUE")) {
  cat("Running all three demo analyses...\n")

  result_binary       <- run_demo("binary")
  result_ordinal      <- run_demo("ordinal")
  result_multinomial  <- run_demo("multinomial")

  cat("\n=== ALL DEMOS COMPLETE ===\n")
  cat("Check the demo directory for output files:\n")
  cat(" ", demo_dir, "\n")
} else {
  cat("Demo loaded. Run individual analyses with:\n")
  cat("  result <- run_demo(\"binary\")\n")
  cat("  result <- run_demo(\"ordinal\")\n")
  cat("  result <- run_demo(\"multinomial\")\n")
  cat("\nOr generate a unified (combined) HTML report:\n")
  cat("  run_demo_unified()                                    # all three\n")
  cat("  run_demo_unified(c(\"binary\", \"ordinal\"))              # pick two\n")
  cat("  run_demo_unified(open_html = TRUE)                    # open in browser\n")
  cat("\nOr run all three (non-interactive):\n")
  cat("  Sys.setenv(RUN_DEMO_ALL = \"TRUE\")\n")
  cat("  source(\"modules/catdriver/examples/demo/run_demo.R\")\n")
}
