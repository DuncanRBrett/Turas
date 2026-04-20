# ==============================================================================
# BRAND HTML REPORT - PAGE BUILDER
# ==============================================================================
# Assembles the complete HTML document from tables, charts, and data.
# Layer 4 of the 4-layer pipeline.
# ==============================================================================

# Source design system if not loaded
local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root) && exists("find_turas_root", mode = "function")) {
    turas_root <- find_turas_root()
  }
  if (!nzchar(turas_root)) turas_root <- getwd()

  ds_dir <- file.path(turas_root, "modules", "shared", "lib", "design_system")
  if (!dir.exists(ds_dir)) ds_dir <- file.path("modules", "shared", "lib", "design_system")
  if (!exists("turas_base_css", mode = "function") && dir.exists(ds_dir)) {
    for (f in c("design_tokens.R", "font_embed.R", "base_css.R")) {
      fp <- file.path(ds_dir, f)
      if (file.exists(fp)) source(fp, local = FALSE)
    }
  }

  pins_path <- file.path(turas_root, "modules", "shared", "lib", "turas_pins_js.R")
  if (!exists("turas_pins_js", mode = "function") && file.exists(pins_path)) {
    source(pins_path, local = FALSE)
  }
})

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

.br_esc <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# COMPONENT BUILDERS
# ==============================================================================

#' Build branded header
#' @keywords internal
build_br_header <- function(config) {
  brand <- config$colour_focal %||% "#1A5276"
  sprintf('
<div class="br-header" style="background:#1a2744;color:#fff;padding:20px 32px;border-radius:0 0 12px 12px;" data-report-title="%s">
  <div style="display:flex;justify-content:space-between;align-items:flex-start;">
    <div>
      <div style="font-size:11px;text-transform:uppercase;letter-spacing:1.5px;opacity:0.7;margin-bottom:4px;">Turas Brand Health</div>
      <h1 id="br-header-title" style="margin:0;font-size:22px;font-weight:700;color:#fff;">%s</h1>
      <div style="font-size:13px;opacity:0.8;margin-top:2px;color:#fff;">%s</div>
    </div>
    <div style="display:flex;gap:8px;">
      <button class="br-save-btn" onclick="_brSaveReport()" title="Save Report"
        style="background:rgba(255,255,255,0.15);border:1px solid rgba(255,255,255,0.3);color:#fff;border-radius:6px;padding:8px 14px;cursor:pointer;font-size:12px;font-weight:500;">
        Save Report
      </button>
      <button class="br-help-btn" onclick="_brToggleHelp()" title="Help"
        style="background:rgba(255,255,255,0.15);border:1px solid rgba(255,255,255,0.3);color:#fff;border-radius:50%%;width:34px;height:34px;cursor:pointer;font-size:14px;font-weight:700;">
        ?
      </button>
    </div>
  </div>
  <div class="br-badge-bar" style="display:flex;gap:16px;margin-top:12px;font-size:11px;opacity:0.7;">
    <span>Client: %s</span>
    <span style="opacity:0.4;">|</span>
    <span>Focal Brand: %s</span>
    <span style="opacity:0.4;">|</span>
    <span>Wave %s</span>
    <span style="opacity:0.4;">|</span>
    <span>%s</span>
  </div>
</div>',
    .br_esc(config$report_title %||% "Brand Health Report"),
    .br_esc(config$report_title %||% "Brand Health Report"),
    .br_esc(config$report_subtitle %||% ""),
    .br_esc(config$client_name %||% ""),
    .br_esc(config$focal_brand %||% ""),
    config$wave %||% 1,
    format(Sys.Date(), "%B %Y"))
}


#' Build tab navigation
#' @keywords internal
build_br_tab_nav <- function(category_names, config) {
  btns <- character(0)
  btns <- c(btns, '<button class="br-tab-btn active" data-tab="summary" onclick="switchBrandTab(\'summary\')">Summary</button>')

  for (cat_name in category_names) {
    cat_id <- gsub("[^a-z0-9]", "-", tolower(cat_name))
    btns <- c(btns, sprintf(
      '<button class="br-tab-btn" data-tab="cat-%s" onclick="switchBrandTab(\'cat-%s\')">%s</button>',
      cat_id, cat_id, .br_esc(cat_name)))
  }

  if (isTRUE(config$element_dba))
    btns <- c(btns, '<button class="br-tab-btn" data-tab="dba" onclick="switchBrandTab(\'dba\')">Brand Assets</button>')
  # WOM is per-category (each category sub-tab). No top-level WOM tab.
  if (isTRUE(config$element_portfolio))
    btns <- c(btns, '<button class="br-tab-btn" data-tab="portfolio" onclick="switchBrandTab(\'portfolio\')">Portfolio</button>')

  btns <- c(btns, sprintf(
    '<button class="br-tab-btn" data-tab="pinned" onclick="switchBrandTab(\'pinned\')">Pinned Views <span class="br-pin-badge" id="br-pin-count-badge">0</span></button>'))
  btns <- c(btns, '<button class="br-tab-btn" data-tab="about" onclick="switchBrandTab(\'about\')">About</button>')

  sprintf('<div class="br-tab-nav">%s</div>', paste(btns, collapse = "\n"))
}


