# ==============================================================================
# CATDRIVER HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Restructures analysis results into HTML-friendly format.
# Pure data transformation — no HTML generation here.
# ==============================================================================

#' Transform Catdriver Results for HTML Rendering
#'
#' Converts the raw results list into a structured format optimised for
#' HTML table and chart generation.
#'
#' @param results Analysis results from run_categorical_keydriver()
#' @param config Configuration list
#' @return List with transformed data for each report section
#' @keywords internal
transform_catdriver_for_html <- function(results, config) {

  # Executive summary text
  summary_lines <- generate_executive_summary(results, config)

  # Transform importance data
  imp_df <- results$importance
  importance <- lapply(seq_len(nrow(imp_df)), function(i) {
    row <- imp_df[i, ]
    list(
      rank = row$rank,
      variable = row$variable,
      label = row$label,
      importance_pct = if (is.na(row$importance_pct)) 0 else as.numeric(row$importance_pct),
      chi_square = if (is.na(row$chi_square)) 0 else round(row$chi_square, 2),
      p_value = row$p_value,
      p_formatted = if (is.na(row$p_value)) "n/a" else format_pvalue(row$p_value),
      significance = if (is.null(row$significance) || is.na(row$significance)) "" else row$significance,
      effect_size = if (is.null(row$effect_size) || is.na(row$effect_size)) "" else row$effect_size
    )
  })

  # Transform factor patterns
  patterns <- list()
  for (var_name in config$driver_vars) {
    pat <- results$factor_patterns[[var_name]]
    if (is.null(pat)) next

    pat_df <- pat$patterns
    outcome_cols <- grep("^pct_", names(pat_df), value = TRUE)
    outcome_names <- sub("^pct_", "", outcome_cols)

    categories <- lapply(seq_len(nrow(pat_df)), function(i) {
      r <- pat_df[i, ]
      outcome_pcts <- setNames(
        as.numeric(pat_df[i, outcome_cols]),
        outcome_names
      )
      list(
        category = r$category,
        n = r$n,
        pct_of_total = as.numeric(r$pct_of_total),
        is_reference = r$is_reference,
        outcome_pcts = outcome_pcts,
        odds_ratio = if (r$is_reference) 1.0 else r$odds_ratio,
        or_lower = if (r$is_reference) NA else r$or_lower,
        or_upper = if (r$is_reference) NA else r$or_upper,
        effect = r$effect %||% ""
      )
    })

    patterns[[var_name]] <- list(
      label = pat$label,
      variable = var_name,
      reference = pat$reference,
      outcome_categories = outcome_names,
      categories = categories
    )
  }

  # Transform odds ratios
  or_df <- results$odds_ratios
  has_bootstrap <- "boot_median_or" %in% names(or_df) && any(!is.na(or_df$boot_median_or))

  odds_ratios <- lapply(seq_len(nrow(or_df)), function(i) {
    r <- or_df[i, ]
    entry <- list(
      factor_label = r$factor_label,
      comparison = r$comparison,
      reference = r$reference,
      or_value = suppressWarnings(as.numeric(gsub("[^0-9.]", "", r$or_formatted))),
      or_formatted = r$or_formatted,
      ci_formatted = r$ci_formatted,
      p_formatted = r$p_formatted,
      significance = r$significance %||% "",
      effect = r$effect %||% ""
    )
    if (has_bootstrap) {
      entry$boot_median_or <- r$boot_median_or
      entry$boot_ci_lower <- r$boot_ci_lower
      entry$boot_ci_upper <- r$boot_ci_upper
      entry$sign_stability <- r$sign_stability
    }
    if ("outcome_level" %in% names(or_df)) {
      entry$outcome_level <- r$outcome_level
    }
    entry
  })

  # Transform diagnostics
  diag <- results$diagnostics
  diagnostics <- list(
    original_n = diag$original_n,
    complete_n = diag$complete_n,
    analysis_n = diag$analysis_n %||% diag$complete_n,
    pct_complete = diag$pct_complete,
    convergence = results$model_result$convergence,
    has_small_cells = length(diag$small_cells) > 0,
    n_small_cell_vars = length(diag$small_cells),
    warnings = diag$warnings %||% character(0),
    missing_summary = diag$missing_summary
  )

  # Model info
  model_info <- list(
    outcome_type = results$model_result$outcome_type %||% results$prep_data$outcome_info$type,
    outcome_label = config$outcome_label,
    outcome_categories = results$prep_data$outcome_info$categories,
    n_categories = results$prep_data$outcome_info$n_categories,
    n_drivers = length(config$driver_vars),
    n_terms = results$prep_data$n_terms,
    fit_statistics = results$model_result$fit_statistics,
    has_bootstrap = has_bootstrap,
    weight_var = config$weight_var,
    weight_diagnostics = results$weight_diagnostics
  )

  # Transform probability lifts (per-driver structure, mirrors patterns)
  probability_lifts <- NULL
  pl_df <- results$probability_lift
  if (is.data.frame(pl_df) && nrow(pl_df) > 0) {
    probability_lifts <- list()
    for (var_name in unique(pl_df$driver)) {
      var_df <- pl_df[pl_df$driver == var_name, , drop = FALSE]
      ref_row <- var_df[var_df$is_reference == TRUE, , drop = FALSE]
      ref_level <- if (nrow(ref_row) > 0) ref_row$level[1] else var_df$level[1]

      categories <- lapply(seq_len(nrow(var_df)), function(i) {
        r <- var_df[i, ]
        list(
          level = r$level,
          is_reference = isTRUE(r$is_reference),
          mean_prob = r$mean_predicted_prob,
          ref_prob = r$reference_prob,
          lift = r$prob_lift,
          lift_pct = r$prob_lift_pct
        )
      })

      probability_lifts[[var_name]] <- list(
        label = var_df$driver_label[1],
        variable = var_name,
        reference = ref_level,
        categories = categories
      )
    }
  }

  # Generate narrative insights
  narrative <- generate_narrative_insights(importance, patterns, model_info, diagnostics)

  list(
    summary_lines = summary_lines,
    importance = importance,
    patterns = patterns,
    odds_ratios = odds_ratios,
    probability_lifts = probability_lifts,
    diagnostics = diagnostics,
    model_info = model_info,
    narrative = narrative,
    has_bootstrap = has_bootstrap,
    analysis_name = config$analysis_name %||% "Categorical Key Driver Analysis",
    run_status = results$run_status %||% "PASS",
    degraded = isTRUE(results$degraded),
    degraded_reasons = results$degraded_reasons %||% character(0)
  )
}


