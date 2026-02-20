# ==============================================================================
# TurasTracker - Tracking Crosstab Engine
# ==============================================================================
#
# Transforms trend results into a tracking crosstab data structure:
# Rows = tracked metrics, Columns = waves x banner segments
# Includes change sub-rows (vs previous, vs baseline) with significance.
#
# This module RESHAPES existing trend results — it does not recalculate
# statistics from raw data.
#
# VERSION: 1.0.0
# ==============================================================================


#' Build Tracking Crosstab
#'
#' Main orchestrator that transforms trend results into the tracking crosstab
#' data structure. Produces a flat list of metric_rows with values, changes,
#' and significance per wave per segment.
#'
#' @param trend_results List. Output from calculate_all_trends() or
#'   calculate_trends_with_banners()
#' @param config List. Configuration object from load_tracking_config()
#' @param question_map List. Question map index from build_question_map_index()
#' @param banner_segments Named list. Banner segment definitions (NULL if no banners)
#' @return List containing:
#'   \item{metrics}{List of metric_row objects}
#'   \item{waves}{Character vector of wave IDs}
#'   \item{wave_labels}{Character vector of wave display names}
#'   \item{banner_segments}{Character vector of segment names}
#'   \item{baseline_wave}{Character. The baseline wave ID}
#'   \item{sections}{Character vector of unique section names}
#'   \item{metadata}{List of report metadata}
#'
#' @export
build_tracking_crosstab <- function(trend_results, config, question_map,
                                     banner_segments = NULL) {

  wave_ids <- config$waves$WaveID
  wave_labels <- config$waves$WaveName
  baseline_wave <- get_baseline_wave(config)
  tracked_questions <- config$tracked_questions

  # Determine if results have banner structure
  has_banners <- !is.null(banner_segments) && length(banner_segments) > 0

  # Get segment names
  if (has_banners) {
    segment_names <- names(banner_segments)
  } else {
    segment_names <- "Total"
  }

  # Build metric rows for each tracked question
  all_metric_rows <- list()

  for (i in seq_len(nrow(tracked_questions))) {
    q_code <- tracked_questions$QuestionCode[i]
    q_trend <- trend_results[[q_code]]

    if (is.null(q_trend)) {
      message(paste0("  [SKIP] No trend results for: ", q_code))
      next
    }

    # Get config-level overrides
    metric_label <- tracked_questions$MetricLabel[i]
    section <- tracked_questions$Section[i]
    sort_order <- tracked_questions$SortOrder[i]

    # Get tracking specs (from config first, then mapping, then defaults)
    tracking_specs_str <- get_tracking_specs(question_map, q_code, config = config)

    # Get question metadata for type info
    metadata <- get_question_metadata(question_map, q_code)
    if (is.null(metadata)) next

    q_type <- normalize_question_type(metadata$QuestionType)

    # Determine the metric_type from the trend result
    # With banners: first segment has the metric_type
    if (has_banners) {
      first_seg <- q_trend[[segment_names[1]]]
      metric_type <- if (!is.null(first_seg)) first_seg$metric_type else "unknown"
    } else {
      metric_type <- q_trend$metric_type
    }

    # Build metric rows for this question
    rows <- build_metric_rows_for_question(
      q_code = q_code,
      q_trend = q_trend,
      metric_type = metric_type,
      tracking_specs_str = tracking_specs_str,
      segment_names = segment_names,
      wave_ids = wave_ids,
      baseline_wave = baseline_wave,
      has_banners = has_banners,
      config = config,
      metric_label_override = metric_label,
      section = section,
      sort_order = sort_order,
      question_text = metadata$QuestionText
    )

    all_metric_rows <- c(all_metric_rows, rows)
  }

  # Apply section and sort ordering
  all_metric_rows <- sort_metric_rows(all_metric_rows)

  # Collect unique sections
  sections <- unique(vapply(all_metric_rows, function(r) {
    if (is.na(r$section) || r$section == "") "(Ungrouped)" else r$section
  }, character(1)))

  # Build metadata
  metadata <- list(
    project_name = get_setting(config, "project_name", default = "Tracking Report"),
    generated_at = Sys.time(),
    confidence_level = get_setting(config, "confidence_level", default = 0.95),
    n_metrics = length(all_metric_rows),
    n_waves = length(wave_ids),
    n_segments = length(segment_names)
  )

  list(
    metrics = all_metric_rows,
    waves = wave_ids,
    wave_labels = wave_labels,
    banner_segments = segment_names,
    baseline_wave = baseline_wave,
    sections = sections,
    metadata = metadata
  )
}