#' Build section toolbar (pin + export + insight)
#' @keywords internal
build_br_section_toolbar <- function(section_id) {
  sprintf('
<div class="br-section-toolbar" style="display:flex;gap:8px;margin-bottom:12px;">
  <button class="br-pin-btn" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin to Views"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:15px;padding:5px 10px;color:#94a3b8;transition:all 0.15s;">
    &#x1F4CC;
  </button>
  <button class="br-export-btn" onclick="_brExportPanel(\'%s\')" title="Export Excel"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    &#x1F4E5; Export
  </button>
  <button class="br-insight-toggle" onclick="_brToggleInsight(\'%s\')"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:12px;padding:5px 10px;color:#64748b;">
    + Add Insight
  </button>
</div>
<div class="br-insight-container" data-section="%s" style="display:none;margin-bottom:16px;">
  <textarea class="br-insight-editor" data-section="%s" placeholder="Type key insight here..."
    style="width:100%%;min-height:60px;border:1px solid #e2e8f0;border-radius:6px;padding:10px;font-family:inherit;font-size:13px;resize:vertical;"></textarea>
  <div class="br-insight-rendered" data-section="%s" ondblclick="_brToggleInsightEdit(\'%s\')"
    style="display:none;padding:10px;border:1px solid #e2e8f0;border-radius:6px;min-height:40px;cursor:pointer;font-size:13px;line-height:1.5;"></div>
  <button class="br-insight-dismiss" onclick="_brDismissInsight(\'%s\')"
    style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:16px;position:absolute;top:4px;right:8px;">&times;</button>
</div>',
    section_id, section_id, section_id, section_id,
    section_id, section_id, section_id, section_id, section_id)
}


