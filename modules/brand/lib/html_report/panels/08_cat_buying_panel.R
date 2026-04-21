# ==============================================================================
# BRAND MODULE - CATEGORY BUYING PANEL ASSEMBLER
# ==============================================================================
# Consumes dirichlet_norms, buyer_heaviness, repertoire (DoP), and
# cat_buying_frequency outputs and emits a self-contained HTML fragment
# for the Category Buying tab per §8 of CAT_BUYING_SPEC_v3.
#
# Layout (top → bottom):
#   1. KPI strip
#   2. Double Jeopardy scatter (DJ y-axis toggle: SCR | w)
#   3. Dirichlet norms table
#   4. Two-column: heaviness stacked bars | buy-rate profile
#   5. DoP deviation heatmap (toggle: Deviation | Observed)
#   6. Collapsible "Descriptive detail" (existing freq bars + repertoire)
#
# Sub-renderers:
#   08_cat_buying_panel_styling.R  — CSS
#   08_cat_buying_panel_chart.R    — SVG builders
#   08_cat_buying_panel_table.R    — norms table + partition callout
#
# SIZE-EXCEPTION: sequential HTML assembly pipeline. Decomposing further
# would require threading many small strings between helper functions,
# reducing readability of the layout specification.
#
# VERSION: 1.0
# ==============================================================================

BRAND_CB_PANEL_VERSION <- "1.0"

# Source sub-renderers if not already loaded
local({
  base <- tryCatch(
    dirname(sys.frame(1)$ofile),
    error = function(e) "modules/brand/lib/html_report/panels"
  )
  for (f in c("08_cat_buying_panel_styling.R",
              "08_cat_buying_panel_chart.R",
              "08_cat_buying_panel_table.R")) {
    fp <- file.path(base, f)
    if (file.exists(fp)) source(fp, local = FALSE)
  }
})

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a
if (!exists(".cb_esc", mode = "function")) {
  .cb_esc <- function(x) {
    if (is.null(x) || is.na(x)) return("")
    x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
  }
}


# ==============================================================================
# PUBLIC ENTRY POINT
# ==============================================================================

