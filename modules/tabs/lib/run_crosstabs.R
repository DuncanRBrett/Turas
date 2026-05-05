# ==============================================================================
# CROSSTABS - TURAS V10.2 (Phase 4 Refactoring)
# ==============================================================================
# Enterprise-grade survey crosstabs - Refactored orchestrator
#
# This file is now a lean orchestrator that coordinates the analysis flow.
# All heavy lifting has been extracted to focused modules in crosstabs/:
#
#   crosstabs/crosstabs_config.R  - Configuration loading
#   crosstabs/data_setup.R        - Data and structure loading
#   crosstabs/analysis_runner.R   - Question processing
#   crosstabs/workbook_builder.R  - Excel output creation
#   crosstabs/checkpoint.R        - Checkpoint system
#
# V10.2 REFACTORING:
# - Reduced from ~1,700 lines to ~350 lines (80% reduction)
# - Converted procedural code to function calls
# - Maintained 100% backward compatibility
#
# PREVIOUS VERSIONS:
# V10.0 - Production release with all fixes applied
# V10.1 - Phase 2/3 utility extraction
# ==============================================================================

SCRIPT_VERSION <- "10.2"

# ==============================================================================
# TRS GUARD LAYER - Must be loaded FIRST
# ==============================================================================

# Determine script directory for sourcing
script_dir <- if (exists("toolkit_path")) dirname(toolkit_path) else getwd()

# Cache lib directory for Phase 2+ subdirectory support
# This MUST be set before sourcing any modules that use tabs_lib_path()
assign(".tabs_lib_dir", script_dir, envir = globalenv())

# TRS Guard Layer - MUST be loaded before any TRS refusal calls
source(file.path(script_dir, "00_guard.R"))

# ==============================================================================
# TRS INFRASTRUCTURE
# ==============================================================================

