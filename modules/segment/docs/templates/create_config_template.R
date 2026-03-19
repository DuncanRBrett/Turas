# ==============================================================================
# CREATE SEGMENT CONFIG TEMPLATE v11.1
# ==============================================================================
# Generates the comprehensive Segment_Config_Template.xlsx using the module's
# built-in generate_segment_config_template() function.
#
# The template includes:
#   - All 48 configuration parameters with default values
#   - Description column explaining each parameter
#   - Data validation dropdowns for constrained parameters
#   - Branded formatting (Aptos font, Turas navy/gold headers)
#   - Frozen header row
#
# Usage:
#   Sys.setenv(TURAS_ROOT = getwd())
#   source("modules/segment/docs/templates/create_config_template.R")
#
# The generated template can also be created programmatically:
#   source("modules/segment/R/00_main.R")
#   generate_segment_config_template("my_config.xlsx")
#
# ==============================================================================

cat("Creating Segment Config Template...\n\n")

# Determine TURAS_ROOT
turas_root <- Sys.getenv("TURAS_ROOT", "")
if (turas_root == "") {
  # Try to auto-detect
  candidate <- getwd()
  while (candidate != dirname(candidate)) {
    if (file.exists(file.path(candidate, "launch_turas.R"))) {
      turas_root <- candidate
      break
    }
    candidate <- dirname(candidate)
  }
  if (turas_root == "") turas_root <- getwd()
  Sys.setenv(TURAS_ROOT = turas_root)
}

# Source the segment module
source(file.path(turas_root, "modules/segment/R/00_main.R"))

# Determine output path
script_dir <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  file.path(turas_root, "modules/segment/docs/templates")
})

output_path <- file.path(script_dir, "Segment_Config_Template.xlsx")

# Generate the template
generate_segment_config_template(output_path, include_sample_values = TRUE)

cat("\nTemplate generation complete.\n")
cat(sprintf("Output: %s\n", output_path))