#' Render the Category Buying HTML panel
#'
#' Assembles all sections into a single HTML fragment. Any upstream
#' \code{REFUSED} element is shown as a refusal block; remaining sections
#' still render.
#'
#' @param panel_data List produced by \code{transform_cat_buying_panel_data()}.
#'   Must contain: \code{cat_name}, \code{category_code}, \code{focal_brand},
#'   \code{focal_colour}, \code{target_months}, \code{longer_months},
#'   \code{dirichlet_norms}, \code{buyer_heaviness}, \code{cat_buying_frequency},
#'   \code{repertoire}.
#'
#' @return Character. A single HTML fragment (string).
#' @export
render_cat_buying_panel <- function(panel_data) {
  if (is.null(panel_data)) {
    return('<div class="cb-refused">Category Buying panel data not available.</div>')
  }

  cat_code    <- panel_data$category_code %||% "cat"
  focal       <- panel_data$focal_brand   %||% NULL
  fcol        <- panel_data$focal_colour  %||% "#1A5276"
  t_months    <- panel_data$target_months %||% 3L
  l_months    <- panel_data$longer_months %||% 12L
  dn          <- panel_data$dirichlet_norms
  bh          <- panel_data$buyer_heaviness
  cbf         <- panel_data$cat_buying_frequency
  rep         <- panel_data$repertoire
  brand_labels <- panel_data$brand_labels %||% NULL

  has_dn <- !is.null(dn) && !identical(dn$status, "REFUSED")
  has_bh <- !is.null(bh) && !identical(bh$status, "REFUSED")

  panel_id <- paste0("cb-panel-", cat_code)
  parts    <- character(0)

  # CSS (injected once per panel — duplicate <style> tags are harmless in HTML5)
  if (exists("cb_panel_css", mode = "function")) parts <- c(parts, cb_panel_css())

  # Panel div with focal colour as CSS variable for chip active state
  parts <- c(parts, sprintf(
    '<div class="cb-panel" id="%s" data-focal-colour="%s" style="--cb-focal-colour:%s;">',
    panel_id, .cb_esc(fcol), .cb_esc(fcol)))

  # Panel subtitle
  subtitle <- sprintf("Target timeframe: last %d months \u00b7 Longer timeframe: last %d months",
                       t_months, l_months)
  parts <- c(parts, sprintf(
    '<p class="cb-subtitle" style="margin-top:0;">%s</p>', .cb_esc(subtitle)))

  # -------------------------------------------------------------------
  # 0b. FOCAL BRAND PICKER (chips)
  # -------------------------------------------------------------------
  parts <- c(parts, .cb_brand_picker(dn, bh, focal, fcol, cat_code, brand_labels))

  # -------------------------------------------------------------------
  # 0c. PER-BRAND KPI JSON (embedded for JS focal switching)
  # -------------------------------------------------------------------
  parts <- c(parts, .cb_kpi_json_script(dn, bh, cat_code))

  # -------------------------------------------------------------------
  # 1. KPI STRIP
  # -------------------------------------------------------------------
  parts <- c(parts, .cb_kpi_strip(dn, bh, cbf, fcol, focal, t_months))

  # -------------------------------------------------------------------
  # 1b. CATEGORY CONTEXT TABLES (frequency + repertoire)
  # -------------------------------------------------------------------
  parts <- c(parts, '<div class="cb-section-title">Category Context</div>')
  parts <- c(parts, '<p style="font-size:12px;color:#64748b;margin:-4px 0 8px;">Category-level purchase frequency and brand repertoire distributions among category buyers.</p>')
  if (exists("cb_freq_repertoire_tables_html", mode = "function")) {
    parts <- c(parts, cb_freq_repertoire_tables_html(cbf, rep))
  }

  # -------------------------------------------------------------------
  # 2. DOUBLE JEOPARDY SCATTER
  # -------------------------------------------------------------------
  parts <- c(parts, '<div class="cb-section-title">Double Jeopardy</div>')
  parts <- c(parts, sprintf(
    '<p style="font-size:12px;color:#64748b;margin:-4px 0 8px;">Brands with higher penetration tend to have modestly higher SCR (loyalty). Points above the curve are over-performing; points below are under-performing relative to Dirichlet expectations.</p>'))

  if (has_dn) {
    parts <- c(parts, .cb_dj_section(dn, focal, fcol, cat_code, brand_labels))
  } else {
    parts <- c(parts, .cb_refused_block(dn, "Double Jeopardy scatter"))
  }

  # -------------------------------------------------------------------
  # 3. DIRICHLET NORMS TABLE
  # -------------------------------------------------------------------
  parts <- c(parts, '<div class="cb-section-title">Dirichlet Norms</div>')
  parts <- c(parts, sprintf(
    '<p style="font-size:12px;color:#64748b;margin:-4px 0 8px;">Observed vs expected values under the Dirichlet model. \u0394%% \u2265 \u00b120%% shaded. Focal row bold.</p>'))

  if (has_dn && exists("cb_norms_table_html", mode = "function")) {
    parts <- c(parts, cb_norms_table_html(
      dn$norms_table, focal_brand = focal,
      target_months    = t_months,
      category_metrics = dn$category_metrics,
      cat_buying_freq  = cbf,
      brand_labels     = brand_labels))
  } else if (!has_dn) {
    parts <- c(parts, .cb_refused_block(dn, "Dirichlet norms table"))
  }

  # -------------------------------------------------------------------
  # 4. TWO-COLUMN: heaviness + buy-rate
  # -------------------------------------------------------------------
  parts <- c(parts, '<div class="cb-two-col">')

  # Left: heaviness stacked bars
  parts <- c(parts, '<div>')
  parts <- c(parts, '<div class="cb-section-title" style="margin-top:0;">Buyer Heaviness</div>')
  parts <- c(parts, '<p style="font-size:11px;color:#64748b;margin:-4px 0 8px;">L = Light | M = Medium | H = Heavy buyer tertile. Dotted lines = category mix.</p>')
  if (has_bh && exists("cb_heaviness_bars_svg", mode = "function")) {
    # "All same tier" note: triggers when all brands collapse into the light tier
    bh_df <- bh$brand_heaviness
    all_same_tier <- !is.null(bh_df) && nrow(bh_df) > 0 &&
      all(bh_df$Heavy_Pct  < 5, na.rm = TRUE) &&
      all(bh_df$Medium_Pct < 5, na.rm = TRUE)
    if (all_same_tier) {
      parts <- c(parts, '<p style="font-size:11px;color:#92400e;background:#fffbeb;border:1px solid #fde68a;border-radius:4px;padding:4px 10px;margin:0 0 6px;">\u26a0 All brands fall in the same buyer tier. Tertile cut-points may be extreme; interpret with caution.</p>')
    }
    parts <- c(parts, cb_heaviness_bars_svg(
      bh$brand_heaviness, bh$category_buyer_mix, focal, fcol, brand_labels))
  } else {
    parts <- c(parts, .cb_refused_block(bh, "Buyer heaviness"))
  }
  parts <- c(parts, '</div>')

  # Right: buy-rate profile
  parts <- c(parts, '<div>')
  parts <- c(parts, '<div class="cb-section-title" style="margin-top:0;">Buy Rate Profile</div>')
  parts <- c(parts, '<p style="font-size:11px;color:#64748b;margin:-4px 0 8px;">Mean purchases per buyer in the target window. Dotted line = category mean.</p>')
  if (has_bh && exists("cb_buyrate_bars_svg", mode = "function")) {
    parts <- c(parts, cb_buyrate_bars_svg(bh$brand_heaviness, focal, fcol, brand_labels))
  } else {
    parts <- c(parts, .cb_refused_block(bh, "Buy rate profile"))
  }
  parts <- c(parts, '</div>')

  parts <- c(parts, '</div>') # close two-col

  # -------------------------------------------------------------------
  # 5. DoP DEVIATION HEATMAP
  # -------------------------------------------------------------------
  parts <- c(parts, '<div class="cb-section-title">Duplication of Purchase (Deviation from Law)</div>')
  parts <- c(parts, '<p style="font-size:12px;color:#64748b;margin:-4px 0 8px;">Positive (green) = more duplication than expected; negative (red) = less. Values in percentage points.</p>')

  dev_mat <- rep$dop_deviation_matrix %||% NULL
  obs_mat <- rep$crossover_matrix     %||% NULL

  if (!is.null(dev_mat) && exists("cb_dop_heatmap_html", mode = "function")) {
    parts <- c(parts, .cb_dop_section(dev_mat, obs_mat, focal, cat_code, rep, brand_labels))
  } else {
    parts <- c(parts,
      '<p style="font-size:12px;color:#94a3b8;">DoP deviation not available (requires BRANDPEN3 data).</p>')
  }

  # -------------------------------------------------------------------
  # 6. LIMITATIONS FOOTER
  # -------------------------------------------------------------------
  parts <- c(parts, .cb_limitations_footer(t_months))

  # -------------------------------------------------------------------
  # 6. COLLAPSIBLE DESCRIPTIVE DETAIL (existing charts demoted)
  # -------------------------------------------------------------------
  parts <- c(parts,
    sprintf('<button class="cb-details-toggle" onclick="_cbToggleDetails(\'%s\')">+ Descriptive detail (frequency, repertoire)</button>', cat_code),
    sprintf('<div class="cb-details-content" id="cb-details-%s">', cat_code),
    '<p style="font-size:12px;color:#64748b;padding:8px 0;">Legacy descriptive charts (category purchase frequency, repertoire size, brand repertoire profile) are available in the Export below.</p>',
    '</div>')

  parts <- c(parts, '</div>') # close cb-panel
  paste(parts, collapse = "\n")
}


