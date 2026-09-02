# ==============================================================================
# TABS. WAVE VALUES FROM MICRODATA (v2 aggregate tracking, upstream stage)
# ==============================================================================
# Derives the long values table (one row per metric: value, base, sd) for ONE
# wave, from that wave's respondent-level data. This is the UPSTREAM twin of
# tracking_aggregate_bridge.R: that turns a values table into wave sidecars,
# this produces the values table in the first place.
#
# WHY IT EXISTS: historical waves usually survive only as published figures
# typed from a spreadsheet. A mean and nothing else, so the renderer's Welch
# test has no spread to work with and the wave plots untested (by design; see
# 22w_waves.js meanLevel). Where the wave's raw data DOES still exist, this
# recovers the base and the standard deviation the test needs, inside tested
# Turas code with an auditable reconciliation against the published figures.
#
# THE RULES IT ENCODES. Each verified against the v2 renderer it must feed:
#   mean        drop options flagged ExcludeFromIndex = Y; base = the count of
#               valid numeric responses; sd = the SAME formula as sdOfScores()
#               in 22w_waves.js, including the Kish effective base when the wave
#               is weighted (so an unweighted wave reduces to the sample sd).
#   proportion  base = ALL non-missing responses to the question. DK/NA stay
#               IN the base. A NET sums its member options.
#   nps         per-respondent +100 / 0 / -100 (9-10 / 7-8 / 0-6); the value is
#               the mean of those, and an sd is recorded even though the bridge
#               does not yet carry it (see tracking_aggregate_bridge.R).
#   multi       a Multi_Mention "any of" NET: selected any member column.
#               base = answered the question at all (any of its columns).
#
# HONEST BY CONSTRUCTION, like the bridge: a metric whose column is absent, or
# whose category cannot be resolved, is SKIPPED and named, never guessed, never
# silently dropped. Nothing here invents a base, an sd or a category.
#
# OFFLINE tool: used to PREPARE a values table, not called in the run_crosstabs
# hot path. Depends on tracking_norm() + %||% (tracking_island.R), and on
# apply_base_filter() (filter_utils.R) only when base_filters are supplied.
#
# READ YOUR WORKBOOKS WITH readxl, NOT openxlsx. Two silent traps, both of which
# produce plausible-looking numbers rather than an error:
#   1. openxlsx::read.xlsx() leaks the raw `xml:space="preserve"` attribute into
#      the value of any cell that has trailing whitespace. Survey_Structure
#      OptionText is full of those, so NET members stop matching and the NET
#      quietly computes 0%.
#   2. openxlsx converts the literal option text "NA" to a missing cell, which
#      drops those respondents out of a proportion's base and shifts the
#      percentage (CCPB Q11 loses 37 of 764 that way).
# readxl::read_excel(..., col_types = "text", na = character(0)) is what Turas's
# own loader uses (data_loader.R:84) and is correct on both counts. Both traps
# are caught by reconcile_wave_values(), which is the point of running it.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

TRACKING_WAVE_METRIC_TYPES <- c("mean", "proportion", "nps", "multi")


#' Normalised option texts a question excludes from its mean
#'
#' Reads the Survey_Structure Options sheet's ExcludeFromIndex column. The same
#' flag the crosstab engine honours, so a wave's recovered mean matches the mean
#' its own report published (typically DK / NA).
#'
#' @param options Survey_Structure Options body (QuestionCode, OptionText,
#'   ExcludeFromIndex).
#' @param code The QuestionCode.
#' @return Character vector of normalised option texts (possibly empty).
#' @keywords internal
.twv_excluded <- function(options, code) {
  if (is.null(options) || !is.data.frame(options) || nrow(options) == 0) return(character(0))
  if (!all(c("QuestionCode", "OptionText") %in% names(options))) return(character(0))
  if (!("ExcludeFromIndex" %in% names(options))) return(character(0))
  hit <- trimws(as.character(options$QuestionCode)) == code &
    toupper(trimws(as.character(options$ExcludeFromIndex %||% ""))) == "Y"
  hit[is.na(hit)] <- FALSE
  unique(tracking_norm(options$OptionText[hit]))
}


