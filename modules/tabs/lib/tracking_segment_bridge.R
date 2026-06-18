# ==============================================================================
# TABS — TRACKING SEGMENT BRIDGE (v2 data-centric report, Phase 1b)
# ==============================================================================
# Serialises the classic tracker module's per-segment trend output into the v2
# wave-island's PRIOR-wave contributions, carrying COMPUTED per-segment totals
# (means / NPS) + bases.
#
# Tracker output shape (calculate_trends_with_banners(), banner_trends.R):
#   trend_results[[question_code]][[segment_name]] = list(
#     metric_type, question_text,
#     wave_results = list(<wave_id> = c(<calculator output>, available = TRUE)))
#   where a mean wave_result carries $mean + $n_unweighted, an NPS one $nps + …
#   Segments come from get_banner_segments(): "Total" (is_total) + one per banner
#   value, each list(name, variable, value, is_total).
#
# Island consumer (assets/js/22w_waves.js) — already built for this:
#   meanValue -> waveQ.seg_stats[segKey].{mean,nps} (Total via waveQ.stats)
#   baseOf    -> waveQ.bases[segKey]                (Total via waveQ.base)
#   waves.segments() matches w.segments[].norm to the AGG banner-column label.
# So the segment KEY is tracking_norm(segment value) — it matches the column
# label (e.g. "Western Cape" -> "western cape").
#
# DECISION (docs/SEGMENT_WAVE_TRENDS_PLAN.md): history = computed per-segment
# totals, NOT raw microdata; the current wave stays live from the tabs run.
#
# SCOPE: mean-kind metrics (mean / NPS) -> values + bases; proportions ->
# published-distribution rows (Total + per-segment %, so rowValue lights up).
# Per-segment SIGNIFICANCE for means (carry sd) and multi_mention / NET-diff rows
# are later phases. Depends on tracking_norm() + %||% (tracking_island.R).
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' A one-field named list, i.e. a JSON object `{field: value}`
#'
#' Kept explicit so jsonlite never collapses a single-entry stats block to an
#' array — the renderer reads `waveQ.stats.mean` / `waveQ.seg_stats[k].mean`.
#'
#' @keywords internal
.tsb_stat <- function(field, value) {
  s <- list()
  s[[field]] <- value
  s
}

