# ==============================================================================
# BRAND MODULE - MENTAL AVAILABILITY PANEL HTML RENDERER
# ==============================================================================
# Consumes build_ma_panel_data() output and emits a self-contained
# HTML fragment for one category's Mental Availability tab.
#
# Three sub-tabs share the same visual contract (ct-* table classes,
# brands-as-columns, heatmap variation vs category average, chips, pins):
#   - Attributes  (brand-image attribute x brand)
#   - CEPs        (CEP x brand linkage; base toggle: total / % aware)
#   - Metrics     (MPen / NS / MMS + CEP penetration ranking)
#
# Visual classes are shared with the funnel panel where possible so the
# two panels feel like a single design language. MA-specific additions
# use the `.ma-*` prefix.
#
# Sub-renderers:
#   02_ma_panel_table.R    — attribute/CEP matrix table (brands-as-columns)
#   02_ma_panel_chart.R    — MMS/MPen/NS summary charts + CEP ranking bar
#   02_ma_panel_styling.R  — MA-specific CSS bundle
#
# Interaction JS: js/brand_ma_panel.js (loaded once per report).
# VERSION: 1.0
# ==============================================================================

BRAND_MA_PANEL_VERSION <- "1.0"


#' Build the Mental Availability panel HTML fragment
#'
#' @param panel_data List from \code{build_ma_panel_data()}.
#' @param category_code Character. Used to scope element ids on the page.
#' @param focal_colour Character. Hex colour for the focal brand.
#' @param excel_filename Optional Excel filename (relative to the HTML
#'   file) for the Export button.
#'
#' @return Character. A single HTML fragment (string).
#' @export
build_ma_panel_html <- function(panel_data, category_code = "cat",
                                focal_colour = "#1A5276",
                                excel_filename = NULL) {
  if (is.null(panel_data) || is.null(panel_data$meta) ||
      length(panel_data$meta) == 0 ||
      (is.null(panel_data$ceps) && is.null(panel_data$attributes))) {
    return('<div class="ma-panel-empty">Mental Availability not available for this category.</div>')
  }

  panel_id <- paste0("ma-", category_code)
  json_payload <- .ma_panel_json(panel_data, focal_colour)
  excel_attr <- if (!is.null(excel_filename) && nzchar(excel_filename))
    sprintf(' data-ma-excel-filename="%s"', .ma_esc(excel_filename)) else ""

  has_attrs <- !is.null(panel_data$attributes) &&
               length(panel_data$attributes$codes) > 0
  has_ceps  <- !is.null(panel_data$ceps) &&
               length(panel_data$ceps$codes) > 0
  has_advantage <- !is.null(panel_data$advantage) &&
                    length(panel_data$advantage$available_stims) > 0

  # Default tab: attributes first if present, else CEPs
  default_tab <- if (has_attrs) "attributes" else "ceps"

  paste0(
    sprintf('<div class="ma-panel" id="%s" data-focal-colour="%s" style="--ma-brand:%s"%s>',
            panel_id, focal_colour, focal_colour, excel_attr),
    sprintf('<script type="application/json" class="ma-panel-data">%s</script>',
            json_payload),
    .ma_sub_tabs(has_attrs, has_ceps, default_tab, has_advantage = has_advantage),
    .ma_focus_bar(panel_data),

    if (has_attrs) paste0(
      sprintf('<div class="ma-subtab" data-ma-subtab="attributes"%s>',
              if (default_tab != "attributes") " hidden" else ""),
      .ma_controls_bar(panel_data, stim = "attributes"),
      .ma_matrix_section(panel_data, stim = "attributes",
                         focal_colour = focal_colour),
      .ma_chart_placeholder(stim = "attributes", pd = panel_data),
      .ma_insight_box(stim = "attributes"),
      '</div>'
    ) else "",

    if (has_ceps) paste0(
      sprintf('<div class="ma-subtab" data-ma-subtab="ceps"%s>',
              if (default_tab != "ceps") " hidden" else ""),
      .ma_controls_bar(panel_data, stim = "ceps"),
      .ma_matrix_section(panel_data, stim = "ceps",
                         focal_colour = focal_colour),
      .ma_chart_placeholder(stim = "ceps", pd = panel_data),
      .ma_insight_box(stim = "ceps"),
      '</div>'
    ) else "",

    if (has_advantage) paste0(
      '<div class="ma-subtab" data-ma-subtab="advantage" hidden>',
      build_ma_advantage_section(panel_data, focal_colour = focal_colour),
      '</div>'
    ) else "",

    '<div class="ma-subtab" data-ma-subtab="metrics" hidden>',
      .ma_metrics_section(panel_data, focal_colour = focal_colour),
      .ma_insight_box(stim = "metrics"),
    '</div>',

    # Panel-wide "About Mental Availability" drawer. Only shows for
    # non-advantage tabs; the advantage tab carries its own Mental
    # Advantage callout at the bottom of its own subtab.
    sprintf('<div class="ma-about-availability">%s</div>', .ma_about_section(panel_data)),
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: SUB-TAB NAV + FOCUS BAR
# ==============================================================================

.ma_sub_tabs <- function(has_attrs, has_ceps, default_tab, has_advantage = FALSE) {
  tabs <- character(0)
  if (has_attrs) tabs <- c(tabs, list(list(
    key = "attributes", label = "Brand Attributes")))
  if (has_ceps) tabs <- c(tabs, list(list(
    key = "ceps", label = "Category Entry Points")))
  if (has_advantage) tabs <- c(tabs, list(list(
    key = "advantage", label = "Mental Advantage")))
  tabs <- c(tabs, list(list(key = "metrics", label = "Headline Metrics")))

  btns <- paste(vapply(tabs, function(t) {
    active <- if (identical(t$key, default_tab)) " active" else ""
    aria <- if (identical(t$key, default_tab)) "true" else "false"
    sprintf(
      '<button type="button" class="ma-subtab-btn%s" data-ma-subtab-target="%s" role="tab" aria-selected="%s">%s</button>',
      active, t$key, aria, .ma_esc(t$label))
  }, character(1)), collapse = "")

  paste0(
    '<nav class="ma-subnav" role="tablist" aria-label="Mental Availability sections">',
    btns, '</nav>'
  )
}


.ma_focus_bar <- function(pd) {
  brand_codes <- pd$config$brand_codes %||% character(0)
  brand_names <- pd$config$brand_names %||% brand_codes
  focal <- pd$meta$focal_brand_code %||% brand_codes[1]

  focus_options <- paste(vapply(seq_along(brand_codes), function(i) {
    sel <- if (brand_codes[i] == focal) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .ma_esc(brand_codes[i]), sel, .ma_esc(brand_names[i]))
  }, character(1)), collapse = "")

  sprintf(
    '<div class="ma-focus-bar">
       <label class="ma-ctl-label">Focal brand</label>
       <select class="ma-focus-select" data-ma-action="focus">%s</select>
     </div>',
    focus_options)
}


# ==============================================================================
# INTERNAL: CONTROLS BAR (per matrix tab)
# ==============================================================================

.ma_controls_bar <- function(pd, stim = c("attributes", "ceps")) {
  stim <- match.arg(stim)
  brand_codes <- pd$config$brand_codes %||% character(0)
  brand_names <- pd$config$brand_names %||% brand_codes
  focal <- pd$meta$focal_brand_code %||% brand_codes[1]

  # Sort: focal first, then alphabetical by brand name
  sorted_order <- order(brand_codes != focal, tolower(brand_names))
  brand_codes  <- brand_codes[sorted_order]
  brand_names  <- brand_names[sorted_order]

  chips_html <- paste(c(
    sprintf('<button type="button" class="col-chip" data-ma-scope="%s" data-ma-brand="__avg__">Cat avg</button>',
            .ma_esc(stim)),
    vapply(seq_along(brand_codes), function(i) {
      sprintf('<button type="button" class="col-chip" data-ma-scope="%s" data-ma-brand="%s">%s</button>',
              .ma_esc(stim), .ma_esc(brand_codes[i]), .ma_esc(brand_names[i]))
    }, character(1)),
    sprintf('<button type="button" class="ma-all-toggle" data-ma-action="toggleall" data-ma-scope="%s">Hide all</button>',
            .ma_esc(stim))
  ), collapse = "")

  block <- if (stim == "attributes") pd$attributes else pd$ceps
  has_aware <- !is.null(block) && !is.null(block$awareness_by_brand)

  base_switcher <- if (has_aware) {
    paste0(
      '<div class="sig-level-switcher" role="group" aria-label="Percentage base">',
      '<span class="sig-level-label">Base:</span>',
      sprintf('<button type="button" class="sig-btn" data-ma-action="basemode" data-ma-stim="%s" data-ma-basemode="aware" aria-pressed="false">%% aware</button>', stim),
      sprintf('<button type="button" class="sig-btn sig-btn-active" data-ma-action="basemode" data-ma-stim="%s" data-ma-basemode="total" aria-pressed="true">%% total</button>', stim),
      '</div>'
    )
  } else ""

  heatmap_switcher <- sprintf(
    '<label class="toggle-label"><input type="checkbox" checked data-ma-action="heatmapmode" data-ma-stim="%s"> Show heatmap</label>',
    stim
  )

  paste0(
    '<div class="ma-controls controls-bar">',
    '<div class="ma-ctl-group"><span class="ma-ctl-label">Show brands</span>',
    sprintf('<div class="ma-chip-row col-chip-bar" data-ma-scope="%s">%s</div></div>',
            stim, chips_html),
    '<div class="ma-meta-row">',
    base_switcher,
    heatmap_switcher,
    sprintf('<label class="toggle-label"><input type="checkbox" data-ma-action="showcounts" data-ma-stim="%s"> Show count</label>', stim),
    sprintf('<label class="toggle-label"><input type="checkbox" checked data-ma-action="showchart" data-ma-stim="%s"> Show chart</label>', stim),
    '<button type="button" class="export-btn ma-pin-dropdown-btn" data-ma-action="pindropdown" title="Pin a section" aria-haspopup="true">&#128204; Pin &#9662;</button>',
    '<button type="button" class="export-btn ma-png-btn" onclick="brExportPngFromEl(this)" title="Export view to PNG">&#x1F5BC; PNG</button>',
    sprintf('<button type="button" class="export-btn ma-export-btn" data-ma-action="exporttable" data-ma-stim="%s" title="Export table to Excel">\u2B73 Excel \u25BE</button>',
            stim),
    '</div>',
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: SECTION SLOTS
# ==============================================================================

.ma_matrix_section <- function(pd, stim, focal_colour) {
  build_ma_matrix_section(pd, stim = stim, focal_colour = focal_colour)
}


.ma_metrics_section <- function(pd, focal_colour) {
  build_ma_metrics_section(pd, focal_colour = focal_colour)
}


.ma_add_insight_strip <- function() {
  '<div class="ma-add-insight-strip">
     <button type="button" class="ma-add-insight-btn" data-ma-action="add-insight">
       + Add Insight
     </button>
   </div>'
}


#' Dot chart scaffold with per-chart brand chips — populated by brand_ma_panel.js.
#' @keywords internal
.ma_chart_placeholder <- function(stim, pd) {
  brand_codes <- pd$config$brand_codes %||% character(0)
  brand_names <- pd$config$brand_names %||% brand_codes

  chips_html <- paste(c(
    vapply(seq_along(brand_codes), function(i) {
      sprintf(
        '<button type="button" class="col-chip chart-chip" data-ma-chart-scope="%s" data-ma-brand="%s">%s</button>',
        stim, .ma_esc(brand_codes[i]), .ma_esc(brand_names[i]))
    }, character(1)),
    sprintf('<button type="button" class="ma-all-toggle" data-ma-chart-action="toggleall" data-ma-chart-scope="%s">Hide all</button>',
            .ma_esc(stim))
  ), collapse = "")

  sprintf(
    '<section class="ma-chart-section" data-ma-stim="%s">
       <div class="ma-chart-chip-bar ma-chip-row" data-ma-chart-scope="%s">%s</div>
       <div class="ma-chart-legend"></div>
       <svg class="ma-bar-chart" data-ma-stim="%s" xmlns="http://www.w3.org/2000/svg"></svg>
     </section>',
    stim, stim, chips_html, stim)
}


#' Full-width editable insight box below the chart.
#' @keywords internal
.ma_insight_box <- function(stim) {
  sprintf(
    '<section class="ma-insight-box" data-ma-stim="%s">
       <div class="ma-insight-box-header">
         <span class="ma-insight-box-title">Insight</span>
         <button type="button" class="ma-insight-box-clear" data-ma-action="clear-insight" data-ma-stim="%s" title="Clear">&#215;</button>
       </div>
       <textarea class="ma-insight-box-text" data-ma-stim="%s" placeholder="Write the headline for this chart (one or two sentences)…"></textarea>
     </section>',
    stim, stim, stim)
}


# ==============================================================================
# INTERNAL: ABOUT DRAWER
# ==============================================================================

.ma_about_section <- function(pd) {
  a <- pd$about
  if (is.null(a)) return("")
  parts <- character(0)
  for (key in c("methodology_note", "mpen_note", "ns_note", "mms_note",
                "attribute_note", "base_note")) {
    val <- a[[key]]
    if (!is.null(val) && nzchar(trimws(val))) {
      parts <- c(parts, sprintf(
        '<p class="ma-about-item"><strong>%s:</strong> %s</p>',
        .ma_about_heading(key), .ma_esc(val)))
    }
  }
  # Metric formulas (always shown)
  parts <- c(parts, paste0(
    '<div class="ma-about-formulas">',
    '<p class="ma-about-item"><strong>Metric formulas</strong></p>',
    '<dl class="ma-formula-dl">',
    '<dt>Mental Penetration (MPen)</dt>',
    '<dd>Respondents linking brand to \u22651 CEP &divide; Total respondents &times; 100</dd>',
    '<dt>Network Size (NS)</dt>',
    '<dd>Total CEP links for brand &divide; Respondents linking \u22651 CEP (average depth)</dd>',
    '<dt>Mental Market Share (MMS)</dt>',
    '<dd>(MPen &times; NS) &divide; &Sigma;(MPen<sub>i</sub> &times; NS<sub>i</sub>) &times; 100 &mdash; brand\u2019s share of all category CEP associations</dd>',
    '<dt>Share of Mind (SOM)</dt>',
    '<dd>MMS &divide; MPen &times; 100 &mdash; CEP links as % of all links by buyers with MPen for that brand. Totals across brands exceed 100%.</dd>',
    '<dt>Cat avg CI (mini bar)</dt>',
    '<dd>For each stimulus row, take the brand values (v<sub>1</sub>\u2026v<sub>n</sub>), compute mean <em>m</em> and standard deviation <em>SD</em>, ',
    'then <strong>SE = SD &divide; &radic;n</strong> and the <strong>95% CI = m &plusmn; 1.96 &times; SE</strong>. ',
    'The shaded range on the mini bar spans lo\u2013hi; the tick marks the mean; labels below show the bounds. ',
    'Interprets the brand values at a stimulus as a sample, so the CI narrows as more brands link to that CEP.</dd>',
    '</dl></div>'
  ))
  if (length(parts) == 0) return("")
  paste0(
    '<details class="ma-about"><summary class="ma-about-summary">About Mental Availability</summary>',
    '<div class="ma-about-body">',
    paste(parts, collapse = ""),
    '</div></details>'
  )
}


.ma_about_heading <- function(key) {
  switch(key,
    methodology_note = "Framework",
    mpen_note        = "Mental Penetration (MPen)",
    ns_note          = "Network Size (NS)",
    mms_note         = "Mental Market Share (MMS)",
    attribute_note   = "Brand Attributes",
    base_note        = "Bases",
    key)
}


# ==============================================================================
# INTERNAL: HELPERS
# ==============================================================================

.ma_panel_json <- function(pd, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  payload <- list(
    meta       = pd$meta,
    attributes = pd$attributes,
    ceps       = pd$ceps,
    metrics    = pd$metrics,
    advantage  = pd$advantage,
    config     = pd$config,
    focal_colour = focal_colour
  )
  jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null",
                   pretty = FALSE, digits = 6)
}


.ma_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
