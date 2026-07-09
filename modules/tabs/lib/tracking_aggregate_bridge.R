# ==============================================================================
# TABS — AGGREGATE-WAVE BRIDGE (v2 data-centric report)
# ==============================================================================
# Emits v2 wave-island PRIOR-wave contributions from a PRE-COMPUTED long values
# table — one row per (metric, wave): a published figure + optional base + sd,
# with no respondent-level microdata. These are the historical waves that survive
# only as spreadsheet aggregates (e.g. CCPB 2011->2024).
#
# This is the value-only twin of tracking_segment_bridge.R: it produces the EXACT
# same island shapes the v2 wave engine (assets/js/22w_waves.js) reads, but from a
# table of figures instead of the classic tracker's microdata-derived trends. The
# consumer contract (locked by test_tracking_segment_bridge.R + the JS gate):
#   mean  -> waveQ.stats.index   (+ .mean mirror, + .sd ONLY when recorded)
#   nps   -> waveQ.stats.nps
#   prop  -> waveQ.rows[norm(category)].pct   (+ .n when a base is known)
#   base  -> waveQ.base
# The renderer decides mean-vs-proportion from the CURRENT question's row kind;
# metric_type/score_type is written but never read by JS. Matching is by
# match_key = tracking_norm(canonical code); a proportion row matches the current
# question's category row by tracking_norm(label).
#
# HONEST BY CONSTRUCTION — the whole point of loading aggregates:
#   - a mean carries sd ONLY when the values table records it; a blank sd makes
#     the renderer's Welch test return "no test", so historical means plot
#     untested (never a fabricated arrow);
#   - a proportion carries its base -> a real pooled-z test wherever a base
#     exists, and no base -> no test;
#   - an NPS net never carries the promoter/detractor split -> "no test".
# It NEVER invents a base, an sd, or a category. A proportion metric with no
# resolvable tracked category is SKIPPED with a console warning, not mis-keyed.
#
# Aggregate history is Total-only: contributions carry no segment breakouts
# (segments = [], and questions omit seg_stats/bases — the renderer reads those
# only when a segment is active). Depends on tracking_norm() + %||%
# (tracking_island.R); the sidecar writer also uses write_wave_contribution().
#
# OFFLINE tool (like tracking_segment_bridge.R): used to GENERATE prior-wave
# sidecars, which the live run then reads via read_wave_contributions(). Not
# sourced in the run_crosstabs hot path.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Accepted metric vocabulary (mirrors the tracker's values-table loader; the
# plural "proportions" is normalised to "proportion").
AGGREGATE_BRIDGE_METRIC_TYPES <- c("mean", "proportion", "nps")


#' Extract the single tracked category from a TrackingSpecs string
#'
#' Reuses the tracker's spec grammar `category:<value>[=<display label>]`,
#' optionally among comma-separated specs (e.g. "mean,category:Yes"). Returns the
#' <value> — the option text the v2 crosstab row is matched on, so any display
#' label after "=" is dropped — or NA when no category spec is present.
#'
#' @param specs A single TrackingSpecs string (or NA).
#' @return The category value, or NA_character_.
#' @keywords internal
.awb_category_from_specs <- function(specs) {
  if (is.null(specs) || length(specs) != 1 || is.na(specs)) return(NA_character_)
  toks <- trimws(strsplit(as.character(specs), ",", fixed = TRUE)[[1]])
  hit <- toks[grepl("^category:", toks, ignore.case = TRUE)]
  if (length(hit) == 0) return(NA_character_)
  val <- sub("^category:", "", hit[1], ignore.case = TRUE)
  val <- strsplit(val, "=", fixed = TRUE)[[1]][1]   # drop the display label after '='
  val <- trimws(val)
  if (!nzchar(val)) NA_character_ else val
}