# ==============================================================================
# INTERNAL SECTION BUILDERS
# ==============================================================================

#' Build the KPI chip strip (§8 item 1)
#' @keywords internal
.cb_kpi_strip <- function(dn, bh, cbf, fcol, focal, t_months) {
  chips <- character(0)

  # % Category buyers (from cat_buying_frequency)
  pct_b <- if (!is.null(cbf) && !identical(cbf$status, "REFUSED") &&
                !is.null(cbf$pct_buyers) && !is.na(cbf$pct_buyers))
    sprintf("%.0f%%", cbf$pct_buyers) else "\u2014"
  chips <- c(chips, sprintf(
    '<div class="cb-kpi-chip"><div class="cb-kpi-val">%s</div><div class="cb-kpi-label">%% Category buyers</div></div>',
    pct_b))

  # Mean purchases per buyer (target window)
  if (!is.null(dn) && !identical(dn$status, "REFUSED") &&
      !is.null(dn$category_metrics$mean_purchases)) {
    mp_val <- sprintf("%.1f", dn$category_metrics$mean_purchases)
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip"><div class="cb-kpi-val">%s</div><div class="cb-kpi-label">Mean purchases / buyer (%dm)</div></div>',
      mp_val, t_months))
  }

  # Focal SCR (obs with exp in brackets) — data-kpi for JS focal switching
  if (!is.null(dn) && !identical(dn$status, "REFUSED")) {
    ms <- dn$metrics_summary
    scr_val  <- if (!is.null(ms$focal_scr_obs) && !is.na(ms$focal_scr_obs))
      sprintf("%.0f%%", ms$focal_scr_obs) else "\u2014"
    scr_exp  <- if (!is.null(ms$focal_scr_exp) && !is.na(ms$focal_scr_exp))
      sprintf("exp %.0f%%", ms$focal_scr_exp) else ""
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip green" data-kpi="scr"><div class="cb-kpi-val green" data-kpi-val>%s</div><div class="cb-kpi-label">Focal SCR <span data-kpi-sub>%s</span></div></div>',
      scr_val, if (nzchar(scr_exp)) sprintf("(%s)", scr_exp) else ""))

    # Focal 100%-loyal
    loy_val <- if (!is.null(ms$focal_loyal_obs) && !is.na(ms$focal_loyal_obs))
      sprintf("%.0f%%", ms$focal_loyal_obs) else "\u2014"
    loy_exp <- if (!is.null(ms$focal_loyal_exp) && !is.na(ms$focal_loyal_exp))
      sprintf("exp %.0f%%", ms$focal_loyal_exp) else ""
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip" data-kpi="loyal"><div class="cb-kpi-val" data-kpi-val>%s</div><div class="cb-kpi-label">Focal 100%%-loyal <span data-kpi-sub>%s</span></div></div>',
      loy_val, if (nzchar(loy_exp)) sprintf("(%s)", loy_exp) else ""))
  }

  # Focal NMI — data-kpi for JS focal switching
  if (!is.null(bh) && !identical(bh$status, "REFUSED")) {
    nmi_val <- bh$metrics_summary$focal_nmi %||% NA
    nmi_txt <- if (!is.na(nmi_val)) sprintf("%.0f", nmi_val) else "\u2014"
    nmi_arrow <- if (!is.na(nmi_val)) {
      if (nmi_val < 85) " \u2193" else if (nmi_val > 115) " \u2191" else " \u2192"
    } else ""
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip amber" data-kpi="nmi"><div class="cb-kpi-val amber" data-kpi-val>%s%s</div><div class="cb-kpi-label">Focal NMI (100 = avg)</div></div>',
      nmi_txt, nmi_arrow))
  }

  sprintf('<div class="cb-kpi-strip">%s</div>', paste(chips, collapse = "\n"))
}


