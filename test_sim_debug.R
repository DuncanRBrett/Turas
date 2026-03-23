# Temporary debug script - clean run - delete after use
setwd("/Users/duncan/Documents/Turas")
shared_lib <- file.path("modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "[.]R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
assign("script_dir_override", file.path(getwd(), "modules", "maxdiff", "R"), envir = globalenv())
source("modules/maxdiff/R/00_main.R")
config_path <- "examples/maxdiff/demo_showcase/Demo_MaxDiff_Config.xlsx"

# Force clean re-source of HTML submodules
.md_html_loaded <- FALSE
assign(".md_html_loaded", FALSE, envir = globalenv())

results <- run_maxdiff(config_path, verbose = TRUE)

# Check simulator separately
sim_main <- "modules/maxdiff/lib/html_simulator/99_simulator_main.R"
source(sim_main, local = FALSE)
config <- load_maxdiff_config(config_path)
sim_html <- tryCatch(
  build_simulator_html_string(results, config),
  error = function(e) { cat("SIM ERROR:", conditionMessage(e), "\n"); NULL }
)
if (!is.null(sim_html)) {
  cat("Simulator HTML length:", nchar(sim_html), "\n")
} else {
  cat("Simulator FAILED\n")
}
