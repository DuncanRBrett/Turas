# ==============================================================================
# CATDRIVER HTML REPORT - UNIFIED MULTI-OUTCOME REPORT
# ==============================================================================
# Generates a single HTML file combining multiple catdriver analyses.
# Single analysis → delegates to standard individual report.
# Multiple analyses → tabbed report: Overview | Analysis1 | Analysis2 | ...
#
# Overview tab shows comparison content (cards, driver matrix, insights).
# Each analysis tab shows the full individual report sections.
# Overview cards are clickable → jump to corresponding analysis tab.
# ==============================================================================

#' Generate Unified Catdriver Report
#'
#' Main entry point for generating a single HTML file containing one or more
#' catdriver analyses. With a single analysis, delegates to the standard
#' individual report. With multiple analyses, creates a tabbed report.
#'
#' @param analyses Named list of analysis entries. Each entry should be a list
#'   with elements: `results` (from run_categorical_keydriver()),
#'   `config` (the config list), and optionally `label` (display name).
#' @param output_path Path for the output HTML file
#' @param report_title Optional title (default: "Categorical Key Driver Analysis")
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @param researcher_logo_path Optional researcher logo file path
#' @param client_logo_path Optional client logo file path
#' @param client_name Optional client name (appears in header as "for X")
#' @param company_name Researcher/company name (default: "The Research Lamppost")
#' @return List with status, output_file, file_size_mb
#' @export
generate_catdriver_unified_report <- function(analyses,
                                              output_path,
                                              report_title = "Categorical Key Driver Analysis",
                                              brand_colour = "#323367",
                                              accent_colour = "#CC9900",
                                              researcher_logo_path = NULL,
                                              client_logo_path = NULL,
                                              client_name = NULL,
                                              company_name = "The Research Lamppost") {

  start_time <- Sys.time()

  cat("\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  CATDRIVER UNIFIED REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # --- Validation ---
  if (!is.list(analyses) || length(analyses) == 0) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: CFG_UNIFIED_NO_ANALYSES\n")
    cat("Message: At least 1 analysis required\n")
    cat("==================\n\n")
    return(list(
      status = "REFUSED",
      code = "CFG_UNIFIED_NO_ANALYSES",
      message = "At least 1 analysis entry required for unified report",
      how_to_fix = "Provide a named list with at least 1 analysis entry"
    ))
  }

  if (!requireNamespace("htmltools", quietly = TRUE)) {
    return(list(status = "REFUSED", code = "PKG_HTMLTOOLS_MISSING",
                message = "htmltools package required",
                how_to_fix = "install.packages('htmltools')"))
  }

  # --- Single analysis: delegate to standard report ---
  if (length(analyses) == 1) {
    cat("  Single analysis detected — generating standard report.\n")
    entry <- analyses[[1]]
    # Thread brand/accent/client from unified call into config
    entry$config$brand_colour <- brand_colour
    entry$config$accent_colour <- accent_colour
    entry$config$researcher_logo_path <- researcher_logo_path
    if (!is.null(client_logo_path)) entry$config$client_logo_path <- client_logo_path
    if (!is.null(client_name)) entry$config$client_name <- client_name
    if (!is.null(company_name)) entry$config$company_name <- company_name
    if (!is.null(report_title)) entry$config$report_title <- report_title
    return(generate_catdriver_html_report(entry$results, entry$config, output_path))
  }

  # --- Multiple analyses: build unified tabbed report ---
  cat(sprintf("  Processing %d analyses for unified report...\n", length(analyses)))

  analysis_names <- names(analyses)
  if (is.null(analysis_names)) {
    analysis_names <- paste0("Analysis_", seq_along(analyses))
    names(analyses) <- analysis_names
  }

  # Generate safe tab IDs for each analysis
  tab_ids <- vapply(analysis_names, function(nm) {
    gsub("[^a-zA-Z0-9]", "-", tolower(nm))
  }, character(1))
  names(tab_ids) <- analysis_names

  # Generate id_prefixes for each analysis
  id_prefixes <- vapply(tab_ids, function(tid) paste0(tid, "-"), character(1))
  names(id_prefixes) <- analysis_names

  # --- Transform, build tables & charts for each analysis ---
  panel_data <- list()
  warnings <- character(0)

  for (name in analysis_names) {
    entry <- analyses[[name]]

    # Skip REFUSED analyses (e.g. outcome variable not found in data)
    # TRS refusals may use status="REFUSED", run_status="REFUSED", or refused=TRUE
    is_refused <- isTRUE(entry$results$refused) ||
                  identical(entry$results$status, "REFUSED") ||
                  identical(entry$results$run_status, "REFUSED")
    if (is_refused) {
      refuse_reason <- entry$results$reason %||% entry$results$message %||% "unknown reason"
      cat(sprintf("  Skipping %s: REFUSED - %s\n", name, refuse_reason))
      warnings <- c(warnings, sprintf("%s was excluded (REFUSED: %s)", name, refuse_reason))
      next
    }

    cat(sprintf("  Transforming: %s...\n", name))

    html_data <- tryCatch({
      transform_catdriver_for_html(entry$results, entry$config)
    }, error = function(e) {
      warnings <<- c(warnings, sprintf("Transform failed for %s: %s", name, e$message))
      NULL
    })

    if (is.null(html_data)) next

    prefix <- id_prefixes[[name]]

    # Build tables with prefix
    tables <- list()
    tables$importance <- tryCatch(
      build_cd_importance_table(html_data$importance, id_prefix = prefix),
      error = function(e) { NULL }
    )
    tables$patterns <- list()
    for (var_name in names(html_data$patterns)) {
      tables$patterns[[var_name]] <- tryCatch(
        build_cd_pattern_table(html_data$patterns[[var_name]], var_name,
                               id_prefix = prefix),
        error = function(e) { NULL }
      )
    }
    tables$odds_ratios <- tryCatch(
      build_cd_odds_ratio_table(html_data$odds_ratios, html_data$has_bootstrap,
                                 id_prefix = prefix),
      error = function(e) { NULL }
    )
    tables$diagnostics <- tryCatch(
      build_cd_diagnostics_table(html_data$diagnostics, html_data$model_info,
                                  entry$config, id_prefix = prefix),
      error = function(e) { NULL }
    )
    # Probability lift tables (one per driver, conditional)
    tables$probability_lifts <- list()
    if (!is.null(html_data$probability_lifts)) {
      for (var_name in names(html_data$probability_lifts)) {
        tables$probability_lifts[[var_name]] <- tryCatch(
          build_cd_probability_lift_table(html_data$probability_lifts[[var_name]],
                                          var_name, id_prefix = prefix),
          error = function(e) { NULL }
        )
      }
    }

    # Build charts
    charts <- list()
    charts$importance <- tryCatch(
      build_cd_importance_chart(html_data$importance, brand_colour),
      error = function(e) { NULL }
    )
    charts$forest <- tryCatch(
      build_cd_forest_plot(html_data$odds_ratios, brand_colour, accent_colour),
      error = function(e) { NULL }
    )
    charts$probability_lift <- tryCatch(
      build_cd_probability_lift_chart(html_data$probability_lifts, brand_colour, accent_colour),
      error = function(e) { NULL }
    )

    panel_data[[name]] <- list(
      html_data = html_data,
      tables = tables,
      charts = charts,
      config = entry$config
    )
  }

  if (length(panel_data) == 0) {
    return(list(
      status = "REFUSED",
      code = "CALC_ALL_TRANSFORMS_FAILED",
      message = "All analysis transforms failed — cannot build unified report",
      how_to_fix = "Check that all analysis results contain valid data"
    ))
  }

  # --- Extract comparison data for overview ---
  # Only include analyses that produced valid panel_data (excludes REFUSED / failed)
  valid_analyses <- analyses[names(panel_data)]
  cat("  Building overview comparison data...\n")
  comp_data <- extract_comparison_data(valid_analyses)
  summaries <- comp_data$summaries
  driver_comparison <- comp_data$driver_comparison

  # Tab targets for clickable overview cards
  tab_targets <- setNames(
    as.list(tab_ids[names(panel_data)]),
    names(panel_data)
  )

  # --- Build CSS ---
  css <- build_cd_unified_css(brand_colour, accent_colour)

  # --- Build logo URIs ---
  logo_uri <- resolve_logo_uri(researcher_logo_path)
  client_logo_uri <- resolve_logo_uri(client_logo_path)

  # --- Build page ---
  cat("  Assembling unified page...\n")

  # Unified header
  header <- build_unified_header(report_title, summaries, brand_colour,
                                  logo_uri, client_logo_uri = client_logo_uri,
                                  client_name = client_name,
                                  company_name = company_name)

  # Tab bar: Overview + one per analysis + Pinned
  tab_buttons <- list(
    htmltools::tags$button(
      class = "cd-analysis-tab active",
      `data-tab` = "overview",
      onclick = "cdSwitchAnalysisTab('overview')",
      "Overview"
    )
  )
  for (name in names(panel_data)) {
    label <- summaries[[name]]$label %||% name
    tab_buttons <- c(tab_buttons, list(
      htmltools::tags$button(
        class = "cd-analysis-tab",
        `data-tab` = tab_ids[[name]],
        onclick = sprintf("cdSwitchAnalysisTab('%s')", tab_ids[[name]]),
        label
      )
    ))
  }
  # Pinned Views tab
  tab_buttons <- c(tab_buttons, list(
    htmltools::tags$button(
      class = "cd-analysis-tab",
      `data-tab` = "pinned",
      onclick = "cdSwitchAnalysisTab('pinned')",
      htmltools::HTML(paste0(
        "\U0001F4CC Pinned ",
        '<span id="cd-pin-count-badge" class="cd-pin-count-badge" style="display:none;">0</span>'
      ))
    )
  ))

  # Action bar (save button)
  action_bar <- build_cd_action_bar(report_title)

  tab_bar <- htmltools::tags$div(
    class = "cd-analysis-tabs",
    tab_buttons
  )

  # Overview panel
  overview_prefix <- "overview-"
  overview_panel <- htmltools::tags$div(
    class = "cd-analysis-panel active",
    id = "cd-tab-overview",
    htmltools::tags$div(
      class = "cd-comp-content",
      build_comparison_overview(summaries, brand_colour, accent_colour,
                                tab_targets = tab_targets, id_prefix = overview_prefix),
      build_comparison_driver_matrix(summaries, driver_comparison, brand_colour,
                                      id_prefix = overview_prefix),
      build_comparison_insights(summaries, driver_comparison, brand_colour,
                                 id_prefix = overview_prefix)
    )
  )

  # Analysis panels
  analysis_panels <- lapply(names(panel_data), function(name) {
    pd <- panel_data[[name]]
    prefix <- id_prefixes[[name]]
    label <- summaries[[name]]$label %||% name

    build_cd_analysis_panel(
      tab_id = tab_ids[[name]],
      panel_title = label,
      html_data = pd$html_data,
      tables = pd$tables,
      charts = pd$charts,
      config = pd$config,
      id_prefix = prefix,
      brand_colour = brand_colour
    )
  })

  # Pinned Views panel
  pinned_panel <- htmltools::tags$div(
    class = "cd-analysis-panel",
    id = "cd-tab-pinned",
    htmltools::tags$div(
      style = "max-width:1100px;margin:0 auto;padding:24px 32px;",
      htmltools::tags$div(
        class = "cd-pinned-panel-header",
        htmltools::tags$div(class = "cd-pinned-panel-title",
                            "\U0001F4CC Pinned Views"),
        htmltools::tags$div(
          class = "cd-pinned-panel-actions",
          htmltools::tags$button(
            class = "cd-pinned-panel-btn",
            onclick = "cdAddSection()",
            "\u2795 Add Section"
          ),
          htmltools::tags$button(
            class = "cd-pinned-panel-btn",
            onclick = "cdExportAllPinnedPNG()",
            "\U0001F4E5 Export All as PNG"
          ),
          htmltools::tags$button(
            class = "cd-pinned-panel-btn",
            onclick = "cdPrintPinnedViews()",
            "\U0001F5B6 Print / PDF"
          ),
          htmltools::tags$button(
            class = "cd-pinned-panel-btn",
            onclick = "cdClearAllPinned()",
            "\U0001F5D1 Clear All"
          )
        )
      ),
      htmltools::tags$div(
        id = "cd-pinned-empty",
        class = "cd-pinned-empty",
        htmltools::tags$div(class = "cd-pinned-empty-icon", "\U0001F4CC"),
        htmltools::tags$div("No pinned views yet."),
        htmltools::tags$div(
          style = "font-size:12px;margin-top:4px;",
          "Click the pin icon on any section to save it here for export."
        )
      ),
      htmltools::tags$div(id = "cd-pinned-cards-container")
    )
  )

  # Hidden insight stores — one per analysis panel + one for overview
  insight_stores <- lapply(names(panel_data), function(name) {
    prefix <- id_prefixes[[name]]
    htmltools::tags$textarea(
      class = "cd-insight-store",
      id = paste0(prefix, "cd-insight-store"),
      `data-cd-prefix` = prefix,
      style = "display:none;",
      "{}"
    )
  })
  # Overview panel insight store
  insight_stores <- c(insight_stores, list(
    htmltools::tags$textarea(
      class = "cd-insight-store",
      id = paste0(overview_prefix, "cd-insight-store"),
      `data-cd-prefix` = overview_prefix,
      style = "display:none;",
      "{}"
    )
  ))

  # Hidden pinned views data store
  pinned_store <- htmltools::tags$script(
    id = "cd-pinned-views-data",
    type = "application/json",
    "[]"
  )

  footer <- build_comparison_footer(company_name = company_name,
                                     client_name = client_name)

  # Read JS files — all 6
  js_files <- c("cd_utils.js", "cd_navigation.js", "cd_unified_tabs.js",
                 "cd_insights.js", "cd_pinned_views.js", "cd_slide_export.js")
  js_tags <- lapply(js_files, function(fname) {
    js_content <- read_js_file(fname)
    htmltools::tags$script(htmltools::HTML(js_content))
  })

  # Report Hub metadata
  source_filename <- gsub("[.]html$", "", basename(output_path), ignore.case = TRUE)
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "catdriver-unified"),
    htmltools::tags$meta(name = "turas-module-version", content = "1.1"),
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  )

  # Assemble final page
  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(name = "viewport",
                           content = "width=device-width, initial-scale=1"),
      htmltools::tags$title(report_title),
      hub_meta,
      htmltools::tags$style(htmltools::HTML(css))
    ),
    htmltools::tags$body(
      class = "cd-body",
      header,
      action_bar,
      tab_bar,
      htmltools::tags$main(
        class = "cd-main",
        htmltools::tags$div(
          class = "cd-content",
          overview_panel,
          analysis_panels,
          pinned_panel,
          footer,
          insight_stores,
          pinned_store
        )
      ),
      js_tags
    )
  )

  page <- htmltools::browsable(page)

  # --- Write file ---
  cat(sprintf("  Writing unified HTML to %s...\n", basename(output_path)))
  write_result <- write_cd_html_report(page, output_path)

  if (write_result$status == "REFUSED") return(write_result)

  elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
  cat(sprintf("  Done! %d analyses, %.2f MB in %.1f seconds\n",
              length(panel_data), write_result$file_size_mb, elapsed))
  cat(paste(rep("-", 60), collapse = ""), "\n\n")

  list(
    status = if (length(warnings) > 0) "PARTIAL" else "PASS",
    message = sprintf("Unified report: %d outcomes, %.2f MB",
                      length(panel_data), write_result$file_size_mb),
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    n_outcomes = length(panel_data),
    elapsed_seconds = elapsed,
    warnings = if (length(warnings) > 0) warnings else NULL
  )
}


