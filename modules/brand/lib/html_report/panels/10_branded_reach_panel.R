# ==============================================================================
# BRAND MODULE - BRANDED REACH PANEL HTML RENDERER
# ==============================================================================
# Emits the Branded Reach tab's HTML fragment. Three internal sub-tabs:
#   1) Overview      — per-ad reach / branded reach / branding %
#   2) Misattribution — per-ad table of brand attribution among seen
#   3) Media mix     — per-ad table of channel mix among seen
#
# Each sub-tab renders a card per ad. Cards include the ad's image
# (config$image_path resolves relative to the report's directory).
#
# Pin/PNG capture works via the existing brand_pins.js machinery: the
# panel root is wrapped in a section with id "section-{cat_id}" and
# data-section by build_br_category_panel.
#
# VERSION: 1.0
# ==============================================================================

BRAND_BRANDED_REACH_PANEL_VERSION <- "1.0"


#' Build branded-reach panel HTML
#'
#' @param panel_data List from \code{build_branded_reach_panel_data()}.
#' @param category_code Character. Used to scope element ids on the page.
#' @param focal_colour Character. Hex colour for focal-brand highlights.
#' @return Character. Single HTML fragment.
#' @export
build_branded_reach_panel_html <- function(panel_data,
                                            category_code = "cat",
                                            focal_colour = "#1A5276") {

  if (is.null(panel_data) ||
      identical(panel_data$meta$status %||% "", "REFUSED") ||
      length(panel_data$ads) == 0) {
    return('<div class="br-reach-empty" style="padding:32px;text-align:center;color:#94a3b8;font-size:14px;">No branded-reach assets configured for this category. Populate the MarketingReach sheet in Survey_Structure.xlsx and set <code>element_branded_reach = Y</code>.</div>')
  }

  panel_id     <- paste0("br-reach-", category_code)
  json_payload <- .br_reach_panel_json(panel_data, focal_colour)

  paste0(
    sprintf(
      '<div class="br-reach-panel" id="%s" data-cat-code="%s" data-focal-colour="%s">',
      panel_id, .br_reach_esc(category_code), .br_reach_esc(focal_colour)),
    sprintf('<script type="application/json" class="br-reach-panel-data">%s</script>',
            json_payload),
    .br_reach_subnav(category_code),
    .br_reach_subtab_overview(panel_data, category_code, focal_colour),
    .br_reach_subtab_misattribution(panel_data, category_code, focal_colour),
    .br_reach_subtab_media(panel_data, category_code, focal_colour),
    .br_reach_insight_box(),
    '</div>'
  )
}


# ==============================================================================
# SUB-TAB NAV
# ==============================================================================

.br_reach_subnav <- function(cat_code) {
  tabs <- list(
    list(key = "overview",      label = "Overview"),
    list(key = "misattribution", label = "Misattribution"),
    list(key = "media",          label = "Media mix")
  )
  btns <- paste(vapply(tabs, function(t) {
    active <- if (identical(t$key, "overview")) " active" else ""
    sprintf(
      '<button type="button" class="br-reach-subtab-btn%s" data-br-reach-tab="%s">%s</button>',
      active, t$key, .br_reach_esc(t$label))
  }, character(1)), collapse = "")
  sprintf('<nav class="br-reach-subnav" data-br-reach-scope="%s">%s</nav>',
          .br_reach_esc(cat_code), btns)
}


# ==============================================================================
# OVERVIEW SUB-TAB
# ==============================================================================

.br_reach_subtab_overview <- function(pd, cat_code, focal_colour) {
  cards <- paste(vapply(pd$ads, function(ad) {
    .br_reach_overview_card(ad, focal_colour,
                             pd$config$decimal_places %||% 0L,
                             cat_code = cat_code)
  }, character(1)), collapse = "")

  sprintf(
    '<section class="br-reach-subtab" data-br-reach-tab="overview">
       <p class="br-reach-blurb">For each ad: <strong>Reach</strong> = %% who saw it; <strong>Branded reach</strong> = %% who saw it AND correctly attributed it to %s; <strong>Branding %%</strong> = of those who saw it, %% correctly attributed.</p>
       <div class="br-reach-card-grid">%s</div>
     </section>',
    .br_reach_esc(pd$meta$focal_brand %||% "the focal brand"), cards)
}


