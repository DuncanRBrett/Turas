# ==============================================================================
# BRAND MODULE - MA PANEL METRICS + RANKING SECTION
# ==============================================================================
# Renders the Headline Metrics sub-tab:
#   - Hero strip: focal brand MPen, NS, MMS (with cat avg comparison)
#   - Brand table: per-brand MPen / NS / MMS + heatmap variation
#   - CEP penetration ranking: horizontal bar chart of category-level CEP %
# ==============================================================================


#' Build the MA metrics section HTML.
#' @param pd Panel data from build_ma_panel_data().
#' @param focal_colour Character. Hex colour for focal highlighting.
#' @return Character string (section element).
#' @export
build_ma_metrics_section <- function(pd, focal_colour = "#1A5276") {
  metrics <- pd$metrics
  if (is.null(metrics)) return("")

  paste0(
    '<section class="ma-section ma-metrics-section">',
    .ma_metrics_hero(pd, focal_colour),
    .ma_metrics_table(pd, focal_colour),
    .ma_cep_ranking(pd, focal_colour),
    '</section>'
  )
}


# ==============================================================================
# HERO CARDS: focal brand MPen / NS / MMS
# ==============================================================================

.ma_metrics_hero <- function(pd, focal_colour) {
  m      <- pd$metrics
  hero   <- m$focal_hero
  avg    <- m$cat_avg
  leader <- m$leader
  focal  <- pd$meta$focal_brand_code
  focal_name <- pd$meta$focal_brand_name %||% focal

  brand_names <- pd$config$brand_names %||% pd$config$brand_codes

  leader_name <- function(code) {
    idx <- match(code, pd$config$brand_codes)
    if (is.na(idx)) code else brand_names[idx]
  }

  card <- function(label, focal_val, avg_val, leader_code, unit) {
    focal_disp <- if (is.na(focal_val)) "\u2014"
                  else if (unit == "pct") sprintf("%.1f%%", focal_val)
                  else sprintf("%.2f", focal_val)
    avg_disp <- if (is.na(avg_val)) "\u2014"
                else if (unit == "pct") sprintf("%.1f%%", avg_val)
                else sprintf("%.2f", avg_val)
    lead_name <- leader_name(leader_code)
    is_leader <- identical(focal, leader_code)
    leader_line <- if (is_leader)
      '<div class="ma-hero-leader ma-hero-leader-focal">Category leader</div>'
      else sprintf('<div class="ma-hero-leader">Leader: <strong>%s</strong></div>',
                   .ma_esc(lead_name))
    sprintf(
      '<div class="tk-hero-card ma-hero-card" style="border-left-color:%s;">
         <div class="tk-hero-label">%s</div>
         <div class="tk-hero-value" style="color:%s;">%s</div>
         <div class="ma-hero-compare">Category avg: <strong>%s</strong></div>
         %s
       </div>',
      focal_colour, .ma_esc(label),
      focal_colour, focal_disp,
      avg_disp, leader_line)
  }

  paste0(
    sprintf('<h3 class="ma-section-title">%s \u2014 Headline Metrics</h3>',
            .ma_esc(focal_name)),
    '<div class="ma-hero-strip tk-hero-strip">',
    card("Mental Penetration (MPen)", hero$mpen, avg$mpen, leader$mpen, "pct"),
    card("Network Size (NS)",         hero$ns,   avg$ns,   leader$ns,   "num"),
    card("Mental Market Share (MMS)", hero$mms,  avg$mms,  leader$mms,  "pct"),
    '</div>'
  )
}


# ==============================================================================
# BRAND METRICS TABLE
# ==============================================================================

