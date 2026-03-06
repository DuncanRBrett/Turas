# ==============================================================================
# TURAS WEIGHTING MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Version: 3.0
# Date: 2026-03-06
#
# DESCRIPTION:
# Calculates survey weights using industry-standard methods:
#   - Design weights for stratified samples
#   - Rim weights (raking) using survey::calibrate()
#   - Cell weights for interlocked distributions
#
# USAGE:
#   result <- run_weighting("path/to/Weight_Config.xlsx")
#   weighted_data <- result$data
#
# Or from command line:
#   Rscript run_weighting.R path/to/Weight_Config.xlsx
#
# DEPENDENCIES:
#   Required: readxl, survey, openxlsx
#   Optional: haven (for SPSS files)
#
# ==============================================================================

SCRIPT_VERSION <- "3.0"

# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

#' Get Module Directory
#'
#' Returns the directory containing this script.
#' @keywords internal
get_module_dir <- function() {
  # Check for explicit override (set by test setup or external caller)
  if (exists("WEIGHTING_MODULE_DIR", envir = .GlobalEnv)) {
    return(get("WEIGHTING_MODULE_DIR", envir = .GlobalEnv))
  }

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

  stop("Cannot locate weighting module directory. Run from the Turas root or weighting module directory.",
       call. = FALSE)
}

#' Source Module Libraries
#'
#' Sources all library files in the correct order.
#' @keywords internal
source_module_libs <- function(module_dir) {
  lib_dir <- file.path(module_dir, "lib")

  if (!dir.exists(lib_dir)) {
    stop(paste0("Module library directory not found: ", lib_dir,
                "\nEnsure the Turas installation is complete and the lib/ directory exists."),
         call. = FALSE)
  }

  # Source in dependency order
  lib_files <- c(
    "00_guard.R",      # TRS guard system - must load first
    "validation.R",
    "config_loader.R",
    "design_weights.R",
    "rim_weights.R",
    "cell_weights.R",
    "trimming.R",
    "diagnostics.R",
    "output.R"
  )

  for (lib_file in lib_files) {
    lib_path <- file.path(lib_dir, lib_file)
    if (file.exists(lib_path)) {
      source(lib_path, local = FALSE)
    }
  }
}

#' Load Shared Infrastructure
#'
#' Loads the shared Turas infrastructure (TRS, logging, utilities).
#' This is mandatory - the module cannot run without shared infrastructure.
#' @keywords internal
load_shared_infrastructure <- function(module_dir) {
  # Find TURAS root by walking up from module directory
  turas_root <- NULL
  check_path <- module_dir
  for (i in 1:5) {
    if (dir.exists(file.path(check_path, "modules", "shared"))) {
      turas_root <- check_path
      break
    }
    check_path <- dirname(check_path)
  }

  if (is.null(turas_root)) {
    stop("Cannot find Turas shared infrastructure (modules/shared/).\n",
         "Run from the Turas root directory or set TURAS_HOME environment variable.",
         call. = FALSE)
  }

  shared_import <- file.path(turas_root, "modules", "shared", "lib", "import_all.R")
  if (!file.exists(shared_import)) {
    stop(paste0("Shared infrastructure file not found: ", shared_import),
         call. = FALSE)
  }

  source(shared_import, local = FALSE)
  return(turas_root)
}

