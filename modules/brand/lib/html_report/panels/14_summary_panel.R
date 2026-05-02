# ==============================================================================
# BRAND MODULE - EXECUTIVE SUMMARY PANEL
# ==============================================================================
# Per-category executive summary with two dropdowns (Category + Brand) at the
# top. Renders a layered dashboard:
#   1. Category context strip (4 neutral chips: avg purchases / avg brands /
#      top channel / top pack — graceful drop when missing)
#   2. Headline sentence (auto-seeded from metrics)
#   3. Focal strip (5 metric cards with cat-avg under, MMS rank badge)
#   4. Diagnostic strip (Top-3 attribute chips + Top-3 CEP chips with delta)
#   5. Analyst commentary (markdown editor — ported from tracker)
#   6. Closing "all categories at a glance" mini-card strip (core cats only)
#   7. Collapsible educational callout
#
# Data flow: pre-compute a per-(cat, brand) payload in R, embed as JSON, JS
# reads dropdown values + payload to render the dashboard. No re-render of
# heavy chart elements — just card values + chip labels.
#
# JS: js/brand_summary_panel.js
# CSS: build_summary_panel_styles(brand_colour) — injected via panel_styles
# ==============================================================================

BRAND_SUMMARY_PANEL_VERSION <- "1.0"


# ==============================================================================
# PUBLIC: build_brand_summary_panel
# ==============================================================================

#' Build the Executive Summary panel HTML
#'
#' @param results List. Top-level brand results (results$results$categories).
#' @param config List. Brand config.
#'
#' @return Character. Complete summary panel HTML fragment.
#' @export
build_brand_summary_panel <- function(results, config) {
  cats <- results$results$categories %||% list()
  if (length(cats) == 0) return(.brsum_empty_panel())

  deep_cats <- .brsum_deep_cats(cats)
  if (length(deep_cats) == 0) return(.brsum_empty_panel())

  default_cat   <- deep_cats[[1]]
  focal_brand   <- config$focal_brand %||% ""
  focal_colour  <- config$colour_focal %||% "#1A5276"
  brand_colours <- .brsum_brand_colour_map(results, config)

  payload <- .brsum_build_payload(deep_cats, cats, results, config,
                                  brand_colours, focal_colour)
  payload$default_category <- default_cat
  payload$default_brand    <- focal_brand
  payload$focal_colour     <- focal_colour

  json_payload <- .brsum_json(payload)

  closing_strip_html <- .brsum_closing_strip(deep_cats, payload, focal_brand)

  # Wrapper carries the JSON and default selections; JS picks them up on init.
  paste(
    '<div class="br-panel active" id="panel-summary">',
      sprintf('<div class="brsum-root" data-default-cat="%s" data-default-brand="%s" data-focal-colour="%s">',
              .brsum_esc(default_cat), .brsum_esc(focal_brand),
              .brsum_esc(focal_colour)),
        sprintf('<script type="application/json" class="brsum-data">%s</script>',
                json_payload),
        .brsum_header(),
        .brsum_dropdown_bar(payload),
        '<div class="brsum-dashboard" data-brsum-fade>',
          .brsum_focal_context_strip(),
          .brsum_card_grid_skeleton(),
        '</div>',
        .brsum_insight_editor(),
        closing_strip_html,
        .brsum_educational_callout(),
      '</div>',
    '</div>',
    sep = "\n"
  )
}


# ==============================================================================
# PUBLIC: build_summary_panel_styles
# ==============================================================================

