# ==============================================================================
# TURAS CONJOINT ANALYSIS MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Conjoint Analysis
# Purpose: World-class conjoint analysis with HB, LC, WTP, HTML output
# Version: 3.0.0
# Date: 2026-03-10
#
# CAPABILITIES (v3.0.0):
#   - Choice-based conjoint (MNL via mlogit/clogit)
#   - Hierarchical Bayes individual-level utilities (bayesm)
#   - Latent Class Analysis for preference segmentation
#   - Willingness to Pay estimation with CIs
#   - Product optimization (exhaustive + greedy)
#   - Source of volume and demand curves
#   - Interactive HTML analysis report
#   - Standalone HTML market simulator
#   - Config-driven interaction effects
#   - Best-worst scaling (sequential/simultaneous)
#   - Alchemer CBC direct import
#
# ==============================================================================

# ==============================================================================
# TRS GUARD LAYER (must be sourced FIRST — before package checks that use conjoint_refuse)
# ==============================================================================

# Source TRS guard layer for refusal handling
.get_guard_dir <- function() {
  dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "")
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    wd <- getwd()
    if (file.exists(file.path(wd, "modules/conjoint/R/00_guard.R"))) {
      return(file.path(wd, "modules/conjoint/R"))
    }
  }
  return(dir)
}

.guard_path <- file.path(.get_guard_dir(), "00_guard.R")
if (file.exists(.guard_path)) {
  source(.guard_path)
}

# ==============================================================================
# TRS INFRASTRUCTURE (TRS v1.0)
# ==============================================================================

# Source TRS run state management
.source_trs_infrastructure <- function() {
  base_dir <- .get_guard_dir()

  # Try multiple paths to find shared/lib
  possible_paths <- c(
    file.path(base_dir, "..", "..", "shared", "lib"),
    file.path(base_dir, "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    file.path(getwd(), "..", "shared", "lib")
  )

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R",
                 "stats_pack_writer.R")

  for (shared_lib in possible_paths) {
    if (dir.exists(shared_lib)) {
      for (f in trs_files) {
        fpath <- file.path(shared_lib, f)
        if (file.exists(fpath)) {
          source(fpath)
        }
      }
      break
    }
  }
}

