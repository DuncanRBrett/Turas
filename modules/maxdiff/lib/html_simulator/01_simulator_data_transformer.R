# ==============================================================================
# MAXDIFF SIMULATOR - DATA TRANSFORMER - TURAS V11.0
# ==============================================================================
# Builds JSON-ready data structure for the interactive simulator

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

#' Build simulator data structure
#'
#' @param hb_results HB results with population and individual utilities
#' @param logit_results Logit results (fallback if no HB)
#' @param config Module config
#'
#' @return List ready for JSON serialization
#' @keywords internal
build_simulator_data <- function(hb_results, logit_results, config,
                                  segment_results = NULL) {

  items <- config$items[config$items$Include == 1, ]
  brand_colour <- config$project_settings$Brand_Colour %||% "#1e3a5f"

  # Build items array
  item_list <- list()
  for (i in seq_len(nrow(items))) {
    item_id <- items$Item_ID[i]
    item_label <- items$Item_Label[i] %||% item_id

    # Get utility from HB first, then logit
    utility <- 0
    if (!is.null(hb_results$population_utilities)) {
      pop <- hb_results$population_utilities
      match_idx <- match(item_id, pop$Item_ID)
      if (!is.na(match_idx)) utility <- pop$HB_Utility_Mean[match_idx]
    } else if (!is.null(logit_results$utilities)) {
      lu <- logit_results$utilities
      match_idx <- match(item_id, lu$Item_ID)
      if (!is.na(match_idx)) utility <- lu$Logit_Utility[match_idx]
    }

    item_list[[i]] <- list(
      id = item_id,
      label = item_label,
      utility = round(utility, 4)
    )
  }

  # Build individual utilities array
  indiv_list <- list()
  if (!is.null(hb_results$individual_utilities)) {
    indiv_mat <- as.matrix(hb_results$individual_utilities)
    item_ids <- colnames(indiv_mat)

    # Get segment data if available
    seg_data <- NULL
    if (!is.null(config$segment_settings) && nrow(config$segment_settings) > 0) {
      seg_data <- config$segment_settings
    }

    for (r in seq_len(nrow(indiv_mat))) {
      entry <- list(
        utilities = round(as.numeric(indiv_mat[r, ]), 4)
      )

      # Add segment info if we have raw_data attached
      if (!is.null(hb_results$respondent_ids)) {
        entry$id <- as.character(hb_results$respondent_ids[r])
      }

      indiv_list[[r]] <- entry
    }
  }

  # Segment definitions for filter
  seg_defs <- list()
  if (!is.null(config$segment_settings) && nrow(config$segment_settings) > 0) {
    for (i in seq_len(nrow(config$segment_settings))) {
      seg_defs[[i]] <- list(
        id = config$segment_settings$Segment_ID[i],
        label = config$segment_settings$Segment_Label[i],
        variable = config$segment_settings$Variable_Name[i]
      )
    }
  }

  list(
    project_name = config$project_settings$Project_Name %||% "MaxDiff",
    brand_colour = brand_colour,
    items = item_list,
    individual_utils = indiv_list,
    segments = seg_defs,
    n_respondents = length(indiv_list),
    n_items = length(item_list)
  )
}
