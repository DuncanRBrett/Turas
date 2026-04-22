# ==============================================================================
# BRAND MODULE - FUNNEL PANEL HTML RENDERER (FUNNEL_SPEC_v2 §6)
# ==============================================================================
# Consumes build_funnel_panel_data() output and emits a self-contained
# HTML fragment for one category's funnel tab.
#
# Visual contract: this panel reuses the tabs module's ct-* CSS classes
# verbatim so the funnel card looks identical to a tabs crosstab card.
# The only funnel-specific CSS lives in 03_funnel_panel_styling.R and
# covers things tabs doesn't express (sub-tab nav, focus dropdown,
# stage-definition popovers, stacked attitude bars).
#
# Interaction JS: js/brand_funnel_panel.js (loaded once per report).
#
# Sub-renderers:
#   03_funnel_panel_table.R     — ct-table heatmap
#   03_funnel_panel_chart.R     — slope chart + consideration detail
#   03_funnel_panel_styling.R   — CSS bundle
#
# VERSION: 2.0
# ==============================================================================

BRAND_FUNNEL_PANEL_VERSION <- "2.0"


# ==============================================================================
# PUBLIC: build_funnel_panel_html
# ==============================================================================

#' Build the funnel panel HTML fragment
#'
#' @param panel_data List from \code{build_funnel_panel_data()}.
#' @param category_code Character. Used to scope element ids on the page.
#' @param focal_colour Character. Hex colour for the focal brand. Defaults
#'   to Turas navy.
#' @param excel_filename Character or NULL. Path (relative to the HTML file)
#'   of the dedicated funnel Excel workbook. When set, the Export button
#'   downloads this file; when NULL the button alerts with a setup hint.
#'
#' @return Character. A single HTML fragment (string).
#' @export
build_funnel_panel_html <- function(panel_data, category_code = "cat",
                                    focal_colour = "#1A5276",
                                    excel_filename = NULL) {
  if (is.null(panel_data) || is.null(panel_data$meta) ||
      length(panel_data$meta) == 0) {
    return('<div class="fn-panel-empty">Funnel not available for this category.</div>')
  }

  panel_id <- paste0("fn-", category_code)
  json_payload <- .funnel_panel_json(panel_data, focal_colour)
  excel_attr <- if (!is.null(excel_filename) && nzchar(excel_filename))
    sprintf(' data-fn-excel-filename="%s"', .fn_esc(excel_filename)) else ""

  paste0(
    sprintf('<div class="fn-panel" id="%s" data-focal-colour="%s"%s>',
            panel_id, focal_colour, excel_attr),
    sprintf('<script type="application/json" class="fn-panel-data">%s</script>',
            json_payload),
    .fn_sub_tabs(),
    .fn_focus_bar(panel_data),
    '<div class="fn-subtab" data-fn-subtab="summary" hidden>',
      .fn_cards_section(panel_data, focal_colour),
    '</div>',
    '<div class="fn-subtab" data-fn-subtab="funnel">',
      .fn_table_controls(panel_data),
      .fn_table_section(panel_data, focal_colour),
      '<div class="fn-chart-wrap-outer">',
        .fn_chart_header(panel_data),
        '<div class="fn-chart-view" data-fn-view="slope">',
          '<div class="fn-aware-note" style="display:none;font-size:11px;color:#64748b;padding:4px 8px 0;font-style:italic;">Awareness pinned to 100%. Chart shows conversion efficiency from awareness.</div>',
          .fn_chart_section(panel_data, focal_colour),
        '</div>',
        '<div class="fn-mf-section-heading">Mini Funnels</div>',
        '<div class="fn-mini-funnels-view" data-fn-view="minifunnels"></div>',
      '</div>',
      .fn_add_insight_strip(),
    '</div>',
    '<div class="fn-subtab" data-fn-subtab="relationship" hidden>',
      .fn_relationship_section(panel_data, focal_colour),
    '</div>',
    .fn_about_section(panel_data),
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: TITLE CARD + SUB-TAB NAV
# ==============================================================================

.fn_title_card <- function(pd) {
  meta <- pd$meta
  n_u <- meta$n_unweighted %||% NA
  wave <- meta$wave_label %||% ""
  sub_parts <- character(0)
  if (!is.null(meta$focal_brand_name))
    sub_parts <- c(sub_parts,
      sprintf("Focal: <strong>%s</strong>", .fn_esc(meta$focal_brand_name)))
  if (!is.null(meta$category_type))
    sub_parts <- c(sub_parts, sprintf("%s funnel",
      .fn_capitalise(meta$category_type)))
  if (nzchar(wave)) sub_parts <- c(sub_parts, sprintf("Wave %s", .fn_esc(wave)))
  if (is.finite(n_u)) sub_parts <- c(sub_parts, sprintf("n = %d", n_u))

  # Plain white card, tabs question-title-card idiom (no gradient; the
  # dark-navy header lives at the report level, not per panel).
  sprintf(
    '<div class="fn-title-card question-title-card">
       <div class="fn-title-card-top">
         <h2 class="fn-title"><span class="fn-title-caret">\u25BE</span> Brand Funnel</h2>
         <button type="button" class="fn-pin-btn pin-btn" title="Pin this panel" aria-label="Pin">\U0001F4CC</button>
       </div>
       <div class="fn-title-sub">%s</div>
     </div>',
    paste(sub_parts, collapse = " &middot; ")
  )
}


.fn_sub_tabs <- function() {
  '<nav class="fn-subnav" role="tablist" aria-label="Funnel sections">
     <button type="button" class="fn-subtab-btn" data-fn-subtab-target="summary" role="tab" aria-selected="false">Summary</button>
     <button type="button" class="fn-subtab-btn active" data-fn-subtab-target="funnel" role="tab" aria-selected="true">Funnel</button>
     <button type="button" class="fn-subtab-btn" data-fn-subtab-target="relationship" role="tab" aria-selected="false">Relationship</button>
   </nav>'
}


# ==============================================================================
# INTERNAL: CONTROLS
# ==============================================================================

#' Summary sub-tab: focus-brand dropdown (changing this re-renders cards).
#' @keywords internal
.fn_focus_bar <- function(pd) {
  brand_codes <- pd$config$chip_picker$all_brands %||%
    (pd$table$brand_codes %||% character(0))
  brand_names <- pd$table$brand_names %||% brand_codes
  focal <- pd$meta$focal_brand_code %||% brand_codes[1]

  focus_options <- paste(vapply(seq_along(brand_codes), function(i) {
    sel <- if (brand_codes[i] == focal) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .fn_esc(brand_codes[i]), sel, .fn_esc(brand_names[i]))
  }, character(1)), collapse = "")

  sprintf(
    '<div class="fn-focus-bar">
       <label class="fn-ctl-label">Focal brand</label>
       <select class="fn-focus-select" data-fn-action="focus">%s</select>
     </div>',
    focus_options)
}


#' Funnel sub-tab: the view-controls row above the table.
#'
#' Matches tabs' controls bar exactly:
#' - \code{.toggle-label} pills for Heatmap / Show count / Show chart
#' - \code{.sig-level-switcher} segmented button for Base (% of total / previous)
#' - \code{.export-btn} with the \u2B73 Export \u25BE icon
#' @keywords internal
.fn_table_controls <- function(pd) {
  brand_codes <- pd$config$chip_picker$all_brands %||%
    (pd$table$brand_codes %||% character(0))
  brand_names <- pd$table$brand_names %||% brand_codes
  focal <- pd$meta$focal_brand_code %||% brand_codes[1]

  chips_html <- paste(vapply(seq_along(brand_codes), function(i) {
    sprintf('<button type="button" class="col-chip" data-fn-scope="table" data-fn-brand="%s">%s</button>',
            .fn_esc(brand_codes[i]), .fn_esc(brand_names[i]))
  }, character(1)), collapse = "")

  paste0(
    '<div class="fn-controls controls-bar">',
    '<div class="fn-ctl-group"><span class="fn-ctl-label">Show brands</span>',
    sprintf('<div class="fn-chip-row col-chip-bar">%s</div></div>', chips_html),

    '<label class="toggle-label"><input type="checkbox" data-fn-action="showci"> Show heatmap</label>',
    '<label class="toggle-label"><input type="checkbox" data-fn-action="showcounts"> Show count</label>',
    '<label class="toggle-label"><input type="checkbox" checked data-fn-action="showchart"> Show chart</label>',

    # Base (% of total / previous) — segmented toggle, same shape as tabs' sig-level-switcher
    '<div class="sig-level-switcher fn-base-switcher" role="group" aria-label="Percentage base">',
    '<span class="sig-level-label">Base:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-action="pctmode" data-fn-pctmode="total" aria-pressed="true">% of total</button>',
    '<button type="button" class="sig-btn" data-fn-action="pctmode" data-fn-pctmode="previous" aria-pressed="false">% of previous</button>',
    '<button type="button" class="sig-btn" data-fn-action="pctmode" data-fn-pctmode="aware" aria-pressed="false" title="Awareness pinned to 100%. Shows conversion from awareness for each stage.">% of aware</button>',
    '</div>',

    # Pin + PNG + Excel grouped on the right (conjoint-style placement)
    '<button type="button" class="fn-pin-dropdown-btn export-btn" data-fn-action="pindropdown" title="Pin a section" aria-haspopup="true">&#128204; Pin &#9662;</button>',
    '<button type="button" class="export-btn fn-png-btn" onclick="brExportPngFromEl(this)" title="Export view to PNG">&#x1F5BC; PNG</button>',
    '<button type="button" class="export-btn fn-export-btn" data-fn-action="exporttable" title="Export table to Excel">\u2B73 Excel \u25BE</button>',
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: CARDS (10 total — 5 funnel + 5 relationship)
# ==============================================================================

.fn_cards_section <- function(pd, focal_colour) {
  funnel_cards <- pd$cards$funnel %||% list()
  rel_cards    <- pd$cards$relationship %||% list()

  paste0(
    '<section class="fn-section fn-cards-section">',
    '<h3 class="fn-section-title">Summary <span class="fn-insight-marker" title="AI insight available">&#9679;</span></h3>',
    '<div class="fn-cards-group-label">Funnel</div>',
    '<div class="fn-card-strip tk-hero-strip">',
    paste(lapply(funnel_cards, .fn_funnel_card, focal_colour),
          collapse = ""),
    '</div>',
    if (length(rel_cards) > 0) paste0(
      '<div class="fn-cards-group-label">Relationship</div>',
      '<div class="fn-card-strip tk-hero-strip">',
      paste(lapply(rel_cards, .fn_relationship_card, focal_colour),
            collapse = ""),
      '</div>'
    ) else "",
    '</section>'
  )
}


.fn_funnel_card <- function(card, focal_colour) {
  focal_pct <- .fn_pct_string(card$focal_pct)
  avg_pct   <- .fn_pct_string(card$cat_avg_pct)
  sig <- card$sig_vs_avg %||% "na"
  sig_badge <- .fn_sig_badge(sig)
  base_line <- if (is.finite(card$focal_base_unweighted %||% NA))
    sprintf('<div class="fn-card-base">Focal n = %d</div>',
            as.integer(card$focal_base_unweighted))
  else ""

  sprintf(
    '<div class="tk-hero-card fn-card fn-card-funnel" style="border-left-color:%s;" data-fn-stage="%s">
       <div class="tk-hero-label">%s</div>
       <div class="fn-card-row">
         <div class="tk-hero-value" style="color:%s;">%s</div>
         %s
       </div>
       <div class="fn-card-compare">Category avg: <strong>%s</strong></div>
       %s
     </div>',
    focal_colour, .fn_esc(card$stage_key),
    .fn_esc(card$stage_label),
    focal_colour, focal_pct, sig_badge,
    avg_pct, base_line
  )
}


.fn_relationship_card <- function(card, focal_colour) {
  focal_pct <- .fn_pct_string(card$focal_pct)
  avg_pct   <- .fn_pct_string(card$cat_avg_pct)
  sprintf(
    '<div class="tk-hero-card fn-card fn-card-relationship" style="border-left-color:%s;">
       <div class="tk-hero-label">%s</div>
       <div class="fn-card-row">
         <div class="tk-hero-value" style="color:%s;">%s</div>
       </div>
       <div class="fn-card-compare">Category avg: <strong>%s</strong></div>
     </div>',
    focal_colour, .fn_esc(card$attitude_label),
    focal_colour, focal_pct, avg_pct
  )
}


.fn_sig_badge <- function(direction) {
  if (direction == "higher") return('<span class="fn-sig fn-sig-up">&uarr;</span>')
  if (direction == "lower")  return('<span class="fn-sig fn-sig-down">&darr;</span>')
  return("")
}


# ==============================================================================
# INTERNAL: SECTION SLOTS (populated by table + chart helpers)
# ==============================================================================

.fn_chart_header <- function(pd) {
  brand_codes <- pd$config$chip_picker$all_brands %||%
    (pd$table$brand_codes %||% character(0))
  brand_names <- pd$table$brand_names %||% brand_codes
  focal <- pd$meta$focal_brand_code %||% brand_codes[1]

  # Stage info for stacked emphasis chips
  stage_keys   <- pd$table$stage_keys   %||% character(0)
  stage_labels <- pd$table$stage_labels %||% list()

  # Cat Avg chip — always first, off by default in slope (toggles the dashed line + mini funnel card)
  cat_avg_chip <- '<button type="button" class="col-chip col-chip-off fn-chip-avg" data-fn-scope="chart" data-fn-brand="__avg__">Cat Avg</button>'

  brand_chips_html <- paste(vapply(seq_along(brand_codes), function(i) {
    active <- brand_codes[i] == focal
    cls <- if (active) "col-chip" else "col-chip col-chip-off"
    sprintf('<button type="button" class="%s" data-fn-scope="chart" data-fn-brand="%s">%s</button>',
            cls, .fn_esc(brand_codes[i]), .fn_esc(brand_names[i]))
  }, character(1)), collapse = "")

  chips_html <- paste0(cat_avg_chip, brand_chips_html)

  # Stage selector chips for bar view — first stage active by default
  stage_chips <- if (length(stage_keys) > 0)
    paste(vapply(seq_along(stage_keys), function(j) {
      k   <- stage_keys[j]
      lbl <- stage_labels[[k]] %||% k
      cls <- if (j == 1) "fn-stk-emph-chip fn-stk-emph-active" else "fn-stk-emph-chip"
      sprintf('<button type="button" class="%s" data-fn-stk-emphasis="%s">%s</button>',
              cls, .fn_esc(k), .fn_esc(lbl))
    }, character(1)), collapse = "")
  else ""

  paste0(
    '<div class="fn-chart-header">',
    # View toggle — always visible
    '<div class="sig-level-switcher fn-view-switcher" role="group" aria-label="View">',
    '<span class="sig-level-label">View:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-action="chartview" data-fn-view="slope" aria-pressed="true">Slope</button>',
    '<button type="button" class="sig-btn" data-fn-action="chartview" data-fn-view="bar" aria-pressed="false">Bar</button>',
    '</div>',
    # Brand chips — always visible
    '<div class="fn-chart-brand-chips col-chip-bar">', chips_html, '</div>',
    # Slope-only controls
    '<div class="sig-level-switcher fn-slope-ctl" role="group" aria-label="Values">',
    '<span class="sig-level-label">Values:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-action="showvalues" data-fn-showvalues="focal" aria-pressed="true">Focal</button>',
    '<button type="button" class="sig-btn" data-fn-action="showvalues" data-fn-showvalues="all" aria-pressed="false">All</button>',
    '<button type="button" class="sig-btn" data-fn-action="showvalues" data-fn-showvalues="none" aria-pressed="false">None</button>',
    '</div>',
    '<div class="sig-level-switcher fn-shading-switcher fn-slope-ctl" role="group" aria-label="Shading">',
    '<span class="sig-level-label">Shading:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-action="shading" data-fn-shading="range" aria-pressed="true">Range</button>',
    '<button type="button" class="sig-btn" data-fn-action="shading" data-fn-shading="ci" aria-pressed="false">CI</button>',
    '<button type="button" class="sig-btn" data-fn-action="shading" data-fn-shading="none" aria-pressed="false">None</button>',
    '</div>',
    '<div class="fn-yaxis-range fn-slope-ctl">',
    '<span class="sig-level-label">Y-axis:</span>',
    '<input type="number" class="fn-yaxis-input" data-fn-yaxis="min" placeholder="0" min="0" max="100" step="5">',
    '<span class="fn-yaxis-sep">\u2013</span>',
    '<input type="number" class="fn-yaxis-input" data-fn-yaxis="max" placeholder="100" min="0" max="100" step="5">',
    '<button type="button" class="fn-yaxis-reset" data-fn-action="yaxisreset" title="Reset y-axis">\u21BA</button>',
    '</div>',
    # Bar-only controls: stage selector
    if (length(stage_keys) > 0) paste0(
      '<div class="fn-stk-ctl fn-stk-emph-row" hidden>',
      '<span class="sig-level-label">Stage:</span>',
      stage_chips,
      '</div>'
    ) else '',
    '</div>'
  )
}


.fn_table_section <- function(pd, focal_colour) {
  build_funnel_table_section(pd, focal_colour)
}

.fn_chart_section <- function(pd, focal_colour) {
  build_funnel_chart_section(pd, focal_colour)
}

.fn_relationship_section <- function(pd, focal_colour) {
  build_funnel_relationship_section(pd, focal_colour)
}


# ==============================================================================
# INTERNAL: ABOUT DRAWER
# ==============================================================================

.fn_about_section <- function(pd) {
  a <- pd$about
  parts <- character(0)

  # Stage definitions (replaces the ? popovers on column headers)
  stage_keys  <- pd$meta$stage_keys  %||% character(0)
  stage_lbls  <- pd$meta$stage_labels %||% list()
  stage_defs  <- pd$meta$stage_definitions %||% list()
  def_items <- vapply(stage_keys, function(k) {
    lbl <- stage_lbls[[k]] %||% k
    def <- stage_defs[[k]] %||% ""
    if (!nzchar(trimws(def))) return("")
    sprintf('<dt class="fn-stage-def-term">%s</dt><dd class="fn-stage-def-body">%s</dd>',
            .fn_esc(lbl), .fn_esc(def))
  }, character(1))
  def_items <- def_items[nzchar(def_items)]
  if (length(def_items) > 0) {
    parts <- c(parts, paste0(
      '<p class="fn-about-item"><strong>Stage definitions:</strong></p>',
      '<dl class="fn-stage-defs">', paste(def_items, collapse = ""), '</dl>'))
  }

  # Methodology notes
  if (!is.null(a)) {
    for (key in c("methodology_note", "base_note", "significance_note",
                  "heavy_buyer_note", "prior_brand_note")) {
      val <- a[[key]]
      if (!is.null(val) && is.character(val) && nzchar(trimws(val))) {
        parts <- c(parts, sprintf('<p class="fn-about-item"><strong>%s:</strong> %s</p>',
                                  .fn_about_heading(key), .fn_esc(val)))
      }
    }
  }

  if (length(parts) == 0) return("")
  paste0(
    '<details class="fn-about"><summary class="fn-about-summary">About this funnel</summary>',
    '<div class="fn-about-body">',
    paste(parts, collapse = ""),
    '</div></details>'
  )
}


.fn_about_heading <- function(key) {
  switch(key,
    methodology_note   = "Methodology",
    base_note          = "Bases",
    significance_note  = "Significance",
    heavy_buyer_note   = "Heavy buyers & frequency",
    prior_brand_note   = "Prior brand",
    key)
}


# ==============================================================================
# INTERNAL: HELPERS
# ==============================================================================

.funnel_panel_json <- function(pd, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  payload <- list(
    meta = pd$meta,
    cards = pd$cards,
    table = pd$table,
    shape_chart = pd$shape_chart,
    consideration_detail = pd$consideration_detail,
    config = pd$config,
    focal_colour = focal_colour
  )
  jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null",
                   pretty = FALSE, digits = 6)
}


.fn_pct_string <- function(pct) {
  if (is.null(pct) || is.na(pct)) return("&mdash;")
  sprintf("%.0f%%", 100 * pct)
}


.fn_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


.fn_capitalise <- function(x) {
  if (is.null(x) || !nzchar(x)) return("")
  paste0(toupper(substring(x, 1, 1)), substring(x, 2))
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
