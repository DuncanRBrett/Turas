# ==============================================================================
# MAXDIFF HTML REPORT - DATA TRANSFORMER - TURAS V11.0
# ==============================================================================
# Transforms MaxDiff analysis results into HTML-ready data structures
# Layer 1 of the 4-layer HTML report pipeline
# ==============================================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

safe_num <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x)
  suppressWarnings(as.numeric(x))
}

htmlEscape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

# ==============================================================================
# MAIN TRANSFORMER
# ==============================================================================

#' Transform MaxDiff results for HTML report
#'
#' @param maxdiff_results List. Full results from run_maxdiff()
#' @param config List. Module configuration
#'
#' @return Structured list with $meta, $summary, $preferences, $items,
#'   $segments, $turf, $diagnostics
#'
#' @keywords internal
transform_maxdiff_for_html <- function(maxdiff_results, config) {

  project_name <- config$project_settings$Project_Name %||% "MaxDiff Analysis"
  brand_colour <- config$project_settings$Brand_Colour %||% "#323367"
  accent_colour <- config$project_settings$Accent_Colour %||% "#CC9900"

  # Determine estimation method used
  has_hb <- !is.null(maxdiff_results$hb_results)
  has_logit <- !is.null(maxdiff_results$logit_results)
  has_counts <- !is.null(maxdiff_results$count_scores)

  method_label <- if (has_hb) "Hierarchical Bayes" else if (has_logit) "Aggregate Logit" else "Count-Based"

  n_total <- maxdiff_results$study_summary$n_respondents %||% 0
  n_items <- sum(config$items$Include == 1)

  # --- Build meta ---
  meta <- list(
    project_name = project_name,
    brand_colour = brand_colour,
    accent_colour = accent_colour,
    method = method_label,
    generated = format(Sys.time(), "%Y-%m-%d %H:%M"),
    n_total = n_total,
    n_items = n_items,
    company_name = config$project_settings$Company_Name %||% "",
    client_name = config$project_settings$Client_Name %||% "",
    researcher_name = config$project_settings$Researcher_Name %||% "",
    researcher_logo_path = config$project_settings$Researcher_Logo_Path %||% NULL,
    client_logo_path = config$project_settings$Client_Logo_Path %||% NULL
  )

  # --- Build summary ---
  summary_data <- transform_summary_section(maxdiff_results, config, meta)

  # --- Build preferences (utility scores + shares) ---
  preferences <- transform_preferences_section(maxdiff_results, config)

  # --- Build item analysis (best/worst counts + discrimination) ---
  items_analysis <- transform_items_section(maxdiff_results, config)

  # --- Build segments ---
  segments <- transform_segments_section(maxdiff_results, config)

  # --- Build TURF ---
  turf <- transform_turf_section(maxdiff_results, config)

  # --- Build diagnostics ---
  diagnostics <- transform_diagnostics_section(maxdiff_results, config)

  list(
    meta = meta,
    summary = summary_data,
    preferences = preferences,
    items = items_analysis,
    segments = segments,
    turf = turf,
    diagnostics = diagnostics
  )
}


# ==============================================================================
# SECTION TRANSFORMERS
# ==============================================================================

transform_summary_section <- function(results, config, meta) {

  has_hb <- !is.null(results$hb_results)
  has_logit <- !is.null(results$logit_results)
  has_counts <- !is.null(results$count_scores)

  # Get top item
  top_item <- "N/A"
  if (has_hb && !is.null(results$hb_results$population_utilities)) {
    pop_utils <- results$hb_results$population_utilities
    top_idx <- which.max(pop_utils$HB_Utility_Mean)
    if (length(top_idx) > 0) {
      top_item <- pop_utils$Item_Label[top_idx] %||% pop_utils$Item_ID[top_idx]
    }
  } else if (has_counts) {
    scores <- results$count_scores
    if ("BW_Score" %in% names(scores)) {
      top_idx <- which.max(scores$BW_Score)
      top_item <- scores$Item_Label[top_idx] %||% scores$Item_ID[top_idx]
    }
  }

  # Callout
  callout <- sprintf(
    '<div class="md-callout md-callout-result">
      <strong>Key Finding:</strong> Among %d items tested with %d respondents using %s estimation,
      <strong>%s</strong> emerged as the most preferred item.
    </div>',
    meta$n_items, meta$n_total, meta$method, htmlEscape(top_item)
  )

  list(
    method_label = meta$method,
    n_total = meta$n_total,
    n_items = meta$n_items,
    top_item = top_item,
    callout = callout
  )
}


