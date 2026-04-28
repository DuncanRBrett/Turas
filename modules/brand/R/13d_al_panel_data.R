# ==============================================================================
# BRAND MODULE - AUDIENCE LENS: PANEL DATA SHAPER
# ==============================================================================
# Transforms a run_audience_lens() result into the structure the HTML
# renderer expects. Adds:
#   - per-metric value vs total deltas + sig flags (single-audience cards)
#   - decimal-place formatting hints
#   - chip class suffix per pair row (grow / fix / defend / none)
#   - schema_version (so v2 pin payloads can extend without breaking pins
#     captured against v1)
#
# VERSION: 1.0
# ==============================================================================

BRAND_AL_PANEL_DATA_VERSION <- "1.0"


#' Shape a run_audience_lens() result for the HTML renderer
#'
#' @param result Output from \code{run_audience_lens()}.
#' @param category_label Display name for the category (e.g. "Dishwash Soap").
#' @param focal_brand Focal brand code.
#' @param focal_colour Hex colour for focal accents.
#' @param decimal_places Integer; defaults to 0.
#' @param wave_label Optional wave label for the source line.
#'
#' @return List with: schema_version, meta, total, audiences, pair_cards,
#'   chart_payloads (one banner table summary), card_payloads (per-audience
#'   plus per-pair). Returns NULL when the result is empty (no audiences
#'   declared).
#'
#' @export
build_audience_lens_panel_data <- function(result, category_label,
                                            focal_brand, focal_colour,
                                            decimal_places = 0L,
                                            wave_label = "") {
  if (is.null(result)) return(NULL)
  if (identical(result$status, "REFUSED")) return(NULL)
  if (length(result$audiences %||% list()) == 0) return(NULL)

  total <- result$total
  audiences <- result$audiences
  pair_cards <- result$pair_cards %||% list()

  catalog <- audience_lens_metric_catalog()

  # Banner table data: one row per metric, one column per audience
  banner_rows <- lapply(catalog, function(group) {
    rows <- lapply(group$metrics, function(m) {
      cells <- lapply(audiences, function(b) {
        bm <- b$metrics[[m$id]]
        if (is.null(bm)) {
          return(list(value = NA_real_, n_base = 0L, base_state = b$base_state,
                      delta_vs_total = NA_real_,
                      buyer_base_na = FALSE, formatted = "—",
                      delta_formatted = "—"))
        }
        # N/A on non-buyer pair side for buyer-base metrics
        is_b_side_of_pair <- !is.null(b$audience$pair_id) &&
                              !is.null(b$audience$pair_role) &&
                              toupper(b$audience$pair_role) == "B"
        buyer_base_na <- isTRUE(m$buyer_base) && is_b_side_of_pair
        if (buyer_base_na) {
          return(list(value = NA_real_, n_base = 0L, base_state = b$base_state,
                      delta_vs_total = NA_real_,
                      buyer_base_na = TRUE, formatted = "N/A †",
                      delta_formatted = "—"))
        }
        tot <- (total$metrics[[m$id]] %||% list(value = NA_real_))$value
        delta <- if (!is.na(bm$value) && !is.na(tot)) bm$value - tot else NA_real_
        list(value = bm$value, n_base = bm$n_base,
             base_state = b$base_state,
             delta_vs_total = delta,
             buyer_base_na = FALSE,
             formatted = .al_fmt_value(bm$value, m$kind, decimal_places),
             delta_formatted = .al_fmt_delta(delta, m$kind, decimal_places))
      })
      total_cell <- {
        tm <- total$metrics[[m$id]]
        if (is.null(tm)) list(value = NA_real_, formatted = "—") else
          list(value = tm$value,
               formatted = .al_fmt_value(tm$value, m$kind, decimal_places))
      }
      list(
        metric_id = m$id, metric_label = m$label, kind = m$kind,
        buyer_base = isTRUE(m$buyer_base),
        total = total_cell,
        cells = cells
      )
    })
    list(group = group$group, rows = rows)
  })

  # Per-audience cards: each holds the formatted scorecard + delta vs total
  cards <- lapply(audiences, function(b) {
    rows <- lapply(catalog, function(group) {
      lapply(group$metrics, function(m) {
        bm <- b$metrics[[m$id]]
        is_b_side <- !is.null(b$audience$pair_id) &&
                       toupper(b$audience$pair_role %||% "") == "B"
        buyer_base_na <- isTRUE(m$buyer_base) && is_b_side
        tot <- (total$metrics[[m$id]] %||% list(value = NA_real_))$value
        delta <- if (!buyer_base_na && !is.null(bm) &&
                       !is.na(bm$value) && !is.na(tot))
                    bm$value - tot else NA_real_
        list(
          metric_id = m$id, metric_label = m$label, group = group$group,
          kind = m$kind, buyer_base = isTRUE(m$buyer_base),
          buyer_base_na = buyer_base_na,
          value = if (is.null(bm)) NA_real_ else bm$value,
          n_base = if (is.null(bm)) 0L else bm$n_base,
          delta_vs_total = delta,
          value_formatted = if (buyer_base_na) "N/A †" else
            .al_fmt_value(if (is.null(bm)) NA_real_ else bm$value,
                           m$kind, decimal_places),
          delta_formatted = if (buyer_base_na) "—" else
            .al_fmt_delta(delta, m$kind, decimal_places),
          note = if (is.null(bm)) NULL else bm$note
        )
      })
    })
    list(
      audience = b$audience,
      n_unweighted = b$n_unweighted,
      n_weighted = b$n_weighted,
      base_state = b$base_state,
      rows = unlist(rows, recursive = FALSE)
    )
  })

  # Pair cards: classifier output + formatted display values
  pair_cards_shaped <- lapply(pair_cards, function(pc) {
    if (is.null(pc) || is.null(pc$rows)) return(NULL)
    pc$rows$value_total_fmt <- mapply(.al_fmt_value, pc$rows$value_total,
                                       pc$rows$kind, decimal_places,
                                       USE.NAMES = FALSE)
    pc$rows$value_a_fmt <- mapply(.al_fmt_value, pc$rows$value_a,
                                   pc$rows$kind, decimal_places,
                                   USE.NAMES = FALSE)
    pc$rows$value_b_fmt <- ifelse(pc$rows$buyer_base, "N/A †",
                                   mapply(.al_fmt_value, pc$rows$value_b,
                                          pc$rows$kind, decimal_places,
                                          USE.NAMES = FALSE))
    pc$rows$delta_fmt <- ifelse(pc$rows$buyer_base, "—",
                                 mapply(.al_fmt_delta, pc$rows$delta_ab,
                                        pc$rows$kind, decimal_places,
                                        USE.NAMES = FALSE))
    pc$rows$chip_class <- vapply(pc$rows$chip, function(c) {
      if (is.na(c) || !nzchar(c)) "none" else tolower(c)
    }, character(1))
    pc$auto_insight <- .al_pair_auto_insight(pc, focal_brand, category_label)
    pc
  })

  list(
    schema_version = 1L,
    meta = list(
      cat_code        = result$meta$cat_code,
      category_label  = category_label,
      focal_brand     = focal_brand,
      focal_colour    = focal_colour,
      wave_label      = as.character(wave_label %||% ""),
      n_total         = result$meta$n_total,
      thresholds      = result$meta$thresholds,
      decimal_places  = as.integer(decimal_places),
      n_audiences     = length(audiences),
      n_suppressed    = length(result$suppressed %||% list()),
      generated_at    = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    ),
    total = list(metrics = total$metrics,
                 n_unweighted = total$n_unweighted,
                 n_weighted = total$n_weighted),
    banner_groups = banner_rows,
    cards = cards,
    pair_cards = pair_cards_shaped,
    suppressed = result$suppressed %||% list()
  )
}


