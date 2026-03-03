# ==============================================================================
# CATDRIVER HTML REPORT - MULTI-OUTCOME COMPARISON
# ==============================================================================
# Generates a comparison report that summarises multiple catdriver analyses
# side-by-side. Useful when the same dataset is analysed with different
# outcome variables (e.g., NPS, Satisfaction, Career Progression).
#
# This is a standalone function that takes a list of pre-run result objects
# (each returned by run_categorical_keydriver()) along with their configs.
# ==============================================================================

#' Generate Multi-Outcome Comparison Report
#'
#' Takes multiple catdriver analysis results and produces a single HTML report
#' comparing drivers, model fit, and key findings across outcomes.
#'
#' @param analyses Named list of analysis entries. Each entry should be a list
#'   with elements: `results` (from run_categorical_keydriver()),
#'   `config` (the config list), and optionally `label` (display name).
#' @param output_path Path for the output HTML file
#' @param report_title Optional title (default: "Multi-Outcome Comparison")
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @param researcher_logo_path Optional logo file path
#' @return List with status, output_file, file_size_mb
#' @export
generate_catdriver_comparison_report <- function(analyses,
                                                  output_path,
                                                  report_title = "Multi-Outcome Comparison",
                                                  brand_colour = "#323367",
                                                  accent_colour = "#CC9900",
                                                  researcher_logo_path = NULL) {

  start_time <- Sys.time()

  cat("\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  CATDRIVER COMPARISON REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # --- Validation ---
  if (!is.list(analyses) || length(analyses) < 2) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: CFG_COMPARISON_MIN_ANALYSES\n")
    cat("Message: At least 2 analyses required for comparison\n")
    cat("==================\n\n")
    return(list(
      status = "REFUSED",
      code = "CFG_COMPARISON_MIN_ANALYSES",
      message = "At least 2 analyses required for comparison",
      how_to_fix = "Provide a named list with at least 2 analysis entries"
    ))
  }

  if (!requireNamespace("htmltools", quietly = TRUE)) {
    return(list(status = "REFUSED", code = "PKG_HTMLTOOLS_MISSING",
                message = "htmltools package required", how_to_fix = "install.packages('htmltools')"))
  }

  # --- Extract summaries and driver comparison ---
  cat(sprintf("  Processing %d analyses...\n", length(analyses)))
  comp_data <- extract_comparison_data(analyses)
  summaries <- comp_data$summaries
  driver_comparison <- comp_data$driver_comparison

  # --- Build HTML ---
  cat("  Building comparison HTML...\n")

  css <- build_comparison_css(brand_colour, accent_colour)

  logo_uri <- resolve_logo_uri(researcher_logo_path)

  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      htmltools::tags$title(report_title),
      htmltools::tags$meta(name = "turas-report-type", content = "catdriver-comparison"),
      htmltools::tags$style(htmltools::HTML(css))
    ),
    htmltools::tags$body(
      class = "cd-body",
      build_comparison_header(report_title, summaries, brand_colour, logo_uri),
      htmltools::tags$div(
        class = "cd-comp-content",
        build_comparison_overview(summaries, brand_colour, accent_colour),
        build_comparison_driver_matrix(summaries, driver_comparison, brand_colour),
        build_comparison_insights(summaries, driver_comparison, brand_colour),
        build_comparison_footer()
      )
    )
  )

  page <- htmltools::browsable(page)

  # --- Write file ---
  write_result <- write_cd_html_report(page, output_path)

  if (write_result$status == "REFUSED") return(write_result)

  elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
  cat(sprintf("  Done! %.2f MB in %.1f seconds\n", write_result$file_size_mb, elapsed))
  cat(paste(rep("-", 60), collapse = ""), "\n\n")

  list(
    status = "PASS",
    message = sprintf("Comparison report: %d outcomes, %.2f MB",
                      length(analyses), write_result$file_size_mb),
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    n_outcomes = length(analyses),
    elapsed_seconds = elapsed
  )
}


