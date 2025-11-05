# ==============================================================================
# TURAS RANKING MODULE - MAIN ORCHESTRATOR
# ==============================================================================
# Main entry point for ranking question analysis
#
# Part of Phase 6: Ranking Migration
# Version: 1.0.0 (based on ranking.r V9.9.3)
#
# ARCHITECTURE:
# This file sources all ranking sub-modules and provides a clean public API
#
# MODULES:
# 1. direction.R - Rank direction normalization
# 2. validation.R - Data quality validation
# 3. extraction.R - Extract ranking data (both formats)
# 4. calculations.R - Statistical calculations
# 5. output.R - Generate output rows
#
# DEPENDENCIES:
# - Core utilities (Phase 1)
# - Data loading (Phase 2)
# - Statistics/weighting (Phase 5)
# ==============================================================================

# ==============================================================================
# SOURCE ALL RANKING MODULES
# ==============================================================================

# Get base directory
if (exists("TURAS_BASE_DIR")) {
  base_dir <- TURAS_BASE_DIR
} else {
  base_dir <- "~/Documents/Turas"
}

ranking_lib_dir <- file.path(base_dir, "modules/ranking/lib")


logging_stub_path <- file.path(base_dir, "core/logging.R")
if (file.exists(logging_stub_path)) {
  source(logging_stub_path)
}


weighting_stubs_path <- file.path(base_dir, "shared/statistics/weighting.R")
if (file.exists(weighting_stubs_path)) {
  source(weighting_stubs_path)
}

# Source all ranking modules in dependency order
cat("Loading Turas Ranking Module...\n")

# Module 1: Direction (no dependencies)
module1_path <- file.path(ranking_lib_dir, "direction.R")
if (file.exists(module1_path)) {
  source(module1_path)
  cat("  ✓ Module 1: direction.R loaded\n")
} else {
  stop("Cannot find module: direction.R at ", module1_path)
}

# Module 2: Validation (depends on logging)
module2_path <- file.path(ranking_lib_dir, "validation.R")
if (file.exists(module2_path)) {
  source(module2_path)
  cat("  ✓ Module 2: validation.R loaded\n")
} else {
  stop("Cannot find module: validation.R at ", module2_path)
}

# Module 3: Extraction (depends on 1, 2)
module3_path <- file.path(ranking_lib_dir, "extraction.R")
if (file.exists(module3_path)) {
  source(module3_path)
  cat("  ✓ Module 3: extraction.R loaded\n")
} else {
  stop("Cannot find module: extraction.R at ", module3_path)
}

# Module 4: Calculations (depends on weighting stubs)
module4_path <- file.path(ranking_lib_dir, "calculations.R")
if (file.exists(module4_path)) {
  source(module4_path)
  cat("  ✓ Module 4: calculations.R loaded\n")
} else {
  stop("Cannot find module: calculations.R at ", module4_path)
}

# Module 5: Output (depends on 4)
module5_path <- file.path(ranking_lib_dir, "output.R")
if (file.exists(module5_path)) {
  source(module5_path)
  cat("  ✓ Module 5: output.R loaded\n")
} else {
  stop("Cannot find module: output.R at ", module5_path)
}

cat("Ranking module loaded successfully!\n")


# ==============================================================================
# PUBLIC API - CONVENIENCE FUNCTIONS
# ==============================================================================

#' Process ranking question end-to-end
#'
#' @description
#' Convenience function that extracts ranking data and generates output rows
#' in a single call. Handles both Position and Item formats automatically.
#'
#' @param data Survey data frame
#' @param question_info Question metadata row
#' @param option_info Options metadata
#' @param banner_data_list List of banner subsets
#' @param banner_info Banner metadata
#' @param internal_keys Banner column keys
#' @param weights_list Weights by banner column (optional)
#' @param config Configuration list (optional)
#' @param show_top_n Show % Top N row (default: TRUE)
#' @param top_n Top N positions (default: 3)
#'
#' @return List with:
#'   - extraction: Extraction results (format, matrix, validation)
#'   - rows: List of output rows by item
#'
#' @export
process_ranking_question <- function(data, question_info, option_info,
                                    banner_data_list, banner_info, internal_keys,
                                    weights_list = NULL, config = NULL,
                                    show_top_n = TRUE, top_n = 3) {
  
  # Extract ranking data
  extraction <- extract_ranking_data(data, question_info, option_info, config)
  
  # Get configuration values
  decimal_places_percent <- if (!is.null(config$decimal_places_percent)) {
    config$decimal_places_percent
  } else {
    0
  }
  
  decimal_places_index <- if (!is.null(config$decimal_places_index)) {
    config$decimal_places_index
  } else {
    1
  }
  
  # Generate output rows for each item
  rows_by_item <- list()
  
  for (item_name in extraction$items) {
    rows <- create_ranking_rows_for_item(
      ranking_matrix = extraction$matrix,
      item_name = item_name,
      banner_data_list = banner_data_list,
      banner_info = banner_info,
      internal_keys = internal_keys,
      weights_list = weights_list,
      show_top_n = show_top_n,
      top_n = top_n,
      num_positions = extraction$num_positions,
      decimal_places_percent = decimal_places_percent,
      decimal_places_index = decimal_places_index,
      add_legend = TRUE
    )
    
    rows_by_item[[item_name]] <- rows
  }
  
  return(list(
    extraction = extraction,
    rows = rows_by_item
  ))
}


# ==============================================================================
# MODULE METADATA
# ==============================================================================

# Module: ranking.R (Main Orchestrator)
# Phase: 6 (Ranking)
# Status: Complete
# Version: 1.0.0
# 
# Sub-modules loaded:
#   1. direction.R - Rank direction normalization (2 functions)
#   2. validation.R - Data quality validation (2 functions)
#   3. extraction.R - Extract ranking data (3 functions)
#   4. calculations.R - Statistical calculations (5 functions)
#   5. output.R - Generate output rows (1 function)
#
# Total functions available: 13
# Total lines: ~3,500
#
# Public API:
#   - process_ranking_question() - End-to-end processing
#   - All module functions accessible directly
#
# Dependencies:
#   - Phase 1: Core utilities, logging
#   - Phase 2: Data loading
#   - Phase 5: Weighting, significance testing
#
# Testing:
#   - See tests/test_phase6.R for comprehensive tests

# ==============================================================================
