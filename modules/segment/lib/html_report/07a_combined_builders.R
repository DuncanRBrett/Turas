# ==============================================================================
# SEGMENT HTML REPORT - COMBINED REPORT BUILDERS
# ==============================================================================
# Extracted from 07_combined_report.R for maintainability.
# Contains page assembly, CSS, header, tab bar, method panels,
# comparison panel, recommendation, comparison table/chart,
# agreement matrix, and tab-switching JavaScript.
#
# Called by generate_segment_combined_html_report() in 07_combined_report.R.
#
# Version: 11.0
# ==============================================================================

# ==============================================================================
# PAGE ASSEMBLY
# ==============================================================================


#' Build Combined Multi-Method HTML Page
#'
#' Assembles the full tabbed HTML page from per-method content and
#' comparison content. Includes report-level tabs (Analysis | Pinned Views)
#' matching the single-method report pattern. Returns an htmltools browsable page.
#'
#' @param method_html_data Named list of transformed html_data per method
#' @param method_tables Named list of table lists per method
#' @param method_charts Named list of chart lists per method
#' @param comparison_content List with table, chart, agreement elements
#' @param config Configuration list
#' @param recommendation Optional recommendation list (from results$recommendation)
#' @return htmltools::browsable tagList
#' @keywords internal
build_seg_combined_page <- function(method_html_data,
                                     method_tables,
                                     method_charts,
                                     comparison_content,
                                     config,
                                     recommendation = NULL) {

  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  report_title <- config$report_title %||% "Segmentation Analysis - Method Comparison"

  active_methods <- names(method_html_data)

  # --- Base CSS + combined-specific CSS ---
  base_css <- build_seg_css(brand_colour, accent_colour)
  combined_css <- .build_seg_combined_css(brand_colour, accent_colour)

  # --- Header ---
  header <- .build_seg_combined_header(method_html_data, config, brand_colour, report_title)

  # --- Tab bar ---
  tab_bar <- .build_seg_method_tab_bar(active_methods, brand_colour)

  # --- Per-method panels ---
  method_panels <- lapply(active_methods, function(m) {
    .build_seg_method_panel(
      method = m,
      html_data = method_html_data[[m]],
      tables = method_tables[[m]],
      charts = method_charts[[m]],
      is_first = (m == active_methods[1])
    )
  })

  # --- Comparison panel ---
  comparison_panel <- .build_seg_comparison_panel(
    comparison_content = comparison_content,
    method_html_data = method_html_data,
    brand_colour = brand_colour,
    accent_colour = accent_colour,
    recommendation = recommendation
  )

  # --- Footer ---
  footer <- build_seg_footer(config)

  # --- JavaScript ---
  tab_js <- .build_seg_combined_js()

  # Load existing JS files
  js_dir <- tryCatch({
    if (exists(".seg_html_report_dir")) {
      file.path(.seg_html_report_dir, "js")
    } else {
      turas_root <- Sys.getenv("TURAS_ROOT", getwd())
      file.path(turas_root, "modules/segment/lib/html_report/js")
    }
  }, error = function(e) {
    turas_root <- Sys.getenv("TURAS_ROOT", getwd())
    file.path(turas_root, "modules/segment/lib/html_report/js")
  })

  js_files <- c("seg_utils.js", "seg_navigation.js",
                "seg_pinned_views.js", "seg_slide_export.js")
  js_tags <- lapply(js_files, function(fname) {
    js_path <- file.path(js_dir, fname)
    js_content <- if (file.exists(js_path)) {
      paste(readLines(js_path, warn = FALSE), collapse = "\n")
    } else {
      sprintf("/* %s not found */", fname)
    }
    htmltools::tags$script(htmltools::HTML(js_content))
  })

  # --- Report Hub metadata ---
  source_filename <- basename(config$output_file %||%
                               config$report_title %||% "Segment_Combined_Report")
  hub_meta <- htmltools::tagList(
    htmltools::tags$meta(name = "turas-report-type", content = "segment-combined"),
    htmltools::tags$meta(name = "turas-module-version", content = "11.1"),
    htmltools::tags$meta(name = "turas-source-filename", content = source_filename)
  )

  # --- Action bar with help ---
  action_bar <- build_seg_action_bar(report_title)

  # --- Report-level tab bar — shared convention ---
  save_icon <- htmltools::HTML('<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-1px;margin-right:5px;"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>')

  report_tab_bar <- htmltools::tags$div(
    class = "report-tabs",
    htmltools::tags$button(
      class = "report-tab active",
      `data-tab` = "analysis",
      onclick = "switchReportTab('analysis')",
      "Analysis"
    ),
    htmltools::tags$button(
      class = "report-tab",
      `data-tab` = "pinned",
      onclick = "switchReportTab('pinned')",
      "Pinned Views"
    ),
    htmltools::tags$button(
      class = "report-tab",
      `data-tab` = "about",
      onclick = "switchReportTab('about')",
      "About"
    ),
    htmltools::tags$button(
      class = "report-tab seg-save-tab",
      onclick = "segSaveReportHTML()",
      save_icon, "Save Report"
    ),
    htmltools::tags$button(
      class = "seg-help-btn",
      onclick = "toggleHelpOverlay()",
      title = "Show help guide",
      "?"
    )
  )

  # --- Pinned Views section ---
  pinned_section <- htmltools::tags$div(
    class = "seg-section",
    id = "seg-pinned-section",
    `data-seg-section` = "pinned-views",
    htmltools::tags$div(
      class = "seg-pinned-panel-header",
      htmltools::tags$div(class = "seg-pinned-panel-title",
                          "\U0001F4CC Pinned Views"),
      htmltools::tags$div(
        class = "seg-pinned-panel-actions",
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segAddSection()",
          "\u2795 Add Section"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segExportAllPinnedPNG()",
          "\U0001F4E5 Export All as PNG"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segPrintPinnedViews()",
          "\U0001F5B6 Print / PDF"
        ),
        htmltools::tags$button(
          class = "seg-pinned-panel-btn",
          onclick = "segClearAllPinned()",
          "\U0001F5D1 Clear All"
        )
      )
    ),
    htmltools::tags$div(
      id = "seg-pinned-empty",
      class = "seg-pinned-empty",
      htmltools::tags$div(class = "seg-pinned-empty-icon", "\U0001F4CC"),
      htmltools::tags$div("No pinned views yet.")
    ),
    htmltools::tags$div(id = "seg-pinned-cards-container")
  )

  # --- Hidden data stores ---
  insight_store <- htmltools::tags$textarea(
    class = "seg-insight-store",
    id = "seg-insight-store",
    `data-seg-prefix` = "",
    style = "display:none;",
    "{}"
  )

  pinned_store <- htmltools::tags$script(
    id = "seg-pinned-views-data",
    type = "application/json",
    "[]"
  )

  # --- Assemble page ---
  page <- htmltools::tagList(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$meta(name = "viewport",
                           content = "width=device-width, initial-scale=1"),
      htmltools::tags$title(report_title),
      hub_meta,
      htmltools::tags$style(htmltools::HTML(base_css)),
      htmltools::tags$style(htmltools::HTML(combined_css))
    ),
    htmltools::tags$body(
      class = "seg-body",
      header,
      action_bar,
      report_tab_bar,
      htmltools::tags$main(
        class = "seg-main",
        # Analysis tab — active by default
        htmltools::tags$div(
          id = "tab-analysis",
          class = "tab-panel active seg-content",
          comparison_panel,
          footer
        ),
        # Pinned Views tab
        htmltools::tags$div(
          id = "tab-pinned",
          class = "tab-panel seg-content",
          pinned_section,
          footer
        ),
        # About tab
        htmltools::tags$div(
          id = "tab-about",
          class = "tab-panel seg-content",
          build_seg_about_section(config, method_html_data[[1]]),
          footer
        ),
        insight_store,
        pinned_store
      ),
      js_tags,
      htmltools::tags$script(htmltools::HTML(tab_js))
    )
  )

  htmltools::browsable(page)
}