transform_preferences_section <- function(results, config) {

  has_hb <- !is.null(results$hb_results)
  has_logit <- !is.null(results$logit_results)
  has_counts <- !is.null(results$count_scores)

  # Build unified scores table
  scores <- NULL
  pref_shares <- NULL

  if (has_hb) {
    pop <- results$hb_results$population_utilities
    scores <- data.frame(
      Item_ID = pop$Item_ID,
      Item_Label = pop$Item_Label %||% pop$Item_ID,
      Utility = round(pop$HB_Utility_Mean, 3),
      SE = round(pop$HB_Utility_SD, 3),
      stringsAsFactors = FALSE
    )

    # Compute preference shares from individual utilities
    if (!is.null(results$hb_results$individual_utilities)) {
      indiv <- results$hb_results$individual_utilities
      if (exists("compute_preference_shares", mode = "function")) {
        pref_shares <- compute_preference_shares(individual_utils = indiv)
      }
    }
  } else if (has_logit) {
    lu <- results$logit_results$utilities
    scores <- data.frame(
      Item_ID = lu$Item_ID,
      Item_Label = lu$Item_Label %||% lu$Item_ID,
      Utility = round(lu$Logit_Utility, 3),
      SE = round(lu$Logit_SE, 3),
      stringsAsFactors = FALSE
    )
    if (exists("compute_preference_shares", mode = "function")) {
      agg <- setNames(lu$Logit_Utility, lu$Item_ID)
      pref_shares <- compute_preference_shares(aggregate_utils = agg)
    }
  } else if (has_counts) {
    cs <- results$count_scores
    scores <- data.frame(
      Item_ID = cs$Item_ID,
      Item_Label = cs$Item_Label %||% cs$Item_ID,
      Utility = round(cs$BW_Score %||% cs$Net_Score %||% rep(0, nrow(cs)), 3),
      SE = rep(NA_real_, nrow(cs)),
      stringsAsFactors = FALSE
    )
  }

  if (!is.null(scores)) {
    # Add rescaled score (0-100)
    scores$Rescaled <- round(rescale_utilities(scores$Utility, "0_100"), 1)
    scores$Rank <- rank_utilities(scores$Utility)

    # Add preference shares
    if (!is.null(pref_shares)) {
      share_df <- data.frame(
        Item_ID = names(pref_shares),
        Pref_Share = round(as.numeric(pref_shares), 1),
        stringsAsFactors = FALSE
      )
      scores <- merge(scores, share_df, by = "Item_ID", all.x = TRUE, sort = FALSE)
    } else {
      scores$Pref_Share <- round(rescale_utilities(scores$Utility, "PROBABILITY"), 1)
    }

    # Sort by utility descending
    scores <- scores[order(-scores$Utility), ]
    rownames(scores) <- NULL
  }

  # Add anchor data if available
  anchor_data <- results$anchor_data

  callout <- '<div class="md-callout md-callout-method"><strong>Preference Scores:</strong> Items ranked by estimated utility from the MaxDiff analysis. Preference shares show each item&#39;s probability of being chosen, summing to 100%.</div>'

  list(
    scores = scores,
    pref_shares = pref_shares,
    anchor_data = anchor_data,
    callout = callout
  )
}


