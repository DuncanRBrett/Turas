# Path Helper Functions for TURAS Regression Tests
#
# These functions help locate example projects and golden values files
# for regression testing.
#
# Author: TURAS Development Team
# Version: 1.0
# Date: 2025-12-02

#' Get paths for an example project
#'
#' Returns a list of file paths for a specific module example project,
#' including data file, config file, and README.
#'
#' @param module Character. Module name (e.g., "tabs", "tracker", "confidence")
#' @param example Character. Example name (default: "basic")
#' @return List with named elements: base, data, config, readme
#' @export
#' @examples
#' paths <- get_example_paths("tabs", "basic")
#' data <- read.csv(paths$data)
get_example_paths <- function(module, example = "basic") {
  base_path <- file.path("examples", module, example)

  if (!dir.exists(base_path)) {
    stop("Example not found: ", base_path, "\n",
         "Please create the example project first.")
  }

  data_path <- file.path(base_path, "data.csv")
  config_path <- file.path(base_path, paste0(module, "_config.xlsx"))
  readme_path <- file.path(base_path, "README.md")

  # Validate required files exist
  if (!file.exists(data_path)) {
    stop("Data file not found: ", data_path)
  }

  if (!file.exists(config_path)) {
    stop("Config file not found: ", config_path)
  }

  list(
    base = base_path,
    data = data_path,
    config = config_path,
    readme = readme_path
  )
}

#' Get golden values file path
#'
#' Returns the path to the golden values JSON file for a specific
#' module and example.
#'
#' @param module Character. Module name
#' @param example Character. Example name (default: "basic")
#' @return Character. Path to golden values JSON file
#' @export
#' @examples
#' golden_path <- get_golden_path("tabs", "basic")
get_golden_path <- function(module, example = "basic") {
  filename <- paste0(module, "_", example, ".json")
  path <- file.path("tests", "regression", "golden", filename)

  if (!file.exists(path)) {
    stop("Golden values file not found: ", path, "\n",
         "Expected file: ", filename, "\n",
         "Please create the golden values file first.")
  }

  path
}

#' Load golden values from JSON
#'
#' Loads and parses a golden values JSON file.
#'
#' @param module Character. Module name
#' @param example Character. Example name (default: "basic")
#' @return List. Parsed golden values structure
#' @export
#' @examples
#' golden <- load_golden("tabs", "basic")
#' print(golden$checks)
load_golden <- function(module, example = "basic") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required for loading golden values.\n",
         "Install it with: install.packages('jsonlite')")
  }

  path <- get_golden_path(module, example)

  tryCatch({
    golden <- jsonlite::fromJSON(path, simplifyVector = FALSE)

    # Validate structure
    if (is.null(golden$module) || is.null(golden$checks)) {
      stop("Invalid golden values file structure. ",
           "Must contain 'module' and 'checks' fields.")
    }

    golden
  }, error = function(e) {
    stop("Error loading golden values from ", path, ":\n", e$message)
  })
}

#' Check if running from TURAS root directory
#'
#' Validates that the working directory is the TURAS root.
#' Stops execution with an error message if not.
#'
#' @return Invisible TRUE if valid, stops with error otherwise
#' @export
check_turas_root <- function() {
  required_dirs <- c("modules", "tests", "examples")

  for (dir in required_dirs) {
    if (!dir.exists(dir)) {
      stop("Not in TURAS root directory.\n",
           "Current directory: ", getwd(), "\n",
           "Missing directory: ", dir, "\n",
           "Please run from the Turas root directory.")
    }
  }

  invisible(TRUE)
}
