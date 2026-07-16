# ==============================================================================
# TABS — READER REPORT: AI PROSE PATH (V15, OPT-IN)
# ==============================================================================
# The deterministic Reader builds the whole report — visuals, structure, the
# numbers, the honesty machinery — from the data layer. This module OPTIONALLY
# replaces the templated narrative (title, argument, verdict, leverage, limits)
# with prose drafted by a model, so the report reads like a considered document
# rather than a filled-in template.
#
# PRIVACY: the model is sent AGGREGATES ONLY — the derived figures the report
# already shows. Never the microdata, never verbatims. Every number the model
# writes is checked against those aggregates (deterministic_number_check); if it
# invents a figure, the AI prose is REJECTED and the deterministic prose stands.
# So the model phrases the numbers; it never generates one, and the report says
# so (disclosure mode = "ai" names the model).
#
# Enabled by config reader_ai_prose (off by default). Any failure — no key, no
# ellmer, a provider error, a failed number check — degrades silently to the
# deterministic prose. The report always builds.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Source the shared AI layer on demand (the data layer deliberately does not
# depend on it, so the provider/verify functions are not otherwise loaded here).
.reader_ensure_ai_layer <- function() {
  if (exists("call_insight_model", mode = "function") &&
      exists("deterministic_number_check", mode = "function")) return(TRUE)
  lib <- get0(".tabs_lib_dir", ifnotfound = file.path("modules", "tabs", "lib"))
  shared_ai <- file.path(dirname(dirname(lib)), "shared", "lib", "ai")
  # the prose-voice fragment is optional — its absence must not disable the layer
  voice_p <- file.path(shared_ai, "ai_voice.R")
  if (file.exists(voice_p)) source(voice_p, local = FALSE)
  ok <- TRUE
  for (f in c("ai_utils.R", "ai_provider.R", "ai_verify.R")) {
    p <- file.path(shared_ai, f)
    if (file.exists(p)) source(p, local = FALSE) else ok <- FALSE
  }
  ok && exists("call_insight_model", mode = "function")
}

#' The structured output the model returns — the narrative only. The numbers,
#' visuals and honesty machinery are the deterministic report's; the model fills
#' these fields and nothing else.
reader_prose_schema <- function() {
  ts <- ellmer::type_string
  leaf <- function() ellmer::type_object(
    "A titled paragraph.",
    lead = ts("A short bold lead-in phrase, e.g. 'Start with the good news.'"),
    body = ts("One to three plain sentences. Use only numbers from the supplied facts."))
  ellmer::type_object(
    "A reader-facing research narrative written from the supplied figures ONLY. Invent no number.",
    title    = ts("A short, specific report title. Evocative is fine; overwrought is not. No colon-subtitle."),
    subtitle = ts("One sentence capturing the through-line of the story."),
    claims   = ellmer::type_array(
      "The argument as 3 to 5 claims, in order, each defending a point. This is the spine — find the story, do not just restate the numbers.",
      items = leaf()),
    verdict  = ts("One paragraph: the point of view — what is really going on beneath the numbers."),
    leverage = ellmer::type_array(
      "2 to 4 ranked, specific actions, each tied to a named weak or falling item.",
      items = leaf()),
    limits   = ellmer::type_array(
      "2 to 3 honest limits — what this survey cannot tell you.",
      items = leaf()))
}

