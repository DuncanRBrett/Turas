# ==============================================================================
# MAXDIFF HTML REPORT - DATA TRANSFORMER - TURAS V11.2
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

  # --- Build head-to-head ---
  head_to_head <- transform_h2h_section(maxdiff_results, config)

  # --- Build diagnostics ---
  diagnostics <- transform_diagnostics_section(maxdiff_results, config)

  # --- Build methodology ---
  methodology <- transform_methodology_section(maxdiff_results, config)

  # --- Insights from config ---
  insights <- config$insights %||% NULL

  # --- Build segment filter options (for dropdown filters on analytical tabs) ---
  segment_filter <- transform_segment_filter_options(maxdiff_results, config)

  # --- Build individual utility distributions (for violin chart) ---
  utility_distributions <- transform_utility_distributions(maxdiff_results)

  list(
    meta = meta,
    summary = summary_data,
    preferences = preferences,
    items = items_analysis,
    head_to_head = head_to_head,
    segments = segments,
    segment_filter = segment_filter,
    utility_distributions = utility_distributions,
    turf = turf,
    diagnostics = diagnostics,
    methodology = methodology,
    insights = insights
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

  # Compute top item's lead over second place for context
  top_lead_text <- ""
  if (has_hb && !is.null(results$hb_results$population_utilities)) {
    pop_utils <- results$hb_results$population_utilities
    sorted_utils <- sort(pop_utils$HB_Utility_Mean, decreasing = TRUE)
    if (length(sorted_utils) >= 2) {
      gap <- sorted_utils[1] - sorted_utils[2]
      second_item <- pop_utils$Item_Label[which(pop_utils$HB_Utility_Mean == sorted_utils[2])[1]] %||%
        pop_utils$Item_ID[which(pop_utils$HB_Utility_Mean == sorted_utils[2])[1]]
      top_lead_text <- sprintf(
        " It holds a utility advantage of %.2f over the second-ranked item (%s), indicating a clear lead in preference.",
        gap, htmlEscape(second_item)
      )
    }
  } else if (has_counts && !is.null(results$count_scores) && "BW_Score" %in% names(results$count_scores)) {
    sorted_bw <- sort(results$count_scores$BW_Score, decreasing = TRUE)
    if (length(sorted_bw) >= 2) {
      gap <- sorted_bw[1] - sorted_bw[2]
      second_idx <- which(results$count_scores$BW_Score == sorted_bw[2])[1]
      second_item <- results$count_scores$Item_Label[second_idx] %||% results$count_scores$Item_ID[second_idx]
      top_lead_text <- sprintf(
        " It leads the second-ranked item (%s) by a BW score margin of %.3f.",
        htmlEscape(second_item), gap
      )
    }
  }

  method_note <- if (has_hb) {
    "Hierarchical Bayes estimation produces individual-level utility estimates, providing the most granular and reliable preference measurement available for MaxDiff data."
  } else if (has_logit) {
    "Aggregate logit estimation provides robust population-level utility estimates derived from a multinomial logistic regression on the choice data."
  } else {
    "Count-based scoring provides a straightforward summary of best and worst selections. While simple to interpret, it does not account for the experimental design structure."
  }

  callout <- sprintf(
    '<div class="md-callout md-callout-result">
      <strong>What you&#39;re looking at:</strong> A MaxDiff study where %d respondents evaluated %d items by repeatedly choosing their most and least preferred options from subsets.<br/>
      <strong>What it means:</strong> <strong>%s</strong> emerged as the most preferred item.%s<br/>
      <strong>What to do:</strong> Use the tabs below to explore preference scores, item-level analysis, and portfolio recommendations.
    </div>
    <div class="md-callout md-callout-method">
      <strong>Estimation Method:</strong> %s &mdash; %s
    </div>',
    meta$n_total, meta$n_items, htmlEscape(top_item), top_lead_text,
    meta$method, method_note
  )

  # Compute top share, bottom item, share range for overview KPI cards
  top_share <- NA_real_
  bottom_item <- "N/A"
  share_range <- NA_real_

  if (has_hb && !is.null(results$hb_results$individual_utilities)) {
    if (exists("compute_preference_shares", mode = "function")) {
      ov_shares <- tryCatch(
        compute_preference_shares(individual_utils = results$hb_results$individual_utilities),
        error = function(e) NULL
      )
      if (!is.null(ov_shares) && length(ov_shares) > 0) {
        # ov_shares are already in percentage scale (0-100) from compute_preference_shares
        top_share <- round(max(ov_shares), 1)
        share_range <- round(max(ov_shares) - min(ov_shares), 1)
        bottom_idx <- which.min(ov_shares)
        bottom_id <- names(ov_shares)[bottom_idx]
        pop_utils <- results$hb_results$population_utilities
        bi <- which(pop_utils$Item_ID == bottom_id)
        bottom_item <- if (length(bi) > 0) (pop_utils$Item_Label[bi[1]] %||% bottom_id) else bottom_id
      }
    }
  } else if (has_logit && !is.null(results$logit_results$utilities)) {
    lu <- results$logit_results$utilities
    if (exists("compute_preference_shares", mode = "function")) {
      agg <- setNames(lu$Logit_Utility, lu$Item_ID)
      ov_shares <- tryCatch(compute_preference_shares(aggregate_utils = agg), error = function(e) NULL)
      if (!is.null(ov_shares) && length(ov_shares) > 0) {
        # ov_shares are already in percentage scale (0-100)
        top_share <- round(max(ov_shares), 1)
        share_range <- round(max(ov_shares) - min(ov_shares), 1)
        bottom_idx <- which.min(ov_shares)
        bottom_id <- names(ov_shares)[bottom_idx]
        bi <- which(lu$Item_ID == bottom_id)
        bottom_item <- if (length(bi) > 0) (lu$Item_Label[bi[1]] %||% bottom_id) else bottom_id
      }
    }
  } else if (has_counts && "BW_Score" %in% names(results$count_scores)) {
    cs <- results$count_scores
    worst_idx <- which.min(cs$BW_Score)
    bottom_item <- cs$Item_Label[worst_idx] %||% cs$Item_ID[worst_idx]
  }

  list(
    method_label = meta$method,
    n_total = meta$n_total,
    n_items = meta$n_items,
    n_tasks = meta$n_tasks %||% results$study_summary$n_tasks %||% NA,
    top_item = top_item,
    bottom_item = bottom_item,
    top_share = top_share,
    share_range = share_range,
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

  callout <- paste0(
    '<div class="md-callout md-callout-result">',
    '<strong>What you&#39;re looking at:</strong> Each item&#39;s preference share (probability of being chosen from the full set, summing to 100%) and rescaled utility score (0&ndash;100 scale).<br/>',
    '<strong>What it means:</strong> Higher preference shares mean an item is more likely to be selected. An item with 20% share is twice as likely to be chosen as one with 10%. ',
    'The 0&ndash;100 scores show relative preference strength &mdash; items are comparable within this study only, not to an external standard.<br/>',
    '<strong>What to do:</strong> Use the sub-tabs to switch between preference shares, individual utility, and anchored MaxDiff views. Use the segment dropdown to filter by group. Click column headers to re-sort the table.',
    '</div>'
  )

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

  callout <- paste0(
    '<div class="md-callout md-callout-result">',
    '<strong>What you&#39;re looking at:</strong> How often each item was picked as &ldquo;best&rdquo; vs &ldquo;worst&rdquo; across all choice tasks, plus the BW Score (Best% minus Worst%, divided by 100).<br/>',
    '<strong>What it means:</strong> Items extending far right in the chart are clear favourites; items extending left are consistently rejected. ',
    'A BW Score near +1 means universally preferred; near &minus;1 means universally disliked; near 0 means polarising or unremarkable.<br/>',
    '<strong>What to do:</strong> Look for items that are strongly positive (prioritise) or strongly negative (consider dropping). ',
    'The Item Strategy Quadrant (if available) shows which items are universally liked vs polarising.',
    '</div>'
  )

  list(
    count_data = count_data,
    discrimination = discrimination,
    callout = callout
  )
}


transform_segments_section <- function(results, config) {

  if (is.null(results$segment_results)) return(NULL)

  seg <- results$segment_results

  callout <- paste0(
    '<div class="md-callout md-callout-result">',
    '<strong>What you&#39;re looking at:</strong> Preference scores broken down by respondent segment (e.g. age, gender, region).<br/>',
    '<strong>What it means:</strong> Items where segments diverge represent targeting opportunities &mdash; features that resonate strongly with one group but not others. ',
    'Differences shown are descriptive only; no formal significance test has been applied. Small segments may show apparent differences due to sampling variability.<br/>',
    '<strong>What to do:</strong> Look for items where segment bars are clearly different. Consider segment sample sizes before acting on apparent differences.',
    '</div>'
  )

  list(
    segment_data = seg,
    callout = callout
  )
}


transform_turf_section <- function(results, config) {

  if (is.null(results$turf_results)) return(NULL)

  turf <- results$turf_results

  threshold_text <- if (!is.null(turf$threshold_method)) {
    sprintf(" Items were classified as appealing to a respondent using the <strong>%s</strong> threshold method.", htmlEscape(turf$threshold_method))
  } else {
    ""
  }

  what_looking <- sprintf(
    '<strong>What you&#39;re looking at:</strong> The optimal combination of items that appeals to the widest possible audience. A portfolio of %d items reaches <strong>%.1f%%</strong> of respondents.%s<br/>',
    nrow(turf$incremental_table),
    max(turf$incremental_table$Reach_Pct, 0),
    threshold_text
  )
  what_means <- paste0(
    '<strong>What it means:</strong> &ldquo;Reach&rdquo; is the percentage of respondents for whom at least one item in the set is appealing. ',
    'Items are added one at a time, each step selecting the item that brings the most new people into the audience. The chart shows diminishing returns as more items are added.<br/>'
  )
  what_to_do <- '<strong>What to do:</strong> Find the &ldquo;elbow&rdquo; in the reach curve &mdash; the point where adding more items yields little additional audience. That is your optimal portfolio size.'
  callout <- paste0('<div class="md-callout md-callout-result">', what_looking, what_means, what_to_do, '</div>')

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

  n_items <- results$study_summary$n_items %||% 0
  n_total <- results$study_summary$n_respondents %||% 0

  # Count segments
  n_segments <- 0
  if (!is.null(config$segment_settings) && is.data.frame(config$segment_settings)) {
    n_segments <- nrow(config$segment_settings)
  }

  # Compute population utility stats and per-respondent stats from individual utilities
  pop_stats <- NULL
  respondent_stats <- NULL
  item_diag_table <- NULL

  indiv <- results$hb_results$individual_utilities
  pop <- results$hb_results$population_utilities

  if (!is.null(indiv)) {
    # Get numeric columns
    if (is.data.frame(indiv)) {
      numeric_cols <- vapply(indiv, is.numeric, logical(1))
      item_ids <- names(indiv)[numeric_cols]
      mat <- as.matrix(indiv[, numeric_cols, drop = FALSE])
    } else {
      mat <- as.matrix(indiv)
      item_ids <- colnames(mat)
    }

    if (!is.null(item_ids) && length(item_ids) >= 2) {
      # Population utility stats
      item_means <- colMeans(mat, na.rm = TRUE)
      item_sds <- apply(mat, 2, sd, na.rm = TRUE)
      util_range <- max(item_means) - min(item_means)
      mean_util <- mean(item_means)
      util_sd <- mean(item_sds)
      discrimination <- if (n_items > 0) util_range / n_items else NA

      pop_stats <- list(
        utility_range = round(util_range, 3),
        mean_utility = round(mean_util, 3),
        utility_sd = round(util_sd, 3),
        discrimination = round(discrimination, 3)
      )

      # Model quality indicators
      # Softmax preference shares per respondent
      exp_mat <- exp(mat)
      row_sums <- rowSums(exp_mat)
      share_mat <- exp_mat / row_sums
      max_shares <- apply(share_mat, 1, max)
      mean_max_share <- mean(max_shares)
      chance_level <- 1 / length(item_ids)
      sharpness_ratio <- mean_max_share / chance_level

      # Entropy ratio (0 = perfectly sharp, 1 = uniform)
      log_share_mat <- log(share_mat + 1e-10)
      row_entropy <- -rowSums(share_mat * log_share_mat)
      max_entropy <- log(length(item_ids))
      entropy_ratio <- mean(row_entropy) / max_entropy

      # Heterogeneity: average within-item SD across population
      heterogeneity <- mean(item_sds)

      quality_indicators <- list(
        mean_max_share = round(mean_max_share * 100, 1),
        chance_level = round(chance_level * 100, 1),
        sharpness_ratio = round(sharpness_ratio, 1),
        entropy_ratio = round(entropy_ratio, 3),
        heterogeneity = round(heterogeneity, 3)
      )

      # Respondent utility distribution
      respondent_ranges <- apply(mat, 1, function(r) max(r, na.rm = TRUE) - min(r, na.rm = TRUE))
      respondent_stats <- list(
        mean_range = round(mean(respondent_ranges), 2),
        min_range = round(min(respondent_ranges), 2),
        max_range = round(max(respondent_ranges), 2)
      )

      # Item-level diagnostics table
      # Get labels
      labels <- item_ids
      if (!is.null(pop) && "Item_Label" %in% names(pop)) {
        label_map <- setNames(pop$Item_Label, pop$Item_ID)
        labels <- ifelse(!is.na(label_map[item_ids]), label_map[item_ids], item_ids)
      }
      pop_utils <- if (!is.null(pop) && "Utility" %in% names(pop)) {
        setNames(pop$Utility, pop$Item_ID)
      } else {
        item_means
      }

      item_diag_table <- data.frame(
        Item_Label = labels,
        Pop_Utility = round(as.numeric(pop_utils[item_ids]), 3),
        Indiv_Mean = round(item_means, 3),
        Indiv_SD = round(item_sds, 3),
        Min = round(apply(mat, 2, min, na.rm = TRUE), 3),
        Max = round(apply(mat, 2, max, na.rm = TRUE), 3),
        stringsAsFactors = FALSE
      )
      item_diag_table <- item_diag_table[order(-item_diag_table$Pop_Utility), ]
      rownames(item_diag_table) <- NULL
    }
  }

  # Callout text
  callout <- '<div class="md-callout md-callout-method" style="margin-bottom:16px;"><span style="margin-right:6px;">&#9432;</span>Model diagnostics assess the reliability and validity of the MaxDiff analysis. Key indicators include <strong>preference sharpness</strong> (how decisive respondents are), <strong>heterogeneity</strong> (how much preferences vary), and <strong>item discrimination</strong> (how effectively the study differentiates between items).</div>'

  list(
    logit_fit = logit_fit,
    hb_diagnostics = hb_diagnostics,
    n_total = n_total,
    n_tasks = results$study_summary$n_tasks %||% 0,
    n_items = n_items,
    n_segments = n_segments,
    pop_stats = pop_stats,
    quality_indicators = if (exists("quality_indicators")) quality_indicators else NULL,
    respondent_stats = respondent_stats,
    item_diag_table = item_diag_table,
    callout = callout
  )
}


# ==============================================================================
# METHODOLOGY SECTION
# ==============================================================================

#' Transform methodology information for HTML report
#'
#' Creates a structured methodology explanation covering what MaxDiff is,
#' the estimation method used, sample/design details, and key assumptions.
#'
#' @param results List. Full results from run_maxdiff()
#' @param config List. Module configuration
#'
#' @return List with $overview, $method_detail, $design_detail,
#'   $assumptions, $callout
#'
#' @keywords internal
transform_methodology_section <- function(results, config) {

  has_hb <- !is.null(results$hb_results)
  has_logit <- !is.null(results$logit_results)

  n_respondents <- results$study_summary$n_respondents %||% 0
  n_items <- results$study_summary$n_items %||% sum(config$items$Include == 1)
  n_tasks <- results$study_summary$n_tasks %||% 0
  items_per_task <- results$study_summary$items_per_task %||% config$design_settings$Items_Per_Task %||% NA

  # --- What is MaxDiff ---
  overview <- paste0(
    'Maximum Difference Scaling (MaxDiff) is a preference measurement technique in which respondents ',
    'repeatedly choose the best and worst options from subsets of items. ',
    'By forcing trade-offs across many such tasks, MaxDiff produces a reliable ranking of items ',
    'on an interval scale of preference. Unlike simple rating scales, MaxDiff eliminates scale-use bias ',
    '(such as the tendency for some respondents to rate everything highly) and yields greater discrimination between items.'
  )

  # --- Estimation method detail ---
  if (has_hb) {
    method_detail <- paste0(
      '<strong>Hierarchical Bayes (HB)</strong> estimation was used. ',
      'HB fits a hierarchical multinomial logit model using Markov Chain Monte Carlo (MCMC) sampling. ',
      'It estimates individual-level utility parameters by borrowing strength from the population distribution, ',
      'making it the preferred method when individual-level preference data is needed (e.g., for segmentation or simulation). ',
      'HB is particularly effective with sparse data because each respondent&#39;s estimates are stabilised ',
      'by the overall population pattern.'
    )
  } else if (has_logit) {
    method_detail <- paste0(
      '<strong>Aggregate Logit</strong> estimation was used. ',
      'This fits a single multinomial logistic regression across all respondents, producing population-level ',
      'utility estimates. It is computationally efficient and appropriate when only aggregate preference rankings ',
      'are required. However, it does not capture individual-level heterogeneity in preferences.'
    )
  } else {
    method_detail <- paste0(
      '<strong>Count-based</strong> scoring was used. ',
      'This approach tallies how often each item was selected as best and worst across all tasks and respondents, ',
      'then computes a simple Best-minus-Worst score. It is the most transparent method and does not require ',
      'model assumptions, but it does not account for the experimental design structure or produce individual-level estimates.'
    )
  }

  # --- Design detail ---
  design_parts <- sprintf("The study included <strong>%d respondents</strong> evaluating <strong>%d items</strong>", n_respondents, n_items)
  if (n_tasks > 0) {
    design_parts <- paste0(design_parts, sprintf(", each completing <strong>%d choice tasks</strong>", n_tasks))
  }
  if (!is.na(items_per_task)) {
    design_parts <- paste0(design_parts, sprintf(" with <strong>%d items per task</strong>", items_per_task))
  }
  design_detail <- paste0(design_parts, ".")

  # --- Assumptions and limitations ---
  assumptions <- paste0(
    '<ul style="margin:0.5em 0;padding-left:1.5em;">',
    '<li><strong>Independence of Irrelevant Alternatives (IIA):</strong> ',
    'The logit model assumes the relative preference between any two items is unaffected by the presence or absence of other items. ',
    'This is a standard assumption in discrete choice modelling.</li>',
    '<li><strong>Stable preferences:</strong> ',
    'Respondent preferences are assumed to remain consistent throughout the survey. Task order effects are mitigated by the randomised experimental design.</li>',
    '<li><strong>Relative measurement:</strong> ',
    'MaxDiff produces relative preferences only. Scores indicate which items are preferred over others within the tested set, ',
    'but do not measure absolute desirability. An item scoring highest is the most preferred among those tested, not necessarily appealing in an absolute sense.</li>',
    '<li><strong>Item set dependence:</strong> ',
    'Adding or removing items from the set could change the relative utilities of the remaining items. Results apply to the specific set of items tested.</li>',
    '</ul>'
  )

  # --- Callout ---
  callout <- paste0(
    '<div class="md-callout md-callout-method">',
    '<strong>What is MaxDiff?</strong> ', overview,
    '</div>',
    '<div class="md-callout md-callout-method">',
    '<strong>Estimation Method:</strong> ', method_detail,
    '</div>',
    '<div class="md-callout md-callout-method">',
    '<strong>Study Design:</strong> ', design_detail,
    '</div>',
    '<div class="md-callout md-callout-method">',
    '<strong>Key Assumptions &amp; Limitations:</strong>', assumptions,
    '</div>'
  )

  list(
    overview = overview,
    method_detail = method_detail,
    design_detail = design_detail,
    assumptions = assumptions,
    callout = callout
  )
}


# ==============================================================================
# HEAD-TO-HEAD SECTION
# ==============================================================================

#' Transform head-to-head comparison data
#'
#' Computes pairwise win rates between items using preference shares or
#' utility scores. Returns a matrix of win percentages.
#'
#' @param results List. Full results from run_maxdiff()
#' @param config List. Module configuration
#'
#' @return List with $h2h_matrix (data.frame), $items, $callout, or NULL
#' @keywords internal
transform_h2h_section <- function(results, config) {

  # Build full H2H matrix from pairwise compute_head_to_head() calls
  # or directly from aggregate utilities when individual data unavailable
  h2h_data <- NULL

  # Prefer HB individual utilities for more accurate H2H
  indiv_utils <- results$hb_results$individual_utilities

  if (!is.null(indiv_utils) && exists("compute_head_to_head", mode = "function")) {
    # Get item column names (exclude non-numeric like resp_id)
    if (is.data.frame(indiv_utils)) {
      numeric_cols <- vapply(indiv_utils, is.numeric, logical(1))
      item_ids <- names(indiv_utils)[numeric_cols]
    } else {
      item_ids <- colnames(indiv_utils)
    }

    if (length(item_ids) >= 2) {
      n <- length(item_ids)
      mat <- matrix(NA_real_, nrow = n, ncol = n, dimnames = list(item_ids, item_ids))
      for (i in seq_len(n)) {
        mat[i, i] <- NA  # self vs self
        for (j in seq_len(n)) {
          if (i != j) {
            res <- tryCatch(
              compute_head_to_head(indiv_utils, item_ids[i], item_ids[j]),
              error = function(e) NULL
            )
            if (!is.null(res)) mat[i, j] <- res$prob_a
          }
        }
      }
      h2h_data <- as.data.frame(mat)
    }
  }

  # Fallback: compute from aggregate utilities using logistic formula
  if (is.null(h2h_data)) {
    agg <- NULL
    if (!is.null(results$hb_results$population_utilities)) {
      pop <- results$hb_results$population_utilities
      agg <- setNames(pop$HB_Utility_Mean, pop$Item_ID)
    } else if (!is.null(results$logit_results$utilities)) {
      lu <- results$logit_results$utilities
      agg <- setNames(lu$Logit_Utility, lu$Item_ID)
    }

    if (!is.null(agg) && length(agg) >= 2) {
      item_ids <- names(agg)
      n <- length(item_ids)
      mat <- matrix(NA_real_, nrow = n, ncol = n, dimnames = list(item_ids, item_ids))
      for (i in seq_len(n)) {
        for (j in seq_len(n)) {
          if (i != j) {
            diff <- agg[i] - agg[j]
            mat[i, j] <- round(1 / (1 + exp(-diff)) * 100, 1)
          }
        }
      }
      h2h_data <- as.data.frame(mat)
    }
  }

  if (is.null(h2h_data)) return(NULL)

  # Get item labels
  items_df <- config$items
  if (!is.null(items_df) && "Item_Label" %in% names(items_df)) {
    label_map <- setNames(items_df$Item_Label, items_df$Item_ID)
  } else {
    label_map <- NULL
  }

  callout <- paste0(
    '<div class="md-callout md-callout-result">',
    '<strong>What you&#39;re looking at:</strong> Pairwise win rates &mdash; each cell shows the probability that the row item would be preferred over the column item in a direct comparison.<br/>',
    '<strong>What it means:</strong> Values above 50% (green) mean the row item wins more often than not. This helps identify competitive matchups and clearly dominant items.<br/>',
    '<strong>What to do:</strong> Look for items that consistently win (all-green rows) or consistently lose (all-red rows). Identify close matchups (values near 50%) where positioning could shift outcomes.',
    '</div>'
  )

  list(
    h2h_data = h2h_data,
    label_map = label_map,
    callout = callout
  )
}


# ==============================================================================
# SEGMENT FILTER OPTIONS (for dropdown on analytical tabs)
# ==============================================================================

#' Extract segment filter options for dropdown rendering
#'
#' @param results List. Full results from run_maxdiff()
#' @param config List. Module configuration
#'
#' @return List with $variables (each containing levels + counts), or NULL
#' @keywords internal
transform_segment_filter_options <- function(results, config) {

  if (is.null(results$segment_results)) return(NULL)

  seg <- results$segment_results
  seg_scores <- seg$segment_scores
  if (is.null(seg_scores) || !is.data.frame(seg_scores) || nrow(seg_scores) == 0) return(NULL)

  # Filter to in-segment rows only (Segment_Value == TRUE)
  if ("Segment_Value" %in% names(seg_scores)) {
    seg_scores <- seg_scores[seg_scores$Segment_Value == TRUE, , drop = FALSE]
    if (nrow(seg_scores) == 0) return(NULL)
  }

  # Get segment config for variable grouping
  seg_cfg <- config$segment_settings
  variables <- list()

  if (!is.null(seg_cfg) && is.data.frame(seg_cfg) && "Variable_Name" %in% names(seg_cfg)) {
    # Group segments by Variable_Name from config
    for (var_name in unique(seg_cfg$Variable_Name)) {
      var_rows <- seg_cfg[seg_cfg$Variable_Name == var_name, , drop = FALSE]
      levels_list <- list()
      for (i in seq_len(nrow(var_rows))) {
        seg_id <- var_rows$Segment_ID[i]
        seg_label <- var_rows$Segment_Label[i]
        # Get N from segment_scores (all rows for this segment have same Segment_N)
        seg_rows <- seg_scores[seg_scores$Segment_ID == seg_id, , drop = FALSE]
        n_val <- if (nrow(seg_rows) > 0 && "Segment_N" %in% names(seg_rows)) {
          seg_rows$Segment_N[1]
        } else {
          NA
        }
        levels_list[[length(levels_list) + 1]] <- list(
          value = seg_id,
          label = seg_label,
          n = n_val
        )
      }
      variables[[var_name]] <- list(
        variable = var_name,
        levels = levels_list
      )
    }
  } else {
    # No config — infer from data, one group per Segment_ID
    for (seg_id in unique(seg_scores$Segment_ID)) {
      seg_rows <- seg_scores[seg_scores$Segment_ID == seg_id, , drop = FALSE]
      seg_label <- if ("Segment_Label" %in% names(seg_rows)) seg_rows$Segment_Label[1] else seg_id
      n_val <- if ("Segment_N" %in% names(seg_rows)) seg_rows$Segment_N[1] else NA
      variables[[seg_id]] <- list(
        variable = seg_id,
        levels = list(list(value = seg_id, label = seg_label, n = n_val))
      )
    }
  }

  if (length(variables) == 0) return(NULL)

  list(
    variables = variables,
    segment_scores = seg_scores
  )
}


# ==============================================================================
# INDIVIDUAL UTILITY DISTRIBUTIONS (for violin/raincloud chart)
# ==============================================================================

#' Compute per-item utility distribution summaries for violin chart
#'
#' @param results List. Full results from run_maxdiff()
#'
#' @return Data frame with Item_ID, Mean, Median, SD, Q25, Q75, Min, Max, or NULL
#' @keywords internal
transform_utility_distributions <- function(results) {

  indiv <- results$hb_results$individual_utilities
  if (is.null(indiv)) return(NULL)

  # Get numeric columns only
  if (is.data.frame(indiv)) {
    numeric_cols <- vapply(indiv, is.numeric, logical(1))
    item_ids <- names(indiv)[numeric_cols]
    mat <- as.matrix(indiv[, numeric_cols, drop = FALSE])
  } else {
    mat <- as.matrix(indiv)
    item_ids <- colnames(mat)
  }

  if (is.null(item_ids) || length(item_ids) < 2) return(NULL)

  # Compute summary stats per item
  dist_df <- data.frame(
    Item_ID = item_ids,
    Mean = vapply(item_ids, function(id) mean(mat[, id], na.rm = TRUE), numeric(1)),
    Median = vapply(item_ids, function(id) median(mat[, id], na.rm = TRUE), numeric(1)),
    SD = vapply(item_ids, function(id) sd(mat[, id], na.rm = TRUE), numeric(1)),
    Q25 = vapply(item_ids, function(id) quantile(mat[, id], 0.25, na.rm = TRUE), numeric(1)),
    Q75 = vapply(item_ids, function(id) quantile(mat[, id], 0.75, na.rm = TRUE), numeric(1)),
    Min = vapply(item_ids, function(id) min(mat[, id], na.rm = TRUE), numeric(1)),
    Max = vapply(item_ids, function(id) max(mat[, id], na.rm = TRUE), numeric(1)),
    stringsAsFactors = FALSE
  )
  rownames(dist_df) <- NULL

  # Compute density estimates for each item (for violin shape)
  densities <- lapply(item_ids, function(id) {
    vals <- mat[, id]
    vals <- vals[!is.na(vals)]
    if (length(vals) < 3) return(NULL)
    d <- density(vals, n = 32)
    list(x = d$x, y = d$y)
  })
  names(densities) <- item_ids

  # Get labels from population utilities if available
  pop <- results$hb_results$population_utilities
  if (!is.null(pop) && "Item_Label" %in% names(pop)) {
    label_map <- setNames(pop$Item_Label, pop$Item_ID)
    dist_df$Item_Label <- label_map[dist_df$Item_ID]
  } else {
    dist_df$Item_Label <- dist_df$Item_ID
  }

  # Sort by mean descending
  dist_df <- dist_df[order(-dist_df$Mean), ]
  rownames(dist_df) <- NULL

  list(
    summary = dist_df,
    densities = densities[dist_df$Item_ID]
  )
}


# ==============================================================================
# SEGMENT ENRICHMENT (preference shares + H2H per segment)
# ==============================================================================

#' Enrich segment scores with preference shares and rescaled scores
#'
#' Takes the basic segment_scores (which only contain BW_Score) and enriches
#' each segment with preference shares and 0-100 rescaled scores computed
#' from individual-level HB utilities filtered to segment respondents.
#'
#' @param segment_scores Data frame. Output from compute_segment_scores()
#' @param individual_utils Data frame/matrix. Respondent x item utilities (with resp_id col)
#' @param raw_data Data frame. Original survey data with segment variables
#' @param segment_settings Data frame. Config segment definitions
#' @param items Data frame. Config items (Item_ID, Item_Label, Include)
#'
#' @return Enriched segment_scores data frame with Pref_Share, Rescaled, Rank columns
#' @keywords internal
enrich_segment_scores <- function(segment_scores, individual_utils, raw_data,
                                   segment_settings, items) {

  if (is.null(segment_scores) || is.null(individual_utils) ||
      is.null(raw_data) || is.null(segment_settings)) {
    return(segment_scores)
  }

  # Get numeric item columns from individual utilities
  if (is.data.frame(individual_utils)) {
    numeric_cols <- vapply(individual_utils, is.numeric, logical(1))
    resp_ids <- if ("resp_id" %in% names(individual_utils)) {
      individual_utils$resp_id
    } else {
      seq_len(nrow(individual_utils))
    }
    utils_mat <- as.matrix(individual_utils[, numeric_cols, drop = FALSE])
  } else {
    utils_mat <- as.matrix(individual_utils)
    resp_ids <- seq_len(nrow(utils_mat))
  }

  item_ids <- colnames(utils_mat)
  if (is.null(item_ids) || length(item_ids) < 2) return(segment_scores)

  # Build respondent-to-raw-data mapping
  resp_id_var <- names(raw_data)[1]
  resp_map <- data.frame(
    resp_id = resp_ids,
    stringsAsFactors = FALSE
  )
  resp_map <- merge(resp_map, raw_data, by.x = "resp_id", by.y = resp_id_var, all.x = TRUE)

  # Get item labels
  label_map <- if (!is.null(items) && "Item_Label" %in% names(items)) {
    setNames(items$Item_Label, items$Item_ID)
  } else {
    setNames(item_ids, item_ids)
  }

  # Process each segment
  enriched_rows <- list()

  for (i in seq_len(nrow(segment_settings))) {
    seg_id <- segment_settings$Segment_ID[i]
    seg_label <- segment_settings$Segment_Label[i]
    seg_var <- segment_settings$Variable_Name[i]
    seg_def <- segment_settings$Segment_Def[i]
    include <- segment_settings$Include_in_Output[i]

    if (include != 1) next
    if (!seg_var %in% names(resp_map)) next

    # Determine segment membership
    if (!is.null(seg_def) && !is.na(seg_def) && nzchar(trimws(seg_def))) {
      seg_membership <- tryCatch(
        safe_eval_expression(seg_def, resp_map, context = sprintf("enrich segment '%s'", seg_id)),
        error = function(e) NULL)
    } else {
      seg_membership <- resp_map[[seg_var]]
    }

    if (is.null(seg_membership)) next

    # Get respondent indices in this segment
    seg_indices <- which(seg_membership == TRUE)
    if (length(seg_indices) < 2) next

    # Filter utilities to segment respondents
    seg_utils <- utils_mat[seg_indices, , drop = FALSE]

    # Compute preference shares for this segment (softmax per respondent, then average)
    n_resp <- nrow(seg_utils)
    shares_mat <- matrix(0, nrow = n_resp, ncol = ncol(seg_utils))
    worst_mat <- matrix(0, nrow = n_resp, ncol = ncol(seg_utils))
    for (r in seq_len(n_resp)) {
      row_utils <- seg_utils[r, ]
      # Best probability: softmax of utilities
      exp_u <- exp(row_utils - max(row_utils, na.rm = TRUE))
      shares_mat[r, ] <- exp_u / sum(exp_u, na.rm = TRUE)
      # Worst probability: softmax of negative utilities
      neg_utils <- -row_utils
      exp_neg <- exp(neg_utils - max(neg_utils, na.rm = TRUE))
      worst_mat[r, ] <- exp_neg / sum(exp_neg, na.rm = TRUE)
    }
    avg_shares <- colMeans(shares_mat, na.rm = TRUE) * 100
    avg_worst <- colMeans(worst_mat, na.rm = TRUE) * 100
    names(avg_shares) <- item_ids
    names(avg_worst) <- item_ids

    # Compute rescaled 0-100 scores from mean segment utilities
    mean_utils <- colMeans(seg_utils, na.rm = TRUE)
    sd_utils <- apply(seg_utils, 2, sd, na.rm = TRUE)
    min_u <- min(mean_utils, na.rm = TRUE)
    max_u <- max(mean_utils, na.rm = TRUE)
    range_u <- max_u - min_u
    rescaled <- if (range_u > 0) (mean_utils - min_u) / range_u * 100 else rep(50, length(mean_utils))
    names(rescaled) <- item_ids

    # Build enriched rows for this segment
    included_items <- if (!is.null(items) && "Include" %in% names(items)) {
      items$Item_ID[items$Include == 1]
    } else {
      item_ids
    }
    included_items <- intersect(included_items, item_ids)

    seg_df <- data.frame(
      Item_ID = included_items,
      Item_Label = vapply(included_items, function(id) label_map[[id]] %||% id, character(1)),
      Pref_Share = avg_shares[included_items],
      Rescaled = rescaled[included_items],
      Best_Pct = round(avg_shares[included_items], 1),
      Worst_Pct = round(avg_worst[included_items], 1),
      HB_Utility_Mean = round(mean_utils[included_items], 4),
      HB_Utility_SD = round(sd_utils[included_items], 4),
      stringsAsFactors = FALSE
    )
    seg_df <- seg_df[order(-seg_df$Rescaled), ]
    seg_df$Rank <- seq_len(nrow(seg_df))

    # Merge with existing BW_Score from segment_scores
    existing <- segment_scores[segment_scores$Segment_ID == seg_id, , drop = FALSE]
    if ("Segment_Value" %in% names(existing)) {
      existing <- existing[existing$Segment_Value == TRUE, , drop = FALSE]
    }

    if (nrow(existing) > 0 && "BW_Score" %in% names(existing)) {
      bw_map <- setNames(existing$BW_Score, existing$Item_ID %||% existing$Item_Label)
      seg_df$BW_Score <- vapply(seg_df$Item_ID, function(id) {
        bw_map[[id]] %||% NA_real_
      }, numeric(1))
    } else {
      seg_df$BW_Score <- NA_real_
    }

    seg_df$Segment_ID <- seg_id
    seg_df$Segment_Label <- seg_label
    seg_df$Segment_Value <- TRUE
    seg_df$Variable_Name <- seg_var
    seg_df$Segment_N <- length(seg_indices)

    enriched_rows[[seg_id]] <- seg_df
  }

  if (length(enriched_rows) == 0) return(segment_scores)

  do.call(rbind, enriched_rows)
}


#' Compute per-segment head-to-head matrices
#'
#' For each segment, filters individual utilities to segment respondents
#' and computes a full H2H comparison matrix.
#'
#' @param individual_utils Data frame/matrix. Respondent x item utilities (with resp_id col)
#' @param raw_data Data frame. Original survey data with segment variables
#' @param segment_settings Data frame. Config segment definitions
#' @param items Data frame. Config items
#' @param label_map Named character vector. Item_ID -> Item_Label
#'
#' @return Named list of H2H data frames (one per segment key like "Variable:Segment_ID")
#' @keywords internal
compute_segment_h2h <- function(individual_utils, raw_data, segment_settings,
                                 items, label_map = NULL) {

  if (is.null(individual_utils) || is.null(raw_data) || is.null(segment_settings)) {
    return(NULL)
  }

  # Get numeric item columns
  if (is.data.frame(individual_utils)) {
    numeric_cols <- vapply(individual_utils, is.numeric, logical(1))
    resp_ids <- if ("resp_id" %in% names(individual_utils)) {
      individual_utils$resp_id
    } else {
      seq_len(nrow(individual_utils))
    }
    utils_mat <- as.matrix(individual_utils[, numeric_cols, drop = FALSE])
  } else {
    utils_mat <- as.matrix(individual_utils)
    resp_ids <- seq_len(nrow(utils_mat))
  }

  item_ids <- colnames(utils_mat)
  if (is.null(item_ids) || length(item_ids) < 2) return(NULL)

  # Build respondent mapping
  resp_id_var <- names(raw_data)[1]
  resp_map <- data.frame(resp_id = resp_ids, stringsAsFactors = FALSE)
  resp_map <- merge(resp_map, raw_data, by.x = "resp_id", by.y = resp_id_var, all.x = TRUE)

  h2h_list <- list()

  for (i in seq_len(nrow(segment_settings))) {
    seg_id <- segment_settings$Segment_ID[i]
    seg_var <- segment_settings$Variable_Name[i]
    seg_def <- segment_settings$Segment_Def[i]
    include <- segment_settings$Include_in_Output[i]

    if (include != 1) next
    if (!seg_var %in% names(resp_map)) next

    # Determine membership
    if (!is.null(seg_def) && !is.na(seg_def) && nzchar(trimws(seg_def))) {
      seg_membership <- tryCatch(
        safe_eval_expression(seg_def, resp_map, context = sprintf("h2h segment '%s'", seg_id)),
        error = function(e) NULL)
    } else {
      seg_membership <- resp_map[[seg_var]]
    }

    if (is.null(seg_membership)) next

    seg_indices <- which(seg_membership == TRUE)
    if (length(seg_indices) < 2) next

    seg_utils <- utils_mat[seg_indices, , drop = FALSE]

    # Compute H2H matrix for this segment
    n <- length(item_ids)
    mat <- matrix(NA_real_, nrow = n, ncol = n, dimnames = list(item_ids, item_ids))
    for (a in seq_len(n)) {
      for (b in seq_len(n)) {
        if (a != b) {
          diff <- seg_utils[, a] - seg_utils[, b]
          prob_a <- mean(1 / (1 + exp(-diff)), na.rm = TRUE)
          mat[a, b] <- round(prob_a * 100, 1)
        }
      }
    }

    seg_key <- paste0(seg_var, ":", seg_id)
    h2h_list[[seg_key]] <- as.data.frame(mat)
  }

  if (length(h2h_list) == 0) return(NULL)
  h2h_list
}
