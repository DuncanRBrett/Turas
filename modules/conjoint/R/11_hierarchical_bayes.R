# ==============================================================================
# HIERARCHICAL BAYES - ADVANCED CONJOINT ANALYSIS
# ==============================================================================
#
# Module: Conjoint Analysis - Hierarchical Bayes Estimation
# Purpose: Framework for Hierarchical Bayes (HB) estimation of conjoint models
# Version: 2.1.0 (Refactored for maintainability)
# Date: 2025-12-27
#
# This file provides a framework for Hierarchical Bayes (HB) estimation of
# conjoint models, which estimates individual-level part-worth utilities
# while borrowing strength across respondents.
#
# REQUIREMENTS:
# - R package: bayesm (Bayesian Methods for Marketing/Micro-Econometrics)
#   Install with: install.packages("bayesm")
# - OR: RSGHB (R package for Hierarchical Bayes estimation)
#   Install with: install.packages("RSGHB")
#
# ADVANTAGES OF HB:
# - Individual-level utilities (not just aggregate)
# - Better handling of preference heterogeneity
# - More stable estimates with small sample sizes
# - Can incorporate respondent covariates
#
# COMPUTATIONAL REQUIREMENTS:
# - Significantly longer run time (minutes to hours vs. seconds)
# - Memory intensive for large datasets
# - Requires MCMC convergence diagnostics
#
# SUB-MODULES:
# - hb_estimation.R: bayesm and RSGHB implementation frameworks
# - hb_convergence.R: MCMC convergence diagnostics
# - hb_visualization.R: Trace plots and summary tables
#
# Part of: Turas Enhanced Conjoint Analysis Module
# ==============================================================================

# Source sub-modules (sourced by 00_main.R which sets .conjoint_module_dir)
source(file.path(.conjoint_module_dir, "hb_estimation.R"))
source(file.path(.conjoint_module_dir, "hb_convergence.R"))
source(file.path(.conjoint_module_dir, "hb_visualization.R"))


# ==============================================================================
# PACKAGE AVAILABILITY AND REQUIREMENTS
# ==============================================================================

#' Check if Hierarchical Bayes packages are available
#'
#' Checks for availability of HB estimation packages (bayesm or RSGHB) and
#' provides installation instructions if neither is available.
#'
#' @return List with package availability and recommendations:
#' \describe{
#'   \item{bayesm_available}{Logical. TRUE if bayesm is installed}
#'   \item{rsghb_available}{Logical. TRUE if RSGHB is installed}
#'   \item{any_available}{Logical. TRUE if at least one package is available}
#'   \item{recommended_package}{Character. "bayesm", "RSGHB", or "none"}
#'   \item{install_instructions}{Character. Installation instructions or NULL}
#' }
#'
#' @examples
#' # Check what HB packages are available
#' hb_status <- check_hb_requirements()
#' if (!hb_status$any_available) {
#'   cat(hb_status$install_instructions)
#' }
#'
#' @export
check_hb_requirements <- function() {

  has_bayesm <- requireNamespace("bayesm", quietly = TRUE)
  has_rsghb <- requireNamespace("RSGHB", quietly = TRUE)

  list(
    bayesm_available = has_bayesm,
    rsghb_available = has_rsghb,
    any_available = has_bayesm || has_rsghb,
    recommended_package = if (has_bayesm) "bayesm" else if (has_rsghb) "RSGHB" else "none",
    install_instructions = if (!has_bayesm && !has_rsghb) {
      "Install bayesm with: install.packages('bayesm')\nOr RSGHB with: install.packages('RSGHB')"
    } else {
      NULL
    }
  )
}


# ==============================================================================
# DATA VALIDATION
# ==============================================================================