tryCatch({
  .source_trs_infrastructure()
}, error = function(e) {
  message(sprintf("[TRS INFO] CONJ_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# ==============================================================================
# LOAD REQUIRED PACKAGES (after guard is available for conjoint_refuse)
# ==============================================================================

suppressPackageStartupMessages({
  # Data manipulation
  if (!require(dplyr, quietly = TRUE)) {
    if (exists("conjoint_refuse", mode = "function")) {
      conjoint_refuse(
        code = "PKG_DPLYR_MISSING",
        title = "Required Package Not Installed",
        problem = "Package 'dplyr' is required but not installed.",
        why_it_matters = "The Conjoint module relies on dplyr for data manipulation operations.",
        how_to_fix = "Install the package with: install.packages('dplyr')"
      )
    } else {
      cat("\n=== TURAS ERROR ===\nPackage 'dplyr' is required but not installed.\nFix: install.packages('dplyr')\n==================\n")
      return(list(status = "REFUSED", code = "PKG_DPLYR_MISSING",
                  message = "Required package 'dplyr' is not installed.",
                  how_to_fix = "Install with: install.packages('dplyr')"))
    }
  }

  # Excel I/O
  if (!require(openxlsx, quietly = TRUE)) {
    if (exists("conjoint_refuse", mode = "function")) {
      conjoint_refuse(
        code = "PKG_OPENXLSX_MISSING",
        title = "Required Package Not Installed",
        problem = "Package 'openxlsx' is required but not installed.",
        why_it_matters = "The Conjoint module requires openxlsx to read configuration files and write output workbooks.",
        how_to_fix = "Install the package with: install.packages('openxlsx')"
      )
    } else {
      cat("\n=== TURAS ERROR ===\nPackage 'openxlsx' is required but not installed.\nFix: install.packages('openxlsx')\n==================\n")
      return(list(status = "REFUSED", code = "PKG_OPENXLSX_MISSING",
                  message = "Required package 'openxlsx' is not installed.",
                  how_to_fix = "Install with: install.packages('openxlsx')"))
    }
  }

  # Choice modeling (optional — checked at estimation time)
  if (!require(mlogit, quietly = TRUE)) {
    message("[TRS INFO] CONJ_PKG_MLOGIT_MISSING: Package 'mlogit' not found - install with: install.packages('mlogit')")
  }

  # Data indexing for mlogit (required for mlogit >= 1.1-0)
  if (!require(dfidx, quietly = TRUE)) {
    message("[TRS INFO] CONJ_PKG_DFIDX_MISSING: Package 'dfidx' not found - install with: install.packages('dfidx')")
  }

  # Fallback estimation
  if (!require(survival, quietly = TRUE)) {
    message("[TRS INFO] CONJ_PKG_SURVIVAL_MISSING: Package 'survival' not found - install with: install.packages('survival')")
  }
})

# ==============================================================================
# LOAD MODULE COMPONENTS
# ==============================================================================

# Get the directory where this script is located
.conjoint_module_dir <- tryCatch({

  # Strategy: walk the source frame stack to find the frame that sourced THIS file.
  # This is robust even when called via nested source() (e.g., run_demo.R → 00_main.R).
  dir <- ""
  for (i in seq_len(sys.nframe())) {
    ofile <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(ofile) && grepl("00_main\\.R$", ofile)) {
      dir <- dirname(ofile)
      break
    }
  }

  # Fallback 1: getSrcDirectory (works in simple source() contexts)
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    dir <- tryCatch(utils::getSrcDirectory(function() {}), error = function(e) "")
    # Validate it actually points to conjoint/R
    if (!is.null(dir) && nzchar(dir) && !file.exists(file.path(dir, "99_helpers.R"))) {
      dir <- ""  # wrong directory, discard
    }
  }

  # Fallback 2: working directory based detection
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    wd <- getwd()
    if (file.exists(file.path(wd, "modules/conjoint/R/99_helpers.R"))) {
      dir <- file.path(wd, "modules/conjoint/R")
    } else if (basename(dirname(wd)) == "conjoint" && basename(wd) == "R") {
      dir <- wd
    } else if (basename(wd) == "conjoint") {
      dir <- file.path(wd, "R")
    } else {
      dir <- file.path(wd, "modules/conjoint/R")
    }
  }
  dir
}, error = function(e) {
  file.path(getwd(), "modules/conjoint/R")
})

# Validate the directory exists
if (!dir.exists(.conjoint_module_dir)) {
  conjoint_refuse(
    code = "IO_MODULE_DIR_NOT_FOUND",
    title = "Module Directory Not Found",
    problem = sprintf("Could not locate conjoint module directory at: %s", .conjoint_module_dir),
    why_it_matters = "The module cannot load required component files without access to its directory.",
    how_to_fix = c(
      sprintf("Current working directory: %s", getwd()),
      "Set your working directory to the Turas root folder",
      "Or ensure the conjoint module is properly installed"
    )
  )
}

# Source all component files in order
source(file.path(.conjoint_module_dir, "99_helpers.R"))      # Helper functions (must be first)
source(file.path(.conjoint_module_dir, "00_preflight.R"))    # Pre-flight checks
source(file.path(.conjoint_module_dir, "01_config.R"))       # Configuration loading
source(file.path(.conjoint_module_dir, "05_alchemer_import.R"))  # Alchemer data import (NEW)
source(file.path(.conjoint_module_dir, "02_data.R"))         # Data loading and validation
source(file.path(.conjoint_module_dir, "03_estimation.R"))   # Model estimation
source(file.path(.conjoint_module_dir, "04_utilities.R"))    # Utilities calculation
source(file.path(.conjoint_module_dir, "05_simulator.R"))    # Market simulator functions
source(file.path(.conjoint_module_dir, "07_output.R"))       # Output generation
source(file.path(.conjoint_module_dir, "08_market_simulator.R"))  # Excel simulator
source(file.path(.conjoint_module_dir, "09_none_handling.R"))     # None option handling

# Optional advanced features (load if needed)
if (file.exists(file.path(.conjoint_module_dir, "06_interactions.R"))) {
  source(file.path(.conjoint_module_dir, "06_interactions.R"))
}
if (file.exists(file.path(.conjoint_module_dir, "10_best_worst.R"))) {
  source(file.path(.conjoint_module_dir, "10_best_worst.R"))
}
if (file.exists(file.path(.conjoint_module_dir, "11_hierarchical_bayes.R"))) {
  source(file.path(.conjoint_module_dir, "11_hierarchical_bayes.R"))
}
if (file.exists(file.path(.conjoint_module_dir, "12_config_template.R"))) {
  source(file.path(.conjoint_module_dir, "12_config_template.R"))
}
if (file.exists(file.path(.conjoint_module_dir, "13_latent_class.R"))) {
  source(file.path(.conjoint_module_dir, "13_latent_class.R"))
}
if (file.exists(file.path(.conjoint_module_dir, "14_willingness_to_pay.R"))) {
  source(file.path(.conjoint_module_dir, "14_willingness_to_pay.R"))
}
if (file.exists(file.path(.conjoint_module_dir, "15_product_optimizer.R"))) {
  source(file.path(.conjoint_module_dir, "15_product_optimizer.R"))
}

if (file.exists(file.path(.conjoint_module_dir, "16_tabs_export.R"))) {
  source(file.path(.conjoint_module_dir, "16_tabs_export.R"))
}

if (file.exists(file.path(.conjoint_module_dir, "17_v2_island.R"))) {
  source(file.path(.conjoint_module_dir, "17_v2_island.R"))
}

# Standalone market simulator (lazy-loaded).
# The combined HTML report that used to be loaded here was retired 2026-08-27.
.conjoint_lib_dir <- file.path(dirname(.conjoint_module_dir), "lib")
assign(".conjoint_lib_dir", .conjoint_lib_dir, envir = globalenv())

.html_simulator_main <- file.path(.conjoint_lib_dir, "html_simulator", "99_simulator_main.R")
if (file.exists(.html_simulator_main)) {
  source(.html_simulator_main)
}

# Clean up
rm(.conjoint_module_dir)

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run Conjoint Analysis
#'
#' Main entry point for enhanced conjoint analysis. Calculates part-worth utilities
#' and attribute importance scores from conjoint experimental data with comprehensive
#' validation and diagnostics.
#'
#' METHODOLOGY:
#' - Primary: mlogit for robust maximum likelihood estimation
#' - Fallback: clogit (survival package) for simpler estimation
#' - Calculates zero-centered part-worth utilities with confidence intervals
#' - Derives attribute importance from utility ranges
#' - Supports choice-based and rating-based designs
#' - Auto-detects and handles "none of these" options
#'
#' @param config_file Path to conjoint configuration Excel file (.xlsx)
#'   Required sheets: Settings, Attributes
#'   Settings sheet should include: data_file, output_file
#' @param data_file Path to respondent data (CSV, XLSX, SAV, DTA).
#'   If NULL, reads from config Settings sheet.
#' @param output_file Path for results Excel file.
#'   If NULL, reads from config Settings sheet.
#' @param verbose Logical, print detailed progress (default TRUE)
#' @param run_preflight Logical. If TRUE, runs a pre-flight check to validate
#'   that all module files, packages, and infrastructure are in place before
#'   starting analysis. Default FALSE to avoid overhead on normal runs.
#'
#' @return List containing:
#'   - utilities: Data frame of part-worth utilities by attribute level
#'   - importance: Data frame of attribute importance scores
#'   - diagnostics: Model fit statistics and quality assessments
#'   - model_result: Full model estimation results
#'   - config: Processed configuration
#'   - data_info: Data statistics and validation results
#'
#' @examples
#' \dontrun{
#' # Using config file with paths specified in Settings
#' results <- run_conjoint_analysis(
#'   config_file = "conjoint_config.xlsx"
#' )
#'
#' # Override paths from config
#' results <- run_conjoint_analysis(
#'   config_file = "conjoint_config.xlsx",
#'   data_file = "my_data.csv",
#'   output_file = "my_results.xlsx"
#' )
#'
#' # View attribute importance
#' print(results$importance)
#'
#' # View part-worth utilities
#' print(results$utilities)
#'
#' # View model diagnostics
#' print(results$diagnostics$fit_statistics)
#' }
#'
#' @export
run_conjoint_analysis <- function(config_file, data_file = NULL, output_file = NULL,
                                  verbose = TRUE, run_preflight = FALSE) {

  # ==========================================================================
  # OPTIONAL PRE-FLIGHT CHECK
  # ==========================================================================

  if (isTRUE(run_preflight)) {
    pf <- conjoint_preflight(verbose = verbose)
    if (pf$status == "REFUSED") {
      cat("\n=== TURAS ERROR ===\n")
      cat("Pre-flight check failed. Cannot proceed with analysis.\n")
      cat("Issues:", paste(pf$failures, collapse = "; "), "\n")
      cat("==================\n\n")
      return(pf)
    }
  }

  # ==========================================================================
  # TRS REFUSAL HANDLER WRAPPER (TRS v1.0)
  # ==========================================================================

  if (exists("conjoint_with_refusal_handler", mode = "function")) {
    conjoint_with_refusal_handler(
      run_conjoint_analysis_impl(config_file, data_file, output_file, verbose)
    )
  } else {
    run_conjoint_analysis_impl(config_file, data_file, output_file, verbose)
  }
}


#' Internal Implementation of Conjoint Analysis
#'
#' @keywords internal
run_conjoint_analysis_impl <- function(config_file, data_file = NULL, output_file = NULL,
                                       verbose = TRUE) {

  # ==========================================================================
  # TRS RUN STATE INITIALIZATION (TRS v1.0)
  # ==========================================================================

  # Create TRS run state for tracking events
  trs_state <- if (exists("turas_run_state_new", mode = "function")) {
    turas_run_state_new("CONJOINT")
  } else {
    NULL
  }

  # Print TRS start banner
  if (exists("turas_print_start_banner", mode = "function")) {
    turas_print_start_banner("CONJOINT", get_conjoint_version())
  } else if (verbose) {
    cat("\n")
    cat(rep("=", 80), "\n", sep = "")
    cat(sprintf("TURAS CONJOINT ANALYSIS - Version %s\n", get_conjoint_version()))
    cat(rep("=", 80), "\n", sep = "")
    cat("\n")
  }

  # Start timing
  start_time <- Sys.time()

  # Error handling wrapper
  result <- tryCatch({

    # STEP 1: Load Configuration
    if (verbose) cat("1. Loading configuration...\n")

    config <- load_conjoint_config(config_file, verbose = verbose)

    # Guard layer (H11). These validators existed but had no production
    # caller — only tests — so the checks they describe never actually ran.
    if (exists("validate_conjoint_config", mode = "function")) {
      validate_conjoint_config(config)
    }
    if (exists("validate_conjoint_attributes", mode = "function")) {
      validate_conjoint_attributes(config$attributes)
    }
    if (exists("validate_wtp_config", mode = "function")) {
      validate_wtp_config(config, config$attributes)
    }
    if (exists("validate_html_config", mode = "function")) {
      validate_html_config(config)
    }

    if (verbose) {
      cat(sprintf("   ✓ Loaded %d attributes with %d total levels\n",
                  nrow(config$attributes),
                  sum(config$attributes$NumLevels)))

      if (length(config$validation$warnings) > 0) {
        cat(sprintf("   ⚠ %d configuration warnings (see messages above)\n",
                    length(config$validation$warnings)))
      }
    }

    # Override paths if provided
    if (!is.null(data_file)) {
      config$data_file <- data_file
    }
    if (!is.null(output_file)) {
      config$output_file <- output_file
    }

    # STEP 2: Load and Validate Data
    if (verbose) cat("\n2. Loading and validating data...\n")

    data_list <- load_conjoint_data(config$data_file, config, verbose = verbose)

    if (exists("guard_check_data_exists", mode = "function")) {
      guard_check_data_exists(data_list$data)
    }

    if (verbose) {
      cat(sprintf("   ✓ Validated %d respondents with %d choice sets\n",
                  data_list$n_respondents,
                  data_list$n_choice_sets))

      if (data_list$has_none) {
        cat(sprintf("   ℹ None option detected and handled (%d selected)\n",
                    data_list$none_info$n_none_chosen))
      }

      if (length(data_list$validation$warnings) > 0) {
        cat(sprintf("   ⚠ %d data warnings (see messages above)\n",
                    length(data_list$validation$warnings)))
      }
    }

    # STEP 3: Estimate Model
    if (verbose) cat("\n3. Estimating choice model...\n")

    model_result <- estimate_choice_model(data_list, config, verbose = verbose)

    if (verbose) {
      cat(sprintf("   ✓ Model estimation complete (method: %s)\n",
                  model_result$method))

      if (!model_result$convergence$converged) {
        cat(sprintf("   ⚠ Convergence warning: %s\n",
                    model_result$convergence$message))
      }
    }

    # STEP 4: Calculate Utilities
    if (verbose) cat("\n4. Calculating part-worth utilities...\n")

    utilities <- calculate_utilities(model_result, config, verbose = verbose)

    if (verbose) {
      cat(sprintf("   ✓ Estimated %d part-worth utilities\n", nrow(utilities)))

      # Show significance summary
      n_sig <- sum(utilities$p_value < 0.05, na.rm = TRUE)
      n_total <- sum(!utilities$is_baseline)
      if (n_total > 0) {
        cat(sprintf("   ✓ %d of %d levels significant (p < 0.05)\n",
                    n_sig, n_total))
      }
    }

    # STEP 5: Calculate Importance
    if (verbose) cat("\n5. Calculating attribute importance...\n")

    # M4: importance from averaged utilities understates any attribute people
    # disagree about, because the disagreement cancels before the range is
    # taken. Where respondent-level part-worths exist, compute each
    # respondent's importance first and average those — which is also the
    # figure the tabs export will carry, so the report and the export agree.
    use_individual_importance <-
      !is.null(model_result$method) &&
      model_result$method %in% c("hierarchical_bayes", "latent_class") &&
      !is.null(model_result$individual_betas) &&
      exists("calculate_attribute_importance_hb", mode = "function")

    importance <- if (use_individual_importance) {
      calculate_attribute_importance_hb(model_result, config, verbose = verbose)
    } else {
      imp <- calculate_attribute_importance(utilities, config, verbose = verbose)
      attr(imp, "importance_method") <- "aggregate"
      imp
    }

    if (verbose) {
      cat("   ✓ Importance scores calculated:\n")
      for (i in seq_len(min(3, nrow(importance)))) {
        cat(sprintf("      %d. %s: %.1f%%\n",
                    i,
                    importance$Attribute[i],
                    importance$Importance[i]))
      }
    }

    # STEP 6: Calculate Diagnostics
    if (verbose) cat("\n6. Running model diagnostics...\n")

    diagnostics <- calculate_model_diagnostics(
      model_result, data_list, utilities, importance, config, verbose = verbose
    )

    if (verbose && model_result$method %in% c("mlogit", "clogit")) {
      cat(sprintf("   ✓ McFadden R² = %.3f (%s)\n",
                  diagnostics$fit_statistics$mcfadden_r2,
                  diagnostics$quality_assessment$level))

      if (!is.na(diagnostics$fit_statistics$hit_rate)) {
        cat(sprintf("   ✓ Hit rate = %.1f%% (chance = %.1f%%)\n",
                    diagnostics$fit_statistics$hit_rate * 100,
                    diagnostics$fit_statistics$chance_rate * 100))
      }
    }

    # STEP 6b: Calculate WTP (if price attribute exists)
    # Note: leaving wtp_price_attribute blank does not skip WTP — an attribute
    # named price/cost/fee is auto-detected. wtp_enabled = N is the off switch,
    # and the template and guard text now say so.
    wtp_result <- NULL
    if (isTRUE(config$wtp_enabled) && exists("calculate_wtp", mode = "function")) {
      # Auto-detect price attribute from config
      price_attr <- config$price_attribute %||% NULL
      if (is.null(price_attr)) {
        # Try to detect a price-like attribute name
        attr_names <- if (!is.null(utilities)) unique(utilities$Attribute) else character(0)
        price_candidates <- grep("price|cost|fee", attr_names, ignore.case = TRUE, value = TRUE)
        if (length(price_candidates) > 0) price_attr <- price_candidates[1]
      }

      if (!is.null(price_attr)) {
        wtp_result <- tryCatch({
          if (verbose) cat(sprintf("\n6b. Calculating willingness to pay (price attribute: %s)...\n", price_attr))
          # Set wtp_price_attribute in config if not already set
          if (is.null(config$wtp_price_attribute) || is.na(config$wtp_price_attribute) ||
              nchar(config$wtp_price_attribute) == 0) {
            config$wtp_price_attribute <- price_attr
          }
          result <- calculate_wtp(utilities, config, model_result, verbose = verbose)
          if (verbose) cat("   \u2713 WTP calculated\n")
          result
        }, error = function(e) {
          if (verbose) cat(sprintf("   WTP calculation skipped: %s\n", conditionMessage(e)))
          NULL
        })
      }
    }

    # STEPS 7-8: Output, HTML Report, and Finalization
    conjoint_generate_outputs(
      utilities = utilities,
      importance = importance,
      diagnostics = diagnostics,
      model_result = model_result,
      config = config,
      data_list = data_list,
      wtp_result = wtp_result,
      trs_state = trs_state,
      start_time = start_time,
      verbose = verbose
    )

  }, error = function(e) {
    # Error handling
    if (verbose) {
      cat("\n")
      cat(rep("=", 80), "\n", sep = "")
      cat("ERROR: Analysis Failed\n")
      cat(rep("=", 80), "\n", sep = "")
      cat("\n")
      cat("Error message:\n")
      cat(conditionMessage(e), "\n")
      cat("\n")

      # Additional troubleshooting
      cat("Troubleshooting:\n")
      cat("  1. Check your configuration file is valid\n")
      cat("  2. Verify your data file exists and has correct format\n")
      cat("  3. Ensure required packages are installed (mlogit, survival, openxlsx)\n")
      cat("  4. Review validation warnings above\n")
      cat("\n")
    }

    # Return TRS refusal for caller to handle
    return(list(
      status = "REFUSED",
      code = "CONJ_ANALYSIS_FAILED",
      message = conditionMessage(e),
      how_to_fix = c(
        "Check your configuration file is valid",
        "Verify your data file exists and has correct format",
        "Ensure required packages are installed (mlogit, survival, openxlsx)",
        "Review validation warnings above"
      )
    ))
  })

  invisible(result)
}


# ==============================================================================
# OUTPUT HELPER: Steps 7-8 + Finalization
# ==============================================================================

#' Generate Conjoint Outputs and Finalize
#'
#' Handles TRS logging, Excel output, optional HTML report generation,
#' timing, and final banner. Returns the result list.
#'
#' @keywords internal
conjoint_generate_outputs <- function(utilities, importance, diagnostics,
                                       model_result, config, data_list,
                                       wtp_result, trs_state, start_time,
                                       verbose = TRUE) {

  if (verbose) cat("\n7. Generating Excel output...\n")

  # A with-interactions model cannot be simulated from a part-worth table, so
  # the report ships without its simulator (see the html_config flag below).
  # The final status is computed from the warning count, so the limitation has
  # to be a warning or the run reports PASS while announcing a PARTIAL.
  .model_has_interactions <- isTRUE(model_result$has_interactions) ||
    isTRUE(attr(utilities, "has_interactions"))

  interaction_warning <- if (.model_has_interactions) {
    paste0("The model includes interaction terms. They are reported in the ",
           "interaction analysis, but a part-worth utilities table cannot ",
           "carry them, so the market simulator is not included in the HTML ",
           "report (CALC_INTERACTIONS_NOT_IN_SIMULATOR).")
  } else {
    character(0)
  }

  # TRS: Log warnings
  all_warnings <- c(config$validation$warnings, data_list$validation$warnings,
                    interaction_warning)
  if (!is.null(trs_state) && length(all_warnings) > 0) {
    for (warn in all_warnings) {
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(trs_state, "CONJ_WARNING", "Analysis warning", problem = warn)
      }
    }
  }

  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

  write_conjoint_output(
    utilities = utilities, importance = importance,
    diagnostics = diagnostics, model_result = model_result,
    config = config, data_info = data_list,
    output_file = config$output_file, run_result = run_result
  )

  if (verbose) cat(sprintf("   \u2713 Results written to: %s\n", basename(config$output_file)))

  # Step 7b: tabs export (opt-in). Written before the report so a refusal here
  # is visible next to the Excel deliverable it accompanies.
  tabs_export_result <- NULL
  if (isTRUE(config$generate_tabs_export)) {
    if (verbose) cat("\n7b. Exporting attribute importance for tabs...\n")

    tabs_export_result <- tryCatch(
      export_conjoint_importance_for_tabs(
        results = list(
          respondent_importance = attr(importance, "respondent_importance"),
          model_result = model_result,
          config = config
        ),
        verbose = verbose
      ),
      turas_refusal = function(e) {
        cat(conditionMessage(e))
        if (!is.null(trs_state) && exists("turas_run_state_partial", mode = "function")) {
          turas_run_state_partial(trs_state, e$code, "Tabs export not produced",
                                  problem = e$problem)
        }
        NULL
      }
    )
  }

  # Step 7c: contribution to the interactive report. Always written when the
  # analysis produced utilities — it is a small JSON file, and a tabs run for
  # the same project picks it up. Nothing consumes it until one does.
  island_result <- NULL
  if (exists("write_conjoint_island", mode = "function")) {
    island_result <- tryCatch(
      write_conjoint_island(
        results = list(
          utilities = utilities,
          importance = importance,
          diagnostics = diagnostics,
          model_result = model_result,
          config = config,
          wtp = wtp_result
        ),
        verbose = verbose
      ),
      turas_refusal = function(e) { cat(conditionMessage(e)); NULL },
      error = function(e) {
        message(sprintf("[TRS INFO] CONJ_ISLAND_FAILED: %s", conditionMessage(e)))
        NULL
      }
    )
  }

  # Step 8: the standalone market simulator.
  #
  # This module's own combined HTML report was retired 2026-08-27, the same
  # retirement tabs made on 2026-08-05: a second reporting stack nobody
  # maintained. Conjoint results now appear in the interactive report as a
  # Conjoint tab, fed by the *_cj_island.json written above. The simulator is
  # a tool rather than report content, so it survives as its own file.
  simulator_result <- NULL
  if (isTRUE(config$generate_html_simulator)) {
    if (verbose) cat("\n8. Generating the standalone market simulator...\n")

    if (!exists("generate_conjoint_simulator", mode = "function")) {
      cat("\n[TRS WARNING] CONJ_SIMULATOR_UNAVAILABLE: the simulator builder is not loaded; no simulator was written.\n\n")
    } else {
      sim_path <- sub("\\.xlsx$", "_simulator.html", config$output_file)
      simulator_result <- tryCatch(
        generate_conjoint_simulator(
          results = list(utilities = utilities, importance = importance,
                         model_result = model_result, config = config),
          output_path = sim_path,
          config = list(brand_colour = config$brand_colour,
                        accent_colour = config$accent_colour,
                        project_name = config$project_name),
          verbose = verbose
        ),
        error = function(e) {
          message(sprintf("[TRS INFO] CONJ_SIMULATOR_FAILED: %s", conditionMessage(e)))
          NULL
        }
      )

      if (!is.null(simulator_result) && identical(simulator_result$status, "REFUSED")) {
        cat("\n\u250c\u2500\u2500\u2500 TURAS: SIMULATOR NOT PRODUCED \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n")
        cat("\u2502 Code:", simulator_result$code, "\n")
        cat("\u2502", simulator_result$message, "\n")
        cat("\u2502 Fix:", simulator_result$how_to_fix, "\n")
        cat("\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n\n")
        if (!is.null(trs_state) && exists("turas_run_state_partial", mode = "function")) {
          turas_run_state_partial(trs_state, simulator_result$code,
                                  "Simulator not produced",
                                  problem = simulator_result$message)
        }
      }
    }
  }

  # Step 8b: Stats Pack (Optional)
  stats_pack_result <- NULL
  # M2: the template writes lowercase generate_stats_pack; this read the
  # capitalised name only, defaulted the miss to "Y", and OR'd in a GUI
  # checkbox that can only turn the pack ON. A config saying "N" therefore
  # produced a stats pack anyway. Read the setting case-tolerantly, let the
  # config's "N" stand, and treat the checkbox as an override only when the
  # user actually ticked it.
  .settings_lookup <- function(settings, name) {
    if (is.null(settings) || length(settings) == 0) return(NULL)
    hit <- which(tolower(names(settings)) == tolower(name))
    if (length(hit) == 0) return(NULL)
    settings[[hit[1]]]
  }

  stats_pack_setting <- .settings_lookup(config$settings, "generate_stats_pack")
  stats_pack_from_config <- if (is.null(stats_pack_setting)) {
    TRUE  # not configured at all: the documented default is on
  } else {
    isTRUE(safe_logical(stats_pack_setting, default = TRUE))
  }

  generate_stats_pack_flag <- stats_pack_from_config ||
    isTRUE(getOption("turas.generate_stats_pack", FALSE))

  if (generate_stats_pack_flag) {
    if (verbose) cat("\n8b. Generating stats pack...\n")
    stats_pack_result <- generate_conjoint_stats_pack(
      config       = config,
      data_list    = data_list,
      model_result = model_result,
      run_result   = run_result,
      start_time   = start_time,
      verbose      = verbose,
      diagnostics  = diagnostics,
      wtp_result   = wtp_result
    )
  } else {
    if (verbose) cat("\n8b. Stats pack skipped (set generate_stats_pack = Y in config to enable)\n")
  }

  # Finalization
  elapsed <- difftime(Sys.time(), start_time, units = "secs")
  if (verbose) cat(sprintf("\nTotal time: %.1f seconds\n", as.numeric(elapsed)))

  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  } else if (verbose) {
    cat(rep("=", 80), "\n", sep = "")
    if (length(all_warnings) == 0) {
      cat("[TRS PASS] CONJOINT - ANALYSIS COMPLETED SUCCESSFULLY\n")
    } else {
      cat(sprintf("[TRS PARTIAL] CONJOINT - ANALYSIS COMPLETED WITH %d WARNING(S)\n", length(all_warnings)))
    }
    cat(rep("=", 80), "\n", sep = "")
    cat("\n")
  }

  top_status <- if (length(all_warnings) == 0) "PASS" else "PARTIAL"

  list(
    status = top_status,
    utilities = utilities,
    importance = importance,
    diagnostics = diagnostics,
    model_result = model_result,
    config = config,
    data_info = data_list,
    elapsed_time = as.numeric(elapsed),
    version = get_conjoint_version(),
    run_result = run_result,
    warnings = if (length(all_warnings) > 0) all_warnings else NULL,
    stats_pack = stats_pack_result,
    tabs_export = tabs_export_result,
    v2_island = island_result,
    simulator = simulator_result,

    # Per-respondent attribute importance, one row per respondent, columns
    # summing to 100 except for respondents with flat part-worths. NULL unless
    # the method produced respondent-level estimates. This is the payload the
    # tabs Allocation export is built on.
    respondent_importance = attr(importance, "respondent_importance"),
    importance_method = attr(importance, "importance_method") %||% "aggregate"
  )
}