transform_items_section <- function(results, config) {

  count_data <- NULL
  discrimination <- NULL

  if (!is.null(results$count_scores)) {
    cs <- results$count_scores
    count_data <- data.frame(
      Item_ID = cs$Item_ID,
      Item_Label = cs$Item_Label %||% cs$Item_ID,
      Best_Pct = round(cs$Best_Pct %||% rep(0, nrow(cs)), 1),
      Worst_Pct = round(cs$Worst_Pct %||% rep(0, nrow(cs)), 1),
      BW_Score = round(cs$BW_Score %||% cs$Net_Score %||% rep(0, nrow(cs)), 3),
      stringsAsFactors = FALSE
    )
    count_data <- count_data[order(-count_data$BW_Score), ]
    rownames(count_data) <- NULL
  }

  # Item discrimination (from HB individual utils)
  if (!is.null(results$hb_results$individual_utilities)) {
    if (exists("classify_item_discrimination", mode = "function")) {
      discrimination <- classify_item_discrimination(
        results$hb_results$individual_utilities,
        config$items
      )
    }
  }

  callout <- '<div class="md-callout md-callout-method"><strong>Item Analysis:</strong> Best% shows how often each item was chosen as most important; Worst% as least important. The diverging chart reveals clear winners and losers at a glance.</div>'

  list(
    count_data = count_data,
    discrimination = discrimination,
    callout = callout
  )
}


transform_segments_section <- function(results, config) {

  if (is.null(results$segment_results)) return(NULL)

  seg <- results$segment_results

  callout <- '<div class="md-callout md-callout-result"><strong>Segment Analysis:</strong> Preferences broken down by respondent segments. Look for items where segments diverge significantly &mdash; these represent targeting opportunities.</div>'

  list(
    segment_data = seg,
    callout = callout
  )
}


transform_turf_section <- function(results, config) {

  if (is.null(results$turf_results)) return(NULL)

  turf <- results$turf_results

  callout <- sprintf(
    '<div class="md-callout md-callout-result"><strong>Portfolio Optimization (TURF):</strong> The greedy algorithm found that a portfolio of %d items reaches %.1f%% of respondents. Each step adds the item providing the highest incremental reach.</div>',
    nrow(turf$incremental_table),
    max(turf$incremental_table$Reach_Pct, 0)
  )

  list(
    incremental_table = turf$incremental_table,
    reach_curve = turf$reach_curve,
    threshold_method = turf$threshold_method,
    callout = callout
  )
}


transform_diagnostics_section <- function(results, config) {

  logit_fit <- NULL
  hb_diagnostics <- NULL

  if (!is.null(results$logit_results$fit_stats)) {
    fs <- results$logit_results$fit_stats
    logit_fit <- list(
      log_likelihood = safe_num(fs$log_likelihood),
      aic = safe_num(fs$aic),
      bic = safe_num(fs$bic),
      pseudo_r2 = safe_num(fs$pseudo_r2 %||% fs$mcfadden_r2)
    )
  }

  if (!is.null(results$hb_results$diagnostics)) {
    hd <- results$hb_results$diagnostics
    hb_diagnostics <- list(
      divergences = safe_num(hd$divergences %||% hd$num_divergent),
      max_rhat = safe_num(hd$max_rhat),
      min_ess = safe_num(hd$min_ess %||% hd$min_bulk_ess),
      quality_score = safe_num(hd$quality_score)
    )
  }

  callout <- '<div class="md-callout md-callout-method"><strong>Diagnostics:</strong> Model fit statistics and convergence indicators. For HB models, R-hat values should be below 1.05 and ESS above 400 for reliable estimates.</div>'

  list(
    logit_fit = logit_fit,
    hb_diagnostics = hb_diagnostics,
    n_total = results$study_summary$n_respondents %||% 0,
    n_tasks = results$study_summary$n_tasks %||% 0,
    n_items = results$study_summary$n_items %||% 0,
    callout = callout
  )
}