# ==============================================================================
# COMBINED-SPECIFIC CSS
# ==============================================================================


#' Build Combined Report CSS
#'
#' Additional CSS for the tabbed method interface, comparison tables,
#' and agreement matrix. Layered on top of build_seg_css().
#'
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @return Character string of CSS
#' @keywords internal
.build_seg_combined_css <- function(brand_colour = "#323367",
                                     accent_colour = "#CC9900") {

  css <- '
/* ==== COMBINED REPORT - METHOD TABS ==== */

.seg-method-tabs {
  display: flex;
  border-bottom: 2px solid #e2e8f0;
  margin: 0 0 24px 0;
  padding: 0;
  gap: 0;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.seg-method-tab {
  padding: 12px 24px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  color: #64748b;
  border-bottom: 3px solid transparent;
  transition: all 0.2s ease;
  user-select: none;
  white-space: nowrap;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.seg-method-tab:hover {
  color: #334155;
  background: #f8fafc;
}

.seg-method-tab-active {
  color: BRAND_COLOUR;
  border-bottom-color: BRAND_COLOUR;
  font-weight: 600;
}

.seg-method-panel {
  display: none;
}

.seg-method-panel-visible {
  display: block;
}

.seg-method-panels-container {
  min-height: 400px;
}

/* ==== COMBINED REPORT - METHOD PANEL SECTIONS ==== */

.seg-combined-section {
  margin-bottom: 28px;
}

.seg-combined-section-title {
  font-size: 16px;
  font-weight: 600;
  color: #1e293b;
  margin: 0 0 12px 0;
  padding-bottom: 8px;
  border-bottom: 1px solid #e2e8f0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.seg-combined-section-desc {
  font-size: 13px;
  color: #64748b;
  margin: 0 0 16px 0;
  line-height: 1.6;
}

/* ==== COMPARISON TAB ==== */

.seg-comparison-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  margin-top: 16px;
}

@media (max-width: 900px) {
  .seg-comparison-grid {
    grid-template-columns: 1fr;
  }
}

.seg-comparison-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 20px;
}

.seg-comparison-card-title {
  font-size: 14px;
  font-weight: 600;
  color: #1e293b;
  margin: 0 0 12px 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

/* Comparison table */
.seg-comparison-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.seg-comparison-table th {
  background: #f8fafc;
  padding: 10px 14px;
  text-align: left;
  font-weight: 600;
  color: #334155;
  border-bottom: 2px solid #e2e8f0;
  white-space: nowrap;
}

.seg-comparison-table td {
  padding: 10px 14px;
  border-bottom: 1px solid #f1f5f9;
  color: #334155;
}

.seg-comparison-table tr:last-child td {
  border-bottom: none;
}

.seg-comparison-best {
  color: ACCENT_COLOUR;
  font-weight: 600;
}

/* Agreement matrix */
.seg-agreement-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.seg-agreement-table th {
  background: #f8fafc;
  padding: 10px 14px;
  text-align: center;
  font-weight: 600;
  color: #334155;
  border-bottom: 2px solid #e2e8f0;
}

.seg-agreement-table td {
  padding: 10px 14px;
  text-align: center;
  border-bottom: 1px solid #f1f5f9;
  color: #334155;
}

.seg-agreement-cell-high {
  background: #ecfdf5;
  color: #059669;
  font-weight: 600;
}

.seg-agreement-cell-medium {
  background: #FFFBEB;
  color: #B45309;
  font-weight: 500;
}

.seg-agreement-cell-low {
  background: #fef2f2;
  color: #dc2626;
}

.seg-agreement-cell-self {
  background: #f1f5f9;
  color: #94a3b8;
  font-style: italic;
}

/* Executive summary card for method panels */
.seg-combined-exec-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 16px 20px;
  margin-bottom: 16px;
}

.seg-combined-exec-stat {
  display: inline-block;
  margin-right: 24px;
  margin-bottom: 4px;
}

.seg-combined-exec-stat-label {
  font-size: 11px;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.seg-combined-exec-stat-value {
  font-size: 18px;
  font-weight: 600;
  color: BRAND_COLOUR;
  font-family: monospace;
}
'

  css <- gsub("BRAND_COLOUR", brand_colour, css, fixed = TRUE)
  css <- gsub("ACCENT_COLOUR", accent_colour, css, fixed = TRUE)

  css
}


# ==============================================================================
# COMBINED HEADER
# ==============================================================================


#' Build Combined Report Header
#'
#' Gradient banner showing report title, methods tested, k value,
#' respondent count, and generation date.
#'
#' @param method_html_data Named list of transformed html_data per method
#' @param config Configuration list
#' @param brand_colour Brand colour hex string
#' @param report_title Report title text
#' @return htmltools tag
#' @keywords internal
.build_seg_combined_header <- function(method_html_data, config, brand_colour, report_title) {

  active_methods <- names(method_html_data)

  # Get method labels
  method_labels <- vapply(active_methods, function(m) {
    switch(tolower(m),
      kmeans  = "K-Means",
      pam     = "PAM",
      hclust  = "Hierarchical",
      gmm     = "GMM",
      mclust  = "GMM",
      lca     = "Latent Class",
      toupper(m)
    )
  }, character(1))

  # Extract k and n from first available method
  first_hd <- method_html_data[[active_methods[1]]]
  k_value <- first_hd$k %||% 0
  n_obs <- first_hd$n_observations %||% 0

  # Researcher and client logos
  logo_el <- NULL
  if (exists("resolve_logo_uri", mode = "function")) {
    logo_uri <- resolve_logo_uri(config$researcher_logo_path)
    if (!is.null(logo_uri) && nzchar(logo_uri)) {
      logo_el <- htmltools::tags$div(
        class = "seg-header-logo-container",
        htmltools::tags$img(
          src = logo_uri,
          alt = "Logo",
          style = "height:56px;width:56px;object-fit:contain;"
        )
      )
    }
  }

  client_logo_el <- NULL
  if (exists("resolve_logo_uri", mode = "function")) {
    client_logo_uri <- resolve_logo_uri(config$client_logo_path)
    if (!is.null(client_logo_uri) && nzchar(client_logo_uri)) {
      client_logo_el <- htmltools::tags$div(
        class = "seg-header-logo-container",
        style = "margin-left:auto;",
        htmltools::tags$img(
          src = client_logo_uri,
          alt = "Client Logo",
          style = "height:56px;width:56px;object-fit:contain;"
        )
      )
    }
  }

  branding_left <- htmltools::tags$div(
    class = "seg-header-branding",
    logo_el,
    htmltools::tags$div(
      htmltools::tags$div(class = "seg-header-module-name", "TURAS Segmentation"),
      htmltools::tags$div(class = "seg-header-module-sub", "Method Comparison Report")
    ),
    client_logo_el
  )

  top_row <- htmltools::tags$div(class = "seg-header-top", branding_left)

  title_el <- htmltools::tags$h1(
    class = "seg-header-title",
    report_title
  )

  subtitle_el <- htmltools::tags$p(
    class = "seg-header-subtitle",
    sprintf("Comparing %d clustering methods on %s observations",
            length(active_methods),
            format(n_obs, big.mark = ","))
  )

  badge_bar <- htmltools::tags$div(
    class = "seg-header-badges",
    htmltools::tags$span(
      class = "seg-badge-item",
      htmltools::tags$span(class = "seg-badge-label", "Methods"),
      htmltools::tags$span(class = "seg-badge-value",
                           paste(method_labels, collapse = ", "))
    ),
    htmltools::tags$span(
      class = "seg-badge-item",
      htmltools::tags$span(class = "seg-badge-label", "k"),
      htmltools::tags$span(class = "seg-badge-value", as.character(k_value))
    ),
    htmltools::tags$span(
      class = "seg-badge-item",
      htmltools::tags$span(class = "seg-badge-label", "n"),
      htmltools::tags$span(class = "seg-badge-value",
                           format(n_obs, big.mark = ","))
    ),
    htmltools::tags$span(
      class = "seg-badge-item",
      htmltools::tags$span(class = "seg-badge-label", "Generated"),
      htmltools::tags$span(class = "seg-badge-value",
                           format(Sys.time(), "%d %B %Y, %H:%M"))
    )
  )

  htmltools::tags$header(
    class = "seg-header",
    style = sprintf("border-top: 4px solid %s;", brand_colour),
    htmltools::tags$div(
      class = "seg-header-inner",
      top_row,
      title_el,
      subtitle_el,
      badge_bar
    )
  )
}


# ==============================================================================
# TAB BAR
# ==============================================================================


#' Build Method Tab Bar
#'
#' Horizontal tab strip with one tab per method plus a Comparison tab.
#'
#' @param active_methods Character vector of method names
#' @param brand_colour Brand colour hex string
#' @return htmltools tag
#' @keywords internal
.build_seg_method_tab_bar <- function(active_methods, brand_colour) {

  method_labels <- vapply(active_methods, function(m) {
    switch(tolower(m),
      kmeans  = "K-Means",
      pam     = "PAM",
      hclust  = "Hierarchical",
      gmm     = "GMM",
      mclust  = "GMM",
      lca     = "Latent Class",
      toupper(m)
    )
  }, character(1))

  tabs <- lapply(seq_along(active_methods), function(i) {
    m <- active_methods[i]
    is_first <- (i == 1)

    htmltools::tags$div(
      class = paste("seg-method-tab",
                     if (is_first) "seg-method-tab-active" else ""),
      `data-method` = m,
      method_labels[i]
    )
  })

  # Add Comparison tab
  comparison_tab <- htmltools::tags$div(
    class = "seg-method-tab",
    `data-method` = "comparison",
    "Comparison"
  )

  htmltools::tags$div(
    class = "seg-method-tabs",
    id = "seg-method-tabs",
    tabs,
    comparison_tab
  )
}


# ==============================================================================
# PER-METHOD PANEL
# ==============================================================================


#' Build Method Panel Content
#'
#' Builds the content panel for a single clustering method, showing
#' executive summary, segment overview, validation, profiles, and
#' segment cards (where available).
#'
#' @param method Character, method name
#' @param html_data Transformed html_data for this method
#' @param tables Named list of table objects for this method
#' @param charts Named list of chart objects for this method
#' @param is_first Logical, whether this is the first (default visible) tab
#' @return htmltools tag
#' @keywords internal
.build_seg_method_panel <- function(method, html_data, tables, charts, is_first = FALSE) {

  method_label <- switch(tolower(method),
    kmeans  = "K-Means",
    pam     = "PAM",
    hclust  = "Hierarchical",
    gmm     = "GMM",
    mclust  = "GMM",
    lca     = "Latent Class",
    toupper(method)
  )

  sections <- list()

  # --- Executive summary card ---
  diag <- html_data$diagnostics
  exec_stats <- list()

  if (!is.null(diag$avg_silhouette) && !is.na(diag$avg_silhouette)) {
    sil_val <- diag$avg_silhouette
    sil_label <- if (sil_val >= 0.50) "Strong"
                 else if (sil_val >= 0.35) "Good"
                 else if (sil_val >= 0.25) "Moderate"
                 else "Weak"
    exec_stats <- c(exec_stats, list(
      htmltools::tags$div(
        class = "seg-combined-exec-stat",
        htmltools::tags$div(class = "seg-combined-exec-stat-label", "Silhouette"),
        htmltools::tags$div(class = "seg-combined-exec-stat-value",
                            sprintf("%.3f", sil_val)),
        htmltools::tags$div(
          style = "font-size:11px; color:#64748b;", sil_label
        )
      )
    ))
  }

  if (!is.null(diag$betweenss_totss) && !is.na(diag$betweenss_totss)) {
    exec_stats <- c(exec_stats, list(
      htmltools::tags$div(
        class = "seg-combined-exec-stat",
        htmltools::tags$div(class = "seg-combined-exec-stat-label", "BSS/TSS"),
        htmltools::tags$div(class = "seg-combined-exec-stat-value",
                            sprintf("%.0f%%", diag$betweenss_totss * 100))
      )
    ))
  }

  if (!is.null(html_data$k) && !is.na(html_data$k)) {
    exec_stats <- c(exec_stats, list(
      htmltools::tags$div(
        class = "seg-combined-exec-stat",
        htmltools::tags$div(class = "seg-combined-exec-stat-label", "Segments"),
        htmltools::tags$div(class = "seg-combined-exec-stat-value",
                            as.character(html_data$k))
      )
    ))
  }

  if (!is.null(html_data$n_observations) && !is.na(html_data$n_observations)) {
    exec_stats <- c(exec_stats, list(
      htmltools::tags$div(
        class = "seg-combined-exec-stat",
        htmltools::tags$div(class = "seg-combined-exec-stat-label", "Respondents"),
        htmltools::tags$div(class = "seg-combined-exec-stat-value",
                            format(html_data$n_observations, big.mark = ","))
      )
    ))
  }

  if (length(exec_stats) > 0) {
    sections$exec <- htmltools::tags$div(
      class = "seg-combined-exec-card",
      exec_stats
    )
  }

  # --- Segment Overview ---
  overview_els <- list()
  if (!is.null(charts$sizes)) {
    overview_els <- c(overview_els, list(charts$sizes))
  }
  if (!is.null(tables$overview)) {
    overview_els <- c(overview_els, list(tables$overview))
  }

  # Pin prefix for combined report (method-specific to avoid collisions)
  pin_prefix <- paste0(tolower(method), "-")

  if (length(overview_els) > 0) {
    sections$overview <- htmltools::tags$div(
      class = "seg-combined-section",
      `data-seg-section` = paste0(pin_prefix, "overview"),
      htmltools::tags$div(
        class = "seg-combined-section-header",
        style = "display:flex;justify-content:space-between;align-items:center;",
        htmltools::tags$h4(class = "seg-combined-section-title", "Segment Overview"),
        build_seg_component_pin_btn(paste0(pin_prefix, "overview"), "chart", pin_prefix)
      ),
      htmltools::tags$p(
        class = "seg-combined-section-desc",
        sprintf("Segment sizes for the %s solution with k = %d.",
                method_label, html_data$k %||% 0)
      ),
      overview_els
    )
  }

  # --- Validation ---
  validation_els <- list()
  if (!is.null(charts$silhouette)) {
    validation_els <- c(validation_els, list(charts$silhouette))
  }
  if (!is.null(tables$validation)) {
    validation_els <- c(validation_els, list(
      htmltools::tags$div(style = "margin-top:16px;", tables$validation)
    ))
  }

  if (length(validation_els) > 0) {
    sections$validation <- htmltools::tags$div(
      class = "seg-combined-section",
      `data-seg-section` = paste0(pin_prefix, "validation"),
      htmltools::tags$div(
        class = "seg-combined-section-header",
        style = "display:flex;justify-content:space-between;align-items:center;",
        htmltools::tags$h4(class = "seg-combined-section-title", "Validation Metrics"),
        build_seg_component_pin_btn(paste0(pin_prefix, "validation"), "chart", pin_prefix)
      ),
      htmltools::tags$p(
        class = "seg-combined-section-desc",
        "Silhouette scores and cluster validation statistics for this method."
      ),
      validation_els
    )
  }

  # --- Profiles (heatmap) ---
  profiles_els <- list()
  if (!is.null(charts$heatmap)) {
    profiles_els <- c(profiles_els, list(charts$heatmap))
  }
  if (!is.null(tables$profiles)) {
    profiles_els <- c(profiles_els, list(
      htmltools::tags$div(style = "margin-top:16px;", tables$profiles)
    ))
  }

  if (length(profiles_els) > 0) {
    sections$profiles <- htmltools::tags$div(
      class = "seg-combined-section",
      `data-seg-section` = paste0(pin_prefix, "profiles"),
      htmltools::tags$div(
        class = "seg-combined-section-header",
        style = "display:flex;justify-content:space-between;align-items:center;",
        htmltools::tags$h4(class = "seg-combined-section-title", "Segment Profiles"),
        build_seg_component_pin_btn(paste0(pin_prefix, "profiles"), "chart", pin_prefix)
      ),
      htmltools::tags$p(
        class = "seg-combined-section-desc",
        "Heatmap showing variable means per segment. Darker cells indicate higher values relative to the overall mean."
      ),
      profiles_els
    )
  }

  # --- Variable Importance ---
  if (!is.null(charts$importance)) {
    sections$importance <- htmltools::tags$div(
      class = "seg-combined-section",
      htmltools::tags$h4(class = "seg-combined-section-title", "Variable Importance"),
      htmltools::tags$p(
        class = "seg-combined-section-desc",
        "Variables ranked by their discriminating power across segments (eta-squared from ANOVA)."
      ),
      charts$importance
    )
  }

  # --- Segment Cards (if available) ---
  if (!is.null(html_data$enhanced$segment_cards)) {
    cards_content <- .build_seg_combined_cards(html_data)
    if (!is.null(cards_content)) {
      sections$cards <- htmltools::tags$div(
        class = "seg-combined-section",
        htmltools::tags$h4(class = "seg-combined-section-title", "Segment Cards"),
        cards_content
      )
    }
  }

  # --- Wrap in panel div ---
  panel_class <- if (is_first) {
    "seg-method-panel seg-method-panel-visible"
  } else {
    "seg-method-panel"
  }

  htmltools::tags$div(
    class = panel_class,
    `data-method` = method,
    htmltools::tags$h3(
      style = "font-size:18px; font-weight:600; color:#1e293b; margin:0 0 16px 0;",
      sprintf("%s Clustering Results", method_label)
    ),
    sections
  )
}


#' Build Simplified Segment Cards for Combined Report
#'
#' Renders segment cards in a compact format suitable for the combined report.
#'
#' @param html_data Transformed html_data containing enhanced$segment_cards
#' @return htmltools tag or NULL
#' @keywords internal
.build_seg_combined_cards <- function(html_data) {

  cards_data <- html_data$enhanced$segment_cards
  if (is.null(cards_data) || length(cards_data) == 0) return(NULL)

  segment_names <- html_data$segment_names %||% list()

  card_els <- lapply(seq_along(cards_data), function(i) {
    card <- cards_data[[i]]
    seg_id <- card$segment_id %||% i
    seg_name <- segment_names[[seg_id]] %||% card$name %||% paste0("Segment ", seg_id)

    # Description
    desc_el <- if (!is.null(card$description) && nzchar(card$description)) {
      htmltools::tags$p(
        style = "font-size:13px; color:#64748b; margin:8px 0 0 0; line-height:1.5;",
        card$description
      )
    }

    # Key characteristics list
    chars_el <- NULL
    if (!is.null(card$key_characteristics) && length(card$key_characteristics) > 0) {
      chars_el <- htmltools::tags$ul(
        style = "margin:8px 0 0 0; padding-left:18px; font-size:12px; color:#475569;",
        lapply(card$key_characteristics, function(ch) {
          htmltools::tags$li(style = "margin-bottom:3px;", ch)
        })
      )
    }

    htmltools::tags$div(
      style = "border:1px solid #e2e8f0; border-radius:6px; padding:14px 18px; margin-bottom:10px; background:white;",
      htmltools::tags$div(
        style = "font-size:14px; font-weight:600; color:#1e293b;",
        sprintf("%s (Segment %d)", seg_name, seg_id)
      ),
      desc_el,
      chars_el
    )
  })

  htmltools::tagList(card_els)
}


# ==============================================================================
# COMPARISON PANEL
# ==============================================================================


#' Build Comparison Panel
#'
#' The Comparison tab content showing side-by-side metrics, bar chart,
#' and inter-method agreement matrix. The Best Fit recommendation banner
#' appears at the very top for immediate visibility.
#'
#' @param comparison_content List with table, chart, agreement
#' @param method_html_data Named list of transformed html_data per method
#' @param brand_colour Brand colour hex string
#' @param accent_colour Accent colour hex string
#' @param recommendation Optional recommendation list (from results$recommendation)
#' @return htmltools tag
#' @keywords internal
.build_seg_comparison_panel <- function(comparison_content,
                                         method_html_data,
                                         brand_colour,
                                         accent_colour,
                                         recommendation = NULL) {

  sections <- list()

  # --- Best Fit recommendation banner (TOP of comparison tab) ---
  rec_section <- .build_seg_combined_recommendation(
    method_html_data, accent_colour, recommendation
  )
  if (!is.null(rec_section)) {
    sections$recommendation <- rec_section
  }

  # Intro text
  active_methods <- names(method_html_data)
  method_labels <- vapply(active_methods, function(m) {
    switch(tolower(m),
      kmeans = "K-Means", pam = "PAM", hclust = "Hierarchical",
      gmm = "GMM", mclust = "GMM", lca = "Latent Class", toupper(m)
    )
  }, character(1))

  sections$intro <- htmltools::tags$p(
    class = "seg-combined-section-desc",
    sprintf("Side-by-side comparison of %s across %d clustering methods.",
            paste(method_labels, collapse = ", "),
            length(active_methods))
  )

  # --- Metrics comparison table ---
  if (!is.null(comparison_content$table)) {
    sections$metrics <- htmltools::tags$div(
      class = "seg-combined-section",
      htmltools::tags$h4(class = "seg-combined-section-title", "Metrics Comparison"),
      htmltools::tags$p(
        class = "seg-combined-section-desc",
        "Best value per metric is highlighted. Higher silhouette, CH index, and BSS/TSS indicate better separation. Larger minimum segment size indicates more balanced solutions."
      ),
      comparison_content$table
    )
  }

  # --- Silhouette comparison chart ---
  if (!is.null(comparison_content$chart)) {
    sections$chart <- htmltools::tags$div(
      class = "seg-combined-section",
      htmltools::tags$h4(class = "seg-combined-section-title", "Silhouette Score Comparison"),
      htmltools::tags$p(
        class = "seg-combined-section-desc",
        "Visual comparison of average silhouette width across methods. Higher is better."
      ),
      comparison_content$chart
    )
  }

  # --- Agreement matrix ---
  if (!is.null(comparison_content$agreement)) {
    sections$agreement <- htmltools::tags$div(
      class = "seg-combined-section",
      htmltools::tags$h4(class = "seg-combined-section-title", "Method Agreement"),
      htmltools::tags$p(
        class = "seg-combined-section-desc",
        "Adjusted Rand Index measuring how similarly each pair of methods assigns respondents to segments. Values range from 0 (random) to 1 (identical). Higher agreement suggests robustness of the segmentation structure."
      ),
      comparison_content$agreement
    )
  }

  # --- Method overview cards with pros/cons ---
  method_cards <- lapply(active_methods, function(m) {
    callout <- .build_method_callout(m, method_html_data[[m]]$k %||% 0)
    if (!is.null(callout)) callout
  })
  method_cards <- Filter(Negate(is.null), method_cards)

  if (length(method_cards) > 0) {
    sections$method_overviews <- htmltools::tags$div(
      class = "seg-combined-section",
      htmltools::tags$h4(class = "seg-combined-section-title", "Method Overviews"),
      htmltools::tags$p(
        class = "seg-combined-section-desc",
        "Each method takes a different approach to grouping respondents. Understanding these differences helps inform which solution to adopt."
      ),
      method_cards
    )
  }

  # --- Analyst insight area for method choice rationale ---
  sections$analyst_insight <- htmltools::tags$div(
    class = "seg-combined-section",
    htmltools::tags$h4(class = "seg-combined-section-title", "Analyst Commentary"),
    htmltools::tags$p(
      class = "seg-combined-section-desc",
      "Use this space to document why a particular method was chosen and any considerations for the final solution."
    ),
    build_seg_insight_area("comparison-method-choice")
  )

  htmltools::tags$div(
    class = "seg-method-panel seg-method-panel-visible",
    `data-method` = "comparison",
    htmltools::tags$h3(
      style = "font-size:18px; font-weight:600; color:#1e293b; margin:0 0 16px 0;",
      "Method Comparison"
    ),
    sections
  )
}


#' Build Combined Report Recommendation
#'
#' Determines and displays which method performs best across metrics.
#' If \code{recommendation} is provided (from \code{results$recommendation}),
#' uses its \code{recommended_method}, \code{reason}, and \code{scores} fields.
#' Otherwise falls back to computing scores from method_html_data.
#'
#' Returns a prominent banner suitable for display at the top of the
#' Comparison tab, using the \code{seg-quality-banner} CSS classes.
#'
#' @param method_html_data Named list of transformed html_data per method
#' @param accent_colour Accent colour hex string
#' @param recommendation Optional recommendation list with recommended_method,
#'   reason, and scores fields (from results$recommendation)
#' @return htmltools tag or NULL
#' @keywords internal
.build_seg_combined_recommendation <- function(method_html_data,
                                                 accent_colour,
                                                 recommendation = NULL) {

  active_methods <- names(method_html_data)
  if (length(active_methods) < 2) return(NULL)

  # --- Resolve best method and reason ---
  if (!is.null(recommendation) &&
      !is.null(recommendation$recommended_method) &&
      nzchar(recommendation$recommended_method)) {
    # Use pre-computed recommendation
    best_method <- recommendation$recommended_method
    reason_text <- recommendation$reason %||% NULL
    ext_scores  <- recommendation$scores
  } else {
    best_method <- NULL
    reason_text <- NULL
    ext_scores  <- NULL
  }

  # Fall back to scoring if no external recommendation
  if (is.null(best_method) || !best_method %in% active_methods) {
    # Score each method: +1 for each metric where it is best
    scores <- setNames(rep(0L, length(active_methods)), active_methods)
    metric_wins <- list()

    # Silhouette - higher is better
    sil_vals <- vapply(active_methods, function(m) {
      method_html_data[[m]]$diagnostics$avg_silhouette %||% NA_real_
    }, numeric(1))

    if (any(!is.na(sil_vals))) {
      best_m <- active_methods[which.max(sil_vals)]
      scores[best_m] <- scores[best_m] + 1L
      metric_wins <- c(metric_wins, list(sprintf(
        "Highest silhouette score (%.3f)", max(sil_vals, na.rm = TRUE)
      )))
    }

    # BSS/TSS - higher is better
    bss_vals <- vapply(active_methods, function(m) {
      method_html_data[[m]]$diagnostics$betweenss_totss %||% NA_real_
    }, numeric(1))

    if (any(!is.na(bss_vals))) {
      best_m <- active_methods[which.max(bss_vals)]
      scores[best_m] <- scores[best_m] + 1L
    }

    # Min segment size - larger is better (more balanced)
    min_sizes <- vapply(active_methods, function(m) {
      sizes <- method_html_data[[m]]$segment_sizes
      if (!is.null(sizes) && nrow(sizes) > 0) min(sizes$n) else NA_real_
    }, numeric(1))

    if (any(!is.na(min_sizes))) {
      best_m <- active_methods[which.max(min_sizes)]
      scores[best_m] <- scores[best_m] + 1L
    }

    best_method <- active_methods[which.max(scores)]
    if (is.null(reason_text)) {
      reason_text <- sprintf(
        "Best results across %d of %d comparison metrics. Review the per-method tabs for detailed validation before making a final selection.",
        max(scores), length(active_methods)
      )
    }
    ext_scores <- as.list(scores)
  }

  # --- Build the best-method label ---
  best_label <- switch(tolower(best_method),
    kmeans = "K-Means", pam = "PAM", hclust = "Hierarchical",
    gmm = "GMM", mclust = "GMM", lca = "Latent Class", toupper(best_method)
  )

  # --- Determine quality tier from silhouette of best method ---
  best_sil <- method_html_data[[best_method]]$diagnostics$avg_silhouette %||% NA_real_
  if (!is.na(best_sil)) {
    if (best_sil >= 0.50) {
      quality_class <- "seg-quality-excellent"
    } else if (best_sil >= 0.35) {
      quality_class <- "seg-quality-good"
    } else if (best_sil >= 0.25) {
      quality_class <- "seg-quality-moderate"
    } else {
      quality_class <- "seg-quality-limited"
    }
  } else {
    quality_class <- "seg-quality-good"
  }

  # --- Build prominent Best Fit banner ---
  # Title line
  banner_title <- htmltools::tags$div(
    style = "font-size: 22px; font-weight: 700; margin-bottom: 6px; color: #1e293b;",
    sprintf("Best Fit: %s", best_label)
  )

  # Reason / explanation
  banner_reason <- NULL
  if (!is.null(reason_text) && nzchar(reason_text)) {
    banner_reason <- htmltools::tags$div(
      style = "font-size: 14px; color: #334155; line-height: 1.6; margin-bottom: 0;",
      reason_text
    )
  }

  # Score breakdown (if scores available)
  score_chips <- NULL
  if (!is.null(ext_scores) && length(ext_scores) > 0) {
    chip_els <- lapply(names(ext_scores), function(m) {
      m_label <- switch(tolower(m),
        kmeans = "K-Means", pam = "PAM", hclust = "Hierarchical",
        gmm = "GMM", mclust = "GMM", lca = "Latent Class", toupper(m)
      )
      sc <- ext_scores[[m]]
      is_best <- (tolower(m) == tolower(best_method))
      chip_style <- if (is_best) {
        sprintf("display:inline-block; padding:4px 12px; border-radius:12px; font-size:12px; font-weight:600; margin-right:8px; margin-top:8px; background:%s; color:white;", accent_colour)
      } else {
        "display:inline-block; padding:4px 12px; border-radius:12px; font-size:12px; font-weight:500; margin-right:8px; margin-top:8px; background:#f1f5f9; color:#64748b;"
      }
      htmltools::tags$span(
        style = chip_style,
        sprintf("%s: %s", m_label, as.character(sc))
      )
    })
    score_chips <- htmltools::tags$div(style = "margin-top: 4px;", chip_els)
  }

  htmltools::tags$div(
    class = paste("seg-quality-banner", quality_class),
    style = "padding: 20px 24px; margin-bottom: 24px;",
    banner_title,
    banner_reason,
    score_chips
  )
}


# ==============================================================================
# COMPARISON BUILDERS
# ==============================================================================


#' Build Method Comparison Table
#'
#' Creates a table comparing key metrics across all methods. The best
#' value for each metric is highlighted with the accent colour.
#'
#' @param method_html_data Named list of transformed html_data per method
#' @return htmltools tag or NULL
#' @keywords internal
build_seg_method_comparison_table <- function(method_html_data) {

  active_methods <- names(method_html_data)
  if (length(active_methods) < 2) return(NULL)

  method_labels <- vapply(active_methods, function(m) {
    switch(tolower(m),
      kmeans = "K-Means", pam = "PAM", hclust = "Hierarchical",
      gmm = "GMM", mclust = "GMM", lca = "Latent Class", toupper(m)
    )
  }, character(1))

  # Extract metrics for each method
  metrics <- lapply(active_methods, function(m) {
    hd <- method_html_data[[m]]
    diag <- hd$diagnostics
    sizes <- hd$segment_sizes

    list(
      method = method_labels[m],
      avg_silhouette = diag$avg_silhouette %||% NA_real_,
      betweenss_totss = diag$betweenss_totss %||% NA_real_,
      ch_index = diag$ch_index %||% NA_real_,
      min_segment_n = if (!is.null(sizes) && nrow(sizes) > 0) min(sizes$n) else NA_real_,
      min_segment_pct = if (!is.null(sizes) && nrow(sizes) > 0) min(sizes$pct) else NA_real_
    )
  })

  # Find best values (higher is better for all except min segment which is also higher = better)
  best_sil <- .find_best_index(metrics, "avg_silhouette", higher = TRUE)
  best_bss <- .find_best_index(metrics, "betweenss_totss", higher = TRUE)
  best_ch <- .find_best_index(metrics, "ch_index", higher = TRUE)
  best_min <- .find_best_index(metrics, "min_segment_n", higher = TRUE)

  # Header row
  header <- htmltools::tags$tr(
    htmltools::tags$th("Method"),
    htmltools::tags$th("Avg Silhouette"),
    htmltools::tags$th("BSS/TSS"),
    htmltools::tags$th("CH Index"),
    htmltools::tags$th("Min Segment"),
    htmltools::tags$th("Min %")
  )

  # Data rows
  rows <- lapply(seq_along(metrics), function(i) {
    met <- metrics[[i]]

    sil_class <- if (i == best_sil) "seg-comparison-best" else ""
    bss_class <- if (i == best_bss) "seg-comparison-best" else ""
    ch_class <- if (i == best_ch) "seg-comparison-best" else ""
    min_class <- if (i == best_min) "seg-comparison-best" else ""

    htmltools::tags$tr(
      htmltools::tags$td(
        style = "font-weight:600;",
        met$method
      ),
      htmltools::tags$td(
        class = sil_class,
        style = "font-family:monospace;",
        if (!is.na(met$avg_silhouette)) sprintf("%.3f", met$avg_silhouette) else "-"
      ),
      htmltools::tags$td(
        class = bss_class,
        style = "font-family:monospace;",
        if (!is.na(met$betweenss_totss)) sprintf("%.0f%%", met$betweenss_totss * 100) else "-"
      ),
      htmltools::tags$td(
        class = ch_class,
        style = "font-family:monospace;",
        if (!is.na(met$ch_index)) sprintf("%.1f", met$ch_index) else "-"
      ),
      htmltools::tags$td(
        class = min_class,
        style = "font-family:monospace;",
        if (!is.na(met$min_segment_n)) format(as.integer(met$min_segment_n), big.mark = ",") else "-"
      ),
      htmltools::tags$td(
        style = "font-family:monospace;",
        if (!is.na(met$min_segment_pct)) sprintf("%.0f%%", met$min_segment_pct) else "-"
      )
    )
  })

  htmltools::tags$table(
    class = "seg-comparison-table",
    htmltools::tags$thead(header),
    htmltools::tags$tbody(rows)
  )
}


#' Find Best Index for a Metric
#'
#' Returns the 1-based index of the method with the best value for a metric.
#'
#' @param metrics List of metric lists
#' @param field Character, the metric field name
#' @param higher Logical, TRUE if higher values are better
#' @return Integer index, or NA if all values are NA
#' @keywords internal
.find_best_index <- function(metrics, field, higher = TRUE) {
  vals <- vapply(metrics, function(m) {
    v <- m[[field]]
    if (is.null(v) || is.na(v)) NA_real_ else as.numeric(v)
  }, numeric(1))

  if (all(is.na(vals))) return(NA_integer_)

  if (higher) which.max(vals) else which.min(vals)
}


#' Build Method Comparison Chart
#'
#' SVG horizontal bar chart comparing average silhouette scores across methods.
#'
#' @param method_html_data Named list of transformed html_data per method
#' @param brand_colour Brand colour hex string
#' @return htmltools::HTML string containing SVG, or NULL
#' @keywords internal
build_seg_method_comparison_chart <- function(method_html_data,
                                               brand_colour = "#323367") {

  active_methods <- names(method_html_data)
  if (length(active_methods) < 2) return(NULL)

  method_labels <- vapply(active_methods, function(m) {
    switch(tolower(m),
      kmeans = "K-Means", pam = "PAM", hclust = "Hierarchical",
      gmm = "GMM", mclust = "GMM", lca = "Latent Class", toupper(m)
    )
  }, character(1))

  sil_vals <- vapply(active_methods, function(m) {
    method_html_data[[m]]$diagnostics$avg_silhouette %||% NA_real_
  }, numeric(1))

  # Filter out NA values
  valid_idx <- which(!is.na(sil_vals))
  if (length(valid_idx) == 0) return(NULL)

  labels <- method_labels[valid_idx]
  values <- sil_vals[valid_idx]

  n <- length(labels)
  bar_height <- 36
  gap <- 12
  label_width <- 140
  chart_width <- 550
  bar_area_width <- chart_width - label_width - 100
  total_height <- n * (bar_height + gap) + 30

  max_val <- max(values, 0.5, na.rm = TRUE)

  # Reference lines at 0.25 and 0.50
  ref_lines <- ""
  for (ref in c(0.25, 0.50)) {
    if (ref <= max_val * 1.15) {
      x_pos <- label_width + (ref / max(max_val * 1.15, 0.01)) * bar_area_width
      ref_lines <- paste0(ref_lines, sprintf(
        '<line x1="%.1f" y1="15" x2="%.1f" y2="%.0f" stroke="#e2e8f0" stroke-width="1" stroke-dasharray="4,3"/>\n',
        x_pos, x_pos, total_height - 5
      ))
      ref_lines <- paste0(ref_lines, sprintf(
        '<text x="%.1f" y="12" text-anchor="middle" font-size="10" font-family="\'Segoe UI\', Arial, sans-serif" fill="#94a3b8" font-weight="400">%.2f</text>\n',
        x_pos, ref
      ))
    }
  }

  # Bars
  bars <- ""
  best_idx <- which.max(values)

  for (i in seq_len(n)) {
    y <- 20 + (i - 1) * (bar_height + gap)
    bar_w <- max(2, (values[i] / max(max_val * 1.15, 0.01)) * bar_area_width)

    # Colour: brand for best, lighter for others
    bar_colour <- if (i == best_idx) brand_colour else "#94a3b8"
    opacity <- if (i == best_idx) 1.0 else 0.65

    # Label
    bars <- paste0(bars, sprintf(
      '<text x="%.0f" y="%.1f" text-anchor="end" font-size="13" font-family="\'Segoe UI\', Arial, sans-serif" fill="#334155" font-weight="%s" dominant-baseline="central">%s</text>\n',
      label_width - 10, y + bar_height / 2,
      if (i == best_idx) "600" else "400",
      htmltools::htmlEscape(labels[i])
    ))

    # Bar
    bars <- paste0(bars, sprintf(
      '<rect x="%.0f" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="%.2f"/>\n',
      label_width, y, bar_w, bar_height, bar_colour, opacity
    ))

    # Value label
    bars <- paste0(bars, sprintf(
      '<text x="%.1f" y="%.1f" font-size="12" font-family="\'Segoe UI\', Arial, sans-serif" fill="#334155" font-weight="500" dominant-baseline="central">%.3f</text>\n',
      label_width + bar_w + 8, y + bar_height / 2, values[i]
    ))
  }

  svg <- sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %.0f" class="seg-chart seg-comparison-silhouette-chart" role="img" aria-label="Method comparison silhouette chart">\n%s\n%s\n</svg>',
    chart_width, total_height, ref_lines, bars
  )

  htmltools::HTML(svg)
}