.ma_metrics_table <- function(pd, focal_colour) {
  rows <- pd$metrics$table
  if (is.null(rows) || length(rows) == 0) return("")

  focal <- pd$meta$focal_brand_code

  # Sort by MMS desc by default
  ord <- order(-vapply(rows, function(r) r$mms %||% NA_real_, numeric(1)))
  rows <- rows[ord]

  # Per-metric max/min for heatmap normalisation
  mpens <- vapply(rows, function(r) r$mpen %||% NA_real_, numeric(1))
  nss   <- vapply(rows, function(r) r$ns   %||% NA_real_, numeric(1))
  mmss  <- vapply(rows, function(r) r$mms  %||% NA_real_, numeric(1))

  fmt_cell <- function(val, col_vals, fmt) {
    if (is.na(val)) return('<td class="ct-td ct-data-col ct-na">&mdash;</td>')
    disp <- if (fmt == "pct") sprintf("%.1f%%", val) else sprintf("%.2f", val)
    col_max <- max(col_vals, na.rm = TRUE)
    frac <- if (is.finite(col_max) && col_max > 0) val / col_max else 0
    frac <- min(1, max(0, frac))
    alpha <- 0.08 + frac * 0.55
    sprintf(
      '<td class="ct-td ct-data-col ma-heatmap-cell" style="background-color:rgba(37,99,171,%.3f);" data-sort-val="%.6f"><span class="ct-val">%s</span></td>',
      alpha, val, disp)
  }

  row_html <- vapply(rows, function(r) {
    focal_row <- !is.null(focal) && identical(r$brand_code, focal)
    cls <- if (focal_row) "ct-row ma-row ma-row-focal" else "ct-row ma-row"
    style <- if (focal_row) sprintf(' style="--ma-row-accent:%s;"', focal_colour) else ""
    focal_badge <- if (focal_row)
      ' <span class="ma-focal-badge">FOCAL</span>' else ""
    paste0(
      sprintf('<tr class="%s" data-ma-brand="%s"%s>', cls,
              .ma_esc(r$brand_code), style),
      sprintf('<td class="ct-td ct-label-col">%s%s</td>',
              .ma_esc(r$brand_name), focal_badge),
      fmt_cell(r$mpen, mpens, "pct"),
      fmt_cell(r$ns,   nss,   "num"),
      fmt_cell(r$mms,  mmss,  "pct"),
      '</tr>'
    )
  }, character(1))

  paste0(
    '<h4 class="ma-subsection-title">Brand metrics ranked by Mental Market Share</h4>',
    '<div class="ma-table-wrap">',
    '<table class="ct-table ma-ct-table ma-metrics-table">',
    '<thead><tr>',
    '<th class="ct-th ct-label-col">Brand</th>',
    '<th class="ct-th ct-data-col" title="% of category buyers linking the brand to at least one CEP">MPen</th>',
    '<th class="ct-th ct-data-col" title="Avg CEPs per linker">NS</th>',
    '<th class="ct-th ct-data-col" title="Share of all brand-CEP links in the category">MMS</th>',
    '</tr></thead>',
    '<tbody>',
    paste(row_html, collapse = ""),
    '</tbody></table></div>'
  )
}


# ==============================================================================
# CEP PENETRATION RANKING (horizontal bar chart)
# ==============================================================================

.ma_cep_ranking <- function(pd, focal_colour) {
  rank_df <- pd$metrics$cep_penetration
  if (is.null(rank_df) || nrow(rank_df) == 0) return("")

  # Align with CEP labels if available
  cep_labels <- pd$ceps$labels %||% character(0)
  cep_codes  <- pd$ceps$codes  %||% character(0)
  label_map <- stats::setNames(cep_labels, cep_codes)

  rank_df <- rank_df[order(-rank_df$Penetration_Pct), , drop = FALSE]
  max_pct <- max(rank_df$Penetration_Pct, na.rm = TRUE)
  if (!is.finite(max_pct) || max_pct <= 0) max_pct <- 100

  bars_html <- vapply(seq_len(nrow(rank_df)), function(i) {
    code <- as.character(rank_df$CEPCode[i])
    pct  <- as.numeric(rank_df$Penetration_Pct[i])
    label <- label_map[[code]]
    if (is.null(label) || is.na(label)) label <- code
    width <- max(2, 100 * pct / max_pct)
    sprintf(
      '<div class="ma-rank-row">
         <div class="ma-rank-rank">#%d</div>
         <div class="ma-rank-label" title="%s">%s</div>
         <div class="ma-rank-bar-track">
           <div class="ma-rank-bar-fill" style="width:%.1f%%;background:%s;"></div>
           <div class="ma-rank-bar-value">%.0f%%</div>
         </div>
       </div>',
      i, .ma_esc(label), .ma_esc(label),
      width, focal_colour, pct)
  }, character(1))

  paste0(
    '<h4 class="ma-subsection-title">Category Entry Point penetration (any brand)</h4>',
    '<p class="ma-subsection-note">How often each entry point comes to mind in the category, regardless of brand. The biggest entry points are where mental presence matters most.</p>',
    '<div class="ma-rank-list">',
    paste(bars_html, collapse = ""),
    '</div>'
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!exists(".ma_esc", mode = "function")) {
  .ma_esc <- function(x) {
    if (is.null(x)) return("")
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub("\"", "&quot;", x, fixed = TRUE)
    x
  }
}
