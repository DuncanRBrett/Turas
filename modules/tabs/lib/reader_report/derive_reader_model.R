# ==============================================================================
# TABS — READER REPORT: DERIVE THE READER MODEL (V15)
# ==============================================================================
# Turns the data layer (dl) already built for the crosstab into the compact
# "reader model" the Reader report renders from. This is PURE derivation — it
# reads numbers the crosstab already computed and never recomputes a statistic,
# so a figure in the Reader can only ever be a figure that is in the crosstab.
#
# Everything here comes from `dl` (aggregates), with two optional inputs parsed
# from islands the crosstab already carries: `prev` (tracking waves, for the
# 2-wave deltas) and `qual` (coded open-ends, for the theme bars). Both are
# optional — the model degrades section-by-section, so a single-wave or
# comments-free study still yields a valid Reader.
#
# NO AI here. The narrative prose in $prose is templated from the numbers. The
# AI path (reader_ai_prose) overwrites $prose downstream and is opt-in.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# --- small helpers ------------------------------------------------------------

#' Normalise a question title the way the tracking renderer does, so a current
#' (dl) question can be matched to a prior wave by title. Lowercase, strip
#' non-alphanumerics, collapse whitespace.
.rr_norm <- function(s) {
  s <- tolower(as.character(s %||% ""))
  s <- gsub("[^a-z0-9]+", " ", s)
  trimws(gsub("\\s+", " ", s))
}

#' The Total-column value of the first row of a given kind (Total is column 1).
.rr_total_of <- function(q, kind, label = NULL) {
  rows <- q$rows %||% list()
  for (r in rows) {
    if (identical(r$kind, kind) && (is.null(label) || identical(r$label, label))) {
      v <- r$pct[[1]] %||% r$pct[1]
      return(suppressWarnings(as.numeric(v)))
    }
  }
  NA_real_
}

#' The Total-column index (mean row) of a question.
.rr_index <- function(q) .rr_total_of(q, "mean")

#' Base n for a column (1 = Total) and whether it is flagged low.
.rr_base <- function(q, col = 1L) {
  b <- q$bases[[col]]
  if (is.null(b)) return(list(n = NA_integer_, low = TRUE))
  list(n = suppressWarnings(as.integer(b$n %||% b[["n"]])),
       low = isTRUE(b$low %||% b[["low"]]))
}

#' Short label for an item: prefer an explicit short_label, else trim the title.
.rr_short <- function(q, n = 42L) {
  s <- q$short_label %||% ""
  if (nzchar(s)) return(as.character(s))
  t <- trimws(as.character(q$title %||% q$code %||% ""))
  if (nchar(t) > n) paste0(substr(t, 1L, n - 1L), "…") else t
}

#' Round for display, dropping trailing zeros but keeping 2dp for indices.
.rr_round <- function(x, d = 2L) {
  if (length(x) != 1 || is.na(x)) return(NA_real_)
  round(as.numeric(x), d)
}

# --- the derivation -----------------------------------------------------------

