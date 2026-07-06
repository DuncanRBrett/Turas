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
reader_ai_facts <- function(model) {
  hl <- lapply(model$headline %||% list(), function(h) list(
    measure = h$label, value = h$value, base = h$base,
    delta = h$delta, netPositive = h$netPositive))
  it <- lapply(model$items %||% list(), function(x) list(
    item = x$short, value = x$value, delta = x$delta))
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
  list(
    project = list(name = model$project$name, wave = model$project$wave,
                   sampling = model$project$sampling_method,
                   lowBaseThreshold = model$project$low_base_threshold),
    scaleMax = (model$headline[[1]]$scaleMax %||% 5),
    trend = list(available = isTRUE(model$trend$available), sinceYear = model$trend$refYear),
    headline = hl, items = it, values = vals, people = ppl,
    itemsFalling = if (isTRUE(model$trend$available))
      lapply(model$splitSlipped %||% list(), function(x) list(item = x$short, value = x$value, delta = x$delta)) else NULL)
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
  out
}

#' Build the system + user prompt. The voice guidance keeps the model in
#' Duncan Brett's register; the constraints keep it honest.
reader_ai_prompt <- function(facts) {
  system <- paste(
    "You are a sharp South African market-research analyst writing the reader-facing narrative for a survey report.",
    "Your job is to find the STORY in the figures — the through-line, the argument a decision-maker can act on — not to restate the numbers.",
    "",
    "VOICE. Write like a smart, experienced person talking straight to the reader. Short, clear sentences; no padding.",
    "Dry and plain, never a consultancy slide. Say the point in ordinary words. Banned: em-dash pile-ups; showy triads;",
    "aphoristic one-liners as filler; 'delve', 'unpack', 'landscape', 'journey', 'leverage', 'robust', 'nuanced', 'holistic';",
    "'it's worth noting', 'at the end of the day'. South African English spelling (colour, organisation, behaviour). Contractions are fine.",
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

#' Generate AI prose for the reader model, or NULL on any failure / number-check
#' rejection (caller keeps the deterministic prose).
reader_generate_ai_prose <- function(model, config_obj = list()) {
  if (!.reader_ensure_ai_layer()) {
    cat("  [Reader AI] AI layer unavailable (ellmer / shared ai modules) — keeping the on-device narrative.\n")
    return(NULL)
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
    return(NULL)
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
  # vector) and NA in the pool would break its any(... < tol) comparison.
  narrative <- paste(c(prose$title, prose$subtitle, prose$verdict,
    unlist(lapply(c(prose$claims, prose$leverage, prose$limits), function(x) c(x$lead, x$body)))),
    collapse = " ")
  facts_numbers <- extract_all_numbers(facts)
  facts_numbers <- facts_numbers[!is.na(facts_numbers)]
  chk <- deterministic_number_check(narrative, facts_numbers)
  if (!isTRUE(chk$pass)) {
    cat(sprintf("  [Reader AI] REJECTED — %s. Keeping the on-device narrative.\n",
                chk$issues %||% "a cited number is not in the data"))
    return(NULL)
  }
  prose$model <- get_model_display_name(ai_config)
  prose
}

#' Apply AI prose to the model when reader_ai_prose is on. Returns the model —
#' enriched with AI prose + an "ai" disclosure when it succeeds, unchanged
#' (deterministic) otherwise. Never throws.
reader_apply_ai_prose <- function(model, config_obj = list()) {
  if (!isTRUE(config_obj$reader_ai_prose)) return(model)
  prose <- tryCatch(reader_generate_ai_prose(model, config_obj), error = function(e) {
    cat(sprintf("  [Reader AI] error: %s — keeping the on-device narrative.\n", conditionMessage(e)))
    NULL
  })
  if (is.null(prose)) return(model)

  model$prose$title <- prose$title
  model$prose$subtitle <- prose$subtitle
  if (length(prose$claims)) model$prose$claims <- prose$claims
  if (length(prose$limits)) model$prose$limits <- prose$limits
  if (nzchar(prose$verdict)) {
    lev <- lapply(seq_along(prose$leverage), function(i)
      list(n = i, lead = prose$leverage[[i]]$lead, body = prose$leverage[[i]]$body))
    model$verdict <- list(lead = "The read", body = prose$verdict, leverage = lev)
  }
  model$disclosure <- list(mode = "ai", model = prose$model,
    text = paste0("The narrative was drafted by ", prose$model,
      " from the survey's aggregate figures — no individual responses or verbatims were sent. ",
      "Every number was computed by Turas, not the model, and checked against the data. Analyst-reviewed."))
  cat(sprintf("  [Reader AI] narrative drafted by %s (numbers verified).\n", prose$model))
  model
}
