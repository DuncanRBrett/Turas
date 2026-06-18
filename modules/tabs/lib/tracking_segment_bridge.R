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
# SCOPE (Phase 1b): mean-kind metrics (mean / NPS) — values + bases. Per-segment
# significance (carry sd / the published distribution) and proportion / NET rows
# are Phase 2. Depends on tracking_norm() + %||% (tracking_island.R).
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

    for (q_code in names(trend_results)) {
      q_segs <- trend_results[[q_code]]
      total_res <- q_segs[["Total"]]
      if (is.null(total_res)) next
      mtype <- total_res$metric_type %||% "mean"
      if (!(mtype %in% mean_kinds)) next                 # Phase 1b: mean-kind only
      stat_field <- if (identical(mtype, "nps")) "nps" else "mean"
      title <- as.character(total_res$question_text %||% q_code)

      value_at <- function(res) {
        wr <- res$wave_results[[wave_id]]
        if (is.null(wr) || !isTRUE(wr$available)) return(NULL)
        v <- if (identical(stat_field, "nps")) wr$nps else wr$mean
        if (is.null(v) || (length(v) == 1 && is.na(v))) return(NULL)
        base <- wr$n_unweighted %||% NA
        list(value = as.numeric(v),
             base = if (length(base) == 1 && is.na(base)) NA else as.numeric(base))
      }

      tot <- value_at(total_res)
      if (is.null(tot)) next                             # question absent this wave

      seg_stats <- list()
      bases <- list()
      for (bk in breakouts) {
        sres <- q_segs[[bk$seg_name]]
        if (is.null(sres)) next
        sv <- value_at(sres)
        if (is.null(sv)) next
        seg_stats[[bk$key]] <- .tsb_stat(stat_field, sv$value)
        bases[[bk$key]] <- sv$base
        seg_present[[bk$key]] <- list(norm = bk$key, label = bk$label, group = bk$group)
      }

      questions[[length(questions) + 1]] <- list(
        match_key = tracking_norm(title),
        title     = title,
        base      = tot$base,
        stats     = .tsb_stat(stat_field, tot$value),
        seg_stats = seg_stats,
        bases     = bases)
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
