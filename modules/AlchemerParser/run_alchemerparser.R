# ==============================================================================
# ALCHEMER PARSER - CLI ENTRY POINT
# ==============================================================================
# Command-line interface for running AlchemerParser
# ==============================================================================

# Get script directory
get_script_dir <- function() {
  # Method 1: Check call stack for ofile
  for (i in seq_len(sys.nframe())) {
    file <- sys.frame(i)$ofile
    if (!is.null(file) && grepl("run_alchemerparser", file)) {
      return(dirname(normalizePath(file)))
    }
  }

  # Method 2: Check commandArgs
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("--file=", "", file_arg))))
  }

  # Fallback
  return(file.path(getwd(), "modules", "AlchemerParser"))
}

# Source all R functions
script_dir <- get_script_dir()
r_files <- list.files(file.path(script_dir, "R"), pattern = "\\.R$",
                     full.names = TRUE)
for (f in r_files) {
  source(f, local = FALSE)
}

# Check required packages
check_dependencies <- function() {
  required_packages <- c("readxl", "openxlsx", "officer")
  missing_packages <- character(0)

  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing_packages <- c(missing_packages, pkg)
    }
  }

  if (length(missing_packages) > 0) {
    cat("\n")
    cat("==============================================================================\n")
    cat("  MISSING DEPENDENCIES\n")
    cat("==============================================================================\n")
    cat("The following packages are required but not installed:\n\n")
    for (pkg in missing_packages) {
      cat(sprintf("  - %s\n", pkg))
    }
    cat("\nTo install, run:\n")
    cat(sprintf("  install.packages(c(%s))\n",
               paste0("'", missing_packages, "'", collapse = ", ")))
    cat("==============================================================================\n\n")
    stop("Missing required packages", call. = FALSE)
  }
}

# Check dependencies on load
check_dependencies()

cat("\n")
cat("==============================================================================\n")
cat("  ALCHEMER PARSER - CLI MODE\n")
cat("==============================================================================\n")
cat("\n")
cat("Usage:\n")
cat("  result <- run_alchemerparser(\n")
cat("    project_dir = '/path/to/alchemer/files',\n")
cat("    project_name = 'MyProject',  # Optional\n")
cat("    output_dir = '/path/to/output',  # Optional, defaults to project_dir\n")
cat("    verbose = TRUE\n")
cat("  )\n")
cat("\n")
cat("Required input files in project_dir:\n")
cat("  - {ProjectName}_questionnaire.docx\n")
cat("  - {ProjectName}_data_export_map.xlsx\n")
cat("  - {ProjectName}_translation-export.xlsx\n")
cat("\n")
cat("Output files generated:\n")
cat("  - {ProjectName}_Crosstab_Config.xlsx\n")
cat("  - {ProjectName}_Survey_Structure.xlsx\n")
cat("  - {ProjectName}_Data_Headers.xlsx\n")
cat("\n")
cat("==============================================================================\n")
cat("\n")
cat("AlchemerParser loaded and ready.\n")
cat("Type '?run_alchemerparser' for help (after loading function documentation).\n")
cat("\n")
