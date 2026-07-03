# ==============================================================================
# TABS — TRACKING ISLAND ASSEMBLER (V11, data-centric report v2, OPTION 3)
# ==============================================================================
# Assembles the `data-prev` tracking island (TR.PREV) the v2 renderer's wave
# engine (assets/js/22w_waves.js) reads to light up the Tracking tab. The model
# is anonymised per-wave microdata: each wave carries, per tracked metric, the
# per-respondent SCORES (the rating for means; +-100/0 for NPS) — the renderer
# recomputes each wave's value + dispersion from them, so nothing is pre-baked
# and significance is recomputed the same way as the live (current) wave.
#
# Island shape (verified against 22w_waves.js + the proven CCS spike island):
#   { schema_version: 1, kind: "tracking_microdata",
#     waves: [ { wave, year, current, segments: [],
#                questions: [ { match_key, title, base, score_type, scores } ] } ] }
#   match_key = the renderer's model.norm(title) — how each wave question is
#   matched to the current (AGG) question. The current wave is flagged.
#
# FORWARD PATH: each wave's own tabs run writes a *_wave.json contribution
# (write_wave_contribution); the latest wave's run reads the prior waves'
# contributions from `waves_source` and assembles them with its own. No prior
# pipeline is re-run. CCS history was a one-time backfill (kept out of the repo).
#
# SCOPE (documented): scores carry MEAN-kind metrics (rating/Likert/NPS). The
# wave mean is unweighted (meanOfScores) — weighted trackers are a documented
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
    sum(as.character(mapping[[wc]]) %in% dl_codes, na.rm = TRUE)
  }, integer(1))
  if (max(hits) == 0) return(NULL)
  wave_cols[which.max(hits)]
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
      for (i in seq_len(nrow(mapping))) {
        code <- as.character(mapping[[wc]][i])
        if (is.na(code) || !(code %in% dl_codes)) next
        spec <- tolower(as.character(mapping$TrackingSpecs[i] %||% ""))
        out[[length(out) + 1]] <- list(
          code = code,
          key = tracking_norm(mapping$QuestionCode[i]),
          title = as.character(mapping$QuestionText[i] %||% mapping$QuestionCode[i]),
          score_type = if (grepl("nps", spec)) "nps" else "mean")
      }
      if (length(out) > 0) return(out)
    }
  }
  # No mapping: list every question; wave_contribution keeps only those that
  # actually carry microdata scores (which only mean-kind questions do).
  # Duplicate normalised titles get an occurrence suffix (t, t#1, t#2, ...)
  # mirroring the renderer's ensureIndexes (22w_waves.js) and extract_waves.py —
  # an unsuffixed duplicate key made two questions collide in the wave index
  # and one silently showed the other's trend.
  out <- list()
  seen <- list()
  for (q in data_layer$questions) {
    key <- tracking_norm(q$title)
    seen_key <- paste0("k:", key)   # prefixed: a blank title can't defeat the lookup
    k <- seen[[seen_key]] %||% 0L
    seen[[seen_key]] <- k + 1L
    if (k > 0L) {
      cat(sprintf(
        "  [WARNING] Tracking: duplicate normalised question title '%s' (question %s) — keyed as '%s#%d' to keep trends separate.\n",
        key, as.character(q$code), key, k))
      key <- paste0(key, "#", k)
    }
    out[[length(out) + 1]] <- list(code = as.character(q$code),
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


#' Assemble the tracking island from the current + prior wave contributions
#'
#' The current contribution is flagged `current` (its scores drive the live
#' point's dispersion); priors are history. Waves are ordered by their numeric
#' year key (NA-keyed waves keep their input order, last).
#'
#' @param current_contribution This wave's contribution (from wave_contribution)
#' @param prior_contributions List of prior waves' contributions
#' @return A tracking-island list, or NULL when there is no current contribution
#' @export
build_tracking_island <- function(current_contribution, prior_contributions = list()) {
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

  waves <- c(priors, list(current_contribution))

  keys <- vapply(waves, function(w) {
    y <- suppressWarnings(as.numeric(w$year))
    if (length(y) != 1 || is.na(y)) Inf else y
  }, numeric(1))
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
#' output filename left its stale sidecar behind), only the newest file is
#' kept — otherwise the duplicate would enter the island as extra "history".
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
  # Newest first, so the first contribution seen per wave label wins the dedupe.
  if (length(files) > 1) {
    files <- files[order(file.mtime(files), decreasing = TRUE)]
  }
  out <- list()
  seen_labels <- character(0)
  for (f in files) {
    c <- tryCatch(jsonlite::read_json(f, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(c) || is.null(c$questions)) {
      cat(sprintf("  [WARNING] Skipped unreadable wave contribution: %s\n", basename(f)))
      next
    }
    lbl <- as.character(c$wave %||% "")
    if (nzchar(lbl) && lbl %in% seen_labels) {
      cat(sprintf(
        "  [NOTE] Tracking: skipped stale duplicate of wave '%s' (%s) — a newer sidecar for that wave was kept.\n",
        lbl, basename(f)))
      next
    }
    if (nzchar(lbl)) seen_labels <- c(seen_labels, lbl)
    out[[length(out) + 1]] <- c
  }
  out
}
