# ==============================================================================
# CONFIDENCE HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Transforms raw confidence_results into an HTML-ready structure with
# plain-English callouts and quality badges.
# ==============================================================================

#' Transform Confidence Results for HTML Rendering
#'
#' Converts the raw results list from run_confidence_analysis() into a
#' structured format optimised for HTML report generation, including
#' plain-English callout text and quality assessments.
#'
#' @param confidence_results List from run_confidence_analysis()
#' @param config List with optional settings
#' @return List with summary, study_level, questions, warnings, methodology
#' @keywords internal
transform_confidence_for_html <- function(confidence_results, config = list()) {
  cr <- confidence_results
  analysis_config <- cr$config

  # Extract key metadata
  conf_level <- as.numeric(analysis_config$study_settings$Confidence_Level %||% 0.95)
  boot_iter <- as.integer(analysis_config$study_settings$Bootstrap_Iterations %||% 1000)
  weight_var <- analysis_config$file_paths$Weight_Variable
  sampling_method <- config$sampling_method %||%
    (analysis_config$study_settings$Sampling_Method %||% "Not_Specified")
  if (is.na(sampling_method) || !nzchar(trimws(sampling_method))) {
    sampling_method <- "Not_Specified"
  }

  is_weighted <- !is.null(weight_var) && !is.na(weight_var) && nzchar(trimws(weight_var))

  # Study-level stats
  study_stats <- cr$study_stats
  n_total <- if (!is.null(study_stats)) study_stats$Actual_n[1] else NA
  n_eff <- if (!is.null(study_stats)) study_stats$Effective_n[1] else n_total
  deff <- if (!is.null(study_stats)) study_stats$DEFF[1] else 1.0

  # Count question types
  prop_results <- cr$proportion_results %||% list()
  mean_results <- cr$mean_results %||% list()
  nps_results <- cr$nps_results %||% list()

  # Build unified question list
  questions <- list()

  for (q_id in names(prop_results)) {
    questions[[q_id]] <- transform_proportion_question(q_id, prop_results[[q_id]],
                                                        conf_level, n_eff, is_weighted,
                                                        sampling_method)
  }

  for (q_id in names(mean_results)) {
    questions[[q_id]] <- transform_mean_question(q_id, mean_results[[q_id]],
                                                  conf_level, n_eff, is_weighted,
                                                  sampling_method)
  }

  for (q_id in names(nps_results)) {
    questions[[q_id]] <- transform_nps_question(q_id, nps_results[[q_id]],
                                                 conf_level, n_eff, is_weighted,
                                                 sampling_method)
  }

  # Attach question labels from config (if Question_Label column exists)
  qa <- analysis_config$question_analysis
  if (!is.null(qa) && "Question_Label" %in% names(qa)) {
    label_map <- setNames(
      as.character(qa$Question_Label),
      as.character(qa$Question_ID)
    )
    for (q_id in names(questions)) {
      lbl <- label_map[[q_id]]
      questions[[q_id]]$question_label <- if (!is.null(lbl) && !is.na(lbl) &&
                                               nzchar(trimws(lbl))) trimws(lbl) else q_id
    }
  } else {
    # No label column — default label to question_id
    for (q_id in names(questions)) {
      questions[[q_id]]$question_label <- q_id
    }
  }

  # Determine methods used
  methods_used <- character()
  for (q in questions) {
    methods_used <- union(methods_used, q$methods_used)
  }

  # Weight concentration and margin comparison
  weight_concentration <- NULL
  margin_comparison <- NULL
  if (!is.null(study_stats)) {
    weight_concentration <- attr(study_stats, "weight_concentration")
    margin_comparison <- attr(study_stats, "margin_comparison")
  }

  list(
    summary = list(
      project_name = config$project_name %||%
        (analysis_config$study_settings$Project_Name %||% "Confidence Analysis"),
      generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      n_total = n_total,
      n_effective = n_eff,
      deff = deff,
      n_proportions = length(prop_results),
      n_means = length(mean_results),
      n_nps = length(nps_results),
      n_questions = length(questions),
      confidence_level = conf_level,
      weight_variable = weight_var,
      is_weighted = is_weighted,
      sampling_method = sampling_method
    ),
    study_level = list(
      stats_df = study_stats,
      weight_concentration = weight_concentration,
      margin_comparison = margin_comparison
    ),
    questions = questions,
    warnings = cr$warnings %||% character(),
    methodology = list(
      methods_used = methods_used,
      confidence_level = conf_level,
      bootstrap_iterations = boot_iter
    )
  )
}