#' Validate data for HB estimation
#'
#' Checks that data meets minimum requirements for Hierarchical Bayes estimation.
#' HB requires sufficient respondents and choice sets per respondent for
#' stable individual-level parameter estimation.
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration object
#'
#' @return Validation results list with components:
#' \describe{
#'   \item{critical}{Character vector of critical errors (estimation cannot proceed)}
#'   \item{warnings}{Character vector of warnings (estimation can proceed but may be unreliable)}
#'   \item{info}{Character vector of informational messages}
#' }
#'
#' @details
#' **Recommended minimums for HB estimation:**
#' - 30+ respondents (absolute minimum: 20)
#' - 8+ choice sets per respondent (absolute minimum: 4)
#'
#' With fewer respondents or choices, aggregate methods (MNL, latent class)
#' may be more appropriate.
#'
#' @export
validate_hb_data <- function(data_list, config) {

  validation <- list(
    critical = character(0),
    warnings = character(0),
    info = character(0)
  )

  # Check minimum respondents (HB needs sufficient sample for priors)
  min_respondents <- 30
  if (data_list$n_respondents < min_respondents) {
    validation$warnings <- c(
      validation$warnings,
      sprintf(
        "HB estimation recommended for %d+ respondents (you have %d). Consider aggregate methods.",
        min_respondents,
        data_list$n_respondents
      )
    )
  }

  # Check choices per respondent
  min_choices_per_resp <- 8
  avg_choices <- data_list$n_choice_sets / data_list$n_respondents

  if (avg_choices < min_choices_per_resp) {
    validation$warnings <- c(
      validation$warnings,
      sprintf(
        "HB estimation works best with %d+ choices per respondent (average: %.1f)",
        min_choices_per_resp,
        avg_choices
      )
    )
  }

  # Info
  validation$info <- c(
    validation$info,
    sprintf("HB will estimate individual utilities for %d respondents",
            data_list$n_respondents),
    sprintf("Each respondent has ~%.1f choice sets", avg_choices)
  )

  validation
}


# ==============================================================================
# MAIN ESTIMATION FUNCTION
# ==============================================================================

#' Estimate Hierarchical Bayes conjoint model
#'
#' This function provides a framework for HB estimation. Full implementation
#' requires bayesm or RSGHB package.
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration object
#' @param mcmc_iterations Integer: number of MCMC iterations (default 10000)
#' @param burn_in Integer: burn-in iterations to discard (default 2000)
#' @param thin Integer: thinning interval (default 10)
#' @param package Character: "bayesm", "RSGHB", or "auto" (default)
#' @param verbose Logical: print progress information (default TRUE)
#'
#' @return HB model result list with components:
#' \describe{
#'   \item{method}{Character. "hierarchical_bayes_bayesm" or "hierarchical_bayes_rsghb"}
#'   \item{individual_utilities}{Matrix. Individual-level part-worths (respondents x parameters)}
#'   \item{aggregate_utilities}{Numeric vector. Population-level means}
#'   \item{mcmc_draws}{MCMC samples for convergence diagnostics}
#'   \item{convergence}{Convergence diagnostics from check_hb_convergence()}
#'   \item{is_hierarchical_bayes}{Logical. Always TRUE}
#'   \item{hb_package}{Character. Package used for estimation}
#' }
#'
#' @details
#' **MCMC Settings:**
#' - **mcmc_iterations**: Total MCMC iterations to run. Minimum 5000, recommended 10000+
#' - **burn_in**: Initial samples to discard. Typically 20-40% of iterations
#' - **thin**: Keep every nth sample. Reduces autocorrelation and storage
#' - **Effective samples**: (mcmc_iterations - burn_in) / thin
#'
#' Example with 10000 iterations, 2000 burn-in, thin=10:
#' - Effective samples: (10000 - 2000) / 10 = 800 samples
#'
#' **Package Selection:**
#' - "auto": Uses bayesm if available, otherwise RSGHB
#' - "bayesm": Uses bayesm package (preferred)
#' - "RSGHB": Uses RSGHB package
#'
#' **Computational Time:**
#' HB estimation is computationally intensive. Typical run times:
#' - Small study (50 respondents, 5 attributes): 5-15 minutes
#' - Medium study (200 respondents, 7 attributes): 30-60 minutes
#' - Large study (500+ respondents, 10+ attributes): 2+ hours
#'
#' @examples
#' \dontrun{
#' # Basic HB estimation with defaults
#' hb_result <- estimate_hierarchical_bayes(
#'   data_list = my_data,
#'   config = my_config
#' )
#'
#' # Custom MCMC settings for faster testing
#' hb_test <- estimate_hierarchical_bayes(
#'   data_list = my_data,
#'   config = my_config,
#'   mcmc_iterations = 5000,
#'   burn_in = 1000,
#'   thin = 5
#' )
#'
#' # Extract individual utilities
#' individual_utils <- hb_result$individual_utilities
#'
#' # Aggregate utilities (population means)
#' aggregate_utils <- hb_result$aggregate_utilities
#'
#' # Check convergence
#' convergence <- check_hb_convergence(hb_result, verbose = TRUE)
#' }
#'
#' @export
estimate_hierarchical_bayes <- function(data_list,
                                         config,
                                         mcmc_iterations = 10000,
                                         burn_in = 2000,
                                         thin = 10,
                                         package = "auto",
                                         verbose = TRUE) {

  # Check requirements
  hb_req <- check_hb_requirements()

  if (!hb_req$any_available) {
    conjoint_refuse(
      code = "PKG_HB_NOT_INSTALLED",
      title = "Hierarchical Bayes Package Not Available",
      problem = "No HB package available",
      why_it_matters = "Hierarchical Bayes estimation requires specialized MCMC packages (bayesm or RSGHB).",
      how_to_fix = hb_req$install_instructions
    )
  }

  # Validate data
  validation <- validate_hb_data(data_list, config)

  if (length(validation$critical) > 0) {
    conjoint_refuse(
      code = "DATA_HB_VALIDATION_FAILED",
      title = "Data Validation Failed for HB Estimation",
      problem = "Data validation failed for HB estimation",
      why_it_matters = "Hierarchical Bayes requires sufficient data per respondent to estimate individual-level utilities.",
      how_to_fix = paste(validation$critical, collapse = "; ")
    )
  }

  # Print warnings
  if (verbose && length(validation$warnings) > 0) {
    cat("\nHB Warnings:\n")
    for (w in validation$warnings) {
      cat("  Warning:", w, "\n")
    }
    cat("\n")
  }

  # Select package
  if (package == "auto") {
    package <- hb_req$recommended_package
  }

  if (verbose) {
    cat(sprintf("\nEstimating Hierarchical Bayes model using %s...\n", package))
    cat(sprintf("  MCMC iterations: %d\n", mcmc_iterations))
    cat(sprintf("  Burn-in: %d\n", burn_in))
    cat(sprintf("  Thinning: %d\n", thin))
    cat(sprintf("  Effective samples: %d\n",
                (mcmc_iterations - burn_in) / thin))
  }

  # Estimate based on package
  if (package == "bayesm") {
    result <- estimate_hb_bayesm(data_list, config, mcmc_iterations,
                                  burn_in, thin, verbose)
  } else if (package == "RSGHB") {
    result <- estimate_hb_rsghb(data_list, config, mcmc_iterations,
                                 burn_in, thin, verbose)
  } else {
    conjoint_refuse(
      code = "CFG_HB_UNKNOWN_PACKAGE",
      title = "Unknown HB Package",
      problem = sprintf("Unknown HB package: %s", package),
      why_it_matters = "Hierarchical Bayes estimation requires a valid package specification.",
      how_to_fix = "Use 'bayesm', 'RSGHB', or 'auto' as the package parameter"
    )
  }

  result$is_hierarchical_bayes <- TRUE
  result$hb_package <- package

  result
}


