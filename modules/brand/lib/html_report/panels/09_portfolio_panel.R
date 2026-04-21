# ==============================================================================
# BRAND MODULE - PORTFOLIO PANEL HTML RENDERER
# ==============================================================================
# Overrides build_br_portfolio_panel() from 03_page_builder.R with a new
# implementation that consumes run_portfolio() output (§6.1 data structure).
#
# Phase 2: Footprint (§4.1) + Category Context (§4.3) subtabs active.
#          Competitive Set + Extension subtabs render a "coming in next phase"
#          placeholder so the nav is complete but non-functional until Phase 4/3.
#
# Sub-renderers (to be added in later phases):
#   09_portfolio_panel_chart.R  — chart wrappers
#   09_portfolio_panel_table.R  — table wrappers
# ==============================================================================

PORTFOLIO_PANEL_VERSION <- "1.0"

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

.pf_esc <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}


# ==============================================================================
# PUBLIC ENTRY POINT  (overrides 03_page_builder.R version)
# ==============================================================================

#' Build the portfolio tab HTML panel
#'
#' Replaces the legacy \code{build_br_portfolio_panel()} from
#' \code{03_page_builder.R} with an implementation that consumes the full
#' §6.1 data structure produced by \code{run_portfolio()}.
#'
#' @param results List. Full \code{run_brand()} result.
#' @param config List. Loaded brand config.
#'
#' @return Character. HTML fragment for the portfolio tab panel.
#' @keywords internal
build_br_portfolio_panel <- function(results, config) {
  focal_colour <- config$colour_focal %||% "#1A5276"
  focal_brand  <- config$focal_brand  %||% ""

  portfolio <- results$results$portfolio

  if (is.null(portfolio) || identical(portfolio$status, "REFUSED")) {
    return(.pf_empty_panel("Portfolio analysis not available."))
  }

  panel_data <- tryCatch(
    build_portfolio_panel_data(portfolio, config, results$structure),
    error = function(e) {
      message(sprintf("[BRAND HTML] Portfolio panel data failed: %s", e$message))
      NULL
    }
  )

  fp_html <- .pf_footprint_subtab(portfolio, panel_data, focal_brand, focal_colour)
  cl_html <- .pf_clutter_subtab(portfolio, panel_data, focal_colour)
  ex_html <- .pf_extension_subtab(portfolio, panel_data, focal_brand, focal_colour)

  timeframe_label <- if (identical(portfolio$timeframe, "3m")) "3-month" else "13-month"
  n_label         <- format(portfolio$n_total %||% 0L, big.mark = ",")

  paste0(
    '<div class="br-panel" id="panel-portfolio">',
    '<div class="br-section">',
    '<div class="pf-panel">',

    # Panel header
    sprintf(
      '<h2 style="font-size:20px;color:#1e293b;margin:0 0 4px;">Portfolio Mapping</h2>'),
    sprintf(
      '<p style="font-size:12px;color:#64748b;margin:0 0 16px;">',
      'Cross-category brand presence. Timeframe: %s. Base: all %s respondents.</p>',
      timeframe_label, n_label
    ),

    # 4-subtab nav (all tabs rendered; Competitive Set + Extension are stubs)
    .pf_sub_nav(),

    # Footprint subtab
    '<div class="pf-subtab active" id="pf-subtab-footprint">',
    fp_html,
    '</div>',

    # Competitive Set subtab (Phase 4 stub)
    '<div class="pf-subtab" id="pf-subtab-constellation">',
    '<div class="pf-coming-soon">Competitive Constellation — available in Phase 4</div>',
    '</div>',

    # Category Context subtab
    '<div class="pf-subtab" id="pf-subtab-clutter">',
    cl_html,
    '</div>',

    # Extension subtab
    '<div class="pf-subtab" id="pf-subtab-extension">',
    ex_html,
    '</div>',

    '</div>',  # .pf-panel
    '</div>',  # .br-section
    '</div>'   # .br-panel
  )
}


# ==============================================================================
# SUBTAB NAV
# ==============================================================================

