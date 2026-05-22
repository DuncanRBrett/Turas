# ==============================================================================
# BRAND MODULE — SHOPPER CONTEXT + FOCAL ENGAGEMENT SECTIONS
# ==============================================================================
# Sample-wide additions to the Summary tab. Two stacked sections appended below
# the existing dashboard:
#
#   1. Shopper context — Grocery chains used + Media channels consumed + Recipe
#      use (5-pt). Sample-wide; doesn't follow the category / focal dropdowns.
#
#   2. Focal-brand engagement — IPK web visit, recipe-book purchase, IPK
#      recipes tried. KPIs computed against the focal brand (defaults to IPK).
#
# Both sections short-circuit to empty when the source data isn't present
# (Brand reports for clients without these questions render the rest of
# Summary unchanged).
#
# Public API:
#   build_shopper_summary_sections(results, config) -> character HTML
#   build_shopper_summary_styles()                  -> character CSS
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


.brss_esc <- function(s) {
  if (is.null(s) || length(s) == 0) return("")
  s <- as.character(s)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;",  s, fixed = TRUE)
  s <- gsub(">", "&gt;",  s, fixed = TRUE)
  s
}


# Render a horizontal-bar chart row: label + bar (width = pct) + percentage
# text. Bars share a common max so the eye can compare rows. Hides options
# the analyst marked as "None of the above" by drawing them with a muted
# style instead of removing them — small N is still informative context.
.brss_bar_row <- function(label, pct, max_pct, focal_colour, is_filler = FALSE) {
  width_pct <- if (max_pct > 0) max(2, min(100, pct / max_pct * 100)) else 0
  bar_colour <- if (is_filler) "#cbd5e1" else focal_colour
  sprintf(
    paste0('<div class="brss-bar-row%s">',
           '<div class="brss-bar-label" title="%s">%s</div>',
           '<div class="brss-bar-track">',
           '<div class="brss-bar-fill" style="width:%.1f%%;background:%s;"></div>',
           '</div>',
           '<div class="brss-bar-value">%.0f%%</div>',
           '</div>'),
    if (is_filler) " brss-bar-row-filler" else "",
    .brss_esc(label), .brss_esc(label),
    width_pct, bar_colour, pct
  )
}


# Build the bar chart for a multi-mention question or single-mention scale.
# Rows already come ordered (by Options sheet SortOrder).
.brss_bar_chart <- function(question, focal_colour, max_rows = 10L) {
  if (is.null(question) || length(question$rows) == 0)
    return('<div class="brss-empty">No responses recorded.</div>')
  rows <- question$rows
  # Cap to top N by pct (most informative). Keep the SortOrder for the
  # retained rows so the chart still reads top-to-bottom in option order.
  if (length(rows) > max_rows) {
    pct_v <- vapply(rows, function(r) r$pct_weighted %||% 0, numeric(1))
    keep <- order(-pct_v)[seq_len(max_rows)]
    rows <- rows[sort(keep)]
  }
  max_pct <- max(vapply(rows, function(r) r$pct_weighted %||% 0, numeric(1)),
                 na.rm = TRUE)
  if (!isTRUE(max_pct > 0)) max_pct <- 1

  bars <- paste(vapply(rows, function(r) {
    label <- r$label %||% r$value %||% "—"
    is_filler <- grepl("^none", label, ignore.case = TRUE)
    .brss_bar_row(label, r$pct_weighted %||% 0, max_pct, focal_colour, is_filler)
  }, character(1)), collapse = "")
  paste0('<div class="brss-bar-chart">', bars, '</div>')
}


# Single KPI card: large %, label, optional base note. Returns "" when the
# KPI itself is NULL (data column wasn't in the survey).
.brss_kpi_card <- function(kpi, title, focal_colour) {
  if (is.null(kpi)) return("")
  pct <- kpi$pct_yes %||% NA_real_
  n_total <- kpi$n_total %||% 0
  base_note <- kpi$base_note %||% sprintf("Base: %d respondents.", n_total)
  pct_display <- if (is.na(pct)) "—" else sprintf("%.0f%%", pct)
  sprintf(
    paste0('<div class="brss-kpi-card">',
           '<div class="brss-kpi-value" style="color:%s">%s</div>',
           '<div class="brss-kpi-title">%s</div>',
           '<div class="brss-kpi-base">%s</div>',
           '</div>'),
    .brss_esc(focal_colour), pct_display,
    .brss_esc(title), .brss_esc(base_note)
  )
}


