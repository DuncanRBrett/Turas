# ==============================================================================
# BRAND MODULE - FUNNEL PANEL HTML RENDERER (FUNNEL_SPEC_v2 §6)
# ==============================================================================
# Consumes build_funnel_panel_data() output and emits a self-contained
# HTML fragment for one category's funnel tab. The fragment is inserted
# into the brand report by 03_page_builder.R.
#
# Visual tokens match tabs + tracker:
#   - Card styling: .tk-hero-card (tracker)
#   - Chip styling: .col-chip (tabs)
#   - Heatmap fill: blue sequential rgba(37,99,171, 0.06..0.40) (tracker)
#
# Interaction JS: js/brand_funnel_panel.js (loaded once per report).
#
# Sub-renderers:
#   03_funnel_panel_table.R     — heatmap table
#   03_funnel_panel_chart.R     — slope chart + relationship detail
#   03_funnel_panel_styling.R   — CSS bundle
#
# VERSION: 1.0
# ==============================================================================

BRAND_FUNNEL_PANEL_VERSION <- "1.0"


# ==============================================================================
# PUBLIC: build_funnel_panel_html
# ==============================================================================

#' Build the funnel panel HTML fragment
#'
#' @param panel_data List from \code{build_funnel_panel_data()}.
#' @param category_code Character. Used to scope element ids on the page.
#' @param focal_colour Character. Hex colour for the focal brand (used for
#'   card accents + chart lines). Defaults to Turas navy.
#'
#' @return Character. A single HTML fragment (string).
#' @export
build_funnel_panel_html <- function(panel_data, category_code = "cat",
                                    focal_colour = "#1A5276") {
  if (is.null(panel_data) || is.null(panel_data$meta) ||
      length(panel_data$meta) == 0) {
    return('<div class="fn-panel-empty">Funnel not available for this category.</div>')
  }

  panel_id <- paste0("fn-", category_code)
  json_payload <- .funnel_panel_json(panel_data, focal_colour)

  paste0(
    sprintf('<div class="fn-panel" id="%s" data-focal-colour="%s">',
            panel_id, focal_colour),
    sprintf('<script type="application/json" class="fn-panel-data">%s</script>',
            json_payload),
    .fn_panel_header(panel_data),
    .fn_controls_bar(panel_data, panel_id),
    .fn_cards_section(panel_data, focal_colour),
    .fn_table_section(panel_data, focal_colour),
    .fn_chart_section(panel_data, focal_colour),
    .fn_relationship_section(panel_data, focal_colour),
    .fn_about_section(panel_data),
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: HEADER + CONTROLS
# ==============================================================================

.fn_panel_header <- function(pd) {
  meta <- pd$meta
  n_u <- meta$n_unweighted %||% NA
  n_w <- meta$n_weighted %||% NA
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

  sprintf(
    '<div class="fn-panel-header">
       <h2 class="fn-panel-title">Brand Funnel</h2>
       <div class="fn-panel-sub">%s</div>
     </div>',
    paste(sub_parts, collapse = " &middot; ")
  )
}


.fn_controls_bar <- function(pd, panel_id) {
  brand_codes <- pd$config$chip_picker$all_brands %||%
    (pd$table$brand_codes %||% character(0))
  brand_names <- pd$table$brand_names %||% brand_codes
  focal <- pd$meta$focal_brand_code %||% brand_codes[1]

  # Focus dropdown — default to focal; value list = every brand
  focus_options <- paste(vapply(seq_along(brand_codes), function(i) {
    sel <- if (brand_codes[i] == focal) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .fn_esc(brand_codes[i]), sel, .fn_esc(brand_names[i]))
  }, character(1)), collapse = "")

  paste0(
    '<div class="fn-controls">',
    sprintf('<label class="fn-ctl-group"><span class="fn-ctl-label">Focus on this brand</span><select class="fn-focus-select" data-fn-action="focus">%s</select></label>',
            focus_options),
    .fn_chip_bar("Show these brands (table)", "table",
                 brand_codes, brand_names, focal,
                 default_all = TRUE),
    .fn_chip_bar("Show these brands (chart)", "chart",
                 brand_codes, brand_names, focal,
                 default_all = FALSE),
    .fn_toggles_bar(),
    '</div>'
  )
}


.fn_chip_bar <- function(label, scope, codes, names, focal, default_all) {
  chips <- vapply(seq_along(codes), function(i) {
    active <- default_all || codes[i] == focal
    cls <- if (active) "col-chip" else "col-chip col-chip-off"
    sprintf('<button type="button" class="%s" data-fn-scope="%s" data-fn-brand="%s">%s</button>',
            cls, scope, .fn_esc(codes[i]), .fn_esc(names[i]))
  }, character(1))
  paste0(
    sprintf('<div class="fn-ctl-group fn-chip-group" data-fn-scope="%s">', scope),
    sprintf('<span class="fn-ctl-label">%s</span>', .fn_esc(label)),
    '<div class="fn-chip-row col-chip-bar">',
    paste(chips, collapse = ""),
    '</div></div>'
  )
}


.fn_toggles_bar <- function() {
  paste0(
    '<div class="fn-ctl-group fn-toggles">',
    '<span class="fn-ctl-label">Display</span>',
    '<label class="fn-toggle"><input type="radio" name="fn-pctmode" value="nested" checked data-fn-action="pctmode"> % of %</label>',
    '<label class="fn-toggle"><input type="radio" name="fn-pctmode" value="absolute" data-fn-action="pctmode"> % of absolute</label>',
    '<span class="fn-sep"></span>',
    '<label class="fn-toggle"><input type="checkbox" data-fn-action="showcounts"> Show counts</label>',
    '<span class="fn-sep"></span>',
    '<label class="fn-toggle"><input type="radio" name="fn-chartview" value="slope" checked data-fn-action="chartview"> Slope</label>',
    '<label class="fn-toggle"><input type="radio" name="fn-chartview" value="small" data-fn-action="chartview"> Small multiples</label>',
    '<span class="fn-sep"></span>',
    '<button type="button" class="fn-export-btn" data-fn-action="export">Export to Excel</button>',
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
  if (is.null(a)) return("")
  parts <- character(0)
  for (key in c("methodology_note", "base_note", "significance_note",
                "heavy_buyer_note", "prior_brand_note")) {
    val <- a[[key]]
    if (!is.null(val) && is.character(val) && nzchar(trimws(val))) {
      parts <- c(parts, sprintf('<p class="fn-about-item"><strong>%s:</strong> %s</p>',
                                .fn_about_heading(key), .fn_esc(val)))
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