#' Derive the reader model from the crosstab data layer.
#'
#' @param dl The data layer list (from build_data_layer) — NOT serialised.
#' @param prev Parsed tracking island (list) or NULL.
#' @param qual Parsed qualitative island (list) or NULL.
#' @param config_obj The tabs config object.
#' @param crosstab_file Basename of the sibling crosstab report (for deep links).
#'
#' @return A list (the reader model), ready for serialize + render. Never throws
#'   on a missing optional section — it sets that section's `available = FALSE`.
#' @export
derive_reader_model <- function(dl, prev = NULL, qual = NULL, config_obj = list(),
                                crosstab_file = "") {
  proj <- dl$project %||% list()
  questions <- dl$questions %||% list()
  columns <- dl$columns %||% list()
  bgroups <- dl$banner_groups %||% list()
  banner_default <- if (length(bgroups)) (bgroups[[1]]$id %||% "") else ""

  # scale battery items (exclude computed composites, which are type "single")
  is_scale <- function(q) identical(q$type, "scale")
  is_composite <- function(q) grepl("^Q_", as.character(q$code %||% ""))
  scale_qs <- Filter(function(q) is_scale(q) && !is_composite(q), questions)
  composite_qs <- Filter(function(q) is_composite(q) && !is.na(.rr_index(q)), questions)

  # ---- trend: match each scale item to its earliest prior wave by title ------
  # Defensive: handles the observed island shape (waves[].questions[] each with
  # match_key + a mean, either $stats$mean or a numeric $scores$Index). If the
  # shape does not yield a usable prior mean, the item simply carries no delta.
  # The tracking island links waves by match_key (e.g. "eng01"); the CURRENT wave
  # carries both the question code (Q05) and that match_key, which is the bridge
  # from a data-layer question to its prior-wave mean. Prior means are keyed by
  # match_key; the earliest non-current wave is the baseline.
  prior_mean_by_key <- list()      # match_key -> earliest-wave mean
  code_to_key <- list()            # current-wave code -> match_key
  ref_year <- NA
  trend_available <- FALSE
  prior_mean_of_q <- function(q) suppressWarnings(as.numeric(
    q$stats$mean %||% q$stats$index %||%
    (if (is.list(q$scores)) (q$scores$Index %||% q$scores$index %||% q$scores$mean) else NULL)))
  if (is.list(prev) && length(prev$waves %||% list())) {
    waves <- prev$waves
    yrs <- suppressWarnings(as.numeric(vapply(waves, function(w) w$year %||% NA, numeric(1))))
    is_current <- vapply(waves, function(w) isTRUE(w$current), logical(1))
    cur_i <- which(is_current)
    if (length(cur_i)) for (q in waves[[cur_i[1]]]$questions %||% list()) {
      cc <- as.character(q$code %||% ""); mk <- as.character(q$match_key %||% "")
      if (nzchar(cc) && nzchar(mk)) code_to_key[[cc]] <- mk
    }
    earliest_i <- NA_integer_
    for (i in order(yrs)) if (!isTRUE(is_current[i])) { earliest_i <- i; break }
    if (!is.na(earliest_i)) {
      ew <- waves[[earliest_i]]
      ref_year <- ew$year %||% NA
      for (q in ew$questions %||% list()) {
        m <- prior_mean_of_q(q)
        if (length(m) == 1 && !is.na(m)) {
          key <- as.character(q$match_key %||% "")
          if (nzchar(key)) prior_mean_by_key[[key]] <- m
          tkey <- .rr_norm(q$title %||% "")   # also index by normalised title (title-linked islands)
          if (nzchar(tkey)) prior_mean_by_key[[tkey]] <- m
        }
      }
      trend_available <- length(prior_mean_by_key) > 0
    }
  }
  item_delta <- function(q) {
    if (!trend_available) return(NA_real_)
    key <- code_to_key[[as.character(q$code %||% "")]]        # code -> match_key
    if (is.null(key) || !nzchar(key)) key <- .rr_norm(q$title) # fall back to title match
    pm <- prior_mean_by_key[[key]]
    cur <- .rr_index(q)
    if (is.null(pm) || is.na(pm) || is.na(cur)) return(NA_real_)
    .rr_round(cur - pm, 2L)
  }

  # ---- items -----------------------------------------------------------------
  items <- lapply(scale_qs, function(q) {
    list(code = as.character(q$code %||% ""),
         short = .rr_short(q),
         category = as.character(q$category %||% ""),
         value = .rr_index(q),
         delta = item_delta(q))
  })
  # rank by current index (ascending — weakest first, as the delta chart wants)
  items <- items[order(vapply(items, function(x) x$value %||% Inf, numeric(1)))]

  # ---- headline cards --------------------------------------------------------
  # Prefer the computed composites (Q_Engage/Q_Value…). Add any single scale
  # question sitting in a Satisfaction-ish category. Cap at 4.
  sat_qs <- Filter(function(q) is_scale(q) &&
    grepl("satisf", tolower(as.character(q$category %||% "")), fixed = FALSE), questions)
  headline_src <- c(composite_qs, sat_qs)
  if (!length(headline_src)) headline_src <- utils::head(scale_qs, 3L)
  headline <- lapply(utils::head(headline_src, 4L), function(q) {
    b <- .rr_base(q, 1L)
    netpos <- .rr_total_of(q, "net", "NET POSITIVE (Satisfied - Dissatisfied)")
    list(label = as.character(q$title %||% q$code),
         value = .rr_index(q),
         scaleMax = q$scale_max %||% 5,
         base = b$n,
         delta = item_delta(q),
         netPositive = if (is.na(netpos)) NULL else netpos,
         q = as.character(q$code %||% ""),
         tab = "crosstabs",
         banner = banner_default)
  })

  # ---- what held / what slipped (only meaningful when trends exist) ----------
  held <- list(); slipped <- list()
  if (trend_available) {
    with_delta <- Filter(function(x) !is.na(x$delta %||% NA), items)
    ord <- with_delta[order(vapply(with_delta, function(x) x$delta, numeric(1)))]
    slipped <- utils::head(ord, 6L)                    # most negative
    held <- utils::head(rev(ord), 6L)                  # least negative / positive
  }

  # ---- values split ----------------------------------------------------------
  values_avail <- FALSE; lives_most <- list(); lives_least <- list(); val_avg <- NA_real_
  val_qs <- Filter(function(q) is_scale(q) &&
    identical(tolower(as.character(q$category %||% "")), "values"), questions)
  if (length(val_qs) >= 3) {
    values_avail <- TRUE
    vv <- lapply(val_qs, function(q) list(label = .rr_short(q, 52L), value = .rr_index(q)))
    val_avg <- .rr_round(mean(vapply(vv, function(x) x$value, numeric(1)), na.rm = TRUE))
    vv <- vv[order(-vapply(vv, function(x) x$value %||% -Inf, numeric(1)))]
    lives_most <- Filter(function(x) !is.na(x$value) && x$value >= val_avg, vv)
    lives_least <- Filter(function(x) !is.na(x$value) && x$value < val_avg, vv)
  }

  low_thr <- suppressWarnings(as.numeric(proj$low_base_threshold %||% 30))
  reg <- list()   # low-base register: every sub-threshold figure the narrative cites

  # ---- people: the sub-group sitting consistently lowest on the headline -----
  # metrics, within the primary banner group. Reproduces the "X runs low on
  # everything" read; every cited figure below the reporting threshold is amber
  # and collected in the register.
  people <- list(available = FALSE)
  grp_cols <- which(vapply(columns, function(c) identical(c$group, banner_default), logical(1)))
  grp_name <- banner_default
  for (g in bgroups) if (identical(g$id, banner_default)) grp_name <- g$name %||% g$id
  metric_qs <- Filter(Negate(is.null), lapply(headline, function(h) {
    hit <- Filter(function(q) identical(as.character(q$code %||% ""), h$q), questions)
    if (length(hit)) hit[[1]] else NULL
  }))
  if (length(grp_cols) >= 2 && length(metric_qs) >= 1) {
    col_stat <- lapply(grp_cols, function(ci) {
      vals <- vapply(metric_qs, function(q) {
        v <- NA_real_
        for (row in q$rows) if (identical(row$kind, "mean")) {
          v <- suppressWarnings(as.numeric(row$pct[[ci]] %||% row$pct[ci])); break
        }
        v
      }, numeric(1))
      b <- .rr_base(metric_qs[[1]], ci)
      list(label = as.character(columns[[ci]]$label %||% ""), ci = ci,
           avg = .rr_round(mean(vals, na.rm = TRUE)),
           metrics = lapply(seq_along(metric_qs), function(k) list(
             name = as.character(metric_qs[[k]]$title %||% metric_qs[[k]]$code),
             value = .rr_round(vals[k]))),
           base = b$n, low = isTRUE(b$low) || (!is.na(b$n) && b$n < low_thr))
    })
    col_stat <- Filter(function(x) !is.na(x$avg), col_stat)
    if (length(col_stat) >= 2) {
      ord <- col_stat[order(vapply(col_stat, function(x) x$avg, numeric(1)))]
      lowest <- ord[[1]]; anchor <- ord[[length(ord)]]
      people <- list(available = TRUE, groupName = grp_name, lowest = lowest, anchor = anchor)
      if (isTRUE(lowest$low)) for (mm in lowest$metrics) if (!is.null(mm$value) && !is.na(mm$value)) {
        reg[[length(reg) + 1L]] <- list(
          figure = sprintf("%s — %s %s", lowest$label, mm$name, format(mm$value, nsmall = 2)),
          base = paste0("n=", lowest$base), section = "The people")
      }
    }
  }

  # ---- prose (templated, deterministic) --------------------------------------
  tracked <- Filter(function(x) !is.na(x$delta %||% NA), items)   # items with a wave-on-wave delta
  n_tracked <- length(tracked)
  n_down <- if (trend_available) sum(vapply(tracked, function(x) isTRUE(x$delta < 0), logical(1))) else NA_integer_
  steepest <- if (length(slipped)) slipped[[1]] else NULL
  strongest <- items[[length(items)]]
  weakest <- items[[1]]

  scale_max1 <- headline[[1]]$scaleMax %||% 5
  claims <- list()
  h_bits <- vapply(headline, function(h)
    sprintf("%s %s", tolower(h$label), format(.rr_round(h$value), nsmall = 2)), character(1))
  claims[[1]] <- list(lead = "Where it stands.",
    body = sprintf("On a %s-point scale, %s.", scale_max1,
                   paste(utils::head(h_bits, 3L), collapse = "; ")))
  if (trend_available && !is.na(n_down)) {
    claims[[length(claims) + 1L]] <- list(lead = "The direction.",
      body = sprintf("Of the %d tracked items, %s lower than %s%s.",
                     n_tracked,
                     if (n_down == n_tracked) sprintf("every one is", n_down) else sprintf("%d are", n_down),
                     ref_year,
                     if (!is.null(steepest)) sprintf("; the steepest fall is “%s” (%s)",
                       steepest$short, format(steepest$delta, nsmall = 2)) else ""))
  }
  claims[[length(claims) + 1L]] <- list(lead = "Strong and weak.",
    body = sprintf("The strongest item is “%s” (%s); the weakest is “%s” (%s).",
                   strongest$short, format(.rr_round(strongest$value), nsmall = 2),
                   weakest$short, format(.rr_round(weakest$value), nsmall = 2)))
  if (isTRUE(values_avail) && length(lives_most) && length(lives_least)) {
    claims[[length(claims) + 1L]] <- list(lead = "The values read.",
      body = sprintf("On its stated values it reads highest on “%s” (%s) and lowest on “%s” (%s).",
                     lives_most[[1]]$label, format(lives_most[[1]]$value, nsmall = 2),
                     lives_least[[length(lives_least)]]$label,
                     format(lives_least[[length(lives_least)]]$value, nsmall = 2)))
  }
  if (isTRUE(people$available)) {
    claims[[length(claims) + 1L]] <- list(lead = "Pattern, not proof.",
      body = sprintf("Across %s, %s sits lowest%s — a lead to check, not a verdict at this base.",
                     tolower(people$groupName), people$lowest$label,
                     if (isTRUE(people$lowest$low)) sprintf(" (n=%s)", people$lowest$base) else ""))
  }

  prose <- list(
    title = as.character(proj$name %||% config_obj$project_title %||% "Reader report"),
    subtitle = sprintf("Every figure below comes from the survey data%s.",
                       if (!is.na(ref_year)) sprintf(", tracked against %s", ref_year) else ""),
    claims = claims,
    limits = list(
      list(lead = "Why it looks the way it does.",
           body = "The survey measures a state, not its cause. It ranks the symptoms; it can't say what drives them — that takes conversation, not more tables."),
      list(lead = "Sub-groups are leads, not verdicts.",
           body = sprintf("Below the top line the cells get small. Treat a group-level difference as something to check%s, never as a ranking.",
                          if (isTRUE(people$available) && isTRUE(people$lowest$low))
                            sprintf(" (the lowest cut here is only n=%s)", people$lowest$base) else ""))))

  # ---- verdict + ranked leverage (templated from the derived facts) ----------
  lev_src <- utils::head(if (trend_available && length(slipped)) slipped else items, 3L)
  ord_words <- c("first", "second", "third", "fourth", "fifth")
  leverage <- lapply(seq_along(lev_src), function(i) {
    it <- lev_src[[i]]
    list(n = i, lead = sprintf("Lift “%s”.", it$short),
         body = sprintf("It sits at %s%s — the %s place to look.",
                        format(.rr_round(it$value), nsmall = 2),
                        if (!is.null(it$delta) && !is.na(it$delta))
                          sprintf(", down %s since %s", format(abs(it$delta), nsmall = 2), ref_year) else "",
                        ord_words[min(i, 5L)]))
  })
  verdict <- list(lead = "The read",
    body = sprintf("The base is %s: the strongest item, “%s”, sits at %s. The work is at the other end — “%s” at %s%s. The leverage below is ranked by where the numbers are weakest.",
                   if (!is.na(strongest$value) && strongest$value >= scale_max1 * 0.75) "solid" else "mixed",
                   strongest$short, format(.rr_round(strongest$value), nsmall = 2),
                   weakest$short, format(.rr_round(weakest$value), nsmall = 2),
                   if (trend_available && !is.null(steepest))
                     sprintf(", and falling fastest is “%s” (%s)", steepest$short, format(steepest$delta, nsmall = 2)) else ""),
    leverage = leverage)

  # ---- glossary (plain + technical for the survey terms in play) -------------
  glossary <- list(
    list(term = "Index", plain = "The average score on the rating scale — higher is more positive.",
         tech = "Mean of the coded scale points on the Total column."),
    list(term = "Net positive", plain = "The share who are positive minus the share who are negative.",
         tech = "%(top box) − %(bottom box); it ignores the neutral middle."),
    list(term = "Base (n)", plain = "How many people answered — a small base moves around more.",
         tech = "Unweighted respondents in the group; every figure below the threshold is in the register."),
    list(term = "Directional", plain = "A pattern from a group too small to prove — a lead, not a fact.",
         tech = sprintf("Base below the reporting threshold of %s.", low_thr)),
    list(term = "Significance", plain = "A gap too big to be chance alone.",
         tech = "Pairwise at the configured alpha; with small cells and many columns few gaps reach it."))

  # ---- practitioner panels (revealed by the depth toggle) --------------------
  tot_base <- if (length(scale_qs)) .rr_base(scale_qs[[1]], 1L)$n else NA
  grp_names <- paste(vapply(bgroups, function(g) as.character(g$name %||% g$id), character(1)), collapse = ", ")
  practitioner <- list(list(after = "standing", title = "Design and bases",
    body = sprintf("%sThe Total column is the safe line%s. Sub-group cells are thinner, and some fall below the reporting threshold of %s — those figures are marked directional and listed in the register.",
                   if (nzchar(proj$sampling_method %||% "")) paste0(proj$sampling_method, ". ") else "",
                   if (!is.na(tot_base)) sprintf(" (n=%s)", tot_base) else "", low_thr)))
  if (isTRUE(people$available)) {
    practitioner[[length(practitioner) + 1L]] <- list(after = "people",
      title = "Why sub-groups rarely reach significance",
      body = sprintf("Split the sample across %s and the cells collapse; most sub-group gaps do not clear significance. The consistency of a pattern across measures is stronger evidence than any single small cell — which is why %s is offered as a lead, confirmed in conversation, not a verdict.",
                     grp_names, people$lowest$label))
  }

  disclosure <- list(mode = "deterministic", requested_mode = "deterministic", model = NULL,
    text = paste0("Built on-device from the survey's own figures. No AI was used; ",
                  "no data left this machine. Every number is computed by Turas and ",
                  "traces to a cell in the crosstab."))

  list(
    schema_version = 1L,
    project = list(
      name = as.character(proj$name %||% ""), client = as.character(proj$client %||% ""),
      wave = as.character(proj$wave %||% ""),
      brand_colour = as.character(proj$brand_colour %||% "#323367"),
      accent_colour = as.character(proj$accent_colour %||% "#CC9900"),
      sampling_method = as.character(proj$sampling_method %||% ""),
      population = proj$population_size %||% NULL, low_base_threshold = low_thr),
    crosstab = as.character(crosstab_file %||% ""),
    bannerDefault = as.character(banner_default),
    headline = headline, items = items,
    trend = list(available = trend_available, refYear = ref_year),
    splitHeld = held, splitSlipped = slipped,
    values = list(available = values_avail, avg = val_avg,
                  livesMost = lives_most, livesLeast = lives_least),
    people = people,
    themes = list(available = FALSE),        # wired next pass (qual island shape)
    register = reg,
    verdict = verdict,
    glossary = glossary,
    practitioner = practitioner,
    prose = prose,
    disclosure = disclosure)
}
