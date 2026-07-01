# ==============================================================================
# TABS MODULE — DATA_QUAL ISLAND BUILDER (records -> schema + confidentiality)
# ==============================================================================
#
# Assembles the DATA_QUAL island from classified questions + the respondent master:
# per-question records keyed by the anonymous index, carrying the verbatim, the
# noteworthy tier, sentiment, per-mention theme valences and rating. Applies the
# verbatim-text confidentiality dial (hidden / redacted / full) with an ingest-time
# PII scrub, so no raw text enters the island unless the mode permits it.
#
# Schema per QUALITATIVE_TAB_PLAN.md §11. The banner + theme-as-quant serialisation
# into DATA_AGG/DATA_MICRO is a separate step (the demographic-cuts dial is honoured
# there and in the JS); this file produces the verbatim/record layer only.
#
# NOTE ON SERIALISATION: a hidden verbatim is stored as NA_character_ so jsonlite
# (na = "null") emits JSON null, which the JS renders as "[quote hidden in this copy]".
#
# Depends on (sourced by the pipeline): qual_workbook_reader.R. Run the tests with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_island_builder.R")
# ==============================================================================

# Verbatim-text confidentiality modes (dial 2; default hidden = numbers-only ship).
QUAL_TEXT_MODES <- c("hidden", "redacted", "full")
# Report-level default for the noteworthy tier filter (dial honoured in the JS).
QUAL_NOTEWORTHY_DEFAULTS <- c("all", "noteworthy", "must_read")

# Direct-identifier patterns scrubbed in REDACTED mode. These catch DIRECT identifiers
# (email / URL / phone); contextual identifiers ("the only male diploma lecturer") are
# NOT caught — that honest limit is documented in QUALITATIVE_TAB_BUILD_NOTES.md §D.
QUAL_PII_PATTERNS <- c(
  email = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
  url   = "https?://[^[:space:]]+",
  www   = "www\\.[^[:space:]]+",
  phone = "\\+?[0-9][0-9 .\\-]{7,}[0-9]"
)
QUAL_PII_REPLACEMENT <- "[redacted]"

#' Scrub direct-identifier PII from a verbatim (REDACTED mode), counting redactions.
#' @param text A verbatim string (or NA/"").
#' @return list(text, redactions) — `text` with identifiers replaced, `redactions` count.
qual_scrub_text <- function(text) {
  if (is.null(text) || is.na(text) || !nzchar(text)) return(list(text = text, redactions = 0L))
  scrubbed <- text
  total <- 0L
  for (pattern in QUAL_PII_PATTERNS) {
    matches <- gregexpr(pattern, scrubbed, perl = TRUE)[[1]]
    n <- if (length(matches) == 1L && matches[1] == -1L) 0L else length(matches)
    if (n > 0L) {
      scrubbed <- gsub(pattern, QUAL_PII_REPLACEMENT, scrubbed, perl = TRUE)
      total <- total + n
    }
  }
  list(text = scrubbed, redactions = total)
}

#' Apply the verbatim-text confidentiality dial to one comment.
#' @param text The raw verbatim.
#' @param mode One of QUAL_TEXT_MODES.
#' @return list(text, redactions); `text` is NULL when hidden (serialised to null).
qual_apply_text_mode <- function(text, mode) {
  if (identical(mode, "hidden")) return(list(text = NULL, redactions = 0L))
  if (identical(mode, "redacted")) return(qual_scrub_text(text))
  list(text = text, redactions = 0L)
}

#' Validate a confidentiality text mode, defaulting safely to "hidden".
qual_validate_text_mode <- function(mode) {
  if (length(mode) == 1L && !is.na(mode) && mode %in% QUAL_TEXT_MODES) mode else "hidden"
}

#' Read a config value with a default when missing/NA.
qual_cfg <- function(config, key, default) {
  value <- config[[key]]
  if (is.null(value) || (length(value) == 1L && is.na(value))) default else value
}

