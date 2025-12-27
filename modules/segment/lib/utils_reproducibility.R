# ==============================================================================
# SEGMENTATION UTILITIES - REPRODUCIBILITY & SEED MANAGEMENT
# ==============================================================================
# Purpose: Random seed management and reproducibility validation
# Part of: Turas Segmentation Module
# Version: 1.1.0 (Refactored for maintainability)
# ==============================================================================

#' Set Seed for Reproducibility
#'
#' DESIGN: Centralized seed management for all random operations
#' ENSURES: Deterministic results across runs with same config
#'
#' @param config Configuration list with optional seed parameter
#' @return The seed value that was set (either from config or auto-generated)
#' @export
set_segmentation_seed <- function(config) {

  # Determine seed value
  if (!is.null(config$seed) && !is.na(config$seed)) {
    # Use seed from config
    seed_value <- as.integer(config$seed)
    seed_source <- "config"
  } else {
    # Generate seed from timestamp for reproducibility
    # Use date + time to ensure uniqueness across runs
    seed_value <- as.integer(format(Sys.time(), "%Y%m%d%H%M%S")) %% .Machine$integer.max
    seed_source <- "auto-generated"
  }

  # Set the seed
  set.seed(seed_value)

  cat(sprintf("🎲 Seed set: %d (%s)\n", seed_value, seed_source))
  cat(sprintf("   Note: Use this seed in config to reproduce results\n\n"))

  return(seed_value)
}


#' Get Current RNG State
#'
#' Captures current random number generator state for later restoration
#'
#' @return The current .Random.seed value
#' @export
get_rng_state <- function() {
  if (exists(".Random.seed", envir = .GlobalEnv)) {
    return(get(".Random.seed", envir = .GlobalEnv))
  } else {
    return(NULL)
  }
}


#' Restore RNG State
#'
#' Restores a previously saved random number generator state
#'
#' @param rng_state The saved RNG state from get_rng_state()
#' @export
restore_rng_state <- function(rng_state) {
  if (!is.null(rng_state)) {
    assign(".Random.seed", rng_state, envir = .GlobalEnv)
  }
}


#' Validate Seed Reproducibility
#'
#' Tests that a given seed produces reproducible results
#'
#' @param seed Seed value to test
#' @param test_data Sample data for testing
#' @param k Number of clusters for testing
#' @return TRUE if reproducible, FALSE otherwise
#' @export
validate_seed_reproducibility <- function(seed, test_data, k = 3) {

  # Run 1
  set.seed(seed)
  result1 <- kmeans(test_data, centers = k, nstart = 10)

  # Run 2 with same seed
  set.seed(seed)
  result2 <- kmeans(test_data, centers = k, nstart = 10)

  # Check if results are identical
  clusters_match <- identical(result1$cluster, result2$cluster)
  centers_match <- all.equal(result1$centers, result2$centers, tolerance = 1e-10)

  if (clusters_match && isTRUE(centers_match)) {
    cat(sprintf("✓ Seed %d produces reproducible results\n", seed))
    return(TRUE)
  } else {
    warning(sprintf("Seed %d does NOT produce reproducible results", seed), call. = FALSE)
    return(FALSE)
  }
}
