# ==============================================================================
# MODULE: crosstabs_significance.R
# ==============================================================================
# Purpose: Statistical significance testing for crosstabs
#
# This module provides:
# - Pairwise significance testing for proportions and means
# - Significance row generation with column letter mapping
# - Support for weighted and unweighted data
# - Bonferroni correction for multiple comparisons
#
# Version: 10.0
# TRS Compliance: v1.0
# ==============================================================================

# ==============================================================================
# SIGNIFICANCE TESTING
# ==============================================================================

#' Run pairwise significance tests
#'
#' Tests whether each column is significantly higher than other columns.
#' Returns significance letters for each column indicating which other
#' columns it is significantly higher than.
#'
#' @param row_data List, test data by column
#' @param row_type Character, test type ("proportion", "topbox", "mean", "index")
#' @param banner_structure List with column names and letters
#' @param alpha Numeric, p-value threshold (default: 0.05)
#' @param bonferroni_correction Logical, apply Bonferroni correction
#' @param min_base Integer, minimum base size for testing
#' @param is_weighted Logical, whether data is weighted
#' @return List of significance results (column_name -> significance letters)
#' @export
run_significance_tests_for_row <- function(row_data, row_type, banner_structure,
                                          alpha = DEFAULT_ALPHA,
                                          bonferroni_correction = TRUE,
                                          min_base = DEFAULT_MIN_BASE,
                                          is_weighted = FALSE) {
  if (is.null(row_data) || length(row_data) == 0) return(list())
  if (is.null(banner_structure) || is.null(banner_structure$letters)) return(list())

  if (!setequal(names(row_data), banner_structure$column_names)) {
    # TRS Refusal: BUG_SIG_LETTER_MISMATCH
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

  sig_results <- list()
  column_names <- names(row_data)

  for (i in seq_along(row_data)) {
    higher_than <- character(0)

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

      if (test_result$significant && test_result$higher) {
        col_letter <- banner_structure$letters[
          banner_structure$column_names == column_names[j]
        ]
        if (length(col_letter) > 0) {
          higher_than <- c(higher_than, col_letter)
        }
      }
    }

    sig_results[[column_names[i]]] <- paste(higher_than, collapse = "")
  }

  return(sig_results)
}

# ==============================================================================
# SIGNIFICANCE ROW GENERATION
# ==============================================================================

#' Add significance row to question table
#'
#' Creates a "Sig." row showing which columns are significantly higher
#' than other columns. Handles multiple banner questions properly.
#'
#' @param test_data List, test data by column
#' @param banner_info List, banner structure with banner_info nested list
#' @param row_type Character, test type
#' @param internal_columns Character vector, all internal column keys
#' @param alpha Numeric, p-value threshold
#' @param bonferroni_correction Logical
#' @param min_base Integer
#' @param is_weighted Logical
#' @return Data frame with sig row or NULL
#' @export
add_significance_row <- function(test_data, banner_info, row_type, internal_columns,
                                alpha = DEFAULT_ALPHA,
                                bonferroni_correction = TRUE,
                                min_base = DEFAULT_MIN_BASE,
                                is_weighted = FALSE) {
  if (is.null(test_data) || length(test_data) < 2) return(NULL)

  sig_values <- setNames(rep("", length(internal_columns)), internal_columns)

  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  if (total_key %in% names(sig_values)) {
    sig_values[total_key] <- "-"
  }

  for (banner_code in names(banner_info$banner_info)) {
    banner_cols <- banner_info$banner_info[[banner_code]]$internal_keys
    banner_test_data <- test_data[names(test_data) %in% banner_cols]

    if (length(banner_test_data) > 1) {
      banner_structure <- list(
        column_names = names(banner_test_data),
        letters = banner_info$banner_info[[banner_code]]$letters
      )

      sig_results <- run_significance_tests_for_row(
        banner_test_data, row_type, banner_structure,
        alpha, bonferroni_correction, min_base,
        is_weighted = is_weighted
      )

      for (col_key in names(sig_results)) {
        sig_values[col_key] <- sig_results[[col_key]]
      }
    }
  }

  sig_row <- data.frame(
    RowLabel = "",
    RowType = SIG_ROW_TYPE,
    stringsAsFactors = FALSE
  )

  for (col_key in internal_columns) {
    sig_row[[col_key]] <- sig_values[col_key]
  }

  return(sig_row)
}

# ==============================================================================
# END OF MODULE: crosstabs_significance.R
# ==============================================================================