#' Build Metric Rows for a Single Question
#'
#' Converts one question's trend results into one or more metric_row objects.
#' A rating question with specs "mean,top2_box" produces two metric_rows.
#'
#' @keywords internal
build_metric_rows_for_question <- function(q_code, q_trend, metric_type,
                                            tracking_specs_str, segment_names,
                                            wave_ids, baseline_wave, has_banners,
                                            config, metric_label_override,
                                            section, sort_order, question_text) {

  rows <- list()

  # Parse the specs to determine which metrics were computed
  if (is.null(tracking_specs_str) || tracking_specs_str == "") {
    # Use defaults based on metric_type
    specs_list <- get_default_specs_list(metric_type)
  } else {
    specs_list <- trimws(strsplit(tracking_specs_str, ",")[[1]])
  }

  # For each spec, build a metric_row
  for (spec_idx in seq_along(specs_list)) {
    spec_original <- specs_list[spec_idx]

    # Strip =Label from spec — extract core spec and optional custom label
    parsed <- parse_spec_label(spec_original)
    spec <- parsed$core
    custom_label <- parsed$label
    spec_lower <- tolower(trimws(spec))

    # Skip distribution (not suitable for crosstab display)
    if (spec_lower == "distribution" || spec_lower == "count_distribution") next

    # Generate label (pass custom_label for =Label support)
    label <- generate_metric_label(
      spec = spec,
      metric_label_override = metric_label_override,
      question_text = question_text,
      metric_type = metric_type,
      specs_list = specs_list,
      custom_label = custom_label
    )

    # Build segments data
    segments_data <- list()
    for (seg_name in segment_names) {
      seg_trend <- if (has_banners) q_trend[[seg_name]] else q_trend

      if (is.null(seg_trend)) {
        segments_data[[seg_name]] <- build_empty_segment(wave_ids)
        next
      }

      segments_data[[seg_name]] <- extract_segment_metric(
        seg_trend = seg_trend,
        metric_type = metric_type,
        spec = spec,
        wave_ids = wave_ids,
        baseline_wave = baseline_wave,
        config = config
      )
    }

    metric_row <- list(
      question_code = q_code,
      metric_label = label,
      metric_name = spec_lower,
      section = if (is.na(section)) "" else section,
      sort_order = if (is.na(sort_order)) spec_idx else sort_order + (spec_idx - 1) * 0.01,
      question_type = metric_type,
      question_text = question_text,
      segments = segments_data
    )

    rows[[length(rows) + 1]] <- metric_row
  }

  rows
}