#' Build a per-metric lookup (title + proportion category) from a QuestionMap body
#'
#' @param mapping A QuestionMap body data frame (from load_question_mapping()), or
#'   NULL. Read columns: QuestionCode (the join key == metric_id), QuestionText
#'   (title), TrackingSpecs (the proportion category). First row per code wins.
#' @return A named list keyed by QuestionCode: each list(title, category).
#' @keywords internal
.awb_mapping_lookup <- function(mapping) {
  lut <- list()
  if (is.null(mapping) || !is.data.frame(mapping) || nrow(mapping) == 0) return(lut)
  if (!("QuestionCode" %in% names(mapping))) return(lut)
  codes  <- trimws(as.character(mapping$QuestionCode))
  titles <- if ("QuestionText" %in% names(mapping)) {
    as.character(mapping$QuestionText)
  } else rep(NA_character_, length(codes))
  specs  <- if ("TrackingSpecs" %in% names(mapping)) {
    as.character(mapping$TrackingSpecs)
  } else rep(NA_character_, length(codes))
  for (i in seq_along(codes)) {
    code <- codes[i]
    if (is.na(code) || !nzchar(code) || !is.null(lut[[code]])) next
    ttl <- titles[i]
    ttl <- if (is.na(ttl) || !nzchar(trimws(ttl))) NA_character_ else trimws(ttl)
    lut[[code]] <- list(title = ttl, category = .awb_category_from_specs(specs[i]))
  }
  lut
}


#' Derive waves_meta from the distinct waves in a values table
#'
#' @param wave_col Character vector of the values table's wave column.
#' @return A list(id, label, year) per distinct wave, year = the 4-digit year in
#'   the id when present (else NA, so assembly keeps input order).
#' @keywords internal
.awb_default_waves_meta <- function(wave_col) {
  lapply(unique(wave_col), function(w) {
    m <- regmatches(w, regexpr("(19|20)\\d{2}", w))
    list(id = w, label = w, year = if (length(m) == 1) as.numeric(m) else NA_real_)
  })
}


#' Build v2 wave-island prior-wave contributions from a pre-computed values table
#'
#' Turns a long table of published aggregates into the wave-island's prior-wave
#' contributions, in the exact shapes the renderer reads — so historical waves
#' that have no microdata still light up the Tracking tab, with honest
#' significance (see the file header).
#'
#' Convention: the values table's `metric_id` IS the canonical QuestionCode, so
#' match_key = tracking_norm(metric_id) aligns with the current wave (which keys
#' by tracking_norm(mapping$QuestionCode)). The mapping is joined by
#' QuestionCode == metric_id for the display title and the proportion category.
#'
#' @param values A data frame, one row per (metric, wave): columns metric_id,
#'   wave, metric_type (mean|proportion|nps), value, and optional base, sd — the
#'   shape load_aggregate_values() emits in `$values`. Assumed already validated
#'   (unique metric/wave keys, numeric value); this function does not re-validate
#'   ranges, only the presence of required columns.
#' @param mapping Optional QuestionMap body (from load_question_mapping()): supplies
#'   each metric's title (QuestionText) and, for proportions, the tracked category
#'   (TrackingSpecs `category:<value>`). Without it, titles fall back to metric_id
#'   and proportion metrics are skipped (no category to key their row on).
#' @param waves_meta Optional list of the waves to emit, oldest first; each
#'   list(id = <values `wave` value>, label = <display label>, year = <numeric
#'   order key>). When NULL, derived from the distinct waves in `values`.
#'
#' @return A list of wave contributions (each `current = FALSE`), each
#'   \item{wave}{display label}
#'   \item{year}{numeric order key (or NA)}
#'   \item{current}{FALSE}
#'   \item{segments}{empty list (aggregate history is Total-only)}
#'   \item{questions}{array of mean/nps `{match_key,title,base,stats}` or
#'     proportion `{match_key,title,base,rows}`}
#'   Returns an empty `list()` when nothing emits.
#'
#' @export
aggregate_wave_contributions <- function(values, mapping = NULL, waves_meta = NULL) {
  if (!is.data.frame(values) || nrow(values) == 0) return(list())
  need <- c("metric_id", "wave", "metric_type", "value")
  miss <- setdiff(need, names(values))
  if (length(miss) > 0) {
    cat(sprintf(
      "[TURAS WARNING] Aggregate bridge: values table missing required column(s): %s — nothing emitted.\n",
      paste(miss, collapse = ", ")))
    return(list())
  }

  metric_id   <- trimws(as.character(values$metric_id))
  wave_col    <- trimws(as.character(values$wave))
  metric_type <- tolower(trimws(as.character(values$metric_type)))
  metric_type[metric_type == "proportions"] <- "proportion"
  value       <- suppressWarnings(as.numeric(values$value))
  base_v <- if ("base" %in% names(values)) suppressWarnings(as.numeric(values$base)) else rep(NA_real_, nrow(values))
  sd_v   <- if ("sd"   %in% names(values)) suppressWarnings(as.numeric(values$sd))   else rep(NA_real_, nrow(values))

  lut <- .awb_mapping_lookup(mapping)
  if (is.null(waves_meta) || length(waves_meta) == 0) {
    waves_meta <- .awb_default_waves_meta(wave_col)
  }

  out_waves <- list()
  for (wm in waves_meta) {
    wid <- trimws(as.character(wm$id %||% ""))
    if (!nzchar(wid)) next
    idx <- which(wave_col == wid)
    if (length(idx) == 0) next

    questions <- list()
    for (i in idx) {
      mid   <- metric_id[i]
      mtype <- metric_type[i]
      v     <- value[i]
      if (is.na(v)) next                                   # no figure -> no point
      base_out <- if (is.na(base_v[i])) NA_real_ else as.numeric(base_v[i])

      info  <- lut[[mid]]
      title <- info$title %||% NA_character_
      if (is.na(title) || !nzchar(title)) title <- mid
      mkey  <- tracking_norm(mid)                          # metric_id == canonical code

      if (identical(mtype, "mean")) {
        # mean: the renderer reads stats.index; carry .mean too (either label
        # resolves) and .sd only when recorded (else the trend plots untested).
        stats <- list(mean = v, index = v)
        if (!is.na(sd_v[i])) stats$sd <- as.numeric(sd_v[i])
        q <- list(match_key = mkey, title = title, base = base_out, stats = stats)

      } else if (identical(mtype, "nps")) {
        # nps: net only; no sd, no index -> "no test" by construction.
        q <- list(match_key = mkey, title = title, base = base_out,
                  stats = list(nps = v))

      } else if (identical(mtype, "proportion")) {
        cat_val <- info$category %||% NA_character_
        if (is.na(cat_val)) {
          cat(sprintf(
            "[TURAS WARNING] Aggregate bridge: proportion metric '%s' has no TrackingSpecs category (category:<value>); skipped — cannot key its row.\n",
            mid))
          next
        }
        row <- list(pct = v)
        if (!is.na(base_out)) row$n <- round(v / 100 * base_out)  # count only when base known
        rows <- list()
        rows[[tracking_norm(cat_val)]] <- row
        q <- list(match_key = mkey, title = title, base = base_out, rows = rows)

      } else {
        next                                               # unknown type -> skip
      }
      questions[[length(questions) + 1]] <- q
    }

    if (length(questions) == 0) next
    out_waves[[length(out_waves) + 1]] <- list(
      wave      = as.character(wm$label %||% wid),
      year      = wm$year,
      current   = FALSE,
      segments  = list(),
      questions = questions)
  }

  # Oldest-first by year (NA keys keep input order, last). Cosmetic — the island
  # assembler re-sorts — but keeps the emitted list tidy for inspection.
  if (length(out_waves) > 1) {
    keys <- vapply(out_waves, function(w) {
      y <- suppressWarnings(as.numeric(w$year))
      if (length(y) != 1 || is.na(y)) Inf else y
    }, numeric(1))
    out_waves <- out_waves[order(keys)]
  }
  out_waves
}