#' Member option texts of a NET, from the Options sheet's BoxCategory column
#'
#' A NET is declared the Turas way: every member option carries the NET's label
#' in BoxCategory. When no option carries the label, the label is treated as a
#' plain single category (e.g. `category:Yes`), which is the common case.
#'
#' @param options Survey_Structure Options body.
#' @param code The QuestionCode (root code for Multi_Mention).
#' @param label The NET / category label from TrackingSpecs.
#' @return Character vector of normalised member option texts.
#' @keywords internal
.twv_members <- function(options, code, label) {
  target <- tracking_norm(label)
  if (is.null(options) || !is.data.frame(options) || nrow(options) == 0) return(target)
  if (!all(c("QuestionCode", "OptionText") %in% names(options))) return(target)
  if (!("BoxCategory" %in% names(options))) return(target)
  roots <- sub("_[0-9]+$", "", trimws(as.character(options$QuestionCode)))
  hit <- roots == code & tracking_norm(options$BoxCategory) == target
  hit[is.na(hit)] <- FALSE
  if (!any(hit)) return(target)                 # plain category, not a NET
  unique(tracking_norm(options$OptionText[hit]))
}


#' Data columns of a Multi_Mention question whose option text is a NET member
#'
#' @param options Survey_Structure Options body (per-column codes: Q03_1, ...).
#' @param data The wave's data frame.
#' @param code Root QuestionCode.
#' @param members Normalised member option texts; NULL = every column.
#' @return list(member_cols, all_cols): column names present in `data`.
#' @keywords internal
.twv_mm_columns <- function(options, data, code, members = NULL) {
  all_cols <- grep(paste0("^", code, "_[0-9]+$"), names(data), value = TRUE)
  if (length(all_cols) == 0 || is.null(members)) {
    return(list(member_cols = all_cols, all_cols = all_cols))
  }
  codes <- trimws(as.character(options$QuestionCode))
  texts <- tracking_norm(options$OptionText)
  member_cols <- all_cols[vapply(all_cols, function(cl) {
    i <- which(codes == cl)
    length(i) > 0 && texts[i[1]] %in% members
  }, logical(1))]
  list(member_cols = member_cols, all_cols = all_cols)
}


#' Valid numeric scores for a rating / NPS column
#'
#' @param data The wave's data frame.
#' @param code Column name.
#' @param excluded Normalised option texts to drop (DK / NA).
#' @return list(scores, keep): numeric vector and the logical row mask.
#' @keywords internal
.twv_scores <- function(data, code, excluded) {
  raw <- data[[code]]
  keep <- !is.na(raw) & !(tracking_norm(raw) %in% excluded)
  num <- suppressWarnings(as.numeric(as.character(raw)))
  keep <- keep & !is.na(num)
  list(scores = num[keep], keep = keep)
}


#' Mean, base and sd of a score vector. The renderer's own formula
#'
#' Mirrors meanOfScores()/sdOfScores() in assets/js/22w_waves.js exactly: the sd
#' is carried on the KISH effective base n_eff = (sum w)^2 / sum(w^2), which
#' collapses to n (and so to the plain sample sd) when the wave is unweighted.
#' Matching the renderer matters because the wave-on-wave Welch test pairs this
#' sd against one the renderer derives itself for the current wave.
#'
#' @param scores Numeric vector.
#' @param weights Optional numeric vector, same length; NULL = unweighted.
#' @return list(value, base, sd): sd NULL when it cannot be computed.
#' @keywords internal
.twv_mean_stats <- function(scores, weights = NULL) {
  n <- length(scores)
  if (n == 0) return(list(value = NA_real_, base = 0L, sd = NULL))
  w <- if (is.null(weights)) rep(1, n) else as.numeric(weights)
  wsum <- sum(w)
  if (!is.finite(wsum) || wsum <= 0) return(list(value = NA_real_, base = n, sd = NULL))
  m <- sum(w * scores) / wsum
  if (n < 2) return(list(value = m, base = n, sd = NULL))
  sumw2 <- sum(w * w)
  eff_n <- if (sumw2 > 0) (wsum * wsum) / sumw2 else 0
  if (eff_n <= 1) return(list(value = m, base = n, sd = NULL))
  variance <- sum(w * (scores - m)^2)
  list(value = m, base = n,
       sd = sqrt((variance / wsum) * eff_n / (eff_n - 1)))
}