#' Build v2 wave-island prior-wave contributions from tracker banner trends
#'
#' Transposes the tracker's question -> segment -> wave nesting into the island's
#' wave -> question -> segment shape, carrying per-segment computed totals.
#'
#' @param trend_results Output of `calculate_trends_with_banners()`:
#'   question_code -> segment_name -> list(metric_type, question_text,
#'   wave_results = list(wave_id = list(mean|nps, n_unweighted, available))).
#' @param segments_meta Banner segment definitions from `get_banner_segments()`:
#'   segment_name -> list(value, variable, is_total).
#' @param waves_meta List of the PRIOR waves to emit, oldest first; each
#'   list(id = <WaveID>, label = <display label>, year = <numeric order key>).
#'
#' @return A list of wave contributions (each `current = FALSE`), each
#'   \item{wave}{display label}
#'   \item{year}{numeric order key}
#'   \item{segments}{array of {norm, label, group} present that wave}
#'   \item{questions}{array of {match_key, title, base, stats, seg_stats, bases}}
#'   Returns an empty `list()` when there is nothing mean-kind to carry.
#'
#' @export
tracker_segment_contributions <- function(trend_results, segments_meta, waves_meta) {
  if (!is.list(trend_results) || length(trend_results) == 0) return(list())
  if (!is.list(waves_meta) || length(waves_meta) == 0) return(list())
  mean_kinds <- c("mean", "nps", "rating_enhanced", "composite_enhanced")

  # Breakout segment descriptors (the Total segment is the seg = null path).
  breakouts <- list()
  for (seg_name in names(segments_meta)) {
    sd <- segments_meta[[seg_name]]
    if (isTRUE(sd$is_total)) next
    breakouts[[length(breakouts) + 1]] <- list(
      seg_name = seg_name,
      key      = tracking_norm(sd$value),
      label    = as.character(sd$value),
      group    = as.character(sd$variable %||% ""))
  }

  out_waves <- list()
  for (wm in waves_meta) {
    wave_id <- wm$id
    seg_present <- list()
    questions <- list()

    # This wave's raw calculator output for a segment (NULL when absent).
    wr_of <- function(res) {
      if (is.null(res)) return(NULL)
      wr <- res$wave_results[[wave_id]]
      if (is.null(wr) || !isTRUE(wr$available)) return(NULL)
      wr
    }
    base_of <- function(wr) {
      b <- wr$n_unweighted %||% NA
      if (length(b) == 1 && is.na(b)) NA else as.numeric(b)
    }
    num_or_null <- function(v) {
      if (is.null(v) || (length(v) == 1 && is.na(v))) NULL else as.numeric(v)
    }

    for (q_code in names(trend_results)) {
      q_segs <- trend_results[[q_code]]
      total_res <- q_segs[["Total"]]
      if (is.null(total_res)) next
      mtype <- total_res$metric_type %||% "mean"
      title <- as.character(total_res$question_text %||% q_code)
      tot_wr <- wr_of(total_res)
      if (is.null(tot_wr)) next                          # question absent this wave

      q <- NULL
      if (mtype %in% mean_kinds) {
        # mean-kind: one value per segment under stats / seg_stats. Means also
        # carry the SD (NPS has none) so the renderer's Welch test can run on
        # the trend without the published distribution.
        stat_field <- if (identical(mtype, "nps")) "nps" else "mean"
        is_mean <- identical(stat_field, "mean")
        mk_stat <- function(wr) {
          v <- num_or_null(if (is_mean) wr$mean else wr$nps)
          if (is.null(v)) return(NULL)
          s <- .tsb_stat(stat_field, v)
          if (is_mean) {
            sd <- num_or_null(wr$sd)
            if (!is.null(sd)) s$sd <- sd
          }
          s
        }
        tot_stat <- mk_stat(tot_wr)
        if (is.null(tot_stat)) next
        seg_stats <- list(); bases <- list()
        for (bk in breakouts) {
          swr <- wr_of(q_segs[[bk$seg_name]]); if (is.null(swr)) next
          ss <- mk_stat(swr); if (is.null(ss)) next
          seg_stats[[bk$key]] <- ss
          bases[[bk$key]] <- base_of(swr)
          seg_present[[bk$key]] <- list(norm = bk$key, label = bk$label, group = bk$group)
        }
        q <- list(match_key = tracking_norm(title), title = title,
                  base = base_of(tot_wr), stats = tot_stat,
                  seg_stats = seg_stats, bases = bases)

      } else if (identical(mtype, "proportions")) {
        # proportions: one published-distribution row per option, Total pct +
        # per-segment pct (rowValue reads rows[norm(label)].pct / .seg[segKey]).
        tot_props <- tot_wr$proportions
        if (is.null(tot_props) || length(tot_props) == 0) next
        tbase <- base_of(tot_wr)
        opts <- names(tot_props)
        rows <- list()
        for (opt in opts) {
          pct <- num_or_null(tot_props[[opt]]); if (is.null(pct)) next
          rows[[tracking_norm(opt)]] <- list(
            pct = pct,
            n   = if (is.na(tbase)) NULL else round(pct / 100 * tbase),
            seg = list())
        }
        if (length(rows) == 0) next
        bases <- list()
        for (bk in breakouts) {
          swr <- wr_of(q_segs[[bk$seg_name]]); if (is.null(swr)) next
          bases[[bk$key]] <- base_of(swr)
          sprops <- swr$proportions
          if (!is.null(sprops)) {
            for (opt in opts) {
              key <- tracking_norm(opt)
              if (is.null(rows[[key]])) next
              sp <- num_or_null(sprops[[opt]])
              if (!is.null(sp)) rows[[key]]$seg[[bk$key]] <- sp
            }
          }
          seg_present[[bk$key]] <- list(norm = bk$key, label = bk$label, group = bk$group)
        }
        q <- list(match_key = tracking_norm(title), title = title,
                  base = tbase, rows = rows, bases = bases)

      } else {
        next                                             # multi_mention etc. — later phase
      }

      questions[[length(questions) + 1]] <- q
    }

    if (length(questions) == 0) next
    out_waves[[length(out_waves) + 1]] <- list(
      wave      = as.character(wm$label %||% wave_id),
      year      = wm$year,
      current   = FALSE,
      segments  = unname(seg_present),
      questions = questions)
  }
  out_waves
}