#' Aggregates-only facts for the model — the figures the report already shows.
#' Never microdata, never verbatims. Also the source-of-truth for the number
#' check, so anything the model cites must appear here.
#'
#' Fact-sheet v2 (§3.2 of READER_REPORT_AI_DESIGN): every fact carries a stable
#' `id` so a story-finding call can reference facts instead of restating them; a
#' `derived` pool holds figures the deterministic layer can compute that prose
#' will want to cite (NETs, gaps, counts, percent-of-scale) so citing one is not
#' a false reject; a `design` block grounds the limits prose (census vs sample,
#' population, waves, banner groups, low-base register). Still aggregates only.
reader_ai_facts <- function(model) {
  scale_max <- as.numeric(model$headline[[1]]$scaleMax %||% 5)
  pct_of_max <- function(v) {
    v <- suppressWarnings(as.numeric(v))
    if (length(v) != 1 || is.na(v) || is.na(scale_max) || scale_max <= 0) return(NULL)
    round(v / scale_max * 100)
  }
  hl <- lapply(seq_along(model$headline %||% list()), function(i) {
    h <- model$headline[[i]]
    list(id = if (nzchar(as.character(h$q %||% ""))) as.character(h$q) else paste0("H", i),
         measure = h$label, value = h$value, base = h$base,
         delta = h$delta, netPositive = h$netPositive, pctOfScale = pct_of_max(h$value))
  })
  it <- lapply(seq_along(model$items %||% list()), function(i) {
    x <- model$items[[i]]
    list(id = if (nzchar(as.character(x$code %||% ""))) as.character(x$code) else paste0("I", i),
         item = x$short, value = x$value, delta = x$delta, pctOfScale = pct_of_max(x$value))
  })
  vals <- if (isTRUE(model$values$available)) list(
    average = model$values$avg,
    livesMost = lapply(model$values$livesMost, function(v) list(value = v$label, score = v$value)),
    livesLeast = lapply(model$values$livesLeast, function(v) list(value = v$label, score = v$value))) else NULL
  ppl <- if (isTRUE(model$people$available)) list(
    group = model$people$groupName,
    lowest = list(label = model$people$lowest$label, base = model$people$lowest$base,
                  metrics = model$people$lowest$metrics),
    anchor = list(label = model$people$anchor$label, base = model$people$anchor$base,
                  average = model$people$anchor$avg)) else NULL

  # --- derived-numbers pool: figures prose legitimately cites but that are not
  #     verbatim in the raw model. Everything here is computed from the same
  #     aggregates and so passes the number check by construction (§3.6).
  item_vals <- suppressWarnings(as.numeric(vapply(model$items %||% list(),
    function(x) as.numeric(x$value %||% NA), numeric(1))))
  item_vals <- item_vals[!is.na(item_vals)]
  item_deltas <- suppressWarnings(as.numeric(vapply(model$items %||% list(),
    function(x) as.numeric(x$delta %||% NA), numeric(1))))
  n_tracked <- sum(!is.na(item_deltas))
  n_falling <- sum(!is.na(item_deltas) & item_deltas < 0)
  spread <- if (length(item_vals) >= 2) round(max(item_vals) - min(item_vals), 2) else NULL
  derived <- list(
    nItems = length(model$items %||% list()),
    nHeadline = length(model$headline %||% list()),
    nTracked = if (isTRUE(model$trend$available)) n_tracked else NULL,
    nFalling = if (isTRUE(model$trend$available)) n_falling else NULL,
    spread = spread)               # widest gap between the strongest and weakest item

  # --- study-design facts: ground the honesty / limits prose (§3.2).
  design <- list(
    censusOrSample = as.character(model$project$sampling_method %||% ""),
    population = model$project$population %||% NULL,
    lowBaseThreshold = model$project$low_base_threshold,
    tracked = isTRUE(model$trend$available),
    sinceYear = if (isTRUE(model$trend$available)) model$trend$refYear else NULL,
    lowBaseRegister = as.integer(length(model$register %||% list())))

  list(
    project = list(name = model$project$name, wave = model$project$wave,
                   sampling = model$project$sampling_method,
                   lowBaseThreshold = model$project$low_base_threshold),
    scaleMax = scale_max,
    trend = list(available = isTRUE(model$trend$available), sinceYear = model$trend$refYear),
    headline = hl, items = it, values = vals, people = ppl,
    derived = derived, design = design,
    itemsFalling = if (isTRUE(model$trend$available))
      lapply(model$splitSlipped %||% list(), function(x) list(item = x$short, value = x$value, delta = x$delta)) else NULL)
}