#' Per-respondent NPS scores (+100 promoter / 0 passive / -100 detractor)
#' @keywords internal
.twv_nps_scores <- function(scores) {
  ifelse(scores >= 9, 100, ifelse(scores <= 6, -100, 0))
}


#' One metric's row, or NULL when it cannot be computed honestly
#' @keywords internal
.twv_one_metric <- function(data, options, net_options, code, spec, weights, skipped) {
  spec <- trimws(as.character(spec %||% ""))

  if (identical(tolower(spec), "mean") || identical(tolower(spec), "nps_score")) {
    if (!(code %in% names(data))) {
      skipped$add(code, sprintf("column '%s' not in the data", code)); return(NULL)
    }
    sc <- .twv_scores(data, code, .twv_excluded(options, code))
    if (length(sc$scores) == 0) {
      skipped$add(code, "no valid numeric responses"); return(NULL)
    }
    w <- if (is.null(weights)) NULL else weights[sc$keep]
    if (identical(tolower(spec), "nps_score")) {
      st <- .twv_mean_stats(.twv_nps_scores(sc$scores), w)
      return(list(metric_type = "nps", value = st$value, base = st$base,
                  sd = st$sd, n = NA_integer_))
    }
    st <- .twv_mean_stats(sc$scores, w)
    return(list(metric_type = "mean", value = st$value, base = st$base,
                sd = st$sd, n = NA_integer_))
  }

  if (!grepl("^category:", spec, ignore.case = TRUE)) {
    skipped$add(code, sprintf("unsupported TrackingSpecs '%s'", spec)); return(NULL)
  }
  label <- trimws(strsplit(sub("^category:", "", spec, ignore.case = TRUE), "=", fixed = TRUE)[[1]][1])
  if (is.na(label) || !nzchar(label)) {
    skipped$add(code, "TrackingSpecs category has no value"); return(NULL)
  }
  members <- .twv_members(net_options %||% options, code, label)

  # Multi_Mention: the question has no single column, so an "any of" NET over
  # the member columns. Base = answered the question at all.
  if (!(code %in% names(data))) {
    # Two different questions are being asked of two different structures here.
    # WHICH option texts belong to the NET is the tracking definition's business
    # (net_options, above): that is the whole point of declaring the NET against
    # one wave's structure. But WHICH data column carries which option text is a
    # fact about THIS wave's data, so it must be read from THIS wave's own
    # structure. Resolving the columns through net_options mapped a recovered
    # wave's Q03_3 by the CURRENT wave's option order, so any wave whose options
    # were reordered or renumbered silently counted the wrong mentions
    # (review 2026-08, M14). net_options remains the fallback for a recovery run
    # given no structure of its own.
    cols <- .twv_mm_columns(options %||% net_options, data, code, members)
    if (length(cols$all_cols) == 0) {
      skipped$add(code, sprintf("no column '%s' and no '%s_n' columns", code, code))
      return(NULL)
    }
    if (length(cols$member_cols) == 0) {
      skipped$add(code, sprintf("NET '%s' matched none of the %s_n columns", label, code))
      return(NULL)
    }
    answered <- rowSums(!is.na(data[, cols$all_cols, drop = FALSE])) > 0
    hits <- rowSums(!is.na(data[, cols$member_cols, drop = FALSE])) > 0 & answered
    base <- sum(answered)
    if (base == 0) { skipped$add(code, "nobody answered the question"); return(NULL) }
    # Weighted wave -> weighted percentage (the weights argument was silently
    # ignored on proportion paths; review 2026-08, I22). base stays the
    # respondent count, matching the mean path's base semantics.
    w <- if (is.null(weights)) rep(1, nrow(data)) else weights
    wbase <- sum(w[answered])
    if (!is.finite(wbase) || wbase <= 0) {
      skipped$add(code, "weights sum to zero over the answered base"); return(NULL)
    }
    return(list(metric_type = "proportion", value = sum(w[hits]) / wbase * 100,
                base = base, sd = NULL, n = sum(hits)))
  }

  # Single-response proportion. DK / NA stay IN the base: that is what the
  # published percentages are formed on (verified on CCPB Q11).
  vals <- data[[code]]

  # An unresolvable category must SKIP AND NAME, never compute 0% under PASS
  # (review 2026-08, I22). A category resolves through a BoxCategory (NET), an
  # OptionText, or a value actually present in this wave's data column (e.g.
  # category:10 on a rating). A label matching NONE of the three is a typo or
  # a NET whose tags are missing from the supplied structure. Without a
  # structure the data-value test alone applies only when it can (documented
  # literal-label fallback stands otherwise).
  opts_src <- net_options %||% options
  if (!is.null(opts_src) && is.data.frame(opts_src) && nrow(opts_src) > 0 &&
      all(c("QuestionCode", "OptionText") %in% names(opts_src))) {
    roots <- sub("_[0-9]+$", "", trimws(as.character(opts_src$QuestionCode)))
    q_opts <- tracking_norm(opts_src$OptionText[roots == code])
    in_structure <- length(q_opts) == 0 || any(q_opts %in% members)
    in_data <- any(tracking_norm(vals) %in% members, na.rm = TRUE)
    if (!in_structure && !in_data) {
      skipped$add(code, sprintf(
        "category '%s' matches no BoxCategory, no OptionText and no data value of %s",
        label, code))
      return(NULL)
    }
  }
  answered <- !is.na(vals)
  base <- sum(answered)
  if (base == 0) { skipped$add(code, "nobody answered the question"); return(NULL) }
  # Weighted wave -> weighted percentage (weights were silently ignored here;
  # review 2026-08, I22). base stays the respondent count.
  hit_rows <- answered & tracking_norm(vals) %in% members
  w <- if (is.null(weights)) rep(1, length(vals)) else weights
  wbase <- sum(w[answered])
  if (!is.finite(wbase) || wbase <= 0) {
    skipped$add(code, "weights sum to zero over the answered base"); return(NULL)
  }
  list(metric_type = "proportion", value = sum(w[hit_rows]) / wbase * 100,
       base = base, sd = NULL, n = sum(hit_rows))
}