# ==============================================================================
# Formatting helpers — kept here so the renderer never needs to know units.
# ==============================================================================

.al_fmt_value <- function(v, kind, dp) {
  if (length(v) == 0 || is.na(v) || !is.finite(v)) return("—")
  dp <- as.integer(dp)
  switch(as.character(kind),
    "pct"   = sprintf("%.*f%%", dp, 100 * v),
    "net"   = sprintf("%+.*f", dp, 100 * v),
    "ratio" = sprintf("%.*f", max(dp, 2L), v),
    "num"   = sprintf("%.*f", max(dp, 1L), v),
    "dist"  = sprintf("%.*f%%", dp, 100 * v),
    sprintf("%.*f", dp, v)
  )
}


.al_fmt_delta <- function(v, kind, dp) {
  if (length(v) == 0 || is.na(v) || !is.finite(v)) return("—")
  dp <- as.integer(dp)
  switch(as.character(kind),
    "pct"   = sprintf("%+.*fpp", dp, 100 * v),
    "net"   = sprintf("%+.*f", dp, 100 * v),
    "ratio" = sprintf("%+.*f", max(dp, 2L), v),
    "num"   = sprintf("%+.*f", max(dp, 1L), v),
    "dist"  = sprintf("%+.*fpp", dp, 100 * v),
    sprintf("%+.*f", dp, v)
  )
}


.al_pair_auto_insight <- function(pc, focal_brand, category_label) {
  rows <- pc$rows
  if (is.null(rows) || nrow(rows) == 0) return("")
  sig_grow <- rows[rows$chip == "GROW" & !is.na(rows$chip), , drop = FALSE]
  sig_fix  <- rows[rows$chip == "FIX"  & !is.na(rows$chip), , drop = FALSE]

  parts <- character(0)
  if (nrow(sig_grow) > 0) {
    top <- sig_grow[order(-abs(sig_grow$delta_ab))[1], ]
    parts <- c(parts, sprintf(
      "Among %s (n=%d) vs %s (n=%d), %s shows the largest gap (%s) — recruitment lever.",
      pc$label_a, pc$n_a, pc$label_b, pc$n_b,
      tolower(top$metric_label), top$delta_fmt))
  }
  if (nrow(sig_fix) > 0) {
    top <- sig_fix[1, ]
    parts <- c(parts, sprintf(
      "%s underperforms category total — retention focus.",
      top$metric_label))
  }
  if (length(parts) == 0) {
    parts <- sprintf(
      "No significant differences between %s and %s for %s in %s.",
      pc$label_a, pc$label_b, focal_brand, category_label)
  }
  paste(parts, collapse = " ")
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Audience lens panel data loaded (v%s)",
                  BRAND_AL_PANEL_DATA_VERSION))
}