# ==============================================================================
# QUESTION TRANSFORMERS
# ==============================================================================

#' @keywords internal
transform_proportion_question <- function(q_id, result, conf_level, global_n_eff,
                                           is_weighted, sampling_method = "Not_Specified") {
  methods_used <- character()
  best_ci <- NULL

  # Find best available CI for summary
  if (!is.null(result$wilson)) {
    best_ci <- result$wilson
    methods_used <- c(methods_used, "Wilson Score")
  }
  if (!is.null(result$moe)) {
    if (is.null(best_ci)) best_ci <- result$moe
    methods_used <- c(methods_used, "Normal Approximation (MOE)")
  }
  if (!is.null(result$bootstrap)) {
    if (is.null(best_ci)) best_ci <- result$bootstrap
    methods_used <- c(methods_used, "Bootstrap")
  }
  if (!is.null(result$bayesian)) {
    if (is.null(best_ci)) best_ci <- result$bayesian
    methods_used <- c(methods_used, "Bayesian Credible")
  }

  p <- result$proportion %||% result$p %||% NA
  n <- result$n %||% NA
  n_eff <- result$n_eff %||% global_n_eff

  ci_lower <- if (!is.null(best_ci)) best_ci$lower else NA
  ci_upper <- if (!is.null(best_ci)) best_ci$upper else NA
  ci_width <- if (!is.na(ci_lower) && !is.na(ci_upper)) (ci_upper - ci_lower) * 100 else NA

  sl <- get_sampling_labels(sampling_method)
  quality <- assess_quality(n_eff, ci_width, result, labels = sl)
  callout <- generate_proportion_callout(q_id, p, ci_lower, ci_upper, n_eff,
                                          conf_level, is_weighted, quality,
                                          methods_used, sampling_method)

  list(
    type = "proportion",
    question_id = q_id,
    estimate = p,
    estimate_pct = if (!is.na(p)) round(p * 100, 1) else NA,
    n = n,
    n_eff = n_eff,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_width = ci_width,
    results = result,
    quality = quality,
    callout = callout,
    methods_used = methods_used
  )
}

#' @keywords internal
transform_mean_question <- function(q_id, result, conf_level, global_n_eff,
                                     is_weighted, sampling_method = "Not_Specified") {
  methods_used <- character()
  best_ci <- NULL

  if (!is.null(result$t_dist)) {
    best_ci <- result$t_dist
    methods_used <- c(methods_used, "t-Distribution")
  }
  if (!is.null(result$bootstrap)) {
    if (is.null(best_ci)) best_ci <- result$bootstrap
    methods_used <- c(methods_used, "Bootstrap")
  }
  if (!is.null(result$bayesian)) {
    if (is.null(best_ci)) best_ci <- result$bayesian
    methods_used <- c(methods_used, "Bayesian Credible")
  }

  mean_val <- result$mean %||% NA
  sd_val <- result$sd %||% NA
  n <- result$n %||% NA
  n_eff <- result$n_eff %||% global_n_eff

  ci_lower <- if (!is.null(best_ci)) best_ci$lower else NA
  ci_upper <- if (!is.null(best_ci)) best_ci$upper else NA
  ci_width <- if (!is.na(ci_lower) && !is.na(ci_upper)) ci_upper - ci_lower else NA

  sl <- get_sampling_labels(sampling_method)
  quality <- assess_quality_mean(n_eff, ci_width, sd_val, mean_val, result, labels = sl)
  callout <- generate_mean_callout(q_id, mean_val, ci_lower, ci_upper, n_eff,
                                    conf_level, is_weighted, quality,
                                    methods_used, sampling_method)

  list(
    type = "mean",
    question_id = q_id,
    estimate = mean_val,
    estimate_pct = NA,
    n = n,
    n_eff = n_eff,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_width = ci_width,
    results = result,
    quality = quality,
    callout = callout,
    methods_used = methods_used
  )
}