#' Build a wave's tracking values table from its respondent-level data
#'
#' Recovers the value, base and (for means/NPS) standard deviation of every
#' tracked metric for one wave, in the exact shape
#' `aggregate_wave_contributions()` consumes, so a historical wave whose raw
#' data survives can carry real significance instead of plotting untested.
#'
#' @param data The wave's respondent-level data frame.
#' @param mapping QuestionMap body: QuestionCode + TrackingSpecs (`mean`,
#'   `nps_score`, or `category:<value>`). One row per tracked metric.
#' @param options Survey_Structure Options body **for this wave**, supplying
#'   ExcludeFromIndex (which options leave a mean) and, unless `net_options` is
#'   given, BoxCategory (NET membership).
#' @param wave The wave label written into the `wave` column (e.g. "2025").
#' @param net_options Optional Options body carrying the **tracking** NET
#'   definitions, when they are declared against a different wave's structure
#'   than the one being computed. The two concerns genuinely differ: what a wave
#'   excludes from its mean is a fact about that wave's own questionnaire, while
#'   a NET's membership is a fact about the tracking series and must match the
#'   label the current wave's report emits. Members are matched by normalised
#'   OptionText, so wording that is stable across waves resolves; wording that
#'   drifted does not, and the metric is skipped and named rather than guessed.
#' @param weights Optional column name in `data` holding respondent weights, or
#'   a numeric vector. Absent = unweighted, and every figure reduces to the
#'   plain unweighted form.
#' @param base_filters Optional named list, metric code -> R filter expression
#'   (e.g. `list(Q26 = 'S11 == "Presell"')`), for metrics whose published series
#'   was formed on a filtered base. Applied via apply_base_filter().
#'
#' @return A list with structure:
#'   \item{status}{"PASS" when every metric computed, "PARTIAL" when some were
#'     skipped, "REFUSED" when nothing could be done}
#'   \item{result}{data frame: metric_id, wave, metric_type, value, base, sd, n}
#'   \item{skipped}{data frame of metric_id + reason for every metric not
#'     computed. Named, never silent}
#'   \item{warnings}{character vector of the same reasons}
#'
#' @examples
#' \dontrun{
#'   res <- wave_values_from_microdata(dat, mapping, options, wave = "2025",
#'                                     base_filters = list(Q26 = 'S11 == "Presell"'))
#'   if (res$status != "REFUSED") utils::write.csv(res$result, "values.csv")
#' }
#'
#' @export
wave_values_from_microdata <- function(data, mapping, options = NULL, wave,
                                       weights = NULL, base_filters = NULL,
                                       net_options = NULL) {
  if (!is.data.frame(data) || nrow(data) == 0) {
    return(.twv_refuse("DATA_MISSING", "`data` must be a non-empty data frame",
                       "Pass the wave's respondent-level data frame."))
  }
  if (!is.data.frame(mapping) || nrow(mapping) == 0 ||
      !all(c("QuestionCode", "TrackingSpecs") %in% names(mapping))) {
    return(.twv_refuse("CFG_MAPPING_INVALID",
                       "`mapping` must be a data frame with QuestionCode and TrackingSpecs",
                       "Pass the QuestionMap sheet of the tracking question mapping workbook."))
  }
  if (missing(wave) || is.null(wave) || !nzchar(as.character(wave))) {
    return(.twv_refuse("CFG_WAVE_MISSING", "`wave` is required",
                       "Pass the wave label, e.g. wave = \"2025\"."))
  }

  wcol <- NULL
  if (!is.null(weights)) {
    wcol <- if (length(weights) == 1 && is.character(weights)) {
      if (!(weights %in% names(data))) {
        return(.twv_refuse("DATA_WEIGHT_MISSING",
                           sprintf("weight column '%s' is not in the data", weights),
                           "Pass a column name present in `data`, or omit `weights`."))
      }
      suppressWarnings(as.numeric(data[[weights]]))
    } else as.numeric(weights)
    if (length(wcol) != nrow(data)) {
      return(.twv_refuse("DATA_WEIGHT_LENGTH", "weights must be one per row",
                         "Pass a vector the same length as nrow(data)."))
    }
    # A missing/invalid weight must refuse, not silently NA every mean under
    # PASS (review 2026-08, I22): "skipped and NAMED, never guessed" is this
    # file's own contract.
    n_bad <- sum(!is.finite(wcol) | wcol < 0)
    if (n_bad > 0) {
      return(.twv_refuse("DATA_WEIGHT_INVALID",
                         sprintf("%d weight value(s) are missing or invalid (NA/negative/non-numeric)", n_bad),
                         "Fill or filter the weight column before recovery - a missing weight silently voids every weighted statistic."))
    }
  }

  skipped <- local({
    codes <- character(0); reasons <- character(0)
    list(add = function(code, reason) {
           codes <<- c(codes, code); reasons <<- c(reasons, reason)
         },
         get = function() data.frame(metric_id = codes, reason = reasons,
                                     stringsAsFactors = FALSE))
  })

  codes <- trimws(as.character(mapping$QuestionCode))
  specs <- as.character(mapping$TrackingSpecs)
  rows <- list()
  for (i in seq_along(codes)) {
    code <- codes[i]
    if (is.na(code) || !nzchar(code)) next

    d <- data; w <- wcol
    bf <- if (is.null(base_filters)) NULL else base_filters[[code]]
    if (!is.null(bf) && nzchar(trimws(as.character(bf)))) {
      if (!exists("apply_base_filter", mode = "function")) {
        skipped$add(code, "base_filter given but filter_utils.R is not loaded"); next
      }
      d <- tryCatch(apply_base_filter(data, as.character(bf)), error = function(e) NULL)
      if (is.null(d) || !is.data.frame(d) || nrow(d) == 0) {
        skipped$add(code, sprintf("base filter '%s' matched no rows", bf)); next
      }
      if (!is.null(wcol)) w <- wcol[d$.original_row]
    }

    got <- .twv_one_metric(d, options, net_options, code, specs[i], w, skipped)
    if (is.null(got)) next
    rows[[length(rows) + 1]] <- data.frame(
      metric_id = code, wave = as.character(wave),
      metric_type = got$metric_type, value = got$value, base = got$base,
      sd = if (is.null(got$sd)) NA_real_ else got$sd,
      n = got$n, stringsAsFactors = FALSE)
  }

  skips <- skipped$get()
  if (length(rows) == 0) {
    msg <- "No metric could be computed from this wave's data."
    cat("\n=== TURAS: wave values ===\n", msg, "\n", sep = "")
    if (nrow(skips) > 0) {
      cat(paste0("  - ", skips$metric_id, ": ", skips$reason, collapse = "\n"), "\n")
    }
    return(list(status = "REFUSED", code = "DATA_NO_METRICS", message = msg,
                how_to_fix = paste("Check that the mapping's QuestionCodes match",
                                   "the data's column names for this wave."),
                result = NULL, skipped = skips, warnings = skips$reason))
  }

  out <- do.call(rbind, rows)
  if (nrow(skips) > 0) {
    cat(sprintf("\n[TURAS] wave %s: %d metrics computed, %d skipped:\n",
                as.character(wave), nrow(out), nrow(skips)))
    cat(paste0("  - ", skips$metric_id, ": ", skips$reason, collapse = "\n"), "\n")
  }
  list(status = if (nrow(skips) == 0) "PASS" else "PARTIAL",
       result = out, skipped = skips, warnings = skips$reason)
}