#' Check Required Packages
#'
#' Verifies required packages are installed.
#' @keywords internal
check_required_packages <- function() {
  required <- c("readxl", "survey", "openxlsx")

  missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]

  if (length(missing) > 0) {
    weighting_refuse(
      code = "PKG_MISSING_DEPENDENCY",
      title = "Missing Required Packages",
      problem = paste0("Required packages not installed: ", paste(missing, collapse = ", ")),
      why_it_matters = "The weighting module cannot run without these packages.",
      how_to_fix = paste0("Install with: install.packages(c(",
                          paste(sprintf('"%s"', missing), collapse = ", "), "))")
    )
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
#' @param progress_callback Function, optional callback for progress updates (for GUI).
#'   Called with (value, message) where value is 0-1 and message is status text.
#' @return List with elements:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSE" (via with_refusal_handler)}
#'   \item{data}{Data frame with weight columns added}
#'   \item{weight_names}{Character vector of weight column names created}
#'   \item{weight_results}{List of per-weight results with diagnostics}
#'   \item{config}{Parsed configuration}
#'   \item{output_file}{Path to output data file (if written)}
#'   \item{diagnostics_file}{Path to diagnostics file (if written)}
#'   \item{run_state}{TRS run state result with timing and events}
#' @export
#'
#' @examples
#' \dontrun{
#' result <- run_weighting("project/Weight_Config.xlsx")
#' if (result$status == "PASS") {
#'   weighted_data <- result$data
#' }
#' }
run_weighting <- function(config_file,
                          data_file = NULL,
                          return_data = TRUE,
                          verbose = TRUE,
                          progress_callback = NULL) {

  # Helper to update progress
  update_progress <- function(value, message) {
    if (!is.null(progress_callback) && is.function(progress_callback)) {
      progress_callback(value, message)
    }
  }

  # ============================================================================
  # Initialization: Load shared infrastructure FIRST
  # ============================================================================
  update_progress(0.02, "Loading shared infrastructure...")

  module_dir <- get_module_dir()

  # Only load shared infra if not already available (e.g., in test context)
  if (!exists("turas_refuse", mode = "function")) {
    load_shared_infrastructure(module_dir)
  }

  # Now that shared infra is loaded, source module libs
  if (!exists("load_weighting_config", mode = "function")) {
    source_module_libs(module_dir)
  }

  # Create run state for TRS tracking
  run_state <- turas_run_state_new("WEIGHTING")

  # Print start banner
  if (verbose) {
    turas_print_start_banner("WEIGHTING", SCRIPT_VERSION)
  }

  # Check packages
  update_progress(0.05, "Checking dependencies...")
  check_required_packages()

  # ============================================================================
  # Load Configuration
  # ============================================================================
  update_progress(0.10, "Loading configuration...")
  config <- load_weighting_config(config_file, verbose = verbose)

  # ============================================================================
  # Load Survey Data
  # ============================================================================
  update_progress(0.15, "Loading survey data...")

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
    weighting_refuse(
      code = "IO_DATA_FILE_NOT_FOUND",
      title = "Data File Not Found",
      problem = paste0("Data file not found: ", data_path),
      why_it_matters = "Cannot calculate weights without survey data.",
      how_to_fix = "Check the file path in configuration and ensure the file exists at the specified location."
    )
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
        weighting_refuse(
          code = "PKG_HAVEN_MISSING",
          title = "Package 'haven' Required",
          problem = "Package 'haven' is required to read SPSS files but is not installed.",
          why_it_matters = "Cannot load SPSS (.sav) format data without the haven package.",
          how_to_fix = "Install with: install.packages('haven')"
        )
      }
      haven::read_sav(data_path)
    } else {
      weighting_refuse(
        code = "IO_UNSUPPORTED_FORMAT",
        title = "Unsupported Data File Format",
        problem = paste0("Unsupported data file format: .", file_ext),
        why_it_matters = "The weighting module can only read Excel, CSV, and SPSS files.",
        how_to_fix = "Convert your data to .xlsx, .csv, or .sav format."
      )
    }
  }, error = function(e) {
    weighting_refuse(
      code = "IO_DATA_LOAD_FAILED",
      title = "Failed to Load Data File",
      problem = paste0("Failed to load data file: ", data_path),
      why_it_matters = "Cannot proceed with weighting without valid survey data.",
      how_to_fix = "Check the file is not corrupted and has the correct format.",
      details = conditionMessage(e)
    )
  })

  data <- as.data.frame(data)

  if (verbose) {
    message("  Rows: ", nrow(data))
    message("  Columns: ", ncol(data))
  }

  # ============================================================================
  # Calculate Weights
  # ============================================================================
  update_progress(0.20, "Preparing weight calculations...")

  weight_specs <- config$weight_specifications
  weight_names <- as.character(weight_specs$weight_name)
  weight_results <- list()
  n_weights <- nrow(weight_specs)

  if (verbose) {
    message("\n", strrep("=", 80))
    message("CALCULATING WEIGHTS")
    message(strrep("=", 80))
  }

  for (i in seq_len(nrow(weight_specs))) {
    spec <- as.list(weight_specs[i, ])
    weight_name <- spec$weight_name
    method <- tolower(spec$method)

    # Progress: distribute 0.20 to 0.80 across weights
    weight_progress <- 0.20 + (0.60 * (i - 1) / n_weights)
    update_progress(weight_progress, sprintf("Calculating weight %d/%d: %s (%s)...",
                                              i, n_weights, weight_name, method))

    if (verbose) {
      message("\n", strrep("-", 70))
      message("Processing: ", weight_name, " (", method, ")")
      message(strrep("-", 70))
    }

    result <- tryCatch({
      res <- list()

      # Calculate based on method
      if (method == "design") {
        res$design_result <- calculate_design_weights_from_config(
          data = data,
          config = config,
          weight_name = weight_name,
          verbose = verbose
        )
        weights <- res$design_result$weights

        if (verbose) {
          print_design_summary(res$design_result, weight_name)
        }

      } else if (method %in% c("rim", "rake")) {
        res$rim_result <- calculate_rim_weights_from_config(
          data = data,
          config = config,
          weight_name = weight_name,
          verbose = verbose
        )
        weights <- res$rim_result$weights

        if (verbose) {
          print_rim_summary(res$rim_result, weight_name)
        }

      } else if (method == "cell") {
        if (!exists("calculate_cell_weights_from_config", mode = "function")) {
          weighting_refuse(
            code = "FEATURE_CELL_NOT_LOADED",
            title = "Cell Weighting Not Available",
            problem = "Cell weighting library (cell_weights.R) is not loaded.",
            why_it_matters = "Cannot calculate cell weights without the cell weighting library.",
            how_to_fix = "Ensure modules/weighting/lib/cell_weights.R exists."
          )
        }
        res$cell_result <- calculate_cell_weights_from_config(
          data = data,
          config = config,
          weight_name = weight_name,
          verbose = verbose
        )
        weights <- res$cell_result$weights

        if (verbose && exists("print_cell_summary", mode = "function")) {
          print_cell_summary(res$cell_result, weight_name)
        }

      } else {
        weighting_refuse(
          code = "CFG_UNKNOWN_METHOD",
          title = "Unknown Weighting Method",
          problem = paste0("Unknown weighting method: ", method),
          why_it_matters = "Cannot calculate weights with an unrecognized method.",
          how_to_fix = "Use one of: 'design', 'rim', 'rake', or 'cell' as the weighting method."
        )
      }

      # Apply trimming if configured
      trimming_result <- apply_trimming_from_config(
        weights = weights,
        spec = spec,
        verbose = verbose
      )

      if (trimming_result$trimming_applied) {
        weights <- trimming_result$weights
        res$trimming_result <- trimming_result
      }

      # Generate diagnostics
      res$diagnostics <- diagnose_weights(
        weights = weights,
        label = weight_name,
        rim_result = res$rim_result,
        trimming_result = trimming_result,
        verbose = verbose
      )

      # Store final weights
      res$weights <- weights
      res

    }, error = function(e) {
      # If this is a turas_refusal, re-throw it
      if (inherits(e, "turas_refusal")) {
        stop(e)
      }

      # Non-refusal error: log as PARTIAL if other weights remain
      if (n_weights > 1) {
        turas_run_state_partial(
          run_state,
          code = "MODEL_WEIGHT_FAILED",
          title = paste0("Weight '", weight_name, "' calculation failed"),
          problem = conditionMessage(e),
          fix = "Check configuration and data for this weight specification.",
          stage = "weight_calculation"
        )
        return(NULL)
      } else {
        # Single weight - re-throw as this is fatal
        stop(e)
      }
    })

    if (is.null(result)) {
      # Weight failed but other weights may succeed (PARTIAL mode)
      weight_results[[weight_name]] <- list(
        weights = rep(NA_real_, nrow(data)),
        diagnostics = NULL,
        error = TRUE
      )
      data[[weight_name]] <- NA_real_
      next
    }

    # Add to data
    data[[weight_name]] <- result$weights
    weight_results[[weight_name]] <- result
  }

  # ============================================================================
  # Write Outputs
  # ============================================================================
  update_progress(0.85, "Writing output files...")

  output_file <- NULL
  diagnostics_file <- NULL

  # Write data if output file specified
  if (!is.null(config$general$output_file_resolved)) {
    output_file <- config$general$output_file_resolved
    write_weighted_data(data, output_file, verbose = verbose)
  }

  update_progress(0.90, "Generating diagnostics report...")

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

    generate_weighting_report(full_results, diagnostics_file,
                              run_state = run_state, verbose = verbose)
  }

  # ============================================================================
  # Generate HTML Report (if configured)
  # ============================================================================
  html_report_file <- NULL

  if (isTRUE(config$general$html_report) && !is.null(config$general$html_report_file_resolved)) {
    update_progress(0.92, "Generating HTML report...")

    # Source HTML report orchestrator
    html_report_main <- file.path(module_dir, "lib", "html_report", "99_html_report_main.R")
    if (file.exists(html_report_main)) {
      # Set lib dir for JS file resolution
      assign(".weighting_lib_dir", file.path(module_dir, "lib"), envir = globalenv())

      tryCatch({
        source(html_report_main, local = FALSE)

        full_results <- list(
          data = data,
          config = config,
          weight_names = weight_names,
          weight_results = weight_results
        )

        html_config <- list(
          brand_colour = config$general$brand_colour %||% "#1e3a5f",
          accent_colour = config$general$accent_colour %||% "#2aa198"
        )

        html_result <- generate_weighting_html_report(
          weighting_results = full_results,
          output_path = config$general$html_report_file_resolved,
          config = html_config
        )

        if (html_result$status == "PASS") {
          html_report_file <- html_result$output_file
        } else {
          if (verbose) {
            cat("\n  [WARNING] HTML report generation failed:", html_result$message, "\n")
          }
          turas_run_state_partial(
            run_state,
            code = "IO_HTML_REPORT_FAILED",
            title = "HTML report generation failed",
            problem = html_result$message %||% "Unknown error",
            fix = "Check HTML report configuration and htmltools package",
            stage = "html_report"
          )
        }
      }, error = function(e) {
        if (verbose) {
          cat("\n  [WARNING] HTML report generation error:", conditionMessage(e), "\n")
        }
        turas_run_state_partial(
          run_state,
          code = "IO_HTML_REPORT_ERROR",
          title = "HTML report generation error",
          problem = conditionMessage(e),
          fix = "Check that htmltools is installed and html_report/ directory is complete",
          stage = "html_report"
        )
      })
    } else {
      if (verbose) {
        cat("\n  [WARNING] HTML report files not found at:", html_report_main, "\n")
      }
    }
  }

  # ============================================================================
  # Build Return Value
  # ============================================================================
  update_progress(0.95, "Finalizing results...")

  # Get run state result
  run_result <- turas_run_state_result(run_state)

  # Print summary
  if (verbose) {
    full_result <- list(
      data = data,
      weight_names = weight_names,
      weight_results = weight_results,
      config = config,
      output_file = output_file,
      diagnostics_file = diagnostics_file
    )
    print_run_summary(full_result)
    turas_print_final_banner(run_result)
  }

  update_progress(1.0, "Complete!")

  return(list(
    status = run_result$status,
    data = if (return_data) data else NULL,
    weight_names = weight_names,
    weight_results = weight_results,
    config = config,
    output_file = output_file,
    diagnostics_file = diagnostics_file,
    html_report_file = html_report_file,
    run_state = run_result
  ))
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

  result <- with_refusal_handler({
    run_weighting(
      config_file = config_file,
      verbose = verbose
    )
  }, module = "WEIGHTING")

  # Exit with appropriate code
  if (is_refusal(result) || is_error(result)) {
    quit(status = 1)
  }
  quit(status = 0)
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
#' \dontrun{
#' pop <- c("Small" = 5000, "Medium" = 2000, "Large" = 500)
#' weighted_data <- quick_design_weight(survey, "size", pop)
#' }
quick_design_weight <- function(data,
                                stratum_variable,
                                population_sizes,
                                weight_name = "weight",
                                normalize = TRUE) {

  # Source libs if needed
  if (!exists("calculate_design_weights", mode = "function")) {
    module_dir <- get_module_dir()
    load_shared_infrastructure(module_dir)
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
#' \dontrun{
#' targets <- list(
#'   Gender = c("Male" = 0.48, "Female" = 0.52),
#'   Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
#' )
#' weighted_data <- quick_rim_weight(survey, targets)
#' }
quick_rim_weight <- function(data,
                             targets,
                             weight_name = "weight",
                             cap = NULL) {

  # Source libs if needed
  if (!exists("calculate_rim_weights", mode = "function")) {
    module_dir <- get_module_dir()
    load_shared_infrastructure(module_dir)
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
