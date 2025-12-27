# ==============================================================================
# SEGMENTATION UTILITIES - PROJECT INITIALIZATION
# ==============================================================================
# Purpose: Project folder structure setup and initialization
# Part of: Turas Segmentation Module
# Version: 1.1.0 (Refactored for maintainability)
# ==============================================================================

#' Initialize Segmentation Project
#'
#' Sets up a new segmentation project with folder structure and config template
#'
#' @param project_name Name of the project
#' @param data_file Path to survey data
#' @param base_folder Base folder for project (default: "projects/")
#' @export
initialize_segmentation_project <- function(project_name, data_file,
                                            base_folder = "projects/") {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("INITIALIZING SEGMENTATION PROJECT\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Create project folder structure
  project_folder <- file.path(base_folder, project_name)

  folders <- c(
    project_folder,
    file.path(project_folder, "config"),
    file.path(project_folder, "output"),
    file.path(project_folder, "data"),
    file.path(project_folder, "reports")
  )

  for (folder in folders) {
    if (!dir.exists(folder)) {
      dir.create(folder, recursive = TRUE)
      cat(sprintf("Created: %s\n", folder))
    }
  }

  # Generate config template
  config_file <- file.path(project_folder, "config", "segmentation_config.xlsx")
  generate_config_template(data_file, config_file, mode = "exploration")

  # Create README
  readme_file <- file.path(project_folder, "README.txt")
  readme_content <- sprintf("
SEGMENTATION PROJECT: %s
Created: %s

FOLDER STRUCTURE:
  config/   - Configuration files
  output/   - Segmentation results
  data/     - Input data files
  reports/  - Final reports and visualizations

NEXT STEPS:
  1. Edit config/segmentation_config.xlsx
  2. Fill in required fields (id_variable, clustering_vars)
  3. Run segmentation using Turas launcher
  4. Review results in output/ folder

DATA FILE:
  %s
", project_name, Sys.time(), data_file)

  writeLines(readme_content, readme_file)

  cat(sprintf("\n✓ Project initialized: %s\n", project_folder))
  cat("\nNext steps:\n")
  cat(sprintf("  1. Edit %s\n", config_file))
  cat("  2. Fill in required configuration fields\n")
  cat("  3. Run segmentation\n\n")

  return(invisible(list(
    project_folder = project_folder,
    config_file = config_file
  )))
}
