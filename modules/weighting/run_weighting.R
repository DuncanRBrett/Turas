# ==============================================================================
# TURAS WEIGHTING MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Version: 2.0
# Date: 2025-12-25
#
# DESCRIPTION:
# Calculates survey weights using industry-standard methods:
#   - Design weights for stratified samples
#   - Rim weights (raking) using survey::calibrate()
#
# USAGE:
#   result <- run_weighting("path/to/Weight_Config.xlsx")
#   weighted_data <- result$data
#
# Or from command line:
#   Rscript run_weighting.R path/to/Weight_Config.xlsx
#
# DEPENDENCIES:
#   Required: readxl, dplyr, openxlsx, survey
#   Optional: haven (for SPSS files)
#
# ==============================================================================

SCRIPT_VERSION <- "2.0"

# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

#' Get Module Directory
#'
#' Returns the directory containing this script.
#' @keywords internal
get_module_dir <- function() {
  # Try multiple methods to find module directory
  if (sys.nframe() > 0 && !is.null(sys.frame(1)$ofile)) {
    return(dirname(sys.frame(1)$ofile))
  }

  # Fallback: look for this file in common locations
  candidates <- c(
    file.path(getwd(), "modules", "weighting"),
    file.path(dirname(getwd()), "weighting"),
    getwd()
  )

  for (path in candidates) {
    if (file.exists(file.path(path, "run_weighting.R"))) {
      return(path)
    }
  }

  stop("Cannot locate weighting module directory", call. = FALSE)
}

#' Source Module Libraries
#'
#' Sources all library files in the correct order.
#' @keywords internal
source_module_libs <- function(module_dir) {
  lib_dir <- file.path(module_dir, "lib")

  if (!dir.exists(lib_dir)) {
    stop(sprintf(
      "Module library directory not found: %s",
      lib_dir
    ), call. = FALSE)
  }

  # Source in dependency order
  lib_files <- c(
    "00_guard.R",      # TRS guard system - must load first
    "validation.R",
    "config_loader.R",
    "design_weights.R",
    "rim_weights.R",
    "trimming.R",
    "diagnostics.R",
    "output.R"
  )

  for (lib_file in lib_files) {
    lib_path <- file.path(lib_dir, lib_file)
    if (file.exists(lib_path)) {
      source(lib_path, local = FALSE)
    } else {
      warning(sprintf("Library file not found: %s", lib_file), call. = FALSE)
    }
  }
}

#' Check Required Packages
#'
#' Verifies required packages are installed.
#' @keywords internal
check_required_packages <- function() {
  required <- c("readxl", "dplyr", "survey", "openxlsx")

  missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]

  if (length(missing) > 0) {
    stop(sprintf(
      "\nRequired packages not installed: %s\n\nInstall with:\n  install.packages(c(%s))",
      paste(missing, collapse = ", "),
      paste(sprintf('"%s"', missing), collapse = ", ")
    ), call. = FALSE)
  }
}

# ==============================================================================
# MAIN FUNCTION
# ==============================================================================