.br_reach_overview_card <- function(ad, focal_colour, dp, cat_code) {
  reach_pct        <- .br_reach_pct(ad$reach_pct, dp)
  branded_pct      <- .br_reach_pct(ad$branded_reach_pct, dp)
  branding_pct     <- .br_reach_pct(ad$branding_pct, dp)
  n_eligible_lbl   <- .br_reach_int(ad$n_eligible)
  n_seen_lbl       <- .br_reach_int(ad$n_seen)

  img_html <- .br_reach_image_block(ad)
  base_lbl <- sprintf("n eligible = %s; n saw it = %s",
                      n_eligible_lbl, n_seen_lbl)
  section_id <- .br_reach_card_section_id(cat_code, ad$asset_code, "overview")

  # data-pin-as-table on a wrapper around image + KPIs so brand_pins.js
  # captureFromRoot has something to grab when the card has no <table>.
  sprintf(
    '<article class="br-reach-card br-element-section" id="section-%s" data-section="%s" data-br-asset="%s">
       <header class="br-reach-card-header">
         <div class="br-reach-card-titlebar">
           <h3 class="br-reach-card-title br-element-title">%s</h3>
           %s
         </div>
         <div class="br-reach-card-sub">%s</div>
       </header>
       <div class="br-reach-card-body" data-pin-as-table>
         %s
         <div class="br-reach-kpi-row">
           <div class="br-reach-kpi"><div class="br-reach-kpi-val">%s</div><div class="br-reach-kpi-label">Reach</div></div>
           <div class="br-reach-kpi" style="border-color:%s"><div class="br-reach-kpi-val" style="color:%s">%s</div><div class="br-reach-kpi-label">Branded reach</div></div>
           <div class="br-reach-kpi"><div class="br-reach-kpi-val">%s</div><div class="br-reach-kpi-label">Branding %%</div></div>
         </div>
         <div class="br-reach-card-base">%s</div>
       </div>
     </article>',
    .br_reach_esc(section_id), .br_reach_esc(section_id),
    .br_reach_esc(ad$asset_code),
    .br_reach_esc(ad$asset_label %||% ad$asset_code),
    .br_reach_card_toolbar(section_id),
    .br_reach_esc(.br_reach_correct_label(ad)),
    img_html,
    reach_pct,
    .br_reach_esc(focal_colour), .br_reach_esc(focal_colour), branded_pct,
    branding_pct,
    .br_reach_esc(base_lbl))
}


# ==============================================================================
# MISATTRIBUTION SUB-TAB
# ==============================================================================