#' Reconcile computed wave values against the figures already published
#'
#' The audit step that makes a recovered wave trustworthy: every recomputed
#' figure is checked against the number that wave actually published. A metric
#' that lands on its published figure is corroborated by a source outside this
#' calculation; one that does not is a definition question to answer BEFORE the
#' values are used, not a rounding curiosity.
#'
#' Published figures are usually rounded, so the default tolerances are one
#' rounding step: 0.05 for means (1 decimal) and 0.5 for percentages (whole
#' numbers). NPS is treated as a percentage.
#'
#' @param values A `wave_values_from_microdata()` result data frame.
#' @param published Named numeric (or a data frame with metric_id + value) of the
#'   figures that wave published.
#' @param tol_mean,tol_pct Tolerances; defaults are one rounding step.
#'
#' @return A list with structure:
#'   \item{status}{"PASS" when every comparable metric reconciles, else "PARTIAL"}
#'   \item{result}{data frame: metric_id, metric_type, computed, published, diff,
#'     reconciles}
#'   \item{message}{one-line summary, e.g. "51 of 52 reconcile"}
#'
#' @export
reconcile_wave_values <- function(values, published, tol_mean = 0.05, tol_pct = 0.5) {
  if (!is.data.frame(values) || nrow(values) == 0) {
    return(.twv_refuse("DATA_MISSING", "`values` must be a non-empty data frame",
                       "Pass the $result of wave_values_from_microdata()."))
  }
  if (is.data.frame(published)) {
    if (!all(c("metric_id", "value") %in% names(published))) {
      return(.twv_refuse("CFG_PUBLISHED_INVALID",
                         "`published` data frame needs metric_id and value columns",
                         "Pass a named numeric vector, or a data frame with those columns."))
    }
    pub <- suppressWarnings(as.numeric(published$value))
    names(pub) <- trimws(as.character(published$metric_id))
  } else {
    pub <- suppressWarnings(as.numeric(published))
    names(pub) <- names(published)
  }

  got <- pub[values$metric_id]
  tol <- ifelse(values$metric_type == "mean", tol_mean, tol_pct)
  diff <- values$value - got
  # unname: `got` carries names (with NA names for metrics that have no
  # published figure); a single NA name would otherwise become data.frame row
  # names and abort with "row names contain missing values" (review 2026-08).
  ok <- unname(!is.na(got) & abs(diff) <= tol + 1e-9)

  out <- data.frame(metric_id = values$metric_id, metric_type = values$metric_type,
                    computed = values$value, published = unname(got), diff = unname(diff),
                    reconciles = ok, stringsAsFactors = FALSE)
  comparable <- !is.na(out$published)
  msg <- sprintf("%d of %d comparable metrics reconcile with the published figures",
                 sum(ok), sum(comparable))
  cat(sprintf("\n[TURAS] %s\n", msg))
  bad <- out[comparable & !out$reconciles, , drop = FALSE]
  if (nrow(bad) > 0) {
    cat("  NOT reconciled - resolve the definition before using these values:\n")
    cat(paste0(sprintf("  - %s: computed %.4f vs published %.4f (%+.4f)",
                       bad$metric_id, bad$computed, bad$published, bad$diff),
               collapse = "\n"), "\n")
  }
  if (any(!comparable)) {
    cat(sprintf("  (%d metric(s) had no published figure to check against)\n", sum(!comparable)))
  }
  # An empty comparable slice must not pass vacuously. All(logical(0)) is TRUE,
  # which turned "nothing was cross-checked" into "Clean." (review 2026-08, C5).
  if (sum(comparable) == 0L) {
    msg <- "no published figures for this wave - nothing was cross-checked"
    cat(sprintf("[TURAS] WARNING: %s\n", msg))
    return(list(status = "PARTIAL", result = out, message = msg))
  }
  list(status = if (all(ok[comparable])) "PASS" else "PARTIAL",
       result = out, message = msg)
}