# ==============================================================================
# DOCUMENTATION AND GUIDANCE
# ==============================================================================

#' Print HB implementation guidance
#'
#' Displays comprehensive guidance for implementing Hierarchical Bayes estimation
#' including requirements, advantages, computational considerations, and
#' implementation status.
#'
#' @return Invisible NULL (prints to console)
#'
#' @examples
#' # Display HB guidance
#' print_hb_guidance()
#'
#' @export
print_hb_guidance <- function() {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("HIERARCHICAL BAYES ESTIMATION GUIDANCE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  cat("REQUIREMENTS:\n")
  cat("  1. Install bayesm: install.packages('bayesm')\n")
  cat("  2. Minimum 30+ respondents recommended\n")
  cat("  3. 8+ choice sets per respondent recommended\n")
  cat("\n")

  cat("ADVANTAGES:\n")
  cat("  - Individual-level utilities (see preferences per person)\n")
  cat("  - Better for heterogeneous populations\n")
  cat("  - Can incorporate respondent demographics\n")
  cat("  - More stable with small samples\n")
  cat("\n")

  cat("COMPUTATIONAL COST:\n")
  cat("  - Run time: Minutes to hours (vs. seconds for aggregate)\n")
  cat("  - Memory: High for large datasets\n")
  cat("  - Requires convergence checking\n")
  cat("\n")

  cat("CURRENT STATUS:\n")
  cat("  Framework implemented, full estimation requires:\n")
  cat("    1. Data preparation for bayesm format\n")
  cat("    2. Prior specification\n")
  cat("    3. MCMC sampling\n")
  cat("    4. Convergence diagnostics\n")
  cat("    5. Individual utility extraction\n")
  cat("\n")

  cat("FOR FULL IMPLEMENTATION:\n")
  cat("  Contact development team or see:\n")
  cat("    - bayesm documentation: ?bayesm::rhierMnlRwMixture\n")
  cat("    - Example: demo(topic='rhierMnlRwMixture', package='bayesm')\n")
  cat("\n")

  invisible(NULL)
}