.pf_sub_nav <- function() {
  paste0(
    '<div class="pf-sub-nav" role="tablist">',
    '<button class="pf-sub-btn active" data-pf-subtab="footprint"',
    '  onclick="pfSwitchSubtab(\'footprint\')"',
    '  role="tab" aria-selected="true">Footprint</button>',
    '<button class="pf-sub-btn" data-pf-subtab="constellation"',
    '  onclick="pfSwitchSubtab(\'constellation\')"',
    '  role="tab" aria-selected="false">Competitive Set</button>',
    '<button class="pf-sub-btn" data-pf-subtab="clutter"',
    '  onclick="pfSwitchSubtab(\'clutter\')"',
    '  role="tab" aria-selected="false">Category Context</button>',
    '<button class="pf-sub-btn" data-pf-subtab="extension"',
    '  onclick="pfSwitchSubtab(\'extension\')"',
    '  role="tab" aria-selected="false">Extension</button>',
    '</div>'
  )
}


# ==============================================================================
# FOOTPRINT SUBTAB
# ==============================================================================

.pf_footprint_subtab <- function(portfolio, panel_data, focal_brand,
                                  focal_colour) {
  fp <- portfolio$footprint_matrix
  bases <- if (!is.null(portfolio$bases) &&
               !is.null(portfolio$bases$per_category))
    portfolio$bases$per_category else NULL

  if (is.null(fp) || !is.data.frame(fp) || nrow(fp) == 0) {
    return('<p style="color:#94a3b8;padding:24px 0;">Footprint data not available.</p>')
  }

  section_id <- "pf-footprint"

  chart_svg <- tryCatch(
    build_heat_strip(
      matrix_df    = fp,
      focal_brand  = focal_brand,
      brand_colour = focal_colour,
      title        = "Brand Awareness by Category (% of category buyers)"
    ),
    error = function(e) ""
  )

  suppressed <- portfolio$suppressions$low_base_cats %||% character(0)
  supp_note  <- if (length(suppressed) > 0) {
    sprintf(
      '<div class="pf-suppression-note">Categories suppressed (base below threshold): %s</div>',
      .pf_esc(paste(suppressed, collapse = ", "))
    )
  } else ""

  about_text <- if (!is.null(panel_data)) {
    panel_data$about$footprint %||% ""
  } else ""

  paste0(
    .pf_section_toolbar(section_id),
    '<div id="', section_id, '-chart" style="margin:8px 0;">',
    chart_svg,
    '</div>',
    if (nzchar(supp_note)) supp_note else "",
    if (nzchar(about_text)) {
      sprintf('<div class="pf-about-drawer"><strong>About this chart:</strong> %s</div>',
              .pf_esc(about_text))
    } else ""
  )
}


# ==============================================================================
# CLUTTER SUBTAB
# ==============================================================================

.pf_clutter_subtab <- function(portfolio, panel_data, focal_colour) {
  cl <- portfolio$clutter
  if (is.null(cl) || is.null(cl$clutter_df) || nrow(cl$clutter_df) == 0) {
    return('<p style="color:#94a3b8;padding:24px 0;">Category context data not available.</p>')
  }

  clutter_df <- cl$clutter_df
  section_id <- "pf-clutter"

  # Convert focal_share_of_aware to 0-100 for scatter y-axis display
  df_plot <- clutter_df
  df_plot$focal_share_pct <- df_plot$focal_share_of_aware * 100

  chart_svg <- tryCatch(
    build_scatter(
      df              = df_plot,
      x_col           = "awareness_set_size_mean",
      y_col           = "focal_share_pct",
      label_col       = "cat",
      focal_label     = NULL,
      brand_colour    = focal_colour,
      comp_colour     = "#64748b",
      title           = "Category Clutter vs Focal Brand Position",
      x_label         = "Awareness Set Size (brands known per buyer)",
      y_label         = "Focal Share of Awareness (%)",
      y_suffix        = "%",
      quadrant_labels = c("Dominant", "Contested",
                          "Niche Opportunity", "Forgotten / Wrong Battle"),
      ref_x           = cl$ref_x,
      ref_y           = if (!is.na(cl$ref_y)) cl$ref_y * 100 else NULL,
      size_col        = "cat_penetration"
    ),
    error = function(e) ""
  )

  context_table <- .pf_clutter_table(clutter_df)

  about_text <- if (!is.null(panel_data)) {
    panel_data$about$clutter %||% ""
  } else ""

  paste0(
    .pf_section_toolbar(section_id),
    '<div id="', section_id, '-chart" style="margin:8px 0;">',
    chart_svg,
    '</div>',
    context_table,
    if (nzchar(about_text)) {
      sprintf('<div class="pf-about-drawer"><strong>About this chart:</strong> %s</div>',
              .pf_esc(about_text))
    } else ""
  )
}


