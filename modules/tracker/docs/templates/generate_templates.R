# ==============================================================================
# Generate Tracker Config Templates
# ==============================================================================
# Run this script to regenerate the Tracking_Config.xlsx and
# Question_Mapping.xlsx templates in this directory.
#
# USAGE:
#   cd /path/to/Turas
#   Rscript modules/tracker/docs/templates/generate_templates.R
#
# ==============================================================================

library(openxlsx)

# Determine project root from this script's location
script_dir <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  "modules/tracker/docs/templates"
})

project_root <- tryCatch({
  normalizePath(file.path(script_dir, "../../../.."))
}, error = function(e) {
  getwd()
})

cat("Project root:", project_root, "\n")

# Source dependencies
source(file.path(project_root, "modules", "shared", "template_styles.R"))

# Source generate_config_templates.R but skip its own source() call
# and the library(openxlsx) call (we already loaded both above).
# The source() call spans lines 26-28, so we remove those lines.
gen_lines <- readLines(file.path(project_root, "modules", "tracker", "lib", "generate_config_templates.R"))
# Remove the multi-line source() block and the library() line
skip_indices <- which(grepl("^source\\(file\\.path\\(dirname|^  \"\\.\"\\)\\)|^library\\(openxlsx\\)", gen_lines))
if (length(skip_indices) > 0) {
  gen_lines <- gen_lines[-skip_indices]
}
eval(parse(text = paste(gen_lines, collapse = "\n")))

# Output directory = this script's directory
output_dir <- file.path(project_root, "modules", "tracker", "docs", "templates")

cat("\nGenerating templates in:", output_dir, "\n\n")

generate_all_tracker_templates(output_dir)