# --- Extract comparison data from analyses ---
#' Extract Comparison Data from Multiple Analyses
#'
#' Pulls summary information and builds a driver comparison matrix
#' from a named list of catdriver analysis results. Used by both
#' the standalone comparison report and the unified tabbed report.
#'
#' @param analyses Named list where each entry has `results`, `config`,
#'   and optionally `label`
#' @return List with `summaries` (named list) and `driver_comparison` (list)
#' @keywords internal
extract_comparison_data <- function(analyses) {

  analysis_names <- names(analyses)
  if (is.null(analysis_names)) {
    analysis_names <- paste0("Analysis_", seq_along(analyses))
  }

  summaries <- list()
  all_drivers <- list()

  for (i in seq_along(analyses)) {
    entry <- analyses[[i]]
    name <- analysis_names[i]
    res <- entry$results
    cfg <- entry$config
    label <- entry$label %||% name

    # Outcome info
    outcome_label <- cfg$outcome_label %||% cfg$outcome_variable %||% name
    outcome_type <- res$model_result$outcome_type %||%
                    res$prep_data$outcome_info$type %||% "binary"

    # Model fit (McFadden R2)
    r2 <- NA_real_
    if (!is.null(res$model_result$fit_statistics)) {
      r2 <- res$model_result$fit_statistics$mcfadden_r2 %||% NA_real_
    }

    # Sample size
    sample_n <- res$diagnostics$complete_n %||% 0

    # Top drivers from importance ranking
    imp_df <- res$importance
    top_drivers <- list()
    if (is.data.frame(imp_df) && nrow(imp_df) > 0) {
      for (j in seq_len(min(nrow(imp_df), 10))) {
        drv <- list(
          rank = j,
          var_name = imp_df$variable[j],
          label = imp_df$label[j] %||% imp_df$variable[j],
          importance_pct = if (is.na(imp_df$importance_pct[j])) 0
                           else as.numeric(imp_df$importance_pct[j])
        )
        top_drivers[[j]] <- drv

        # Accumulate for cross-outcome comparison
        all_drivers[[length(all_drivers) + 1]] <- list(
          var_name = imp_df$variable[j],
          label = imp_df$label[j] %||% imp_df$variable[j],
          rank = j,
          importance_pct = drv$importance_pct,
          outcome = name
        )
      }
    }

    summaries[[name]] <- list(
      name = name,
      label = label,
      outcome_label = outcome_label,
      outcome_type = outcome_type,
      r2 = r2,
      r2_label = classify_r2(r2),
      sample_n = sample_n,
      top_drivers = top_drivers
    )
  }

  # --- Build driver comparison matrix ---
  unique_vars <- unique(vapply(all_drivers, function(d) d$var_name, character(1)))

  driver_comparison <- lapply(unique_vars, function(var) {
    matches <- all_drivers[vapply(all_drivers,
                                   function(d) d$var_name == var, logical(1))]
    label <- matches[[1]]$label

    ranks <- list()
    pcts <- list()
    for (m in matches) {
      ranks[[m$outcome]] <- m$rank
      pcts[[m$outcome]] <- m$importance_pct
    }

    list(
      var_name = var,
      label = label,
      ranks = ranks,
      pcts = pcts,
      n_appearances = length(matches)
    )
  })

  # Sort by appearances desc, then average rank asc
  if (length(driver_comparison) > 0) {
    driver_comparison <- driver_comparison[order(
      -vapply(driver_comparison, function(d) d$n_appearances, numeric(1)),
      vapply(driver_comparison, function(d) mean(unlist(d$ranks)), numeric(1))
    )]
  }

  list(summaries = summaries, driver_comparison = driver_comparison)
}


# --- Helper: classify R2 ---
classify_r2 <- function(r2) {
  if (is.na(r2)) return("N/A")
  if (r2 >= 0.4) "Excellent"
  else if (r2 >= 0.2) "Good"
  else if (r2 >= 0.1) "Moderate"
  else "Limited"
}


