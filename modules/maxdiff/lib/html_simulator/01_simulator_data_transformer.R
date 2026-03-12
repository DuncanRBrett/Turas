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
                                  segment_results = NULL, raw_data = NULL) {

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
    # Drop non-numeric columns (e.g., resp_id) before matrix conversion
    indiv_df <- hb_results$individual_utilities
    if (is.data.frame(indiv_df)) {
      numeric_cols <- sapply(indiv_df, is.numeric)
      indiv_mat <- as.matrix(indiv_df[, numeric_cols, drop = FALSE])
    } else {
      indiv_mat <- as.matrix(indiv_df)
    }
    item_ids <- colnames(indiv_mat)

    # Get segment data if available
    seg_data <- NULL
    if (!is.null(config$segment_settings) && nrow(config$segment_settings) > 0) {
      seg_data <- config$segment_settings
    }

    # Build respondent ID lookup for segment mapping
    resp_ids <- NULL
    if (!is.null(hb_results$respondent_ids)) {
      resp_ids <- as.character(hb_results$respondent_ids)
    } else if (is.data.frame(hb_results$individual_utilities) &&
               "resp_id" %in% names(hb_results$individual_utilities)) {
      resp_ids <- as.character(hb_results$individual_utilities$resp_id)
    }

    # Get segment variable names for lookup
    seg_vars <- NULL
    if (!is.null(config$segment_settings) && nrow(config$segment_settings) > 0) {
      seg_vars <- unique(config$segment_settings$Variable_Name)
    }

    # Build respondent-to-segment lookup from raw_data
    resp_segments <- NULL
    id_var <- config$project_settings$Respondent_ID_Variable %||% "Respondent_ID"
    if (!is.null(raw_data) && !is.null(seg_vars) && !is.null(resp_ids) &&
        id_var %in% names(raw_data)) {
      resp_segments <- list()
      raw_ids <- as.character(raw_data[[id_var]])
      for (sv in seg_vars) {
        if (sv %in% names(raw_data)) {
          resp_segments[[sv]] <- setNames(as.character(raw_data[[sv]]), raw_ids)
        }
      }
    }

    for (r in seq_len(nrow(indiv_mat))) {
      entry <- list(
        utilities = round(as.numeric(indiv_mat[r, ]), 4)
      )

      if (!is.null(resp_ids) && r <= length(resp_ids)) {
        entry$id <- resp_ids[r]

        # Add segment membership
        if (!is.null(resp_segments)) {
          segs <- list()
          for (sv in names(resp_segments)) {
            val <- resp_segments[[sv]][resp_ids[r]]
            if (!is.na(val)) segs[[sv]] <- val
          }
          if (length(segs) > 0) entry$segments <- segs
        }
      }

      indiv_list[[r]] <- entry
    }
  }

  # Segment definitions for filter
  seg_defs <- list()
  if (!is.null(config$segment_settings) && nrow(config$segment_settings) > 0) {
    for (i in seq_len(nrow(config$segment_settings))) {
      seg_var <- config$segment_settings$Variable_Name[i]

      # Extract the actual data value from Segment_Def (e.g., 'Age_Group == "18-34"' -> "18-34")
      seg_def <- config$segment_settings$Segment_Def[i] %||% ""
      filter_val <- ""
      m <- regmatches(seg_def, regexpr('"([^"]+)"', seg_def, perl = TRUE))
      if (length(m) == 1) filter_val <- gsub('^"|"$', '', m)

      seg_defs[[i]] <- list(
        id = config$segment_settings$Segment_ID[i],
        label = config$segment_settings$Segment_Label[i],
        variable = seg_var,
        value = filter_val
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
    n_items = length(item_list),
    analyst_name = config$project_settings$Analyst_Name %||% "",
    analyst_email = config$project_settings$Analyst_Email %||% "",
    analyst_phone = config$project_settings$Analyst_Phone %||% "",
    appendices = config$project_settings$Appendices %||% "",
    closing_notes = config$project_settings$Closing_Notes %||% ""
  )
}