#' @keywords internal
transform_nps_question <- function(q_id, result, conf_level, global_n_eff,
                                    is_weighted, sampling_method = "Not_Specified") {
  methods_used <- character()
  best_ci <- NULL

  if (!is.null(result$moe_normal)) {
    best_ci <- result$moe_normal
    methods_used <- c(methods_used, "Normal Approximation")
  }
  if (!is.null(result$bootstrap)) {
    if (is.null(best_ci)) best_ci <- result$bootstrap
    methods_used <- c(methods_used, "Bootstrap")
  }
  if (!is.null(result$bayesian)) {
    if (is.null(best_ci)) best_ci <- result$bayesian
    methods_used <- c(methods_used, "Bayesian Credible")
  }

  nps_score <- result$nps_score %||% NA
  n <- result$n %||% NA
  n_eff <- result$n_eff %||% global_n_eff

  ci_lower <- if (!is.null(best_ci)) best_ci$lower else NA
  ci_upper <- if (!is.null(best_ci)) best_ci$upper else NA
  ci_width <- if (!is.na(ci_lower) && !is.na(ci_upper)) ci_upper - ci_lower else NA

  sl <- get_sampling_labels(sampling_method)
  quality <- assess_quality(n_eff, ci_width, result, labels = sl)
  callout <- generate_nps_callout(q_id, nps_score, ci_lower, ci_upper, n_eff,
                                   conf_level, is_weighted, quality,
                                   result$pct_promoters, result$pct_detractors,
                                   methods_used, sampling_method)

  list(
    type = "nps",
    question_id = q_id,
    estimate = nps_score,
    estimate_pct = NA,
    n = n,
    n_eff = n_eff,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_width = ci_width,
    results = result,
    quality = quality,
    callout = callout,
    methods_used = methods_used
  )
}


# ==============================================================================
# QUALITY ASSESSMENT
# ==============================================================================

#' @keywords internal
assess_quality <- function(n_eff, ci_width_pp, result, labels = NULL) {
  # ci_width_pp is in percentage points for proportions, raw for NPS
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  badge <- "good"
  reasons <- character()

  if (is.na(n_eff) || n_eff < 30) {
    badge <- "poor"
    reasons <- c(reasons, "Very small effective sample size (below 30)")
  } else if (n_eff < 100) {
    badge <- if (badge != "poor") "warn" else badge
    reasons <- c(reasons, "Small effective sample size (below 100)")
  }

  if (!is.na(ci_width_pp) && ci_width_pp > 20) {
    badge <- "poor"
    reasons <- c(reasons, sprintf("Very wide %s (over 20 percentage points)", tolower(labels$interval_name)))
  } else if (!is.na(ci_width_pp) && ci_width_pp > 10) {
    badge <- if (badge != "poor") "warn" else badge
    reasons <- c(reasons, sprintf("Wide %s (over 10 percentage points)", tolower(labels$interval_name)))
  }

  list(badge = badge, reasons = reasons)
}

#' @keywords internal
assess_quality_mean <- function(n_eff, ci_width, sd_val, mean_val, result, labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  badge <- "good"
  reasons <- character()

  if (is.na(n_eff) || n_eff < 30) {
    badge <- "poor"
    reasons <- c(reasons, "Very small effective sample size (below 30)")
  } else if (n_eff < 100) {
    badge <- if (badge != "poor") "warn" else badge
    reasons <- c(reasons, "Small effective sample size (below 100)")
  }

  # For means, check CI width relative to SD
  if (!is.na(ci_width) && !is.na(sd_val) && sd_val > 0) {
    relative_width <- ci_width / sd_val
    if (relative_width > 1.5) {
      badge <- "poor"
      reasons <- c(reasons, sprintf("%s width exceeds 1.5 standard deviations", labels$interval_abbrev))
    } else if (relative_width > 0.8) {
      badge <- if (badge != "poor") "warn" else badge
      reasons <- c(reasons, sprintf("%s width is large relative to the standard deviation", labels$interval_abbrev))
    }
  }

  list(badge = badge, reasons = reasons)
}