#' Splice Recovered Wave Values Into a Values Table
#'
#' Replaces the target wave's rows with the recovered figures and INSERTS rows
#' for computed metrics the table has no (metric_id, wave) row for. The splice
#' used to replace only, so recovering a wave absent from the table silently
#' wrote nothing (production review 2026-08, C5). History rows are never touched.
#'
#' @param values The full values table (data frame with at least metric_id and
#'   wave columns; base/sd columns are added when missing).
#' @param computed A `wave_values_from_microdata()` result data frame
#'   (metric_id, wave, metric_type, value, base, sd, ...).
#' @param wave The wave label being recovered.
#'
#' @return A list with structure:
#'   \item{status}{"PASS"}
#'   \item{values}{the spliced table}
#'   \item{replaced}{number of existing rows updated}
#'   \item{inserted}{number of new rows appended}
#'
#' @export
splice_wave_values <- function(values, computed, wave) {
  if (!is.data.frame(values) || !all(c("metric_id", "wave") %in% names(values))) {
    return(.twv_refuse("DATA_VALUES_INVALID",
                       "`values` must be a data frame with metric_id and wave columns",
                       "Pass the values table as read from its CSV."))
  }
  if (!is.data.frame(computed) || nrow(computed) == 0) {
    return(.twv_refuse("DATA_MISSING", "`computed` must be a non-empty data frame",
                       "Pass the $result of wave_values_from_microdata()."))
  }
  for (col in c("metric_type", "base", "sd")) {
    if (!(col %in% names(values))) values[[col]] <- NA
  }
  replaced <- 0L
  inserted <- 0L
  for (i in seq_len(nrow(computed))) {
    r <- computed[i, ]
    hit <- values$metric_id == r$metric_id & as.character(values$wave) == as.character(wave)
    if (any(hit)) {
      values$value[hit] <- r$value
      values$base[hit]  <- r$base
      values$sd[hit]    <- r$sd
      replaced <- replaced + sum(hit)
    } else {
      add <- data.frame(metric_id = r$metric_id, wave = as.character(wave),
                        metric_type = r$metric_type, value = r$value,
                        base = r$base, sd = r$sd, stringsAsFactors = FALSE)
      for (col in setdiff(names(values), names(add))) add[[col]] <- NA
      values <- rbind(values, add[, names(values), drop = FALSE])
      inserted <- inserted + 1L
    }
  }
  cat(sprintf("[TURAS] splice: %d row(s) replaced, %d inserted for wave %s\n",
              replaced, inserted, as.character(wave)))
  list(status = "PASS", values = values, replaced = replaced, inserted = inserted)
}


#' Console-visible TRS refusal (Turas runs in Shiny, errors must reach the console)
#' @keywords internal
.twv_refuse <- function(code, message, how_to_fix) {
  cat("\n=== TURAS ERROR ===\n")
  cat("Context: tracking_wave_values\n")
  cat("Code:", code, "\n")
  cat("Message:", message, "\n")
  cat("Fix:", how_to_fix, "\n")
  cat("===================\n\n")
  list(status = "REFUSED", code = code, message = message,
       how_to_fix = how_to_fix, result = NULL)
}

# ==============================================================================
# END OF TRACKING_WAVE_VALUES.R
# ==============================================================================