#' Build Agreement Matrix
#'
#' Calculates the Adjusted Rand Index (ARI) between every pair of methods
#' and displays the result as a matrix table. Falls back to simple
#' percentage agreement if ARI computation is not available.
#'
#' @param method_results Named list of per-method results (from results$method_results)
#' @param active_methods Character vector of method names to include
#' @return htmltools tag or NULL
#' @keywords internal
build_seg_agreement_matrix <- function(method_results, active_methods) {

  if (length(active_methods) < 2) return(NULL)

  method_labels <- vapply(active_methods, function(m) {
    switch(tolower(m),
      kmeans = "K-Means", pam = "PAM", hclust = "Hierarchical",
      gmm = "GMM", mclust = "GMM", lca = "Latent Class", toupper(m)
    )
  }, character(1))

  # Extract cluster assignments
  assignments <- list()
  for (m in active_methods) {
    mr <- method_results[[m]]
    clusters <- mr$cluster_result$clusters %||% NULL
    if (is.null(clusters)) {
      clusters <- mr$clusters %||% NULL
    }
    if (!is.null(clusters)) {
      assignments[[m]] <- as.integer(clusters)
    }
  }

  valid_methods <- intersect(active_methods, names(assignments))
  if (length(valid_methods) < 2) return(NULL)

  # Ensure all assignment vectors have the same length
  n_obs <- unique(vapply(assignments[valid_methods], length, integer(1)))
  if (length(n_obs) != 1) {
    # Different lengths - cannot compare
    return(htmltools::tags$div(
      class = "seg-combined-section-desc",
      style = "color:#dc2626;",
      "Cannot compute agreement: methods have different numbers of observations."
    ))
  }

  # Compute pairwise ARI
  n_methods <- length(valid_methods)
  ari_matrix <- matrix(NA_real_, nrow = n_methods, ncol = n_methods,
                        dimnames = list(valid_methods, valid_methods))

  for (i in seq_len(n_methods)) {
    ari_matrix[i, i] <- 1.0
    if (i < n_methods) {
      for (j in (i + 1):n_methods) {
        ari_val <- .compute_adjusted_rand_index(
          assignments[[valid_methods[i]]],
          assignments[[valid_methods[j]]]
        )
        ari_matrix[i, j] <- ari_val
        ari_matrix[j, i] <- ari_val
      }
    }
  }

  # Build HTML table
  valid_labels <- method_labels[match(valid_methods, active_methods)]

  # Header row
  header_cells <- list(htmltools::tags$th(""))
  for (lbl in valid_labels) {
    header_cells <- c(header_cells, list(htmltools::tags$th(lbl)))
  }
  header_row <- htmltools::tags$tr(header_cells)

  # Data rows
  rows <- lapply(seq_len(n_methods), function(i) {
    cells <- list(htmltools::tags$td(
      style = "font-weight:600; text-align:left;",
      valid_labels[i]
    ))

    for (j in seq_len(n_methods)) {
      val <- ari_matrix[i, j]

      if (i == j) {
        cell_class <- "seg-agreement-cell-self"
        cell_text <- "-"
      } else if (is.na(val)) {
        cell_class <- ""
        cell_text <- "N/A"
      } else {
        cell_class <- if (val >= 0.65) "seg-agreement-cell-high"
                      else if (val >= 0.35) "seg-agreement-cell-medium"
                      else "seg-agreement-cell-low"
        cell_text <- sprintf("%.3f", val)
      }

      cells <- c(cells, list(htmltools::tags$td(class = cell_class, cell_text)))
    }

    htmltools::tags$tr(cells)
  })

  htmltools::tags$table(
    class = "seg-agreement-table",
    htmltools::tags$thead(header_row),
    htmltools::tags$tbody(rows)
  )
}