#' Generate Conjoint Stats Pack
#'
#' Builds the diagnostic payload from conjoint analysis results and writes the
#' stats pack Excel workbook alongside the main output.
#'
#' @keywords internal
generate_conjoint_stats_pack <- function(config, data_list, model_result,
                                          run_result, start_time, verbose,
                                          diagnostics = NULL, wtp_result = NULL) {

  # The config asked for a stats pack. If the writer is unavailable we cannot
  # produce one, and that must be visible regardless of the verbose setting.
  if (!exists("turas_write_stats_pack", mode = "function")) {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: Conjoint - stats pack\n")
    cat("│ Code: PKG_STATS_PACK_WRITER_UNAVAILABLE\n")
    cat("│ generate_stats_pack = Y but turas_write_stats_pack() is\n")
    cat("│ not loaded, so no stats pack was written.\n")
    cat("│ How to fix: ensure modules/shared/lib/stats_pack_writer.R\n")
    cat("│ is sourced (it is loaded by import_all.R).\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(NULL)
  }

  # Output path: same base as main output with _stats_pack suffix
  main_out    <- config$output_file %||% "conjoint_output.xlsx"
  output_path <- sub("(\\.xlsx)$", "_stats_pack.xlsx", main_out, ignore.case = TRUE)
  if (identical(output_path, main_out)) {
    output_path <- paste0(tools::file_path_sans_ext(main_out), "_stats_pack.xlsx")
  }

  # Data receipt
  data_receipt <- list(
    file_name           = basename(config$data_file %||% "unknown"),
    n_rows              = data_list$n_respondents %||% 0L,
    n_cols              = ncol(data_list$raw_data %||% data.frame()),
    questions_in_config = nrow(config$attributes %||% data.frame())
  )

  # Data used
  data_used <- list(
    n_respondents      = data_list$n_respondents %||% 0L,
    n_excluded         = 0L,
    weighted           = FALSE,
    questions_analysed = nrow(config$attributes %||% data.frame()),
    questions_skipped  = 0L
  )

  # Model type
  model_type  <- toupper(model_result$method %||% "MNL")
  is_hb       <- grepl("HB|BAYES|bayesm", model_type, ignore.case = TRUE)
  n_attr      <- nrow(config$attributes %||% data.frame())
  n_levels    <- if (!is.null(config$attributes) && "NumLevels" %in% names(config$attributes)) {
    sum(config$attributes$NumLevels, na.rm = TRUE)
  } else 0L
  n_tasks     <- data_list$n_choice_sets %||% NA
  hb_iters    <- if (is_hb) as.character(config$hb_iterations %||% config$settings$HB_Iterations %||% "—") else "N/A"
  seed_val    <- as.character(config$seed %||% config$settings$Seed %||% "Not set")
  # M1: this read enable_wtp / Enable_WTP, settings that do not exist, so the
  # pack said "WTP Estimation: Disabled" on every run that shipped a WTP table.
  # Read the actual result instead.
  wtp_flag    <- !is.null(wtp_result) && !is.null(wtp_result$wtp_table) &&
                 nrow(wtp_result$wtp_table) > 0
  sim_flag    <- isTRUE(config$generate_html_simulator) || isTRUE(config$settings$Generate_Simulator)

  # M1: the pack credited every HB run to a package that appears nowhere in
  # this module and is not in renv.lock (the engine is bayesm) — and every
  # other run "base R clogit() (MNL)" even when mlogit did the estimating.
  # Derive it from what actually ran.
  raw_method  <- model_result$method %||% ""
  impl_label  <- switch(
    raw_method,
    "hierarchical_bayes"      = "bayesm::rhierMnlRwMixture (HB)",
    "latent_class"            = "bayesm::rhierMnlRwMixture, mixture of normals (latent class)",
    "mlogit"                  = "mlogit (MNL)",
    "clogit"                  = "survival::clogit (MNL)",
    "best_worst_sequential"   = "mlogit, best and worst estimated separately (BWS sequential)",
    "ols_rating"              = "stats::lm (rating-based)",
    if (nzchar(raw_method)) sprintf("%s", raw_method) else "unknown"
  )

  # M1: the packages list was hardcoded and omitted whatever actually ran.
  packages_used <- c("openxlsx")
  packages_used <- c(packages_used, switch(
    raw_method,
    "hierarchical_bayes"    = "bayesm",
    "latent_class"          = "bayesm",
    "mlogit"                = c("mlogit", "dfidx"),
    "clogit"                = "survival",
    "best_worst_sequential" = c("mlogit", "dfidx"),
    "ols_rating"            = character(0),
    character(0)
  ))
  packages_used <- unique(packages_used)

  # TRS summary
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

  # HB convergence diagnostics (when available)
  convergence_info <- model_result$convergence %||% NULL
  if (!is.null(convergence_info)) {
    hb_convergence_items <- list(
      "Convergence Status" = if (isTRUE(convergence_info$converged)) "CONVERGED" else "NOT CONVERGED",
      "ESS Range" = if (!is.null(convergence_info$effective_sample_size)) {
        sprintf("%.0f - %.0f", min(convergence_info$effective_sample_size),
                max(convergence_info$effective_sample_size))
      } else "N/A",
      "Geweke Test" = if (!is.null(convergence_info$geweke_pass)) {
        if (convergence_info$geweke_pass) "PASSED" else sprintf("FAILED (max |z| = %.2f)", max(abs(convergence_info$geweke_z)))
      } else "N/A"
    )
  } else {
    hb_convergence_items <- list()
  }

  # Model fit statistics (when available)
  # M1: this read model_result$diagnostics$fit_statistics, which is never
  # attached — the fit statistics live on the diagnostics object the pipeline
  # computes separately — so the model-fit block was silently always absent.
  # The field name was wrong too: calculate_choice_fit_stats returns
  # log_likelihood_fitted, not log_likelihood.
  fit_stats <- diagnostics$fit_statistics %||%
    model_result$diagnostics$fit_statistics %||% NULL

  fmt_num <- function(x, fmt) {
    if (is.null(x) || length(x) == 0 || !is.finite(x)) return("N/A")
    sprintf(fmt, x)
  }

  model_fit_items <- if (!is.null(fit_stats)) {
    items <- list(
      "McFadden R-squared" = fmt_num(fit_stats$mcfadden_r2, "%.4f"),
      "Hit Rate" = if (is.null(fit_stats$hit_rate) || !is.finite(fit_stats$hit_rate)) {
        "N/A"
      } else {
        sprintf("%.1f%%", fit_stats$hit_rate * 100)
      },
      "Log-Likelihood (fitted)" = fmt_num(fit_stats$log_likelihood_fitted, "%.2f"),
      "Log-Likelihood (null)" = fmt_num(fit_stats$log_likelihood_null, "%.2f")
    )
    items
  } else {
    list()
  }

  assumptions <- list(
    "Model Type"            = model_type,
    "Attributes"            = as.character(n_attr),
    "Levels"                = as.character(n_levels),
    "Tasks per respondent"  = if (!is.na(n_tasks)) as.character(n_tasks) else "—",
    "HB Iterations"         = hb_iters,
    "HB Burn-in"            = if (is_hb) as.character(config$hb_burnin %||% config$settings$HB_Burnin %||% "—") else "N/A",
    "HB Thin"               = if (is_hb) as.character(config$hb_thin %||% config$settings$HB_Thin %||% "—") else "N/A",
    "HB Chains"             = if (is_hb) "1" else "N/A",
    "HB Standard Errors"    = if (is_hb) {
      switch(model_result$se_method %||% "unknown",
             "posterior_draws" = "Posterior SD of the mixture-mean draws",
             "heterogeneity_over_sqrt_n" = "Approximate: heterogeneity SD / sqrt(n)",
             "unknown")
    } else "N/A",
    "Seed"                  = seed_val,
    "WTP Estimation"        = if (wtp_flag) "Enabled" else "Disabled",
    "Market Simulation"     = if (sim_flag) "Enabled" else "Disabled",
    "Implementation"        = impl_label,
    "TRS Status"            = run_result$status %||% "PASS",
    "TRS Events"            = trs_summary
  )

  if (length(hb_convergence_items) > 0) {
    assumptions <- c(assumptions, hb_convergence_items)
  }
  if (length(model_fit_items) > 0) {
    assumptions <- c(assumptions, model_fit_items)
  }

  duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  payload <- list(
    module           = "CONJOINT",
    project_name     = config$project_name %||% NULL,
    analyst_name     = config$analyst_name %||% NULL,
    research_house   = config$company_name %||% NULL,
    run_timestamp    = start_time,
    turas_version    = get_conjoint_version(),
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = duration_secs,
    data_receipt     = data_receipt,
    data_used        = data_used,
    assumptions      = assumptions,
    run_result       = run_result,
    packages         = packages_used,
    config_echo      = list(settings = config$settings, attributes = config$attributes)
  )

  result <- turas_write_stats_pack(payload, output_path)

  if (!is.null(result) && verbose) {
    cat(sprintf("   \u2713 Stats pack written: %s\n", basename(output_path)))
  }

  result
}


#' @export
conjoint <- run_conjoint_analysis  # Alias for convenience
