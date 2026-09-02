# ==============================================================================
# RUN THE CONJOINT EXAMPLE END TO END
# ==============================================================================
#
# Runs the smartphone example (example_config.xlsx over sample_cbc_data.csv)
# and prints what came out. Works from any working directory: it finds the
# Turas root by walking up from this file, then sources the module's entry
# point, which loads the rest of the module itself.
#
# Usage:
#   Rscript modules/conjoint/examples/test_analysis.R
# or, from R:
#   source("modules/conjoint/examples/test_analysis.R")
# ==============================================================================

.find_turas_root <- function() {
  home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(home) && dir.exists(file.path(home, "modules", "conjoint"))) return(normalizePath(home))
  start <- local({
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg))))
    getwd()
  })
  d <- start
  for (i in 1:8) {
    if (dir.exists(file.path(d, "modules", "conjoint", "R"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("Cannot find the Turas root above ", start, ". Run from inside the Turas folder.")
}

turas_root <- .find_turas_root()
setwd(turas_root)

cat("\n", strrep("=", 78), "\n", sep = "")
cat("TURAS CONJOINT: EXAMPLE RUN\n")
cat(strrep("=", 78), "\n\n", sep = "")

cat("1. Loading the module from", file.path(turas_root, "modules", "conjoint"), "\n")
source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))

cat("\n2. Running the smartphone example (hierarchical Bayes)...\n\n")
config_file <- file.path(turas_root, "modules", "conjoint", "examples", "example_config.xlsx")
results <- run_conjoint_analysis(config_file = config_file, verbose = TRUE)

cat("\n", strrep("=", 78), "\n", sep = "")
cat("RESULT\n")
cat(strrep("=", 78), "\n\n", sep = "")

if (!is.list(results) || is.null(results$importance)) {
  cat("The run did not produce results. Status:",
      if (is.list(results)) results$status else "unknown", "\n")
  cat("Read the messages above; a refusal names the setting or file at fault.\n")
} else {
  cat(sprintf("Status: %s (PARTIAL means the run finished with warnings; 50 respondents is small for HB)\n",
              results$status))
  cat(sprintf("Method: %s\n", results$model_result$method))
  cat("\nAttribute importance:\n")
  imp <- results$importance[order(-results$importance$Importance), ]
  for (i in seq_len(nrow(imp))) {
    cat(sprintf("  %d. %-16s %5.1f%%\n", i, imp$Attribute[i], imp$Importance[i]))
  }
  cat("\nFrom the simulated utilities, Price and Brand should lead and Screen Size should trail; the middle three are close.\n")

  out_dir <- dirname(results$config$output_file)
  cat("\nFiles in", out_dir, ":\n")
  for (f in sort(list.files(out_dir))) cat("  ", f, "\n")
  cat("\nThe *_cj_island.json is the Conjoint tab for a tabs v2 report (conjoint_island setting).\n")
  cat("The *_tabs_importance.xlsx is a tabs Allocation question: paste its QUESTIONMAP_SNIPPET rows into a tabs config.\n")
  cat("The *_simulator.html is the standalone market simulator; open it in a browser.\n")
}

invisible(results)