#' Years the prose may legitimately mention. The facts payload carries years as
#' labels (project name, wave, trend refYear), not as data values, so the
#' number check would reject "since 2023" or "the 2024 trough" as invented
#' figures. Collect every year named in the study identity and fill the span
#' between the earliest and latest, so intermediate wave years pass too.
.reader_year_pool <- function(facts) {
  strings <- c(facts$project$name, facts$project$wave)
  yrs <- suppressWarnings(as.numeric(unlist(
    regmatches(strings, gregexpr("\\b(19|20)\\d{2}\\b", strings)))))
  yrs <- c(yrs, suppressWarnings(as.numeric(facts$trend$sinceYear)))
  yrs <- yrs[!is.na(yrs) & yrs >= 1900 & yrs <= 2100]
  if (!length(yrs)) return(numeric(0))
  seq(min(yrs), max(yrs))
}

#' Render the facts as a compact, readable block for the user prompt.
reader_ai_facts_text <- function(facts) {
  ln <- function(...) paste0(..., "\n")
  fnum <- function(x) if (is.null(x) || is.na(x)) "n/a" else format(round(as.numeric(x), 2), nsmall = 2)
  out <- ln("STUDY: ", facts$project$name, " (", facts$project$wave, "), ",
            facts$project$sampling %||% "", ". Scale out of ", facts$scaleMax, ".")
  if (isTRUE(facts$trend$available)) out <- paste0(out, ln("Tracked against ", facts$trend$sinceYear, "."))
  out <- paste0(out, ln("\nHEADLINE:"))
  for (h in facts$headline) out <- paste0(out, ln("  - ", h$measure, ": ", fnum(h$value),
    if (!is.null(h$base)) paste0(" (n=", h$base, ")") else "",
    if (!is.null(h$delta) && !is.na(h$delta)) paste0(", change ", fnum(h$delta)) else "",
    if (!is.null(h$netPositive)) paste0(", net positive +", h$netPositive) else ""))
  out <- paste0(out, ln("\nITEMS (weakest first):"))
  for (i in facts$items) out <- paste0(out, ln("  - ", i$item, ": ", fnum(i$value),
    if (!is.null(i$delta) && !is.na(i$delta)) paste0(", change ", fnum(i$delta)) else ""))
  if (!is.null(facts$values)) {
    out <- paste0(out, ln("\nVALUES (average ", fnum(facts$values$average), "):"))
    for (v in facts$values$livesMost) out <- paste0(out, ln("  - lives most: ", v$value, " ", fnum(v$score)))
    for (v in facts$values$livesLeast) out <- paste0(out, ln("  - lives least: ", v$value, " ", fnum(v$score)))
  }
  if (!is.null(facts$people)) {
    p <- facts$people
    out <- paste0(out, ln("\nSUB-GROUPS (within ", p$group, "): lowest is ", p$lowest$label,
      " (n=", p$lowest$base, "), anchor is ", p$anchor$label, " at ", fnum(p$anchor$average),
      " (n=", p$anchor$base, "). Small bases — directional only."))
  }
  d <- facts$derived
  if (!is.null(d)) {
    dbits <- c(
      if (!is.null(d$nItems)) paste0(d$nItems, " scale items") else NULL,
      if (!is.null(d$nTracked)) paste0(d$nTracked, " tracked") else NULL,
      if (!is.null(d$nFalling)) paste0(d$nFalling, " of them lower than the base year") else NULL,
      if (!is.null(d$spread)) paste0("widest item gap ", fnum(d$spread)) else NULL)
    if (length(dbits)) out <- paste0(out, ln("\nDERIVED (already computed — safe to cite): ",
      paste(dbits, collapse = "; "), "."))
  }
  dz <- facts$design
  if (!is.null(dz)) {
    zbits <- c(
      if (nzchar(dz$censusOrSample %||% "")) dz$censusOrSample else NULL,
      if (!is.null(dz$population)) paste0("universe ", dz$population) else NULL,
      if (!is.null(dz$lowBaseThreshold)) paste0("reporting threshold n=", dz$lowBaseThreshold) else NULL,
      if (isTRUE(dz$lowBaseRegister > 0)) paste0(dz$lowBaseRegister, " figures below threshold") else NULL)
    if (length(zbits)) out <- paste0(out, ln("\nDESIGN: ", paste(zbits, collapse = "; "), "."))
  }
  out
}

