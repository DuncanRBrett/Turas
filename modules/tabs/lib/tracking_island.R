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


#' Build this wave's tracking contribution from its data layer + microdata
#'
#' One entry per mean-kind metric (rating/Likert/NPS) that carries microdata
#' scores: the per-respondent scores (NA dropped), matched by normalised title.
#'
#' @param data_layer The built data layer (for titles + types)
#' @param micro The TR.MICRO payload (for $scores)
#' @param config_obj The tabs config (for wave label + order key)
#' @return A wave contribution list, or NULL when no metric carries scores
#' @export
wave_contribution <- function(data_layer, micro, config_obj) {
  if (is.null(micro) || is.null(micro$scores)) return(NULL)
  questions <- list()
  for (q in data_layer$questions) {
    sc <- micro$scores[[q$code]]
    if (is.null(sc)) next
    sc <- as.numeric(sc)
    keep <- !is.na(sc)
    if (!any(keep)) next
    questions[[length(questions) + 1]] <- list(
      match_key  = tracking_norm(q$title),
      title      = as.character(q$title),
      base       = sum(keep),
      score_type = if (identical(q$type, "nps")) "nps" else "mean",
      scores     = as.list(round(sc[keep], 4))
    )
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
  priors <- lapply(prior_contributions, function(w) { w$current <- FALSE; w })
  priors <- priors[!vapply(priors, is.null, logical(1))]
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
  written <- tryCatch({ writeLines(json, output_path, useBytes = TRUE); TRUE },
                      error = function(e) FALSE)
  if (!written) return(invisible(NULL))
  cat(sprintf("  Wave contribution: %s\n", basename(output_path)))
  invisible(output_path)
}


#' Read prior waves' tracking contributions from a source folder
#'
#' Reads every *_wave.json under `waves_source` (skipping the current run's own
#' file when given). Malformed files are skipped with a warning.
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
  out <- lapply(files, function(f) {
    c <- tryCatch(jsonlite::read_json(f, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(c) || is.null(c$questions)) {
      cat(sprintf("  [WARNING] Skipped unreadable wave contribution: %s\n", basename(f)))
      return(NULL)
    }
    c
  })
  out[!vapply(out, is.null, logical(1))]
}