#' Build one record's island entry, remapping theme labels to ids and applying text mode.
#' @param rec A reader record (id, text, noteworthy_tier, sentiment, rating, themeVals).
#' @param idx The respondent's anonymous 0-based index.
#' @param theme_id_map Named list mapping theme label -> 0-based theme id.
#' @param text_mode One of QUAL_TEXT_MODES.
#' @param demo_labels Banner-dimension labels to carry as record demographics (empty
#'   when the demographic-cuts dial is "block", so no demographics enter the island).
#' @return list(record, redactions).
qual_build_record_island <- function(rec, idx, theme_id_map, text_mode, demo_labels) {
  applied <- qual_apply_text_mode(rec$text, text_mode)
  theme_vals <- list()
  for (label in names(rec$themeVals)) {
    id <- theme_id_map[[label]]
    if (!is.null(id)) theme_vals[[as.character(id)]] <- rec$themeVals[[label]]
  }
  record <- list(
    idx = idx,
    text = if (is.null(applied$text)) NA_character_ else applied$text,
    noteworthy = isTRUE(rec$noteworthy), tier = rec$noteworthy_tier,
    sentiment = rec$sentiment, rating = rec$rating, themeVals = theme_vals
  )
  if (length(demo_labels)) {
    demos <- list()
    for (label in demo_labels) {
      value <- rec$demos[[label]]
      demos[[label]] <- if (is.null(value) || is.na(value)) NA_character_ else as.character(value)
    }
    record$demos <- demos
  }
  list(record = record, redactions = applied$redactions)
}

#' k-anonymise per-respondent demographic tags (demographic_cuts = "safe").
#'
#' For each respondent keep the broadest combination of demographic tags whose
#' matching-respondent count stays >= k, dropping finer tags that would narrow the group
#' below k. Greedy: add tags biggest-group-first, keep a tag only while the shown combination
#' still covers >= k respondents. Every displayed tag-combination therefore covers >= k people,
#' so no comment identifies a group smaller than the threshold (e.g. "Admin" shows when there
#' are 70, but "Admin + <1yr" is suppressed when only 3 share it). Direct identifiers in the
#' verbatim TEXT are a separate dial (qual_confidentiality_mode).
#'
#' @param demo_rows List, one per respondent, each a named list(label -> value or NA).
#' @param labels Demographic dimension labels (the columns to consider).
#' @param k Reporting threshold (>= 2); k <= 1 returns the rows unchanged (nothing is unsafe).
#' @return A list parallel to demo_rows; each respondent's named list with unsafe tags -> NA.
qual_kanon_tags <- function(demo_rows, labels, k) {
  n <- length(demo_rows)
  if (n == 0L || length(labels) == 0L || !is.finite(k) || k <= 1L) return(demo_rows)
  M <- matrix(NA_character_, nrow = n, ncol = length(labels), dimnames = list(NULL, labels))
  for (i in seq_len(n)) {
    row <- demo_rows[[i]]
    for (lbl in labels) {
      v <- if (is.null(row)) NULL else row[[lbl]]
      if (!is.null(v) && length(v) == 1L && !is.na(v)) M[i, lbl] <- as.character(v)
    }
  }
  match_count <- function(cols, vals) {
    keep <- rep(TRUE, n)
    for (t in seq_along(cols)) keep <- keep & !is.na(M[, cols[t]]) & M[, cols[t]] == vals[t]
    sum(keep)
  }
  cell <- function(i, j) unname(M[i, j])                       # matrix names must not leak into tags
  safe_for_row <- function(i) {
    out <- stats::setNames(as.list(rep(NA_character_, length(labels))), labels)
    present <- unname(which(!is.na(M[i, ])))
    if (length(present)) {
      marg <- vapply(present, function(j) match_count(j, cell(i, j)), integer(1))
      ord <- present[order(-marg, present)]                    # broadest group first
      keep_cols <- integer(0); keep_vals <- character(0)
      for (j in ord) {
        if (match_count(c(keep_cols, j), c(keep_vals, cell(i, j))) >= k) {
          keep_cols <- c(keep_cols, j); keep_vals <- c(keep_vals, cell(i, j))
        }
      }
      for (j in keep_cols) out[[labels[j]]] <- cell(i, j)
    }
    out
  }
  cache <- new.env(parent = emptyenv()); res <- vector("list", n)
  for (i in seq_len(n)) {
    key <- paste(ifelse(is.na(M[i, ]), "", M[i, ]), collapse = "")
    if (is.null(cache[[key]])) assign(key, safe_for_row(i), envir = cache)
    res[[i]] <- get(key, envir = cache)
  }
  res
}

