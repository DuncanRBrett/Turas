# ==============================================================================
# PIPELINE GATE. Child-process runner
# ==============================================================================
#
# Runs ONE parity config through the real tabs entry point, run_tabs_analysis(),
# exactly as launch_turas() does, into a project directory the caller owns. The
# pipeline gate (test_reference_pipeline.R) spawns this in a fresh Rscript so
# nothing the tabs pipeline puts in the global environment can leak into the
# test runner's shared R process, and reads the numbers back from the files it
# writes: the Crosstabs workbook and the v2 HTML report's data island.
#
# Usage:
#   Rscript run_pipeline_child.R <turas_root> <project_dir> <config_name> \
#           [Setting=Value ...]
#
# The project is generated fresh into <project_dir> (never the fixture folder),
# the named config gets the Setting=Value overrides appended to its Settings
# sheet, and the run writes <project_dir>/Output/.
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  cat("Usage: run_pipeline_child.R <turas_root> <project_dir> <config_name> [Setting=Value ...]\n")
  quit(status = 2)
}
turas_root  <- normalizePath(args[1], mustWork = TRUE)
project_dir <- normalizePath(args[2], mustWork = FALSE)
config_name <- args[3]
overrides   <- args[-(1:3)]

suppressWarnings(suppressMessages(library(openxlsx)))

fixture_dir <- file.path(turas_root, "modules/tabs/tests/fixtures/parity_project")
source(file.path(fixture_dir, "generate_parity_project.R"))
source(file.path(turas_root, "modules/shared/lib/turas_save_workbook_atomic.R"))

dir.create(project_dir, showWarnings = FALSE, recursive = TRUE)
generate_parity_project(project_dir)

config_path <- file.path(project_dir, config_name)
if (length(overrides) > 0) {
  kv <- strsplit(overrides, "=", fixed = TRUE)
  settings <- read.xlsx(config_path, sheet = "Settings", skipEmptyRows = FALSE)
  for (pair in kv) {
    key <- pair[1]
    value <- paste(pair[-1], collapse = "=")
    hit <- which(settings$Setting == key)
    if (length(hit)) settings$Value[hit] <- value
    else settings <- rbind(settings, data.frame(Setting = key, Value = value))
  }
  wb <- loadWorkbook(config_path)
  removeWorksheet(wb, "Settings")
  addWorksheet(wb, "Settings")
  worksheetOrder(wb) <- c(length(names(wb)), seq_len(length(names(wb)) - 1))
  writeData(wb, "Settings", settings)
  turas_saveWorkbook(wb, config_path)
}

setwd(turas_root)
source(file.path(turas_root, "modules/tabs/run_tabs.R"))
res <- run_tabs_analysis(config_path)
ok <- !(is.list(res) && identical(res$status, "REFUSED"))
cat("\nPIPELINE_CHILD_DONE", if (ok) "OK" else "REFUSED", "\n")
quit(status = if (ok) 0 else 1)
