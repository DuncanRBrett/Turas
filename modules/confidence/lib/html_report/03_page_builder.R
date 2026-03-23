# ==============================================================================
# CONFIDENCE HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles the complete HTML page: CSS, header, tabs, content, JS.
# Self-contained — no external dependencies.
# Uses gsub() token replacement for colours (avoids sprintf 8192 limit).
# ==============================================================================

# Source the shared design system (TURAS_ROOT-aware)
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()
  ds_dir <- file.path(turas_root, "modules", "shared", "lib", "design_system")
  if (!dir.exists(ds_dir)) ds_dir <- file.path("modules", "shared", "lib", "design_system")
  if (!exists("turas_base_css", mode = "function") && dir.exists(ds_dir)) {
    source(file.path(ds_dir, "design_tokens.R"), local = FALSE)
    source(file.path(ds_dir, "font_embed.R"), local = FALSE)
    source(file.path(ds_dir, "base_css.R"), local = FALSE)
  }
  # Source callout registry
  callout_dir <- file.path(turas_root, "modules", "shared", "lib", "callouts")
  if (!dir.exists(callout_dir)) callout_dir <- file.path("modules", "shared", "lib", "callouts")
  if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
    source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
  }
})

# Null-coalescing operator (canonical definition in utils.R)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' Build Complete Confidence Report HTML Page
#'
#' @param html_data List from transform_confidence_for_html()
#' @param tables List of HTML table strings
#' @param charts List of HTML chart strings
#' @param config List with brand_colour, accent_colour, logo, etc.
#' @param source_filename Character base filename for Save
#' @return Character string of complete HTML document
#' @keywords internal
build_confidence_page <- function(html_data, tables, charts, config,
                                   source_filename = "Confidence_Report",
                                   labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")

  # Robust colour extraction: handle NULL, NA, and empty strings
  brand <- config$brand_colour %||% "#1e3a5f"
  if (is.na(brand) || !nzchar(trimws(brand))) brand <- "#1e3a5f"
  accent <- config$accent_colour %||% "#2aa198"
  if (is.na(accent) || !nzchar(trimws(accent))) accent <- "#2aa198"

  meta_tags <- build_ci_meta_tags(html_data$summary, source_filename)
  css <- build_ci_css(brand, accent)
  header <- build_ci_header(html_data$summary, brand, config, labels = labels)
  nav <- build_ci_tab_nav()
  help_overlay <- build_ci_help_overlay()
  summary_panel <- build_ci_summary_panel(html_data, tables, charts, labels = labels)
  details_panel <- build_ci_details_panel(html_data, tables, charts, brand, labels = labels)
  notes_panel <- build_ci_notes_panel(html_data, config)
  footer <- build_ci_footer()
  js <- build_ci_js()

  paste0(
    '<!DOCTYPE html>\n<html lang="en">\n<head>\n',
    '<meta charset="UTF-8">\n',
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n',
    meta_tags, '\n',
    sprintf('<title>%s</title>\n', htmlEscape(labels$report_title)),
    '<style>\n', css, '\n</style>\n',
    '</head>\n<body>\n',
    header, '\n',
    nav, '\n',
    help_overlay, '\n',
    '<div class="ci-content">\n',
    summary_panel, '\n',
    details_panel, '\n',
    notes_panel, '\n',
    '</div>\n',
    footer, '\n',
    '<script>\n', js, '\n</script>\n',
    '</body>\n</html>'
  )
}


# ==============================================================================
# META TAGS
# ==============================================================================

build_ci_meta_tags <- function(summary, source_filename) {
  paste0(
    '<meta name="turas-report-type" content="confidence">\n',
    '<meta name="turas-generated" content="', summary$generated, '">\n',
    '<meta name="turas-total-n" content="', summary$n_total %||% "", '">\n',
    '<meta name="turas-questions" content="', summary$n_questions %||% 0, '">\n',
    '<meta name="turas-confidence-level" content="', summary$confidence_level, '">\n',
    '<meta name="turas-weighted" content="', if (summary$is_weighted) "Yes" else "No", '">\n',
    '<meta name="turas-sampling-method" content="', summary$sampling_method %||% "Not_Specified", '">\n',
    '<meta name="turas-source-filename" content="', source_filename, '">'
  )
}


# ==============================================================================
# CSS
# ==============================================================================