#' Extract Metric Values for One Segment
#'
#' Pulls values, changes, and significance from a segment's trend result
#' for a specific metric spec.
#'
#' @keywords internal
extract_segment_metric <- function(seg_trend, metric_type, spec, wave_ids,
                                    baseline_wave, config) {

  spec_lower <- tolower(trimws(spec))
  metric_name <- normalize_metric_name(spec_lower)

  values <- list()
  n_values <- list()

  # Extract per-wave values based on metric_type
  for (wave_id in wave_ids) {
    wr <- seg_trend$wave_results[[wave_id]]

    if (is.null(wr) || isFALSE(wr$available)) {
      values[[wave_id]] <- NA_real_
      n_values[[wave_id]] <- NA_integer_
      next
    }

    val <- extract_metric_value(wr, metric_type, metric_name)
    values[[wave_id]] <- val

    # Extract sample size
    n_values[[wave_id]] <- if (!is.null(wr$n_unweighted)) {
      wr$n_unweighted
    } else {
      NA_integer_
    }
  }

  # Calculate vs previous changes
  change_vs_previous <- list()
  sig_vs_previous <- list()

  for (i in 2:length(wave_ids)) {
    wid <- wave_ids[i]
    prev_wid <- wave_ids[i - 1]
    curr_val <- values[[wid]]
    prev_val <- values[[prev_wid]]

    if (!is.na(curr_val) && !is.na(prev_val)) {
      change_vs_previous[[wid]] <- curr_val - prev_val
    } else {
      change_vs_previous[[wid]] <- NA_real_
    }

    # Get significance from trend result's existing sig tests
    sig_key <- paste0(prev_wid, "_vs_", wid)
    sig_vs_previous[[wid]] <- extract_significance(seg_trend, metric_name, sig_key)
  }

  # Calculate vs baseline changes
  change_vs_baseline <- list()
  sig_vs_baseline <- list()

  baseline_val <- values[[baseline_wave]]
  for (wid in wave_ids) {
    if (wid == baseline_wave) next
    curr_val <- values[[wid]]

    if (!is.na(curr_val) && !is.na(baseline_val)) {
      change_vs_baseline[[wid]] <- curr_val - baseline_val
    } else {
      change_vs_baseline[[wid]] <- NA_real_
    }

    # For baseline significance: check if pre-computed, otherwise NA
    # Baseline sig tests may not exist in existing trend results (consecutive only)
    sig_key <- paste0(baseline_wave, "_vs_", wid)
    sig_result <- extract_significance(seg_trend, metric_name, sig_key)
    # If not found (likely — existing code only tests consecutive), mark as NA
    sig_vs_baseline[[wid]] <- sig_result
  }

  list(
    values = values,
    n = n_values,
    change_vs_previous = change_vs_previous,
    change_vs_baseline = change_vs_baseline,
    sig_vs_previous = sig_vs_previous,
    sig_vs_baseline = sig_vs_baseline
  )
}


#' Extract a Single Metric Value from Wave Results
#'
#' Handles the different storage patterns across metric types:
#' - rating_enhanced: wave_results$W1$metrics$mean
#' - nps: wave_results$W1$nps, wave_results$W1$promoters_pct
#' - single_choice_enhanced/multi_mention: wave_results$W1$proportions$code
#'
#' @keywords internal
extract_metric_value <- function(wave_result, metric_type, metric_name) {

  if (metric_type %in% c("rating_enhanced", "rating", "composite", "composite_enhanced")) {
    # Enhanced structure: metrics sub-list
    if (!is.null(wave_result$metrics) && !is.null(wave_result$metrics[[metric_name]])) {
      return(wave_result$metrics[[metric_name]])
    }
    # Legacy structure: top-level
    if (!is.null(wave_result[[metric_name]])) {
      return(wave_result[[metric_name]])
    }
    return(NA_real_)

  } else if (metric_type == "nps") {
    # NPS: values at top level
    if (!is.null(wave_result[[metric_name]])) {
      return(wave_result[[metric_name]])
    }
    return(NA_real_)

  } else if (metric_type %in% c("single_choice", "single_choice_enhanced")) {
    # Single choice: proportions sub-list
    if (!is.null(wave_result$proportions) && !is.null(wave_result$proportions[[metric_name]])) {
      return(wave_result$proportions[[metric_name]])
    }
    # Category spec: check for the category name
    if (grepl("^category_", metric_name)) {
      cat_name <- sub("^category_", "", metric_name)
      if (!is.null(wave_result$proportions) && cat_name %in% names(wave_result$proportions)) {
        return(wave_result$proportions[[cat_name]])
      }
    }
    return(NA_real_)

  } else if (metric_type %in% c("multi_mention", "multi_choice", "category_mentions")) {
    # Multi-mention: various structures
    if (!is.null(wave_result[[metric_name]])) {
      return(wave_result[[metric_name]])
    }
    # Check metrics sub-list
    if (!is.null(wave_result$metrics) && !is.null(wave_result$metrics[[metric_name]])) {
      return(wave_result$metrics[[metric_name]])
    }
    # Check proportions
    if (!is.null(wave_result$proportions) && !is.null(wave_result$proportions[[metric_name]])) {
      return(wave_result$proportions[[metric_name]])
    }
    return(NA_real_)
  }

  # Fallback
  if (!is.null(wave_result[[metric_name]])) {
    return(wave_result[[metric_name]])
  }
  if (!is.null(wave_result$metrics) && !is.null(wave_result$metrics[[metric_name]])) {
    return(wave_result$metrics[[metric_name]])
  }

  NA_real_
}