.pf_clutter_table <- function(clutter_df) {
  if (nrow(clutter_df) == 0) return("")
  rows_html <- paste(vapply(seq_len(nrow(clutter_df)), function(i) {
    r <- clutter_df[i, ]
    sprintf(
      '<tr><td>%s</td><td>%.1f</td><td>%.1f%%</td><td>%.1f%%</td><td>%s</td></tr>',
      .pf_esc(r$cat),
      r$awareness_set_size_mean,
      r$focal_share_of_aware * 100,
      r$cat_penetration * 100,
      .pf_esc(r$quadrant)
    )
  }, character(1)), collapse = "")

  paste0(
    '<div style="margin-top:16px;overflow-x:auto;">',
    '<table style="width:100%;border-collapse:collapse;font-size:12px;">',
    '<thead><tr style="background:#f8fafc;font-weight:600;color:#475569;">',
    '<th style="padding:8px;text-align:left;border-bottom:1px solid #e2e8f0;">Category</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Avg brands known</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Focal share</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Cat. penetration</th>',
    '<th style="padding:8px;text-align:left;border-bottom:1px solid #e2e8f0;">Quadrant</th>',
    '</tr></thead><tbody>',
    rows_html,
    '</tbody></table></div>'
  )
}


# ==============================================================================
# EXTENSION SUBTAB
# ==============================================================================

.pf_extension_subtab <- function(portfolio, panel_data, focal_brand, focal_colour) {
  strength  <- portfolio$strength
  extension <- portfolio$extension
  section_id <- "pf-extension"

  # --- Strength map ---
  strength_html <- if (!is.null(strength) &&
                        !is.null(strength$per_brand) &&
                        focal_brand %in% names(strength$per_brand)) {
    fb_df <- strength$per_brand[[focal_brand]]
    if (nrow(fb_df) >= 2) {
      fb_df$cat_pen_pct    <- fb_df$cat_pen    * 100
      fb_df$brand_aware_pct <- fb_df$brand_aware
      chart_svg <- tryCatch(
        build_bubble_scatter(
          df          = fb_df,
          x_col       = "cat_pen_pct",
          y_col       = "brand_aware_pct",
          label_col   = "cat",
          size_col    = "aware_n_w",
          brand_colour = focal_colour,
          title       = sprintf("Portfolio Strength: %s (%%)", .pf_esc(focal_brand))
        ),
        error = function(e) ""
      )
      paste0(
        '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin:0 0 12px;">',
        'Portfolio Strength Map</h3>',
        '<div style="margin:8px 0;">', chart_svg, '</div>',
        '<p style="font-size:11px;color:#94a3b8;margin:4px 0 16px;">',
        'Each bubble = one category. X = category penetration in sample; ',
        'Y = brand awareness among category buyers. Diagonal = equal performance.</p>'
      )
    } else if (nrow(fb_df) == 1) {
      sprintf(
        '<div class="pf-coming-soon" style="min-height:100px;">%s is present in only one category — strength map requires two or more.</div>',
        .pf_esc(focal_brand)
      )
    } else {
      '<p style="color:#94a3b8;padding:16px 0;">Strength map data not available.</p>'
    }
  } else {
    '<p style="color:#94a3b8;padding:16px 0;">Strength map data not available.</p>'
  }

  # --- Extension table ---
  ext_html <- if (!is.null(extension) &&
                   !is.null(extension$extension_df) &&
                   nrow(extension$extension_df) > 0) {
    home_note <- if (nzchar(extension$home_cat %||% "")) {
      sprintf(
        '<p style="font-size:11px;color:#64748b;margin:0 0 12px;">Home category: <strong>%s</strong> (%s). Non-home categories ranked by lift.</p>',
        .pf_esc(extension$home_cat),
        if (identical(extension$home_cat_source, "config")) "configured" else "auto-detected"
      )
    } else ""

    paste0(
      '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin:16px 0 8px;">',
      'Permission-to-Extend</h3>',
      home_note,
      .pf_extension_table(extension$extension_df)
    )
  } else {
    '<p style="color:#94a3b8;padding:16px 0;">Extension data not available.</p>'
  }

  about_text <- if (!is.null(panel_data)) panel_data$about$extension %||% "" else ""

  paste0(
    .pf_section_toolbar(section_id),
    strength_html,
    ext_html,
    if (nzchar(about_text)) {
      sprintf('<div class="pf-about-drawer"><strong>About this analysis:</strong> %s</div>',
              .pf_esc(about_text))
    } else ""
  )
}


