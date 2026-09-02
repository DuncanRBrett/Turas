# ==============================================================================
# TABS. TRACKING ISLAND ASSEMBLER (V11, data-centric report v2, OPTION 3)
# ==============================================================================
# Assembles the `data-prev` tracking island (TR.PREV) the v2 renderer's wave
# engine (assets/js/22w_waves.js) reads to light up the Tracking tab. The model
# is anonymised per-wave microdata: each wave carries, per tracked metric, the
# per-respondent SCORES (the rating for means; +-100/0 for NPS): the renderer
# recomputes each wave's value + dispersion from them, so nothing is pre-baked
# and significance is recomputed the same way as the live (current) wave.
#
# Island shape (verified against 22w_waves.js + the proven CCS spike island):
#   { schema_version: 1, kind: "tracking_microdata",
#     waves: [ { wave, year, current, segments: [],
#                questions: [ { match_key, title, base, score_type, scores } ] } ] }
#   match_key = the renderer's model.norm(title): how each wave question is
#   matched to the current (AGG) question. The current wave is flagged.
#
# FORWARD PATH: each wave's own tabs run writes a *_wave.json contribution
# (write_wave_contribution); the latest wave's run reads the prior waves'
# contributions from `waves_source` and assembles them with its own. No prior
# pipeline is re-run. CCS history was a one-time backfill (kept out of the repo).
#
# SCOPE (documented): scores carry MEAN-kind metrics (rating/Likert/NPS). The
# wave mean is unweighted (meanOfScores): weighted trackers are a documented
# follow-up (carry per-wave weights + weight meanOfScores). Proportion / NET
# tracking over waves (per-wave distributions) is likewise a future extension.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}


#' Normalise a title for cross-wave matching (mirrors the renderer's model.norm)
#'
#' @param text A question title
#' @return Lower-cased, whitespace-collapsed, punctuation-stripped key
#' @export
tracking_norm <- function(text) {
  x <- tolower(trimws(as.character(text %||% "")))
  x <- gsub("\\s+", " ", x)
  x <- gsub("[^a-z0-9 ]", "", x)
  trimws(x)
}


#' Numeric x-axis order key for a wave
#'
#' Uses config wave_order when set (e.g. 2025.5 so two same-year waves never
#' collide on the trend axis); else derives a 4-digit year from the wave label;
#' else NA (assembly then keeps input order).
#'
#' @param config_obj The tabs config object
#' @return Numeric order key, or NA
#' @export
wave_order_key <- function(config_obj) {
  wo <- config_obj$wave_order
  if (!is.null(wo) && nzchar(as.character(wo))) {
    n <- suppressWarnings(as.numeric(wo))
    if (!is.na(n)) return(n)
  }
  lbl <- as.character(config_obj$wave %||% "")
  m <- regmatches(lbl, regexpr("(19|20)\\d{2}", lbl))
  if (length(m) == 1) return(as.numeric(m))
  NA_real_
}


#' Load a classic-tracker Question_Mapping workbook (the curated link)
#'
#' Reads the "QuestionMap" sheet (the classic tracker's format): one row per
#' tracked metric with a canonical QuestionCode (the stable cross-wave key),
#' per-wave question codes (Wave22..Wave25, the rename map), and TrackingSpecs
#' (mean / nps_score). Returns the body data frame, or NULL when absent/unusable.
#'
#' @param path Path to the Question_Mapping workbook
#' @return Data frame of tracked metrics, or NULL
#' @export
load_question_mapping <- function(path) {
  if (is.null(path) || !nzchar(as.character(path)) || !file.exists(path)) return(NULL)
  if (!requireNamespace("openxlsx", quietly = TRUE)) return(NULL)
  sheets <- tryCatch(openxlsx::getSheetNames(path), error = function(e) character(0))
  sheet <- if ("QuestionMap" %in% sheets) "QuestionMap" else sheets[1]
  raw <- tryCatch(openxlsx::read.xlsx(path, sheet = sheet, colNames = FALSE),
                  error = function(e) NULL)
  if (is.null(raw) || nrow(raw) == 0) return(NULL)
  hrow <- which(raw[[1]] == "QuestionCode")[1]
  if (is.na(hrow)) return(NULL)
  names(raw) <- as.character(unlist(raw[hrow, ]))
  body <- raw[(hrow + 1):nrow(raw), , drop = FALSE]
  body <- body[!is.na(body$QuestionCode) & grepl("^[A-Za-z]", body$QuestionCode) &
               !grepl("^\\[", body$QuestionCode), , drop = FALSE]
  if (nrow(body) == 0 || !("QuestionCode" %in% names(body))) return(NULL)
  body
}


