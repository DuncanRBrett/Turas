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

  # --- Build methodology ---
  methodology <- transform_methodology_section(maxdiff_results, config)

  list(
    meta = meta,
    summary = summary_data,
    preferences = preferences,
    items = items_analysis,
    segments = segments,
    turf = turf,
    diagnostics = diagnostics,
    methodology = methodology
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
      <strong>Key Finding:</strong> Among %d items evaluated by %d respondents,
      <strong>%s</strong> emerged as the most preferred item.%s
    </div>
    <div class="md-callout md-callout-method">
      <strong>Estimation Method:</strong> %s %s
    </div>',
    meta$n_items, meta$n_total, htmlEscape(top_item), top_lead_text,
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
    '<div class="md-callout md-callout-method">',
    '<strong>Rescaled Scores (0&ndash;100):</strong> ',
    'Utility estimates have been rescaled to a 0&ndash;100 range for ease of interpretation, ',
    'where 0 represents the least preferred item and 100 represents the most preferred item among those tested. ',
    'These scores reflect relative preference strength &mdash; items are only comparable to each other within this study, ',
    'not to an external or absolute standard.',
    '</div>',
    '<div class="md-callout md-callout-method">',
    '<strong>Preference Shares:</strong> ',
    'Preference shares represent each item&#39;s estimated probability of being chosen from the full set, ',
    'derived from the multinomial logit model. They sum to 100% and are the most intuitive metric for comparing items. ',
    'An item with a 20% preference share is twice as likely to be chosen as one with a 10% share.',
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
    '<div class="md-callout md-callout-method">',
    '<strong>Item Analysis &mdash; Best/Worst Counts:</strong> ',
    '<strong>Best%</strong> is the percentage of times an item was selected as best (most preferred) when it appeared in a task. ',
    '<strong>Worst%</strong> is the percentage of times it was selected as worst (least preferred) when shown. ',
    '<strong>BW Score</strong> = (Best% &minus; Worst%) &divide; 100, ranging from &minus;1 (universally disliked &mdash; always chosen as worst) ',
    'to +1 (universally preferred &mdash; always chosen as best). ',
    'A score near zero indicates the item generates neither strong positive nor strong negative sentiment.',
    '</div>',
    '<div class="md-callout md-callout-result">',
    '<strong>Reading the Chart:</strong> ',
    'The diverging bar chart makes it easy to spot items with strong positive or negative sentiment. ',
    'Items extending far to the right are clear favourites; items extending to the left are consistently rejected.',
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
    '<strong>Segment Analysis:</strong> ',
    'This section shows how preferences vary across different respondent segments. ',
    'Items where segments diverge represent potential targeting opportunities &mdash; ',
    'features or messages that resonate strongly with one group but not others.',
    '</div>',
    '<div class="md-callout md-callout-method">',
    '<strong>Interpretation Note:</strong> ',
    'Differences shown are descriptive only &mdash; no formal statistical significance test has been applied. ',
    'Apparent differences between small segments may reflect sampling variability rather than true preference differences. ',
    'Consider segment sample sizes when drawing conclusions.',
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

  callout <- sprintf(
    '%s%s',
    sprintf(
      '<div class="md-callout md-callout-result"><strong>Portfolio Optimization (TURF):</strong> Portfolio optimization identifies the combination of items that appeals to the widest audience. A portfolio of %d items reaches <strong>%.1f%%</strong> of respondents.%s</div>',
      nrow(turf$incremental_table),
      max(turf$incremental_table$Reach_Pct, 0),
      threshold_text
    ),
    paste0(
      '<div class="md-callout md-callout-method">',
      '<strong>How It Works:</strong> ',
      '<strong>Reach</strong> is the percentage of respondents for whom at least one item in the portfolio is appealing. ',
      'Items are added one at a time using a greedy algorithm: at each step, the item that brings the most new people into the portfolio&#39;s audience is selected. ',
      'This is a greedy approximation that is optimal for practical purposes but is not guaranteed to find the globally optimal combination for every possible portfolio size.',
      '</div>'
    )
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

  has_hb_diag <- !is.null(hb_diagnostics)
  has_logit_diag <- !is.null(logit_fit)

  diag_parts <- '<div class="md-callout md-callout-method"><strong>Diagnostics:</strong> '
  if (has_hb_diag) {
    diag_parts <- paste0(diag_parts,
      '<strong>Convergence (HB):</strong> ',
      'R-hat values below 1.05 indicate the MCMC chains have converged to the target distribution. ',
      'Effective Sample Size (ESS) above 400 suggests sufficient independent draws for reliable posterior summaries. ',
      'Divergent transitions above 0 may indicate model misspecification or overly complex likelihood surfaces &mdash; ',
      'results should be interpreted with caution if divergences are present.'
    )
  }
  if (has_logit_diag) {
    if (has_hb_diag) diag_parts <- paste0(diag_parts, '<br/><br/>')
    diag_parts <- paste0(diag_parts,
      '<strong>Model Fit (Logit):</strong> ',
      'McFadden&#39;s pseudo R&sup2; above 0.2 is generally considered good fit for discrete choice models. ',
      'AIC and BIC provide relative measures for comparing alternative model specifications &mdash; lower values indicate better fit.'
    )
  }
  if (!has_hb_diag && !has_logit_diag) {
    diag_parts <- paste0(diag_parts,
      'Count-based analysis does not produce model fit statistics. ',
      'Consider using Hierarchical Bayes or Aggregate Logit estimation for formal diagnostic measures.'
    )
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
