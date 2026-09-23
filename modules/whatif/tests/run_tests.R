#!/usr/bin/env Rscript
# ==============================================================================
# WHAT IF TEST RUNNER
# ==============================================================================
#
# Runs the What if engine test suite. Synthetic data only.
#
# Usage (from the Turas root or the module folder):
#   Rscript modules/whatif/tests/run_tests.R [--verbose]
#
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
verbose <- "--verbose" %in% args || "-v" %in% args

find_module_root <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg)) {
    return(normalizePath(dirname(dirname(sub("^--file=", "", file_arg[1])))))
  }
  for (cand in c(getwd(), file.path(getwd(), "modules", "whatif"))) {
    if (file.exists(file.path(cand, "R", "00_main.R"))) return(normalizePath(cand))
  }
  NULL
}
module_root <- find_module_root()
if (is.null(module_root)) {
  cat("[What if] Cannot find the module root. Run from the Turas root or modules/whatif.\n")
  quit(status = 1)
}
turas_root <- dirname(dirname(module_root))

cat("==============================================================================\n")
cat("  WHAT IF TEST SUITE\n")
cat("==============================================================================\n\n")

for (pkg in c("testthat")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("[What if] Missing required package:", pkg, "\n")
    quit(status = 1)
  }
}
if (!requireNamespace("ordinal", quietly = TRUE)) {
  cat("  ordinal is not installed: the clm agreement tests will be skipped\n")
}

source(file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R"))
for (f in sort(list.files(file.path(module_root, "R"), pattern = "\\.R$", full.names = TRUE))) {
  source(f)
}
source(file.path(module_root, "tests", "fixtures", "synthetic_data", "generate_test_data.R"))

library(testthat)
results <- test_dir(file.path(module_root, "tests", "testthat"),
                    reporter = if (verbose) "progress" else "summary",
                    stop_on_failure = FALSE)
df <- as.data.frame(results)
failed <- sum(df$failed) + sum(df$error)
cat(sprintf("\n  Total: %d | Passed: %d | Failed: %d | Skipped: %d\n\n",
            sum(df$nb), sum(df$nb) - sum(df$failed) - sum(df$skipped), sum(df$failed) + sum(df$error),
            sum(df$skipped)))
quit(status = if (failed > 0) 1 else 0)
