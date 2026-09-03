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
    # Drop the ID column BY NAME, then non-numeric columns (review C2 / F3):
    # a numeric resp_id passed the is.numeric filter and became element 1 of
    # every respondent's utilities vector, which the engine indexes by item
    # position - every item would read the previous item's utility.
    indiv_df <- hb_results$individual_utilities
    if (is.data.frame(indiv_df)) {
      indiv_df <- indiv_df[, !(names(indiv_df) %in% c("resp_id", "respondent_id", "Respondent_ID")), drop = FALSE]
      numeric_cols <- sapply(indiv_df, is.numeric)
      indiv_mat <- as.matrix(indiv_df[, numeric_cols, drop = FALSE])
    } else {
      indiv_mat <- as.matrix(indiv_df)
    }
    # The engine pairs utilities[i] with items[i] BY POSITION and the column
    # names do not travel. The fallback's reshape() writes the item columns in
    # alphabetical order while items follow the config, so before this every
    # share, head-to-head and reach figure was computed on the wrong items.
    # Align the columns to the item list; refuse to guess if one is missing.
    wanted <- vapply(item_list, function(it) it$id, character(1))
    if (!is.null(colnames(indiv_mat))) {
      missing_cols <- setdiff(wanted, colnames(indiv_mat))
      if (length(missing_cols) > 0) {
        message(sprintf(
          "[TRS INFO] MAXD_SIM_UTILS_MISSING: individual utilities have no column for %s; those items are dropped from the simulator.",
          paste(missing_cols, collapse = ", ")))
        keep <- vapply(item_list, function(it) it$id %in% colnames(indiv_mat), logical(1))
        item_list <- item_list[keep]
        wanted <- wanted[keep]
      }
      indiv_mat <- indiv_mat[, wanted, drop = FALSE]
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

  # Segment definitions for the filter. The engine filters respondents by
  # `segments[variable] === value`, so every entry needs a LEVEL value. A
  # SEGMENT_SETTINGS row is one per group (Variable_Name, blank Segment_Def)
  # since Session A; such a row is expanded here into one entry per level
  # observed in the data. Before this, the group row produced a single entry
  # with an empty value that matched nobody, and choosing it zeroed every
  # share. A row whose Segment_Def names a value ('Region == "Gauteng"') is
  # kept as that one level.
  seg_defs <- list()
  if (!is.null(config$segment_settings) && nrow(config$segment_settings) > 0) {
    for (i in seq_len(nrow(config$segment_settings))) {
      seg_var <- config$segment_settings$Variable_Name[i]
      seg_id <- config$segment_settings$Segment_ID[i]
      seg_label <- config$segment_settings$Segment_Label[i] %||% seg_id
      seg_def <- config$segment_settings$Segment_Def[i] %||% ""
      if (is.na(seg_def)) seg_def <- ""

      m <- regmatches(seg_def, regexpr('"([^"]+)"', seg_def, perl = TRUE))
      if (length(m) == 1) {
        seg_defs[[length(seg_defs) + 1]] <- list(
          id = seg_id, label = seg_label, variable = seg_var,
          value = gsub('^"|"$', '', m)
        )
      } else if (!is.null(raw_data) && seg_var %in% names(raw_data)) {
        lv <- as.character(raw_data[[seg_var]])
        lv <- sort(unique(lv[!is.na(lv) & nzchar(lv)]))
        for (v in lv) {
          seg_defs[[length(seg_defs) + 1]] <- list(
            id = paste0(seg_id, ":", v), label = paste0(seg_label, ": ", v),
            variable = seg_var, value = v
          )
        }
      } else {
        message(sprintf(
          "[TRS INFO] MAXD_SIM_SEGMENT_SKIPPED: segment '%s' has no level value and '%s' is not a data column; it is left out of the simulator's filter.",
          seg_id, seg_var))
      }
    }
  }

  # Name the estimator honestly. Without cmdstanr the module's "HB" is an
  # empirical-Bayes fallback on count scores, and the simulator used to call
  # that "Hierarchical Bayes" on its Overview and Diagnostics panels.
  est <- .md_sim_estimator(hb_results, logit_results)

  list(
    project_name = config$project_settings$Project_Name %||% "MaxDiff",
    brand_colour = brand_colour,
    items = item_list,
    individual_utils = indiv_list,
    segments = seg_defs,
    n_respondents = length(indiv_list),
    method = est$label,
    method_code = est$code,
    approximate = est$approximate,
    estimation_note = est$note,
    n_items = length(item_list),
    analyst_name = config$project_settings$Analyst_Name %||% "",
    analyst_email = config$project_settings$Analyst_Email %||% "",
    analyst_phone = config$project_settings$Analyst_Phone %||% "",
    appendices = config$project_settings$Appendices %||% "",
    closing_notes = config$project_settings$Closing_Notes %||% ""
  )
}


#' Which estimator produced the utilities the simulator runs on
#' @keywords internal
.md_sim_estimator <- function(hb_results, logit_results) {
  if (!is.null(hb_results) && !is.null(hb_results$individual_utilities)) {
    m <- hb_results$model_fit$method %||% hb_results$diagnostics$method %||% ""
    if (identical(m, "cmdstanr")) {
      return(list(code = "stan_hb", label = "Stan hierarchical Bayes", approximate = FALSE,
                  note = "Individual utilities are posterior means from the Stan model."))
    }
    return(list(code = "empirical_bayes", label = "Empirical Bayes fallback (count-based)",
                approximate = TRUE,
                note = paste0("cmdstanr was not available, so the individual utilities ",
                              "are empirical-Bayes shrunken best-minus-worst counts, not ",
                              "Bayesian posterior estimates. Shares, head-to-head ",
                              "probabilities and reach are computed from those.")))
  }
  list(code = "aggregate_logit", label = "Aggregate logit", approximate = FALSE,
       note = "One conditional logit fitted to the whole sample; no individual utilities.")
}