# ==============================================================================
# CALLOUT TEXT GENERATORS (Plain English with assumption warnings)
# ==============================================================================

#' Generate structured proportion callout (3 visual sections)
#' @keywords internal
generate_proportion_callout <- function(q_id, p, lower, upper, n_eff,
                                         conf_level, is_weighted, quality,
                                         methods_used,
                                         sampling_method = "Not_Specified") {
  pct <- round(conf_level * 100)
  labels <- get_sampling_labels(sampling_method)
  sections <- character()

  # === SECTION 1: KEY RESULT (blue callout) ===
  result_parts <- character()
  if (!is.na(p) && !is.na(lower) && !is.na(upper)) {
    moe <- round((upper - lower) / 2 * 100, 1)
    result_parts <- c(result_parts, sprintf(
      "The observed proportion is <strong>%.1f%%</strong>, with a %d%% %s of <strong>%.1f%% to %.1f%%</strong> (&plusmn;%.1f pp).",
      p * 100, pct, labels$interval_term, lower * 100, upper * 100, moe
    ))
    if (moe <= 3) {
      result_parts <- c(result_parts, "This is a tight, highly precise estimate.")
    } else if (moe <= 5) {
      result_parts <- c(result_parts, "This is a reasonably precise estimate.")
    } else if (moe <= 10) {
      result_parts <- c(result_parts, "Moderately wide &mdash; the direction is clear, but treat the exact figure with caution.")
    } else {
      result_parts <- c(result_parts, "<strong>Caution:</strong> Very wide interval &mdash; the true value is quite uncertain. A larger sample would help.")
    }
    if (quality$badge != "good") {
      result_parts <- c(result_parts, paste0(
        "<strong>", if (quality$badge == "poor") "Quality concern" else "Note", ":</strong> ",
        paste(quality$reasons, collapse = ". "), "."
      ))
    }
  }
  sections <- c(sections, sprintf(
    '<div class="ci-callout ci-callout-result">%s</div>',
    paste(result_parts, collapse = " ")
  ))

  # === SECTION 2: METHOD NOTES (grey callout) ===
  method_parts <- character()

  if ("Wilson Score" %in% methods_used) {
    method_parts <- c(method_parts,
      "<strong>Wilson score</strong> (Wilson, 1927) &mdash; preferred for proportion CIs because it maintains reliable coverage even when proportions are extreme or sample sizes are small, unlike the standard &plusmn; margin of error which can produce impossible values below 0% or above 100%."
    )
  }
  if ("Normal Approximation (MOE)" %in% methods_used) {
    method_parts <- c(method_parts,
      "<strong>Normal approximation (MOE)</strong> &mdash; the classic &plusmn; margin of error. Works well for mid-range proportions (20&ndash;80%) with large samples."
    )
  }
  if ("Bootstrap" %in% methods_used) {
    method_parts <- c(method_parts,
      "<strong>Bootstrap</strong> &mdash; estimates the interval by resampling the data thousands of times. Makes no distributional assumptions, so it is robust for unusual response patterns."
    )
  }
  if ("Bayesian Credible" %in% methods_used) {
    method_parts <- c(method_parts, sprintf(
      "<strong>Bayesian credible interval</strong> &mdash; unlike the frequentist methods above (which say \"this method is right %d%% of the time\"), the Bayesian interval gives a direct probability: \"there is a %d%% chance the true value is in this range.\" Bayesian intervals also do not depend on the concept of repeated random sampling, which can make them more meaningful for non-random or one-off studies.",
      pct, pct
    ))
  }
  if (is_weighted) {
    method_parts <- c(method_parts, sprintf(
      "<strong>Weighting:</strong> Effective n&nbsp;=&nbsp;%s (Kish, 1965). Intervals are widened to reflect precision loss from unequal weights.",
      if (!is.na(n_eff)) format(n_eff, big.mark = ",") else "unknown"
    ))
  }
  if (length(method_parts) > 0) {
    sections <- c(sections, sprintf(
      '<div class="ci-callout ci-callout-method"><p>%s</p></div>',
      paste(method_parts, collapse = "</p><p>")
    ))
  }

  # === SECTION 3: SAMPLING NOTE (amber callout) ===
  sections <- c(sections, build_sampling_note(sampling_method))

  paste(sections, collapse = "\n")
}