#' Generate and write aggregate prior-wave sidecars (*_wave.json) to a folder
#'
#' Thin convenience over aggregate_wave_contributions() + write_wave_contribution():
#' one `<safe wave label>_wave.json` per emitted wave, ready for the live run to
#' read from its `waves_source`. This is the aggregate twin of the per-wave sidecar
#' each live tabs run writes.
#'
#' @param values,mapping,waves_meta As for aggregate_wave_contributions().
#' @param output_dir Destination folder (created if absent).
#' @param prefix Optional filename prefix (default "").
#' @return The paths written (invisibly), a character vector (possibly empty).
#'
#' @export
write_aggregate_wave_sidecars <- function(values, mapping = NULL, waves_meta = NULL,
                                          output_dir, prefix = "") {
  if (missing(output_dir) || is.null(output_dir) || !nzchar(as.character(output_dir))) {
    cat("[TURAS WARNING] Aggregate bridge: no output_dir given; nothing written.\n")
    return(invisible(character(0)))
  }
  contribs <- aggregate_wave_contributions(values, mapping, waves_meta)
  if (length(contribs) == 0) {
    cat("[TURAS WARNING] Aggregate bridge: no wave contributions to write (nothing emitted).\n")
    return(invisible(character(0)))
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  paths <- character(0)
  for (w in contribs) {
    safe <- gsub("[^A-Za-z0-9_-]+", "_", as.character(w$wave %||% "wave"))
    p <- file.path(output_dir, paste0(prefix, safe, "_wave.json"))
    written <- write_wave_contribution(w, p)
    if (!is.null(written)) paths <- c(paths, p)
  }
  invisible(paths)
}