# ==============================================================================
# HELPER: Read JS file from the html_report/js/ directory
# ==============================================================================
read_js_file <- function(filename) {
  js_path <- file.path(.cd_html_report_dir, "js", filename)
  if (file.exists(js_path)) {
    paste(readLines(js_path, warn = FALSE), collapse = "\n")
  } else {
    sprintf("/* %s not found */", filename)
  }
}


# ==============================================================================
# HELPER: Build unified header
# ==============================================================================
build_unified_header <- function(report_title, summaries, brand_colour,
                                  logo_uri, client_logo_uri = NULL,
                                  client_name = NULL, company_name = NULL) {

  # Build logo elements — researcher left, client right
  logo_els <- htmltools::tagList()
  if (!is.null(logo_uri) && nzchar(logo_uri)) {
    logo_els <- htmltools::tagAppendChild(logo_els,
      htmltools::tags$div(
        class = "cd-comp-logo-container",
        htmltools::tags$img(src = logo_uri, alt = "Researcher Logo")
      )
    )
  }
  if (!is.null(client_logo_uri) && nzchar(client_logo_uri)) {
    logo_els <- htmltools::tagAppendChild(logo_els,
      htmltools::tags$div(
        class = "cd-comp-logo-container",
        htmltools::tags$img(src = client_logo_uri, alt = "Client Logo")
      )
    )
  }

  # "Prepared by X for Y" row
  prepared_row <- NULL
  prepared_parts <- c()
  if (!is.null(company_name) && nzchar(company_name)) {
    prepared_parts <- c(prepared_parts, sprintf(
      'Prepared by <span style="font-weight:600;">%s</span>',
      htmltools::htmlEscape(company_name)
    ))
  }
  if (!is.null(client_name) && nzchar(client_name)) {
    prepared_parts <- c(prepared_parts, sprintf(
      'for <span style="font-weight:600;">%s</span>',
      htmltools::htmlEscape(client_name)
    ))
  }
  if (length(prepared_parts) > 0) {
    prepared_row <- htmltools::tags$div(
      class = "cd-comp-header-prepared",
      htmltools::HTML(paste(prepared_parts, collapse = " "))
    )
  }

  n_outcomes <- length(summaries)

  # Gather unique sample sizes
  sample_ns <- vapply(summaries, function(s) s$sample_n, numeric(1))
  sample_text <- if (length(unique(sample_ns)) == 1) {
    sprintf("n = %s", format(sample_ns[1], big.mark = ","))
  } else {
    sprintf("n = %s \u2013 %s", format(min(sample_ns), big.mark = ","),
            format(max(sample_ns), big.mark = ","))
  }

  badge_items <- list(
    htmltools::tags$span(class = "cd-comp-badge",
      htmltools::HTML(sprintf(
        '<span class="cd-comp-badge-val">%d</span>&nbsp;Outcomes', n_outcomes))),
    htmltools::tags$span(class = "cd-comp-badge-sep"),
    htmltools::tags$span(class = "cd-comp-badge", sample_text),
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
        logo_els,
        htmltools::tags$div(
          htmltools::tags$div(class = "cd-comp-module-name", "Turas Catdriver"),
          htmltools::tags$div(class = "cd-comp-module-sub",
                              "Multi-Outcome Key Driver Analysis")
        )
      ),
      htmltools::tags$div(class = "cd-comp-title", report_title),
      prepared_row,
      htmltools::tags$div(class = "cd-comp-badges", badge_items)
    )
  )
}