.br_reach_subtab_misattribution <- function(pd, cat_code, focal_colour) {
  cards <- paste(vapply(pd$ads, function(ad) {
    asset_id <- ad$asset_code
    table_df <- pd$misattribution[[asset_id]]
    .br_reach_misattribution_card(ad, table_df, focal_colour,
                                   pd$config$decimal_places %||% 0L,
                                   cat_code = cat_code)
  }, character(1)), collapse = "")

  sprintf(
    '<section class="br-reach-subtab" data-br-reach-tab="misattribution" hidden>
       <p class="br-reach-blurb">Of respondents who said they saw each ad, which brand did they pick? Rows show every brand in the category plus DK / OTHER. The focal brand is highlighted.</p>
       <div class="br-reach-card-grid">%s</div>
     </section>', cards)
}


.br_reach_misattribution_card <- function(ad, table_df, focal_colour, dp,
                                            cat_code) {
  if (is.null(table_df) || !is.data.frame(table_df) || nrow(table_df) == 0) {
    rows <- '<tr><td colspan="3" class="br-reach-empty-cell">No attribution data for this ad.</td></tr>'
  } else {
    rows <- paste(vapply(seq_len(nrow(table_df)), function(i) {
      bc       <- table_df$BrandCode[i]
      bl       <- table_df$BrandLabel[i]
      n_val    <- as.integer(round(table_df$n[i]))
      pct_val  <- table_df$pct_of_seen[i]
      pct_disp <- .br_reach_pct(pct_val, dp)
      is_corr  <- isTRUE(table_df$is_correct[i])
      tag <- if (is_corr) ' <span class="br-reach-focal-tag">FOCAL</span>' else ""
      sprintf(
        '<tr class="%s"><td class="br-reach-attr-brand">%s%s</td><td class="br-reach-attr-pct">%s</td><td class="br-reach-attr-n">%d</td></tr>',
        if (is_corr) "br-reach-row-focal" else "br-reach-row-other",
        .br_reach_esc(bl), tag, pct_disp, n_val)
    }, character(1)), collapse = "")
  }

  img_html   <- .br_reach_image_block(ad)
  section_id <- .br_reach_card_section_id(cat_code, ad$asset_code, "misattribution")

  sprintf(
    '<article class="br-reach-card br-element-section" id="section-%s" data-section="%s" data-br-asset="%s">
       <header class="br-reach-card-header">
         <div class="br-reach-card-titlebar">
           <h3 class="br-reach-card-title br-element-title">%s</h3>
           %s
         </div>
         <div class="br-reach-card-sub">%s</div>
       </header>
       <div class="br-reach-card-body">
         %s
         <table class="br-reach-attr-table">
           <thead><tr><th>Brand picked</th><th>%% of seen</th><th>n</th></tr></thead>
           <tbody>%s</tbody>
         </table>
       </div>
     </article>',
    .br_reach_esc(section_id), .br_reach_esc(section_id),
    .br_reach_esc(ad$asset_code),
    .br_reach_esc(ad$asset_label %||% ad$asset_code),
    .br_reach_card_toolbar(section_id),
    .br_reach_esc(.br_reach_correct_label(ad)),
    img_html,
    rows)
}


# ==============================================================================
# MEDIA MIX SUB-TAB
# ==============================================================================

.br_reach_subtab_media <- function(pd, cat_code, focal_colour) {
  cards <- paste(vapply(pd$ads, function(ad) {
    asset_id <- ad$asset_code
    table_df <- pd$media_mix[[asset_id]]
    .br_reach_media_card(ad, table_df, focal_colour,
                          pd$config$decimal_places %||% 0L,
                          cat_code = cat_code)
  }, character(1)), collapse = "")

  sprintf(
    '<section class="br-reach-subtab" data-br-reach-tab="media" hidden>
       <p class="br-reach-blurb">Of respondents who said they saw each ad, where did they say they saw it? Multi-mention — totals exceed 100%%.</p>
       <div class="br-reach-card-grid">%s</div>
     </section>', cards)
}


.br_reach_media_card <- function(ad, table_df, focal_colour, dp, cat_code) {
  if (is.null(table_df) || !is.data.frame(table_df) || nrow(table_df) == 0) {
    rows <- '<tr><td colspan="3" class="br-reach-empty-cell">No media data for this ad.</td></tr>'
  } else {
    max_pct <- max(table_df$pct_of_seen, na.rm = TRUE)
    if (!is.finite(max_pct) || max_pct <= 0) max_pct <- 1
    rows <- paste(vapply(seq_len(nrow(table_df)), function(i) {
      mc       <- table_df$MediaCode[i]
      ml       <- table_df$MediaLabel[i]
      n_val    <- as.integer(round(table_df$n[i]))
      pct_val  <- table_df$pct_of_seen[i]
      pct_disp <- .br_reach_pct(pct_val, dp)
      bar_w    <- if (is.finite(pct_val)) max(2, 100 * pct_val / max_pct) else 0
      sprintf(
        '<tr><td class="br-reach-media-label">%s</td><td class="br-reach-media-bar"><div class="br-reach-media-bar-fill" style="width:%.1f%%;background-color:%s"></div></td><td class="br-reach-media-pct">%s</td><td class="br-reach-media-n">%d</td></tr>',
        .br_reach_esc(ml), bar_w, .br_reach_esc(focal_colour), pct_disp, n_val)
    }, character(1)), collapse = "")
  }

  img_html   <- .br_reach_image_block(ad)
  section_id <- .br_reach_card_section_id(cat_code, ad$asset_code, "media")

  sprintf(
    '<article class="br-reach-card br-element-section" id="section-%s" data-section="%s" data-br-asset="%s">
       <header class="br-reach-card-header">
         <div class="br-reach-card-titlebar">
           <h3 class="br-reach-card-title br-element-title">%s</h3>
           %s
         </div>
         <div class="br-reach-card-sub">%s</div>
       </header>
       <div class="br-reach-card-body">
         %s
         <table class="br-reach-media-table">
           <thead><tr><th>Channel</th><th></th><th>%%</th><th>n</th></tr></thead>
           <tbody>%s</tbody>
         </table>
       </div>
     </article>',
    .br_reach_esc(section_id), .br_reach_esc(section_id),
    .br_reach_esc(ad$asset_code),
    .br_reach_esc(ad$asset_label %||% ad$asset_code),
    .br_reach_card_toolbar(section_id),
    .br_reach_esc(.br_reach_correct_label(ad)),
    img_html,
    rows)
}


# ==============================================================================
# IMAGE BLOCK
# ==============================================================================
# When an ad's ImagePath is populated AND the file exists relative to the
# report's output directory, embed it. Otherwise render a stylised
# placeholder so the layout stays consistent across ads.

.br_reach_image_block <- function(ad) {
  img_path <- ad$image_path
  if (is.null(img_path) || is.na(img_path) || !nzchar(trimws(img_path))) {
    return('<div class="br-reach-img-placeholder" aria-label="No image supplied"><span>No image</span></div>')
  }
  sprintf(
    '<div class="br-reach-img-wrap"><img class="br-reach-img" src="%s" alt="%s" onerror="this.parentNode.innerHTML=\'<div class=\\\'br-reach-img-placeholder\\\'><span>Image not found</span></div>\'"></div>',
    .br_reach_esc(img_path),
    .br_reach_esc(ad$asset_label %||% ad$asset_code))
}


# ==============================================================================
# INSIGHT BOX
# ==============================================================================

.br_reach_insight_box <- function() {
  '<section class="br-reach-insight-box ma-insight-box" data-br-reach-stim="reach">
     <div class="ma-insight-box-header">
       <span class="ma-insight-box-title">Insight</span>
       <button type="button" class="ma-insight-box-clear" data-br-reach-action="clear-insight" title="Clear">&#215;</button>
     </div>
     <textarea class="ma-insight-box-text" placeholder="Write the headline for this tab (one or two sentences)…"></textarea>
   </section>'
}


# ==============================================================================
# HELPERS
# ==============================================================================

.br_reach_pct <- function(v, dp) {
  if (is.null(v) || is.na(v) || !is.finite(v)) return('<span class="br-reach-na">—</span>')
  sprintf("%.*f%%", as.integer(dp), 100 * v)
}

.br_reach_int <- function(v) {
  if (is.null(v) || is.na(v) || !is.finite(v)) return("—")
  sprintf("%d", as.integer(round(v)))
}

.br_reach_card_section_id <- function(cat_code, asset_code, tab_key) {
  # Match the page-builder's category id slug rule (lowercase, non-alnum -> '-')
  cat_id   <- gsub("[^a-z0-9]", "-", tolower(as.character(cat_code %||% "cat")))
  asset_id <- gsub("[^a-z0-9]", "-", tolower(as.character(asset_code %||% "ad")))
  sprintf("br-reach-%s-%s-%s", cat_id, asset_id, tab_key)
}


.br_reach_card_toolbar <- function(section_id) {
  # Per-card pin + PNG buttons. Onclick handlers call the existing
  # window.brTogglePin / window.brExportPng wired by brand_pins.js — they
  # find the section via [data-section] / id="section-<sid>".
  sprintf(
    '<div class="br-reach-card-toolbar" data-section="%s">
       <button class="br-pin-btn br-reach-card-pin" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin this card">&#x1F4CC;</button>
       <button class="br-png-btn br-reach-card-png" onclick="brExportPng(\'%s\',this)" title="Export PNG of this card">&#x1F5BC;</button>
     </div>',
    .br_reach_esc(section_id), .br_reach_esc(section_id),
    .br_reach_esc(section_id), .br_reach_esc(section_id))
}


.br_reach_correct_label <- function(ad) {
  bc  <- ad$correct_brand %||% ""
  cat <- ad$category %||% ""
  if (cat == "ALL" || !nzchar(cat)) {
    sprintf("Correct brand: %s", bc)
  } else {
    sprintf("Correct brand: %s · Category: %s", bc, cat)
  }
}

.br_reach_panel_json <- function(pd, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  payload <- list(
    meta           = pd$meta,
    ads            = pd$ads,
    misattribution = pd$misattribution,
    media_mix      = pd$media_mix,
    config         = pd$config,
    focal_colour   = focal_colour
  )
  jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null",
                   pretty = FALSE, digits = 6)
}

.br_reach_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# CSS
# ==============================================================================
# Returned as a fragment to be concatenated into the page <style> block.
# Mirrors the WOM panel pattern: keep all styles scoped under .br-reach-panel
# so they cannot leak into other tabs.

#' Build branded-reach panel CSS
#' @param focal_colour Character. Hex colour for focal accents.
#' @return Character. CSS string (no <style> tags).
#' @export
build_branded_reach_panel_styles <- function(focal_colour = "#1A5276") {
  sprintf('
.br-reach-panel { font: 13px/1.45 system-ui, -apple-system, Segoe UI, sans-serif; color: #1e293b; }
.br-reach-empty { font-style: italic; }

.br-reach-subnav { display:flex; gap:6px; margin: 4px 0 16px; border-bottom: 1px solid #e2e8f0; padding-bottom: 6px; }
.br-reach-subtab-btn { background:none; border:1px solid transparent; padding:6px 12px; border-radius:6px; cursor:pointer; font-size:12px; color:#64748b; }
.br-reach-subtab-btn:hover { background:#f1f5f9; }
.br-reach-subtab-btn.active { background: %s; color:#fff; border-color: %s; }

.br-reach-subtab { padding-top: 4px; }
.br-reach-blurb  { font-size:12px; color:#64748b; margin: 0 0 14px; }

.br-reach-card-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: 16px; }

.br-reach-card { background:#fff; border:1px solid #e2e8f0; border-radius:10px; padding:14px; box-shadow: 0 1px 2px rgba(0,0,0,.03); position: relative; }
.br-reach-card-header { margin-bottom: 10px; }
.br-reach-card-titlebar { display: flex; align-items: flex-start; justify-content: space-between; gap: 8px; }
.br-reach-card-title  { font-weight: 600; font-size: 14px; color:#0f172a; margin: 0; line-height: 1.3; }
.br-reach-card-sub    { font-size: 11px; color:#64748b; margin-top: 4px; }

/* Per-card pin + PNG toolbar — small, top-right, dimmed until card hover */
.br-reach-card-toolbar { display: flex; gap: 4px; flex-shrink: 0; opacity: .35; transition: opacity .15s; }
.br-reach-card:hover .br-reach-card-toolbar,
.br-reach-card-toolbar:focus-within { opacity: 1; }
.br-reach-card-pin, .br-reach-card-png {
  background:#fff; border:1px solid #e2e8f0; border-radius:6px; cursor:pointer;
  padding:3px 7px; font-size:13px; line-height:1; color:#64748b;
  transition: background-color .12s, border-color .12s, color .12s;
}
.br-reach-card-pin:hover, .br-reach-card-png:hover { background:#f1f5f9; border-color:#cbd5e1; color:#0f172a; }
.br-reach-card-pin.pin-flash { background: %s; border-color: %s; color:#fff; }

.br-reach-img-wrap { background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; overflow:hidden; margin-bottom:12px; aspect-ratio: 16 / 9; display:flex; align-items:center; justify-content:center; }
.br-reach-img      { max-width:100%%; max-height:100%%; object-fit:contain; display:block; }
.br-reach-img-placeholder { width:100%%; height:100%%; display:flex; align-items:center; justify-content:center; color:#94a3b8; font-size:11px; font-style:italic; background: repeating-linear-gradient(45deg, #f8fafc, #f8fafc 8px, #eef2f7 8px, #eef2f7 16px); }

.br-reach-kpi-row { display:flex; gap:8px; margin: 6px 0 4px; }
.br-reach-kpi { flex:1; border:1px solid #e2e8f0; border-radius:8px; padding:10px 8px; text-align:center; background:#fff; }
.br-reach-kpi-val   { font-size:18px; font-weight:700; color:#0f172a; }
.br-reach-kpi-label { font-size:10px; color:#64748b; margin-top:2px; text-transform:uppercase; letter-spacing:.4px; }

.br-reach-card-base { font-size: 11px; color:#94a3b8; margin-top: 8px; }

/* Misattribution table */
.br-reach-attr-table { width:100%%; border-collapse: collapse; margin-top: 10px; font-size: 12px; }
.br-reach-attr-table th, .br-reach-attr-table td { padding: 6px 8px; border-bottom: 1px solid #f1f5f9; text-align: left; }
.br-reach-attr-table th { font-weight: 600; color:#64748b; font-size: 11px; text-transform:uppercase; letter-spacing:.4px; }
.br-reach-attr-pct { text-align:right; font-variant-numeric: tabular-nums; width: 90px; }
.br-reach-attr-n   { text-align:right; font-variant-numeric: tabular-nums; width: 60px; color:#94a3b8; }
.br-reach-row-focal { background-color: %s14; font-weight: 600; }
.br-reach-row-focal td { color:#0f172a; }
.br-reach-focal-tag { font-size: 9px; background: %s; color:#fff; padding: 1px 5px; border-radius: 3px; margin-left: 6px; vertical-align: middle; letter-spacing: .5px; }
.br-reach-empty-cell { text-align:center; color:#94a3b8; font-style:italic; padding:18px 0 !important; }

/* Media mix table */
.br-reach-media-table { width:100%%; border-collapse: collapse; margin-top: 10px; font-size: 12px; }
.br-reach-media-table th, .br-reach-media-table td { padding: 5px 6px; border-bottom: 1px solid #f1f5f9; text-align: left; }
.br-reach-media-table th { font-weight: 600; color:#64748b; font-size: 11px; text-transform:uppercase; letter-spacing:.4px; }
.br-reach-media-label { width: 30%%; }
.br-reach-media-bar   { width: 40%%; }
.br-reach-media-bar-fill { height: 10px; border-radius: 6px; opacity: .85; }
.br-reach-media-pct   { text-align:right; font-variant-numeric: tabular-nums; width: 60px; }
.br-reach-media-n     { text-align:right; font-variant-numeric: tabular-nums; width: 50px; color:#94a3b8; }

.br-reach-na { color: #cbd5e1; font-style: italic; }

.br-reach-insight-box { margin-top: 18px; }
', focal_colour, focal_colour, focal_colour, focal_colour, focal_colour, focal_colour)
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