#' Build the DJ scatter section with y-axis toggle
#' @keywords internal
.cb_dj_section <- function(dn, focal, fcol, cat_code, brand_labels = NULL) {
  dj_id <- paste0("cb-dj-", cat_code)
  parts <- character(0)

  # Toggle buttons
  parts <- c(parts, sprintf(
    '<div class="cb-toggle-bar">
  <button class="cb-toggle-btn active" onclick="_cbDJToggle(\'%s\',\'scr\',this)">SCR</button>
  <button class="cb-toggle-btn" onclick="_cbDJToggle(\'%s\',\'w\',this)">Buy rate</button>
</div>',
    dj_id, dj_id))

  # SCR version (default visible)
  scr_svg <- if (exists("cb_dj_scatter_svg", mode = "function"))
    cb_dj_scatter_svg(dn$norms_table, dn$dj_curve, focal, fcol, "scr",
                      brand_labels = brand_labels) else ""
  w_svg   <- if (exists("cb_dj_scatter_svg", mode = "function"))
    cb_dj_scatter_svg(dn$norms_table, dn$dj_curve, focal, fcol, "w",
                      brand_labels = brand_labels) else ""

  parts <- c(parts, sprintf('<div class="cb-dj-container" id="%s">', dj_id))
  parts <- c(parts, sprintf('<div data-dj-yaxis="scr">%s</div>', scr_svg))
  parts <- c(parts, sprintf('<div data-dj-yaxis="w" style="display:none;">%s</div>', w_svg))
  parts <- c(parts, '</div>')

  paste(parts, collapse = "\n")
}


