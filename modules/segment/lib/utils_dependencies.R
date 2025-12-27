# ==============================================================================
# SEGMENTATION UTILITIES - PACKAGE DEPENDENCIES
# ==============================================================================
# Purpose: Package dependency checking and installation management
# Part of: Turas Segmentation Module
# Version: 1.1.0 (Refactored for maintainability)
# ==============================================================================

# ==============================================================================
# PACKAGE DEPENDENCY MANAGEMENT
# ==============================================================================
#
# MINIMUM INSTALL (core k-means functionality):
#   - stats      (built-in)  - kmeans clustering
#   - cluster    (CRAN)      - silhouette analysis
#   - readxl     (CRAN)      - read Excel config files
#   - writexl    (CRAN)      - write Excel output files
#
# FULL INSTALL (all features including LCA):
#   - All minimum packages, plus:
#   - poLCA      (CRAN)      - Latent Class Analysis
#   - MASS       (built-in)  - Mahalanobis distance for outliers
#   - rpart      (built-in)  - Decision tree segment rules
#   - psych      (CRAN)      - Factor analysis, reliability
#   - fmsb       (CRAN)      - Radar charts for profiles
#   - ggplot2    (CRAN)      - Enhanced visualizations
#   - randomForest (CRAN)    - Variable importance (optional)
#   - haven      (CRAN)      - SPSS file support (optional)
#
# ==============================================================================

#' Check Segmentation Package Dependencies
#'
#' Validates that required packages are installed and reports on optional
#' packages. Returns a structured list of available/missing packages.
#'
#' @param verbose Logical, print detailed output (default: TRUE)
#' @param install_missing Logical, attempt to install missing required packages (default: FALSE)
#' @return List with available, missing_required, missing_optional, and ready status
#' @export
#' @examples
#' # Check dependencies before running segmentation
#' deps <- check_segment_dependencies()
#' if (!deps$ready) {
#'   cat("Missing required packages:", paste(deps$missing_required, collapse = ", "))
#' }
check_segment_dependencies <- function(verbose = TRUE, install_missing = FALSE) {

  # Define package categories
  required_packages <- list(
    cluster = "Silhouette analysis and cluster validation",
    readxl  = "Read Excel configuration files",
    writexl = "Write Excel output files"
  )

  optional_packages <- list(
    poLCA       = "Latent Class Analysis (alternative to k-means)",
    MASS        = "Mahalanobis distance for outlier detection",
    rpart       = "Decision tree classification rules",
    psych       = "Factor analysis and reliability metrics",
    fmsb        = "Radar charts for segment profiles",
    ggplot2     = "Enhanced visualizations",
    randomForest = "Variable importance analysis",
    haven       = "Read SPSS data files"
  )

  builtin_packages <- c("stats", "MASS", "rpart")

  # Check each package
  check_pkg <- function(pkg) {
    if (pkg %in% builtin_packages) {
      # Built-in packages are always available
      return(TRUE)
    }
    requireNamespace(pkg, quietly = TRUE)
  }

  # Check required packages
  required_status <- sapply(names(required_packages), check_pkg)
  missing_required <- names(required_packages)[!required_status]

  # Check optional packages
  optional_status <- sapply(names(optional_packages), check_pkg)
  available_optional <- names(optional_packages)[optional_status]
  missing_optional <- names(optional_packages)[!optional_status]

  # Overall readiness
  ready <- length(missing_required) == 0

  if (verbose) {
    cat("\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("SEGMENTATION MODULE - PACKAGE DEPENDENCIES\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("\n")

    # Required packages
    cat("REQUIRED PACKAGES:\n")
    for (pkg in names(required_packages)) {
      status <- if (required_status[pkg]) "[OK]" else "[MISSING]"
      cat(sprintf("  %s %-12s - %s\n", status, pkg, required_packages[[pkg]]))
    }

    # Optional packages
    cat("\nOPTIONAL PACKAGES:\n")
    for (pkg in names(optional_packages)) {
      status <- if (optional_status[pkg]) "[OK]" else "[--]"
      cat(sprintf("  %s %-12s - %s\n", status, pkg, optional_packages[[pkg]]))
    }

    # Summary
    cat("\n")
    cat(rep("-", 70), "\n", sep = "")
    if (ready) {
      cat("STATUS: Ready for segmentation (all required packages installed)\n")
      if (length(missing_optional) > 0) {
        cat(sprintf("        %d optional package(s) not installed\n", length(missing_optional)))
      }
    } else {
      cat("STATUS: NOT READY - missing required packages\n")
      cat("\nTo install missing required packages, run:\n")
      cat(sprintf("  install.packages(c(%s))\n",
                  paste(sprintf('"%s"', missing_required), collapse = ", ")))
    }
    cat("\n")

    # Feature availability based on packages
    cat("FEATURE AVAILABILITY:\n")
    cat(sprintf("  K-means clustering:      %s\n", if (ready) "Available" else "Unavailable"))
    cat(sprintf("  Latent Class Analysis:   %s\n",
                if ("poLCA" %in% available_optional) "Available" else "Unavailable (install poLCA)"))
    cat(sprintf("  Mahalanobis outliers:    %s\n",
                if (check_pkg("MASS")) "Available" else "Unavailable"))
    cat(sprintf("  Decision tree rules:     %s\n",
                if (check_pkg("rpart")) "Available" else "Unavailable"))
    cat(sprintf("  Radar charts:            %s\n",
                if ("fmsb" %in% available_optional) "Available" else "Unavailable (install fmsb)"))
    cat(sprintf("  Variable importance:     %s\n",
                if ("randomForest" %in% available_optional) "Available" else "Unavailable (install randomForest)"))
    cat("\n")
  }

  # Attempt installation if requested
  if (install_missing && length(missing_required) > 0) {
    cat("Attempting to install missing required packages...\n")
    for (pkg in missing_required) {
      tryCatch({
        install.packages(pkg, quiet = TRUE)
        cat(sprintf("  Installed: %s\n", pkg))
      }, error = function(e) {
        cat(sprintf("  Failed to install: %s (%s)\n", pkg, e$message))
      })
    }
  }

  return(invisible(list(
    ready = ready,
    available = c(names(required_packages)[required_status], available_optional),
    missing_required = missing_required,
    missing_optional = missing_optional,
    features = list(
      kmeans = ready,
      lca = "poLCA" %in% available_optional,
      outlier_mahalanobis = check_pkg("MASS"),
      decision_rules = check_pkg("rpart"),
      radar_charts = "fmsb" %in% available_optional,
      variable_importance = "randomForest" %in% available_optional
    )
  )))
}


#' Get Minimum Install Command
#'
#' Returns the R command to install only required packages for basic
#' k-means segmentation functionality.
#'
#' @return Character string with install.packages() command
#' @export
get_minimum_install_cmd <- function() {
  cmd <- 'install.packages(c("cluster", "readxl", "writexl"))'
  cat("Minimum install (k-means only):\n")
  cat(paste0("  ", cmd, "\n"))
  invisible(cmd)
}


#' Get Full Install Command
#'
#' Returns the R command to install all packages for full segmentation
#' functionality including LCA and advanced features.
#'
#' @return Character string with install.packages() command
#' @export
get_full_install_cmd <- function() {
  cmd <- 'install.packages(c("cluster", "readxl", "writexl", "poLCA", "psych", "fmsb", "ggplot2", "randomForest", "haven"))'
  cat("Full install (all features):\n")
  cat(paste0("  ", cmd, "\n"))
  invisible(cmd)
}