#' CSS for the Executive Summary panel
#'
#' @param brand_colour Character. Hex focal-brand colour.
#' @return Character. CSS string.
#' @export
build_summary_panel_styles <- function(brand_colour = "#1A5276") {
  # NOTE: built via gsub template (not sprintf) because the full CSS is
  # >8K chars, which trips R's sprintf 8192-char fmt limit.
  # Single placeholder token: %FOCAL%
  template <- '
.brsum-root { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
  color: #1e293b; width: 100%; }

/* ---- Header ---- */
.brsum-header { margin: 0 0 20px; }
.brsum-eyebrow { font-size: 11px; font-weight: 600; color: #94a3b8;
  text-transform: uppercase; letter-spacing: 0.8px; }
.brsum-title { font-size: 28px; font-weight: 700; color: #0f172a;
  margin: 4px 0 0; line-height: 1.2; letter-spacing: -0.01em; }
.brsum-subtitle { font-size: 14px; color: #64748b; margin: 6px 0 0; }

/* ---- Dropdown bar (sticky) ---- */
.brsum-dropdown-bar { position: sticky; top: 56px; z-index: 30;
  background: #f8f7f5; padding: 14px 0; margin: 0 0 28px;
  border-bottom: 1px solid #e2e8f0;
  display: flex; gap: 20px; flex-wrap: wrap; align-items: center; }
.brsum-dropdown-group { display: flex; align-items: center; gap: 10px; }
.brsum-dropdown-label { font-size: 11px; font-weight: 600; color: #64748b;
  text-transform: uppercase; letter-spacing: 0.5px; }
.brsum-dropdown { font-size: 14px; padding: 9px 14px;
  border: 1px solid #cbd5e1; border-radius: 6px; background: #fff;
  color: #1e293b; cursor: pointer; min-width: 220px; font-weight: 500;
  transition: border-color 0.15s, box-shadow 0.15s; }
.brsum-dropdown:hover { border-color: %FOCAL%; }
.brsum-dropdown:focus { outline: none; border-color: %FOCAL%;
  box-shadow: 0 0 0 3px rgba(26,82,118,0.15); }

/* ---- Dashboard fade ---- */
[data-brsum-fade] { transition: opacity 200ms ease; }
[data-brsum-fade].brsum-fading { opacity: 0; }

/* ---- Strip wrappers (legacy — Analyst commentary + closing strip still use the title style) ---- */
.brsum-strip { margin: 0 0 36px; }
.brsum-strip-title { font-size: 11px; font-weight: 700; color: #475569;
  text-transform: uppercase; letter-spacing: 1px; margin: 0 0 14px;
  display: flex; align-items: center; gap: 10px; }
.brsum-strip-title::after { content: ""; flex: 1; height: 1px;
  background: linear-gradient(to right, #e2e8f0, transparent); }

/* ---- Focal context header strip ---- */
/* Single line at the top of the dashboard naming the focal brand and
   category. Each card below relies on this for context, so cards do not
   repeat the focal name in their headers. */
.brsum-focal-context {
  display: flex; align-items: baseline; gap: 8px;
  padding: 12px 18px; margin: 0 0 18px;
  background: linear-gradient(135deg, %FOCAL% 0%, color-mix(in srgb, %FOCAL% 85%, #1e293b) 100%);
  border-radius: 10px; color: #fff;
  flex-wrap: wrap;
}
.brsum-fc-eyebrow {
  font-size: 9px; font-weight: 700; letter-spacing: 1.4px;
  text-transform: uppercase; color: rgba(255, 255, 255, 0.75);
  background: rgba(255, 255, 255, 0.18);
  padding: 3px 8px; border-radius: 999px;
}
.brsum-fc-brand {
  font-size: 22px; font-weight: 700; letter-spacing: -0.01em;
  color: #fff;
}
.brsum-fc-divider { color: rgba(255, 255, 255, 0.45); font-size: 18px; }
.brsum-fc-cat {
  font-size: 16px; font-weight: 500;
  color: rgba(255, 255, 255, 0.92);
}

/* ---- Card grid (11 cards, 2 per row, full-width spans for dot plots) ---- */
.brsum-card-grid {
  display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px;
  margin: 0 0 28px;
}
.brsum-card-wide { grid-column: 1 / -1; }
.brsum-card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
  padding: 16px 18px;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  display: flex; flex-direction: column; min-width: 0;
}
.brsum-card-header {
  display: flex; align-items: baseline; justify-content: space-between;
  gap: 12px; flex-wrap: wrap;
  border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-bottom: 12px;
}
.brsum-card-title {
  font-size: 13px; font-weight: 600; color: #1a2744;
  margin: 0; letter-spacing: 0.1px;
}
.brsum-card-meta {
  font-size: 10px; font-weight: 500; color: #94a3b8;
  font-variant-numeric: tabular-nums;
}
.brsum-card-body { flex: 1 1 auto; min-height: 56px; }
.brsum-card-empty {
  font-size: 12px; color: #94a3b8; font-style: italic;
  padding: 8px 0;
}

/* ---- Stat rows (Category context card) ---- */
.brsum-stat-rows {
  display: flex; flex-direction: column; gap: 8px;
}
.brsum-stat-row {
  display: flex; align-items: baseline; justify-content: space-between;
  gap: 12px; padding: 6px 0;
  border-bottom: 1px dashed #f1f5f9;
}
.brsum-stat-row:last-child { border-bottom: 0; }
.brsum-stat-label {
  font-size: 12px; color: #64748b; font-weight: 500;
}
.brsum-stat-value {
  font-size: 16px; font-weight: 700; color: #1e293b;
  font-variant-numeric: tabular-nums;
  display: flex; align-items: baseline; gap: 8px;
}
.brsum-stat-sub {
  font-size: 10px; color: #94a3b8; font-weight: 500;
}

/* ---- Value chips (MA metrics, Brand summary, WOM cards) ---- */
.brsum-vchip-grid {
  display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px;
}
.brsum-vchip-grid-single {
  grid-template-columns: 1fr;
}
.brsum-vchip {
  background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 8px;
  padding: 12px 14px; min-width: 0;
}
.brsum-vchip-label {
  font-size: 10px; font-weight: 600; color: #94a3b8;
  text-transform: uppercase; letter-spacing: 0.5px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.brsum-vchip-value {
  font-size: 26px; font-weight: 700; line-height: 1.1;
  margin: 4px 0 6px; letter-spacing: -0.01em;
  font-variant-numeric: tabular-nums;
}
.brsum-vchip-catavg {
  font-size: 11px; color: #64748b;
}
.brsum-vchip-catavg span {
  color: #334155; font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.brsum-vchip-leader {
  font-size: 10px; color: #94a3b8; margin-top: 4px;
}
.brsum-vchip-leader.brsum-leader-on {
  color: #047857; font-weight: 700; letter-spacing: 0.4px;
  text-transform: uppercase;
}
@media (max-width: 480px) {
  .brsum-vchip-grid { grid-template-columns: 1fr; }
}

/* ---- Empty state inherited by chip lists (closing strip uses this) ---- */
.brsum-empty-note { font-size: 12px; color: #94a3b8; font-style: italic; }
.brsum-chip { display: inline-flex; align-items: center; gap: 8px;
  background: #f1f5f9; border: 1px solid #e2e8f0;
  padding: 6px 12px; border-radius: 999px; font-size: 13px;
  color: #1e293b; font-weight: 500; line-height: 1.2; }
.brsum-chip-delta { font-size: 11px; font-weight: 700; color: #0f766e;
  background: #d1fae5; padding: 2px 7px; border-radius: 999px;
  line-height: 1.2; }
.brsum-chip-delta.neg { color: #475569; background: #e2e8f0; }

/* ---- Insight editor (ported from tracker, scoped to brsum) ---- */
.brsum-insight-block { margin: 0 0 36px; }
.brsum-insight-toolbar { display: flex; align-items: center; gap: 6px;
  margin: 0 0 10px; flex-wrap: wrap; }
.brsum-insight-btn { padding: 5px 11px; font-size: 13px;
  background: #fff; border: 1px solid #cbd5e1; border-radius: 5px;
  cursor: pointer; color: #475569; min-width: 30px;
  transition: border-color 0.12s, color 0.12s; }
.brsum-insight-btn:hover { border-color: %FOCAL%; color: %FOCAL%; }
.brsum-insight-hint { font-size: 11px; color: #94a3b8; margin-left: 10px;
  font-style: italic; }
.brsum-insight-editor { width: 100%; min-height: 130px;
  border: 1px solid #cbd5e1; border-radius: 8px; padding: 14px 16px;
  font-size: 14px; line-height: 1.6; color: #1e293b;
  font-family: "SF Mono", "Menlo", "Consolas", monospace;
  resize: vertical; background: #fefefe; box-sizing: border-box; }
.brsum-insight-editor:focus { outline: none; border-color: %FOCAL%;
  box-shadow: 0 0 0 3px rgba(26,82,118,0.12); }
.brsum-insight-rendered { margin-top: 14px; padding: 16px 20px;
  border-left: 3px solid %FOCAL%; background: #f8fafa;
  border-radius: 0 8px 8px 0; font-size: 14px; line-height: 1.6;
  color: #1e293b; }
.brsum-insight-rendered:empty { display: none; }
.brsum-insight-rendered h2 { font-size: 15px; font-weight: 700;
  margin: 8px 0 6px; color: #0f172a; }
.brsum-insight-rendered ul { margin: 6px 0; padding-left: 22px; }
.brsum-insight-rendered blockquote { margin: 6px 0; padding: 4px 14px;
  border-left: 3px solid #cbd5e1; color: #475569; font-style: italic; }

/* ---- Closing strip (mini cards) ---- */
.brsum-closing { margin: 0 0 32px; padding-top: 28px;
  border-top: 1px solid #e2e8f0; }
.brsum-mini-grid { display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.brsum-mini-card { background: #fff; border: 1px solid #e2e8f0;
  border-radius: 8px; padding: 14px 16px; cursor: pointer;
  transition: border-color 0.15s, transform 0.15s, box-shadow 0.15s; }
.brsum-mini-card:hover { border-color: %FOCAL%; transform: translateY(-1px);
  box-shadow: 0 2px 6px rgba(15,23,42,0.04); }
.brsum-mini-cat { font-size: 12px; font-weight: 600; color: #475569;
  margin: 0 0 10px; line-height: 1.3; }
.brsum-mini-row { display: flex; justify-content: space-between;
  font-size: 11px; color: #475569; margin: 3px 0; }
.brsum-mini-num { font-weight: 700; color: #1e293b; }

/* ---- Educational callout (collapsible) ---- */
.brsum-edu { margin: 48px 0 0; border-top: 1px solid #e2e8f0;
  padding-top: 18px; }
.brsum-edu-toggle { background: none; border: none; cursor: pointer;
  display: flex; align-items: center; gap: 10px;
  font-size: 12px; font-weight: 700; color: #475569;
  text-transform: uppercase; letter-spacing: 0.6px; padding: 6px 0; }
.brsum-edu-toggle:hover { color: %FOCAL%; }
.brsum-edu-arrow { display: inline-block; transition: transform 0.15s;
  font-size: 10px; color: #94a3b8; }
.brsum-edu.open .brsum-edu-arrow { transform: rotate(90deg); }
.brsum-edu-body { display: none; padding: 18px 22px; margin-top: 10px;
  background: #f8fafc; border-left: 3px solid %FOCAL%;
  border-radius: 0 8px 8px 0;
  font-size: 13px; line-height: 1.65; color: #334155; }
.brsum-edu.open .brsum-edu-body { display: block; }
.brsum-edu-body p { margin: 6px 0; }
.brsum-edu-body strong { color: #0f172a; }

/* ---- Responsive collapse ---- */
@media (max-width: 820px) {
  .brsum-card-grid { grid-template-columns: 1fr; }
}
@media (max-width: 600px) {
  .brsum-title { font-size: 22px; }
  .brsum-fc-brand { font-size: 18px; }
  .brsum-fc-cat { font-size: 14px; }
  .brsum-dropdown { min-width: 160px; }
  .brsum-dropdown-bar { position: static; }
}

/* ---- Print ---- */
@media print {
  .brsum-dropdown-bar, .brsum-insight-toolbar, .brsum-edu-toggle {
    display: none !important;
  }
  .brsum-edu-body { display: block !important; }
  [data-brsum-fade] { opacity: 1 !important; }
}
'
  gsub("%FOCAL%", brand_colour, template, fixed = TRUE)
}


# ==============================================================================
# INTERNAL: PAYLOAD CONSTRUCTION
# ==============================================================================

# Filter to "core" / deep-dive categories (those with funnel + MA data).
# Awareness-only categories are excluded from the dashboard's primary view.
.brsum_deep_cats <- function(cats) {
  out <- character(0)
  for (cn in names(cats)) {
    cr <- cats[[cn]]
    has_funnel <- !is.null(cr$funnel) &&
      !identical(cr$funnel$status, "REFUSED")
    has_ma <- !is.null(cr$mental_availability) &&
      !identical(cr$mental_availability$status, "REFUSED")
    if (has_funnel || has_ma) out <- c(out, cn)
  }
  out
}


# Build the JSON payload: per-category context + per-(cat, brand) snapshot.
.brsum_build_payload <- function(deep_cats, cats, results, config,
                                  brand_colours, focal_colour) {
  out <- list(categories = list())
  for (cn in deep_cats) {
    cr <- cats[[cn]]
    label_map <- .brsum_brand_label_map(cr, results, cn)
    brand_codes <- .brsum_brand_codes_for_cat(cr)
    if (length(brand_codes) == 0) next

    # Per-category context (4 chips)
    context <- .brsum_context_for_cat(cr)

    # CEP + attribute label tables for this category (used by diagnostic chips)
    cep_labels  <- .brsum_cep_labels_for_cat(results, cn)
    attr_labels <- .brsum_attr_labels_for_cat(results, cn, cr)

    # Per-brand snapshots
    brands <- list()
    for (bc in brand_codes) {
      brands[[bc]] <- .brsum_brand_snapshot(
        bc, cr, label_map, brand_colours, focal_colour,
        cep_labels = cep_labels, attr_labels = attr_labels,
        cat_name = cn)
    }

    out$categories[[cn]] <- list(
      label = cn,
      n_brands = length(brand_codes),
      context = context,
      brand_codes = brand_codes,
      brand_labels = unname(vapply(brand_codes,
                                    function(b) label_map[[b]] %||% b,
                                    character(1))),
      brands = brands
    )
  }
  out
}


# Brand codes from MA (preferred) or funnel.
.brsum_brand_codes_for_cat <- function(cr) {
  if (!is.null(cr$mental_availability$mms$BrandCode)) {
    return(as.character(cr$mental_availability$mms$BrandCode))
  }
  if (!is.null(cr$funnel$stages$brand_code)) {
    return(unique(as.character(cr$funnel$stages$brand_code)))
  }
  character(0)
}


# Map BrandCode -> BrandLabel using whatever sources are reachable. Falls
# back to the code itself when no label is available.
#
# Source priority:
#  1. `results$structure$brands` (Category + BrandCode + BrandLabel) — the
#     canonical label table on the Survey_Structure sheet.
#  2. `results$results$portfolio_overview$categories[[cat_code]]$brand_names`
#     — a named list (BrandCode -> BrandName) keyed by category code, not
#     category name.
.brsum_brand_label_map <- function(cr, results, cat_name) {
  out <- list()

  # Source 1: structure$brands filtered to this category.
  brands_df <- results$structure$brands
  if (!is.null(brands_df) && nrow(brands_df) > 0 &&
      "BrandCode" %in% names(brands_df) &&
      "BrandLabel" %in% names(brands_df)) {
    sub <- if ("Category" %in% names(brands_df)) {
      brands_df[brands_df$Category == cat_name, , drop = FALSE]
    } else brands_df
    for (i in seq_len(nrow(sub))) {
      bc <- as.character(sub$BrandCode[i])
      bl <- as.character(sub$BrandLabel[i])
      if (!is.na(bc) && nzchar(bc) && !is.na(bl) && nzchar(bl)) {
        out[[bc]] <- bl
      }
    }
  }

  # Source 2: portfolio_overview brand_names list, keyed by category CODE.
  # Resolve cat_name -> cat_code via structure$categories (or the brands
  # table itself, which carries CategoryCode).
  cat_code <- NULL
  if (!is.null(brands_df) && "Category" %in% names(brands_df) &&
      "CategoryCode" %in% names(brands_df)) {
    hits <- brands_df$CategoryCode[brands_df$Category == cat_name]
    if (length(hits) > 0) cat_code <- as.character(hits[1])
  }
  pov <- results$results$portfolio_overview
  if (!is.null(cat_code) && !is.null(pov$categories[[cat_code]]$brand_names)) {
    bn <- pov$categories[[cat_code]]$brand_names
    # `brand_names` may be a named list (BrandCode -> BrandName) or a data
    # frame with brand_code + brand_name columns.
    if (is.list(bn) && !is.data.frame(bn) && length(bn) > 0) {
      for (k in names(bn)) {
        if (is.null(out[[k]]) || identical(out[[k]], k)) {
          out[[k]] <- as.character(bn[[k]])
        }
      }
    } else if (is.data.frame(bn) && nrow(bn) > 0 &&
               !is.null(bn$brand_code) && !is.null(bn$brand_name)) {
      for (i in seq_len(nrow(bn))) {
        k <- as.character(bn$brand_code[i])
        if (is.null(out[[k]]) || identical(out[[k]], k)) {
          out[[k]] <- as.character(bn$brand_name[i])
        }
      }
    }
  }

  out
}


# Map BrandCode -> hex colour from config or panel data fallbacks.
.brsum_brand_colour_map <- function(results, config) {
  out <- list()
  bc <- config$brand_colours
  if (is.list(bc) || is.character(bc)) {
    for (k in names(bc)) out[[k]] <- as.character(bc[[k]])
  }
  out
}


# CEP labels for a category (data frame with CEPCode + CEPText). Source:
# `results$structure$ceps` filtered to the category. Returns NULL when the
# structure isn't available so the caller falls back to bare codes.
.brsum_cep_labels_for_cat <- function(results, cat_name) {
  ceps_all <- results$structure$ceps
  if (is.null(ceps_all) || nrow(ceps_all) == 0) return(NULL)
  if ("Category" %in% names(ceps_all)) {
    ceps_all[ceps_all$Category == cat_name, , drop = FALSE]
  } else {
    ceps_all
  }
}


# Attribute labels for a category. First try `results$structure$attributes`
# (raw survey structure); fall back to the MA result's own `attribute_labels`
# data frame (built when attribute_labels were threaded in).
.brsum_attr_labels_for_cat <- function(results, cat_name, cr) {
  attrs_all <- results$structure$attributes
  if (!is.null(attrs_all) && nrow(attrs_all) > 0) {
    if ("Category" %in% names(attrs_all)) {
      sub <- attrs_all[attrs_all$Category == cat_name, , drop = FALSE]
      if (nrow(sub) > 0) return(sub)
    } else {
      return(attrs_all)
    }
  }
  cr$mental_availability$attribute_labels
}


# Per-category context: 4 chips. Returns NULL fields when source is missing.
.brsum_context_for_cat <- function(cr) {
  ctx <- list(avg_purchases = NULL, avg_brands = NULL,
              top_channel = NULL, top_pack = NULL)

  # Avg purchases per category buyer (from cat_buying_frequency)
  cbf <- cr$cat_buying_frequency
  if (!is.null(cbf) && !identical(cbf$status, "REFUSED") &&
      !is.null(cbf$mean_freq) && !is.na(cbf$mean_freq)) {
    ctx$avg_purchases <- list(
      value = sprintf("%.1f", cbf$mean_freq),
      sub   = cbf$frequency_unit %||% "per period"
    )
  }

  # Avg brands per category buyer (mean_repertoire)
  rep <- cr$repertoire
  if (!is.null(rep) && !identical(rep$status, "REFUSED") &&
      !is.null(rep$mean_repertoire) && !is.na(rep$mean_repertoire)) {
    ctx$avg_brands <- list(
      value = sprintf("%.1f", rep$mean_repertoire),
      sub   = "brands per buyer"
    )
  }

  # Top channel (shopper_location$top)
  loc <- cr$shopper_location
  if (!is.null(loc) && !identical(loc$status, "REFUSED") &&
      !is.null(loc$top$label) && nzchar(loc$top$label)) {
    ctx$top_channel <- list(
      value = as.character(loc$top$label),
      sub   = if (!is.null(loc$top$pct) && !is.na(loc$top$pct))
                sprintf("%.0f%% of buyers", loc$top$pct) else ""
    )
  }

  # Top pack (shopper_packsize$top)
  pak <- cr$shopper_packsize
  if (!is.null(pak) && !identical(pak$status, "REFUSED") &&
      !is.null(pak$top$label) && nzchar(pak$top$label)) {
    ctx$top_pack <- list(
      value = as.character(pak$top$label),
      sub   = if (!is.null(pak$top$pct) && !is.na(pak$top$pct))
                sprintf("%.0f%% of buyers", pak$top$pct) else ""
    )
  }

  ctx
}


# Build per-brand snapshot for one category.
.brsum_brand_snapshot <- function(brand_code, cr, label_map,
                                   brand_colours, focal_colour,
                                   cep_labels = NULL, attr_labels = NULL,
                                   cat_name = NA_character_) {
  label <- label_map[[brand_code]] %||% brand_code
  colour <- brand_colours[[brand_code]] %||% focal_colour

  ma <- cr$mental_availability
  fn <- cr$funnel
  rep <- cr$repertoire
  wm <- cr$wom

  # ---- MMS + rank ----
  mms_value <- NA_real_
  mms_cat_avg <- NA_real_
  mms_rank <- NA_integer_
  n_brands <- NA_integer_
  if (!is.null(ma$mms) && nrow(ma$mms) > 0) {
    n_brands <- nrow(ma$mms)
    mms_cat_avg <- mean(ma$mms$MMS, na.rm = TRUE)
    if (brand_code %in% ma$mms$BrandCode) {
      mms_value <- ma$mms$MMS[ma$mms$BrandCode == brand_code]
      mms_rank <- which(order(-ma$mms$MMS) ==
                          which(ma$mms$BrandCode == brand_code))
    }
  }

  # ---- MPen ----
  mpen_value <- NA_real_
  mpen_cat_avg <- NA_real_
  if (!is.null(ma$mpen) && nrow(ma$mpen) > 0) {
    mpen_cat_avg <- mean(ma$mpen$MPen, na.rm = TRUE)
    if (brand_code %in% ma$mpen$BrandCode) {
      mpen_value <- ma$mpen$MPen[ma$mpen$BrandCode == brand_code]
    }
  }

  # ---- Funnel: bought_target ----
  bt_value <- NA_real_
  bt_cat_avg <- NA_real_
  if (!is.null(fn$stages) && nrow(fn$stages) > 0) {
    rows <- fn$stages[fn$stages$stage_key == "bought_target", , drop = FALSE]
    if (nrow(rows) > 0) {
      bt_cat_avg <- mean(rows$pct_weighted, na.rm = TRUE)
      hit <- rows$pct_weighted[rows$brand_code == brand_code]
      if (length(hit) == 1) bt_value <- hit
    }
  }

  # ---- Loyalty (Sole_Pct from repertoire profile) ----
  loy_value <- NA_real_
  loy_cat_avg <- NA_real_
  brp <- rep$brand_repertoire_profile
  if (!is.null(brp) && nrow(brp) > 0 && "Sole_Pct" %in% names(brp)) {
    loy_cat_avg <- mean(brp$Sole_Pct, na.rm = TRUE)
    if (brand_code %in% brp$BrandCode) {
      loy_value <- brp$Sole_Pct[brp$BrandCode == brand_code]
    }
  }

  # ---- Net WOM ----
  net_wom <- NA_real_
  net_wom_cat_avg <- NA_real_
  if (!is.null(wm$net_balance) && nrow(wm$net_balance) > 0 &&
      "Net_Received" %in% names(wm$net_balance)) {
    net_wom_cat_avg <- mean(wm$net_balance$Net_Received, na.rm = TRUE)
    if (brand_code %in% wm$net_balance$BrandCode) {
      net_wom <- wm$net_balance$Net_Received[
        wm$net_balance$BrandCode == brand_code]
    }
  }

  focal_metrics <- list(
    list(
      label = "MMS",
      value = .brsum_pct(mms_value, "%"),
      cat_avg = .brsum_pct(mms_cat_avg, "%"),
      rank = if (!is.na(mms_rank) && !is.na(n_brands))
                sprintf("Rank %d / %d", mms_rank, n_brands) else NA_character_
    ),
    list(label = "MPen", value = .brsum_pct(mpen_value, "%", scale = 100),
         cat_avg = .brsum_pct(mpen_cat_avg, "%", scale = 100), rank = NA_character_),
    list(label = "Bought target",
         value = .brsum_pct(bt_value, "%", scale = 100),
         cat_avg = .brsum_pct(bt_cat_avg, "%", scale = 100), rank = NA_character_),
    list(label = "Loyalty (Sole)",
         value = .brsum_pct(loy_value, "%", already_pct = TRUE),
         cat_avg = .brsum_pct(loy_cat_avg, "%", already_pct = TRUE),
         rank = NA_character_),
    list(label = "Net WOM",
         value = .brsum_signed(net_wom),
         cat_avg = .brsum_signed(net_wom_cat_avg), rank = NA_character_)
  )

  # ---- MA metrics card (4 chips: MPen, NS, MMS, SOM) ----
  # MPen and MMS already computed above. NS comes from ma$ns; SOM is
  # derived (MMS / MPen × 100) per the Romaniuk 2022 definition.
  ns_value   <- NA_real_
  ns_cat_avg <- NA_real_
  ns_leader  <- NA_character_
  if (!is.null(ma$ns) && nrow(ma$ns) > 0 && "NS" %in% names(ma$ns)) {
    ns_cat_avg <- mean(ma$ns$NS, na.rm = TRUE)
    if (brand_code %in% ma$ns$BrandCode)
      ns_value <- ma$ns$NS[ma$ns$BrandCode == brand_code]
    leader_idx <- which.max(ma$ns$NS)
    if (length(leader_idx) == 1)
      ns_leader <- as.character(ma$ns$BrandCode[leader_idx])
  }

  # SOM = MMS / MPen × 100 (share of mind vs share of awareness).
  som_for <- function(mms_v, mpen_v) {
    if (!is.finite(mms_v) || !is.finite(mpen_v) || mpen_v <= 0) NA_real_
    else (mms_v / mpen_v) * 100
  }
  som_value <- som_for(mms_value, mpen_value)
  som_cat_avg <- if (!is.null(ma$mms) && !is.null(ma$mpen) &&
                      nrow(ma$mms) > 0 && nrow(ma$mpen) > 0) {
    mer <- merge(ma$mms[, c("BrandCode", "MMS")],
                 ma$mpen[, c("BrandCode", "MPen")],
                 by = "BrandCode")
    s <- vapply(seq_len(nrow(mer)), function(i)
      som_for(mer$MMS[i], mer$MPen[i]), numeric(1))
    mean(s, na.rm = TRUE)
  } else NA_real_
  som_leader <- if (!is.null(ma$mms) && !is.null(ma$mpen)) {
    mer <- merge(ma$mms[, c("BrandCode", "MMS")],
                 ma$mpen[, c("BrandCode", "MPen")],
                 by = "BrandCode")
    s <- vapply(seq_len(nrow(mer)), function(i)
      som_for(mer$MMS[i], mer$MPen[i]), numeric(1))
    li <- which.max(s)
    if (length(li) == 1) as.character(mer$BrandCode[li]) else NA_character_
  } else NA_character_
  mpen_leader <- if (!is.null(ma$mpen) && nrow(ma$mpen) > 0) {
    li <- which.max(ma$mpen$MPen)
    if (length(li) == 1) as.character(ma$mpen$BrandCode[li]) else NA_character_
  } else NA_character_
  mms_leader <- if (!is.null(ma$mms) && nrow(ma$mms) > 0) {
    li <- which.max(ma$mms$MMS)
    if (length(li) == 1) as.character(ma$mms$BrandCode[li]) else NA_character_
  } else NA_character_

  ma_metrics <- list(
    list(key = "mpen", label = "Mental Penetration (MPen)",
         value = .brsum_pct(mpen_value, "%", scale = 100),
         cat_avg = .brsum_pct(mpen_cat_avg, "%", scale = 100),
         leader = label_map[[mpen_leader]] %||% mpen_leader,
         is_leader = !is.na(mpen_leader) && identical(mpen_leader, brand_code)),
    list(key = "ns", label = "Network Size (NS)",
         value = .brsum_num(ns_value, digits = 2),
         cat_avg = .brsum_num(ns_cat_avg, digits = 2),
         leader = label_map[[ns_leader]] %||% ns_leader,
         is_leader = !is.na(ns_leader) && identical(ns_leader, brand_code)),
    list(key = "mms", label = "Mental Market Share (MMS)",
         value = .brsum_pct(mms_value, "%"),
         cat_avg = .brsum_pct(mms_cat_avg, "%"),
         leader = label_map[[mms_leader]] %||% mms_leader,
         is_leader = !is.na(mms_leader) && identical(mms_leader, brand_code)),
    list(key = "som", label = "Share of Mind (SOM)",
         value = .brsum_pct(som_value, "%", already_pct = TRUE),
         cat_avg = .brsum_pct(som_cat_avg, "%", already_pct = TRUE),
         leader = label_map[[som_leader]] %||% som_leader,
         is_leader = !is.na(som_leader) && identical(som_leader, brand_code))
  )

  # ---- Brand summary card (Pen, Avg purchase, Vol share, SCR obs) ----
  # All four come from dirichlet_norms$norms_table for the focal brand;
  # cat avg is the unweighted mean across brands in the table.
  brand_summary_metrics <- list(
    list(key = "pen",       label = "Penetration",
         value = NA_character_, cat_avg = NA_character_),
    list(key = "buy_rate",  label = "Avg purchases / buyer",
         value = NA_character_, cat_avg = NA_character_),
    list(key = "vol_share", label = "Volume share",
         value = NA_character_, cat_avg = NA_character_),
    list(key = "scr_obs",   label = "SCR (observed)",
         value = NA_character_, cat_avg = NA_character_)
  )
  dn <- cr$dirichlet_norms
  if (!is.null(dn) && !identical(dn$status, "REFUSED") &&
      !is.null(dn$norms_table) && nrow(dn$norms_table) > 0) {
    nt <- dn$norms_table
    cat_mean_purch <- if (!is.null(dn$category_metrics$mean_purchases))
      as.numeric(dn$category_metrics$mean_purchases) else NA_real_
    vol_share_for <- function(pen, buy_rate) {
      if (!is.finite(pen) || !is.finite(buy_rate) || !is.finite(cat_mean_purch) ||
          cat_mean_purch == 0) return(NA_real_)
      buy_rate * (pen / 100) / cat_mean_purch * 100
    }
    pen_val   <- if (brand_code %in% nt$BrandCode)
      as.numeric(nt$Penetration_Obs_Pct[nt$BrandCode == brand_code]) else NA_real_
    buy_val   <- if (brand_code %in% nt$BrandCode)
      as.numeric(nt$BuyRate_Obs[nt$BrandCode == brand_code]) else NA_real_
    scr_val   <- if (brand_code %in% nt$BrandCode)
      as.numeric(nt$SCR_Obs_Pct[nt$BrandCode == brand_code]) else NA_real_
    vol_val   <- vol_share_for(pen_val, buy_val)
    pen_avg   <- mean(as.numeric(nt$Penetration_Obs_Pct), na.rm = TRUE)
    buy_avg   <- mean(as.numeric(nt$BuyRate_Obs),         na.rm = TRUE)
    scr_avg   <- mean(as.numeric(nt$SCR_Obs_Pct),         na.rm = TRUE)
    vol_avg   <- mean(vapply(seq_len(nrow(nt)), function(i)
      vol_share_for(as.numeric(nt$Penetration_Obs_Pct[i]),
                    as.numeric(nt$BuyRate_Obs[i])), numeric(1)), na.rm = TRUE)

    brand_summary_metrics[[1]]$value   <- .brsum_pct(pen_val, "%", already_pct = TRUE)
    brand_summary_metrics[[1]]$cat_avg <- .brsum_pct(pen_avg, "%", already_pct = TRUE)
    brand_summary_metrics[[2]]$value   <- .brsum_num(buy_val, digits = 1)
    brand_summary_metrics[[2]]$cat_avg <- .brsum_num(buy_avg, digits = 1)
    brand_summary_metrics[[3]]$value   <- .brsum_pct(vol_val, "%", already_pct = TRUE)
    brand_summary_metrics[[3]]$cat_avg <- .brsum_pct(vol_avg, "%", already_pct = TRUE)
    brand_summary_metrics[[4]]$value   <- .brsum_pct(scr_val, "%", already_pct = TRUE)
    brand_summary_metrics[[4]]$cat_avg <- .brsum_pct(scr_avg, "%", already_pct = TRUE)
  }

  # ---- WOM card (Net WOM only — focal vs cat avg) ----
  wom_card <- list(
    label   = "Net WOM",
    value   = .brsum_signed(net_wom),
    cat_avg = .brsum_signed(net_wom_cat_avg)
  )

  # ---- Diagnostic strip: top-3 attributes + top-3 CEPs by advantage ----
  # Prefer per-category labels passed in; fall back to MA's attribute_labels
  # field (built inside the engine when survey-structure attributes were
  # supplied).
  attr_label_df <- attr_labels %||% ma$attribute_labels
  attr_chips <- .brsum_top_advantage_chips(
    ma$attribute_advantage, brand_code, attr_label_df,
    label_col = "AttrText", code_col = "AttrCode")
  cep_chips  <- .brsum_top_advantage_chips(
    ma$cep_advantage, brand_code, cep_labels,
    label_col = "CEPText", code_col = "CEPCode")

  # Headline sentence (template-based, editable downstream)
  headline <- .brsum_headline_sentence(
    label, cat_name, mms_value, mms_rank, n_brands,
    mms_cat_avg)

  list(
    name = label,
    code = brand_code,
    colour = colour,
    headline = headline,
    focal_metrics = focal_metrics,
    diagnostic = list(attributes = attr_chips, ceps = cep_chips),
    ma_metrics = ma_metrics,
    brand_summary = brand_summary_metrics,
    wom = wom_card
  )
}


# Pull the top-N (default 3) stims with positive advantage for the given
# brand. `adv` is a `calculate_mental_advantage()` result list with fields
# `advantage` (matrix), `stim_codes`, `brand_codes`. `labels_df` is an
# optional data frame mapping codes to display labels.
.brsum_top_advantage_chips <- function(adv, brand_code, labels_df = NULL,
                                       label_col = "AttrText",
                                       code_col = "AttrCode", n = 3) {
  if (is.null(adv) || is.null(adv$advantage)) return(list())
  if (!brand_code %in% adv$brand_codes) return(list())
  vec <- adv$advantage[, brand_code, drop = TRUE]
  if (length(vec) == 0) return(list())
  # Top-N positive
  ord <- order(-vec)
  top_idx <- ord[seq_len(min(n, length(ord)))]
  out <- list()
  for (i in top_idx) {
    if (is.na(vec[i]) || vec[i] <= 0) next
    code <- names(vec)[i] %||% adv$stim_codes[i]
    lab <- code
    if (!is.null(labels_df) && code_col %in% names(labels_df) &&
        label_col %in% names(labels_df)) {
      m <- labels_df[[label_col]][match(code, labels_df[[code_col]])]
      if (!is.na(m) && nzchar(m)) lab <- m
    }
    out[[length(out) + 1L]] <- list(
      label = lab,
      delta = round(as.numeric(vec[i]), 1)
    )
  }
  out
}


# Headline sentence. Template-based. Inserts brand name + category position.
.brsum_headline_sentence <- function(brand_name, cat_name, mms, rank, n,
                                      mms_cat_avg) {
  bn <- brand_name %||% "This brand"
  cn <- if (is.null(cat_name) || is.na(cat_name)) "this category" else cat_name
  if (is.na(mms)) {
    return(sprintf("%s data not available for %s.", bn, cn))
  }

  rank_text <- if (!is.na(rank) && !is.na(n)) {
    if (rank == 1L) sprintf("the #1 brand in %s", cn)
    else if (rank == 2L) sprintf("the #2 brand in %s", cn)
    else if (rank == 3L) sprintf("the #3 brand in %s", cn)
    else sprintf("ranked %d of %d in %s", rank, n, cn)
  } else cn

  cmp <- if (!is.na(mms_cat_avg) && mms_cat_avg > 0) {
    delta <- mms - mms_cat_avg
    if (abs(delta) < 0.005) "in line with the category average"
    else if (delta > 0) sprintf("above the category average of %.0f%%",
                                 100 * mms_cat_avg)
    else sprintf("below the category average of %.0f%%",
                  100 * mms_cat_avg)
  } else ""

  sprintf("%s is %s with an MMS of %.0f%%%s.",
          bn, rank_text, 100 * mms,
          if (nzchar(cmp)) sprintf(", %s", cmp) else "")
}


# ==============================================================================
# INTERNAL: HTML BUILDERS
# ==============================================================================

.brsum_empty_panel <- function() {
  paste(
    '<div class="br-panel active" id="panel-summary">',
      '<div style="padding:48px;text-align:center;color:#64748b;">',
        '<p style="font-size:14px;">No deep-dive categories available for the executive summary.</p>',
      '</div>',
    '</div>',
    sep = "\n"
  )
}


.brsum_header <- function() {
  paste(
    '<div class="brsum-header">',
      '<div class="brsum-eyebrow">Executive Summary</div>',
      '<h1 class="brsum-title">How is this brand doing?</h1>',
      '<p class="brsum-subtitle">A category-by-category snapshot. Pick a category and a brand to see where it sits and why.</p>',
    '</div>',
    sep = "\n"
  )
}


.brsum_dropdown_bar <- function(payload) {
  cat_options <- vapply(names(payload$categories), function(cn) {
    sprintf('<option value="%s">%s</option>',
            .brsum_esc(cn), .brsum_esc(cn))
  }, character(1))

  # Brand options are populated dynamically by JS based on selected category;
  # we inject a placeholder.
  paste(
    '<div class="brsum-dropdown-bar">',
      '<div class="brsum-dropdown-group">',
        '<span class="brsum-dropdown-label">Category</span>',
        '<select class="brsum-dropdown" data-brsum-cat>',
          paste(cat_options, collapse = ""),
        '</select>',
      '</div>',
      '<div class="brsum-dropdown-group">',
        '<span class="brsum-dropdown-label">Brand</span>',
        '<select class="brsum-dropdown" data-brsum-brand></select>',
      '</div>',
    '</div>',
    sep = "\n"
  )
}


# ==============================================================================
# DASHBOARD SKELETON (v2 — card grid)
# ==============================================================================
# Layout (top → bottom):
#   1. Focal context strip — the chosen focal brand + category, displayed
#      once at the top so per-card headers don't have to repeat them.
#   2. Card grid — 11 cards, two per row, with the two dot-plots (CEP and
#      Brand attributes) spanning full width because they need horizontal
#      room. Card content is rendered by JS reading the JSON payload; this
#      function only emits empty containers + section labels.

.brsum_focal_context_strip <- function() {
  paste(
    '<div class="brsum-focal-context" data-brsum-focal-context>',
      '<span class="brsum-fc-eyebrow">FOCAL</span>',
      '<span class="brsum-fc-brand" data-brsum-fc-brand>&mdash;</span>',
      '<span class="brsum-fc-divider">&middot;</span>',
      '<span class="brsum-fc-cat" data-brsum-fc-cat>&mdash;</span>',
    '</div>',
    sep = "\n"
  )
}


.brsum_card_grid_skeleton <- function() {
  card <- function(key, title, wide = FALSE) {
    cls <- if (wide) ' brsum-card-wide' else ''
    paste0(
      '<section class="brsum-card brsum-card-', key, cls,
        '" data-brsum-card="', key, '">',
        '<header class="brsum-card-header">',
          '<h3 class="brsum-card-title">', title, '</h3>',
          '<span class="brsum-card-meta" data-brsum-card-meta="', key, '"></span>',
        '</header>',
        '<div class="brsum-card-body" data-brsum-card-body="', key, '"></div>',
      '</section>')
  }
  paste(
    '<div class="brsum-card-grid">',
      card("context",       "Category context"),
      card("ma_metrics",    "Mental Availability — headline metrics"),
      card("brand_summary", "Brand summary"),
      card("funnel",        "Brand funnel"),
      card("attitude",      "Brand attitude"),
      card("loyalty",       "Loyalty segmentation"),
      card("purchase_dist", "Purchase distribution"),
      card("wom",           "Word of mouth"),
      card("dop",           "Duplication of purchase"),
      card("cep",           "Category Entry Points",  wide = TRUE),
      card("attrs",         "Brand attributes",       wide = TRUE),
    '</div>',
    sep = "\n"
  )
}


.brsum_insight_editor <- function() {
  paste(
    '<div class="brsum-insight-block">',
      '<div class="brsum-strip-title">Analyst commentary</div>',
      '<div class="brsum-insight-toolbar">',
        '<button class="brsum-insight-btn" title="Bold" onclick="brsumInsertMd(\'**\',\'**\')"><strong>B</strong></button>',
        '<button class="brsum-insight-btn" title="Italic" onclick="brsumInsertMd(\'*\',\'*\')"><em>I</em></button>',
        '<button class="brsum-insight-btn" title="Heading" onclick="brsumInsertMd(\'## \',\'\')">H2</button>',
        '<button class="brsum-insight-btn" title="Bullet" onclick="brsumInsertMd(\'- \',\'\')">&bull;</button>',
        '<button class="brsum-insight-btn" title="Quote" onclick="brsumInsertMd(\'&gt; \',\'\')">&ldquo;</button>',
        '<span class="brsum-insight-hint">**bold**, *italic*, ## heading, - bullet, &gt; quote</span>',
      '</div>',
      '<textarea class="brsum-insight-editor" id="brsum-insight-editor" rows="5" placeholder="Type the brand story for this category. The headline above is editable here." oninput="brsumRenderInsight()"></textarea>',
      '<div class="brsum-insight-rendered" id="brsum-insight-rendered"></div>',
    '</div>',
    sep = "\n"
  )
}


.brsum_closing_strip <- function(deep_cats, payload, focal_brand) {
  # Only show the "across all categories" strip when there are 2+ deep-dive
  # categories. Single-category reports (the common case) don't benefit from
  # this view — it just adds noise.
  if (length(deep_cats) < 2 || !nzchar(focal_brand)) return("")
  cards <- character(0)
  for (cn in deep_cats) {
    cat_payload <- payload$categories[[cn]]
    if (is.null(cat_payload)) next
    snap <- cat_payload$brands[[focal_brand]]
    if (is.null(snap)) next
    mms <- snap$focal_metrics[[1]]$value
    mpen <- snap$focal_metrics[[2]]$value
    bt   <- snap$focal_metrics[[3]]$value
    cards <- c(cards, sprintf(
      '<div class="brsum-mini-card" onclick="brsumSwitchCat(\'%s\')">
         <div class="brsum-mini-cat">%s</div>
         <div class="brsum-mini-row"><span>MMS</span><span class="brsum-mini-num">%s</span></div>
         <div class="brsum-mini-row"><span>MPen</span><span class="brsum-mini-num">%s</span></div>
         <div class="brsum-mini-row"><span>Bought-T</span><span class="brsum-mini-num">%s</span></div>
       </div>',
      .brsum_esc(cn), .brsum_esc(cn), .brsum_esc(mms),
      .brsum_esc(mpen), .brsum_esc(bt)
    ))
  }
  if (length(cards) == 0) return("")
  paste(
    '<div class="brsum-closing">',
      sprintf('<div class="brsum-strip-title">%s across all categories</div>',
              .brsum_esc(payload$categories[[deep_cats[1]]]$brands[[focal_brand]]$name %||% focal_brand)),
      '<div class="brsum-mini-grid">',
        paste(cards, collapse = "\n"),
      '</div>',
    '</div>',
    sep = "\n"
  )
}


.brsum_educational_callout <- function() {
  body <- paste(
    '<p>This Executive Summary answers one question per brand-and-category: <strong>"How is this brand doing in this category, and why?"</strong></p>',
    '<p><strong>Category context</strong> &mdash; the size and shape of the category. Baselines, not brand metrics.</p>',
    '<p><strong>Where the brand sits</strong> &mdash; five metrics that locate the brand. Big numbers are the brand\'s value; small numbers are the category average. MMS rank tells you where the brand stands against competitors on mental marketshare (the equity benchmark).</p>',
    '<p><strong>Why it sits there</strong> &mdash; the diagnostic. Strongest associations (attributes) and the moments the brand owns (Category Entry Points) explain the position above.</p>',
    '<p><strong>Analyst commentary</strong> &mdash; your written take. Drives the narrative for stakeholders who skim numbers.</p>',
    '<p style="margin-top:12px;color:#64748b;font-size:12px;">Drill into any sub-tab on this category for the full evidence behind these summaries.</p>',
    sep = "\n")

  # TODO: when the central Turas callout editor lands, replace this static
  # body with `turas_callout("brand", "executive_summary", collapsed = TRUE)`
  # so the copy can be maintained outside this file.
  paste(
    '<div class="brsum-edu" data-brsum-edu>',
      '<button class="brsum-edu-toggle" type="button" onclick="brsumToggleEdu(this)">',
        '<span class="brsum-edu-arrow">&#x25B6;</span>',
        '<span>How to read this dashboard</span>',
      '</button>',
      sprintf('<div class="brsum-edu-body">%s</div>', body),
    '</div>',
    sep = "\n"
  )
}


# ==============================================================================
# INTERNAL: FORMATTING HELPERS
# ==============================================================================

# Pretty percentage formatter. Handles three input shapes:
#  - already_pct = TRUE: value is already in 0..100 scale (e.g. Sole_Pct)
#  - scale = 100: value is in 0..1, multiply by 100 (e.g. MPen)
#  - default: value is in 0..1 (e.g. MMS)
.brsum_pct <- function(x, suffix = "%", scale = 100,
                       already_pct = FALSE) {
  if (is.null(x) || is.na(x)) return("—")
  if (already_pct) return(sprintf("%.0f%s", x, suffix))
  sprintf("%.0f%s", x * scale, suffix)
}


# Signed-integer formatter (for net WOM)
.brsum_signed <- function(x) {
  if (is.null(x) || is.na(x)) return("—")
  if (x > 0) sprintf("+%.0f", x)
  else sprintf("%.0f", x)
}


# Plain numeric formatter (for NS, avg purchases — not a percentage)
.brsum_num <- function(x, digits = 1) {
  if (is.null(x) || is.na(x) || !is.finite(x)) return("—")
  sprintf(paste0("%.", as.integer(digits), "f"), x)
}


.brsum_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


.brsum_json <- function(payload) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", null = "null",
                   pretty = FALSE, digits = 6)
}


# Local null-coalesce. Some R versions / module load orders may not have
# the global %||%, so define a local fallback.
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
