# ==============================================================================
# BRAND MODULE - FUNNEL PANEL CHART + RELATIONSHIP DETAIL
# ==============================================================================
# Slope chart: focal brand solid, category average dashed, min/max range
# shaded band. Competitor lines added by JS when the user toggles chips.
#
# Relationship detail: per-brand stacked strip showing the 5 attitude
# positions as proportion of aware base.
#
# Both sections emit static SVG baseline; the JS layer swaps series in
# response to control changes.
# ==============================================================================


# ==============================================================================
# PUBLIC: chart section
# ==============================================================================

#' Build the slope-chart section (static baseline; JS overlays competitors)
#'
#' @param pd Panel data.
#' @param focal_colour Hex colour.
#' @return Character HTML.
#' @export
build_funnel_chart_section <- function(pd, focal_colour = "#1A5276") {
  sc <- pd$shape_chart
  if (is.null(sc) || length(sc$stage_positions) == 0) return("")
  stage_keys <- sc$focal_series$stage_keys %||%
                 sc$category_avg_series$stage_keys %||% character(0)
  stage_labels <- vapply(stage_keys, .fn_stage_lookup_label,
                         character(1), pd = pd)

  svg <- .fn_slope_svg(sc, stage_keys, stage_labels, focal_colour)

  paste0(
    '<section class="fn-section fn-chart-section">',
    '<div class="fn-chart-wrap" data-fn-chart="slope">',
    svg,
    '</div>',
    '</section>'
  )
}


#' Build the relationship section: horizontal stacked bar chart (brands as rows)
#' + flipped heatmap table (brands as rows, attitudes as columns).
#'
#' Controls: emphasis chip row, sort segmented button, base toggle.
#' Chart and headline are JS-built; the table is static HTML with
#' dual data-fn-rel-pct-aware / data-fn-rel-pct-total attributes.
#'
#' @param pd Panel data from build_funnel_panel_data().
#' @param focal_colour Hex colour.
#' @return Character HTML.
#' @export
build_funnel_relationship_section <- function(pd, focal_colour = "#1A5276") {
  cd <- pd$consideration_detail
  if (is.null(cd) || is.null(cd$brands) || length(cd$brands) == 0) return("")

  focal   <- pd$meta$focal_brand_code %||% character(0)
  brands  <- cd$brands
  n_total <- as.numeric(pd$meta$n_weighted %||% pd$meta$n_unweighted %||% NA_real_)

  focal_entries <- Filter(function(b) identical(b$brand_code, focal), brands)
  comp_entries  <- Filter(function(b) !identical(b$brand_code, focal), brands)
  if (length(comp_entries) > 0) {
    nms <- tolower(vapply(comp_entries,
      function(b) as.character(b$brand_name %||% b$brand_code), character(1)))
    comp_entries <- comp_entries[order(nms)]
  }
  ordered <- c(focal_entries, comp_entries)
  if (length(ordered) == 0) return("")

  paste0(
    '<section class="fn-section fn-rel-chart-section">',
    .fn_rel_controls(ordered, focal),
    .fn_rel_table_v2(ordered, focal, focal_colour, n_total),
    '<div class="fn-rel-headline" data-fn-rel-headline style="display:none;margin-top:14px;"></div>',
    '<div class="fn-rel-chart-area" data-fn-rel-chart-area>',
    '<div class="fn-rel-chart-controls col-chip-bar">',
    '<span class="sig-level-label" style="flex-shrink:0;">Emphasise:</span>',
    .fn_rel_emphasis_chips(),
    '</div>',
    '<div class="fn-rel-chart" data-fn-rel-chart></div>',
    '</div>',
    .fn_add_insight_strip(),
    '</section>'
  )
}


# ==============================================================================
# INTERNAL: RELATIONSHIP CONTROLS BAR
# ==============================================================================