#' Extract Significance Result
#'
#' @keywords internal
extract_significance <- function(seg_trend, metric_name, sig_key) {

  # Check multiple significance storage locations
  # 1. Enhanced: $significance$metric_name$sig_key
  if (!is.null(seg_trend$significance)) {
    sig <- seg_trend$significance

    # Enhanced metrics store sig per metric name
    if (!is.null(sig[[metric_name]]) && !is.null(sig[[metric_name]][[sig_key]])) {
      sig_result <- sig[[metric_name]][[sig_key]]
      if (is.list(sig_result) && !is.null(sig_result$significant)) {
        return(sig_result$significant)
      }
      return(sig_result)
    }

    # Legacy NPS/basic: sig directly at $significance$sig_key
    if (!is.null(sig[[sig_key]])) {
      sig_result <- sig[[sig_key]]
      if (is.list(sig_result) && !is.null(sig_result$significant)) {
        return(sig_result$significant)
      }
      return(sig_result)
    }
  }

  # Not found — likely because baseline comparisons aren't in existing results
  NA
}


#' Build Empty Segment Data
#'
#' Returns a segment structure with all NAs for when a segment has no data.
#'
#' @keywords internal
build_empty_segment <- function(wave_ids) {
  values <- setNames(as.list(rep(NA_real_, length(wave_ids))), wave_ids)
  n_values <- setNames(as.list(rep(NA_integer_, length(wave_ids))), wave_ids)

  list(
    values = values,
    n = n_values,
    change_vs_previous = list(),
    change_vs_baseline = list(),
    sig_vs_previous = list(),
    sig_vs_baseline = list()
  )
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Normalize Metric Name
#'
#' Converts spec syntax to the internal metric name used in wave_results.
#' E.g., "range:9-10" → "range_9_10", "category:Yes" → "category_yes",
#' "box:Agree" → "box_agree"
#'
#' @keywords internal
normalize_metric_name <- function(spec_lower) {
  if (grepl("^range:", spec_lower)) {
    gsub("[^a-z0-9_]", "_", spec_lower)
  } else if (grepl("^box:", spec_lower)) {
    box_name <- trimws(sub("^box:", "", spec_lower))
    paste0("box_", gsub("[^a-z0-9_]", "_", tolower(box_name)))
  } else if (grepl("^category:", spec_lower)) {
    # Extract category name and normalize
    cat_name <- trimws(sub("^category:", "", spec_lower))
    paste0("category_", gsub("[^a-z0-9_]", "_", tolower(cat_name)))
  } else if (grepl("^option:", spec_lower)) {
    trimws(sub("^option:", "", spec_lower))
  } else {
    spec_lower
  }
}


#' Get Default Specs List for a Metric Type
#'
#' Returns the default list of specs when none are specified.
#'
#' @keywords internal
get_default_specs_list <- function(metric_type) {
  switch(metric_type,
    "rating" = , "rating_enhanced" = c("mean"),
    "nps" = c("nps_score"),
    "single_choice" = , "single_choice_enhanced" = c("all"),
    "multi_mention" = , "multi_choice" = , "category_mentions" = c("auto"),
    "composite" = , "composite_enhanced" = c("mean"),
    c("mean")  # fallback
  )
}


#' Generate Human-Readable Metric Label
#'
#' Produces a display label for a metric row. Uses the custom label from
#' =Label syntax if provided, then MetricLabel override, otherwise generates
#' from question text and spec.
#'
#' @param custom_label Character or NULL. Custom label from =Label syntax.
#' @keywords internal
generate_metric_label <- function(spec, metric_label_override, question_text,
                                   metric_type, specs_list,
                                   custom_label = NULL) {

  spec_lower <- tolower(trimws(spec))

  # If only one spec and MetricLabel provided, use it directly
  if (!is.na(metric_label_override) && metric_label_override != "" && length(specs_list) == 1) {
    return(metric_label_override)
  }

  # Build a descriptive suffix
  # If custom_label from =Label syntax is provided, use it
  suffix <- if (!is.null(custom_label) && nzchar(custom_label)) {
    paste0("(", custom_label, ")")
  } else {
    switch(spec_lower,
      "mean" = "(Mean)",
      "top_box" = "(Top Box)",
      "top2_box" = "(Top 2 Box)",
      "top3_box" = "(Top 3 Box)",
      "bottom_box" = "(Bottom Box)",
      "bottom2_box" = "(Bottom 2 Box)",
      "nps_score" = "(NPS)",
      "nps" = "(NPS)",
      "promoters_pct" = "(% Promoters)",
      "passives_pct" = "(% Passives)",
      "detractors_pct" = "(% Detractors)",
      "any" = "(% Any)",
      "count_mean" = "(Mean Count)",
      {
        # Pattern-based specs
        if (grepl("^range:", spec_lower)) {
          range_part <- sub("^range:", "", spec_lower)
          paste0("(Range ", range_part, ")")
        } else if (grepl("^box:", spec_lower)) {
          box_part <- trimws(sub("^box:", "", spec))
          paste0("(% ", box_part, ")")
        } else if (grepl("^category:", spec_lower)) {
          cat_part <- trimws(sub("^category:", "", spec))
          paste0("(% ", cat_part, ")")
        } else if (grepl("^option:", spec_lower)) {
          opt_part <- sub("^option:", "", spec)
          paste0("(", opt_part, ")")
        } else {
          paste0("(", spec, ")")
        }
      }
    )
  }

  # Use MetricLabel if available, else question_text
  base_label <- if (!is.na(metric_label_override) && metric_label_override != "") {
    metric_label_override
  } else if (!is.null(question_text) && !is.na(question_text) && question_text != "") {
    question_text
  } else {
    spec
  }

  # If multiple specs, add suffix; if single spec, add suffix only if no override
  if (length(specs_list) > 1) {
    paste(base_label, suffix)
  } else if (is.na(metric_label_override) || metric_label_override == "") {
    paste(base_label, suffix)
  } else {
    base_label
  }
}


#' Sort Metric Rows by Section and SortOrder
#'
#' @keywords internal
sort_metric_rows <- function(metric_rows) {
  if (length(metric_rows) == 0) return(metric_rows)

  # Extract sort keys
  sections <- vapply(metric_rows, function(r) {
    if (is.na(r$section) || r$section == "") "(Ungrouped)" else r$section
  }, character(1))

  orders <- vapply(metric_rows, function(r) r$sort_order, numeric(1))

  # Sort by section (alphabetical, but "(Ungrouped)" last), then by sort_order
  section_rank <- ifelse(sections == "(Ungrouped)", "~zzz", sections)
  sort_idx <- order(section_rank, orders)

  metric_rows[sort_idx]
}