#' Build the system + user prompt. The voice guidance keeps the model in
#' Duncan Brett's register; the constraints keep it honest.
reader_ai_prompt <- function(facts) {
  system <- paste(
    "You are a sharp South African market-research analyst writing the reader-facing narrative for a survey report.",
    "Your job is to find the STORY in the figures — the through-line, the argument a decision-maker can act on — not to restate the numbers.",
    "",
    get0("TURAS_PROSE_VOICE", ifnotfound = ""),
    "",
    "HONESTY (hard rules). Use ONLY numbers that appear in the FACTS. Never invent, round beyond the given precision, or extrapolate a figure.",
    "Every number you write must be traceable to the facts. Small-base sub-groups are leads, not verdicts — say so. Do not name a cause the data can't support.",
    "",
    "STRUCTURE. Return: a title; a one-sentence subtitle; the argument as 3-5 ordered claims (lead phrase + a sentence or two);",
    "a verdict paragraph (the point of view); 2-4 ranked leverage actions tied to named weak/falling items; 2-3 honest limits.",
    "Lead with the strength if there is one, then the problem. Be specific — name the items and cite their numbers.")
  user <- paste0(
    "Write the narrative for this study from the facts below. Only these numbers exist.\n\n",
    reader_ai_facts_text(facts))
  list(system = system, user = user)
}

# Normalise an ellmer array result (list-of-lists or data.frame) to a plain
# list of list(lead=, body=).
.reader_as_leaves <- function(x) {
  if (is.null(x)) return(list())
  if (is.data.frame(x)) return(lapply(seq_len(nrow(x)), function(i)
    list(lead = as.character(x$lead[i] %||% ""), body = as.character(x$body[i] %||% ""))))
  lapply(x, function(e) list(lead = as.character(e$lead %||% e[["lead"]] %||% ""),
                             body = as.character(e$body %||% e[["body"]] %||% "")))
}