.source_trs_infrastructure_tabs <- function() {
  possible_paths <- c(
    file.path(script_dir, "..", "..", "shared", "lib"),
    file.path(script_dir, "..", "shared", "lib"),
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
  .source_trs_infrastructure_tabs()
}, error = function(e) {
  message(sprintf("[TRS INFO] TABS_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# Create TRS run state for tracking events
trs_state <- if (exists("turas_run_state_new", mode = "function")) {
  turas_run_state_new("TABS")
} else {
  NULL
}

# ==============================================================================
# DEPENDENCY CHECKS
# ==============================================================================

check_dependencies <- function() {
  required_packages <- c("openxlsx", "readxl")
  missing <- character(0)

  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing <- c(missing, pkg)
    }
  }

  if (length(missing) > 0) {
    tabs_refuse(
      code = "PKG_MISSING_PACKAGES",
      title = "Missing Required Packages",
      problem = paste0("Required packages not installed: ", paste(missing, collapse = ", ")),
      why_it_matters = "Crosstab analysis requires these packages to function properly.",
      how_to_fix = c(
        "Install the missing packages with:",
        paste0("  install.packages(c(", paste(sprintf('"%s"', missing), collapse = ", "), "))")
      ),
      missing = missing
    )
  }

  if (!requireNamespace("lobstr", quietly = TRUE)) {
    message("Note: 'lobstr' package not found. Memory monitoring will be disabled.")
  }

  invisible(NULL)
}

check_dependencies()

# ==============================================================================
# CONSTANTS
# ==============================================================================

TOTAL_COLUMN <- "Total"
SIG_ROW_TYPE <- "Sig."
SIG2_ROW_TYPE <- "Sig.2"   # Secondary significance level row (dual-alpha feature, V10.10)
BASE_ROW_LABEL <- "Base (n=)"
UNWEIGHTED_BASE_LABEL <- "Base (unweighted)"
WEIGHTED_BASE_LABEL <- "Base (weighted)"
EFFECTIVE_BASE_LABEL <- "Effective base"
FREQUENCY_ROW_TYPE <- "Frequency"
COLUMN_PCT_ROW_TYPE <- "Column %"
ROW_PCT_ROW_TYPE <- "Row %"
AVERAGE_ROW_TYPE <- "Average"
INDEX_ROW_TYPE <- "Index"
SCORE_ROW_TYPE <- "Score"

MINIMUM_BASE_SIZE <- 30
VERY_SMALL_BASE_SIZE <- 10
DEFAULT_ALPHA <- 0.05
DEFAULT_MIN_BASE <- 30

MAX_EXCEL_COLUMNS <- 16384
MAX_EXCEL_ROWS <- 1048576

BATCH_WRITE_THRESHOLD <- 100
VECTORIZE_THRESHOLD <- 50
CHECKPOINT_FREQUENCY <- 10

MEMORY_WARNING_GIB <- 6
MEMORY_CRITICAL_GIB <- 8

MAX_DECIMAL_PLACES <- 6

# ==============================================================================
# LOAD CORE DEPENDENCIES
# ==============================================================================

source(file.path(script_dir, "shared_functions.R"))
source(file.path(script_dir, "validation.R"))
source(file.path(script_dir, "weighting.R"))
source(file.path(script_dir, "ranking.R"))
source(file.path(script_dir, "banner.R"))
source(file.path(script_dir, "cell_calculator.R"))
source(file.path(script_dir, "question_dispatcher.R"))
source(file.path(script_dir, "standard_processor.R"))
source(file.path(script_dir, "numeric_processor.R"))
source(file.path(script_dir, "allocation_processor.R"))
source(file.path(script_dir, "excel_writer.R"))
source(file.path(script_dir, "banner_indices.R"))
source(file.path(script_dir, "config_loader.R"))
source(file.path(script_dir, "question_orchestrator.R"))
source(file.path(script_dir, "composite_processor.R"))
source(file.path(script_dir, "summary_builder.R"))

# ==============================================================================
# LOAD PHASE 4 MODULES
# ==============================================================================

tabs_source("crosstabs", "checkpoint.R")
tabs_source("crosstabs", "crosstabs_config.R")
tabs_source("crosstabs", "data_setup.R")
tabs_source("crosstabs", "analysis_runner.R")
tabs_source("crosstabs", "workbook_builder.R")

# V10.3: HTML Report module (loaded conditionally, sources its own submodules)
tabs_source("html_report", "99_html_report_main.R")

# ==============================================================================
# SIGNIFICANCE TESTING FUNCTIONS
# ==============================================================================
# These functions are kept here as they may be used by other modules

#' Run pairwise significance tests
#'
#' @param row_data List, test data by column
#' @param row_type Character, test type
#' @param banner_structure List with column names and letters
#' @param alpha Numeric, p-value threshold
#' @param bonferroni_correction Logical
#' @param min_base Integer
#' @param is_weighted Logical
#' @return List of significance results
#' @export
run_significance_tests_for_row <- function(row_data, row_type, banner_structure,
                                           alpha = DEFAULT_ALPHA,
                                           bonferroni_correction = TRUE,
                                           min_base = DEFAULT_MIN_BASE,
                                           is_weighted = FALSE,
                                           alpha2 = NULL) {
  if (is.null(row_data) || length(row_data) == 0) return(list())
  if (is.null(banner_structure) || is.null(banner_structure$letters)) return(list())

  if (!setequal(names(row_data), banner_structure$column_names)) {
    tabs_refuse(
      code = "BUG_SIG_LETTER_MISMATCH",
      title = "Significance Letter Mapping Mismatch",
      problem = "Banner column names don't match test data keys.",
      why_it_matters = "Significance letters would be incorrectly mapped to columns.",
      how_to_fix = c(
        "This is an internal error - please report it",
        "Include the error details in your report"
      ),
      expected = banner_structure$column_names,
      observed = names(row_data),
      details = paste0("Test data keys: ", paste(head(names(row_data), 5), collapse = ", "),
                       "\nBanner columns: ", paste(head(banner_structure$column_names, 5), collapse = ", "))
    )
  }

  num_comparisons <- choose(length(row_data), 2)
  if (num_comparisons == 0) return(list())

  alpha_adj <- alpha
  if (bonferroni_correction && num_comparisons > 0) {
    alpha_adj <- alpha / num_comparisons
  }

  # Dual-alpha: pre-compute secondary threshold once (V10.10).
  # When alpha2 is provided we re-use the p_value from the single test call
  # rather than running every test twice. This keeps dual-alpha performance
  # identical to single-alpha performance.
  dual <- !is.null(alpha2)
  alpha2_adj <- if (dual) {
    if (bonferroni_correction && num_comparisons > 0) alpha2 / num_comparisons else alpha2
  } else NULL

  sig_results  <- list()
  sig_results2 <- if (dual) list() else NULL
  column_names <- names(row_data)

  for (i in seq_along(row_data)) {
    higher_than  <- character(0)
    higher_than2 <- if (dual) character(0) else NULL

    for (j in seq_along(row_data)) {
      if (i == j) next

      test_result <- if (row_type %in% c("proportion", "topbox")) {
        weighted_z_test_proportions(
          row_data[[i]]$count, row_data[[i]]$base,
          row_data[[j]]$count, row_data[[j]]$base,
          row_data[[i]]$eff_n, row_data[[j]]$eff_n,
          is_weighted = is_weighted,
          min_base = min_base,
          alpha = alpha_adj
        )
      } else if (row_type %in% c("mean", "index")) {
        weighted_t_test_means(
          row_data[[i]]$values, row_data[[j]]$values,
          row_data[[i]]$weights, row_data[[j]]$weights,
          min_base = min_base,
          alpha = alpha_adj
        )
      } else {
        list(significant = FALSE, p_value = NA_real_, higher = FALSE)
      }

      # Primary significance decision (uses pre-compared $significant from test)
      if (test_result$significant && test_result$higher) {
        col_letter <- banner_structure$letters[
          banner_structure$column_names == column_names[j]
        ]
        if (length(col_letter) > 0) {
          higher_than <- c(higher_than, col_letter)
        }
      }

      # Secondary significance: re-use p_value, compare against alpha2_adj.
      # No second test call needed — the expensive computation is already done.
      if (dual && test_result$higher && !is.na(test_result$p_value) &&
          test_result$p_value < alpha2_adj) {
        col_letter <- banner_structure$letters[
          banner_structure$column_names == column_names[j]
        ]
        if (length(col_letter) > 0) {
          higher_than2 <- c(higher_than2, col_letter)
        }
      }
    }

    sig_results[[column_names[i]]] <- paste(higher_than, collapse = "")
    if (dual) sig_results2[[column_names[i]]] <- paste(higher_than2, collapse = "")
  }

  if (dual) return(list(primary = sig_results, secondary = sig_results2))
  return(sig_results)
}


#' Add significance row
#'
#' Computes pairwise significance letters for a data row and returns one or
#' two sig rows (data frames). When \code{alpha_secondary} is non-NULL a
#' second row with \code{RowType = "Sig.2"} is appended for the dual-alpha
#' HTML toggle feature (V10.10).
#'
#' @param test_data List, test data by column
#' @param banner_info List, banner structure
#' @param row_type Character, test type
#' @param internal_columns Character vector
#' @param alpha Numeric, primary p-value threshold
#' @param bonferroni_correction Logical
#' @param min_base Integer
#' @param is_weighted Logical
#' @param alpha_secondary Numeric or NULL. When non-NULL, a secondary sig row
#'   is calculated and appended. Default NULL (feature disabled).
#' @return Data frame with one sig row (primary only) or two rows (primary +
#'   secondary), or NULL if fewer than two columns in test_data.
#' @export
add_significance_row <- function(test_data, banner_info, row_type, internal_columns,
                                 alpha = DEFAULT_ALPHA,
                                 bonferroni_correction = TRUE,
                                 min_base = DEFAULT_MIN_BASE,
                                 is_weighted = FALSE,
                                 alpha_secondary = NULL) {
  if (is.null(test_data) || length(test_data) < 2) return(NULL)

  # When dual-alpha is active, label rows with the confidence level so Excel
  # output is self-documenting. When single-alpha, blank label preserves the
  # existing format exactly (backward compatible).
  dual_mode <- !is.null(alpha_secondary)

  primary_label   <- if (dual_mode) alpha_to_confidence_label(alpha) else ""
  secondary_label <- if (dual_mode) alpha_to_confidence_label(alpha_secondary) else NULL

  # Initialise sig value vectors for primary (and optionally secondary).
  total_key  <- paste0("TOTAL::", TOTAL_COLUMN)
  sig_values  <- setNames(rep("", length(internal_columns)), internal_columns)
  sig_values2 <- if (dual_mode) setNames(rep("", length(internal_columns)), internal_columns) else NULL

  if (total_key %in% names(sig_values)) {
    sig_values[total_key]  <- "-"
    if (dual_mode) sig_values2[total_key] <- "-"
  }

  for (banner_code in names(banner_info$banner_info)) {
    banner_cols      <- banner_info$banner_info[[banner_code]]$internal_keys
    banner_test_data <- test_data[names(test_data) %in% banner_cols]

    if (length(banner_test_data) > 1) {
      banner_structure <- list(
        column_names = names(banner_test_data),
        letters      = banner_info$banner_info[[banner_code]]$letters
      )
      # Single call: p-values computed once; both alpha thresholds applied
      # inside run_significance_tests_for_row when alpha2 is provided.
      sig_results <- run_significance_tests_for_row(
        banner_test_data, row_type, banner_structure,
        alpha, bonferroni_correction, min_base,
        is_weighted = is_weighted,
        alpha2 = alpha_secondary
      )

      if (dual_mode) {
        # dual path: sig_results is list(primary=..., secondary=...)
        for (col_key in names(sig_results$primary))
          sig_values[col_key]  <- sig_results$primary[[col_key]]
        for (col_key in names(sig_results$secondary))
          sig_values2[col_key] <- sig_results$secondary[[col_key]]
      } else {
        for (col_key in names(sig_results)) sig_values[col_key] <- sig_results[[col_key]]
      }
    }
  }

  # Assemble primary row
  primary_row <- data.frame(RowLabel = primary_label, RowType = SIG_ROW_TYPE,
                             stringsAsFactors = FALSE)
  for (col_key in internal_columns) primary_row[[col_key]] <- sig_values[col_key]

  if (!dual_mode) return(primary_row)

  # Assemble secondary row and combine
  secondary_row <- data.frame(RowLabel = secondary_label, RowType = SIG2_ROW_TYPE,
                               stringsAsFactors = FALSE)
  for (col_key in internal_columns) secondary_row[[col_key]] <- sig_values2[col_key]

  rbind(primary_row, secondary_row)
}


#' Write question table (Sig overlay safeguards applied)
#'
#' @param wb Workbook
#' @param sheet Character
#' @param data_table Data frame
#' @param banner_info List
#' @param internal_keys Character vector
#' @param styles List
#' @param current_row Integer
#' @return Integer, next row
#' @export
write_question_table_fast <- function(wb, sheet, data_table, banner_info,
                                       internal_keys, styles, current_row) {
  if (is.null(data_table) || nrow(data_table) == 0) return(current_row)

  n_rows <- nrow(data_table)
  n_data_cols <- length(banner_info$columns)

  label_col <- as.character(data_table$RowLabel)
  type_col <- as.character(data_table$RowType)

  data_matrix <- matrix(NA_real_, nrow = n_rows, ncol = n_data_cols)

  sig_cells <- list()

  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  total_col_idx <- which(internal_keys == total_key)

  for (i in seq_along(internal_keys)) {
    internal_key <- internal_keys[i]
    if (internal_key %in% names(data_table)) {
      col_data <- data_table[[internal_key]]

      sig_row_types <- c(SIG_ROW_TYPE, SIG2_ROW_TYPE)
      if (any(type_col %in% sig_row_types)) {
        sig_indices <- which(type_col %in% sig_row_types)
        for (sig_idx in sig_indices) {
          sig_val <- col_data[sig_idx]

          if (!is.na(sig_val) && is.character(sig_val) && nchar(sig_val) > 0) {
            if (length(total_col_idx) == 0 || i != total_col_idx) {
              sig_cells[[length(sig_cells) + 1]] <- list(
                row = current_row + sig_idx - 1,
                col = i + 2,
                value = sig_val
              )
            }
          }
          col_data[sig_idx] <- NA
        }
      }

      data_matrix[, i] <- suppressWarnings(as.numeric(col_data))
    }
  }

  openxlsx::writeData(wb, sheet, label_col,
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::writeData(wb, sheet, type_col,
                      startRow = current_row, startCol = 2, colNames = FALSE)

  openxlsx::writeData(wb, sheet, data_matrix,
                      startRow = current_row, startCol = 3, colNames = FALSE)

  for (sig_cell in sig_cells) {
    openxlsx::writeData(wb, sheet, sig_cell$value,
                        startRow = sig_cell$row, startCol = sig_cell$col,
                        colNames = FALSE)
  }

  for (row_idx in seq_len(n_rows)) {
    row_type <- type_col[row_idx]
    style <- get_row_style(row_type, styles)

    openxlsx::addStyle(wb, sheet, style,
                       rows = current_row + row_idx - 1,
                       cols = 3:(2 + n_data_cols), gridExpand = TRUE)
  }

  return(current_row + n_rows)
}


#' Format value for output
#'
#' @param value Numeric value
#' @param type Value type
#' @param decimal_places_percent Integer
#' @param decimal_places_ratings Integer
#' @param decimal_places_index Integer
#' @param decimal_places_numeric Integer
#' @return Formatted numeric or NA_real_
#' @export
format_output_value <- function(value, type = "frequency",
                                decimal_places_percent = 0,
                                decimal_places_ratings = 1,
                                decimal_places_index = 1,
                                decimal_places_numeric = 1) {
  if (is.null(value) || is.na(value)) return(NA_real_)

  formatted_value <- switch(type,
    "percent" = round(as.numeric(value), decimal_places_percent),
    "rating" = round(as.numeric(value), decimal_places_ratings),
    "index" = round(as.numeric(value), decimal_places_index),
    "numeric" = round(as.numeric(value), decimal_places_numeric),
    "frequency" = round(as.numeric(value), 0),
    round(as.numeric(value), 2)
  )

  return(formatted_value)
}


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

# Print TRS start banner
if (exists("turas_print_start_banner", mode = "function")) {
  turas_print_start_banner("TABS", SCRIPT_VERSION)
} else {
  print_toolkit_header("Crosstab Analysis - Turas v10.2")
}

# Validate config file exists
validation_check <- validate_config_file(config_file)
if (is.list(validation_check) && identical(validation_check$status, "REFUSED")) {
  cat("\n=== TURAS ERROR ===\n")
  cat("Code:", validation_check$code, "\n")
  cat("Message:", validation_check$message, "\n")
  cat("Fix:", validation_check$how_to_fix, "\n")
  cat("==================\n\n")
  return(validation_check)
}

# Record start time
start_time <- Sys.time()

# ==============================================================================
# STEP 1: LOAD CONFIGURATION
# ==============================================================================

config_result <- load_crosstabs_config(config_file)
if (is.list(config_result) && identical(config_result$status, "REFUSED")) {
  cat("\n=== TURAS ERROR ===\n")
  cat("Code:", config_result$code, "\n")
  cat("Message:", config_result$message, "\n")
  cat("Fix:", config_result$how_to_fix, "\n")
  cat("==================\n\n")
  return(config_result)
}

# ==============================================================================
# STEP 2: LOAD DATA
# ==============================================================================

data_result <- load_crosstabs_data(config_result)
if (is.list(data_result) && identical(data_result$status, "REFUSED")) {
  cat("\n=== TURAS ERROR ===\n")
  cat("Code:", data_result$code, "\n")
  cat("Message:", data_result$message, "\n")
  cat("Fix:", data_result$how_to_fix, "\n")
  cat("==================\n\n")
  return(data_result)
}

# ==============================================================================
# STEP 3: RUN ANALYSIS
# ==============================================================================

analysis_result <- run_crosstabs_analysis(
  config_result,
  data_result,
  checkpoint_frequency = CHECKPOINT_FREQUENCY,
  total_column = TOTAL_COLUMN
)

# ==============================================================================
# STEP 4: CREATE EXCEL OUTPUT
# ==============================================================================

workbook_result <- create_crosstabs_workbook(
  all_results = analysis_result$all_results,
  composite_results = analysis_result$composite_results,
  composite_defs = data_result$composite_defs,
  survey_structure = data_result$survey_structure,
  survey_data = data_result$survey_data,
  banner_info = analysis_result$banner_info,
  config_obj = config_result$config_obj,
  error_log = analysis_result$error_log,
  trs_state = trs_state,
  run_status = analysis_result$run_status,
  skipped_questions = analysis_result$skipped_questions,
  partial_questions = analysis_result$partial_questions,
  processed_questions = analysis_result$processed_questions,
  crosstab_questions = data_result$crosstab_questions,
  effective_n = data_result$effective_n,
  master_weights = data_result$master_weights,
  output_path = config_result$output_path,
  script_version = SCRIPT_VERSION,
  total_column = TOTAL_COLUMN,
  very_small_base = VERY_SMALL_BASE_SIZE
)

# ==============================================================================
# STEP 4b: GENERATE HTML REPORT (if enabled)
# ==============================================================================

if (isTRUE(config_result$config_obj$html_report)) {
  html_output_path <- sub("\\.xlsx$", ".html", config_result$output_path)

  # Attach config file path for AI insights sidecar detection
  config_result$config_obj$config_file_path <- config_result$config_file

  html_result <- tryCatch({
    generate_html_report(
      all_results = analysis_result$all_results,
      banner_info = analysis_result$banner_info,
      config_obj = config_result$config_obj,
      output_path = html_output_path,
      survey_structure = data_result$survey_structure
    )
  }, error = function(e) {
    cat("\n[WARNING] HTML report generation failed:", e$message, "\n")
    cat("  Traceback:\n")
    cat(paste("  ", traceback(e), collapse = "\n"), "\n")
    cat("  The Excel output was not affected.\n\n")
    NULL
  })

  if (!is.null(html_result) && html_result$status == "PASS") {
    cat(sprintf("  HTML Report: %s (%.1f MB)\n",
        html_result$output_file, html_result$file_size_mb))

    # Minify for client delivery (if requested via Shiny checkbox)
    if (exists("turas_prepare_deliverable", mode = "function")) {
      turas_prepare_deliverable(html_output_path)
    }
  }
}

# ==============================================================================
# STEP 4c: GENERATE STATS PACK
# ==============================================================================

stats_pack_file <- NULL
generate_stats_pack_flag <- isTRUE(
  toupper(config_result$config_obj$generate_stats_pack %||% "Y") == "Y"
) || isTRUE(getOption("turas.generate_stats_pack", FALSE))

if (generate_stats_pack_flag && exists("turas_write_stats_pack", mode = "function")) {
  stats_pack_file <- tryCatch({
    generate_tabs_stats_pack(
      config_result  = config_result,
      data_result    = data_result,
      analysis_result = analysis_result,
      workbook_result = workbook_result,
      start_time     = start_time,
      script_version = SCRIPT_VERSION
    )
  }, error = function(e) {
    cat(sprintf("\n[WARNING] Stats pack generation failed: %s\n", conditionMessage(e)))
    NULL
  })
  if (!is.null(stats_pack_file)) {
    cat(sprintf("  Stats Pack: %s\n", basename(stats_pack_file)))
  }
}

# ==============================================================================
# STEP 5: COMPLETION SUMMARY
# ==============================================================================

elapsed <- difftime(Sys.time(), start_time, units = "secs")

# Get run result for final banner
run_result <- workbook_result$run_result

# Print final banner
if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
  turas_print_final_banner(run_result)
} else {
  cat("\n")
  cat(paste(rep("=", 80), collapse=""), "\n")
  cat("ANALYSIS COMPLETE - TURAS V10.2 (REFACTORED)\n")
  cat(paste(rep("=", 80), collapse=""), "\n\n")

  if (analysis_result$run_status == "PARTIAL") {
    cat("  TRS Status: PARTIAL (see Run_Status sheet for details)\n")
    if (length(analysis_result$skipped_questions) > 0) {
      cat(sprintf("  Questions skipped: %d\n", length(analysis_result$skipped_questions)))
    }
    if (length(analysis_result$partial_questions) > 0) {
      cat(sprintf("  Questions with missing sections: %d\n", length(analysis_result$partial_questions)))
    }
  } else {
    cat("  TRS Status: PASS\n")
  }
  cat("\n")
}

cat("  Project:", workbook_result$project_name, "\n")
cat("  Questions:", length(analysis_result$all_results), "\n")
cat("  Responses:", nrow(data_result$survey_data), "\n")

if (config_result$config_obj$apply_weighting) {
  cat("  Weighting:", config_result$config_obj$weight_variable, "\n")
  cat("  Effective N:", data_result$effective_n, "\n")
}

cat("  Significance:", if (config_result$config_obj$enable_significance_testing) "ENABLED" else "disabled", "\n")
if (config_result$config_obj$enable_significance_testing) {
  cat("  Alpha (p-value):", sprintf("%.3f", config_result$config_obj$alpha), "\n")
}
cat("  Output:", workbook_result$output_path, "\n")
cat("  Duration:", format_seconds(as.numeric(elapsed)), "\n")

if (nrow(analysis_result$error_log) > 0) {
  cat("  Issues:", nrow(analysis_result$error_log), "(see Error Log)\n")
}

cat("\n")
cat("TURAS Tabs V10.8.1\n")
cat("\n")
cat(paste(rep("=", 80), collapse=""), "\n")

# ==============================================================================
# STATS PACK HELPER
# ==============================================================================

#' Generate Tabs Stats Pack
#'
#' Builds the diagnostic payload from crosstab results and writes the stats
#' pack Excel workbook alongside the main output.
#'
#' @keywords internal
generate_tabs_stats_pack <- function(config_result, data_result,
                                     analysis_result, workbook_result,
                                     start_time, script_version) {

  if (!exists("turas_write_stats_pack", mode = "function")) return(NULL)

  # Output path: derive from main output
  main_out <- config_result$output_path %||% "tabs_output.xlsx"
  output_path <- sub("(\\.xlsx)$", "_stats_pack.xlsx", main_out, ignore.case = TRUE)
  if (identical(output_path, main_out)) {
    output_path <- paste0(tools::file_path_sans_ext(main_out), "_stats_pack.xlsx")
  }

  config_obj <- config_result$config_obj

  # Data receipt
  data_receipt <- list(
    file_name = basename(config_obj$data_file %||% "unknown"),
    n_rows    = nrow(data_result$survey_data),
    n_cols    = ncol(data_result$survey_data)
  )

  # Data used
  n_questions <- length(analysis_result$all_results)
  n_skipped <- length(analysis_result$skipped_questions)
  n_partial <- length(analysis_result$partial_questions)

  data_used <- list(
    n_respondents      = nrow(data_result$survey_data),
    n_excluded         = 0L,
    questions_total    = n_questions + n_skipped,
    questions_analysed = n_questions,
    questions_skipped  = n_skipped,
    questions_partial  = n_partial
  )

  # Weight diagnostics
  is_weighted <- isTRUE(config_obj$apply_weighting)
  weight_var <- if (is_weighted) config_obj$weight_variable else NULL
  eff_n_val <- data_result$effective_n %||% NA

  # Significance testing parameters
  sig_enabled <- isTRUE(config_obj$enable_significance_testing)
  alpha_val <- config_obj$alpha %||% 0.05
  min_base_val <- config_obj$min_base %||% 30

  # TRS summary
  run_result <- workbook_result$run_result
  n_events <- length(run_result$events %||% list())
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
    if (remainder > 0) parts <- c(parts, sprintf("%d info event(s)", remainder))
    paste(parts, collapse = ", ")
  }

  duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  assumptions <- list(
    "Analysis Type"              = "Cross-tabulation",
    "Questions Processed"        = as.character(n_questions),
    "Questions Skipped"          = as.character(n_skipped),
    "Weighting"                  = if (is_weighted) sprintf("Yes — %s", weight_var) else "No",
    "Effective N"                = if (!is.na(eff_n_val)) format(round(eff_n_val), big.mark = ",") else "—",
    "Significance Testing"       = if (sig_enabled) "Enabled" else "Disabled",
    "Alpha (p-value threshold)"  = if (sig_enabled) sprintf("%.3f", alpha_val) else "—",
    "Minimum Base Size"          = as.character(min_base_val),
    "Bonferroni Correction"      = if (sig_enabled && isTRUE(config_obj$bonferroni_correction)) "Applied" else "Not applied",
    "HTML Report"                = if (isTRUE(config_obj$html_report)) "Generated" else "Not requested",
    "AI Insights"                = if (isTRUE(config_obj$ai_insights)) "Enabled" else "Disabled",
    "TRS Status"                 = run_result$status %||% "PASS",
    "TRS Events"                 = trs_summary
  )

  config_echo <- list(
    data_file      = config_obj$data_file,
    structure_file = config_obj$structure_file,
    output_file    = config_result$output_path,
    apply_weighting = config_obj$apply_weighting,
    weight_variable = config_obj$weight_variable,
    enable_significance_testing = config_obj$enable_significance_testing
  )

  payload <- list(
    module           = "TABS",
    project_name     = workbook_result$project_name   %||% NULL,
    analyst_name     = config_obj$analyst_name         %||% NULL,
    research_house   = config_obj$research_house       %||% NULL,
    run_timestamp    = start_time,
    turas_version    = script_version,
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = if (duration_secs > 0 && duration_secs < 86400) duration_secs else NA,
    data_receipt     = data_receipt,
    data_used        = data_used,
    assumptions      = assumptions,
    run_result       = run_result,
    packages         = c("openxlsx", "readxl"),
    config_echo      = config_echo
  )

  result <- turas_write_stats_pack(payload, output_path)

  if (!is.null(result)) {
    message(sprintf("[TRS INFO] TABS: Stats pack written: %s", basename(output_path)))
  }

  output_path
}

# ==============================================================================
# END OF SCRIPT
# ==============================================================================
