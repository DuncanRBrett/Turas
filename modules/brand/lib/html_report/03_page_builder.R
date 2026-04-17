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
<div class="br-header" style="background:linear-gradient(135deg,%s 0%%,%s 100%%);color:#fff;padding:20px 32px;border-radius:0 0 12px 12px;">
  <div style="display:flex;justify-content:space-between;align-items:flex-start;">
    <div>
      <div style="font-size:11px;text-transform:uppercase;letter-spacing:1.5px;opacity:0.7;margin-bottom:4px;">Turas Brand Health</div>
      <h1 style="margin:0;font-size:22px;font-weight:700;">%s</h1>
      <div style="font-size:13px;opacity:0.8;margin-top:2px;">%s</div>
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
    brand, adjustcolor(brand, offset = c(0.15, 0.15, 0.15, 0)),
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
  if (isTRUE(config$element_wom))
    btns <- c(btns, '<button class="br-tab-btn" data-tab="wom" onclick="switchBrandTab(\'wom\')">Word-of-Mouth</button>')
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


#' Build a category panel with sub-tabs for each element
#' @keywords internal
build_br_category_panel <- function(cat_name, cat_results, charts, tables,
                                     config, panels = list()) {
  cat_id <- gsub("[^a-z0-9]", "-", tolower(cat_name))
  panel_id <- paste0("cat-", cat_id)
  focal <- config$focal_brand %||% ""

  parts <- character(0)
  parts <- c(parts, sprintf('<div class="br-panel" id="panel-%s">', panel_id))
  parts <- c(parts, sprintf('<h2 style="font-size:20px;color:#1e293b;margin:0 0 8px;">%s</h2>', .br_esc(cat_name)))

  # Sub-tab navigation
  elements <- character(0)
  if (!is.null(cat_results$mental_availability) &&
      !identical(cat_results$mental_availability$status, "REFUSED"))
    elements <- c(elements, "ma")
  if (!is.null(cat_results$funnel) &&
      !identical(cat_results$funnel$status, "REFUSED"))
    elements <- c(elements, "funnel")
  if (!is.null(cat_results$repertoire) &&
      !identical(cat_results$repertoire$status, "REFUSED"))
    elements <- c(elements, "repertoire")
  if (!is.null(cat_results$drivers_barriers) &&
      !identical(cat_results$drivers_barriers$status, "REFUSED"))
    elements <- c(elements, "db")

  if (length(elements) > 1) {
    elem_labels <- c(ma = "Mental Availability", funnel = "Funnel",
                     repertoire = "Repertoire", db = "Drivers & Barriers")
    subtab_btns <- vapply(seq_along(elements), function(i) {
      el <- elements[i]
      active <- if (i == 1) " active" else ""
      sprintf('<button class="br-subtab-btn%s" data-group="%s" data-subtab="%s" onclick="switchCategorySubtab(this)">%s</button>',
              active, cat_id, el, elem_labels[el])
    }, character(1))
    parts <- c(parts, sprintf('<div class="br-subtab-nav">%s</div>',
                                paste(subtab_btns, collapse = "\n")))
  }

  # Sub-panels
  for (i in seq_along(elements)) {
    el <- elements[i]
    active <- if (i == 1) " active" else ""
    section_id <- paste0(el, "-", cat_id)
    parts <- c(parts, sprintf('<div class="br-subpanel%s" data-group="%s" data-subpanel="%s">',
                                active, cat_id, el))
    parts <- c(parts, sprintf('<div class="br-element-section" id="section-%s" data-section="%s">',
                                section_id, section_id))
    parts <- c(parts, build_br_section_toolbar(section_id))

    # If a dedicated panel HTML was emitted (funnel — role-registry
    # architecture), render that instead of the generic charts+tables
    # block. Falls back to the legacy chart/table rendering otherwise.
    chart_key <- paste0(el, "_", cat_id)
    if (!is.null(panels[[chart_key]])) {
      parts <- c(parts, panels[[chart_key]])
    } else {
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

      <h3 style="font-size:15px;color:%s;margin:20px 0 8px;">Drivers &amp; Barriers</h3>
      <p>Attribute importance is derived statistically from the relationship between CEP linkage
      and buying behaviour. This is methodologically stronger than asking respondents to rate
      importance directly.</p>

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

  if (isTRUE(config$element_wom) && !is.null(results$results$wom)) {
    wom_id <- "wom"
    panel_parts <- c(panel_parts, sprintf(
      '<div class="br-panel" id="panel-wom"><div class="br-element-section" id="section-%s" data-section="%s">%s',
      wom_id, wom_id, build_br_section_toolbar(wom_id)))
    if (!is.null(charts[["wom"]])) {
      for (ch in charts[["wom"]]) {
        panel_parts <- c(panel_parts, build_br_chart_wrapper(ch$svg, ch$title %||% ""))
      }
    }
    if (!is.null(tables[["wom"]])) panel_parts <- c(panel_parts, tables[["wom"]])
    panel_parts <- c(panel_parts, '</div></div>')
  }

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