.fn_rel_controls <- function(ordered, focal) {
  brand_chips <- paste(vapply(ordered, function(b) {
    code   <- as.character(b$brand_code)
    name   <- b$brand_name %||% b$brand_code
    is_foc <- identical(code, as.character(focal))
    label  <- if (is_foc) paste0(.fn_esc(name), ' <span class="fn-focal-badge">FOCAL</span>')
               else .fn_esc(name)
    sprintf('<button type="button" class="col-chip fn-rel-brand-chip active" data-fn-rel-brand="%s">%s</button>',
            .fn_esc(code), label)
  }, character(1)), collapse = "")

  # Category average chip
  avg_chip <- '<button type="button" class="col-chip fn-rel-brand-chip fn-rel-avg-chip active" data-fn-rel-brand="__avg__">Cat avg</button>'

  paste0(
    '<div class="fn-rel-controls">',
    # Brand chips row (including cat avg)
    '<div class="fn-rel-brand-row col-chip-bar">',
    '<span class="sig-level-label" style="flex-shrink:0;">Brands:</span>',
    brand_chips,
    avg_chip,
    '</div>',
    # Meta row: base, shading, count, chart toggle, export
    '<div class="fn-rel-meta-row">',
    '<div class="sig-level-switcher" role="group" aria-label="Percentage base">',
    '<span class="sig-level-label">Base:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-rel-base="aware" aria-pressed="true">% aware</button>',
    '<button type="button" class="sig-btn" data-fn-rel-base="total" aria-pressed="false">% total</button>',
    '</div>',
    '<div class="sig-level-switcher" role="group" aria-label="Table shading">',
    '<span class="sig-level-label">Shading:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-rel-shade="off" aria-pressed="true">Off</button>',
    '<button type="button" class="sig-btn" data-fn-rel-shade="heatmap" aria-pressed="false">Heatmap</button>',
    '</div>',
    '<div class="sig-level-switcher" role="group" aria-label="Show counts">',
    '<span class="sig-level-label">Counts:</span>',
    '<button type="button" class="sig-btn sig-btn-active" data-fn-rel-count="off" aria-pressed="true">%</button>',
    '<button type="button" class="sig-btn" data-fn-rel-count="on" aria-pressed="false">% &amp; n</button>',
    '</div>',
    '<div class="fn-rel-meta-actions">',
    '<button type="button" class="fn-rel-chart-toggle-btn" data-fn-rel-chart-vis="on" aria-pressed="true">Hide chart</button>',
    '<button type="button" class="export-btn fn-rel-export-btn" data-fn-rel-action="export" title="Export table to CSV">',
    '<svg width="12" height="12" viewBox="0 0 12 12" fill="none" style="flex-shrink:0;"><path d="M6 1v7M3 6l3 3 3-3M1 10h10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ' Export',
    '</button>',
    '</div>',
    '</div>',
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: EMPHASIS CHIPS (rendered in chart area)
# ==============================================================================

.fn_rel_emphasis_chips <- function() {
  seg_labels <- c(All = "all", Love = "attitude.love", Prefer = "attitude.prefer",
                  Ambivalent = "attitude.ambivalent", Reject = "attitude.reject",
                  `No opinion` = "attitude.no_opinion")
  paste(vapply(seq_along(seg_labels), function(i) {
    nm     <- names(seg_labels)[i]
    active <- if (nm == "All") " active" else ""
    sprintf('<button type="button" class="col-chip fn-rel-seg-chip%s" data-fn-rel-emphasis="%s">%s</button>',
            active, seg_labels[[i]], .fn_esc(nm))
  }, character(1)), collapse = "")
}


# ==============================================================================
# INTERNAL: RELATIONSHIP TABLE v2 — BRANDS AS ROWS, ATTITUDES AS COLUMNS
# ==============================================================================

.fn_rel_table_v2 <- function(ordered, focal, focal_colour, n_total) {
  if (length(ordered) == 0) return("")

  att_roles  <- c("attitude.love", "attitude.prefer", "attitude.ambivalent",
                  "attitude.reject", "attitude.no_opinion")
  att_labels <- c("Love", "Prefer", "Ambivalent", "Reject", "No opinion")

  # Category average per attitude (across all brands, % of aware base)
  brands_all <- ordered
  cat_avg_aware <- vapply(att_roles, function(role) {
    vals <- vapply(brands_all, function(b)
      as.numeric(b$segments[[role]] %||% NA_real_), numeric(1))
    vals <- vals[is.finite(vals)]
    if (length(vals) == 0) NA_real_ else mean(vals)
  }, numeric(1))

  # Per-attitude column max for heatmap scaling (across all brands)
  att_max <- vapply(att_roles, function(role) {
    vals <- vapply(brands_all, function(b)
      as.numeric(b$segments[[role]] %||% NA_real_), numeric(1))
    vals <- vals[is.finite(vals) & vals > 0]
    if (length(vals) == 0) 1 else max(vals)
  }, numeric(1))
  names(att_max) <- att_roles

  att_ths <- paste(vapply(seq_along(att_labels), function(i)
    sprintf(
      '<th class="ct-th ct-data-col fn-rel-th-att fn-rel-th-sortable" data-fn-rel-sortable="%s" data-fn-att="%s" style="cursor:pointer;">%s<button class="ct-sort-indicator" data-fn-rel-sort-ind="%s" aria-label="Sort by %s">\u2195</button></th>',
      .fn_esc(att_roles[i]), .fn_esc(att_roles[i]), .fn_esc(att_labels[i]),
      .fn_esc(att_roles[i]), .fn_esc(att_labels[i])),
    character(1)), collapse = "")

  header <- paste0(
    '<thead><tr>',
    '<th class="ct-th ct-label-col fn-rel-th-sortable" data-fn-rel-sortable="brand" style="text-align:left;min-width:160px;cursor:pointer;">Brand<button class="ct-sort-indicator" data-fn-rel-sort-ind="brand" aria-label="Sort by brand">\u2195</button></th>',
    '<th class="ct-th ct-data-col" style="min-width:70px;">Base</th>',
    att_ths,
    '</tr></thead>'
  )

  avg_cells <- paste(vapply(att_roles, function(role) {
    pct <- cat_avg_aware[[role]]
    if (!is.finite(pct))
      return('<td class="ct-td ct-data-col fn-rel-td-avg ct-na">&mdash;</td>')
    sprintf(
      '<td class="ct-td ct-data-col fn-rel-td-avg" data-fn-att="%s" data-fn-rel-pct-aware="%.6f"><span class="ct-val">%.0f%%</span></td>',
      .fn_esc(role), pct, 100 * pct)
  }, character(1)), collapse = "")
  avg_row <- paste0(
    '<tr class="ct-row fn-row-avg-all fn-rel-row">',
    '<td class="ct-td ct-label-col"><em>Category avg</em></td>',
    '<td class="ct-td ct-data-col fn-rel-td-avg"><span style="color:#94a3b8;font-size:11px;">\u2014</span></td>',
    avg_cells,
    '</tr>'
  )

  focal_rows <- paste(vapply(
    Filter(function(b) identical(as.character(b$brand_code), as.character(focal)), ordered),
    function(b) .fn_rel_brand_row_v2(b, att_roles, att_max, focal, n_total),
    character(1)), collapse = "")

  comp_rows <- paste(vapply(
    Filter(function(b) !identical(as.character(b$brand_code), as.character(focal)), ordered),
    function(b) .fn_rel_brand_row_v2(b, att_roles, att_max, focal, n_total),
    character(1)), collapse = "")

  paste0(
    '<div class="fn-rel-table-wrap fn-table-wrap" style="margin-top:16px;">',
    '<table class="ct-table fn-ct-table fn-rel-table-v2" data-fn-rel-table="1">',
    header,
    '<tbody>',
    focal_rows,
    avg_row,
    comp_rows,
    '</tbody></table></div>'
  )
}


.fn_rel_brand_row_v2 <- function(brand, att_roles, att_max, focal, n_total) {
  is_focal <- identical(brand$brand_code, focal)
  row_cls  <- trimws(paste("ct-row fn-rel-row",
                            if (is_focal) "fn-row-focal" else "fn-row-competitor"))

  label_txt <- .fn_esc(brand$brand_name %||% brand$brand_code)
  if (is_focal) label_txt <- paste0(label_txt, ' <span class="fn-focal-badge">FOCAL</span>')

  aware_n <- as.numeric(brand$aware_base %||% NA_real_)
  focal_cls <- if (is_focal) " fn-rel-td-focal" else ""

  base_cell <- if (is.finite(aware_n)) {
    ni   <- as.integer(round(aware_n))
    warn <- ni < 30L
    sprintf('<td class="ct-td ct-data-col%s"><span class="%s">n=%d%s</span></td>',
            focal_cls,
            if (warn) "ct-low-base" else "ct-base-n", ni,
            if (warn) " \u26A0" else "")
  } else {
    sprintf('<td class="ct-td ct-data-col%s ct-na">&mdash;</td>', focal_cls)
  }

  att_cells <- paste(vapply(att_roles, function(role) {
    pct_aware <- as.numeric(brand$segments[[role]] %||% NA_real_)
    if (!is.finite(pct_aware))
      return(sprintf('<td class="ct-td ct-data-col%s ct-na">&mdash;</td>', focal_cls))

    pct_total <- if (is.finite(aware_n) && is.finite(n_total) && n_total > 0)
      pct_aware * (aware_n / n_total) else NA_real_

    denom <- if (!is.finite(att_max[[role]]) || att_max[[role]] <= 0) 1 else att_max[[role]]
    frac  <- min(1, max(0, pct_aware / denom))
    hm    <- sprintf("rgba(37,99,171,%.3f)", 0.08 + frac * 0.57)

    total_attr     <- if (is.finite(pct_total))
      sprintf(' data-fn-rel-pct-total="%.6f"', pct_total) else ""
    count_aware    <- if (is.finite(aware_n))
      sprintf(' data-fn-rel-count-aware="%d"', as.integer(round(pct_aware * aware_n))) else ""
    count_total    <- if (is.finite(pct_total) && is.finite(n_total))
      sprintf(' data-fn-rel-count-total="%d"', as.integer(round(pct_total * n_total))) else ""

    sprintf(
      '<td class="ct-td ct-data-col ct-heatmap-cell%s" data-heatmap="%s" data-fn-att="%s" data-fn-rel-pct-aware="%.6f"%s%s%s><span class="ct-val">%.0f%%</span></td>',
      focal_cls, hm, .fn_esc(role), pct_aware, total_attr, count_aware, count_total, 100 * pct_aware)
  }, character(1)), collapse = "")

  sprintf('<tr class="%s" data-fn-brand="%s">%s%s%s</tr>',
          row_cls,
          .fn_esc(brand$brand_code),
          sprintf('<td class="ct-td ct-label-col">%s</td>', label_txt),
          base_cell,
          att_cells)
}


# ==============================================================================
# INTERNAL: SLOPE SVG
# ==============================================================================

.fn_slope_svg <- function(sc, stage_keys, stage_labels, focal_colour) {
  n_stages <- length(stage_keys)
  if (n_stages < 2) return("")

  w <- 760; h <- 360
  ml <- 60; mr <- 30; mt <- 40; mb <- 60
  pw <- w - ml - mr
  ph <- h - mt - mb

  # Y scale 0..1 (percentages)
  y_for <- function(val) {
    if (is.na(val)) return(NA_real_)
    mt + ph * (1 - max(0, min(1, val)))
  }
  x_for <- function(i) ml + pw * (i - 1) / max(1, n_stages - 1)

  parts <- character(0)

  # Envelope band
  if (!is.null(sc$envelope)) {
    env_min <- sc$envelope$min_values
    env_max <- sc$envelope$max_values
    if (length(env_min) == n_stages && length(env_max) == n_stages &&
        !all(is.na(env_min))) {
      top_pts <- paste(sprintf("%.2f,%.2f",
                               vapply(seq_len(n_stages), x_for, numeric(1)),
                               vapply(env_max, y_for, numeric(1))),
                       collapse = " ")
      bot_pts <- paste(sprintf("%.2f,%.2f",
                               rev(vapply(seq_len(n_stages), x_for, numeric(1))),
                               rev(vapply(env_min, y_for, numeric(1)))),
                       collapse = " ")
      parts <- c(parts, sprintf(
        '<polygon points="%s %s" fill="rgba(148,163,184,0.18)" stroke="none" data-fn-series="envelope"/>',
        top_pts, bot_pts))
    }
  }

  # Category average dashed grey
  parts <- c(parts, .fn_svg_line(sc$category_avg_series$pct_values,
                                 x_for, y_for, n_stages,
                                 "#64748b", dashed = TRUE,
                                 series = "catavg"))

  # Axes + stage labels + y gridlines
  parts <- c(parts, .fn_svg_axes(ml, mt, pw, ph, n_stages, x_for,
                                 stage_labels))

  # Focal brand solid + data labels
  focal_pct <- sc$focal_series$pct_values %||% rep(NA_real_, n_stages)
  parts <- c(parts, .fn_svg_line(focal_pct, x_for, y_for, n_stages,
                                 focal_colour, dashed = FALSE,
                                 series = "focal"))
  parts <- c(parts, .fn_svg_datapoints(focal_pct, x_for, y_for, n_stages,
                                       focal_colour, is_focal = TRUE))

  # Legend
  parts <- c(parts, .fn_svg_legend(focal_colour, ml, h))

  sprintf('<svg class="fn-slope-svg" viewBox="0 0 %d %d" width="100%%" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Funnel slope chart">%s</svg>',
          w, h, paste(parts, collapse = ""))
}


.fn_svg_line <- function(pcts, x_for, y_for, n_stages, colour,
                         dashed = FALSE, series = "") {
  if (length(pcts) != n_stages || all(is.na(pcts))) return("")
  dash_attr <- if (dashed) ' stroke-dasharray="5,4"' else ''
  pts <- character(0)
  for (i in seq_len(n_stages)) {
    if (!is.na(pcts[i])) {
      pts <- c(pts, sprintf("%.2f,%.2f", x_for(i), y_for(pcts[i])))
    }
  }
  if (length(pts) < 2) return("")
  sprintf('<polyline points="%s" fill="none" stroke="%s" stroke-width="2.2"%s data-fn-series="%s"/>',
          paste(pts, collapse = " "), colour, dash_attr, series)
}


.fn_svg_datapoints <- function(pcts, x_for, y_for, n_stages, colour,
                               is_focal = FALSE) {
  parts <- character(0)
  for (i in seq_len(n_stages)) {
    if (!is.na(pcts[i])) {
      cx <- x_for(i); cy <- y_for(pcts[i])
      r <- if (is_focal) 5 else 3.5
      parts <- c(parts, sprintf(
        '<circle cx="%.2f" cy="%.2f" r="%.1f" fill="%s" stroke="#fff" stroke-width="1.5"/>',
        cx, cy, r, colour))
      if (is_focal) {
        parts <- c(parts, sprintf(
          '<text x="%.2f" y="%.2f" text-anchor="middle" font-size="11" font-weight="700" fill="%s">%.0f%%</text>',
          cx, cy - 10, colour, 100 * pcts[i]))
      }
    }
  }
  paste(parts, collapse = "")
}


.fn_svg_axes <- function(ml, mt, pw, ph, n_stages, x_for, stage_labels) {
  # Y gridlines at 0, 25, 50, 75, 100
  lines_y <- vapply(c(0.25, 0.5, 0.75, 1.0), function(v) {
    y <- mt + ph * (1 - v)
    sprintf('<line x1="%d" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#e2e8f0" stroke-width="1"/><text x="%d" y="%.2f" font-size="10" fill="#94a3b8" text-anchor="end">%.0f%%</text>',
            ml, y, ml + pw, y, ml - 6, y + 3, 100 * v)
  }, character(1))
  # X stage labels
  x_labels <- vapply(seq_len(n_stages), function(i) {
    sprintf('<text x="%.2f" y="%.2f" font-size="11" font-weight="500" fill="#1e293b" text-anchor="middle">%s</text>',
            x_for(i), mt + ph + 22, .fn_esc(stage_labels[i]))
  }, character(1))
  paste(c(lines_y, x_labels), collapse = "")
}


.fn_svg_legend <- function(focal_colour, ml, h) {
  y <- h - 10
  sprintf(
    '<g class="fn-slope-legend" font-size="10" fill="#64748b">
       <line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="2.5"/>
       <text x="%d" y="%d">Focal</text>
       <line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#64748b" stroke-width="2" stroke-dasharray="5,4"/>
       <text x="%d" y="%d">Category avg</text>
       <rect x="%d" y="%d" width="18" height="8" fill="rgba(148,163,184,0.18)"/>
       <text x="%d" y="%d">Min-max range</text>
     </g>',
    ml, y, ml + 18, y, focal_colour,
    ml + 24, y + 3,
    ml + 80, y, ml + 98, y,
    ml + 104, y + 3,
    ml + 170, y - 6,
    ml + 194, y + 3
  )
}


# ==============================================================================
# HELPERS
# ==============================================================================

.fn_stage_lookup_label <- function(key, pd) {
  labels <- pd$meta$stage_labels
  if (is.null(labels) || is.null(labels[[key]])) return(key)
  labels[[key]]
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!exists(".fn_esc", mode = "function")) {
  .fn_esc <- function(x) {
    if (is.null(x)) return("")
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub("\"", "&quot;", x, fixed = TRUE)
    x
  }
}
