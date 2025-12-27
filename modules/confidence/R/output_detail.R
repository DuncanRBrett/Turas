# ==============================================================================
# OUTPUT DETAIL SHEETS - TURAS V10.1
# ==============================================================================
# Detail sheet generators for Proportions, Means, and NPS analyses
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Extracted from 07_output.R (2025-12-27)
#          - Proportions detail sheet and dataframe builder
#          - Means detail sheet and dataframe builder
#          - NPS detail sheet and dataframe builder
#
# DEPENDENCIES:
# - openxlsx (for Excel writing)
# - output_formatting.R (for apply_numeric_formatting)
#
# FUNCTIONS:
# - add_proportions_detail_sheet(): Add proportions detail sheet to workbook
# - build_proportions_dataframe(): Convert proportion results to dataframe
# - add_means_detail_sheet(): Add means detail sheet to workbook
# - build_means_dataframe(): Convert mean results to dataframe
# - add_nps_detail_sheet(): Add NPS detail sheet to workbook
# - build_nps_dataframe(): Convert NPS results to dataframe
# ==============================================================================

OUTPUT_DETAIL_VERSION <- "10.1"


# ==============================================================================
# PROPORTIONS DETAIL SHEET
# ==============================================================================

#' Add proportions detail sheet (internal)
#' @keywords internal
add_proportions_detail_sheet <- function(wb, prop_results, decimal_sep) {

  openxlsx::addWorksheet(wb, "Proportions_Detail")

  # Title
  openxlsx::writeData(wb, "Proportions_Detail", "PROPORTIONS - DETAILED RESULTS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Proportions_Detail",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Convert results list to data frame
  prop_df <- build_proportions_dataframe(prop_results)

  if (nrow(prop_df) == 0) {
    openxlsx::writeData(wb, "Proportions_Detail", "No proportion analyses performed",
                        startCol = 1, startRow = 3)
    return(invisible(NULL))
  }

  # Write numeric data (not converted to strings)
  openxlsx::writeData(wb, "Proportions_Detail", prop_df, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Apply Excel number formatting to preserve numeric values
  apply_numeric_formatting(wb, "Proportions_Detail", 4, 1, prop_df, decimal_sep)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Proportions_Detail", header_style, rows = 3,
                     cols = 1:ncol(prop_df), gridExpand = TRUE)

  # Auto-size columns
  openxlsx::setColWidths(wb, "Proportions_Detail", cols = 1:ncol(prop_df), widths = "auto")
}


#' Build proportions dataframe from results list (internal)
#' @keywords internal
build_proportions_dataframe <- function(prop_results) {

  if (length(prop_results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(prop_results)) {
    q_result <- prop_results[[q_id]]

    # Base info
    base_row <- list(
      Question_ID = q_id,
      Category = ifelse(!is.null(q_result$category), q_result$category, "Total"),
      Proportion = ifelse(!is.null(q_result$proportion), q_result$proportion, NA),
      Sample_Size = ifelse(!is.null(q_result$n), q_result$n, NA),
      Effective_n = ifelse(!is.null(q_result$n_eff), q_result$n_eff, NA)
    )

    # MOE
    if (!is.null(q_result$moe_normal)) {
      base_row$MOE_Normal_Lower <- q_result$moe_normal$lower
      base_row$MOE_Normal_Upper <- q_result$moe_normal$upper
      base_row$MOE <- q_result$moe_normal$moe
    }

    # Wilson
    if (!is.null(q_result$wilson)) {
      base_row$Wilson_Lower <- q_result$wilson$lower
      base_row$Wilson_Upper <- q_result$wilson$upper
    }

    # Bootstrap
    if (!is.null(q_result$bootstrap)) {
      base_row$Bootstrap_Lower <- q_result$bootstrap$lower
      base_row$Bootstrap_Upper <- q_result$bootstrap$upper
    }

    # Bayesian
    if (!is.null(q_result$bayesian)) {
      base_row$Bayesian_Lower <- q_result$bayesian$lower
      base_row$Bayesian_Upper <- q_result$bayesian$upper
    }

    rows_list[[length(rows_list) + 1]] <- base_row
  }

  # Combine all rows - use bind_rows to handle mismatched columns
  if (requireNamespace("dplyr", quietly = TRUE)) {
    df <- dplyr::bind_rows(rows_list)
  } else {
    # Fallback: find all unique column names and fill missing ones with NA
    all_cols <- unique(unlist(lapply(rows_list, names)))
    rows_list_filled <- lapply(rows_list, function(row) {
      missing_cols <- setdiff(all_cols, names(row))
      for (col in missing_cols) {
        row[[col]] <- NA
      }
      return(row[all_cols])  # Reorder to match all_cols
    })
    df <- do.call(rbind, lapply(rows_list_filled, function(x) as.data.frame(x, stringsAsFactors = FALSE)))
  }

  return(df)
}


# ==============================================================================
# MEANS DETAIL SHEET
# ==============================================================================

#' Add means detail sheet (internal)
#' @keywords internal
add_means_detail_sheet <- function(wb, mean_results, decimal_sep) {

  openxlsx::addWorksheet(wb, "Means_Detail")

  # Title
  openxlsx::writeData(wb, "Means_Detail", "MEANS - DETAILED RESULTS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Means_Detail",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Convert results list to data frame
  mean_df <- build_means_dataframe(mean_results)

  if (nrow(mean_df) == 0) {
    openxlsx::writeData(wb, "Means_Detail", "No mean analyses performed",
                        startCol = 1, startRow = 3)
    return(invisible(NULL))
  }

  # Write numeric data (not converted to strings)
  openxlsx::writeData(wb, "Means_Detail", mean_df, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Apply Excel number formatting to preserve numeric values
  apply_numeric_formatting(wb, "Means_Detail", 4, 1, mean_df, decimal_sep)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Means_Detail", header_style, rows = 3,
                     cols = 1:ncol(mean_df), gridExpand = TRUE)

  # Auto-size columns
  openxlsx::setColWidths(wb, "Means_Detail", cols = 1:ncol(mean_df), widths = "auto")
}


#' Build means dataframe from results list (internal)
#' @keywords internal
build_means_dataframe <- function(mean_results) {

  if (length(mean_results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(mean_results)) {
    q_result <- mean_results[[q_id]]

    # Base info
    base_row <- list(
      Question_ID = q_id,
      Mean = ifelse(!is.null(q_result$mean), q_result$mean, NA),
      SD = ifelse(!is.null(q_result$sd), q_result$sd, NA),
      Sample_Size = ifelse(!is.null(q_result$n), q_result$n, NA),
      Effective_n = ifelse(!is.null(q_result$n_eff), q_result$n_eff, NA)
    )

    # t-distribution CI
    if (!is.null(q_result$t_dist)) {
      base_row$tDist_Lower <- q_result$t_dist$lower
      base_row$tDist_Upper <- q_result$t_dist$upper
      base_row$SE <- q_result$t_dist$se
      base_row$DF <- q_result$t_dist$df
    }

    # Bootstrap
    if (!is.null(q_result$bootstrap)) {
      base_row$Bootstrap_Lower <- q_result$bootstrap$lower
      base_row$Bootstrap_Upper <- q_result$bootstrap$upper
    }

    # Bayesian
    if (!is.null(q_result$bayesian)) {
      base_row$Bayesian_Lower <- q_result$bayesian$lower
      base_row$Bayesian_Upper <- q_result$bayesian$upper
      base_row$Bayesian_Mean <- q_result$bayesian$post_mean
    }

    rows_list[[length(rows_list) + 1]] <- base_row
  }

  # Combine all rows - use bind_rows to handle mismatched columns
  if (requireNamespace("dplyr", quietly = TRUE)) {
    df <- dplyr::bind_rows(rows_list)
  } else {
    # Fallback: find all unique column names and fill missing ones with NA
    all_cols <- unique(unlist(lapply(rows_list, names)))
    rows_list_filled <- lapply(rows_list, function(row) {
      missing_cols <- setdiff(all_cols, names(row))
      for (col in missing_cols) {
        row[[col]] <- NA
      }
      return(row[all_cols])  # Reorder to match all_cols
    })
    df <- do.call(rbind, lapply(rows_list_filled, function(x) as.data.frame(x, stringsAsFactors = FALSE)))
  }

  return(df)
}


# ==============================================================================
# NPS DETAIL SHEET
# ==============================================================================

#' Add NPS detail sheet (internal)
#' @keywords internal
add_nps_detail_sheet <- function(wb, nps_results, decimal_sep) {

  openxlsx::addWorksheet(wb, "NPS_Detail")

  # Title
  openxlsx::writeData(wb, "NPS_Detail", "NET PROMOTER SCORE - DETAILED RESULTS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "NPS_Detail",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Convert results list to data frame
  nps_df <- build_nps_dataframe(nps_results)

  if (nrow(nps_df) == 0) {
    openxlsx::writeData(wb, "NPS_Detail", "No NPS analyses performed",
                        startCol = 1, startRow = 3)
    return(invisible(NULL))
  }

  # Write numeric data (not converted to strings)
  openxlsx::writeData(wb, "NPS_Detail", nps_df, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Apply Excel number formatting to preserve numeric values
  apply_numeric_formatting(wb, "NPS_Detail", 4, 1, nps_df, decimal_sep)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "NPS_Detail", header_style, rows = 3,
                     cols = 1:ncol(nps_df), gridExpand = TRUE)

  # Auto-size columns
  openxlsx::setColWidths(wb, "NPS_Detail", cols = 1:ncol(nps_df), widths = "auto")
}


#' Build NPS dataframe from results list (internal)
#' @keywords internal
build_nps_dataframe <- function(nps_results) {

  if (length(nps_results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(nps_results)) {
    q_result <- nps_results[[q_id]]

    # Base info
    base_row <- list(
      Question_ID = q_id,
      NPS_Score = ifelse(!is.null(q_result$nps_score), q_result$nps_score, NA),
      Pct_Promoters = ifelse(!is.null(q_result$pct_promoters), q_result$pct_promoters, NA),
      Pct_Detractors = ifelse(!is.null(q_result$pct_detractors), q_result$pct_detractors, NA),
      Sample_Size = ifelse(!is.null(q_result$n), q_result$n, NA),
      Effective_n = ifelse(!is.null(q_result$n_eff), q_result$n_eff, NA)
    )

    # Normal approximation CI
    if (!is.null(q_result$normal_ci)) {
      base_row$Normal_Lower <- q_result$normal_ci$lower
      base_row$Normal_Upper <- q_result$normal_ci$upper
      base_row$SE <- q_result$normal_ci$se
    }

    # Bootstrap
    if (!is.null(q_result$bootstrap)) {
      base_row$Bootstrap_Lower <- q_result$bootstrap$lower
      base_row$Bootstrap_Upper <- q_result$bootstrap$upper
    }

    # Bayesian
    if (!is.null(q_result$bayesian)) {
      base_row$Bayesian_Lower <- q_result$bayesian$lower
      base_row$Bayesian_Upper <- q_result$bayesian$upper
      base_row$Bayesian_Mean <- q_result$bayesian$post_mean
    }

    rows_list[[length(rows_list) + 1]] <- base_row
  }

  # Combine all rows - use bind_rows to handle mismatched columns
  if (requireNamespace("dplyr", quietly = TRUE)) {
    df <- dplyr::bind_rows(rows_list)
  } else {
    # Fallback: find all unique column names and fill missing ones with NA
    all_cols <- unique(unlist(lapply(rows_list, names)))
    rows_list_filled <- lapply(rows_list, function(row) {
      missing_cols <- setdiff(all_cols, names(row))
      for (col in missing_cols) {
        row[[col]] <- NA
      }
      return(row[all_cols])  # Reorder to match all_cols
    })
    df <- do.call(rbind, lapply(rows_list_filled, function(x) as.data.frame(x, stringsAsFactors = FALSE)))
  }

  return(df)
}