# ==============================================================================
# HELPER: Build a single analysis panel (all 6 sections)
# ==============================================================================
#' Build Analysis Panel Content
#'
#' Builds all report sections for one analysis within a unified tabbed report.
#' Each section uses the id_prefix for unique IDs.
#'
#' @param tab_id Tab ID string for the panel
#' @param panel_title Display title for the analysis
#' @param html_data Transformed data from transform_catdriver_for_html()
#' @param tables Named list of table objects
#' @param charts Named list of chart objects
#' @param config Configuration list
#' @param id_prefix ID prefix string
#' @param brand_colour Brand colour hex string
#' @return htmltools tag (the panel div)
#' @keywords internal
build_cd_analysis_panel <- function(tab_id, panel_title, html_data, tables,
                                     charts, config, id_prefix, brand_colour) {

  model_info <- html_data$model_info
  fit <- model_info$fit_statistics

  # Model type label
  model_label <- switch(model_info$outcome_type,
    binary = "Binary Logistic",
    ordinal = "Ordinal Logistic",
    nominal = "Multinomial Logistic",
    model_info$outcome_type %||% "Logistic"
  )

  # Panel heading bar with key stats
  r2_text <- if (!is.null(fit) && !is.na(fit$mcfadden_r2)) {
    sprintf("R\u00B2 = %.3f", fit$mcfadden_r2)
  } else {
    "R\u00B2 = N/A"
  }

  panel_heading <- htmltools::tags$div(
    class = "cd-panel-heading",
    htmltools::tags$div(class = "cd-panel-heading-title", panel_title),
    htmltools::tags$div(
      class = "cd-panel-heading-stats",
      htmltools::tags$span(class = "cd-panel-stat", model_label),
      htmltools::tags$span(class = "cd-panel-stat-sep", "\u2022"),
      htmltools::tags$span(class = "cd-panel-stat",
        sprintf("n = %s", format(html_data$diagnostics$complete_n, big.mark = ","))),
      htmltools::tags$span(class = "cd-panel-stat-sep", "\u2022"),
      htmltools::tags$span(class = "cd-panel-stat", r2_text),
      htmltools::tags$span(class = "cd-panel-stat-sep", "\u2022"),
      htmltools::tags$span(class = "cd-panel-stat",
        sprintf("%d Drivers", model_info$n_drivers))
    )
  )

  # Section nav bar (sticky, scoped with id_prefix)
  section_nav <- build_cd_section_nav(brand_colour, id_prefix = id_prefix)

  # Build all 6 sections with id_prefix
  exec_summary <- build_cd_exec_summary(html_data, brand_colour,
                                         id_prefix = id_prefix)
  importance <- build_cd_importance_section(tables, charts, brand_colour,
                                             id_prefix = id_prefix,
                                             n_drivers = length(html_data$importance))
  patterns <- build_cd_patterns_section(html_data, tables,
                                         id_prefix = id_prefix)
  prob_lifts <- build_cd_probability_lifts_section(html_data, tables, charts,
                                                     id_prefix = id_prefix)
  odds_ratios <- build_cd_or_section(tables, charts, html_data$has_bootstrap,
                                      id_prefix = id_prefix,
                                      odds_ratios = html_data$odds_ratios)
  diagnostics <- build_cd_diagnostics_section(tables, html_data,
                                               id_prefix = id_prefix)
  interpretation <- build_cd_interpretation_section(brand_colour,
                                                     id_prefix = id_prefix)

  htmltools::tags$div(
    class = "cd-analysis-panel",
    id = paste0("cd-tab-", tab_id),
    panel_heading,
    section_nav,
    exec_summary,
    importance,
    patterns,
    prob_lifts,
    odds_ratios,
    diagnostics,
    interpretation
  )
}


