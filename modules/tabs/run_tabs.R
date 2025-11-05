# ==============================================================================
# TURAS>TABS - CROSSTABULATION MODULE
# ==============================================================================
# Click "Source" in RStudio to run
# ==============================================================================

# Load Turas if not already loaded
if (!exists("TURAS_HOME")) {
  # Try to find turas.R
  search_paths <- c(
    "../..",  # If running from modules/tabs/
    "..",     # If running from modules/
    "."       # If running from Turas root
  )
  
  for (path in search_paths) {
    if (file.exists(file.path(path, "turas.R"))) {
      source(file.path(path, "turas.R"))
      break
    }
  }
  
  if (!exists("TURAS_HOME")) {
    stop("Cannot find Turas. Please run from Turas directory or set TURAS_HOME")
  }
}

# Load Tabs module
turas_load("tabs")

#' Main entry point for Tabs analysis
run_tabs_analysis <- function(project_path = NULL) {
  
  cat("\n")
  cat("=======================================\n")
  cat("       TURAS>TABS ANALYSIS             \n")
  cat("=======================================\n\n")
  
  # Select project if not provided
  if (is.null(project_path)) {
    project_path <- turas_select_project()
    if (is.null(project_path)) {
      cat("No project selected.\n")
      return(invisible(NULL))
    }
  }
  
  # Set working directory to project
  old_wd <- setwd(project_path)
  on.exit(setwd(old_wd))
  
  cat("\nProject:", basename(project_path), "\n")
  cat("Path:", project_path, "\n\n")
  
  # Check for required files
  required_files <- c(
    "Survey_Structure.xlsx",
    "Tabs_Config.xlsx"
  )
  
  missing_files <- required_files[!file.exists(required_files)]
  
  if (length(missing_files) > 0) {
    cat("Missing required files:\n")
    for (file in missing_files) {
      cat("  x", file, "\n")
    }
    cat("\nPlease add the required files and try again.\n")
    return(invisible(NULL))
  }
  
  # Run analysis (placeholder - will be implemented during migration)
  cat("Loading configuration...\n")
  cat("Loading survey structure...\n")
  cat("Loading data...\n")
  cat("Running crosstabulation...\n")
  cat("Writing output...\n")
  
  cat("\nAnalysis complete!\n")
  cat("Output saved to:", file.path(project_path, "Output"), "\n\n")
}

# Run if sourced interactively
if (interactive()) {
  run_tabs_analysis()
}