#' Run Weighting Analysis
#'
#' Main entry point for the weighting module. Calculates survey weights
#' based on configuration file specifications.
#'
#' @param config_file Character, path to Weight_Config.xlsx
#' @param data_file Character, optional override for data file path (NULL = use config)
#' @param return_data Logical, return data frame in result (default: TRUE)
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return List with elements:
#'   \item{data}{Data frame with weight columns added}
#'   \item{diagnostics}{List of diagnostic results per weight}
#'   \item{config}{Parsed configuration}
#'   \item{weight_names}{Character vector of weight column names created}
#' @export
#'
#' @examples
#' result <- run_weighting("project/Weight_Config.xlsx")
#' weighted_data <- result$data
#'
#' # Access diagnostics
#' result$diagnostics[["population_weight"]]
run_weighting <- function(config_file,
                          data_file = NULL,
                          return_data = TRUE,
                          verbose = TRUE) {

  start_time <- Sys.time()

  # ============================================================================
  # Initialization
  # ============================================================================
  if (verbose) {
    cat("\n")
    cat(strrep("=", 80), "\n")
    cat("TURAS WEIGHTING MODULE v", SCRIPT_VERSION, "\n", sep = "")
    cat(strrep("=", 80), "\n")
    cat("Started: ", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n")
  }

  # Check packages
  check_required_packages()

  # Source module libraries if not already loaded
  if (!exists("load_weighting_config", mode = "function")) {
    module_dir <- get_module_dir()
    source_module_libs(module_dir)
  }

  # Load shared utilities if available
  tryCatch({
    turas_root <- find_turas_root()
    shared_import <- file.path(turas_root, "modules", "shared", "lib", "import_all.R")
    if (file.exists(shared_import)) {
      source(shared_import)
    }
  }, error = function(e) {
    # Shared utilities not available - continue without them
  })

  # ============================================================================
  # Load Configuration
  # ============================================================================
  config <- load_weighting_config(config_file, verbose = verbose)

  # ============================================================================
  # Load Survey Data
  # ============================================================================
  # Use override data_file if provided, otherwise use config
  if (!is.null(data_file)) {
    data_path <- data_file
  } else {
    data_path <- config$general$data_file_resolved
  }

  if (verbose) {
    message("\nLoading survey data...")
    message("  File: ", basename(data_path))
  }

  # Check file exists
  if (!file.exists(data_path)) {
    stop(sprintf(
      "\nData file not found: %s\n\nPlease check:\n  1. File path in configuration\n  2. File exists at specified location",
      data_path
    ), call. = FALSE)
  }

  # Load data based on file type
  file_ext <- tolower(tools::file_ext(data_path))

  data <- tryCatch({
    if (file_ext %in% c("xlsx", "xls")) {
      readxl::read_excel(data_path)
    } else if (file_ext == "csv") {
      read.csv(data_path, stringsAsFactors = FALSE)
    } else if (file_ext == "sav") {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required to read SPSS files. Install with: install.packages('haven')",
             call. = FALSE)
      }
      haven::read_sav(data_path)
    } else {
      stop(sprintf("Unsupported data file format: .%s", file_ext), call. = FALSE)
    }
  }, error = function(e) {
    stop(sprintf(
      "Failed to load data file: %s\n\nError: %s",
      data_path, conditionMessage(e)
    ), call. = FALSE)
  })

  data <- as.data.frame(data)

  if (verbose) {
    message("  Rows: ", nrow(data))
    message("  Columns: ", ncol(data))
  }

  # ============================================================================
  # Calculate Weights
  # ============================================================================
  weight_specs <- config$weight_specifications
  weight_names <- as.character(weight_specs$weight_name)
  weight_results <- list()

  if (verbose) {
    message("\n", strrep("=", 80))
    message("CALCULATING WEIGHTS")
    message(strrep("=", 80))
  }

  for (i in seq_len(nrow(weight_specs))) {
    spec <- as.list(weight_specs[i, ])
    weight_name <- spec$weight_name
    method <- tolower(spec$method)

    if (verbose) {
      message("\n", strrep("-", 70))
      message("Processing: ", weight_name, " (", method, ")")
      message(strrep("-", 70))
    }

    result <- list()

    # Calculate based on method
    if (method == "design") {
      result$design_result <- calculate_design_weights_from_config(
        data = data,
        config = config,
        weight_name = weight_name,
        verbose = verbose
      )
      weights <- result$design_result$weights

      if (verbose) {
        print_design_summary(result$design_result, weight_name)
      }

    } else if (method == "rim") {
      result$rim_result <- calculate_rim_weights_from_config(
        data = data,
        config = config,
        weight_name = weight_name,
        verbose = verbose
      )
      weights <- result$rim_result$weights

      if (verbose) {
        print_rim_summary(result$rim_result, weight_name)
      }

    } else {
      stop(sprintf("Unknown weighting method: %s", method), call. = FALSE)
    }

    # Apply trimming if configured
    trimming_result <- apply_trimming_from_config(
      weights = weights,
      spec = spec,
      verbose = verbose
    )

    if (trimming_result$trimming_applied) {
      weights <- trimming_result$weights
      result$trimming_result <- trimming_result
    }

    # Generate diagnostics
    result$diagnostics <- diagnose_weights(
      weights = weights,
      label = weight_name,
      rim_result = result$rim_result,
      trimming_result = trimming_result,
      verbose = verbose
    )

    # Store final weights
    result$weights <- weights

    # Add to data
    data[[weight_name]] <- weights

    weight_results[[weight_name]] <- result
  }

  # ============================================================================
  # Write Outputs
  # ============================================================================
  output_file <- NULL
  diagnostics_file <- NULL

  # Write data if output file specified
  if (!is.null(config$general$output_file_resolved)) {
    output_file <- config$general$output_file_resolved
    write_weighted_data(data, output_file, verbose = verbose)
  }

  # Save diagnostics if configured
  if (config$general$save_diagnostics && !is.null(config$general$diagnostics_file_resolved)) {
    diagnostics_file <- config$general$diagnostics_file_resolved

    # Compile full results for report
    full_results <- list(
      data = data,
      config = config,
      weight_names = weight_names,
      weight_results = weight_results
    )

    generate_weighting_report(full_results, diagnostics_file, verbose = verbose)
  }

  # ============================================================================
  # Build Return Value
  # ============================================================================
  result <- list(
    data = if (return_data) data else NULL,
    weight_names = weight_names,
    weight_results = weight_results,
    config = config,
    output_file = output_file,
    diagnostics_file = diagnostics_file
  )

  # Print summary
  if (verbose) {
    print_run_summary(result)

    elapsed <- difftime(Sys.time(), start_time, units = "secs")
    cat("Completed in ", round(elapsed, 1), " seconds\n\n", sep = "")
  }

  return(result)
}