# --- Comparison CSS ---
build_comparison_css <- function(brand_colour, accent_colour) {
  css <- '
:root {
  --cd-brand: BRAND_COLOUR;
  --cd-accent: ACCENT_COLOUR;
  --ct-brand: BRAND_COLOUR;
  --ct-accent: ACCENT_COLOUR;
  --ct-text-primary: #1e293b;
  --ct-text-secondary: #64748b;
  --ct-bg-surface: #ffffff;
  --ct-bg-muted: #f8f9fa;
  --ct-border: #e2e8f0;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

.cd-body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: #f8f7f5;
  color: #1e293b;
  line-height: 1.5;
  font-size: 13px;
}

.cd-comp-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 100%);
  padding: 24px 32px;
  border-bottom: 3px solid var(--cd-brand);
}

.cd-comp-header-inner {
  max-width: 1200px;
  margin: 0 auto;
}

.cd-comp-header-top {
  display: flex;
  align-items: center;
  gap: 16px;
}

.cd-comp-logo-container {
  width: 72px; height: 72px; border-radius: 12px;
  background: transparent; display: flex; align-items: center; justify-content: center;
}

.cd-comp-logo-container img { height: 56px; width: 56px; object-fit: contain; }

.cd-comp-module-name { color: #fff; font-size: 28px; font-weight: 700; letter-spacing: -0.3px; }
.cd-comp-module-sub { color: rgba(255,255,255,0.50); font-size: 12px; margin-top: 2px; }
.cd-comp-title { color: #fff; font-size: 22px; font-weight: 700; margin-top: 16px; letter-spacing: -0.3px; }

.cd-comp-badges {
  display: inline-flex; align-items: center; margin-top: 12px;
  border: 1px solid rgba(255,255,255,0.15); border-radius: 6px;
  background: rgba(255,255,255,0.05);
}

.cd-comp-badge {
  display: inline-flex; align-items: center; padding: 4px 12px;
  font-size: 12px; font-weight: 600; color: rgba(255,255,255,0.85);
}

.cd-comp-badge-val { color: #fff; font-weight: 700; }
.cd-comp-badge-sep { width: 1px; height: 16px; background: rgba(255,255,255,0.20); }

.cd-comp-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: 24px 32px;
}

.cd-comp-section {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 24px 28px;
  margin-bottom: 20px;
}

.cd-comp-section-title {
  font-size: 16px; font-weight: 700; color: var(--cd-brand);
  margin-bottom: 14px; padding-bottom: 8px;
  border-bottom: 2px solid var(--cd-brand);
}

/* Overview cards */
.cd-comp-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 16px;
  margin-bottom: 8px;
}

.cd-comp-card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
  padding: 16px 20px; border-top: 3px solid var(--cd-brand);
}

.cd-comp-card-title {
  font-size: 15px; font-weight: 700; color: var(--cd-brand);
  margin-bottom: 4px;
}