.pf_extension_table <- function(ext_df) {
  if (nrow(ext_df) == 0) return("")

  rows_html <- paste(vapply(seq_len(nrow(ext_df)), function(i) {
    r          <- ext_df[i, ]
    is_home    <- isTRUE(r$is_home)
    low_base   <- isTRUE(r$low_base_flag)
    lift_str   <- if (!is.na(r$lift) && !is_home) {
      if (low_base) sprintf("%.2f&#x2020;", r$lift) else sprintf("%.2f", r$lift)
    } else if (is_home) "(home)" else "—"
    sig_str    <- if (!is.na(r$p_adj) && !is_home) {
      if (r$p_adj < 0.05) "&#x2605;" else ""
    } else ""
    row_style <- if (is_home) ' style="background:#f8fafc;color:#94a3b8;"' else ""
    sprintf(
      '<tr%s><td>%s</td><td style="text-align:right;">%s</td><td style="text-align:right;">%.1f%%</td><td style="text-align:right;">%s%s</td></tr>',
      row_style,
      .pf_esc(r$cat),
      format(r$n_buyers_uw, big.mark = ","),
      r$focal_aware_pct %||% 0,
      lift_str, sig_str
    )
  }, character(1)), collapse = "")

  paste0(
    '<div style="overflow-x:auto;">',
    '<table style="width:100%;border-collapse:collapse;font-size:12px;">',
    '<thead><tr style="background:#f8fafc;font-weight:600;color:#475569;">',
    '<th style="padding:8px;text-align:left;border-bottom:1px solid #e2e8f0;">Category</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Buyers (n)</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Aware of focal</th>',
    '<th style="padding:8px;text-align:right;border-bottom:1px solid #e2e8f0;">Lift &#x2605;=sig.</th>',
    '</tr></thead><tbody>',
    rows_html,
    '</tbody></table>',
    '<p style="font-size:10px;color:#94a3b8;margin:6px 0 0;">',
    '&#x2605; p&lt;0.05 (BH-corrected). &#x2020; low base (n&lt;threshold).</p>',
    '</div>'
  )
}


# ==============================================================================
# SHARED HELPERS
# ==============================================================================

.pf_section_toolbar <- function(section_id) {
  sprintf(
    '<div class="br-section-toolbar" style="display:flex;gap:8px;margin-bottom:12px;">
  <button class="br-pin-btn" data-section="%s" onclick="brTogglePin(\'%s\')" title="Pin to Views"
    style="background:none;border:1px solid #e2e8f0;border-radius:6px;cursor:pointer;font-size:15px;padding:5px 10px;color:#94a3b8;">
    &#x1F4CC;
  </button>
</div>',
    section_id, section_id
  )
}

.pf_empty_panel <- function(msg = "Portfolio analysis not available.") {
  sprintf(
    '<div class="br-panel" id="panel-portfolio"><div class="br-section"><p style="color:#94a3b8;padding:32px;text-align:center;">%s</p></div></div>',
    .pf_esc(msg)
  )
}