#' Generate structured mean callout (3 visual sections)
#' @keywords internal
generate_mean_callout <- function(q_id, mean_val, lower, upper, n_eff,
                                   conf_level, is_weighted, quality,
                                   methods_used,
                                   sampling_method = "Not_Specified") {
  pct <- round(conf_level * 100)
  labels <- get_sampling_labels(sampling_method)
  sections <- character()

  # === SECTION 1: KEY RESULT (blue callout) ===
  result_parts <- character()
  if (!is.na(mean_val) && !is.na(lower) && !is.na(upper)) {
    width <- upper - lower
    result_parts <- c(result_parts, sprintf(
      "The observed mean is <strong>%.2f</strong>, with a %d%% %s of <strong>%.2f to %.2f</strong> (width: %.2f).",
      mean_val, pct, labels$interval_term, lower, upper, width
    ))
    denom <- abs(mean_val) + 0.001
    rw <- width / denom
    if (rw < 0.1) {
      result_parts <- c(result_parts, "High precision relative to the mean value.")
    } else if (rw < 0.2) {
      result_parts <- c(result_parts, "Reasonably precise estimate.")
    } else if (rw < 0.3) {
      result_parts <- c(result_parts, "Somewhat wide &mdash; the direction is sound, but treat the exact value with caution.")
    } else {
      result_parts <- c(result_parts, "<strong>Caution:</strong> Wide interval &mdash; substantial uncertainty. A larger sample would improve precision.")
    }
    if (quality$badge != "good") {
      result_parts <- c(result_parts, paste0(
        "<strong>", if (quality$badge == "poor") "Quality concern" else "Note", ":</strong> ",
        paste(quality$reasons, collapse = ". "), "."
      ))
    }
  }
  sections <- c(sections, sprintf(
    '<div class="ci-callout ci-callout-result">%s</div>',
    paste(result_parts, collapse = " ")
  ))

  # === SECTION 2: METHOD NOTES (grey callout) ===
  method_parts <- character()

  if ("t-Distribution" %in% methods_used) {
    method_parts <- c(method_parts,
      "<strong>t-distribution</strong> &mdash; the standard method for means. Accounts for the extra uncertainty from estimating the standard deviation. Reliable when n&nbsp;&gt;&nbsp;30 (Central Limit Theorem) or when data is roughly bell-shaped."
    )
  }
  if ("Bootstrap" %in% methods_used) {
    method_parts <- c(method_parts,
      "<strong>Bootstrap</strong> &mdash; resamples the data thousands of times without assuming any particular distribution. Especially useful for skewed, bounded, or heavy-tailed data where the t-distribution may be unreliable."
    )
  }
  if ("Bayesian Credible" %in% methods_used) {
    method_parts <- c(method_parts, sprintf(
      "<strong>Bayesian credible interval</strong> &mdash; gives a direct probability statement: \"there is a %d%% chance the true mean is in this range,\" rather than the frequentist interpretation (\"this method captures the truth %d%% of the time across many surveys\"). Does not rely on repeated-sampling logic, so it can be more meaningful for non-random or one-off studies.",
      pct, pct
    ))
  }
  if (is_weighted) {
    method_parts <- c(method_parts, sprintf(
      "<strong>Weighting:</strong> Effective n&nbsp;=&nbsp;%s (Kish, 1965). Weighted variance uses Bessel\\'s correction for unbiased estimation under unequal weights.",
      if (!is.na(n_eff)) format(n_eff, big.mark = ",") else "unknown"
    ))
  }
  if (length(method_parts) > 0) {
    sections <- c(sections, sprintf(
      '<div class="ci-callout ci-callout-method"><p>%s</p></div>',
      paste(method_parts, collapse = "</p><p>")
    ))
  }

  # === SECTION 3: SAMPLING NOTE (amber callout) ===
  sections <- c(sections, build_sampling_note(sampling_method))

  paste(sections, collapse = "\n")
}