#' Build the DoP section with observed/deviation toggle
#' @keywords internal
.cb_dop_section <- function(dev_mat, obs_mat, focal, cat_code, rep,
                             brand_labels = NULL) {
  dop_id <- paste0("cb-dop-", cat_code)
  parts  <- character(0)

  parts <- c(parts, sprintf(
    '<div class="cb-toggle-bar">
  <button class="cb-toggle-btn active" onclick="_cbDoPToggle(\'%s\',\'dev\',this)">Deviation from law</button>
  <button class="cb-toggle-btn" onclick="_cbDoPToggle(\'%s\',\'obs\',this)">Observed duplication</button>
</div>', dop_id, dop_id))

  dev_html <- if (exists("cb_dop_heatmap_html", mode = "function"))
    cb_dop_heatmap_html(dev_mat, obs_mat, focal, brand_labels = brand_labels) else ""
  obs_html <- if (exists("cb_dop_heatmap_html", mode = "function") && !is.null(obs_mat))
    cb_dop_heatmap_html(obs_mat, NULL, focal, brand_labels = brand_labels) else ""

  parts <- c(parts, sprintf('<div id="%s">', dop_id))
  parts <- c(parts, sprintf('<div data-dop-view="dev">%s</div>', dev_html))
  parts <- c(parts, sprintf('<div data-dop-view="obs" style="display:none;">%s</div>', obs_html))
  parts <- c(parts, '</div>')

  # Partition callout
  if (exists("cb_partition_callout_html", mode = "function")) {
    parts <- c(parts, cb_partition_callout_html(dev_mat))
  }

  paste(parts, collapse = "\n")
}


#' Build the focal brand picker chip row
#'
#' Emits one chip per brand detected across norms_table and brand_heaviness.
#' The active chip is the current focal brand.
#'
#' @keywords internal
.cb_brand_picker <- function(dn, bh, focal, fcol, cat_code, brand_labels = NULL) {
  # Collect all brand codes
  codes <- character(0)
  if (!is.null(dn) && !identical(dn$status, "REFUSED") &&
      !is.null(dn$norms_table))
    codes <- c(codes, as.character(dn$norms_table$BrandCode))
  if (!is.null(bh) && !identical(bh$status, "REFUSED") &&
      !is.null(bh$brand_heaviness))
    codes <- c(codes, as.character(bh$brand_heaviness$BrandCode))
  codes <- unique(codes)
  if (length(codes) == 0) return("")

  # Use .cb_brand_lbl helper if available
  lbl_fn <- if (exists(".cb_brand_lbl", mode = "function")) .cb_brand_lbl else
    function(code, bl) tools::toTitleCase(tolower(as.character(code)))

  chips <- character(0)
  for (bc in codes) {
    lbl    <- lbl_fn(bc, brand_labels)
    is_act <- !is.null(focal) && bc == focal
    cls    <- paste("cb-focal-chip", if (is_act) "active" else "")
    chips  <- c(chips, sprintf(
      '<button class="%s" onclick="_cbSetFocal(this,\'%s\')" data-brand="%s">%s</button>',
      cls, cat_code, .cb_esc(bc), .cb_esc(lbl)))
  }
  sprintf('<div class="cb-brand-picker">%s</div>', paste(chips, collapse = "\n"))
}


#' Embed per-brand KPI data as a JSON script block for JS focal switching
#'
#' Shape: \code{{"IPK":{"scr_obs":"42%","scr_exp":"exp 38%","loyal_obs":"18%",
#'   "loyal_exp":"exp 15%","nmi":"85","nmi_arrow":"\u2192"},...}}
#'
#' @keywords internal
.cb_kpi_json_script <- function(dn, bh, cat_code) {
  entries <- list()

  has_dn <- !is.null(dn) && !identical(dn$status, "REFUSED") &&
            !is.null(dn$norms_table)
  has_bh <- !is.null(bh) && !identical(bh$status, "REFUSED") &&
            !is.null(bh$brand_heaviness)

  codes <- character(0)
  if (has_dn) codes <- c(codes, as.character(dn$norms_table$BrandCode))
  if (has_bh) codes <- c(codes, as.character(bh$brand_heaviness$BrandCode))
  codes <- unique(codes)
  if (length(codes) == 0) return("")

  for (bc in codes) {
    scr_obs  <- "\u2014"; scr_exp  <- ""
    loy_obs  <- "\u2014"; loy_exp  <- ""
    nmi_txt  <- "\u2014"; nmi_arrow <- ""

    if (has_dn) {
      nt <- dn$norms_table
      ri <- which(nt$BrandCode == bc)
      if (length(ri) == 1) {
        if (!is.na(nt$SCR_Obs_Pct[ri]))
          scr_obs <- sprintf("%.0f%%", nt$SCR_Obs_Pct[ri])
        if (!is.na(nt$SCR_Exp_Pct[ri]))
          scr_exp <- sprintf("exp %.0f%%", nt$SCR_Exp_Pct[ri])
        if (!is.na(nt$Pct100Loyal_Obs[ri]))
          loy_obs <- sprintf("%.0f%%", nt$Pct100Loyal_Obs[ri])
        if (!is.na(nt$Pct100Loyal_Exp[ri]))
          loy_exp <- sprintf("exp %.0f%%", nt$Pct100Loyal_Exp[ri])
      }
    }

    if (has_bh) {
      bh_df <- bh$brand_heaviness
      ri    <- which(bh_df$BrandCode == bc)
      if (length(ri) == 1 && "NaturalMonopolyIndex" %in% names(bh_df)) {
        nmi_v <- bh_df$NaturalMonopolyIndex[ri]
        if (!is.na(nmi_v)) {
          nmi_txt   <- sprintf("%.0f", nmi_v)
          nmi_arrow <- if (nmi_v < 85) "\u2193" else if (nmi_v > 115) "\u2191" else "\u2192"
        }
      }
    }

    entries[[bc]] <- list(
      scr_obs   = scr_obs,
      scr_exp   = scr_exp,
      loyal_obs = loy_obs,
      loyal_exp = loy_exp,
      nmi       = nmi_txt,
      nmi_arrow = nmi_arrow
    )
  }

  json_str <- tryCatch(
    jsonlite::toJSON(entries, auto_unbox = TRUE, pretty = FALSE),
    error = function(e) "{}"
  )

  sprintf(
    '<script type="application/json" class="cb-panel-data" id="cb-data-%s">%s</script>',
    .cb_esc(cat_code), json_str)
}


#' Render a refused-element block
#' @keywords internal
.cb_refused_block <- function(elem, label) {
  if (is.null(elem)) {
    return(sprintf('<div class="cb-refused">%s not available (no data).</div>', .cb_esc(label)))
  }
  sprintf('<div class="cb-refused">%s not available: %s (%s).</div>',
          .cb_esc(label),
          .cb_esc(elem$message %||% ""),
          .cb_esc(elem$code    %||% ""))
}


#' Render the limitations footer (§15)
#' @keywords internal
.cb_limitations_footer <- function(t_months) {
  sprintf(
    '<div style="margin:20px 0 8px;padding:10px 14px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:6px;font-size:10px;color:#94a3b8;line-height:1.6;">
<strong>Limitations:</strong> Dirichlet expected values assume a stationary category over the target timeframe (%dm). Growing or declining categories produce systematic deviations. BRANDPEN3 is stated recall, subject to telescoping and omission. Winsorisation at 99th percentile \u00d7 3 mitigates extreme outliers but does not correct systematic bias. For categories with &lt; 4 brands, estimates are flagged as PARTIAL.
</div>',
    t_months)
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Cat Buying Panel loaded (v%s)",
                  BRAND_CB_PANEL_VERSION))
}
