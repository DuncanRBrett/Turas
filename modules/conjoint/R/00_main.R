# ==============================================================================
# TURAS CONJOINT ANALYSIS MODULE - ENHANCED MAIN ENTRY POINT
# ==============================================================================
#
# Module: Conjoint Analysis
# Purpose: Calculate part-worth utilities and attribute importance from
#          choice-based or rating-based conjoint data
# Version: Turas v10.1 (Phase 1 - Alchemer Integration)
# Date: 2025-12-12
#
# NEW IN v10.1:
#   - Alchemer CBC export direct import (05_alchemer_import.R)
#   - Enhanced mlogit estimation with better diagnostics
#   - Improved zero-centering and importance calculations
#
# ==============================================================================

# ==============================================================================
# LOAD REQUIRED PACKAGES
# ==============================================================================

# Suppress package startup messages for cleaner output
suppressPackageStartupMessages({
  # Data manipulation
  if (!require(dplyr, quietly = TRUE)) {
    stop("Package 'dplyr' is required. Install with: install.packages('dplyr')")
  }

  # Excel I/O
  if (!require(openxlsx, quietly = TRUE)) {
    stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')")
  }

  # Choice modeling
  if (!require(mlogit, quietly = TRUE)) {
    warning("Package 'mlogit' not found. Install with: install.packages('mlogit')")
  }

  # Data indexing for mlogit (required for mlogit >= 1.1-0)
  if (!require(dfidx, quietly = TRUE)) {
    warning("Package 'dfidx' not found. Install with: install.packages('dfidx')")
  }

  # Fallback estimation
  if (!require(survival, quietly = TRUE)) {
    warning("Package 'survival' not found. Install with: install.packages('survival')")
  }
})

# ==============================================================================
# LOAD MODULE COMPONENTS
# ==============================================================================

# Get the directory where this script is located
.conjoint_module_dir <- tryCatch({
  dir <- getSrcDirectory(function() {})
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    # Fallback if getSrcDirectory doesn't work
    dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "")
  }
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    # Check if we're in Turas directory structure
    wd <- getwd()
    if (file.exists(file.path(wd, "modules/conjoint/R"))) {
      # We're in Turas root
      dir <- file.path(wd, "modules/conjoint/R")
    } else if (basename(dirname(wd)) == "conjoint" && basename(wd) == "R") {
      # We're already in modules/conjoint/R
      dir <- wd
    } else if (basename(wd) == "conjoint") {
      # We're in modules/conjoint
      dir <- file.path(wd, "R")
    } else {
      # Last resort - assume working directory is Turas root
      dir <- file.path(wd, "modules/conjoint/R")
    }
  }
  dir
}, error = function(e) {
  file.path(getwd(), "modules/conjoint/R")
})

# Validate the directory exists
if (!dir.exists(.conjoint_module_dir)) {
  stop(sprintf(
    "Could not locate conjoint module directory. Expected: %s\nCurrent working directory: %s",
    .conjoint_module_dir, getwd()
  ))
}

# Source all component files in order
source(file.path(.conjoint_module_dir, "99_helpers.R"))      # Helper functions (must be first)
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
                                  verbose = TRUE) {

  # Start timing
  start_time <- Sys.time()

  # Print header
  if (verbose) {
    cat("\n")
    cat(rep("=", 80), "\n", sep = "")
    cat("TURAS CONJOINT ANALYSIS - Version 2.1 (Alchemer Integration)\n")
    cat(rep("=", 80), "\n", sep = "")
    cat("\n")
  }

  # Error handling wrapper
  result <- tryCatch({

    # STEP 1: Load Configuration
    if (verbose) cat("1. Loading configuration...\n")

    config <- load_conjoint_config(config_file, verbose = verbose)

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

    importance <- calculate_attribute_importance(utilities, config, verbose = verbose)

    if (verbose) {
      cat("   ✓ Importance scores calculated:\n")
      for (i in 1:min(3, nrow(importance))) {
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

    # STEP 7: Generate Output
    if (verbose) cat("\n7. Generating Excel output...\n")

    write_conjoint_output(
      utilities = utilities,
      importance = importance,
      diagnostics = diagnostics,
      model_result = model_result,
      config = config,
      data_info = data_list,
      output_file = config$output_file
    )

    if (verbose) {
      cat(sprintf("   ✓ Results written to: %s\n", basename(config$output_file)))
    }

    # Calculate elapsed time
    elapsed <- difftime(Sys.time(), start_time, units = "secs")

    if (verbose) {
      cat("\n")
      cat(rep("=", 80), "\n", sep = "")
      cat("ANALYSIS COMPLETE\n")
      cat(sprintf("Total time: %.1f seconds\n", as.numeric(elapsed)))
      cat(rep("=", 80), "\n", sep = "")
      cat("\n")
    }

    # Return comprehensive results
    list(
      utilities = utilities,
      importance = importance,
      diagnostics = diagnostics,
      model_result = model_result,
      config = config,
      data_info = data_list,
      elapsed_time = as.numeric(elapsed),
      version = "2.1.0"
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

    # Re-throw error for caller to handle
    stop(e)
  })

  invisible(result)
}


#' @export
conjoint <- run_conjoint_analysis  # Alias for convenience