#' Build the shopper-context + focal-engagement sections for the summary tab
#'
#' @param results Output from run_brand(). Reads results$shopper_context and
#'   results$focal_engagement (both NULL when underlying data absent).
#' @param config Brand config. Reads focal_brand + colour_focal.
#' @return Character. HTML fragment to append to the summary tab content.
#' @export
build_shopper_summary_sections <- function(results, config) {
  ctx <- results$shopper_context
  eng <- results$focal_engagement
  if (is.null(ctx) && is.null(eng)) return("")

  focal_brand   <- config$focal_brand %||% "IPK"
  brand_colours <- config$brand_colours %||% list()
  focal_colour  <- (brand_colours[[focal_brand]]) %||%
                    (config$colour_focal %||% "#1A5276")

  # Section 1: Shopper context (grocery + media + recipe use)
  ctx_html <- ""
  if (!is.null(ctx)) {
    cards <- list()
    if (!is.null(ctx$grocery)) {
      cards[[length(cards) + 1L]] <- sprintf(
        '<div class="brss-section-card"><h4 class="brss-card-title">Grocery chains used (past 3 months)</h4>%s</div>',
        .brss_bar_chart(ctx$grocery, focal_colour))
    }
    if (!is.null(ctx$media)) {
      cards[[length(cards) + 1L]] <- sprintf(
        '<div class="brss-section-card"><h4 class="brss-card-title">Media channels consumed</h4>%s</div>',
        .brss_bar_chart(ctx$media, focal_colour))
    }
    if (!is.null(ctx$recipe_use)) {
      cards[[length(cards) + 1L]] <- sprintf(
        '<div class="brss-section-card"><h4 class="brss-card-title">Recipe use frequency</h4>%s</div>',
        .brss_bar_chart(ctx$recipe_use, focal_colour, max_rows = 5L))
    }
    if (length(cards) > 0) {
      n_total <- ctx$n_total %||% 0
      ctx_html <- paste0(
        '<section class="brss-section">',
        '<div class="brss-section-head"><h3 class="brss-section-title">Sample shopper context</h3>',
        sprintf('<span class="brss-section-meta">n = %d</span></div>', n_total),
        sprintf('<div class="brss-cards-grid brss-cards-grid-%d">', length(cards)),
        paste(unlist(cards), collapse = ""),
        '</div></section>'
      )
    }
  }

  # Section 2: Focal-brand engagement (web / books / recipes-tried)
  eng_html <- ""
  if (!is.null(eng)) {
    focal_label <- focal_brand  # kept short — the section title carries the name
    kpis <- c(
      .brss_kpi_card(eng$website,
        sprintf("Visited %s website", focal_label), focal_colour),
      .brss_kpi_card(eng$books,
        sprintf("Bought %s recipe books", focal_label), focal_colour),
      .brss_kpi_card(eng$recipes_tried,
        sprintf("Tried %s recipes", focal_label), focal_colour)
    )
    kpis <- kpis[nzchar(kpis)]
    if (length(kpis) > 0) {
      eng_html <- paste0(
        '<section class="brss-section">',
        sprintf('<div class="brss-section-head"><h3 class="brss-section-title">%s engagement</h3></div>',
                .brss_esc(focal_label)),
        '<div class="brss-kpi-grid">',
        paste(kpis, collapse = ""),
        '</div></section>'
      )
    }
  }

  paste0(ctx_html, eng_html)
}


#' CSS for the shopper-context + focal-engagement sections
#'
#' @return Character. CSS string to append to the summary panel styles.
#' @export
build_shopper_summary_styles <- function() {
  '
.brss-section {
  margin-top: 24px;
  padding: 20px 24px;
  background: #fff;
  border-radius: 10px;
  border: 1px solid #e2e8f0;
}
.brss-section-head {
  display: flex; align-items: baseline; justify-content: space-between;
  margin-bottom: 16px;
}
.brss-section-title {
  color: #1e293b;
  font-size: 15px;
  font-weight: 600;
  margin: 0;
}
.brss-section-meta {
  color: #94a3b8;
  font-size: 11px;
}
.brss-cards-grid {
  display: grid;
  gap: 16px;
}
.brss-cards-grid-1 { grid-template-columns: 1fr; }
.brss-cards-grid-2 { grid-template-columns: repeat(2, 1fr); }
.brss-cards-grid-3 { grid-template-columns: repeat(3, 1fr); }
.brss-section-card {
  padding: 12px;
  background: #f8fafc;
  border-radius: 8px;
}
.brss-card-title {
  color: #475569;
  font-size: 12px;
  font-weight: 600;
  margin: 0 0 10px 0;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.brss-bar-chart {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.brss-bar-row {
  align-items: center;
  display: grid;
  font-size: 11px;
  gap: 8px;
  grid-template-columns: 130px 1fr 40px;
}
.brss-bar-row-filler { opacity: 0.55; }
.brss-bar-label {
  color: #475569;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.brss-bar-track {
  background: #f1f5f9;
  border-radius: 3px;
  height: 14px;
  overflow: hidden;
  position: relative;
}
.brss-bar-fill {
  border-radius: 3px;
  height: 100%;
  transition: width 0.2s ease;
}
.brss-bar-value {
  color: #1e293b;
  font-weight: 600;
  text-align: right;
}
.brss-kpi-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
}
.brss-kpi-card {
  padding: 18px;
  background: #f8fafc;
  border-radius: 8px;
  text-align: center;
}
.brss-kpi-value {
  font-size: 32px;
  font-weight: 700;
  line-height: 1.1;
}
.brss-kpi-title {
  color: #475569;
  font-size: 12px;
  font-weight: 600;
  margin-top: 6px;
}
.brss-kpi-base {
  color: #94a3b8;
  font-size: 10px;
  margin-top: 8px;
}
.brss-empty {
  color: #94a3b8;
  font-size: 11px;
  font-style: italic;
  padding: 8px 0;
}
'
}
