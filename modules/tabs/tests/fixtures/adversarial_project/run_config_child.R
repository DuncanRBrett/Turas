# Child-process runner: run ONE existing tabs config through run_tabs_analysis()
# in a fresh Rscript, so nothing the pipeline sets globally leaks into the test
# runner's process. Usage: Rscript run_config_child.R <turas_root> <config_path>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) { cat("Usage: run_config_child.R <turas_root> <config_path>\n"); quit(status = 2) }
setwd(normalizePath(args[1], mustWork = TRUE))
source(file.path(getwd(), "modules/tabs/run_tabs.R"))
res <- run_tabs_analysis(normalizePath(args[2], mustWork = TRUE))
ok <- !(is.list(res) && identical(res$status, "REFUSED"))
cat("\nCONFIG_CHILD_DONE", if (ok) "OK" else "REFUSED", "\n")
quit(status = if (ok) 0 else 1)
