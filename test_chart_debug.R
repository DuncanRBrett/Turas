# Temporary chart debug - delete after use
setwd("/Users/duncan/Documents/Turas")
shared_lib <- file.path("modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "[.]R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
assign("script_dir_override", file.path(getwd(), "modules", "maxdiff", "R"), envir = globalenv())
source("modules/maxdiff/R/00_main.R")
config_path <- "examples/maxdiff/demo_showcase/Demo_MaxDiff_Config.xlsx"
results <- run_maxdiff(config_path, verbose = FALSE)

# Source HTML modules AFTER run_maxdiff (overwrite cached versions)
source("modules/maxdiff/lib/html_report/01_data_transformer.R")
source("modules/maxdiff/lib/html_report/04_chart_builder.R")

config <- load_maxdiff_config(config_path)
html_data <- transform_maxdiff_for_html(results, config)
brand <- html_data$meta$brand_colour

chart <- tryCatch(
  build_utility_distribution_chart(html_data$utility_distributions, brand),
  error = function(e) {
    cat("CHART ERROR:", e$message, "\n")
    cat("Call:", deparse(e$call), "\n")
    ""
  }
)
cat("Chart length:", nchar(chart), "\n")