build_ci_css <- function(brand, accent) {
  shared_css <- tryCatch(turas_base_css(brand, accent, prefix = "ci"), error = function(e) "")
  css <- '
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --ci-brand: BRAND;
  --ci-accent: ACCENT;
  --ci-text-primary: #1e293b;
  --ci-text-secondary: #64748b;
  --ci-text-tertiary: #94a3b8;
  --ci-bg-surface: #ffffff;
  --ci-bg-muted: #f8f9fa;
  --ci-bg-page: #f8f7f5;
  --ci-border: #e2e8f0;
  --ci-border-light: #f1f5f9;
  --ci-radius: 10px;
  --ci-radius-sm: 6px;
  --ci-shadow-card: 0 1px 3px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.03);
  --ci-shadow-hover: 0 4px 12px rgba(0,0,0,0.07);
  --ci-transition: 0.2s ease;
}
body {
  font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  background: var(--ci-bg-page);
  color: var(--ci-text-primary);
  line-height: 1.6;
  font-size: 14px;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* Header */
.ci-header {
  background: linear-gradient(135deg, #1a2744 0%, #2a3f5f 60%, #1e3a5f 100%);
  border-bottom: 3px solid BRAND;
  padding: 28px 32px 24px;
}
.ci-header-inner {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: 24px;
}
.ci-header-logo {
  width: 56px; height: 56px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.ci-header-text { flex: 1; }
.ci-header-title {
  color: #fff; font-size: 22px; font-weight: 700;
  letter-spacing: -0.3px;
}
.ci-header-subtitle {
  color: rgba(255,255,255,0.45); font-size: 11px; font-weight: 500;
  text-transform: uppercase; letter-spacing: 0.5px; margin-top: 2px;
}
.ci-header-project {
  color: #fff; font-size: 18px; font-weight: 600; margin-top: 6px;
  letter-spacing: -0.2px;
}
.ci-header-prepared {
  color: rgba(255,255,255,0.6); font-size: 13px; font-weight: 400; margin-top: 4px;
}
.ci-header-badges {
  display: inline-flex; align-items: center;
  margin-top: 14px;
  border: 1px solid rgba(255,255,255,0.12);
  border-radius: var(--ci-radius-sm);
  background: rgba(255,255,255,0.04);
  overflow: hidden;
}
.ci-badge {
  padding: 5px 14px;
  color: rgba(255,255,255,0.8);
  font-size: 11px;
  font-weight: 600;
  white-space: nowrap;
  letter-spacing: 0.2px;
}
.ci-badge-sep {
  width: 1px; height: 16px;
  background: rgba(255,255,255,0.15);
}
#ci-save-badge {
  display: none;
  padding: 6px 14px;
  color: rgba(255,255,255,0.85);
  font-size: 12px;
  font-weight: 500;
}

/* Tab Navigation */
.report-tabs {
  display: flex; align-items: center;
  background: #fff;
  border-bottom: 1px solid var(--ci-border);
  padding: 0 24px;
  max-width: 1200px;
  margin: 0 auto;
  box-shadow: 0 1px 2px rgba(0,0,0,0.02);
}
.report-tab {
  padding: 14px 24px;
  border: none; background: transparent;
  color: var(--ci-text-secondary);
  font-size: 13px; font-weight: 600;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  transition: all var(--ci-transition);
  font-family: inherit;
  letter-spacing: 0.1px;
}
.report-tab:hover:not(.active) {
  color: var(--ci-text-primary);
  background: #fafbfc;
}
.report-tab.active {
  color: BRAND;
  border-bottom-color: BRAND;
}
.ci-save-tab {
  margin-left: auto;
  color: BRAND;
  border-bottom-color: transparent !important;
}
.ci-save-tab:hover { background: #f0f9ff; }

/* Help button */
.ci-help-btn {
  width: 26px; height: 26px; border-radius: 50%;
  border: 1.5px solid #cbd5e1; background: transparent;
  color: #64748b; font-size: 13px; font-weight: 700;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  margin-left: 8px; flex-shrink: 0;
  transition: all var(--ci-transition);
}
.ci-help-btn:hover { border-color: BRAND; color: BRAND; background: #f0f9ff; }

/* Help overlay */
.ci-help-overlay {
  display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.6); z-index: 9999; cursor: pointer;
}
.ci-help-overlay.active { display: flex; align-items: center; justify-content: center; }
.ci-help-card {
  background: #fff; border-radius: 12px; padding: 28px 32px; max-width: 640px; width: 92%;
  max-height: 85vh; overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3); cursor: default;
}
.ci-help-card h2 { font-size: 20px; margin-bottom: 4px; color: BRAND; }
.ci-help-card .help-subtitle { font-size: 12px; color: #94a3b8; margin-bottom: 20px; }
.ci-help-card h3 {
  font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px;
  color: #94a3b8; margin: 18px 0 8px; padding-top: 14px; border-top: 1px solid #f1f5f9;
}
.ci-help-card h3:first-of-type { border-top: none; padding-top: 0; margin-top: 8px; }
.ci-help-card ul { list-style: none; padding: 0; margin: 0; }
.ci-help-card li { padding: 5px 0; font-size: 13px; color: #374151; line-height: 1.4; }
.ci-help-card .help-key {
  display: inline-block; background: #f1f5f9; border-radius: 4px;
  padding: 2px 8px; font-weight: 600; color: BRAND; margin-right: 8px;
  font-size: 11px; min-width: 110px; text-align: center;
}
.ci-help-card .help-dismiss { margin-top: 18px; text-align: center; color: #94a3b8; font-size: 12px; }

/* Content */
.ci-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: 24px;
}
.tab-panel { display: none; }
.tab-panel.active { display: block; }

/* Cards */
.ci-card {
  background: var(--ci-bg-surface);
  border-radius: var(--ci-radius);
  border: 1px solid var(--ci-border);
  padding: 28px;
  margin-bottom: 24px;
  box-shadow: var(--ci-shadow-card);
}
.ci-card h3 {
  font-size: 15px; font-weight: 700;
  color: var(--ci-text-primary);
  margin-bottom: 18px;
  padding-bottom: 10px;
  border-bottom: 2px solid BRAND;
  letter-spacing: -0.2px;
}

/* Dynamic Callouts (per-question, data-driven) */
.ci-callout {
  border-radius: var(--ci-radius-sm);
  padding: 14px 18px;
  margin-bottom: 16px;
  font-size: 13px;
  line-height: 1.7;
  color: #334155;
  background: #f0f7ff;
  border: 1px solid #dbeafe;
  border-left: 3px solid BRAND;
}
.ci-callout strong { color: #1e293b; }

.ci-callout-warning {
  background: #fff7ed;
  border: 1px solid #fed7aa;
  border-left: 3px solid #f59e0b;
}
.ci-callout-result {
  background: linear-gradient(135deg, #f0f7ff 0%, #f8fbff 100%);
  border: 1px solid #dbeafe;
  border-left: 3px solid BRAND;
  margin-bottom: 10px;
}
.ci-callout-method {
  background: #f8fafc;
  border: 1px solid #e8ecf1;
  border-left: 3px solid #94a3b8;
  margin-bottom: 10px;
  font-size: 12px;
  color: #475569;
}
.ci-callout-method p { margin: 0 0 8px 0; }
.ci-callout-method p:last-child { margin-bottom: 0; }
.ci-callout-sampling {
  background: linear-gradient(135deg, #fffbeb 0%, #fffef5 100%);
  border: 1px solid #fde68a;
  border-left: 3px solid #d4a853;
  font-size: 12px;
  color: #78350f;
}

/* Registry Callouts (t-callout from shared design system) */
.t-callout { margin-bottom: 18px; }
.ci-card .t-callout:last-child { margin-bottom: 0; }

/* Tables */
.ci-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
  margin-bottom: 16px;
  border-radius: var(--ci-radius-sm);
  overflow: hidden;
}
.ci-table thead th {
  background: #f8f9fb;
  padding: 12px 16px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  color: var(--ci-text-secondary);
  border-bottom: 2px solid var(--ci-border);
  text-align: left;
}
.ci-table tbody td {
  padding: 10px 16px;
  border-bottom: 1px solid var(--ci-border-light);
  vertical-align: middle;
  transition: background-color 0.15s ease;
}
.ci-table tbody tr:hover { background: #eef2f7; }
.ci-table tbody tr:last-child td { border-bottom: 1px solid var(--ci-border); }
.ci-num {
  text-align: right;
  font-variant-numeric: tabular-nums;
  font-weight: 500;
}
.ci-table thead th.ci-num {
  text-align: right;
}
.ci-label-col { font-weight: 600; color: var(--ci-text-primary); }
.ci-table-compact { font-size: 12px; }
.ci-table-compact td { padding: 8px 12px; }
.ci-row-highlight { background: #f8f9fa; }

/* Quality Badges */
.ci-quality-good {
  color: #059669; font-weight: 700;
  background: #ecfdf5; padding: 2px 8px; border-radius: 4px;
  font-size: 11px; text-transform: uppercase; letter-spacing: 0.3px;
  display: inline-block;
}
.ci-quality-warn {
  color: #d97706; font-weight: 700;
  background: #fffbeb; padding: 2px 8px; border-radius: 4px;
  font-size: 11px; text-transform: uppercase; letter-spacing: 0.3px;
  display: inline-block;
}
.ci-quality-poor {
  color: #dc2626; font-weight: 700;
  background: #fef2f2; padding: 2px 8px; border-radius: 4px;
  font-size: 11px; text-transform: uppercase; letter-spacing: 0.3px;
  display: inline-block;
}
.ci-diff-good { color: #059669; font-weight: 600; }
.ci-diff-warn { color: #d97706; font-weight: 600; }
.ci-diff-poor { color: #dc2626; font-weight: 600; }

/* Question Navigation (Details Tab) */
.ci-nav {
  display: flex; flex-wrap: wrap; gap: 8px;
  margin-bottom: 24px;
  padding: 16px 20px;
  background: var(--ci-bg-surface);
  border-radius: var(--ci-radius);
  border: 1px solid var(--ci-border);
  box-shadow: var(--ci-shadow-card);
}
.ci-nav-btn {
  padding: 8px 18px;
  border: 1px solid var(--ci-border);
  border-radius: 20px;
  background: var(--ci-bg-surface);
  color: var(--ci-text-secondary);
  font-size: 12px; font-weight: 600;
  cursor: pointer;
  transition: all var(--ci-transition);
  font-family: inherit;
  letter-spacing: 0.1px;
}
.ci-nav-btn:hover {
  background: #f0f7ff;
  border-color: BRAND;
  color: BRAND;
}
.ci-nav-btn.active {
  background: BRAND; color: #fff;
  border-color: BRAND;
  box-shadow: 0 2px 4px rgba(30,58,95,0.2);
}
.ci-detail-panel { display: none; }
.ci-detail-panel.active { display: block; }

/* Comments */
.ci-comments-box {
  width: 100%;
  min-height: 120px;
  padding: 14px 18px;
  border: 1px solid var(--ci-border);
  border-radius: var(--ci-radius-sm);
  font-family: inherit;
  font-size: 14px;
  line-height: 1.6;
  color: var(--ci-text-primary);
  background: #fff;
  resize: vertical;
  transition: border-color var(--ci-transition), box-shadow var(--ci-transition);
}
.ci-comments-box:focus {
  outline: none;
  border-color: BRAND;
  box-shadow: 0 0 0 3px rgba(30,58,95,0.08);
}

/* Footer */
.ci-footer {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px 24px;
  text-align: center;
  font-size: 11px;
  color: var(--ci-text-tertiary);
  border-top: 1px solid var(--ci-border);
}

/* Stats row */
.ci-stats-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}
.ci-stat-card {
  background: var(--ci-bg-surface);
  border: 1px solid var(--ci-border);
  border-top: 3px solid BRAND;
  border-radius: var(--ci-radius);
  padding: 20px 16px;
  text-align: center;
  box-shadow: var(--ci-shadow-card);
  transition: box-shadow var(--ci-transition);
}
.ci-stat-card:hover {
  box-shadow: var(--ci-shadow-hover);
}
.ci-stat-value {
  font-size: 32px; font-weight: 700;
  color: BRAND;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.5px;
  line-height: 1.2;
}
.ci-stat-label {
  font-size: 11px; font-weight: 600;
  color: var(--ci-text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-top: 6px;
}

/* Method docs */
.ci-method-doc {
  background: var(--ci-bg-surface);
  border: 1px solid var(--ci-border);
  border-left: 3px solid var(--ci-text-tertiary);
  border-radius: 0 var(--ci-radius-sm) var(--ci-radius-sm) 0;
  padding: 20px 24px;
  margin-bottom: 16px;
  transition: border-left-color var(--ci-transition);
}
.ci-method-doc:hover {
  border-left-color: BRAND;
}
.ci-method-doc h4 {
  font-size: 14px; font-weight: 700;
  color: var(--ci-text-primary);
  margin-bottom: 10px;
  letter-spacing: -0.1px;
}
.ci-method-doc p {
  font-size: 13px; line-height: 1.7;
  color: #475569;
  margin-bottom: 10px;
}
.ci-method-doc p:last-child { margin-bottom: 0; }

/* Print */
@media print {
  body { background: #fff; }
  .report-tabs, .ci-save-tab, .ci-nav, .ci-comments-box, .ci-help-overlay, .ci-help-btn { display: none !important; }
  .tab-panel { display: block !important; page-break-inside: avoid; }
  .ci-detail-panel { display: block !important; }
  .ci-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .ci-card { box-shadow: none; border: 1px solid #ddd; break-inside: avoid; }
  .ci-stat-card { box-shadow: none; border-top-color: #999; }
  .t-callout { break-inside: avoid; }
}

/* Question Meta Bar */
.ci-question-meta {
  display: flex; align-items: center; gap: 16px; flex-wrap: wrap;
  padding: 12px 16px;
  background: #f8f9fb;
  border-radius: var(--ci-radius-sm);
  margin-bottom: 16px;
  font-size: 13px;
}
.ci-question-meta strong { font-weight: 600; }
'

  # Token replacement (avoids sprintf 8192 char limit)
  css <- gsub("BRAND", brand, css, fixed = TRUE)
  css <- gsub("ACCENT", accent, css, fixed = TRUE)
  paste0(shared_css, "\n", css)
}


# ==============================================================================
# HEADER
# ==============================================================================

build_ci_header <- function(summary, brand, config, labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  # Logo: custom or fallback SVG checkmark
  logo_html <- '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="40" height="40"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>'

  if (!is.null(config$logo_file) && file.exists(config$logo_file)) {
    tryCatch({
      ext <- tolower(tools::file_ext(config$logo_file))
      mime <- switch(ext, png = "image/png", jpg = "image/jpeg",
                     jpeg = "image/jpeg", svg = "image/svg+xml", "image/png")
      b64 <- base64enc::base64encode(config$logo_file)
      logo_html <- sprintf(
        '<img src="data:%s;base64,%s" alt="Logo" style="max-width:40px; max-height:40px; object-fit:contain;"/>',
        mime, b64
      )
    }, error = function(e) NULL)
  }

  # Prepared by/for
  prepared <- ""
  researcher <- config$researcher_name %||% config$company_name %||% ""
  client <- config$client_name %||% ""
  if (nzchar(researcher) && nzchar(client)) {
    prepared <- sprintf('<div class="ci-header-prepared">Prepared by %s for %s</div>',
                         htmlEscape(researcher), htmlEscape(client))
  } else if (nzchar(researcher)) {
    prepared <- sprintf('<div class="ci-header-prepared">Prepared by %s</div>',
                         htmlEscape(researcher))
  } else if (nzchar(client)) {
    prepared <- sprintf('<div class="ci-header-prepared">Prepared for %s</div>',
                         htmlEscape(client))
  }

  # Badges (using separator divs matching weighting module pattern)
  sep <- '<div class="ci-badge-sep"></div>'
  badge_items <- character()
  if (!is.na(summary$n_total)) {
    badge_items <- c(badge_items, sprintf('<span class="ci-badge">n = %s</span>',
                                 format(summary$n_total, big.mark = ",")))
  }
  badge_items <- c(badge_items, sprintf('<span class="ci-badge">%d Questions</span>', summary$n_questions))
  badge_items <- c(badge_items, sprintf(
    paste0('<span class="ci-badge">', labels$badge_text_fmt, '</span>'),
    round(summary$confidence_level * 100)))
  if (summary$is_weighted) {
    badge_items <- c(badge_items, '<span class="ci-badge">Weighted</span>')
  }
  # Sampling method badge (skip if Not_Specified)
  sm <- summary$sampling_method %||% "Not_Specified"
  if (!is.na(sm) && nzchar(sm) && sm != "Not_Specified") {
    sm_label <- switch(sm,
      "Random" = "Random Sample",
      "Stratified" = "Stratified Random",
      "Cluster" = "Cluster Sample",
      "Quota" = "Quota Sample",
      "Online_Panel" = "Online Panel",
      "Self_Selected" = "Self-Selected",
      "Census" = "Census",
      sm  # fallback to raw value
    )
    badge_items <- c(badge_items, sprintf('<span class="ci-badge">%s</span>',
                                           htmlEscape(sm_label)))
  }
  # Generated date
  gen_date <- tryCatch(
    format(as.POSIXct(summary$generated), "%b %Y"),
    error = function(e) format(Sys.time(), "%b %Y")
  )
  badge_items <- c(badge_items, sprintf('<span class="ci-badge">Generated %s</span>', gen_date))
  badge_items <- c(badge_items, '<span id="ci-save-badge"></span>')
  badges <- paste(badge_items, collapse = sep)

  sprintf(
    '<div class="ci-header">
      <div class="ci-header-inner">
        <div class="ci-header-logo">%s</div>
        <div class="ci-header-text">
          <div class="ci-header-title">%s</div>
          <div class="ci-header-subtitle">%s</div>
          <div class="ci-header-project">%s</div>
          %s
          <div class="ci-header-badges">%s</div>
        </div>
      </div>
    </div>',
    logo_html,
    htmlEscape(labels$report_title),
    htmlEscape(labels$report_subtitle),
    htmlEscape(summary$project_name),
    prepared,
    badges
  )
}


# ==============================================================================
# TAB NAVIGATION
# ==============================================================================

build_ci_tab_nav <- function() {
  save_icon <- '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-1px;margin-right:5px;"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>'
  paste0(
    '<div class="report-tabs">
    <button class="report-tab active" data-tab="summary" onclick="switchReportTab(\'summary\')">Summary</button>
    <button class="report-tab" data-tab="details" onclick="switchReportTab(\'details\')">Question Details</button>
    <button class="report-tab" data-tab="notes" onclick="switchReportTab(\'notes\')">Method Notes</button>
    <button class="report-tab ci-save-tab" onclick="saveReportHTML()">', save_icon, 'Save Report</button>
    <button class="ci-help-btn" onclick="toggleHelpOverlay()" title="Show help guide">?</button>
  </div>'
  )
}


# ==============================================================================
# HELP OVERLAY
# ==============================================================================

#' Build Help Overlay for Confidence Report
#'
#' Creates a modal overlay with a quick-reference guide to interactive features.
#' Shown via the ? button in the tab bar.
#'
#' @return Character string of help overlay HTML
#' @keywords internal
build_ci_help_overlay <- function() {
  '
<div class="ci-help-overlay" id="ci-help-overlay" onclick="toggleHelpOverlay()">
  <div class="ci-help-card" onclick="event.stopPropagation()">
    <h2>Quick Guide</h2>
    <div class="help-subtitle">Everything you need to know about this report</div>

    <h3>Navigating</h3>
    <ul>
      <li><span class="help-key">Summary</span>Overview of all questions with quality ratings and forest plot</li>
      <li><span class="help-key">Question Details</span>Per-question analysis with method comparisons and charts</li>
      <li><span class="help-key">Method Notes</span>Statistical methodology, assumptions, and limitations</li>
    </ul>

    <h3>Understanding Results</h3>
    <ul>
      <li><span class="help-key">Stability Interval</span>The range of plausible values for the true population parameter</li>
      <li><span class="help-key">Forest Plot</span>Dots = estimates, bars = intervals. Shorter bars = more precision</li>
      <li><span class="help-key">Quality Badge</span><strong style="color:#059669;">Good</strong> = precise, <strong style="color:#d97706;">Caution</strong> = moderate width, <strong style="color:#dc2626;">Poor</strong> = wide intervals</li>
    </ul>

    <h3>Interactive Features</h3>
    <ul>
      <li><span class="help-key">Question Nav</span>Click question buttons in the Details tab to switch between questions</li>
      <li><span class="help-key">Callouts</span>Click the <strong>i</strong> callout headers to expand/collapse educational notes</li>
      <li><span class="help-key">Comments</span>Add analyst notes in the Method Notes tab — saved with the report</li>
      <li><span class="help-key">Save Report</span>Downloads a self-contained HTML file with your comments preserved</li>
    </ul>

    <div class="help-dismiss">Click outside this panel or press Escape to close</div>
  </div>
</div>'
}


# ==============================================================================
# SUMMARY PANEL
# ==============================================================================

build_ci_summary_panel <- function(html_data, tables, charts, labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  summary <- html_data$summary
  parts <- character()

  # Stats cards
  stat_cards <- character()
  if (!is.na(summary$n_total)) {
    stat_cards <- c(stat_cards, sprintf(
      '<div class="ci-stat-card"><div class="ci-stat-value">%s</div><div class="ci-stat-label">Sample Size</div></div>',
      format(summary$n_total, big.mark = ",")
    ))
  }
  if (summary$is_weighted && !is.na(summary$n_effective)) {
    stat_cards <- c(stat_cards, sprintf(
      '<div class="ci-stat-card"><div class="ci-stat-value">%s</div><div class="ci-stat-label">Effective N</div></div>',
      format(summary$n_effective, big.mark = ",")
    ))
  }
  stat_cards <- c(stat_cards, sprintf(
    '<div class="ci-stat-card"><div class="ci-stat-value">%d</div><div class="ci-stat-label">Questions</div></div>',
    summary$n_questions
  ))
  if (summary$is_weighted && !is.na(summary$deff)) {
    stat_cards <- c(stat_cards, sprintf(
      '<div class="ci-stat-card"><div class="ci-stat-value">%.2f</div><div class="ci-stat-label">Design Effect</div></div>',
      summary$deff
    ))
  }
  parts <- c(parts, sprintf('<div class="ci-stats-row">%s</div>', paste(stat_cards, collapse = "\n")))

  # Study-level card (if weighted)
  if (summary$is_weighted && nzchar(tables$study_level %||% "")) {
    # Registry callout for static educational text
    study_callout <- turas_callout("confidence", "study_level_weighting", collapsed = TRUE)

    # Dynamic data-specific summary
    deff_val <- summary$deff %||% 1
    efficiency <- if (!is.na(deff_val) && deff_val > 0) round(100 / deff_val, 1) else NA
    deff_summary <- sprintf(
      '<div class="ci-callout ci-callout-result"><strong>Your study:</strong> DEFF = %.2f, reducing your effective sample from %s to %s.',
      deff_val,
      format(summary$n_total, big.mark = ","),
      format(summary$n_effective, big.mark = ",")
    )
    if (!is.na(efficiency)) {
      eff_text <- if (efficiency >= 85) {
        sprintf(" Efficiency of %.0f%% is excellent &mdash; weighting has minimal impact.", efficiency)
      } else if (efficiency >= 70) {
        sprintf(" Efficiency of %.0f%% is acceptable, though precision is somewhat reduced.", efficiency)
      } else {
        sprintf(" <strong>Warning:</strong> Efficiency of %.0f%% means weighting significantly reduces statistical power.", efficiency)
      }
      deff_summary <- paste0(deff_summary, eff_text)
    }
    deff_summary <- paste0(deff_summary, "</div>")

    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Study-Level Statistics</h3>%s\n%s\n%s</div>',
      deff_summary, study_callout, tables$study_level
    ))
  }

  # Summary table — registry callouts
  if (nzchar(tables$summary %||% "")) {
    overview_callout <- turas_callout("confidence", "results_overview")
    method_callout <- turas_callout("confidence", "method_selection", collapsed = TRUE)
    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Results Overview</h3>%s\n%s\n%s</div>',
      overview_callout, method_callout, tables$summary
    ))
  }

  # Forest plot — registry callout
  if (nzchar(charts$forest_plot %||% "")) {
    forest_callout <- turas_callout("confidence", "forest_plot_guide", collapsed = TRUE)
    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>%s</h3>%s\n%s</div>',
      labels$overview_title, charts$forest_plot, forest_callout
    ))
  }

  # Representativeness — registry callout
  if (nzchar(tables$representativeness %||% "")) {
    repr_callout <- turas_callout("confidence", "representativeness")
    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Sample Representativeness</h3>%s\n%s</div>',
      repr_callout, tables$representativeness
    ))
  }

  sprintf('<div id="tab-summary" class="tab-panel active">%s</div>',
          paste(parts, collapse = "\n"))
}


# ==============================================================================
# DETAILS PANEL
# ==============================================================================

build_ci_details_panel <- function(html_data, tables, charts, brand, labels = NULL) {
  if (is.null(labels)) labels <- get_sampling_labels("Not_Specified")
  questions <- html_data$questions
  if (length(questions) == 0) {
    return('<div id="tab-details" class="tab-panel"><div class="ci-card"><p>No question results to display.</p></div></div>')
  }

  conf_level <- html_data$methodology$confidence_level

  # Question nav buttons
  nav_buttons <- character()
  q_ids <- names(questions)
  for (i in seq_along(q_ids)) {
    active <- if (i == 1) " active" else ""
    q_raw_label <- questions[[q_ids[i]]]$question_label
    q_label <- if (!is.null(q_raw_label) && q_raw_label != q_ids[i])
      paste0(q_ids[i], " \u2014 ", q_raw_label) else q_ids[i]
    nav_buttons <- c(nav_buttons, sprintf(
      '<button class="ci-nav-btn%s" data-question="%s" onclick="switchQuestionDetail(\'%s\')">%s</button>',
      active, q_ids[i], q_ids[i], htmlEscape(q_label)
    ))
  }
  nav_html <- sprintf('<div class="ci-nav">%s</div>', paste(nav_buttons, collapse = "\n"))

  # Per-question detail panels
  panels <- character()
  for (i in seq_along(q_ids)) {
    q <- questions[[q_ids[i]]]
    active <- if (i == 1) " active" else ""

    panel_parts <- character()

    # Callout (structured HTML from callout generator — already has its own divs)
    panel_parts <- c(panel_parts, q$callout)

    # Cluster warning (only for cluster samples)
    if (labels$sampling_method_normalised == "cluster") {
      panel_parts <- c(panel_parts, CLUSTER_WARNING_HTML)
    }

    # Quality meta bar
    badge_class <- paste0("ci-quality-", q$quality$badge)
    badge_label <- switch(q$quality$badge, good = "Good", warn = "Caution", poor = "Poor")
    type_label <- switch(q$type, proportion = "Proportion", mean = "Mean", nps = "NPS")

    panel_parts <- c(panel_parts, sprintf(
      '<div class="ci-question-meta">
        <span>Type: <strong>%s</strong></span>
        <span>Quality: <span class="%s">%s</span></span>
        <span>Effective N: <strong>%s</strong></span>
      </div>',
      type_label, badge_class, badge_label,
      if (!is.na(q$n_eff)) format(q$n_eff, big.mark = ",") else "N/A"
    ))

    # Method comparison table (use pre-built from orchestrator if available)
    detail_key <- paste0("detail_", q_ids[i])
    detail_table <- tables[[detail_key]] %||% ""
    if (!nzchar(detail_table)) {
      # Fallback: build on demand if not pre-built
      detail_table <- if (q$type == "proportion") {
        build_proportion_detail_table(q$results, conf_level, labels = labels)
      } else if (q$type == "mean") {
        build_mean_detail_table(q$results, conf_level, labels = labels)
      } else if (q$type == "nps") {
        build_nps_detail_table(q$results, conf_level, labels = labels)
      } else ""
    }

    if (nzchar(detail_table)) {
      panel_parts <- c(panel_parts, detail_table)
    }

    # Method comparison chart (use pre-built from orchestrator if available)
    chart_key <- paste0("methods_", q_ids[i])
    method_chart <- charts[[chart_key]] %||% ""
    if (!nzchar(method_chart)) {
      # Fallback: build on demand if not pre-built
      method_chart <- build_method_comparison_chart(q, brand)
    }
    if (nzchar(method_chart)) {
      panel_parts <- c(panel_parts, method_chart)
    }

    q_heading <- if (!is.null(q$question_label) && q$question_label != q_ids[i])
      paste0(q_ids[i], " \u2014 ", q$question_label) else q_ids[i]
    panels <- c(panels, sprintf(
      '<div id="ci-detail-%s" class="ci-detail-panel%s"><div class="ci-card"><h3>%s</h3>%s</div></div>',
      q_ids[i], active, htmlEscape(q_heading),
      paste(panel_parts, collapse = "\n")
    ))
  }

  sprintf('<div id="tab-details" class="tab-panel">%s\n%s</div>',
          nav_html, paste(panels, collapse = "\n"))
}


# ==============================================================================
# NOTES PANEL
# ==============================================================================

build_ci_notes_panel <- function(html_data, config) {
  parts <- character()
  methods_used <- html_data$methodology$methods_used
  conf_level <- html_data$methodology$confidence_level
  boot_iter <- html_data$methodology$bootstrap_iterations

  # Method documentation
  parts <- c(parts, '<div class="ci-card"><h3>Statistical Methods</h3>')

  # Coverage probability explanation — from callout registry
  parts <- c(parts, turas_callout("confidence", "confidence_level"))

  if ("Normal Approximation (MOE)" %in% methods_used || "Normal Approximation" %in% methods_used) {
    parts <- c(parts, sprintf(
      '<div class="ci-method-doc">
        <h4>Margin of Error (Wald / Normal Approximation)</h4>
        <p><strong>Formula:</strong> p&#770;&nbsp;&plusmn;&nbsp;z<sub>&alpha;/2</sub>&nbsp;&times;&nbsp;&radic;(p&#770;(1&minus;p&#770;)&nbsp;/&nbsp;n), where z<sub>&alpha;/2</sub>&nbsp;=&nbsp;%.3f for %d%% confidence. For weighted data, n is replaced by n<sub>eff</sub> (Kish, 1965).</p>
        <p><strong>What it does:</strong> Estimates the maximum likely distance between the sample proportion and the true population proportion. This is the standard "plus or minus" figure reported in polls and surveys.</p>
        <p><strong>When it works well:</strong> Large samples (n&nbsp;&gt;&nbsp;30) with proportions between roughly 20%% and 80%%. Coverage probability is close to nominal in this range.</p>
        <p><strong>When it breaks down:</strong> At extreme proportions (below 5%% or above 95%%), the Wald interval has poor coverage &mdash; actual coverage can drop well below the stated confidence level. It can also produce intervals that extend below 0%% or above 100%%, which are logically impossible. For these cases, the Wilson score method is preferred.</p>
        <p><strong>Key assumption:</strong> Simple random sampling (or design-adjusted effective n). Not appropriate for clustered, stratified, or non-probability samples without modification.</p>
        <p><strong>Reference:</strong> This is the classical Wald interval. See Brown, Cai &amp; DasGupta (2001), "Interval estimation for a binomial proportion," <em>Statistical Science</em>, 16(2), for a thorough comparison of interval methods.</p>
      </div>',
      qnorm(1 - (1 - conf_level) / 2), round(conf_level * 100)
    ))
  }

  if ("Wilson Score" %in% methods_used) {
    parts <- c(parts, sprintf(
      '<div class="ci-method-doc">
        <h4>Wilson Score Interval</h4>
        <p><strong>Formula:</strong> The interval is obtained by inverting the score test for the binomial proportion. The centre is shifted from p&#770; toward 0.5 by the factor z<sup>2</sup>/(n&nbsp;+&nbsp;z<sup>2</sup>), and the width is: (1/(1&nbsp;+&nbsp;z<sup>2</sup>/n))&nbsp;&times;&nbsp;(p&#770;&nbsp;+&nbsp;z<sup>2</sup>/(2n)&nbsp;&plusmn;&nbsp;z&nbsp;&times;&nbsp;&radic;(p&#770;(1&minus;p&#770;)/n&nbsp;+&nbsp;z<sup>2</sup>/(4n<sup>2</sup>))), where z<sub>&alpha;/2</sub>&nbsp;=&nbsp;%.3f.</p>
        <p><strong>What it does:</strong> Produces confidence intervals for proportions that are guaranteed to lie within [0,&nbsp;1] and have near-nominal coverage probability even at extreme proportions and small sample sizes.</p>
        <p><strong>When it works well:</strong> All proportion scenarios, but especially at extremes (p&nbsp;&lt;&nbsp;0.10 or p&nbsp;&gt;&nbsp;0.90) and with sample sizes under 100. Agresti &amp; Coull (1998) recommend it as a default replacement for the Wald interval.</p>
        <p><strong>When it breaks down:</strong> Like all frequentist proportion methods, it still assumes independent Bernoulli trials from a random sample. It does not correct for clustering, stratification, or selection bias.</p>
        <p><strong>Key assumption:</strong> Random sampling with independent observations. The improvement over the Wald method is purely mathematical &mdash; it does not address sampling design issues.</p>
        <p><strong>References:</strong> Wilson, E.B. (1927), "Probable inference, the law of succession, and statistical inference," <em>Journal of the American Statistical Association</em>, 22(158). Agresti, A. &amp; Coull, B.A. (1998), "Approximate is better than exact for interval estimation of binomial proportions," <em>The American Statistician</em>, 52(2).</p>
      </div>',
      qnorm(1 - (1 - conf_level) / 2)
    ))
  }

  if ("Bootstrap" %in% methods_used) {
    parts <- c(parts, sprintf(
      '<div class="ci-method-doc">
        <h4>Bootstrap Confidence Interval</h4>
        <p><strong>Procedure:</strong> The original sample of n observations is resampled with replacement %s times. For each resample, the statistic of interest (proportion, mean, or NPS) is recalculated. The confidence interval is taken from the &alpha;/2 and 1&minus;&alpha;/2 percentiles of the bootstrap distribution (the "percentile method").</p>
        <p><strong>What it does:</strong> Estimates the sampling distribution of a statistic empirically, without assuming any particular parametric form. This is especially valuable when the statistic has a complex or unknown distribution (e.g., NPS, ratios, differences).</p>
        <p><strong>When it works well:</strong> Moderate to large samples where the data may be skewed, heavy-tailed, multimodal, or bounded. Performs well when parametric assumptions (normality, symmetry) are questionable. With sufficient iterations, the percentile bootstrap achieves good coverage for most smooth statistics.</p>
        <p><strong>When it breaks down:</strong> (1)&nbsp;Very small samples (n&nbsp;&lt;&nbsp;15): the bootstrap distribution is too coarse to accurately represent the sampling distribution. (2)&nbsp;Biased samples: the bootstrap faithfully reproduces any selection bias in the original data &mdash; it cannot correct for non-random sampling. (3)&nbsp;Clustered or dependent data: standard bootstrap assumes independent observations; for panel or clustered data, a block bootstrap or cluster bootstrap is needed.</p>
        <p><strong>Percentile vs. BCa:</strong> This report uses the percentile method for simplicity and interpretability. The bias-corrected and accelerated (BCa) method can improve coverage when the bootstrap distribution is skewed, but adds computational complexity and can be unstable with small samples.</p>
        <p><strong>Key assumption:</strong> The sample is representative of the population, and observations are independent.</p>
        <p><strong>Reference:</strong> Efron, B. &amp; Tibshirani, R.J. (1993), <em>An Introduction to the Bootstrap</em>, Chapman &amp; Hall.</p>
      </div>',
      format(boot_iter, big.mark = ",")
    ))
  }

  if ("Bayesian Credible" %in% methods_used) {
    parts <- c(parts, sprintf(
      '<div class="ci-method-doc">
        <h4>Bayesian Credible Interval</h4>
        <p><strong>For proportions:</strong> Uses Beta-Binomial conjugacy. Given x successes in n trials with a Beta(&alpha;<sub>0</sub>,&nbsp;&beta;<sub>0</sub>) prior, the posterior is Beta(x&nbsp;+&nbsp;&alpha;<sub>0</sub>,&nbsp;n&minus;x&nbsp;+&nbsp;&beta;<sub>0</sub>). The credible interval is taken from the &alpha;/2 and 1&minus;&alpha;/2 quantiles of this posterior. A weakly informative Jeffreys prior (Beta(0.5,&nbsp;0.5)) is commonly used.</p>
        <p><strong>For means:</strong> Uses a Normal-Inverse-Gamma conjugate model. With weakly informative priors, the posterior mean interval converges to the frequentist t-distribution interval.</p>
        <p><strong>What it does:</strong> Produces an interval with a direct probabilistic interpretation: there is a %d%% posterior probability that the true parameter lies within the stated bounds (given the data and the prior). This is often the interpretation people <em>intuitively</em> give to frequentist intervals, even though it is only strictly valid in the Bayesian framework.</p>
        <p><strong>When it works well:</strong> Tracking studies where previous waves provide defensible prior information. Small samples where prior knowledge can stabilise estimates. Also useful when the direct probabilistic interpretation is important for decision-making.</p>
        <p><strong>When it breaks down:</strong> An informative prior that conflicts with the truth will bias the posterior, especially in small samples where the data cannot overwhelm the prior. With large samples, the prior is washed out and Bayesian and frequentist intervals converge (Bernstein&ndash;von Mises theorem). With uninformative priors, Bayesian and frequentist results are nearly identical.</p>
        <p><strong>Key assumption:</strong> The model is correctly specified and the prior is defensible. Random sampling is still assumed.</p>
        <p><strong>References:</strong> Gelman, A. et al. (2013), <em>Bayesian Data Analysis</em>, 3rd ed., CRC Press. For proportions: Agresti, A. &amp; Min, Y. (2005), "Frequentist performance of Bayesian confidence intervals for comparing proportions in 2&times;2 contingency tables," <em>Biometrics</em>, 61(2).</p>
      </div>',
      round(conf_level * 100)
    ))
  }

  if ("t-Distribution" %in% methods_used) {
    parts <- c(parts,
      '<div class="ci-method-doc">
        <h4>t-Distribution Confidence Interval (for Means)</h4>
        <p><strong>Formula:</strong> x&#772;&nbsp;&plusmn;&nbsp;t<sub>&alpha;/2,&thinsp;n&minus;1</sub>&nbsp;&times;&nbsp;s&nbsp;/&nbsp;&radic;n, where t<sub>&alpha;/2,&thinsp;n&minus;1</sub> is the critical value from the t-distribution with n&minus;1 degrees of freedom. For weighted data, n is replaced by n<sub>eff</sub> and s by the Bessel-corrected weighted standard deviation.</p>
        <p><strong>What it does:</strong> Accounts for the additional uncertainty that arises from estimating the population standard deviation from the sample (rather than knowing it). The t-distribution has heavier tails than the normal, producing wider intervals that are appropriate when the true SD is unknown.</p>
        <p><strong>When it works well:</strong> (1)&nbsp;Data is approximately normally distributed, at any sample size. (2)&nbsp;Data is non-normal but the sample is large (n&nbsp;&gt;&nbsp;30), where the Central Limit Theorem ensures the sampling distribution of the mean is approximately normal. Coverage is remarkably robust to non-normality for n&nbsp;&gt;&nbsp;40.</p>
        <p><strong>When it breaks down:</strong> Heavily skewed or heavy-tailed distributions with small samples (n&nbsp;&lt;&nbsp;20). In such cases, the actual coverage can deviate from nominal. Common examples: income data, time-to-completion data, data with floor/ceiling effects. Bootstrap intervals are more appropriate here.</p>
        <p><strong>Weighted variance:</strong> For weighted data, the Bessel-corrected weighted variance is s<sup>2</sup><sub>w</sub>&nbsp;=&nbsp;&Sigma;w<sub>i</sub>(x<sub>i</sub>&minus;x&#772;<sub>w</sub>)<sup>2</sup>&nbsp;/&nbsp;(&Sigma;w&nbsp;&minus;&nbsp;&Sigma;w<sup>2</sup>/&Sigma;w), which provides an unbiased estimate of the population variance under reliability (frequency) weighting.</p>
        <p><strong>Key assumption:</strong> Random sampling, independent observations, approximate normality or large sample. For weighted data, weights are treated as reliability (frequency) weights, not probability weights (for which the survey package approach is more appropriate).</p>
        <p><strong>Reference:</strong> Student [W.S. Gosset] (1908), "The probable error of a mean," <em>Biometrika</em>, 6(1). For weighted variance: Cochran, W.G. (1977), <em>Sampling Techniques</em>, 3rd ed., Wiley.</p>
      </div>'
    )
  }

  # Effective sample size documentation (always show if weighted)
  if (html_data$summary$is_weighted) {
    parts <- c(parts,
      '<div class="ci-method-doc">
        <h4>Effective Sample Size (Design Effect)</h4>
        <p><strong>Formula:</strong> n<sub>eff</sub>&nbsp;=&nbsp;(&Sigma;w<sub>i</sub>)<sup>2</sup>&nbsp;/&nbsp;&Sigma;w<sub>i</sub><sup>2</sup>. The design effect is DEFF&nbsp;=&nbsp;n&nbsp;/&nbsp;n<sub>eff</sub>&nbsp;=&nbsp;1&nbsp;+&nbsp;CV<sup>2</sup>(w), where CV(w) is the coefficient of variation of the weights.</p>
        <p><strong>What it means:</strong> When survey responses carry unequal weights, some observations contribute more to the estimate than others. The effective sample size is the number of equally-weighted observations that would give the same precision as the actual weighted sample. A DEFF of 1.0 means weights are equal (no efficiency loss); a DEFF of 2.0 means the weighted sample is only as precise as an unweighted sample half its size.</p>
        <p><strong>Interpretation guide:</strong> DEFF&nbsp;&lt;&nbsp;1.5 (efficiency&nbsp;&gt;&nbsp;67%): acceptable for most purposes. DEFF&nbsp;1.5&ndash;2.0 (efficiency&nbsp;50&ndash;67%): weighting is having a meaningful impact on precision; consider whether the weighting scheme can be simplified. DEFF&nbsp;&gt;&nbsp;2.0 (efficiency&nbsp;&lt;&nbsp;50%): weighting is severely reducing precision; review the weighting targets and consider collapsing categories.</p>
        <p><strong>Key limitation:</strong> The Kish formula measures only the precision loss from unequal weights. It does not capture clustering effects (for which a separate design effect adjustment would be needed) or non-response bias.</p>
        <p><strong>Reference:</strong> Kish, L. (1965), <em>Survey Sampling</em>, Wiley. Kish, L. (1992), "Weighting for unequal P<sub>i</sub>," <em>Journal of Official Statistics</em>, 8(2).</p>
      </div>'
    )
  }

  parts <- c(parts, '</div>')

  # Limitations — from callout registry
  parts <- c(parts,
    '<div class="ci-card"><h3>Understanding Limitations</h3>',
    turas_callout("confidence", "precision_accuracy"),
    turas_callout("confidence", "non_sampling_error"),
    turas_callout("confidence", "multiple_comparisons"),
    '</div>'
  )

  # Warnings from analysis
  warnings <- html_data$warnings
  if (length(warnings) > 0) {
    warning_items <- paste(
      sapply(warnings, function(w) sprintf('<li>%s</li>', htmlEscape(w))),
      collapse = "\n"
    )
    parts <- c(parts, sprintf(
      '<div class="ci-card"><h3>Analysis Warnings</h3><ul style="margin-left:20px; font-size:13px;">%s</ul></div>',
      warning_items
    ))
  }

  # Comments box
  parts <- c(parts,
    '<div class="ci-card">
      <h3>Comments</h3>
      <p style="font-size:12px; color:#64748b; margin-bottom:12px;">Add your comments below. These will be saved when you use the Save Report button.</p>
      <textarea class="ci-comments-box" id="analyst-comments" placeholder="Add your comments, observations, or notes here..."></textarea>
    </div>'
  )

  sprintf('<div id="tab-notes" class="tab-panel">%s</div>', paste(parts, collapse = "\n"))
}


# ==============================================================================
# FOOTER
# ==============================================================================

build_ci_footer <- function() {
  sprintf(
    '<div class="ci-footer">Generated by Turas Confidence &middot; %s &middot; The Research Lamppost (Pty) Ltd</div>',
    format(Sys.time(), "%Y-%m-%d %H:%M")
  )
}


# ==============================================================================
# JAVASCRIPT
# ==============================================================================

build_ci_js <- function() {
  js_dir <- get0(".confidence_html_report_dir", envir = globalenv())

  if (!is.null(js_dir)) {
    js_path <- file.path(js_dir, "js", "confidence_navigation.js")
    if (file.exists(js_path)) {
      return(paste(readLines(js_path, warn = FALSE), collapse = "\n"))
    }
  }

  # Inline fallback
  '
function switchReportTab(tabName) {
  document.querySelectorAll(".report-tab").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
  });
  document.querySelectorAll(".tab-panel").forEach(function(panel) { panel.classList.remove("active"); });
  var target = document.getElementById("tab-" + tabName);
  if (target) target.classList.add("active");
}
function switchQuestionDetail(questionId) {
  document.querySelectorAll(".ci-nav-btn").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-question") === questionId);
  });
  document.querySelectorAll(".ci-detail-panel").forEach(function(panel) { panel.classList.remove("active"); });
  var target = document.getElementById("ci-detail-" + questionId);
  if (target) target.classList.add("active");
}
function saveReportHTML() {
  var meta = document.querySelector("meta[name=turas-source-filename]");
  var baseName = meta ? meta.getAttribute("content") : "Confidence_Report";
  document.querySelectorAll("textarea").forEach(function(ta) { ta.textContent = ta.value; });
  var html = document.documentElement.outerHTML;
  var blob = new Blob(["<!DOCTYPE html>\\n" + html], { type: "text/html" });
  var url = URL.createObjectURL(blob);
  var a = document.createElement("a"); a.href = url; a.download = baseName + "_Updated.html";
  document.body.appendChild(a); a.click(); document.body.removeChild(a); URL.revokeObjectURL(url);
}
function toggleHelpOverlay() {
  var overlay = document.getElementById("ci-help-overlay");
  if (overlay) overlay.classList.toggle("active");
}
// --- Callout collapsibility with localStorage persistence ---
document.addEventListener("DOMContentLoaded", function() {
  switchReportTab("summary");

  // Restore callout collapsed states from localStorage
  var storageKey = "turas-ci-callout-states";
  var saved = {};
  try { saved = JSON.parse(localStorage.getItem(storageKey) || "{}"); } catch(e) {}

  document.querySelectorAll(".t-callout").forEach(function(callout, idx) {
    var key = callout.id || ("callout-" + idx);
    if (saved[key] === "collapsed") {
      callout.classList.add("collapsed");
    } else if (saved[key] === "expanded") {
      callout.classList.remove("collapsed");
    }
    // Click handler on header (remove inline onclick to avoid double-toggle)
    var header = callout.querySelector(".t-callout-header");
    if (header) {
      header.removeAttribute("onclick");
      header.addEventListener("click", function() {
        callout.classList.toggle("collapsed");
        // Persist state
        try {
          var states = JSON.parse(localStorage.getItem(storageKey) || "{}");
          states[key] = callout.classList.contains("collapsed") ? "collapsed" : "expanded";
          localStorage.setItem(storageKey, JSON.stringify(states));
        } catch(e) {}
      });
    }
  });
  // Escape key closes help overlay
  document.addEventListener("keydown", function(e) {
    if (e.key === "Escape") {
      var overlay = document.getElementById("ci-help-overlay");
      if (overlay && overlay.classList.contains("active")) overlay.classList.remove("active");
    }
  });
});
'
}


# ==============================================================================
# UTILITY
# ==============================================================================

# htmlEscape: canonical definition in 02_table_builder.R
if (!exists("htmlEscape", mode = "function")) {
  htmlEscape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    x
  }
}