#' Generate structured NPS callout (3 visual sections)
#' @keywords internal
generate_nps_callout <- function(q_id, nps_score, lower, upper, n_eff,
                                  conf_level, is_weighted, quality,
                                  pct_promoters, pct_detractors,
                                  methods_used = character(),
                                  sampling_method = "Not_Specified") {
  pct <- round(conf_level * 100)
  labels <- get_sampling_labels(sampling_method)
  sections <- character()

  # === SECTION 1: KEY RESULT (blue callout) ===
  result_parts <- character()
  if (!is.na(nps_score)) {
    prom <- pct_promoters %||% NA
    detr <- pct_detractors %||% NA
    pass <- if (!is.na(prom) && !is.na(detr)) 100 - prom - detr else NA

    result_parts <- c(result_parts, sprintf(
      "The Net Promoter Score is <strong>%+.0f</strong> (Promoters %.0f%% &minus; Detractors %.0f%%, Passives %.0f%%).",
      nps_score, prom, detr, pass
    ))

    if (!is.na(lower) && !is.na(upper)) {
      moe_nps <- round((upper - lower) / 2, 1)
      result_parts <- c(result_parts, sprintf(
        "The %d%% %s runs from <strong>%+.0f to %+.0f</strong> (&plusmn;%.1f points).",
        pct, labels$interval_term, lower, upper, moe_nps
      ))
      if (nps_score != 0 && lower <= 0 && upper >= 0) {
        result_parts <- c(result_parts,
          "The interval crosses zero &mdash; the difference between promoters and detractors is not statistically significant at this level."
        )
      }
    }

    if (nps_score > 50) {
      result_parts <- c(result_parts, "Above +50 is widely considered excellent (though benchmarks vary by industry).")
    } else if (nps_score > 0) {
      result_parts <- c(result_parts, "Positive: more promoters than detractors.")
    } else if (nps_score == 0) {
      result_parts <- c(result_parts, "Neutral: promoters and detractors are balanced.")
    } else {
      result_parts <- c(result_parts, "<strong>Warning:</strong> Negative NPS &mdash; more detractors than promoters.")
    }

    if (quality$badge != "good") {
      result_parts <- c(result_parts, paste0(
        "<strong>", if (quality$badge == "poor") "Quality concern" else "Note", ":</strong> ",
        paste(quality$reasons, collapse = ". "), "."
      ))
    }
  }
  sections <- c(sections, sprintf(
    '<div class="ci-callout ci-callout-result">%s</div>',
    paste(result_parts, collapse = " ")
  ))

  # === SECTION 2: METHOD NOTES (grey callout) ===
  method_parts <- character()

  method_parts <- c(method_parts,
    "<strong>How NPS intervals work:</strong> NPS is a difference of two proportions from the same sample (promoters minus detractors), so its standard error accounts for the covariance between categories. Bootstrap intervals are often preferred because the NPS distribution can be non-normal, especially with small or unbalanced groups."
  )

  if ("Bayesian Credible" %in% methods_used) {
    method_parts <- c(method_parts, sprintf(
      "<strong>Bayesian credible interval</strong> &mdash; gives a direct %d%% probability statement about where the true NPS lies. Unlike frequentist intervals, it does not depend on repeated-sampling assumptions, which can make it more appropriate for non-random studies.",
      pct
    ))
  }

  if (is_weighted && !is.na(n_eff)) {
    method_parts <- c(method_parts, sprintf(
      "<strong>Weighting:</strong> Effective n&nbsp;=&nbsp;%s (Kish, 1965). Intervals widened accordingly.",
      format(n_eff, big.mark = ",")
    ))
  }

  method_parts <- c(method_parts,
    "<strong>NPS limitation:</strong> NPS collapses an 11-point scale into three categories, discarding within-group variation. The confidence interval quantifies sampling uncertainty of the aggregate score, but cannot recover information lost through categorisation."
  )

  sections <- c(sections, sprintf(
    '<div class="ci-callout ci-callout-method"><p>%s</p></div>',
    paste(method_parts, collapse = "</p><p>")
  ))

  # === SECTION 3: SAMPLING NOTE (amber callout) ===
  sections <- c(sections, build_sampling_note(sampling_method))

  paste(sections, collapse = "\n")
}


