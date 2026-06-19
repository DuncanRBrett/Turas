# ==============================================================================
# TABS — SEGMENT TREND COMPUTE (v2 data-centric report)
# ==============================================================================
# Config-driven orchestrator that turns per-respondent wave data into the
# tracker `trend_results` shape (question -> segment -> wave_results) by calling
# the classic tracker module's TESTED calculators — `calculate_weighted_mean`,
# `calculate_nps_score`, `calculate_proportions` (modules/tracker/lib/
# statistical_core.R). The result feeds `tracker_segment_contributions()`
# (tracking_segment_bridge.R) -> the v2 wave island.
#
# This is the "integrated tracker with segments" engine for the new format:
# Total + each value of every banner dimension (e.g. Campus / Department /
# Tenure), per wave, for each tracked metric. Segment cells with no data are
# dropped (a metric or banner absent in a wave just leaves a gap — graceful).
#
# Cross-wave matching is by COLUMN per wave (the caller supplies, per wave, the
# data column for each metric and each banner dimension), so renumbered surveys
# and renamed banner columns are handled. Metric titles + segment values are the
# canonical keys the renderer matches on (tracking_norm).
#
# DEPENDS ON: the tracker calculators (statistical_core.R) being loaded.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Case-insensitive, whitespace-trimmed equality against a banner value.
.tsc_eq <- function(x, value) {
  trimws(toupper(as.character(x))) == trimws(toupper(as.character(value)))
}

# One wave_result (the tracker calculator output + available=TRUE), or NULL.
.tsc_wave_result <- function(type, vals, weights) {
  if (identical(type, "proportions")) {
    if (all(is.na(vals))) return(NULL)
    r <- calculate_proportions(as.character(vals), weights)
    return(list(proportions = as.list(r$proportions),
                n_unweighted = r$n_unweighted, available = TRUE))
  }
  v <- suppressWarnings(as.numeric(vals))
  if (all(is.na(v))) return(NULL)
  if (identical(type, "nps")) {
    r <- calculate_nps_score(v, weights)
    if (length(r$nps) == 1 && is.na(r$nps)) return(NULL)
    return(list(nps = r$nps, n_unweighted = r$n_unweighted, available = TRUE))
  }
  # default: mean-kind
  r <- calculate_weighted_mean(v, weights)
  if (length(r$mean) == 1 && is.na(r$mean)) return(NULL)
  list(mean = r$mean, sd = r$sd, n_unweighted = r$n_unweighted, available = TRUE)
}

