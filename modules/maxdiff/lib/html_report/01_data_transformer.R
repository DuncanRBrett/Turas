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

  list(
    meta = meta,
    summary = summary_data,
    preferences = preferences,
    items = items_analysis,
    head_to_head = head_to_head,
    segments = segments,
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

  callout <- paste0(
    '<div class="md-callout md-callout-result">',
    '<strong>What you&#39;re looking at:</strong> Each item&#39;s preference share (probability of being chosen from the full set, summing to 100%) and rescaled utility score (0&ndash;100 scale).<br/>',
    '<strong>What it means:</strong> Higher preference shares mean an item is more likely to be selected. An item with 20% share is twice as likely to be chosen as one with 10%. ',
    'The 0&ndash;100 scores show relative preference strength &mdash; items are comparable within this study only, not to an external standard.<br/>',
    '<strong>What to do:</strong> Use the toggle to switch between preference shares and raw utility scores. Click column headers to re-sort the table.',
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

  has_hb_diag <- !is.null(hb_diagnostics)
  has_logit_diag <- !is.null(logit_fit)

  diag_parts <- '<div class="md-callout md-callout-result"><strong>What you&#39;re looking at:</strong> Technical measures that confirm whether the statistical model ran correctly and produced reliable estimates.<br/>'
  diag_parts <- paste0(diag_parts, '<strong>What it means:</strong> ')
  if (has_hb_diag) {
    diag_parts <- paste0(diag_parts,
      'R-hat below 1.05 = the model converged (green badge = good). ',
      'ESS above 400 = enough independent samples for reliable estimates. ',
      'Zero divergent transitions = the model explored the parameter space cleanly.'
    )
  }
  if (has_logit_diag) {
    if (has_hb_diag) diag_parts <- paste0(diag_parts, ' ')
    diag_parts <- paste0(diag_parts,
      'McFadden pseudo R&sup2; above 0.2 = good model fit for discrete choice. ',
      'Lower AIC/BIC = better fit.'
    )
  }
  if (!has_hb_diag && !has_logit_diag) {
    diag_parts <- paste0(diag_parts,
      'Count-based analysis does not produce model fit statistics. ',
      'Consider HB or Logit estimation for formal diagnostics.'
    )
  }
  diag_parts <- paste0(diag_parts, '<br/><strong>What to do:</strong> ')
  if (has_hb_diag || has_logit_diag) {
    diag_parts <- paste0(diag_parts, 'If all badges are green, results are reliable. If any show warnings, consult the methodology section below for guidance.')
  } else {
    diag_parts <- paste0(diag_parts, 'Review study design metrics to ensure adequate sample size and task coverage.')
  }
  callout <- paste0(diag_parts, '</div>')

  list(
    logit_fit = logit_fit,
    hb_diagnostics = hb_diagnostics,
    n_total = results$study_summary$n_respondents %||% 0,
    n_tasks = results$study_summary$n_tasks %||% 0,
    n_items = results$study_summary$n_items %||% 0,
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