#' Generate Narrative Insights
#'
#' Detects patterns in the analysis results and produces plain-English
#' insight statements suitable for the executive summary.
#'
#' Patterns detected:
#' - Dominant driver (one driver has >40% importance)
#' - Clear top tier (top 2-3 drivers account for >70% of total)
#' - Dose-response patterns (monotonic OR progression within a driver)
#' - Extreme odds ratios (very large effects suggesting strong differentiation)
#'
#' @param importance List of importance entries
#' @param patterns List of factor pattern entries
#' @param model_info Model information list
#' @param diagnostics Diagnostics list
#' @return List with: insights (character vector), dominant_driver (name or NULL),
#'   dose_response_drivers (names), key_findings (list of finding structures)
#' @keywords internal
generate_narrative_insights <- function(importance, patterns, model_info, diagnostics) {

  insights <- character(0)
  key_findings <- list()
  dose_response_drivers <- character(0)
  dominant_driver <- NULL

  n_drivers <- length(importance)
  if (n_drivers == 0) return(list(
    insights = "No driver importance data available.",
    dominant_driver = NULL,
    dose_response_drivers = character(0),
    key_findings = list()
  ))

  # --- Dominant driver detection ---
  top_pct <- importance[[1]]$importance_pct
  top_label <- importance[[1]]$label

  if (top_pct >= 40) {
    dominant_driver <- top_label
    insights <- c(insights, sprintf(
      "%s is the dominant driver, accounting for %.0f%% of explained variation \u2014 substantially more than any other factor.",
      top_label, top_pct
    ))
  } else if (n_drivers >= 2) {
    top2_pct <- importance[[1]]$importance_pct + importance[[2]]$importance_pct
    if (top2_pct >= 70) {
      insights <- c(insights, sprintf(
        "%s (%.0f%%) and %s (%.0f%%) together account for %.0f%% of explained variation, forming a clear top tier.",
        importance[[1]]$label, importance[[1]]$importance_pct,
        importance[[2]]$label, importance[[2]]$importance_pct,
        top2_pct
      ))
    }
  }

  # --- Dose-response detection ---
  for (var_name in names(patterns)) {
    pat <- patterns[[var_name]]
    cats <- pat$categories
    if (length(cats) < 3) next

    # Get non-reference categories with valid ORs
    non_ref <- cats[!vapply(cats, function(c) isTRUE(c$is_reference), logical(1))]
    ors <- vapply(non_ref, function(c) {
      val <- suppressWarnings(as.numeric(c$odds_ratio))
      if (is.na(val)) NA_real_ else val
    }, numeric(1))

    valid_ors <- ors[!is.na(ors)]
    if (length(valid_ors) < 3) next

    # Check monotonic (all increasing or all decreasing)
    diffs <- diff(valid_ors)
    if (all(diffs > 0) || all(diffs < 0)) {
      dose_response_drivers <- c(dose_response_drivers, var_name)
      direction <- if (all(diffs > 0)) "increasing" else "decreasing"
      range_text <- sprintf("%.1fx to %.1fx", min(valid_ors), max(valid_ors))
      insights <- c(insights, sprintf(
        "%s shows a dose-response pattern with %s odds ratios across categories (%s), suggesting a graded relationship.",
        pat$label, direction, range_text
      ))
    }
  }

  # --- Key findings: extreme ORs ---
  for (var_name in names(patterns)) {
    pat <- patterns[[var_name]]
    for (cat in pat$categories) {
      if (isTRUE(cat$is_reference)) next
      or_val <- suppressWarnings(as.numeric(cat$odds_ratio))
      if (is.na(or_val)) next

      if (or_val >= 5.0) {
        key_findings <- c(key_findings, list(list(
          driver = pat$label,
          category = cat$category,
          or_value = or_val,
          direction = "positive",
          text = sprintf("%s \u2014 %s is %.1fx more likely than the reference group.",
                         pat$label, cat$category, or_val)
        )))
      } else if (or_val <= 0.2 && or_val > 0) {
        key_findings <- c(key_findings, list(list(
          driver = pat$label,
          category = cat$category,
          or_value = or_val,
          direction = "negative",
          text = sprintf("%s \u2014 %s is %.0f%% less likely than the reference group.",
                         pat$label, cat$category, (1 - or_val) * 100)
        )))
      }
    }
  }

  # Sort key findings by OR magnitude (largest effects first)
  if (length(key_findings) > 0) {
    magnitudes <- vapply(key_findings, function(f) {
      if (f$direction == "positive") f$or_value else 1 / f$or_value
    }, numeric(1))
    key_findings <- key_findings[order(magnitudes, decreasing = TRUE)]

    # Limit to top 5
    if (length(key_findings) > 5) key_findings <- key_findings[1:5]
  }

  # --- Model quality note ---
  fit <- model_info$fit_statistics
  if (!is.null(fit) && !is.na(fit$mcfadden_r2)) {
    r2 <- fit$mcfadden_r2
    if (r2 < 0.1) {
      insights <- c(insights,
        "The measured factors explain only a small portion of the variation, suggesting important unmeasured drivers exist. Results should be interpreted as directional signals rather than definitive explanations."
      )
    }
  }

  list(
    insights = insights,
    dominant_driver = dominant_driver,
    dose_response_drivers = dose_response_drivers,
    key_findings = key_findings
  )
}