#' Detect which mapping wave-column matches the current data layer
#'
#' The current wave is the Wave* column whose question codes best match the
#' questions present in this run's data layer (so no per-wave config is needed).
#'
#' @param mapping A Question_Mapping body (from load_question_mapping)
#' @param data_layer The built data layer
#' @return The matching column name (e.g. "Wave25"), or NULL
#' @export
detect_wave_column <- function(mapping, data_layer) {
  wave_cols <- grep("^Wave", names(mapping), value = TRUE)
  if (length(wave_cols) == 0) return(NULL)
  dl_codes <- vapply(data_layer$questions, function(q) as.character(q$code), character(1))
  hits <- vapply(wave_cols, function(wc) {
    # trimws to match tracking_metrics(): detection and use must agree on what
    # a cell says, or a whitespace-padded column detects as the current wave
    # and then contributes nothing (I-7).
    sum(trimws(as.character(mapping[[wc]])) %in% dl_codes, na.rm = TRUE)
  }, integer(1))
  if (max(hits) == 0) return(NULL)
  # which.max() silently takes the FIRST column on a tie, so two waves whose
  # mapping columns match this data equally well resolved to whichever happened
  # to be leftmost, and every metric then keyed off the wrong wave without a
  # word (review 2026-08, M14). A tie is a real ambiguity in the mapping: say so.
  tied <- wave_cols[hits == max(hits)]
  if (length(tied) > 1) {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: Tabs tracking, ambiguous wave column\n")
    cat(sprintf("│ %d Question_Mapping wave columns match this data equally\n", length(tied)))
    cat(sprintf("│ well (%d of %d question codes each): %s\n",
                max(hits), length(dl_codes), paste(tied, collapse = ", ")))
    cat(sprintf("│ Using '%s'. The leftmost. If that is the wrong wave,\n", tied[1]))
    cat("│ every tracked metric is keyed off the wrong column.\n")
    cat("│ How to fix: make each wave column list only ITS wave's\n")
    cat("│ question codes, so exactly one column matches this run.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
  }
  tied[1]
}


#' The tracked metrics for this wave: {code, key, title, score_type}
#'
#' With a mapping: the curated metrics, keyed by the canonical QuestionCode
#' (stable across renames), resolved to this wave's question code. Without one:
#' every question carrying a mean, keyed by normalised title (the quick view).
#'
#' @param data_layer The built data layer
#' @param mapping Optional Question_Mapping body
#' @return A list of metric descriptors
#' @export
tracking_metrics <- function(data_layer, mapping = NULL) {
  dl_codes <- vapply(data_layer$questions, function(q) as.character(q$code), character(1))
  if (!is.null(mapping)) {
    wc <- detect_wave_column(mapping, data_layer)
    if (!is.null(wc)) {
      out <- list()
      unmatched <- character(0)
      for (i in seq_len(nrow(mapping))) {
        # trimws: an Excel-authored cell holding "Q1 " matched nothing and the
        # row was skipped in silence, so the metric simply stopped appearing in
        # the Tracking tab, which reads as "not tracked", not "broken mapping".
        # The pairing report cannot catch it either, because it counts only the
        # metrics this wave contributes (review 2026-08-21, I-7).
        code <- trimws(as.character(mapping[[wc]][i]))
        if (is.na(code) || !nzchar(code)) next
        if (!(code %in% dl_codes)) {
          unmatched <- c(unmatched, code)
          next
        }
        spec <- tolower(as.character(mapping$TrackingSpecs[i] %||% ""))
        out[[length(out) + 1]] <- list(
          code = code,
          key = tracking_norm(mapping$QuestionCode[i]),
          title = as.character(mapping$QuestionText[i] %||% mapping$QuestionCode[i]),
          score_type = if (grepl("nps", spec)) "nps" else "mean")
      }
      if (length(unmatched) > 0) {
        cat("\n┌─── TURAS TRACKING WARNING ─────────────────────────────────┐\n")
        cat("│ Question_Mapping column '", wc, "' names ", length(unmatched),
            " question code(s)\n", sep = "")
        cat("│ that are not in this run's data layer, so they are NOT tracked:\n")
        cat("│  ", paste(unmatched, collapse = ", "), "\n", sep = "")
        cat("│ Check the spelling against Survey_Structure (a composite uses its\n")
        cat("│ CompositeCode). These metrics will be missing from the Tracking tab.\n")
        cat("└────────────────────────────────────────────────────────────┘\n\n")
      }
      if (length(out) > 0) return(out)
    }
  }
  # No mapping: list every question; wave_contribution keeps only those that
  # actually carry microdata scores (which only mean-kind questions do).
  # Duplicate normalised titles get an occurrence suffix (t, t#1, t#2, ...)
  # mirroring the renderer's ensureIndexes (22w_waves.js) and extract_waves.py,
  # an unsuffixed duplicate key made two questions collide in the wave index
  # and one silently showed the other's trend.
  #
  # The suffix is ordered by question CODE, not by position in the data layer.
  # It used to be positional, so moving two same-titled questions past each other
  # between waves handed each the other's key, and with it, the other's history
  # (review 2026-08, M14). Codes are stable across a reorder; positions are not.
  # INSERTING a new same-titled question whose code sorts earlier still shifts
  # the suffixes, which is why the warning points at question_mapping: a
  # canonical key is the only way to track duplicate titles reliably.
  titles <- vapply(data_layer$questions, function(q) tracking_norm(q$title), character(1))
  codes <- vapply(data_layer$questions, function(q) as.character(q$code), character(1))
  suffix <- integer(length(titles))
  for (t in unique(titles)) {
    idx <- which(titles == t)
    if (length(idx) < 2L) next
    idx <- idx[order(codes[idx])]
    suffix[idx] <- seq_along(idx) - 1L
    cat(sprintf(
      "  [WARNING] Tracking: %d questions share the normalised title '%s' (%s): keyed '%s' then '%s' by question code to keep their trends separate. Set 'question_mapping' to track them by a canonical key instead.\n",
      length(idx), t, paste(codes[idx], collapse = ", "), t,
      paste(sprintf("%s#%d", t, seq_len(length(idx) - 1L)), collapse = ", ")))
  }

  out <- list()
  for (i in seq_along(data_layer$questions)) {
    q <- data_layer$questions[[i]]
    key <- if (suffix[i] == 0L) titles[i] else paste0(titles[i], "#", suffix[i])
    out[[length(out) + 1]] <- list(code = codes[i],
      key = key, title = as.character(q$title),
      score_type = if (identical(q$type, "nps")) "nps" else "mean")
  }
  out
}


#' Build this wave's tracking contribution from its data layer + microdata
#'
#' One entry per tracked metric that carries microdata scores: the per-respondent
#' scores (NA dropped) and their weights, keyed by the canonical metric key (from
#' the mapping) or the normalised title. Carries each question's own code so the
#' wave engine can link it to history by the canonical key.
#'
#' @param data_layer The built data layer (for codes + titles + types)
#' @param micro The TR.MICRO payload (for $scores, $weights)
#' @param config_obj The tabs config (for wave label + order key)
#' @param mapping Optional Question_Mapping body (the curated cross-wave link)
#' @return A wave contribution list, or NULL when no metric carries scores
#' @export
wave_contribution <- function(data_layer, micro, config_obj, mapping = NULL) {
  if (is.null(micro) || is.null(micro$scores)) return(NULL)
  weights <- if (!is.null(micro$weights)) as.numeric(micro$weights) else rep(1, micro$n %||% 0)
  metrics <- tracking_metrics(data_layer, mapping)
  questions <- list()
  for (mt in metrics) {
    sc <- micro$scores[[mt$code]]
    if (is.null(sc)) next
    sc <- as.numeric(sc)
    keep <- !is.na(sc)
    if (!any(keep)) next
    qw <- weights[keep]
    questions[[length(questions) + 1]] <- list(
      code       = mt$code,
      match_key  = mt$key,
      title      = mt$title,
      base       = sum(keep),
      score_type = mt$score_type,
      scores     = as.list(round(sc[keep], 4)),
      # weights omitted (-> unweighted reducer) when every weight is 1
      weights    = if (all(qw == 1)) NULL else as.list(round(qw, 6)))
  }
  if (length(questions) == 0) return(NULL)
  list(
    wave     = as.character(config_obj$wave %||% ""),
    year     = wave_order_key(config_obj),
    segments = list(),
    questions = questions
  )
}


#' Does a data-layer question publish a mean?
#'
#' The gate the microdata path applies implicitly: only a question carrying a
#' mean row gets per-respondent scores (micro_scores_for_question), so only such
#' a question can contribute a mean-kind metric to a wave.
#'
#' @param dl_q One built data-layer question
#' @return TRUE when the question has a row of kind "mean"
#' @keywords internal
tracking_has_mean_row <- function(dl_q) {
  rows <- dl_q$rows %||% list()
  if (!length(rows)) return(FALSE)
  any(vapply(rows, function(r) identical(r$kind, "mean"), logical(1)))
}


#' A data-layer question's published Total base
#'
#' @param dl_q One built data-layer question
#' @return The first column's unweighted base, or NA_real_
#' @keywords internal
tracking_total_base <- function(dl_q) {
  b <- tryCatch(dl_q$bases[[1]]$n, error = function(e) NULL)
  if (is.null(b) || length(b) != 1) return(NA_real_)
  suppressWarnings(as.numeric(b))
}


#' Build this wave's tracking contribution from PUBLISHED figures only
#'
#' The confidentiality build (`html_report_v2_microdata = FALSE`) ships no
#' per-respondent records, so `wave_contribution()` has no scores to work from,
#' and the Tracking tab used to be lost along with them, which put anonymity and
#' a trend line in competition. They are not in competition: the renderer needs
#' the current wave only to know WHICH metrics track and what their cross-wave
#' keys are, and it already reads the current point off the published figures
#' when no scores are present (`waves.currentPoint()` returns null and both its
#' callers fall back to the published cell, 22w_waves.js / 27t_tracking.js). The
#' current wave's SD for the Welch test comes from `sdFromModel()`, derived from
#' the published category distribution, so wave-on-wave significance still runs.
#' The one honest degrade: a question that publishes only its mean (every category
#' hidden) has no distribution to take a spread from, so it plots untested where
#' the microdata build would have tested it off the scores.
#'
#' This therefore emits the same contribution shape as `wave_contribution()`
#' minus `scores`/`weights`: nothing in it describes an individual.
#'
#' The metric set is deliberately the same one the microdata build of this same
#' wave would produce, mean-kind metrics only, so the confidential copy and the
#' analyst's own copy show the same trend. (The mirror is the mean-row gate;
#' `micro_scores_for_question()` also requires a Rating/Likert/NPS/Numeric
#' variable type, so a categorical question that publishes a mean would appear
#' here and not there. It would simply pair with no history and be reported as
#' unmatched.)
#'
#' @param data_layer The built data layer (for codes, titles, rows, bases)
#' @param config_obj The tabs config (for wave label + order key)
#' @param mapping Optional Question_Mapping body (the curated cross-wave link)
#' @return A wave contribution list, or NULL when no metric publishes a mean
#' @export
published_wave_contribution <- function(data_layer, config_obj, mapping = NULL) {
  metrics <- tracking_metrics(data_layer, mapping)
  if (!length(metrics)) return(NULL)

  by_code <- list()
  for (q in data_layer$questions) by_code[[as.character(q$code)]] <- q

  questions <- list()
  for (mt in metrics) {
    q <- by_code[[as.character(mt$code)]]
    if (is.null(q) || !tracking_has_mean_row(q)) next
    questions[[length(questions) + 1]] <- list(
      code       = mt$code,
      match_key  = mt$key,
      title      = mt$title,
      base       = tracking_total_base(q),
      score_type = mt$score_type)
  }
  if (length(questions) == 0) return(NULL)
  list(
    wave     = as.character(config_obj$wave %||% ""),
    year     = wave_order_key(config_obj),
    segments = list(),
    questions = questions
  )
}


#' Assemble the tracking island from the current + prior wave contributions
#'
#' The current contribution is flagged `current` (its scores drive the live
#' point's dispersion); priors are history. Waves are ordered by their numeric
#' year key (NA-keyed waves keep their input order, last).
#'
#' @param current_contribution This wave's contribution (from wave_contribution)
#' @param prior_contributions List of prior waves' contributions
#' The cross-wave keys a contribution offers (match_key, title_norm fallback)
#'
#' @param w A wave contribution
#' @return Character vector of non-empty keys
#' @keywords internal
tracking_wave_keys <- function(w) {
  qs <- w$questions %||% list()
  if (!length(qs)) return(character(0))
  keys <- vapply(qs, function(q) {
    as.character(q$match_key %||% q$title_norm %||% "")[1]
  }, character(1))
  keys[!is.na(keys) & nzchar(keys)]
}


#' The option labels a live question offers for cross-wave row pairing
#'
#' The renderer resolves a prior wave's row by `TR.model.norm(label)` against
#' that wave's `rows` map (22w_waves.js rowValue), so these are the keys that
#' have to match. Category and NET rows only. Mean-kind rows pair at question
#' level, through the metric key.
#'
#' @param q A data-layer question
#' @return Character vector of normalised option labels
#' @keywords internal
tracking_option_labels <- function(q) {
  rows <- q$rows %||% list()
  if (!length(rows)) return(character(0))
  keep <- vapply(rows, function(r) {
    identical(r$kind, "category") || identical(r$kind, "net")
  }, logical(1))
  if (!any(keep)) return(character(0))
  labs <- vapply(rows[keep], function(r) tracking_norm(r$label), character(1))
  unique(labs[!is.na(labs) & nzchar(labs)])
}


#' Report how many of this wave's OPTION rows pair with the prior waves
#'
#' A proportion trend pairs row by row, on the normalised option label alone,
#' so renaming "Very satisfied" to "Extremely satisfied", or dropping a NET
#' member, silently truncates that row's trend. The question-level report below
#' cannot see it: it checks the mean/NPS metrics this wave contributes, and a
#' proportion trend contributes no metric at all. Nothing checked these, which
#' is why a renamed option read as "no movement" rather than "no comparison"
#' (review 2026-08, I24).
#'
#' Silent by design when no prior wave carries `rows`. A mean-only tracker has
#' no option pairing to report on.
#'
#' @param data_layer The built data layer (the live option labels)
#' @param priors The prior wave contributions
#' @param mapping Optional Question_Mapping body (same keying as tracking_metrics)
#' @param max_report Most questions to name individually before summarising
#' @return list(questions, checked, matched, unmatched), invisibly
#' @keywords internal
tracking_report_option_pairing <- function(data_layer, priors, mapping = NULL,
                                           max_report = 5L) {
  out <- list(questions = list(), checked = 0L, matched = 0L, unmatched = 0L)
  if (is.null(data_layer) || !length(data_layer$questions) || !length(priors)) {
    return(invisible(out))
  }

  # Every option row the history offers, per cross-wave key.
  prior_rows <- list()
  for (w in priors) {
    for (q in (w$questions %||% list())) {
      if (is.null(q$rows) || !length(q$rows)) next
      k <- as.character(q$match_key %||% q$title_norm %||% "")[1]
      if (is.na(k) || !nzchar(k)) next
      prior_rows[[k]] <- unique(c(prior_rows[[k]], names(q$rows)))
    }
  }
  if (!length(prior_rows)) return(invisible(out))   # no proportion history to pair against

  by_code <- list()
  for (q in data_layer$questions) by_code[[as.character(q$code)]] <- q

  for (mt in tracking_metrics(data_layer, mapping)) {
    have <- prior_rows[[mt$key]]
    if (is.null(have) || !length(have)) next
    q <- by_code[[as.character(mt$code)]]
    if (is.null(q)) next
    live <- tracking_option_labels(q)
    if (!length(live)) next
    miss <- setdiff(live, have)
    out$checked <- out$checked + length(live)
    out$matched <- out$matched + (length(live) - length(miss))
    out$unmatched <- out$unmatched + length(miss)
    if (length(miss)) {
      out$questions[[length(out$questions) + 1]] <- list(
        code = as.character(mt$code), title = as.character(mt$title),
        live = length(live), unmatched = miss)
    }
  }
  if (out$checked == 0L) return(invisible(out))

  if (out$unmatched == 0L) {
    cat(sprintf("  Tracking: all %d tracked option row(s) matched history.\n", out$checked))
    return(invisible(out))
  }

  shown <- utils::head(out$questions, max_report)
  for (h in shown) {
    labels <- utils::head(h$unmatched, 6L)
    more <- length(h$unmatched) - length(labels)
    cat(sprintf(
      "  [NOTE] Tracking: '%s', %d of %d option(s) found no prior wave row, so those trends are empty: %s%s\n",
      h$title, length(h$unmatched), h$live,
      paste(sprintf("\"%s\"", labels), collapse = ", "),
      if (more > 0) sprintf(" (+%d more)", more) else ""))
  }
  if (length(out$questions) > length(shown)) {
    cat(sprintf("  [NOTE] Tracking: %d further question(s) have unmatched option rows.\n",
                length(out$questions) - length(shown)))
  }
  # Every option of every question missing is the shape of a renamed scale or a
  # wave keyed a different way, not a handful of edits.
  if (out$matched == 0L) {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: Tabs tracking, no option row matched history\n")
    cat(sprintf("│ %d tracked option row(s) were checked and NONE pair with\n", out$checked))
    cat("│ a prior wave, so every proportion trend is empty. The\n")
    cat("│ Tracking tab will show no movement, which reads as 'nothing\n")
    cat("│ changed' when the truth is 'nothing was compared'.\n")
    cat("│ How to fix: option rows pair on the normalised label alone.\n")
    cat("│ Restore the prior wording, or rebuild the prior waves'\n")
    cat("│ sidecars from data that uses the current wording.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
  }
  invisible(out)
}


#' Report how many of this wave's metrics pair with the prior waves
#'
#' The cross-wave key changes SHAPE with the config: `tracking_metrics()` keys by
#' the canonical question code when a Question_Mapping is loaded, and by the
#' normalised title when one is not. A wave built under one regime can never pair
#' with history built under the other, and the Tracking tab renders that total
#' miss as a scorecard with no cards and "0 significant increases / 0 decreases /
#' 0 stable", which reads as "nothing moved this wave" when the truth is "nothing
#' was compared". So say it here, at build time, where the operator can see it.
#'
#' Only the metrics THIS wave contributes are checked (the mean/NPS kind that
#' carry scores): those are what the scorecard and the wave-on-wave counts are
#' built from.
#'
#' @param current_contribution This wave's contribution
#' @param priors The prior wave contributions (already de-duplicated)
#' @param data_layer Optional built data layer. Supplying it also checks the
#'   OPTION rows a proportion trend pairs on (see tracking_report_option_pairing)
#' @param mapping Optional Question_Mapping body, for the option-level check
#' @return list(current, priors, matched, unmatched, options), invisibly
#' @keywords internal
tracking_report_pairing <- function(current_contribution, priors,
                                    data_layer = NULL, mapping = NULL) {
  # Option rows first: they are checked even when this wave contributes no
  # mean/NPS metric at all, which is exactly the proportion-only tracker the
  # question-level report below has nothing to say about.
  opts <- tracking_report_option_pairing(data_layer, priors, mapping)
  cur_keys <- tracking_wave_keys(current_contribution)
  out <- list(current = length(cur_keys), priors = length(priors),
              matched = 0L, unmatched = length(cur_keys), options = opts)
  if (!length(priors) || !length(cur_keys)) return(invisible(out))

  prior_keys <- unique(unlist(lapply(priors, tracking_wave_keys), use.names = FALSE))
  out$matched <- sum(cur_keys %in% prior_keys)
  out$unmatched <- length(cur_keys) - out$matched

  if (out$matched == 0L) {
    shape <- function(keys) if (length(keys)) sprintf("\"%s\"", keys[1]) else "(none)"
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: Tabs tracking, no metric matched history\n")
    cat(sprintf("│ %d prior wave(s) loaded, but none of this wave's %d tracked\n",
                out$priors, out$current))
    cat("│ metrics share a cross-wave key with them, so every trend\n")
    cat("│ is empty and the Tracking tab has nothing to compare.\n")
    cat(sprintf("│ This wave keys by: %s\n", shape(cur_keys)))
    cat(sprintf("│ History keys by  : %s\n", shape(prior_keys)))
    cat("│ How to fix: set 'question_mapping' in the config to the\n")
    cat("│ tracker's Question_Mapping workbook, so this wave keys by\n")
    cat("│ the canonical question code the way the history does.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
  } else if (out$unmatched > 0L) {
    cat(sprintf(
      "  [NOTE] Tracking: %d of %d metrics matched history; %d found no prior wave.\n",
      out$matched, out$current, out$unmatched))
  } else {
    cat(sprintf("  Tracking: all %d metrics matched %d prior wave(s).\n",
                out$matched, out$priors))
  }
  invisible(out)
}


#' @param data_layer Optional built data layer, so the build-time pairing report
#'   can also check the option rows a proportion trend pairs on (I24)
#' @param mapping Optional Question_Mapping body, for that same check
#' @return A tracking-island list, or NULL when there is no current contribution
#' @export
build_tracking_island <- function(current_contribution, prior_contributions = list(),
                                  data_layer = NULL, mapping = NULL) {
  if (is.null(current_contribution)) return(NULL)
  current_contribution$current <- TRUE
  priors <- lapply(prior_contributions, function(w) {
    w$current <- FALSE
    w
  })
  priors <- priors[!vapply(priors, is.null, logical(1))]

  # A prior contribution with the CURRENT wave's label is a stale sidecar from
  # an earlier run of this same wave (e.g. a renamed/versioned re-run whose old
  # *_wave.json no longer matches exclude_path). Keeping it would make the
  # current wave compare against itself, masking the real wave-on-wave movement.
  cur_label <- as.character(current_contribution$wave %||% "")
  if (nzchar(cur_label)) {
    is_self <- vapply(priors, function(w) {
      identical(as.character(w$wave %||% ""), cur_label)
    }, logical(1))
    if (any(is_self)) {
      cat(sprintf(
        "  [NOTE] Tracking: skipped %d stale prior contribution(s) labelled '%s' (same wave as the current run).\n",
        sum(is_self), cur_label))
      priors <- priors[!is_self]
    }
  }

  # Loud when this wave pairs with nothing. An unmatched tracker renders as
  # zeros, which read as findings rather than as a missing comparison. With a
  # data layer the option rows a proportion trend pairs on are checked too.
  tracking_report_pairing(current_contribution, priors, data_layer, mapping)

  waves <- c(priors, list(current_contribution))

  keys <- vapply(waves, function(w) {
    y <- suppressWarnings(as.numeric(w$year))
    if (length(y) != 1 || is.na(y)) Inf else y
  }, numeric(1))

  # A wave with no derivable year (a label like "Baseline" carrying no 4-digit
  # year) sorts to Inf, i.e. AFTER the current wave, so the renderer treats it
  # as "the previous wave" for every delta chip, anchors vs-first on it, and
  # draws its point off the chart canvas because `year - y0` coerces null to 0.
  # It is never a usable comparison point, so drop it and say which one went
  # (review 2026-08-21, I-8).
  # The current wave is always kept (it is this run's own output); only priors
  # can be dropped, and a yearless CURRENT wave gets its own warning because the
  # whole trend then has no anchor.
  is_current <- seq_along(waves) == length(waves)
  drop_prior <- is.infinite(keys) & !is_current

  if (any(drop_prior)) {
    dropped <- vapply(waves[drop_prior],
                      function(w) as.character(w$wave %||% "(unlabelled)"), character(1))
    cat("\n┌─── TURAS TRACKING WARNING ─────────────────────────────────┐\n")
    cat("│ ", length(dropped), " prior wave(s) carry no year and cannot be placed on\n", sep = "")
    cat("│ a trend line, so they are EXCLUDED from tracking:\n")
    cat("│  ", paste(dropped, collapse = ", "), "\n", sep = "")
    cat("│ Left in, they sort after the current wave: every 'vs previous' delta\n")
    cat("│ would compare against them and their point would fall off the chart.\n")
    cat("│ Fix: label the wave with a 4-digit year (e.g. 'Baseline 2023'), or\n")
    cat("│ give it an explicit year via waves_meta / wave_order.\n")
    cat("└────────────────────────────────────────────────────────────┘\n\n")
    waves <- waves[!drop_prior]
    keys <- keys[!drop_prior]
  }
  if (any(is.infinite(keys))) {
    cat("\n  [WARNING] Tracking: the current wave ('",
        as.character(waves[[length(waves)]]$wave %||% "(unlabelled)"),
        "') carries no 4-digit year.\n", sep = "")
    cat("  Trend positions are derived from the year, so the chart may place it oddly.\n")
    cat("  Fix: include the year in the wave label, or set it via waves_meta.\n\n")
  }
  waves <- waves[order(keys)]

  list(schema_version = 1L, kind = "tracking_microdata", waves = waves)
}


#' Serialise a tracking island to the JSON island string
#'
#' @param island A list from build_tracking_island()
#' @return A JSON string, or "null" when island is NULL
#' @export
serialize_tracking_island <- function(island) {
  if (is.null(island)) return("null")
  jsonlite::toJSON(island, auto_unbox = TRUE, na = "null", null = "null",
                   digits = 6, pretty = FALSE)
}


#' Write this wave's tracking contribution sidecar (for future waves to read)
#'
#' @param contribution A wave contribution (from wave_contribution), or NULL
#' @param output_path Destination *_wave.json path
#' @return The path written (invisibly), or NULL
#' @export
write_wave_contribution <- function(contribution, output_path) {
  if (is.null(contribution)) return(invisible(NULL))
  if (!requireNamespace("jsonlite", quietly = TRUE)) return(invisible(NULL))
  # Provenance for the dedupe. read_wave_contributions used to resolve two
  # sidecars for the same wave by file mtime, but an mtime is when the file was
  # last COPIED, not when its numbers were produced, so dropping a stale backup
  # into waves_source made it beat the genuine newer run (review 2026-08, M14).
  # Stamped here, at the one moment that means "this sidecar was produced now".
  if (is.null(contribution$built)) {
    contribution$built <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  }
  json <- jsonlite::toJSON(contribution, auto_unbox = TRUE, na = "null",
                           null = "null", digits = 6, pretty = FALSE)
  written <- tryCatch({
    writeLines(json, output_path, useBytes = TRUE)
    TRUE
  }, error = function(e) FALSE)
  if (!written) return(invisible(NULL))
  cat(sprintf("  Wave contribution: %s\n", basename(output_path)))
  invisible(output_path)
}


#' Read prior waves' tracking contributions from a source folder
#'
#' Reads every *_wave.json under `waves_source` (skipping the current run's own
#' file when given). Malformed files are skipped with a warning. When two
#' sidecars carry the SAME wave label (a re-run of a wave under a different
#' output filename left its stale sidecar behind), only the newest is kept,
#' otherwise the duplicate would enter the island as extra "history".
#'
#' "Newest" is the sidecar's own recorded `built` stamp, not the file's mtime:
#' an mtime is when the file was last copied, so a stale backup dropped into the
#' folder used to outrank the genuine newer run (review 2026-08, M14). Sidecars
#' written before the stamp existed fall back to mtime, and the dedupe note says
#' which rule decided.
#'
#' @param waves_source Folder containing prior *_wave.json contributions
#' @param exclude_path Optional path to skip (this run's own contribution)
#' @return A list of prior contributions (possibly empty)
#' @export
read_wave_contributions <- function(waves_source, exclude_path = NULL) {
  if (is.null(waves_source) || !nzchar(as.character(waves_source)) ||
      !dir.exists(waves_source)) {
    return(list())
  }
  files <- list.files(waves_source, pattern = "_wave\\.json$", full.names = TRUE)
  if (!is.null(exclude_path)) {
    files <- files[normalizePath(files, mustWork = FALSE) !=
                   normalizePath(exclude_path, mustWork = FALSE)]
  }

  # Read first, then order. The ordering key lives INSIDE the file.
  recs <- list()
  for (f in files) {
    c <- tryCatch(jsonlite::read_json(f, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(c) || is.null(c$questions)) {
      cat(sprintf("  [WARNING] Skipped unreadable wave contribution: %s\n", basename(f)))
      next
    }
    stamp <- suppressWarnings(as.POSIXct(as.character(c$built %||% NA_character_),
                                         format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"))
    stamped <- length(stamp) == 1 && !is.na(stamp)
    recs[[length(recs) + 1]] <- list(
      contrib = c, file = f, stamped = stamped,
      when = if (stamped) stamp else as.POSIXct(file.mtime(f), tz = "UTC"))
  }
  if (length(recs) > 1) {
    recs <- recs[order(vapply(recs, function(r) as.numeric(r$when), numeric(1)),
                       decreasing = TRUE)]
  }

  out <- list()
  seen_labels <- character(0)
  for (r in recs) {
    c <- r$contrib
    lbl <- as.character(c$wave %||% "")
    if (nzchar(lbl) && lbl %in% seen_labels) {
      cat(sprintf(
        "  [NOTE] Tracking: skipped stale duplicate of wave '%s' (%s): a newer sidecar for that wave was kept (by %s).\n",
        lbl, basename(r$file),
        if (r$stamped) "recorded build time" else "file date, which a copy resets"))
      next
    }
    if (nzchar(lbl)) seen_labels <- c(seen_labels, lbl)
    out[[length(out) + 1]] <- c
  }
  out
}
