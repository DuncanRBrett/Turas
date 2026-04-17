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
    '<h3 class="fn-section-title">Shape view <span class="fn-insight-marker" title="AI insight available">&#9679;</span></h3>',
    '<div class="fn-chart-wrap" data-fn-chart="slope">',
    svg,
    '</div>',
    '</section>'
  )
}


#' Build the relationship table section (ct-table, brands as columns,
#' attitude positions as rows — same chrome as the funnel table).
#'
#' Columns: [Attitude label | Focal | Category avg | Competitor 1 | ...]
#' Rows:    [Base (n=) | Love | Prefer | Ambivalent | Reject | No opinion]
#'
#' @param pd Panel data from build_funnel_panel_data().
#' @param focal_colour Hex colour.
#' @return Character HTML.
#' @export
build_funnel_relationship_section <- function(pd, focal_colour = "#1A5276") {
  cd <- pd$consideration_detail
  if (is.null(cd) || is.null(cd$brands) || length(cd$brands) == 0) return("")

  focal  <- pd$meta$focal_brand_code %||% character(0)
  brands <- cd$brands

  focal_entries <- Filter(function(b) identical(b$brand_code, focal), brands)
  comp_entries  <- Filter(function(b) !identical(b$brand_code, focal), brands)
  if (length(comp_entries) > 0) {
    nms <- tolower(vapply(comp_entries,
      function(b) as.character(b$brand_name %||% b$brand_code), character(1)))
    comp_entries <- comp_entries[order(nms)]
  }
  ordered <- c(focal_entries, comp_entries)
  if (length(ordered) == 0) return("")

  att_roles  <- c("attitude.love", "attitude.prefer", "attitude.ambivalent",
                  "attitude.reject", "attitude.no_opinion")
  att_labels <- c("Love", "Prefer", "Ambivalent", "Reject", "No opinion")

  # Category average per attitude across all brands
  cat_avg <- vapply(att_roles, function(role) {
    vals <- vapply(brands, function(b)
      as.numeric(b$segments[[role]] %||% NA_real_), numeric(1))
    vals <- vals[is.finite(vals)]
    if (length(vals) == 0) NA_real_ else mean(vals)
  }, numeric(1))

  # Per-brand column max for per-column heatmap scaling
  brand_max <- vapply(ordered, function(b) {
    vals <- vapply(att_roles, function(r)
      as.numeric(b$segments[[r]] %||% NA_real_), numeric(1))
    vals <- vals[is.finite(vals) & vals > 0]
    if (length(vals) == 0) 1 else max(vals)
  }, numeric(1))
  names(brand_max) <- vapply(ordered, function(b) b$brand_code, character(1))
  avg_max <- { v <- cat_avg[is.finite(cat_avg) & cat_avg > 0]
               if (length(v) == 0) 1 else max(v) }

  paste0(
    '<section class="fn-section fn-table-section fn-rel-table-section">',
    '<div class="fn-table-wrap">',
    '<table class="ct-table fn-ct-table fn-rel-table">',
    .fn_rel_header(ordered, focal, focal_colour),
    '<tbody>',
    .fn_rel_base_row(ordered, focal),
    paste(vapply(seq_along(att_roles), function(i)
      .fn_rel_att_row(att_roles[i], att_labels[i], ordered, focal,
                      cat_avg[i], brand_max, avg_max),
      character(1)), collapse = ""),
    '</tbody></table></div>',
    .fn_add_insight_strip(),
    '</section>'
  )
}


# ==============================================================================
# INTERNAL: RELATIONSHIP TABLE HELPERS
# ==============================================================================

.fn_rel_header <- function(ordered, focal, focal_colour) {
  focal_name <- {
    e <- Filter(function(b) identical(b$brand_code, focal), ordered)
    if (length(e) > 0) .fn_esc(as.character(e[[1]]$brand_name %||% e[[1]]$brand_code))
    else "Focal"
  }
  comp_entries <- Filter(function(b) !identical(b$brand_code, focal), ordered)

  comp_ths <- paste(vapply(comp_entries, function(b)
    sprintf('<th class="ct-th ct-data-col">%s</th>',
            .fn_esc(as.character(b$brand_name %||% b$brand_code))),
    character(1)), collapse = "")

  paste0(
    '<thead><tr>',
    '<th class="ct-th ct-label-col">Attitude</th>',
    sprintf('<th class="ct-th ct-data-col fn-rel-th-focal">%s</th>', focal_name),
    '<th class="ct-th ct-data-col fn-rel-th-avg"><em>Category avg</em></th>',
    comp_ths,
    '</tr></thead>'
  )
}


.fn_rel_base_row <- function(ordered, focal) {
  all_n <- vapply(ordered, function(b)
    as.numeric(b$aware_base %||% NA_real_), numeric(1))
  finite_n <- all_n[is.finite(all_n)]
  avg_n <- if (length(finite_n) == 0) NA_real_ else mean(finite_n)

  small_base <- if (exists(".FN_SMALL_BASE")) .FN_SMALL_BASE else 30L
  n_cell <- function(n, extra_cls = "") {
    base_cls <- trimws(paste("ct-td ct-data-col", extra_cls))
    if (!is.finite(n))
      return(sprintf('<td class="%s ct-na">&mdash;</td>', base_cls))
    ni <- as.integer(round(n))
    warn <- ni < small_base
    sprintf('<td class="%s"><span class="%s">n=%d%s</span></td>',
            base_cls,
            if (warn) "ct-low-base" else "ct-base-n", ni,
            if (warn) " \u26A0" else "")
  }

  focal_cell <- n_cell(all_n[match(focal,
    vapply(ordered, function(b) b$brand_code, character(1)))],
    "fn-rel-td-focal")
  comp_codes  <- vapply(Filter(function(b) !identical(b$brand_code, focal), ordered),
                        function(b) b$brand_code, character(1))
  comp_cells  <- paste(vapply(which(!vapply(ordered, function(b)
    identical(b$brand_code, focal), logical(1))),
    function(i) n_cell(all_n[i]), character(1)), collapse = "")

  paste0(
    '<tr class="ct-row ct-row-base fn-row-base">',
    '<td class="ct-td ct-label-col">Base (n=)</td>',
    focal_cell,
    n_cell(avg_n, "fn-rel-td-avg"),
    comp_cells,
    '</tr>'
  )
}


