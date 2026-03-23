# ==============================================================================
# CATDRIVER HTML REPORT - SECTION BUILDERS
# ==============================================================================
# Content section builders for each report section.
# Extracted from 03_page_builder.R for maintainability.
#
# FUNCTIONS:
# - build_cd_exec_summary()              - Executive summary
# - build_cd_importance_section()        - Driver importance
# - build_cd_patterns_section()          - Factor patterns
# - build_cd_probability_lifts_section() - Probability lifts
# - build_cd_or_section()               - Odds ratios
# - build_cd_diagnostics_section()       - Model diagnostics
# - build_cd_interpretation_section()    - Interpretation guide
# - build_cd_footer()                    - Report footer
# ==============================================================================

build_cd_exec_summary <- function(html_data, brand_colour, id_prefix = "") {

  fit <- html_data$model_info$fit_statistics

  # Model confidence callout
  confidence_html <- NULL
  if (!is.null(fit) && !is.na(fit$mcfadden_r2)) {
    r2 <- fit$mcfadden_r2
    r2_pct <- round(r2 * 100, 1)

    if (r2 >= 0.4) {
      conf_class <- "cd-confidence-excellent"
      conf_text <- sprintf("Excellent model fit (R\u00B2 = %.3f). The %d measured factors explain %.1f%% of variation in the outcome.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else if (r2 >= 0.2) {
      conf_class <- "cd-confidence-good"
      conf_text <- sprintf("Good model fit (R\u00B2 = %.3f). The %d measured factors explain %.1f%% of variation in the outcome.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else if (r2 >= 0.1) {
      conf_class <- "cd-confidence-moderate"
      conf_text <- sprintf("Moderate model fit (R\u00B2 = %.3f). The %d measured factors explain %.1f%% of variation. Other unmeasured factors may also play a role.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    } else {
      conf_class <- "cd-confidence-limited"
      conf_text <- sprintf("Limited model fit (R\u00B2 = %.3f). The %d measured factors explain only %.1f%% of variation. Key unmeasured factors likely influence the outcome.",
                           r2, html_data$model_info$n_drivers, r2_pct)
    }

    confidence_html <- htmltools::tags$div(
      class = paste("cd-model-confidence", conf_class),
      htmltools::tags$strong("Model Confidence: "),
      conf_text
    )
  }

  # Sample info bar (n= and weighted/unweighted)
  n_obs <- html_data$model_info$n_observations
  weight_var <- html_data$model_info$weight_var
  is_weighted <- !is.null(weight_var) && nzchar(weight_var %||% "")
  weight_label <- if (is_weighted) "Weighted" else "Unweighted"

  sample_info_html <- htmltools::tags$div(
    class = "cd-sample-info-bar",
    htmltools::tags$span(
      class = "cd-sample-badge",
      sprintf("n = %s", format(n_obs, big.mark = ","))
    ),
    htmltools::tags$span(
      class = paste0("cd-weight-badge", if (is_weighted) " cd-weight-on" else ""),
      weight_label
    )
  )

  # Top 3 driver callout cards
  top_n <- min(3, length(html_data$importance))
  driver_cards <- lapply(html_data$importance[1:top_n], function(d) {
    htmltools::tags$div(
      class = "cd-callout",
      htmltools::tags$div(class = "cd-callout-title",
                          sprintf("#%d %s", d$rank, d$label)),
      htmltools::tags$div(class = "cd-callout-text",
                          sprintf("%.1f%% of explained variation | %s %s",
                                  d$importance_pct, d$p_formatted, d$significance))
    )
  })

  # Narrative insights
  narrative <- html_data$narrative
  narrative_html <- NULL
  if (!is.null(narrative) && length(narrative$insights) > 0) {
    insight_items <- lapply(narrative$insights, function(txt) {
      htmltools::tags$li(class = "cd-key-insight-item", txt)
    })
    narrative_html <- htmltools::tags$div(
      style = "margin-bottom:16px;",
      htmltools::tags$h3(class = "cd-key-insights-heading", "Key Insights"),
      htmltools::tags$ul(style = "padding-left:20px;", insight_items)
    )
  }

  # Key findings (extreme ORs)
  findings_html <- NULL
  if (!is.null(narrative) && length(narrative$key_findings) > 0) {
    finding_items <- lapply(narrative$key_findings, function(f) {
      icon <- if (f$direction == "positive") "\u2191" else "\u2193"
      colour <- if (f$direction == "positive") "var(--cd-success)" else "var(--cd-danger)"
      htmltools::tags$div(
        class = "cd-finding-item",
        htmltools::tags$span(
          class = "cd-finding-icon",
          style = sprintf("color:%s;", colour),
          icon
        ),
        htmltools::tags$span(class = "cd-finding-text", f$text)
      )
    })
    findings_html <- htmltools::tags$div(
      class = "cd-finding-box",
      htmltools::tags$h3(class = "cd-top-drivers-label", "Standout Findings"),
      finding_items
    )
  }

  # Section title + pin + insight
  title_row <- build_cd_section_title_row("Executive Summary", "exec-summary",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("exec-summary", id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-section cd-page-active",
    id = paste0(id_prefix, "cd-exec-summary"),
    `data-cd-section` = "exec-summary",
    title_row,
    insight_area,
    sample_info_html,
    confidence_html,
    narrative_html,
    driver_cards,
    findings_html,
    # Degraded warnings
    if (html_data$degraded && length(html_data$degraded_reasons) > 0) {
      htmltools::tags$div(
        class = "cd-model-confidence cd-confidence-limited",
        htmltools::tags$strong("Degraded Output: "),
        paste(html_data$degraded_reasons, collapse = "; ")
      )
    }
  )
}


#' Build Importance Section
#' @keywords internal
build_cd_importance_section <- function(tables, charts, brand_colour,
                                        id_prefix = "", n_drivers = 0) {
  title_row <- build_cd_section_title_row("Driver Importance", "importance",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("importance", id_prefix = id_prefix)

  # Importance filter bar — show threshold options if many drivers
  filter_bar <- NULL
  if (n_drivers > 5) {
    filter_bar <- build_cd_importance_filter_bar(id_prefix, n_drivers)
  }

  # Wrap chart and table in containers with component pin buttons
  chart_wrapper <- if (!is.null(charts$importance)) {
    htmltools::tags$div(
      class = "cd-chart-wrapper",
      charts$importance
    )
  }

  table_wrapper <- if (!is.null(tables$importance)) {
    htmltools::tags$div(
      class = "cd-table-wrapper",
      filter_bar,
      tables$importance
    )
  }

  # Callout from shared registry
  importance_callout <- htmltools::HTML(
    turas_callout("catdriver", "driver_importance", collapsed = TRUE)
  )

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-importance"),
    `data-cd-section` = "importance",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "cd-section-intro",
      "Relative importance of each driver in explaining the outcome, based on chi-square contribution. Higher percentage means stronger statistical relationship."
    ),
    importance_callout,
    chart_wrapper,
    table_wrapper
  )
}


#' Build Importance Filter Bar
#'
#' Threshold options: All | Top 3 | Top 5 | Significant
#' @keywords internal
build_cd_importance_filter_bar <- function(id_prefix = "", n_drivers = 0) {
  prefix_js <- if (nchar(id_prefix) > 0) paste0("'", id_prefix, "'") else "''"

  # Determine sensible "top N" options based on total count
  options <- list(
    list(label = "All", mode = "all"),
    list(label = "Top 3", mode = "top-3"),
    list(label = "Top 5", mode = "top-5")
  )
  if (n_drivers > 8) {
    options <- c(options, list(list(label = "Top 8", mode = "top-8")))
  }
  options <- c(options, list(list(label = "Significant", mode = "significant")))

  chips <- lapply(options, function(opt) {
    active_class <- if (opt$mode == "all") " active" else ""
    htmltools::tags$button(
      class = paste0("cd-or-chip", active_class),
      `data-cd-imp-mode` = opt$mode,
      onclick = sprintf("cdFilterImportanceBars('%s',%s)", opt$mode, prefix_js),
      opt$label
    )
  })

  htmltools::tags$div(
    class = "cd-or-chip-bar",
    id = paste0(id_prefix, "cd-importance-filter"),
    style = "margin-top: 6px; margin-bottom: 2px;",
    htmltools::tags$span(
      style = "font-size: 12px; color: #64748b; font-weight: 500; margin-right: 8px;",
      "Show:"
    ),
    chips
  )
}


#' Build Patterns Section with Factor Picker
#' @keywords internal
build_cd_patterns_section <- function(html_data, tables, id_prefix = "") {

  pattern_names <- names(html_data$patterns)
  if (length(pattern_names) == 0) return(NULL)

  # Factor picker tabs
  tabs <- lapply(seq_along(pattern_names), function(i) {
    var_name <- pattern_names[i]
    label <- html_data$patterns[[var_name]]$label
    active_class <- if (i == 1) " active" else ""
    safe_id <- gsub("[^a-zA-Z0-9_]", "-", var_name)

    htmltools::tags$button(
      class = paste0("cd-factor-tab", active_class),
      onclick = sprintf("cdShowFactor('%s','%s')", safe_id, id_prefix),
      `data-factor` = paste0(id_prefix, safe_id),
      label
    )
  })

  # Factor panels
  panels <- lapply(seq_along(pattern_names), function(i) {
    var_name <- pattern_names[i]
    safe_id <- gsub("[^a-zA-Z0-9_]", "-", var_name)
    active_class <- if (i == 1) " active" else ""
    label <- html_data$patterns[[var_name]]$label
    ref <- html_data$patterns[[var_name]]$reference

    htmltools::tags$div(
      class = paste0("cd-factor-panel", active_class),
      id = paste0(id_prefix, "cd-panel-", safe_id),
      htmltools::tags$h3(
        class = "cd-panel-heading-label",
        sprintf("%s (reference: %s)", label, ref)
      ),
      tables$patterns[[var_name]]
    )
  })

  title_row <- build_cd_section_title_row("Factor Patterns", "patterns",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("patterns", id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-patterns"),
    `data-cd-section` = "patterns",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "cd-section-intro",
      htmltools::HTML(paste0(
        "Category-level breakdown for each driver. ",
        "<strong>% of Sample</strong> = share of respondents in that category. ",
        "Outcome columns = how those respondents split across the outcome. ",
        "<strong>Odds Ratio</strong> compares each category to the reference (1.00 = no difference)."
      ))
    ),
    htmltools::tags$div(
      class = "cd-effect-legend",
      htmltools::HTML(paste0(
        "<strong>Effect Size key:</strong> ",
        "<span class='cd-effect-tag'>Negligible</span> OR &lt; 1.1\u00D7 &nbsp; ",
        "<span class='cd-effect-tag'>Small</span> 1.1\u2013\u200A1.5\u00D7 &nbsp; ",
        "<span class='cd-effect-tag'>Medium</span> 1.5\u2013\u200A2\u00D7 &nbsp; ",
        "<span class='cd-effect-tag'>Large</span> 2\u2013\u200A3\u00D7 &nbsp; ",
        "<span class='cd-effect-tag'>Very Large</span> &gt; 3\u00D7"
      ))
    ),
    htmltools::tags$div(class = "cd-factor-tabs", tabs),
    panels
  )
}


#' Build Probability Lifts Section
#'
#' Tabbed per-driver view showing how predicted probability changes for
#' each category compared to the reference. Includes a diverging bar chart
#' and per-driver tables. Follows the patterns section layout.
#'
#' @param html_data Transformed HTML data (must include probability_lifts)
#' @param tables List of table objects (must include probability_lifts list)
#' @param charts List of chart objects (includes probability_lift chart)
#' @param id_prefix ID prefix for unified report scoping
#' @return htmltools tag, or NULL if no probability lift data
#' @keywords internal
build_cd_probability_lifts_section <- function(html_data, tables, charts,
                                                id_prefix = "") {

  pl <- html_data$probability_lifts
  if (is.null(pl) || length(pl) == 0) return(NULL)

  lift_names <- names(pl)

  # Tabbed interface — use "lift-" prefix to avoid ID collision with Patterns section
  tabs <- lapply(seq_along(lift_names), function(i) {
    var_name <- lift_names[i]
    label <- pl[[var_name]]$label
    active_class <- if (i == 1) " active" else ""
    safe_id <- paste0("lift-", gsub("[^a-zA-Z0-9_]", "-", var_name))

    htmltools::tags$button(
      class = paste0("cd-factor-tab", active_class),
      onclick = sprintf("cdShowFactor('%s','%s')", safe_id, id_prefix),
      `data-factor` = paste0(id_prefix, safe_id),
      label
    )
  })

  # Panels — one per driver (with "lift-" prefix)
  panels <- lapply(seq_along(lift_names), function(i) {
    var_name <- lift_names[i]
    safe_id <- paste0("lift-", gsub("[^a-zA-Z0-9_]", "-", var_name))
    active_class <- if (i == 1) " active" else ""
    label <- pl[[var_name]]$label
    ref <- pl[[var_name]]$reference

    htmltools::tags$div(
      class = paste0("cd-factor-panel", active_class),
      id = paste0(id_prefix, "cd-panel-", safe_id),
      htmltools::tags$h3(
        class = "cd-panel-heading-label",
        sprintf("%s (reference: %s)", label, ref)
      ),
      tables$probability_lifts[[var_name]]
    )
  })

  title_row <- build_cd_section_title_row("Probability Lifts", "probability-lifts",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("probability-lifts", id_prefix = id_prefix)

  # Methodology callout (from shared registry)
  lift_callout <- htmltools::HTML(
    turas_callout("catdriver", "probability_lifts", collapsed = TRUE)
  )

  # Chip bar for driver show/hide on the combined chart
  lift_chip_bar <- build_cd_lift_chip_bar(html_data$probability_lifts, id_prefix = id_prefix)

  # Chart wrapper (combined chart showing all drivers)
  chart_el <- NULL
  if (!is.null(charts$probability_lift)) {
    chart_el <- htmltools::tags$div(
      class = "cd-chart-wrapper",
      lift_chip_bar,
      charts$probability_lift
    )
  }

  # Table wrapper (holds the tabbed panels)
  table_el <- htmltools::tags$div(
    class = "cd-table-wrapper",
    htmltools::tags$div(class = "cd-factor-tabs", tabs),
    panels
  )

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-probability-lifts"),
    `data-cd-section` = "probability-lifts",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "cd-section-intro",
      "How each driver level changes the predicted probability of the outcome compared to the reference category. Values represent percentage-point changes."
    ),
    lift_callout,
    chart_el,
    table_el,
    htmltools::tags$p(
      class = "cd-section-intro",
      style = "margin-top:12px;font-size:11px;font-style:italic;",
      "Probability lifts are mean predicted probabilities for observations in each category, holding other factors at their observed values. They are sample-specific marginal effects."
    )
  )
}


#' Build Odds Ratios Section
#' @keywords internal
build_cd_or_section <- function(tables, charts, has_bootstrap,
                                 id_prefix = "", odds_ratios = NULL) {
  bootstrap_note <- if (has_bootstrap) {
    htmltools::tags$p(
      style = "color:var(--cd-text-faint);font-size:12px;margin-top:8px;",
      "Bootstrap columns show resampled estimates. Sign stability indicates the percentage of bootstrap samples where the OR remained on the same side of 1.0."
    )
  }

  title_row <- build_cd_section_title_row("Odds Ratios", "odds-ratios",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("odds-ratios", id_prefix = id_prefix)

  # Methodology callout (from shared registry)
  or_callout <- htmltools::HTML(
    turas_callout("catdriver", "odds_ratios", collapsed = TRUE)
  )

  # OR chip bar for factor filtering
  chip_bar <- build_cd_or_chip_bar(odds_ratios, id_prefix = id_prefix)

  # Wrap chart and table in containers with component pin buttons
  chart_wrapper <- if (!is.null(charts$forest)) {
    htmltools::tags$div(
      class = "cd-chart-wrapper",
      charts$forest
    )
  }

  table_wrapper <- if (!is.null(tables$odds_ratios)) {
    htmltools::tags$div(
      class = "cd-table-wrapper",
      chip_bar,
      tables$odds_ratios,
      bootstrap_note
    )
  }

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-odds-ratios"),
    `data-cd-section` = "odds-ratios",
    title_row,
    insight_area,
    htmltools::tags$p(
      class = "cd-section-intro",
      "Detailed coefficient table showing the odds ratio for each factor level compared to its reference category. OR > 1 means higher likelihood; OR < 1 means lower likelihood."
    ),
    or_callout,
    chart_wrapper,
    table_wrapper
  )
}


#' Build Diagnostics Section
#' @keywords internal
build_cd_diagnostics_section <- function(tables, html_data, id_prefix = "") {

  # Warning list
  warnings_html <- NULL
  if (length(html_data$diagnostics$warnings) > 0) {
    warning_items <- lapply(html_data$diagnostics$warnings, function(w) {
      htmltools::tags$li(class = "cd-key-insight-item", w)
    })
    warnings_html <- htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(class = "cd-panel-heading-label", "Warnings"),
      htmltools::tags$ul(style = "padding-left:20px;", warning_items)
    )
  }

  # Model fit stats — each as a labeled card with brief explanation
  fit <- html_data$model_info$fit_statistics
  fit_cards <- list()
  if (!is.null(fit)) {
    if (!is.na(fit$mcfadden_r2)) {
      r2_label <- if (fit$mcfadden_r2 >= 0.4) "Excellent"
                  else if (fit$mcfadden_r2 >= 0.2) "Good"
                  else if (fit$mcfadden_r2 >= 0.1) "Moderate"
                  else "Limited"
      fit_cards <- c(fit_cards, list(htmltools::tags$div(
        class = "cd-fit-card",
        htmltools::tags$div(class = "cd-fit-card-value",
          sprintf("%.3f", fit$mcfadden_r2)),
        htmltools::tags$div(class = "cd-fit-card-label",
          htmltools::HTML("McFadden R\u00B2")),
        htmltools::tags$div(class = "cd-fit-card-quality", r2_label),
        htmltools::tags$div(class = "cd-fit-card-note",
          "Proportion of explained variation. Values 0.2\u20130.4 indicate good fit for logistic models.")
      )))
    }
    if (!is.na(fit$aic)) {
      fit_cards <- c(fit_cards, list(htmltools::tags$div(
        class = "cd-fit-card",
        htmltools::tags$div(class = "cd-fit-card-value",
          sprintf("%.1f", fit$aic)),
        htmltools::tags$div(class = "cd-fit-card-label", "AIC"),
        htmltools::tags$div(class = "cd-fit-card-quality",
          style = "color:#64748b;",
          "Comparison metric only"),
        htmltools::tags$div(class = "cd-fit-card-note",
          "This number has no absolute good/bad threshold \u2014 it is only useful when comparing alternative models on the same data. A lower AIC indicates a better-fitting model.")
      )))
    }
    if (!is.na(fit$lr_statistic)) {
      lr_is_sig <- !is.na(fit$lr_pvalue) && fit$lr_pvalue < 0.05
      lr_verdict_text <- if (lr_is_sig) {
        "\u2713 Yes \u2014 the model is statistically significant"
      } else {
        "\u2717 No \u2014 the model is not statistically significant"
      }
      lr_verdict_class <- paste0("cd-fit-card-verdict ",
        if (lr_is_sig) "cd-verdict-yes" else "cd-verdict-no")

      fit_cards <- c(fit_cards, list(htmltools::tags$div(
        class = "cd-fit-card",
        htmltools::tags$div(class = lr_verdict_class, lr_verdict_text),
        htmltools::tags$div(class = "cd-fit-card-value",
          style = "margin-top:8px;",
          sprintf("\u03C7\u00B2(%d) = %.1f", fit$lr_df, fit$lr_statistic)),
        htmltools::tags$div(class = "cd-fit-card-label",
          htmltools::HTML(sprintf("Likelihood Ratio Test &nbsp;(p %s)",
                                   format_pvalue(fit$lr_pvalue)))),
        htmltools::tags$div(class = "cd-fit-card-note",
          "Tests whether the drivers collectively predict the outcome better than chance alone. A significant result (p < 0.05) means the drivers matter.")
      )))
    }
  }

  fit_html <- if (length(fit_cards) > 0) {
    htmltools::tags$div(
      style = "margin-top:16px;",
      htmltools::tags$h3(class = "cd-panel-heading-label", "Model Fit Statistics"),
      htmltools::tags$div(class = "cd-fit-cards-grid", fit_cards)
    )
  }

  title_row <- build_cd_section_title_row("Model Diagnostics", "diagnostics",
                                           id_prefix = id_prefix)
  insight_area <- build_cd_insight_area("diagnostics", id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-diagnostics"),
    `data-cd-section` = "diagnostics",
    title_row,
    insight_area,
    tables$diagnostics,
    fit_html,
    warnings_html
  )
}


#' Build Interpretation Guide Section
#' @keywords internal
build_cd_interpretation_section <- function(brand_colour = "#323367", id_prefix = "") {
  title_row <- build_cd_section_title_row("How to Interpret These Results",
                                           "interpretation",
                                           id_prefix = id_prefix,
                                           show_pin = FALSE)

  htmltools::tags$div(
    class = "cd-section",
    id = paste0(id_prefix, "cd-interpretation"),
    `data-cd-section` = "interpretation",
    title_row,
    htmltools::tags$div(
      class = "cd-interp-grid",
      htmltools::tags$div(
        htmltools::tags$h3(
          class = "cd-panel-heading-label",
          style = "color:var(--cd-success);",
          "DO"
        ),
        htmltools::tags$ul(
          class = "cd-interp-list",
          htmltools::tags$li("Focus on large effects (OR > 2.0 or < 0.5) that are practically meaningful"),
          htmltools::tags$li("Consider the ranking of drivers rather than exact OR values"),
          htmltools::tags$li("Validate key findings with qualitative research or experiments"),
          htmltools::tags$li("Report uncertainty ranges when presenting to stakeholders")
        )
      ),
      htmltools::tags$div(
        htmltools::tags$h3(
          class = "cd-panel-heading-label",
          style = "color:var(--cd-danger);",
          "DON'T"
        ),
        htmltools::tags$ul(
          class = "cd-interp-list",
          htmltools::tags$li("Treat odds ratios as precise population parameters"),
          htmltools::tags$li("Make causal claims without experimental evidence"),
          htmltools::tags$li("Over-interpret small differences (OR 1.1 vs 1.2)"),
          htmltools::tags$li("Ignore multicollinearity or convergence warnings")
        )
      )
    ),
    htmltools::tags$div(
      class = "cd-interp-note",
      htmltools::tags$strong("Note: "),
      "Odds ratios show association, not causation. With non-probability samples, p-values and confidence intervals should be treated as approximate indicators rather than strict inferential bounds."
    )
  )
}


#' Build Footer
#' @param config Configuration list (optional, for company/client name)
#' @keywords internal
build_cd_footer <- function(config = list()) {
  company_name <- config$company_name %||% "The Research LampPost (Pty) Ltd"
  client_name <- config$client_name %||% NULL

  prepared <- company_name
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared <- sprintf("%s | Prepared for %s", prepared, client_name)
  }

  htmltools::tags$div(
    class = "cd-footer",
    sprintf("Generated by TURAS Categorical Key Driver Module v1.1 | %s",
            format(Sys.time(), "%d %B %Y %H:%M")),
    htmltools::tags$br(),
    prepared
  )
}