#' Compute Adjusted Rand Index
#'
#' Calculates the Adjusted Rand Index (ARI) between two integer cluster
#' assignment vectors. Uses the formula based on the contingency table
#' of the two partitions. ARI ranges from -0.5 to 1.0, where 1.0 means
#' identical partitions and 0.0 means agreement no better than random.
#'
#' @param labels1 Integer vector of cluster assignments from method 1
#' @param labels2 Integer vector of cluster assignments from method 2
#' @return Numeric ARI value, or NA if computation fails
#' @keywords internal
.compute_adjusted_rand_index <- function(labels1, labels2) {

  if (length(labels1) != length(labels2)) return(NA_real_)
  n <- length(labels1)
  if (n < 2) return(NA_real_)

  # Build contingency table
  tab <- table(labels1, labels2)

  # Sum of combinations
  sum_nij_c2 <- sum(choose(tab, 2))

  # Row and column sums
  a_i <- rowSums(tab)
  b_j <- colSums(tab)

  sum_ai_c2 <- sum(choose(a_i, 2))
  sum_bj_c2 <- sum(choose(b_j, 2))

  n_c2 <- choose(n, 2)

  if (n_c2 == 0) return(NA_real_)

  expected <- (sum_ai_c2 * sum_bj_c2) / n_c2
  max_index <- (sum_ai_c2 + sum_bj_c2) / 2

  if (max_index == expected) return(1.0)

  ari <- (sum_nij_c2 - expected) / (max_index - expected)

  ari
}


# ==============================================================================
# TAB SWITCHING JAVASCRIPT
# ==============================================================================


#' Build Combined Report JavaScript
#'
#' Returns inline JavaScript for tab switching.
#'
#' @return Character string of JavaScript code
#' @keywords internal
.build_seg_combined_js <- function() {
  '
/* ==== Segment Combined Report - Tab Switching ==== */
document.addEventListener("DOMContentLoaded", function() {
  var tabs = document.querySelectorAll(".seg-method-tab");
  var panels = document.querySelectorAll(".seg-method-panel");

  tabs.forEach(function(tab) {
    tab.addEventListener("click", function() {
      var method = this.getAttribute("data-method");

      // Update active tab
      tabs.forEach(function(t) {
        t.classList.remove("seg-method-tab-active");
      });
      this.classList.add("seg-method-tab-active");

      // Show/hide panels
      panels.forEach(function(p) {
        if (p.getAttribute("data-method") === method) {
          p.classList.add("seg-method-panel-visible");
        } else {
          p.classList.remove("seg-method-panel-visible");
        }
      });
    });
  });
});
'
}