#' Generate AI prose for the reader model. Returns a list with `$prose` (the
#' drafted narrative on success, NULL on any failure / number-check rejection)
#' and `$reason` (a short human phrase naming the failure, NULL on success).
#' The reason surfaces in the report's failure banner (§3.7) so a degraded run
#' is never mistaken for an Opus draft.
reader_generate_ai_prose <- function(model, config_obj = list()) {
  fail <- function(reason) list(prose = NULL, reason = reason)
  if (!.reader_ensure_ai_layer()) {
    cat("  [Reader AI] AI layer unavailable (ellmer / shared ai modules) — keeping the on-device narrative.\n")
    return(fail("the AI layer is unavailable (ellmer or API key missing)"))
  }
  model_id <- resolve_ai_model_alias(config_obj$ai_model %||% "")
  if (!nzchar(model_id)) model_id <- "claude-opus-4-8"   # the reader is the flagship — default to the strong model
  ai_config <- list(provider = config_obj$ai_provider %||% "anthropic",
                    model = model_id, max_tokens = 3000L)

  facts <- reader_ai_facts(model)
  prompt <- reader_ai_prompt(facts)
  res <- tryCatch(call_insight_model(prompt, reader_prose_schema(), ai_config),
                  error = function(e) NULL)
  if (is.null(res) || !is.list(res) || !nzchar(res$verdict %||% "")) {
    cat("  [Reader AI] No usable response — keeping the on-device narrative.\n")
    return(fail("no usable response from the model"))
  }

  prose <- list(
    title = as.character(res$title %||% model$prose$title),
    subtitle = as.character(res$subtitle %||% model$prose$subtitle),
    claims = .reader_as_leaves(res$claims),
    verdict = as.character(res$verdict),
    leverage = .reader_as_leaves(res$leverage),
    limits = .reader_as_leaves(res$limits))

  # Number check: every figure in the AI prose must exist in the facts we sent.
  # Pass a clean, NA-free numeric vector as the source — the shared check treats
  # its argument as the source pool (extract_all_numbers is identity on a numeric
  # vector) and NA in the pool would break its any(... < tol) comparison. The
  # pool includes the fact-sheet v2 derived-numbers and design facts (they live
  # inside `facts`), so citing a legitimately derived figure is not a false
  # reject (§3.6).
  narrative <- paste(c(prose$title, prose$subtitle, prose$verdict,
    unlist(lapply(c(prose$claims, prose$leverage, prose$limits), function(x) c(x$lead, x$body)))),
    collapse = " ")
  facts_numbers <- extract_all_numbers(facts)
  facts_numbers <- c(facts_numbers, .reader_year_pool(facts))
  facts_numbers <- facts_numbers[!is.na(facts_numbers)]
  chk <- deterministic_number_check(narrative, facts_numbers)
  if (!isTRUE(chk$pass)) {
    cat(sprintf("  [Reader AI] REJECTED — %s. Keeping the on-device narrative.\n",
                chk$issues %||% "a cited number is not in the data"))
    return(fail("a cited figure was not in the data"))
  }
  prose$model <- get_model_display_name(ai_config)
  list(prose = prose, reason = NULL)
}

#' Apply AI prose to the model when reader_ai_prose is on. Returns the model —
#' enriched with AI prose + an "ai" disclosure when it succeeds. When the AI
#' path was requested but degraded, the model is left on its deterministic
#' narrative but its disclosure is stamped requested_mode="ai" + a
#' fallback_reason, so the report can show the §3.7 failure banner rather than
#' passing a degraded run off as an Opus draft. Never throws.
reader_apply_ai_prose <- function(model, config_obj = list()) {
  if (!isTRUE(config_obj$reader_ai_prose)) return(model)
  # AI prose was requested — record that on the disclosure whatever the outcome.
  model$disclosure$requested_mode <- "ai"
  gen <- tryCatch(reader_generate_ai_prose(model, config_obj), error = function(e) {
    cat(sprintf("  [Reader AI] error: %s — keeping the on-device narrative.\n", conditionMessage(e)))
    list(prose = NULL, reason = "an unexpected error while drafting")
  })
  if (is.null(gen$prose)) {
    model$disclosure$fallback_reason <- gen$reason %||% "the AI narrative was unavailable"
    cat("  [Reader AI] requested but unavailable — the report will show the on-device narrative and say so.\n")
    return(model)
  }
  prose <- gen$prose

  model$prose$title <- prose$title
  model$prose$subtitle <- prose$subtitle
  if (length(prose$claims)) model$prose$claims <- prose$claims
  if (length(prose$limits)) model$prose$limits <- prose$limits
  if (nzchar(prose$verdict)) {
    lev <- lapply(seq_along(prose$leverage), function(i)
      list(n = i, lead = prose$leverage[[i]]$lead, body = prose$leverage[[i]]$body))
    model$verdict <- list(lead = "The read", body = prose$verdict, leverage = lev)
  }
  model$disclosure <- list(mode = "ai", requested_mode = "ai", model = prose$model,
    text = paste0("The narrative was drafted by ", prose$model,
      " from the survey's aggregate figures — no individual responses or verbatims were sent. ",
      "Every number was computed by Turas, not the model, and checked against the data. Analyst-reviewed."))
  cat(sprintf("  [Reader AI] narrative drafted by %s (numbers verified).\n", prose$model))
  model
}