# ==============================================================================
# CSS: Unified report styles (extends individual + comparison CSS)
# ==============================================================================
build_cd_unified_css <- function(brand_colour, accent_colour) {

  # Base individual report CSS
  base_css <- build_cd_css(brand_colour, accent_colour)

  # Comparison-specific CSS (cards, matrix, insights)
  comp_css <- build_comparison_css(brand_colour, accent_colour)

  # Unified tab and panel CSS
  unified_css <- '
/* ================================================================ */
/* UNIFIED ANALYSIS TABS — sticky horizontal bar                    */
/* Matches tabs/tracker .report-tabs pattern                        */
/* ================================================================ */

.cd-analysis-tabs {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--cd-card, #ffffff);
  border-bottom: 2px solid var(--cd-border, #e2e8f0);
  display: flex;
  align-items: center;
  gap: 0;
  padding: 0 24px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.cd-analysis-tab {
  display: inline-flex;
  align-items: center;
  padding: 12px 20px;
  color: #64748b;
  background: none;
  border: none;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  font-family: inherit;
  transition: all 0.15s ease;
}

.cd-analysis-tab:hover {
  color: var(--cd-brand, #323367);
  background: #f8fafc;
}

.cd-analysis-tab.active {
  color: var(--cd-brand, #323367);
  border-bottom-color: var(--cd-brand, #323367);
}

/* ================================================================ */
/* ANALYSIS PANELS — hide/show via .active class                    */
/* ================================================================ */

.cd-analysis-panel {
  display: none;
}

.cd-analysis-panel.active {
  display: block;
}

/* Section nav inside panels stacks below the tab bar */
.cd-analysis-panel .cd-section-nav {
  top: 46px;
  z-index: 99;
}

/* ================================================================ */
/* PANEL HEADING BAR — lightweight heading per analysis panel        */
/* ================================================================ */

.cd-panel-heading {
  background: var(--ct-bg-muted, #f8f9fa);
  border: 1px solid var(--cd-border, #e2e8f0);
  border-left: 3px solid var(--cd-brand, #323367);
  border-radius: 0 8px 8px 0;
  padding: 16px 20px;
  margin-bottom: 20px;
}

.cd-panel-heading-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--cd-brand, #323367);
  margin-bottom: 4px;
}

.cd-panel-heading-stats {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.cd-panel-stat {
  font-size: 12px;
  color: #64748b;
  font-weight: 500;
}

.cd-panel-stat-sep {
  color: #d1d5db;
  font-size: 10px;
}

/* ================================================================ */
/* CLICKABLE OVERVIEW CARDS — hover effect for unified mode          */
/* ================================================================ */

.cd-comp-card-clickable {
  cursor: pointer;
  transition: border-color 0.15s, box-shadow 0.15s;
}

.cd-comp-card-clickable:hover {
  border-color: var(--cd-brand, #323367);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

/* ================================================================ */
/* PIN COUNT BADGE — small badge in the Pinned tab button            */
/* ================================================================ */

.cd-pin-count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 9px;
  background: var(--cd-brand, #323367);
  color: white;
  font-size: 10px;
  font-weight: 700;
  margin-left: 4px;
}

.cd-analysis-tab.active .cd-pin-count-badge {
  background: white;
  color: var(--cd-brand, #323367);
}

/* ================================================================ */
/* PRINT: show all panels, hide tab bar                             */
/* ================================================================ */

@media print {
  .cd-analysis-tabs { display: none !important; }
  .cd-analysis-panel { display: block !important; page-break-before: always; }
  .cd-analysis-panel:first-child { page-break-before: auto; }
  .cd-panel-heading {
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .cd-comp-card-clickable { cursor: default; box-shadow: none; }
}

/* ================================================================ */
/* RESPONSIVE: unified mode                                         */
/* ================================================================ */

@media (max-width: 768px) {
  .cd-analysis-tabs { padding: 0 12px; }
  .cd-analysis-tab { padding: 10px 14px; font-size: 12px; }
}

/* ================================================================ */
/* UNIFIED HEADER: prepared-by row & dual logos                      */
/* ================================================================ */

.cd-comp-header-prepared {
  color: rgba(255,255,255,0.70);
  font-size: 13px;
  margin-top: 4px;
  letter-spacing: 0.2px;
}

.cd-comp-header-top {
  display: flex;
  align-items: center;
  gap: 16px;
}
'
  # Combine all CSS. The unified_css overrides come last.
  paste(base_css, comp_css, unified_css, sep = "\n\n")
}
