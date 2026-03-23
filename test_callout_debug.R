# Temporary debug script - delete after use
setwd("/Users/duncan/Documents/Turas")

shared_lib <- file.path("modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "[.]R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
assign("script_dir_override", file.path(getwd(), "modules", "maxdiff", "R"), envir = globalenv())
source("modules/maxdiff/R/00_main.R")

config_path <- "examples/maxdiff/demo_showcase/Demo_MaxDiff_Config.xlsx"
cat("Running MaxDiff...\n")
results <- run_maxdiff(config_path, verbose = FALSE)
cat("MaxDiff status:", results$status, "\n")

# Now source the HTML report sub-modules
source("modules/maxdiff/lib/html_report/99_html_report_main.R")
.md_load_report_submodules()

# Try transform
cat("\n=== Testing transform_maxdiff_for_html ===\n")
config <- results$config
if (is.null(config)) {
  config <- load_maxdiff_config(config_path)
  cat("Config loaded from file\n")
}

html_data <- tryCatch(
  transform_maxdiff_for_html(results, config),
  error = function(e) {
    cat("TRANSFORM ERROR:", conditionMessage(e), "\n")
    NULL
  }
)

if (!is.null(html_data)) {
  cat("Transform SUCCESS\n")
  cat("Keys:", paste(names(html_data), collapse = ", "), "\n")
} else {
  cat("Transform FAILED\n")
}