#' Compute per-segment wave trends from per-respondent wave data
#'
#' @param waves List of `list(id = <wave id>, data = <per-respondent data.frame>)`,
#'   oldest first.
#' @param metrics List of tracked metrics, each
#'   `list(code = <stable id>, title = <canonical question text>,
#'         type = "mean" | "nps" | "proportions",
#'         cols = list(<wave id> = <data column name in that wave>))`.
#' @param segment_dims List of banner dimensions, each
#'   `list(label = <e.g. "Campus">, cols = list(<wave id> = <column>))`.
#' @param weight_col Optional weight column name (used when present in a wave;
#'   absent -> unweighted).
#'
#' @return `list(trend_results = <question -> segment -> {metric_type,
#'   question_text, wave_results}>, segments_meta = <segment_name -> {value,
#'   variable, is_total}>)` — ready for `tracker_segment_contributions()`.
#' @export
compute_segment_trends <- function(waves, metrics, segment_dims, weight_col = NULL) {
  if (!is.list(waves) || length(waves) == 0) return(list(trend_results = list(), segments_meta = list()))
  wave_ids <- vapply(waves, function(w) as.character(w$id), character(1))
  wdata <- stats::setNames(lapply(waves, function(w) w$data), wave_ids)

  # Enumerate segments: Total + every value of each dimension seen in any wave.
  segments_meta <- list(Total = list(is_total = TRUE))
  for (dim in segment_dims) {
    vals <- character(0)
    for (wid in wave_ids) {
      col <- dim$cols[[wid]]; d <- wdata[[wid]]
      if (!is.null(col) && col %in% names(d)) {
        vals <- union(vals, as.character(stats::na.omit(unique(d[[col]]))))
      }
    }
    for (v in vals) {
      segments_meta[[paste0(dim$label, "_", v)]] <-
        list(value = v, variable = dim$label, is_total = FALSE, .cols = dim$cols)
    }
  }

  trend_results <- list()
  for (m in metrics) {
    mtype <- m$type %||% "mean"
    qsegs <- list()
    for (sn in names(segments_meta)) {
      seg <- segments_meta[[sn]]
      wr <- list()
      for (wid in wave_ids) {
        d <- wdata[[wid]]
        mcol <- m$cols[[wid]]
        if (is.null(mcol) || !(mcol %in% names(d))) next            # metric absent this wave
        rows <- rep(TRUE, nrow(d))
        if (!isTRUE(seg$is_total)) {
          scol <- seg$.cols[[wid]]
          if (is.null(scol) || !(scol %in% names(d))) next          # dimension absent this wave
          rows <- !is.na(d[[scol]]) & .tsc_eq(d[[scol]], seg$value)
        }
        if (!any(rows)) next
        w <- if (!is.null(weight_col) && weight_col %in% names(d)) {
          as.numeric(d[[weight_col]][rows])
        } else rep(1, sum(rows))
        res <- .tsc_wave_result(mtype, d[[mcol]][rows], w)
        if (!is.null(res)) wr[[wid]] <- res
      }
      if (length(wr)) {
        qsegs[[sn]] <- list(metric_type = mtype, question_text = m$title,
                            key = m$key %||% m$title, wave_results = wr)
      }
    }
    if (length(qsegs)) trend_results[[m$code]] <- qsegs
  }

  # strip the internal .cols before handing segments_meta to the bridge
  segments_meta <- lapply(segments_meta, function(s) { s$.cols <- NULL; s })
  list(trend_results = trend_results, segments_meta = segments_meta)
}

#' Backfill per-wave segment-trend sidecars for the v2 island
#'
#' Writes one `<wave>_wave.json` per wave carrying computed per-segment totals,
#' into a `waves_source` directory. A normal v2 tabs build (run_crosstabs with
#' `html_report_v2_tracking = TRUE` and `waves_source` pointed here) then reads
#' them via `read_wave_contributions()` and assembles a segment-aware island —
#' NO pipeline change. Reuses compute_segment_trends() + the bridge +
#' write_wave_contribution() (so the current wave stays the live tabs run).
#'
#' @param waves,metrics,segment_dims,weight_col As `compute_segment_trends()`.
#' @param out_dir Destination directory (created if absent).
#' @param wave_labels,wave_years Optional lists keyed by wave id (display label /
#'   numeric order key); default to the id and `as.numeric(id)`.
#' @return Character vector of sidecar paths written (invisibly).
#' @export
write_segment_wave_sidecars <- function(waves, metrics, segment_dims, out_dir,
                                        weight_col = NULL, wave_labels = NULL,
                                        wave_years = NULL) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  ct <- compute_segment_trends(waves, metrics, segment_dims, weight_col)
  wave_ids <- vapply(waves, function(w) as.character(w$id), character(1))
  waves_meta <- lapply(wave_ids, function(id) list(
    id = id,
    label = wave_labels[[id]] %||% id,
    year = wave_years[[id]] %||% suppressWarnings(as.numeric(id))))
  contribs <- tracker_segment_contributions(ct$trend_results, ct$segments_meta, waves_meta)
  paths <- character(0)
  for (cw in contribs) {
    fid <- gsub("[^A-Za-z0-9]+", "_", as.character(cw$wave))
    p <- file.path(out_dir, paste0(fid, "_wave.json"))
    write_wave_contribution(cw, p)
    paths <- c(paths, p)
  }
  invisible(paths)
}
