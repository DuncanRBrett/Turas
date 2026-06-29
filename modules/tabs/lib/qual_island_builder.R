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
#' @return list(record, redactions).
qual_build_record_island <- function(rec, idx, theme_id_map, text_mode) {
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
  list(record = record, redactions = applied$redactions)
}

#' Build the island entry for one question (themed or raw).
#' @param question A classified question from the reader.
#' @param id_to_idx Named map from respondent id to 0-based index (the master).
#' @param text_mode One of QUAL_TEXT_MODES.
#' @return The per-question island list (code, title, type, base, themes, records, meta).
qual_build_question_island <- function(question, id_to_idx, text_mode) {
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
    built <- qual_build_record_island(rec, slot, theme_id_map, text_mode)
    records[[length(records) + 1L]] <- built$record
    redactions <- redactions + built$redactions
  }
  list(code = question$code, title = question$title, type = question$type,
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
  cuts <- if (identical(qual_cfg(config, "demographic_cuts", "allow"), "block")) "block" else "allow"
  default_tier <- qual_cfg(config, "noteworthy_default", "all")
  if (!default_tier %in% QUAL_NOTEWORTHY_DEFAULTS) default_tier <- "all"
  islands <- lapply(questions,
                    function(q) qual_build_question_island(q, master$id_to_idx, text_mode))
  list(textMode = text_mode, demographicCuts = cuts, noteworthyDefault = default_tier,
       n = master$n, questions = islands)
}