#' Build tailored sampling note based on study sampling method
#'
#' Returns an HTML callout explaining what the sampling design means for
#' interpreting the intervals. Honest and defensible: probability designs
#' get standard CI language, non-probability designs get language that
#' accurately reflects what the intervals can and cannot tell you.
#'
#' @param sampling_method Character. One of: Random, Stratified, Cluster,
#'   Quota, Online_Panel, Self_Selected, Census, Not_Specified
#' @return Character. HTML string with appropriate styling class
#' @keywords internal
build_sampling_note <- function(sampling_method = "Not_Specified") {
  note <- switch(sampling_method,

    "Random" = '<strong>Sampling design: simple random sample.</strong> Every person in the target population had an equal chance of being selected. This is the gold standard for survey sampling, and the confidence intervals can be taken at face value. The remaining uncertainty is practical rather than statistical: people who chose not to respond may hold different views from those who did, and the way questions are worded always influences answers to some degree.',

    "Stratified" = '<strong>Sampling design: stratified random sample.</strong> The population was divided into groups (e.g. by channel, region, or segment) and people were sampled randomly within each group. This ensures reliable results for each group, even smaller ones, but may mean some groups are deliberately oversampled relative to their true size. Within each group, the confidence intervals are trustworthy. At total level, they are conservative &mdash; if anything, slightly wider than necessary. As with any survey, people who declined to take part may differ from those who did.',

    "Cluster" = '<strong>Sampling design: cluster sample.</strong> The population was divided into natural groupings (e.g. branches, stores, or teams) and a selection of these groupings was sampled rather than individuals directly. This is practical and cost-effective but means that people within the same cluster tend to give similar responses, which reduces the effective sample size. The confidence intervals reported here do not adjust for this clustering effect and may therefore be narrower than they should be. Results should be treated as indicative, and differences near the margin of error interpreted with caution.',

    "Quota" = '<strong>Sampling design: quota sample.</strong> Respondents were recruited to match the target population on selected characteristics such as age, gender, or region. Within these quotas, selection was not random &mdash; interviewers or recruiters chose who to approach. The stability intervals describe the variability in the achieved sample and are useful for comparing groups and detecting shifts between waves. They should not be read as exact margins of error, because the non-random selection within quotas introduces uncertainty that the intervals cannot measure.',

    "Online_Panel" = '<strong>Sampling design: online research panel.</strong> Respondents were drawn from a pre-recruited research panel, usually with quotas to match the target population on key characteristics. The stability intervals measure how stable the results are within this sample, but panel members are volunteers who have opted in to research &mdash; they are not a random cross-section of the population. These intervals are reliable for tracking changes over time and comparing subgroups, but should be read as a measure of precision rather than a guaranteed margin of error.',

    "Self_Selected" = '<strong>Sampling design: self-selected (opt-in) sample.</strong> Respondents chose to take part &mdash; there was no structured selection from a defined population. The stability intervals describe the range of results you would expect if you repeated the exercise with a similar group of volunteers, but they do not tell you how close the results are to what the broader population thinks. These results are useful for identifying patterns and priorities within the responding group. They are not generalisable without additional evidence that the respondents are representative.',

    "Census" = '<strong>Sampling design: census (full population).</strong> Everyone in the target population was invited to participate. There is no sampling error in the traditional sense &mdash; the uncertainty comes entirely from who chose to respond. If most people responded, the results closely represent the whole population. If response rates are low, the responding group may not be representative, and the confidence intervals understate the true uncertainty. The response rate is the single most important quality indicator for this type of study. If the response rate is below 50%, consider treating the results as you would a convenience sample.',

    # Default: Not_Specified — sampling method unknown, use cautious framing
    '<strong>About your sample:</strong> The sampling method for this study was not recorded. The stability intervals describe the variability in the observed data and provide a useful indication of estimate precision. However, their interpretation depends on how the sample was drawn. If the sample is broadly representative of the target population, the intervals are a reasonable guide to the margin of error. If representativeness is uncertain, treat them as a measure of internal consistency rather than definitive bounds.'
  )

  sprintf('<div class="ci-callout ci-callout-sampling">%s</div>', note)
}


# Null-coalescing operator (canonical definition in utils.R)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