#' Wrap content in a chart container with pin button
#' @keywords internal
build_br_chart_wrapper <- function(chart_svg, chart_title = "") {
  if (is.null(chart_svg) || !nzchar(chart_svg)) return("")
  sprintf('
<div class="br-chart-wrapper" style="position:relative;margin:16px 0;">
  <button class="br-chart-pin-btn" onclick="brPinChart(this,\'%s\')"
    style="position:absolute;top:4px;right:4px;background:rgba(255,255,255,0.9);border:1px solid #e2e8f0;border-radius:4px;cursor:pointer;font-size:14px;padding:3px 6px;opacity:0;transition:opacity 0.15s;z-index:5;">
    &#x1F4CC;
  </button>
  <div class="br-chart-container">%s</div>
</div>', .br_esc(chart_title), chart_svg)
}


#' Build the summary dashboard panel
#' @keywords internal
build_br_summary_panel <- function(results, config) {
  focal <- config$focal_brand %||% ""
  parts <- character(0)
  parts <- c(parts, '<div class="br-panel active" id="panel-summary"><div class="br-section">')
  parts <- c(parts, '<h2 style="font-size:20px;color:#1e293b;margin:0 0 20px;">Executive Summary</h2>')

  # Per-category headline cards
  cats <- results$results$categories
  if (!is.null(cats)) {
    parts <- c(parts, '<div class="br-summary-grid" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;">')
    for (cat_name in names(cats)) {
      cr <- cats[[cat_name]]
      ma <- cr$mental_availability
      funnel <- cr$funnel

      mms_val <- if (!is.null(ma) && !is.null(ma$metrics_summary$focal_mms)) {
        sprintf("%.1f%%", ma$metrics_summary$focal_mms * 100)
      } else "\u2014"
      mpen_val <- if (!is.null(ma) && !is.null(ma$metrics_summary$focal_mpen)) {
        sprintf("%.0f%%", ma$metrics_summary$focal_mpen * 100)
      } else "\u2014"
      aware_val <- if (!is.null(funnel) &&
                        !is.null(funnel$metrics_summary$focal_by_stage$aware)) {
        sprintf("%.0f%%", 100 * funnel$metrics_summary$focal_by_stage$aware)
      } else "\u2014"

      parts <- c(parts, sprintf('
<div class="br-cat-card" style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:16px;">
  <div style="font-size:13px;font-weight:600;color:#64748b;margin-bottom:12px;">%s</div>
  <div style="display:flex;gap:16px;">
    <div style="text-align:center;flex:1;">
      <div style="font-size:22px;font-weight:700;color:%s;">%s</div>
      <div style="font-size:10px;color:#94a3b8;">MMS</div>
    </div>
    <div style="text-align:center;flex:1;">
      <div style="font-size:22px;font-weight:700;color:%s;">%s</div>
      <div style="font-size:10px;color:#94a3b8;">MPen</div>
    </div>
    <div style="text-align:center;flex:1;">
      <div style="font-size:22px;font-weight:700;color:%s;">%s</div>
      <div style="font-size:10px;color:#94a3b8;">Awareness</div>
    </div>
  </div>
</div>',
        .br_esc(cat_name),
        config$colour_focal, mms_val,
        config$colour_focal, mpen_val,
        config$colour_focal, aware_val))
    }
    parts <- c(parts, '</div>')
  }

  parts <- c(parts, '</div></div>')
  paste(parts, collapse = "\n")
}


#' Build a category panel with 2-layer flat sub-tabs
#'
#' Each element's internal sections (Funnel/Relationship, Attributes/CEPs/Metrics)
#' are promoted to category-level sub-tabs, removing the intermediate element
#' grouping layer. The panel HTML for each element is kept intact but its
#' internal nav bar is hidden via CSS.
#'
#' Sub-tab order: Brand Funnel → Brand Attitude → Brand Attributes →
#' Category Entry Points → MA Metrics → Category Buying
#'
#' @keywords internal
build_br_category_panel <- function(cat_name, cat_results, charts, tables,
                                     config, panels = list()) {
  cat_id <- gsub("[^a-z0-9]", "-", tolower(cat_name))
  panel_id <- paste0("cat-", cat_id)

  parts <- character(0)
  parts <- c(parts, sprintf('<div class="br-panel" id="panel-%s">', panel_id))

  # Detect which elements have renderable data
  has_funnel <- !is.null(cat_results$funnel) &&
    !identical(cat_results$funnel$status, "REFUSED")
  has_ma <- !is.null(cat_results$mental_availability) &&
    !identical(cat_results$mental_availability$status, "REFUSED")
  has_repertoire <- !is.null(cat_results$repertoire) &&
    !identical(cat_results$repertoire$status, "REFUSED")
  has_wom <- !is.null(cat_results$wom) &&
    !identical(cat_results$wom$status, "REFUSED") &&
    !is.null(cat_results$wom$wom_metrics)

  # Build flat sub-tab list in the required display order.
  # Each entry: key (unique), label, subpanel (which .br-subpanel to show),
  # internal_tab (which internal panel tab to switch to, "" = n/a).
  flat_tabs <- list()
  if (has_funnel) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "fn-funnel",       label = "Brand Funnel",
                subpanel = "fn",  internal_tab = "funnel")),
      list(list(key = "fn-relationship", label = "Brand Attitude",
                subpanel = "fn",  internal_tab = "relationship"))
    )
  }
  if (has_ma) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "ma-attributes",   label = "Brand Attributes",
                subpanel = "ma",  internal_tab = "attributes")),
      list(list(key = "ma-ceps",         label = "Category Entry Points",
                subpanel = "ma",  internal_tab = "ceps")),
      list(list(key = "ma-metrics",      label = "MA Metrics",
                subpanel = "ma",  internal_tab = "metrics"))
    )
  }
  if (has_repertoire) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "rep",             label = "Category Buying",
                subpanel = "rep", internal_tab = ""))
    )
  }
  if (has_wom) {
    flat_tabs <- c(flat_tabs,
      list(list(key = "wom",             label = "Word of Mouth",
                subpanel = "wom", internal_tab = ""))
    )
  }

  # Sub-tab navigation bar
  if (length(flat_tabs) > 0) {
    subtab_btns <- vapply(seq_along(flat_tabs), function(i) {
      tab <- flat_tabs[[i]]
      active_cls <- if (i == 1) " active" else ""
      sprintf(
        '<button class="br-subtab-btn%s" data-group="%s" data-subtab="%s" data-subpanel="%s" data-internal-tab="%s" onclick="switchCategorySubtab(this)">%s</button>',
        active_cls, cat_id, tab$key, tab$subpanel, tab$internal_tab, tab$label
      )
    }, character(1))
    parts <- c(parts, sprintf('<div class="br-subtab-nav">%s</div>',
                              paste(subtab_btns, collapse = "\n")))
  }

  # One sub-panel per element. Active sub-panel = the one containing the first tab.
  first_subpanel <- if (length(flat_tabs) > 0) flat_tabs[[1]]$subpanel else ""

  # Element map: subpanel key → element name used for chart/panel lookup keys
  element_map <- list()
  if (has_funnel)     element_map[["fn"]]  <- "funnel"
  if (has_ma)         element_map[["ma"]]  <- "ma"
  if (has_repertoire) element_map[["rep"]] <- "repertoire"
  if (has_wom)        element_map[["wom"]] <- "wom"

  for (sp_key in names(element_map)) {
    el        <- element_map[[sp_key]]
    active    <- if (sp_key == first_subpanel) " active" else ""
    section_id <- paste0(el, "-", cat_id)
    chart_key  <- paste0(el, "_", cat_id)

    parts <- c(parts, sprintf(
      '<div class="br-subpanel%s" data-group="%s" data-subpanel="%s">',
      active, cat_id, sp_key))
    parts <- c(parts, sprintf(
      '<div class="br-element-section" id="section-%s" data-section="%s">',
      section_id, section_id))

    if (!is.null(panels[[chart_key]])) {
      parts <- c(parts, panels[[chart_key]])
    } else if (el == "ma") {
      parts <- c(parts,
        '<div style="padding:32px;text-align:center;color:#94a3b8;font-size:14px;">',
        'Mental Availability panel could not be rendered.',
        ' Ensure <code>02a_ma_panel_data.R</code> is sourced before calling',
        ' <code>generate_brand_html_report()</code>.',
        '</div>')
    } else if (el == "wom") {
      # WOM: per-category, rendered from charts + tables keyed as wom_{cat_id}
      parts <- c(parts, build_br_section_toolbar(section_id))
      wom_key <- paste0("wom_", cat_id)
      parts <- c(parts, sprintf(
        '<h3 class="br-element-title">Word of Mouth \u2014 %s</h3>',
        .br_esc(cat_name)))
      parts <- c(parts, '<p style="font-size:12px;color:#64748b;margin:0 0 12px;">',
        'Percentage of category buyers who received or shared word-of-mouth about each brand ',
        'in the study\'s recall timeframe.</p>')
      if (!is.null(charts[[wom_key]])) {
        for (ch in charts[[wom_key]]) {
          parts <- c(parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
        }
      }
      if (!is.null(tables[[wom_key]])) {
        parts <- c(parts, tables[[wom_key]])
      }
    } else if (el == "repertoire") {
      # Category Buying: repertoire metrics with contextual header
      parts <- c(parts, build_br_section_toolbar(section_id))
      parts <- c(parts, sprintf(
        '<h3 class="br-element-title">Category Buying \u2014 %s</h3>',
        .br_esc(cat_name)))
      parts <- c(parts, '<p style="font-size:12px;color:#64748b;margin:0 0 12px;">',
        'Brand repertoire size, sole loyalty, and brand overlap among category buyers. ',
        'Buying frequency analysis will be added in a future update.</p>')
      if (!is.null(charts[[chart_key]])) {
        for (ch in charts[[chart_key]]) {
          parts <- c(parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
        }
      }
      if (!is.null(tables[[chart_key]])) {
        parts <- c(parts, tables[[chart_key]])
      }
    } else {
      # Legacy path: any future elements without a dedicated panel
      parts <- c(parts, build_br_section_toolbar(section_id))
      if (!is.null(charts[[chart_key]])) {
        for (ch in charts[[chart_key]]) {
          parts <- c(parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
        }
      }
      if (!is.null(tables[[chart_key]])) {
        parts <- c(parts, tables[[chart_key]])
      }
    }

    parts <- c(parts, '</div></div>')
  }

  parts <- c(parts, '</div>')
  paste(parts, collapse = "\n")
}


#' Build the portfolio optimisation panel
#'
#' Cross-category comparison table showing IPK's brand position across all
#' categories in the study. Full categories show MA and funnel metrics;
#' awareness-only categories show awareness only.
#'
#' @keywords internal
build_br_portfolio_panel <- function(results, config) {
  focal <- config$focal_brand %||% ""
  brand_colour <- config$colour_focal %||% "#1A5276"
  cats <- results$results$categories
  if (is.null(cats) || length(cats) == 0)
    return('<div class="br-panel" id="panel-portfolio"><div class="br-section"><p style="color:#94a3b8;padding:32px;text-align:center;">No category data available.</p></div></div>')

  section_id <- "portfolio-overview"
  parts <- character(0)
  parts <- c(parts, '<div class="br-panel" id="panel-portfolio">')
  parts <- c(parts, '<div class="br-section">')
  parts <- c(parts, sprintf(
    '<h2 style="font-size:20px;color:#1e293b;margin:0 0 6px;">Portfolio Overview</h2>'))
  parts <- c(parts, sprintf(
    '<p style="font-size:13px;color:#64748b;margin:0 0 20px;">Cross-category brand position for <strong>%s</strong>. Full categories show the complete CBM battery. Awareness-only categories contribute brand tracking data only.</p>',
    .br_esc(focal)))

  # --- Summary metrics table ---
  parts <- c(parts, '<div class="br-element-section" id="section-portfolio-overview" data-section="portfolio-overview">')
  parts <- c(parts, build_br_section_toolbar(section_id))

  # Column headers
  parts <- c(parts, '
<div style="overflow-x:auto;">
<table class="br-table" data-sortable="true">
<thead>
<tr>
  <th>Category</th>
  <th>Analysis</th>
  <th>Awareness</th>
  <th>MMS</th>
  <th>MPen</th>
  <th>NS</th>
</tr>
</thead>
<tbody>')

  for (cat_name in names(cats)) {
    cr    <- cats[[cat_name]]
    depth <- cr$analysis_depth %||% "full"

    awareness_str <- "\u2014"
    mms_str       <- "\u2014"
    mpen_str      <- "\u2014"
    ns_str        <- "\u2014"

    if (depth == "full") {
      # Awareness from funnel metrics_summary
      fn <- cr$funnel
      if (!is.null(fn) && !identical(fn$status, "REFUSED") &&
          !is.null(fn$metrics_summary$focal_by_stage$aware)) {
        awareness_str <- sprintf("%.0f%%",
          fn$metrics_summary$focal_by_stage$aware * 100)
      }
      # MA metrics
      ma <- cr$mental_availability
      if (!is.null(ma) && !identical(ma$status, "REFUSED")) {
        ms <- ma$metrics_summary
        if (!is.null(ms$focal_mms))  mms_str  <- sprintf("%.1f%%", ms$focal_mms * 100)
        if (!is.null(ms$focal_mpen)) mpen_str <- sprintf("%.0f%%", ms$focal_mpen * 100)
        if (!is.null(ms$focal_ns))   ns_str   <- sprintf("%.1f",   ms$focal_ns)
      }
    }

    depth_badge <- if (depth == "full")
      sprintf('<span style="background:#EBF5FB;color:%s;border-radius:4px;padding:2px 7px;font-size:10px;font-weight:600;">Full</span>', brand_colour)
    else
      '<span style="background:#f1f5f9;color:#94a3b8;border-radius:4px;padding:2px 7px;font-size:10px;font-weight:500;">Awareness only</span>'

    row_style <- if (depth == "awareness_only") ' style="color:#94a3b8;"' else ""

    parts <- c(parts, sprintf(
      '<tr%s><td style="font-weight:%s;">%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
      row_style,
      if (depth == "full") "600" else "400",
      .br_esc(cat_name),
      depth_badge,
      awareness_str, mms_str, mpen_str, ns_str))
  }

  parts <- c(parts, '</tbody></table></div>')

  # Metric legend
  parts <- c(parts, '
<div style="margin-top:12px;font-size:11px;color:#94a3b8;display:flex;gap:16px;flex-wrap:wrap;">
  <span><strong>Awareness</strong> = % category buyers who have heard of the brand</span>
  <span><strong>MMS</strong> = Mental Market Share (share of all brand-CEP links)</span>
  <span><strong>MPen</strong> = Mental Penetration (% buyers linking \u22651 CEP)</span>
  <span><strong>NS</strong> = Network Size (mean CEPs per linking buyer)</span>
</div>')

  parts <- c(parts, '</div>')  # element-section

  # --- Future sections placeholder ---
  parts <- c(parts, '
<div class="br-element-section" style="margin-top:16px;">
  <h3 class="br-element-title">Portfolio Optimisation \u2014 Coming Soon</h3>
  <p style="font-size:13px;color:#64748b;line-height:1.6;">
    Future versions will add:
  </p>
  <ul style="font-size:13px;color:#64748b;line-height:2;padding-left:20px;">
    <li>Awareness-indexed MMS to compare mental availability efficiency across categories</li>
    <li>Category investment prioritisation matrix (market size \u00d7 brand strength)</li>
    <li>Cross-category CEP overlap analysis (which entry points span multiple categories)</li>
    <li>Portfolio growth opportunity scoring</li>
  </ul>
</div>')

  parts <- c(parts, '</div>')  # section
  parts <- c(parts, '</div>')  # panel

  paste(parts, collapse = "\n")
}


#' Build pinned views panel
#' @keywords internal
build_br_pinned_panel <- function() {
  '
<div class="br-panel" id="panel-pinned">
  <div style="max-width:1400px;margin:0 auto;padding:20px 0;">
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
      <div>
        <h2 style="font-size:18px;font-weight:700;color:#1e293b;margin:0 0 4px;">Pinned Views</h2>
        <p style="font-size:12px;color:#64748b;margin:0;">Pin charts and tables to build a curated set of key findings.</p>
      </div>
      <div style="display:flex;gap:8px;">
        <button class="br-action-btn" onclick="brAddSection()" style="background:#fff;border:1px solid #e2e8f0;border-radius:6px;padding:6px 12px;cursor:pointer;font-size:12px;color:#64748b;">&#x2795; Add Section</button>
        <button class="br-action-btn" onclick="brExportAllPinned()" style="background:#fff;border:1px solid #e2e8f0;border-radius:6px;padding:6px 12px;cursor:pointer;font-size:12px;color:#64748b;">&#x1F4E4; Export All</button>
      </div>
    </div>
    <div id="br-pinned-cards-container"></div>
    <div id="br-pinned-empty" style="text-align:center;padding:60px 20px;color:#94a3b8;">
      <div style="font-size:36px;margin-bottom:12px;">&#x1F4CC;</div>
      <div style="font-size:14px;font-weight:600;">No pinned views yet.</div>
      <div style="font-size:12px;margin-top:4px;">Click the pin icon on any section to add views here.</div>
    </div>
    <script type="application/json" id="br-pinned-views-data">[]</script>
  </div>
</div>'
}


#' Build about panel
#' @keywords internal
build_br_about_panel <- function(config) {
  sprintf('
<div class="br-panel" id="panel-about">
  <div class="br-section" style="max-width:800px;">
    <h2 style="font-size:20px;color:#1e293b;margin:0 0 16px;">About & Methodology</h2>
    <div style="font-size:13px;line-height:1.7;color:#475569;">
      <p>This report uses the <strong>Category Buyer Mindset (CBM)</strong> framework
      developed by Jenni Romaniuk at the Ehrenberg-Bass Institute for Marketing Science.</p>

      <h3 style="font-size:15px;color:%s;margin:20px 0 8px;">Mental Availability</h3>
      <p><strong>Mental Market Share (MMS)</strong> measures the brand&rsquo;s share of all
      brand&ndash;CEP links in the category. <strong>Mental Penetration (MPen)</strong> measures
      the proportion of category buyers who link the brand to at least one Category Entry Point.
      <strong>Network Size (NS)</strong> measures the average number of CEPs linked among those
      who link at least one.</p>

      <h3 style="font-size:15px;color:%s;margin:20px 0 8px;">Brand Funnel</h3>
      <p>Funnel stages are derived from core CBM data, not from sequential funnel questions.
      The 5-level attitude scale provides richer diagnostics than traditional binary consideration.
      Rejection is captured explicitly (attitude code 4).</p>

      <h3 style="font-size:15px;color:%s;margin:20px 0 8px;">References</h3>
      <ul style="padding-left:20px;">
        <li>Romaniuk, J. (2022). <em>Better Brand Health</em>. Oxford University Press.</li>
        <li>Sharp, B. (2010). <em>How Brands Grow</em>. Oxford University Press.</li>
        <li>Romaniuk, J. &amp; Sharp, B. (2016). <em>How Brands Grow Part 2</em>. Oxford University Press.</li>
        <li>Romaniuk, J. (2018). <em>Building Distinctive Brand Assets</em>. Oxford University Press.</li>
      </ul>

      <p style="margin-top:20px;font-size:11px;color:#94a3b8;">Report generated by TURAS Analytics Platform v%s on %s.</p>
    </div>
  </div>
</div>',
    config$colour_focal %||% "#1A5276",
    config$colour_focal %||% "#1A5276",
    config$colour_focal %||% "#1A5276",
    "1.0", format(Sys.time(), "%d %B %Y at %H:%M"))
}


#' Build help overlay
#' @keywords internal
build_br_help_overlay <- function() {
  '
<div id="br-help-overlay" class="br-help-overlay" onclick="if(event.target===this)_brToggleHelp()">
  <div class="br-help-card" style="background:#fff;border-radius:12px;padding:24px 28px;max-width:500px;margin:80px auto;box-shadow:0 20px 60px rgba(0,0,0,0.15);font-size:13px;line-height:1.6;color:#475569;position:relative;">
    <button onclick="_brToggleHelp()" style="position:absolute;top:12px;right:16px;background:none;border:none;font-size:20px;cursor:pointer;color:#94a3b8;">&times;</button>
    <h3 style="margin:0 0 12px;font-size:16px;color:#1e293b;">Report Guide</h3>
    <p><strong>Navigation:</strong> Use the tabs to switch between categories and elements. Sub-tabs within each category show different analytical views.</p>
    <p><strong>Pin:</strong> Click &#x1F4CC; on any section to pin charts/tables to the Pinned Views tab for presentation building.</p>
    <p><strong>Insight:</strong> Click &ldquo;+ Add Insight&rdquo; to annotate any section with your analysis. Double-click the rendered text to edit.</p>
    <p><strong>Export:</strong> Click &ldquo;Export&rdquo; to download section data as Excel. &ldquo;Save Report&rdquo; downloads the full HTML.</p>
    <p><strong>Sort:</strong> Click any table column header to sort ascending/descending.</p>
  </div>
</div>'
}


# ==============================================================================
# MAIN PAGE ASSEMBLY
# ==============================================================================

#' Assemble the full brand HTML page
#'
#' @param results List. Output from run_brand().
#' @param charts Named list. Chart SVGs keyed by element_catid.
#' @param tables Named list. Table HTML keyed by element_catid.
#' @param config List. Brand config.
#' @param brand_js Character. Module JS code.
#' @param pins_js Character. TurasPins JS code.
#'
#' @return Character. Complete HTML document.
#' @keywords internal
build_brand_page <- function(results, charts, tables, config,
                              brand_js = "", pins_js = "",
                              panels = list(), panel_styles = "",
                              panel_js = "") {

  brand_colour <- config$colour_focal %||% "#1A5276"
  accent_colour <- config$colour_focal_accent %||% "#2E86C1"

  # --- CSS ---
  base_css <- ""
  if (exists("turas_base_css", mode = "function")) {
    base_css <- tryCatch(
      turas_base_css(brand_colour = brand_colour, accent_colour = accent_colour),
      error = function(e) ""
    )
  }

  module_css <- sprintf('
:root { --br-brand: %s; --br-accent: %s; --brand-colour: %s; }
body { background: #f8f7f5; margin: 0; padding: 0; }
.br-container { max-width: 1200px; margin: 0 auto; padding: 0 32px 60px; }
.br-tab-nav {
  position: sticky; top: 0; z-index: 100; background: #fff;
  border-bottom: 1px solid #e2e8f0; padding: 0 32px;
  display: flex; gap: 0; overflow-x: auto; white-space: nowrap;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}
.br-tab-btn {
  background: none; border: none; border-bottom: 3px solid transparent;
  padding: 12px 18px; font-size: 13px; font-weight: 500; color: #64748b;
  cursor: pointer; transition: all 0.15s; white-space: nowrap;
}
.br-tab-btn:hover { color: #1e293b; background: #f8f9fa; }
.br-tab-btn.active { color: %s; border-bottom-color: %s; font-weight: 600; }
.br-pin-badge {
  background: %s; color: #fff; border-radius: 10px; padding: 1px 6px;
  font-size: 10px; font-weight: 700; margin-left: 4px; display: inline-block;
  min-width: 16px; text-align: center;
}
.br-panel { display: none; padding: 24px 0; }
.br-panel.active { display: block; }
.br-subtab-nav {
  display: flex; gap: 0; border-bottom: 1px solid #e2e8f0; margin-bottom: 20px;
}
.br-subtab-btn {
  background: none; border: none; border-bottom: 2px solid transparent;
  padding: 10px 16px; font-size: 12px; font-weight: 500; color: #94a3b8;
  cursor: pointer; transition: all 0.15s;
}
.br-subtab-btn.active { color: %s; border-bottom-color: %s; }
.br-subtab-btn:hover { color: #64748b; }
.br-subpanel { display: none; }
.br-subpanel.active { display: block; }
.br-section { margin-bottom: 24px; }
.br-element-section {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
  padding: 20px 24px; margin-bottom: 16px; position: relative;
}
.br-element-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 0 0 12px; }
.br-table { width: 100%%; border-collapse: collapse; font-size: 12px; }
.br-table th {
  background: #f8f9fa; color: #64748b; font-weight: 600; font-size: 11px;
  text-transform: uppercase; letter-spacing: 0.5px; padding: 8px 12px;
  border-bottom: 2px solid #e2e8f0; text-align: left; cursor: pointer;
  user-select: none; white-space: nowrap;
}
.br-table td { padding: 8px 12px; border-bottom: 1px solid #f0f0f0; color: #334155; }
.br-table tr:hover td { background: #f8f9fb; }
.br-table .focal-row { background: #EBF5FB !important; font-weight: 600; }
.br-table .focal-row td { color: %s; }
.br-chart-wrapper:hover .br-chart-pin-btn { opacity: 1; }
.pin-flash { animation: br-flash 0.6s ease; }
@keyframes br-flash { 0%%,100%% { transform:scale(1); } 50%% { transform:scale(1.3); color:%s; } }
.br-help-overlay {
  display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.4); z-index: 1000;
}
.br-help-overlay.open { display: block; }
/* 2-layer nav: internal panel sub-navbars are hidden — their tabs are
   promoted to the category-level .br-subtab-nav. The internal nav HTML
   is kept in the DOM so JS click-dispatch still works. */
.fn-subnav, .ma-subnav { display: none !important; }
@media print {
  .br-tab-nav, .br-section-toolbar, .br-insight-container,
  .br-chart-pin-btn, .br-save-btn, .br-help-btn { display: none !important; }
  .br-panel { display: block !important; page-break-inside: avoid; }
  .br-subpanel { display: block !important; }
}
  ', brand_colour, accent_colour, brand_colour,
     brand_colour, brand_colour, brand_colour,
     brand_colour, brand_colour,
     brand_colour, brand_colour)

  # --- Panels ---
  category_names <- names(results$results$categories)
  # Only include deep-dive categories (those with MA data)
  deep_cats <- character(0)
  for (cn in category_names) {
    cr <- results$results$categories[[cn]]
    has_content <- !is.null(cr$mental_availability) || !is.null(cr$funnel)
    if (has_content) deep_cats <- c(deep_cats, cn)
  }

  # panel_parts = accumulator of per-panel HTML fragments
  # (disambiguated from the `panels` parameter which is a lookup keyed by
  # element_categoryid for dedicated role-registry panel HTML).
  panel_parts <- character(0)
  panel_parts <- c(panel_parts, build_br_summary_panel(results, config))

  for (cat_name in deep_cats) {
    panel_parts <- c(panel_parts, build_br_category_panel(
      cat_name, results$results$categories[[cat_name]],
      charts, tables, config, panels = panels
    ))
  }

  # Brand-level panels
  if (isTRUE(config$element_dba) && !is.null(results$results$dba)) {
    dba_id <- "dba"
    panel_parts <- c(panel_parts, sprintf(
      '<div class="br-panel" id="panel-dba"><div class="br-element-section" id="section-%s" data-section="%s">%s',
      dba_id, dba_id, build_br_section_toolbar(dba_id)))
    if (!is.null(charts[["dba"]])) {
      for (ch in charts[["dba"]]) {
        panel_parts <- c(panel_parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
      }
    }
    if (!is.null(tables[["dba"]])) panel_parts <- c(panel_parts, tables[["dba"]])
    panel_parts <- c(panel_parts, '</div></div>')
  }

  # WOM is now per-category (sub-tab inside each category panel).
  # No brand-level WOM panel.

  if (isTRUE(config$element_portfolio))
    panel_parts <- c(panel_parts, build_br_portfolio_panel(results, config))

  panel_parts <- c(panel_parts, build_br_pinned_panel())
  panel_parts <- c(panel_parts, build_br_about_panel(config))

  # --- Assemble page ---
  sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="turas-report-type" content="brand">
  <meta name="turas-source-filename" content="%s">
  <title>%s</title>
  <style>%s\n%s</style>
  %s
</head>
<body>
  %s
  %s
  <div class="br-container">%s</div>
  %s
  %s
  <script>%s</script>
  <script>%s</script>
  <script>%s</script>
</body>
</html>',
    .br_esc(config$report_title %||% "brand_report"),
    .br_esc(config$report_title %||% "Brand Health Report"),
    base_css, module_css,
    panel_styles,
    build_br_header(config),
    build_br_tab_nav(deep_cats, config),
    paste(panel_parts, collapse = "\n"),
    build_br_help_overlay(),
    "",
    pins_js,
    brand_js,
    panel_js
  )
}