.cd-comp-card-sub { font-size: 12px; color: #64748b; margin-bottom: 10px; }

.cd-comp-card-stat {
  display: flex; justify-content: space-between; align-items: center;
  padding: 4px 0; font-size: 13px;
}

.cd-comp-card-stat-label { color: #64748b; }
.cd-comp-card-stat-value { font-weight: 600; color: #1e293b; }

.cd-comp-r2-bar {
  height: 6px; background: #f1f5f9; border-radius: 3px; margin-top: 8px; overflow: hidden;
}

.cd-comp-r2-fill { height: 100%; border-radius: 3px; }

/* Driver matrix table */
.cd-comp-table { width: 100%; border-collapse: collapse; font-size: 13px; }

.cd-comp-th {
  background: var(--ct-bg-muted); color: #64748b; font-weight: 600; font-size: 11px;
  text-transform: uppercase; letter-spacing: 0.3px; padding: 8px 10px;
  text-align: center; border-bottom: 2px solid #e2e8f0;
}

.cd-comp-th:first-child { text-align: left; }

.cd-comp-td {
  padding: 6px 10px; border-bottom: 1px solid #f0f0f0;
  text-align: center; font-variant-numeric: tabular-nums;
}

.cd-comp-td:first-child { text-align: left; font-weight: 500; }

.cd-comp-rank-1 { background: #D1FAE5; color: #065F46; font-weight: 700; border-radius: 4px; }
.cd-comp-rank-2 { background: #DBEAFE; color: #1D4ED8; font-weight: 600; border-radius: 4px; }
.cd-comp-rank-3 { background: #FEF3C7; color: #92400E; font-weight: 500; border-radius: 4px; }
.cd-comp-rank-other { color: #64748b; }
.cd-comp-rank-absent { color: #d1d5db; font-style: italic; }

/* Insights */
.cd-comp-insight {
  display: flex; align-items: flex-start; gap: 10px;
  margin-bottom: 10px; padding: 10px 14px;
  background: #f8fafa; border-radius: 6px; border-left: 3px solid var(--cd-brand);
}

.cd-comp-insight-text { font-size: 13px; color: #1e293b; line-height: 1.5; }

.cd-comp-footer {
  text-align: center; padding: 24px; color: #94a3b8; font-size: 11px;
  border-top: 1px solid #e2e8f0; margin-top: 32px;
}

@media print {
  .cd-comp-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .cd-comp-section { break-inside: avoid; page-break-inside: avoid; }
  .cd-comp-content { padding: 16px; max-width: none; }
}

@media (max-width: 768px) {
  .cd-comp-cards { grid-template-columns: 1fr; }
  .cd-comp-content { padding: 16px; }
  .cd-comp-header { padding: 16px; }
}
'
  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)
  css
}


# --- Comparison header ---
build_comparison_header <- function(report_title, summaries, brand_colour, logo_uri) {

  logo_el <- NULL
  if (!is.null(logo_uri) && nzchar(logo_uri)) {
    logo_el <- htmltools::tags$div(
      class = "cd-comp-logo-container",
      htmltools::tags$img(src = logo_uri, alt = "Logo")
    )
  }

  n_outcomes <- length(summaries)

  badge_items <- list(
    htmltools::tags$span(class = "cd-comp-badge",
      htmltools::HTML(sprintf('<span class="cd-comp-badge-val">%d</span>&nbsp;Outcomes', n_outcomes))),
    htmltools::tags$span(class = "cd-comp-badge-sep"),
    htmltools::tags$span(class = "cd-comp-badge",
      format(Sys.Date(), "Created %b %Y"))
  )

  htmltools::tags$div(
    class = "cd-comp-header",
    htmltools::tags$div(
      class = "cd-comp-header-inner",
      htmltools::tags$div(
        class = "cd-comp-header-top",
        logo_el,
        htmltools::tags$div(
          htmltools::tags$div(class = "cd-comp-module-name", "Turas Catdriver"),
          htmltools::tags$div(class = "cd-comp-module-sub", "Multi-Outcome Comparison")
        )
      ),
      htmltools::tags$div(class = "cd-comp-title", report_title),
      htmltools::tags$div(class = "cd-comp-badges", badge_items)
    )
  )
}


# --- Overview cards ---
# tab_targets: optional named list mapping analysis names to tab IDs.
# When provided (unified mode), cards become clickable to switch tabs.
build_comparison_overview <- function(summaries, brand_colour, accent_colour,
                                      tab_targets = NULL) {

  cards <- lapply(summaries, function(s) {
    r2_pct <- if (!is.na(s$r2)) round(s$r2 * 100, 1) else 0
    r2_colour <- switch(s$r2_label,
      "Excellent" = "#059669",
      "Good" = "#2563EB",
      "Moderate" = "#F59E0B",
      "Limited" = "#c0392b",
      "#94a3b8"
    )

    model_type <- switch(s$outcome_type,
      binary = "Binary Logistic",
      ordinal = "Ordinal Logistic",
      nominal = "Multinomial Logistic",
      s$outcome_type
    )

    # Top 3 drivers mini-list
    top3 <- s$top_drivers[1:min(3, length(s$top_drivers))]
    driver_list <- lapply(top3, function(d) {
      htmltools::tags$div(
        style = "font-size:12px;color:#1e293b;padding:2px 0;",
        htmltools::tags$span(
          style = sprintf("color:%s;font-weight:600;", brand_colour),
          sprintf("#%d", d$rank)
        ),
        sprintf(" %s (%.0f%%)", d$label, d$importance_pct)
      )
    })

    # If tab_targets provided, make card clickable
    card_class <- "cd-comp-card"
    card_onclick <- NULL
    if (!is.null(tab_targets) && !is.null(tab_targets[[s$name]])) {
      card_class <- "cd-comp-card cd-comp-card-clickable"
      card_onclick <- sprintf("cdSwitchAnalysisTab('%s')", tab_targets[[s$name]])
    }

    htmltools::tags$div(
      class = card_class,
      onclick = card_onclick,
      htmltools::tags$div(class = "cd-comp-card-title", s$label),
      htmltools::tags$div(class = "cd-comp-card-sub", s$outcome_label),
      htmltools::tags$div(class = "cd-comp-card-stat",
        htmltools::tags$span(class = "cd-comp-card-stat-label", "Model"),
        htmltools::tags$span(class = "cd-comp-card-stat-value", model_type)
      ),
      htmltools::tags$div(class = "cd-comp-card-stat",
        htmltools::tags$span(class = "cd-comp-card-stat-label", "Sample"),
        htmltools::tags$span(class = "cd-comp-card-stat-value",
                             format(s$sample_n, big.mark = ","))
      ),
      htmltools::tags$div(class = "cd-comp-card-stat",
        htmltools::tags$span(class = "cd-comp-card-stat-label", "Model Fit"),
        htmltools::tags$span(
          style = sprintf("font-weight:600;color:%s;", r2_colour),
          sprintf("R\u00B2 = %.3f (%s)", if (is.na(s$r2)) 0 else s$r2, s$r2_label)
        )
      ),
      htmltools::tags$div(class = "cd-comp-r2-bar",
        htmltools::tags$div(
          class = "cd-comp-r2-fill",
          style = sprintf("width:%.0f%%;background:%s;", min(r2_pct * 2, 100), r2_colour)
        )
      ),
      htmltools::tags$div(
        style = "margin-top:10px;",
        htmltools::tags$div(
          style = "font-size:11px;font-weight:600;color:#64748b;text-transform:uppercase;margin-bottom:4px;",
          "Top Drivers"
        ),
        driver_list
      )
    )
  })

  htmltools::tags$div(
    class = "cd-comp-section",
    htmltools::tags$h2(class = "cd-comp-section-title", "Outcome Overview"),
    htmltools::tags$div(class = "cd-comp-cards", cards)
  )
}


# --- Driver comparison matrix ---
build_comparison_driver_matrix <- function(summaries, driver_comparison, brand_colour) {

  outcome_names <- vapply(summaries, function(s) s$label, character(1))

  # Header row
  header_cells <- list(htmltools::tags$th(class = "cd-comp-th", "Driver"))
  for (nm in outcome_names) {
    header_cells <- c(header_cells, list(htmltools::tags$th(class = "cd-comp-th", nm)))
  }
  header_row <- htmltools::tags$tr(header_cells)

  # Data rows
  data_rows <- lapply(driver_comparison, function(d) {
    cells <- list(htmltools::tags$td(class = "cd-comp-td", d$label))
    for (s in summaries) {
      rank <- d$ranks[[s$name]]
      pct <- d$pcts[[s$name]]
      if (is.null(rank)) {
        cells <- c(cells, list(htmltools::tags$td(
          class = "cd-comp-td",
          htmltools::tags$span(class = "cd-comp-rank-absent", "\u2014")
        )))
      } else {
        rank_class <- if (rank == 1) "cd-comp-rank-1"
                      else if (rank == 2) "cd-comp-rank-2"
                      else if (rank == 3) "cd-comp-rank-3"
                      else "cd-comp-rank-other"
        cells <- c(cells, list(htmltools::tags$td(
          class = "cd-comp-td",
          htmltools::tags$span(class = rank_class,
            sprintf("#%d", rank)),
          htmltools::tags$span(
            style = "margin-left:4px;font-size:11px;color:#94a3b8;",
            sprintf("%.0f%%", pct)
          )
        )))
      }
    }
    htmltools::tags$tr(cells)
  })

  htmltools::tags$div(
    class = "cd-comp-section",
    htmltools::tags$h2(class = "cd-comp-section-title", "Driver Comparison Matrix"),
    htmltools::tags$p(
      style = "color:#64748b;font-size:13px;margin-bottom:14px;",
      "How each driver ranks across different outcomes. Rank #1 indicates the strongest driver for that outcome."
    ),
    htmltools::tags$table(
      class = "cd-comp-table",
      htmltools::tags$thead(header_row),
      htmltools::tags$tbody(data_rows)
    )
  )
}


# --- Cross-outcome insights ---
build_comparison_insights <- function(summaries, driver_comparison, brand_colour) {

  insights <- character(0)

  # Find consistent top drivers (rank 1-3 across all outcomes)
  n_outcomes <- length(summaries)
  for (d in driver_comparison) {
    if (d$n_appearances == n_outcomes) {
      ranks <- unlist(d$ranks)
      if (all(ranks <= 3)) {
        insights <- c(insights, sprintf(
          "%s is a top-3 driver across all %d outcomes (ranks: %s), making it a universal influence factor.",
          d$label, n_outcomes,
          paste(sprintf("#%d", ranks), collapse = ", ")
        ))
      }
    }
  }

  # Find outcome-specific drivers (appear in only 1 outcome)
  for (d in driver_comparison) {
    if (d$n_appearances == 1 && max(unlist(d$ranks)) <= 2) {
      outcome_name <- names(d$ranks)[1]
      s <- summaries[[outcome_name]]
      insights <- c(insights, sprintf(
        "%s is uniquely important for %s (rank #%d, %.0f%%) but does not appear as a top driver for other outcomes.",
        d$label, s$label, d$ranks[[1]], d$pcts[[1]]
      ))
    }
  }

  # Best-fit vs worst-fit comparison
  r2_vals <- vapply(summaries, function(s) {
    if (is.na(s$r2)) 0 else s$r2
  }, numeric(1))
  best_idx <- which.max(r2_vals)
  worst_idx <- which.min(r2_vals)
  if (best_idx != worst_idx && max(r2_vals) > 0) {
    best <- summaries[[best_idx]]
    worst <- summaries[[worst_idx]]
    insights <- c(insights, sprintf(
      "The measured factors explain %s best (R\u00B2 = %.3f, %s) and %s least well (R\u00B2 = %.3f, %s). The weaker-fit outcomes may be driven by unmeasured factors.",
      best$label, best$r2, best$r2_label,
      worst$label, worst$r2, worst$r2_label
    ))
  }

  if (length(insights) == 0) {
    insights <- "No cross-outcome patterns detected with the current set of analyses."
  }

  insight_els <- lapply(insights, function(txt) {
    htmltools::tags$div(
      class = "cd-comp-insight",
      htmltools::tags$span(class = "cd-comp-insight-text", txt)
    )
  })

  htmltools::tags$div(
    class = "cd-comp-section",
    htmltools::tags$h2(class = "cd-comp-section-title", "Cross-Outcome Insights"),
    htmltools::tags$p(
      style = "color:#64748b;font-size:13px;margin-bottom:14px;",
      "Patterns detected by comparing driver importance across outcomes."
    ),
    insight_els
  )
}


# --- Footer ---
build_comparison_footer <- function() {
  htmltools::tags$div(
    class = "cd-comp-footer",
    sprintf("Generated by TURAS Catdriver Comparison Module | %s",
            format(Sys.time(), "%d %B %Y %H:%M")),
    htmltools::tags$br(),
    "The Research LampPost (Pty) Ltd"
  )
}