.fn_rel_att_row <- function(role, label, ordered, focal,
                             cat_avg_pct, brand_max, avg_max) {
  small_base <- if (exists(".FN_SMALL_BASE")) .FN_SMALL_BASE else 30L

  pct_cell <- function(pct, col_max, extra_cls = "") {
    base_cls <- trimws(paste("ct-td ct-data-col", extra_cls))
    if (!is.finite(pct))
      return(sprintf('<td class="%s ct-na">&mdash;</td>', base_cls))
    denom  <- if (!is.finite(col_max) || col_max <= 0) 1 else col_max
    frac   <- min(1, max(0, pct / denom))
    hm     <- sprintf("rgba(37,99,171,%.3f)", 0.08 + frac * 0.57)
    sprintf(
      '<td class="%s ct-heatmap-cell" data-heatmap="%s" data-fn-pct-abs="%.6f"><span class="ct-val">%.0f%%</span></td>',
      base_cls, hm, pct, 100 * pct)
  }

  focal_idx <- which(vapply(ordered, function(b)
    identical(b$brand_code, focal), logical(1)))
  focal_pct <- if (length(focal_idx) == 1)
    as.numeric(ordered[[focal_idx]]$segments[[role]] %||% NA_real_) else NA_real_

  comp_entries <- Filter(function(b) !identical(b$brand_code, focal), ordered)
  comp_cells <- paste(vapply(comp_entries, function(b) {
    pct <- as.numeric(b$segments[[role]] %||% NA_real_)
    pct_cell(pct, brand_max[[b$brand_code]])
  }, character(1)), collapse = "")

  paste0(
    sprintf('<tr class="ct-row fn-rel-row" data-fn-att="%s">', .fn_esc(role)),
    sprintf('<td class="ct-td ct-label-col">%s</td>', .fn_esc(label)),
    pct_cell(focal_pct, brand_max[[focal]], "fn-rel-td-focal"),
    pct_cell(cat_avg_pct, avg_max, "fn-rel-td-avg"),
    comp_cells,
    '</tr>'
  )
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
# INTERNAL: RELATIONSHIP STACKED BARS
# ==============================================================================

.fn_segment_picker <- function() {
  labels <- c(All = "all", Love = "attitude.love",
              Prefer = "attitude.prefer",
              Ambivalent = "attitude.ambivalent",
              Reject = "attitude.reject",
              `No opinion` = "attitude.no_opinion")
  chips <- vapply(seq_along(labels), function(i) {
    active <- if (names(labels)[i] == "All") " active" else ""
    sprintf('<button type="button" class="col-chip fn-seg-chip%s" data-fn-emphasis="%s">%s</button>',
            active, labels[i], names(labels)[i])
  }, character(1))
  paste0(
    '<div class="fn-seg-picker col-chip-bar">',
    '<span class="col-chip-label">Emphasise:</span>',
    paste(chips, collapse = ""),
    '</div>'
  )
}


.fn_brand_seg_bar <- function(brand, focal_colour, focal_code) {
  segs <- brand$segments %||% list()
  is_focal <- identical(brand$brand_code, focal_code)
  seg_order <- c("attitude.love", "attitude.prefer", "attitude.ambivalent",
                 "attitude.reject", "attitude.no_opinion")
  seg_colours <- c(
    attitude.love = "#1A5276", attitude.prefer = "#2E86C1",
    attitude.ambivalent = "#85C1E9", attitude.reject = "#C0392B",
    attitude.no_opinion = "#D5D8DC")
  seg_labels <- c(attitude.love = "Love", attitude.prefer = "Prefer",
                  attitude.ambivalent = "Ambivalent",
                  attitude.reject = "Reject",
                  attitude.no_opinion = "No opinion")

  segments <- vapply(seg_order, function(role) {
    val <- segs[[role]] %||% 0
    w <- sprintf("%.2f%%", 100 * val)
    sprintf('<span class="fn-seg" data-fn-role="%s" data-fn-pct="%.4f" style="width:%s;background:%s;" title="%s %.0f%%"></span>',
            role, val, w, seg_colours[[role]], seg_labels[[role]],
            100 * val)
  }, character(1))

  focal_attr <- if (is_focal) ' data-fn-focal="1"' else ''
  focal_cls <- if (is_focal) " fn-bar-row-focal" else ""
  sprintf(
    '<div class="fn-bar-row%s" data-fn-brand="%s"%s>
       <div class="fn-bar-label">%s</div>
       <div class="fn-bar-track">%s</div>
     </div>',
    focal_cls, .fn_esc(brand$brand_code), focal_attr,
    .fn_esc(brand$brand_name %||% brand$brand_code),
    paste(segments, collapse = "")
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