#' Build the island entry for one question (themed or raw).
#' @param question A classified question from the reader.
#' @param id_to_idx Named map from respondent id to 0-based index (the master).
#' @param text_mode One of QUAL_TEXT_MODES.
#' @param demo_labels Banner-dimension labels to carry as record demographics.
#' @param demo_map Optional named list (respondent id -> k-anonymised demos) used by the
#'   "safe" tagging mode; when supplied it replaces each record's raw demographics.
#' @return The per-question island list (code, title, type, base, themes, records, meta).
qual_build_question_island <- function(question, id_to_idx, text_mode, demo_labels = character(0),
                                       demo_map = NULL) {
  themes <- question$roles$themes
  theme_list <- lapply(seq_along(themes),
                       function(i) list(id = i - 1L, label = themes[[i]]$label))
  theme_id_map <- stats::setNames(as.list(seq_along(themes) - 1L),
                                  vapply(themes, function(t) t$label, character(1)))
  records <- list()
  redactions <- 0L
  for (rec in question$records) {
    # Single-bracket lookup returns NA for an unknown id (the [[ ]] form errors); this
    # matters for the Phase-2 join, where a qual id may be absent from the host index.
    slot <- unname(id_to_idx[rec$id])
    if (length(slot) != 1L || is.na(slot)) next
    if (!is.null(demo_map)) rec$demos <- demo_map[[as.character(rec$id)]]   # "safe" mode k-anon tags
    built <- qual_build_record_island(rec, slot, theme_id_map, text_mode, demo_labels)
    records[[length(records) + 1L]] <- built$record
    redactions <- redactions + built$redactions
  }
  list(code = question$code, title = question$title, type = question$type,
       sheet = question$sheet,
       base = list(answered = length(records), asked = NA_integer_),
       themes = theme_list, records = records,
       meta = list(dropped_codes = question$meta$dropped_codes,
                   n_records = length(records),
                   pii_scrubbed = redactions > 0L, redactions = redactions))
}

#' Build the full DATA_QUAL island from questions + the respondent master + config.
#'
#' @param questions List of classified questions from `qual_read_workbook()`.
#' @param master The respondent master from `qual_build_respondent_master()`.
#' @param config List with `text_mode`, `demographic_cuts`, `noteworthy_default`.
#' @return The DATA_QUAL island list (textMode, demographicCuts, noteworthyDefault, n, questions).
#' @examples
#' \dontrun{
#'   island <- qual_build_data_qual(res$questions, master,
#'                                  list(text_mode = "hidden", demographic_cuts = "allow"))
#' }
qual_build_data_qual <- function(questions, master, config = list()) {
  text_mode <- qual_validate_text_mode(qual_cfg(config, "text_mode", "hidden"))
  raw_cuts <- qual_cfg(config, "demographic_cuts", "allow")
  cuts <- if (identical(raw_cuts, "block")) "block" else
          if (identical(raw_cuts, "safe")) "safe" else "allow"
  # Comment tagging is governed by the demographic_cuts dial, independent of the reporting
  # threshold: "block" ships no demographics at all (source-safe, Total-only); "allow" ships
  # every tag (internal — a fine crossing can identify on a small sample); "safe" k-anonymises
  # the tags against min_reporting_base, so a comment shows only the broadest combination of
  # tags that still covers >= k people ("Admin" when there are 70, not "Admin + <1yr" when 3).
  default_tier <- qual_cfg(config, "noteworthy_default", "all")
  if (!default_tier %in% QUAL_NOTEWORTHY_DEFAULTS) default_tier <- "all"
  # Demographics ride the island unless blocked (then the tab is Total-only, no demos leak).
  banner_dims <- if (identical(cuts, "block") || is.null(master$banner_dims)) list() else master$banner_dims
  demo_labels <- vapply(banner_dims, function(d) d$label, character(1))
  # "safe" mode: pre-compute the k-anonymised tag subset per respondent, so only tags that
  # survive the threshold ever enter the island (View-Source shows nothing finer than k).
  demo_map <- NULL
  if (identical(cuts, "safe") && length(demo_labels)) {
    k <- suppressWarnings(as.numeric(qual_cfg(config, "min_reporting_base", 1)))
    if (length(k) == 1L && !is.na(k) && k > 1) {
      seen <- new.env(parent = emptyenv()); ids <- character(0); rows <- list()
      for (q in questions) for (rec in q$records) {
        id <- as.character(rec$id)
        if (is.null(seen[[id]])) {
          assign(id, TRUE, envir = seen)
          ids <- c(ids, id); rows[[length(rows) + 1L]] <- rec$demos
        }
      }
      demo_map <- stats::setNames(qual_kanon_tags(rows, demo_labels, k), ids)
    }
  }
  islands <- lapply(questions,
                    function(q) qual_build_question_island(q, master$id_to_idx, text_mode, demo_labels, demo_map))
  out <- list(textMode = text_mode, demographicCuts = cuts, noteworthyDefault = default_tier,
              n = master$n, questions = islands)
  if (length(demo_labels)) {
    out$demographics <- lapply(banner_dims, function(d) list(label = d$label, values = d$values))
  }
  out
}
