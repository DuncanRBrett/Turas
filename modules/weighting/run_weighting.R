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

  # TRS infrastructure not yet loaded — use formatted console error
  cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
  cat("│ Code: IO_MODULE_DIR_NOT_FOUND\n")
  cat("│ Cannot locate weighting module directory.\n")
  cat("│ Fix: Run from the Turas root or weighting module directory.\n")
  cat("└───────────────────────────────────────────────────────┘\n\n")
  stop("Cannot locate weighting module directory.", call. = FALSE)
}

#' Source Module Libraries
#'
#' Sources all library files in the correct order.
#' @keywords internal
source_module_libs <- function(module_dir) {
  lib_dir <- file.path(module_dir, "lib")

  if (!dir.exists(lib_dir)) {
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Code: IO_MODULE_LIB_NOT_FOUND\n")
    cat(sprintf("│ Module library directory not found: %s\n", lib_dir))
    cat("│ Fix: Ensure the Turas installation is complete.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    stop(paste0("Module library directory not found: ", lib_dir), call. = FALSE)
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
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Code: IO_SHARED_NOT_FOUND\n")
    cat("│ Cannot find Turas shared infrastructure (modules/shared/).\n")
    cat("│ Fix: Run from the Turas root directory or set TURAS_HOME.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    stop("Cannot find Turas shared infrastructure.", call. = FALSE)
  }

  shared_import <- file.path(turas_root, "modules", "shared", "lib", "import_all.R")
  if (!file.exists(shared_import)) {
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Code: IO_IMPORT_ALL_NOT_FOUND\n")
    cat(sprintf("│ Shared infrastructure file not found: %s\n", shared_import))
    cat("│ Fix: Verify modules/shared/lib/import_all.R exists.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    stop(paste0("Shared infrastructure file not found: ", shared_import), call. = FALSE)
  }

  source(shared_import, local = FALSE)

  # Source stats pack writer (not included in import_all.R)
  stats_pack_path <- file.path(turas_root, "modules", "shared", "lib", "stats_pack_writer.R")
  if (file.exists(stats_pack_path)) {
    tryCatch(
      source(stats_pack_path, local = FALSE),
      error = function(e) {
        message(sprintf("[TRS INFO] WEIGHTING: Could not load stats_pack_writer.R: %s", e$message))
      }
    )
  }

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
                          progress_callback = NULL,
                          html_report = NULL) {

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

  # Apply GUI overrides (html_report parameter takes precedence over config file)
  if (!is.null(html_report)) {
    config$general$html_report <- isTRUE(html_report)
    if (isTRUE(html_report) && is.null(config$general$html_report_file_resolved)) {
      # Auto-generate HTML report path from output_file or config_file
      base_path <- config$general$output_file_resolved %||% config_file
      config$general$html_report_file_resolved <- sub(
        "\\.[^.]+$", "_weighting_report.html", base_path
      )
    }
  }

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
      read.csv(data_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
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

  # Resolve id_column: if not set in config, use first column of data
  if (is.null(config$general$id_column)) {
    config$general$id_column <- names(data)[1]
    if (verbose) {
      message("  ID column: ", config$general$id_column, " (auto-detected: first column)")
    }
  } else {
    if (verbose) {
      message("  ID column: ", config$general$id_column)
    }
  }

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

  # Write weight lookup file (ID + weight columns) if output file specified
  if (!is.null(config$general$output_file_resolved)) {
    output_file <- config$general$output_file_resolved
    write_weighted_data(data, output_file,
                        id_column = config$general$id_column,
                        weight_names = weight_names,
                        verbose = verbose)
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
          accent_colour = config$general$accent_colour %||% "#2aa198",
          researcher_name = config$general$researcher_name,
          client_name = config$general$client_name,
          logo_file = config$general$logo_file_resolved
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
  # Generate Stats Pack (Optional)
  # ============================================================================
  stats_pack_file <- NULL
  generate_stats_pack_flag <- isTRUE(
    toupper(config$general$generate_stats_pack %||% "Y") == "Y"
  ) || isTRUE(getOption("turas.generate_stats_pack", FALSE))

  if (generate_stats_pack_flag) {
    update_progress(0.93, "Generating stats pack...")
    stats_pack_file <- generate_weighting_stats_pack(
      config       = config,
      data         = data,
      weight_names = weight_names,
      weight_results = weight_results,
      run_state    = run_state,
      start_time   = proc.time(),
      verbose      = verbose
    )
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
    stats_pack_file = stats_pack_file,
    run_state = run_result
  ))
}

# ==============================================================================
# STATS PACK HELPER
# ==============================================================================

#' Generate Weighting Stats Pack
#'
#' Builds the diagnostic payload from weighting results and writes the stats
#' pack Excel workbook alongside the main output.
#'
#' @keywords internal
generate_weighting_stats_pack <- function(config, data, weight_names,
                                          weight_results, run_state,
                                          start_time, verbose = TRUE) {

  if (!exists("turas_write_stats_pack", mode = "function")) {
    if (verbose) message("[TRS INFO] WEIGHTING: Stats pack writer not loaded - skipping")
    return(NULL)
  }

  # Output path: derive from output file or data file
  main_out <- config$general$output_file_resolved %||%
              config$general$data_file_resolved %||% "weighting_output.xlsx"
  output_path <- sub("(\\.xlsx|\\.csv|\\.sav)$", "_stats_pack.xlsx", main_out,
                     ignore.case = TRUE)
  if (identical(output_path, main_out)) {
    output_path <- paste0(tools::file_path_sans_ext(main_out), "_stats_pack.xlsx")
  }

  # Data receipt
  data_receipt <- list(
    file_name = basename(config$general$data_file_resolved %||% "unknown"),
    n_rows    = nrow(data),
    n_cols    = ncol(data)
  )

  # Count unique respondents excluded (NA or zero weight in ANY weight column)
  n_excluded <- if (length(weight_names) > 0) {
    excluded_mask <- Reduce(`|`, lapply(weight_names, function(wn) {
      w <- data[[wn]]
      is.na(w) | w == 0
    }))
    sum(excluded_mask)
  } else 0L

  data_used <- list(
    n_respondents = nrow(data),
    n_excluded    = n_excluded
  )

  # Build per-weight assumption rows
  weight_specs <- config$weight_specifications
  weight_detail_parts <- character(0)
  for (wn in weight_names) {
    wr <- weight_results[[wn]]
    if (is.null(wr)) next
    spec_row <- if (!is.null(weight_specs)) {
      weight_specs[tolower(weight_specs$weight_name) == tolower(wn), , drop = FALSE]
    } else NULL
    method <- if (!is.null(spec_row) && nrow(spec_row) > 0) {
      as.character(spec_row$method[1])
    } else "unknown"
    weight_detail_parts <- c(weight_detail_parts,
                             sprintf("%s (%s)", wn, method))
  }

  # Per-weight diagnostics for stats pack (report ALL weights, not just first)
  per_weight_details <- list()
  for (wn in weight_names) {
    wr <- weight_results[[wn]]
    if (is.null(wr) || is.null(wr$diagnostics)) next
    diag <- wr$diagnostics
    per_weight_details[[wn]] <- list(
      effective_n = diag$effective_sample$effective_n %||% NA,
      deff = diag$effective_sample$design_effect %||% NA,
      efficiency = diag$effective_sample$efficiency %||% NA,
      quality = diag$quality$status %||% "—"
    )
  }

  # Summary effective N and DEFF (from first weight with valid diagnostics)
  eff_n_val <- NA
  deff_val <- NA
  for (wn in weight_names) {
    wr <- weight_results[[wn]]
    if (!is.null(wr) && !is.null(wr$diagnostics)) {
      eff_n_val <- wr$diagnostics$effective_sample$effective_n %||% NA
      deff_val <- wr$diagnostics$effective_sample$design_effect %||% NA
      break
    }
  }

  # Convergence info (from first rim result if present)
  conv_tol <- NA
  conv_iters <- NA
  for (wn in weight_names) {
    wr <- weight_results[[wn]]
    rim <- tryCatch(wr$rim_result, error = function(e) NULL)
    if (!is.null(rim)) {
      conv_tol <- rim$convergence_tolerance %||% NA
      conv_iters <- rim$iterations %||% NA
      break
    }
  }

  # Trimming info (from first trimmed weight)
  trim_str <- "None"
  for (wn in weight_names) {
    wr <- weight_results[[wn]]
    trim <- tryCatch(wr$trimming_result, error = function(e) NULL)
    if (!is.null(trim) && isTRUE(trim$trimming_applied)) {
      lower <- tryCatch(trim$lower_bound %||% NA, error = function(e) NA)
      upper <- tryCatch(trim$upper_bound %||% NA, error = function(e) NA)
      trim_str <- sprintf("Applied — lower: %s, upper: %s",
              if (!is.na(lower)) as.character(lower) else "—",
              if (!is.na(upper)) as.character(upper) else "—")
      break
    }
  }

  # TRS summary
  run_result <- if (!is.null(run_state) && exists("turas_run_state_result", mode = "function")) {
    tryCatch(turas_run_state_result(run_state), error = function(e) NULL)
  } else NULL
  n_events   <- length(run_result$events %||% list())
  n_refusals <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "REFUSE"), logical(1)))
  n_partials <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "PARTIAL"), logical(1)))
  trs_summary <- if (n_events == 0) {
    "No events — ran cleanly"
  } else {
    parts <- character(0)
    if (n_refusals > 0) parts <- c(parts, sprintf("%d refusal(s)", n_refusals))
    if (n_partials > 0) parts <- c(parts, sprintf("%d partial(s)", n_partials))
    remainder <- n_events - n_refusals - n_partials
    if (remainder  > 0) parts <- c(parts, sprintf("%d info event(s)", remainder))
    paste(parts, collapse = ", ")
  }

  # Dominant method string
  methods_used <- if (!is.null(weight_specs)) {
    unique(tolower(as.character(weight_specs$method)))
  } else "unknown"

  rim_method_str <- if ("rim" %in% methods_used || "rake" %in% methods_used) {
    "Iterative Proportional Fitting (survey package)"
  } else NA

  assumptions <- list(
    "Weight Type(s)"              = paste(unique(methods_used), collapse = ", "),
    "Weights Calculated"          = paste(weight_detail_parts, collapse = "; "),
    "Rim weighting"               = if (!is.na(rim_method_str)) rim_method_str else "Not used",
    "Convergence tolerance"       = if (!is.na(conv_tol)) as.character(conv_tol) else "—",
    "Iterations to convergence"   = if (!is.na(conv_iters)) as.character(conv_iters) else "—",
    "Trimming"                    = trim_str,
    "Effective N after weighting" = if (!is.na(eff_n_val)) format(round(eff_n_val), big.mark = ",") else "—",
    "DEFF"                        = if (!is.na(deff_val)) sprintf("%.3f", deff_val) else "—",
    "Per-weight diagnostics"      = paste(vapply(names(per_weight_details), function(wn) {
      d <- per_weight_details[[wn]]
      sprintf("%s: eff_n=%s, DEFF=%s, quality=%s",
              wn,
              if (!is.na(d$effective_n)) format(round(d$effective_n), big.mark = ",") else "—",
              if (!is.na(d$deff)) sprintf("%.3f", d$deff) else "—",
              d$quality)
    }, character(1)), collapse = " | "),
    "TRS Status"                  = run_result$status %||% "PASS",
    "TRS Events"                  = trs_summary
  )

  config_echo <- list(
    general = config$general[setdiff(names(config$general),
                                     c("data_file_resolved", "output_file_resolved",
                                       "diagnostics_file_resolved", "html_report_file_resolved"))]
  )

  duration_secs <- as.numeric(proc.time()["elapsed"] - start_time["elapsed"])

  payload <- list(
    module           = "WEIGHTING",
    project_name     = config$general$project_name   %||% NULL,
    analyst_name     = config$general$researcher_name %||% NULL,
    research_house   = config$general$client_name    %||% NULL,
    run_timestamp    = Sys.time(),
    turas_version    = SCRIPT_VERSION,
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = if (duration_secs > 0 && duration_secs < 86400) duration_secs else NA,
    data_receipt     = data_receipt,
    data_used        = data_used,
    assumptions      = assumptions,
    run_result       = run_result,
    packages         = c("openxlsx", "readxl", "survey", "data.table"),
    config_echo      = config_echo
  )

  result <- turas_write_stats_pack(payload, output_path)

  if (!is.null(result) && verbose) {
    message(sprintf("[TRS INFO] WEIGHTING: Stats pack written: %s", basename(output_path)))
  }

  result
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