# ==============================================================================
# COMMAND LINE INTERFACE
# ==============================================================================

#' Run from Command Line
#'
#' Handles command line execution of the weighting module.
#' @keywords internal
run_cli <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) < 1) {
    cat("\nTURAS Weighting Module v", SCRIPT_VERSION, "\n\n", sep = "")
    cat("Usage: Rscript run_weighting.R <config_file> [options]\n\n")
    cat("Arguments:\n")
    cat("  config_file    Path to Weight_Config.xlsx\n\n")
    cat("Options:\n")
    cat("  --quiet        Suppress progress messages\n")
    cat("  --no-output    Don't write output file (return data only)\n")
    cat("\nExample:\n")
    cat("  Rscript run_weighting.R project/Weight_Config.xlsx\n\n")
    quit(status = 1)
  }

  config_file <- args[1]
  verbose <- !("--quiet" %in% args)

  tryCatch({
    result <- run_weighting(
      config_file = config_file,
      verbose = verbose
    )

    # Exit successfully
    quit(status = 0)

  }, error = function(e) {
    message("\nERROR: ", conditionMessage(e))
    quit(status = 1)
  })
}

# Run CLI if executed directly (but not if being sourced by GUI launcher)
if (!interactive() && identical(environment(), globalenv()) &&
    (!exists("TURAS_LAUNCHER_ACTIVE") || !TURAS_LAUNCHER_ACTIVE)) {
  run_cli()
}

# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

#' Quick Design Weight Calculation
#'
#' Simplified interface for design weight calculation without full config.
#'
#' @param data Data frame, survey data
#' @param stratum_variable Character, stratification column name
#' @param population_sizes Named vector, stratum -> population count
#' @param weight_name Character, name for weight column (default: "weight")
#' @param normalize Logical, normalize to mean=1 (default: TRUE)
#' @return Data frame with weight column added
#' @export
#'
#' @examples
#' pop <- c("Small" = 5000, "Medium" = 2000, "Large" = 500)
#' weighted_data <- quick_design_weight(survey, "size", pop)
quick_design_weight <- function(data,
                                stratum_variable,
                                population_sizes,
                                weight_name = "weight",
                                normalize = TRUE) {

  # Source libs if needed
  if (!exists("calculate_design_weights", mode = "function")) {
    module_dir <- get_module_dir()
    source_module_libs(module_dir)
  }

  weights <- calculate_design_weights(
    data = data,
    stratum_variable = stratum_variable,
    population_sizes = population_sizes,
    verbose = FALSE
  )

  if (normalize) {
    weights <- normalize_design_weights(weights)
  }

  data[[weight_name]] <- weights
  return(data)
}

#' Quick Rim Weight Calculation
#'
#' Simplified interface for rim weight calculation without full config.
#'
#' @param data Data frame, survey data
#' @param targets Named list, variable -> named vector of target proportions (0-1)
#' @param weight_name Character, name for weight column (default: "weight")
#' @param cap Numeric, optional weight cap (default: NULL)
#' @return Data frame with weight column added
#' @export
#'
#' @examples
#' targets <- list(
#'   Gender = c("Male" = 0.48, "Female" = 0.52),
#'   Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
#' )
#' weighted_data <- quick_rim_weight(survey, targets)
quick_rim_weight <- function(data,
                             targets,
                             weight_name = "weight",
                             cap = NULL) {

  # Source libs if needed
  if (!exists("calculate_rim_weights", mode = "function")) {
    module_dir <- get_module_dir()
    source_module_libs(module_dir)
  }

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    cap_weights = cap,
    verbose = FALSE
  )

  data[[weight_name]] <- result$weights
  return(data)
}
