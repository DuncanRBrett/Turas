# ==============================================================================
# TABS MODULE. DATA_QUAL ISLAND BUILDER (records -> schema + confidentiality)
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
# Verbatim scope (dial 3): which comments ship readable text. "all" ships every comment
# except hide-marked ones; "noteworthy" ships only tier >= 1 (noteworthy/must-read/
# priority). Orthogonal to text mode. Scope picks WHICH comments, text mode picks HOW
# their text is treated. Every comment is counted in the distribution regardless.
QUAL_VERBATIM_SCOPES <- c("all", "noteworthy")
# Report-level default for the noteworthy tier filter (dial honoured in the JS).
QUAL_NOTEWORTHY_DEFAULTS <- c("all", "noteworthy", "must_read", "priority")

# Direct-identifier patterns scrubbed in REDACTED mode. These catch DIRECT identifiers
# (email / URL / phone); contextual identifiers ("the only male diploma lecturer") are
# NOT caught. That honest limit is documented in QUALITATIVE_TAB_BUILD_NOTES.md §D.
QUAL_PII_PATTERNS <- c(
  email = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
  url   = "https?://[^[:space:]]+",
  www   = "www\\.[^[:space:]]+",
  phone = "\\+?[0-9][0-9 .\\-]{7,}[0-9]"
)
QUAL_PII_REPLACEMENT <- "[redacted]"

#' Scrub direct-identifier PII from a verbatim (REDACTED mode), counting redactions.
#' @param text A verbatim string (or NA/"").
#' @return list(text, redactions): `text` with identifiers replaced, `redactions` count.
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

#' Whether a record's verbatim text ships, given the report's verbatim scope.
#'
#' The scope decides which comments are readable; every comment is counted in the theme
#' distribution regardless (its text is the only thing withheld). A comment is shown when:
#'   - scope "all", always, UNLESS it carries a hide marker; or
#'   - scope "noteworthy", only when it is tier >= 1 (noteworthy / must-read / priority),
#'                          and a hide marker still withholds it (redundant, since a hide
#'                          marker is tier 0, but explicit).
#' An unthemed, un-noteworthy comment under "noteworthy" scope is simply not shown. It
#' still counts, it just carries no readable text (Duncan's rule: theme all, show some).
#' @param rec A reader record (noteworthy_tier, hidden).
#' @param scope "all" or "noteworthy".
#' @return TRUE when the verbatim text should ship.
qual_verbatim_shows <- function(rec, scope) {
  if (isTRUE(rec$hidden)) return(FALSE)
  if (identical(scope, "noteworthy")) return(isTRUE(rec$noteworthy_tier >= 1L))
  TRUE
}

#' Which text stands in for a comment where the context is not a theme page.
#'
#' The precedence, from QUALITATIVE_EXTRACTS_PLAN.md section 4: the Lead-marked
#' fragment, else the comment's general fragment (a blank Theme cell or `all`),
#' else the first themed fragment, else the verbatim. A comment the analyst wrote
#' any extract for never falls back to its verbatim, because the extract exists
#' precisely so the whole comment does not ship.
#'
#' @param rec A reader record.
#' @return list(text, theme): `theme` is the theme LABEL when the chosen text is a
#'   themed fragment (so the report can name it), else NA.
qual_unscoped_text <- function(rec) {
  if (!is.null(rec$extract_lead)) {
    lead_theme <- rec$extract_lead_theme
    return(list(text = rec$extract_lead,
                theme = if (is.null(lead_theme)) NA_character_ else lead_theme))
  }
  if (!is.null(rec$extract_all)) return(list(text = rec$extract_all, theme = NA_character_))
  if (!is.null(rec$extract_general)) return(list(text = rec$extract_general, theme = NA_character_))
  if (length(rec$extracts)) {
    label <- names(rec$extracts)[[1]]
    return(list(text = rec$extracts[[label]], theme = label))
  }
  list(text = rec$text, theme = NA_character_)
}

#' Apply the confidentiality dial to a comment's per-theme fragments.
#'
#' Every fragment passes through the SAME dial as a verbatim, which is the whole
#' basis on which the release audit's declared textMode still describes the file:
#' hidden emits nothing, redacted scrubs each fragment and counts what it removed,
#' full ships them as typed.
#'
#' @param rec A reader record.
#' @param theme_id_map Named list mapping theme label -> 0-based theme id.
#' @param text_mode One of QUAL_TEXT_MODES.
#' @return list(extracts, all, redactions): `extracts` is keyed by theme id as a
#'   character, empty when nothing survives the dial.
qual_apply_extracts_text_mode <- function(rec, theme_id_map, text_mode) {
  out <- list(); redactions <- 0L
  for (label in names(rec$extracts)) {
    id <- theme_id_map[[label]]
    if (is.null(id)) next            # a theme the island does not carry
    applied <- qual_apply_text_mode(rec$extracts[[label]], text_mode)
    redactions <- redactions + applied$redactions
    if (!is.null(applied$text) && nzchar(applied$text)) out[[as.character(id)]] <- applied$text
  }
  all_applied <- if (is.null(rec$extract_all)) list(text = NULL, redactions = 0L)
                 else qual_apply_text_mode(rec$extract_all, text_mode)
  list(extracts = out, all = all_applied$text,
       redactions = redactions + all_applied$redactions)
}

#' Build one record's island entry, remapping theme labels to ids and applying text mode.
#' @param rec A reader record (id, text, noteworthy_tier, hidden, sentiment, rating, themeVals).
#' @param idx The respondent's anonymous 0-based index.
#' @param theme_id_map Named list mapping theme label -> 0-based theme id.
#' @param text_mode One of QUAL_TEXT_MODES.
#' @param demo_labels Banner-dimension labels to carry as record demographics (empty
#'   when the demographic-cuts dial is "block", so no demographics enter the island).
#' @param scope Verbatim scope ("all" or "noteworthy"): governs whether THIS record's
#'   text ships. A withheld record is emitted with text = null and suppressed = TRUE, so
#'   it still counts in the distribution but is never listed as a readable comment.
#' @param rid The respondent's opaque reader-key token (`qual_reader_keys`), or NULL.
#'   Emitted only when non-NULL, so an island built without the sidecar is byte-identical
#'   to the pre-I20 shape and the JS stays on legacy idx keying.
#' @return list(record, redactions).
qual_build_record_island <- function(rec, idx, theme_id_map, text_mode, demo_labels,
                                      scope = "all", rid = NULL, cut = NULL) {
  shows <- qual_verbatim_shows(rec, scope)
  # A withheld verbatim never enters the island as text (build-time confidentiality /
  # curation): no text mode, no PII scrub needed, nothing readable in the page source.
  # That covers its extracts too, which are the same respondent's words.
  unscoped <- if (shows) qual_unscoped_text(rec) else list(text = NULL, theme = NA_character_)
  applied <- if (shows) qual_apply_text_mode(unscoped$text, text_mode) else list(text = NULL, redactions = 0L)
  frag <- if (shows) qual_apply_extracts_text_mode(rec, theme_id_map, text_mode)
          else list(extracts = list(), all = NULL, redactions = 0L)
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
  # THE EXTRACTS. A fragment is quotable beside the themes the analyst named, and
  # nowhere else: under a theme with no fragment the comment is counted and shows no
  # text, exactly as a hide mark behaves. Emitted only when the workbook supplies
  # them, so an island built without an extracts sheet is byte-identical to one
  # built before this existed.
  if (length(frag$extracts)) record$extracts <- frag$extracts
  if (!is.null(frag$all) && nzchar(frag$all)) record$extractAll <- frag$all
  # hasExtracts cannot be inferred from the two fields above: a comment carrying only
  # a general fragment has neither, and still must not show that fragment beside a
  # theme it makes no claim about. It is gated on text having SURVIVED the dial:
  # under `hidden` (the default, numbers-only ship) no fragment and no verbatim
  # ships, and the flag on its own made the report drop those comments from every
  # theme list and then claim they were quoted elsewhere (review 2026-09-17, C3).
  if (shows && isTRUE(rec$has_extracts) && !is.null(applied$text)) record$hasExtracts <- TRUE
  # Which theme the unscoped text speaks to, when it is a themed fragment shown away
  # from that theme's page (the priority block, a pin, the story tab), so the report
  # can name it rather than presenting a fragment as the whole comment.
  if (shows && !is.null(applied$text) && !is.na(unscoped$theme)) {
    tid <- theme_id_map[[unscoped$theme]]
    if (!is.null(tid)) record$textTheme <- as.integer(tid)
  }
  # The stable reader key. Uniform random, so it discloses nothing under any privacy
  # dial (block / safe / hidden / aggregates-only): it is the ONE field that survives
  # a re-export, which is what stops a reader mark drifting onto another respondent.
  if (!is.null(rid) && length(rid) == 1L && !is.na(rid) && nzchar(rid)) record$rid <- as.character(rid)
  # suppressed = withheld from the readable list (scope or hide). Emitted only when true
  # so the JS drops it from the comment list while still counting it everywhere else;
  # absent (the common case) reads as false, keeping the island lean.
  if (!shows) record$suppressed <- TRUE
  # The split band (NPS Detractor/Passive/Promoter etc.) is a first-class report-level
  # axis, carried alongside sentiment, NOT a demographic tag, so it is never subject to
  # the demographic k-anonymisation (the band mirrors a closed question already reported).
  if (!is.null(rec$band) && !is.na(rec$band)) record$band <- as.character(rec$band)
  if (length(demo_labels)) {
    demos <- list()
    for (label in demo_labels) {
      value <- rec$demos[[label]]
      demos[[label]] <- if (is.null(value) || is.na(value)) NA_character_ else as.character(value)
    }
    record$demos <- demos
  }
  # The CUT: which level of each declared variable this comment's author falls
  # in, as the same level indices the aggregate cube keys its cells by. It is
  # what lets a live audience filter reach the comments on a build that carries
  # no respondent records. Only entries that survived the same k-anonymisation
  # the demographic tags get are here; a variable this comment cannot be placed
  # on is ABSENT, and the renderer leaves that comment out of a cut on it rather
  # than guessing. Omitted entirely when the question does not carry one, so a
  # records build's island is byte-identical to one built before this existed.
  if (!is.null(cut) && length(cut)) {
    kept <- list()
    for (nm in names(cut)) {
      v <- cut[[nm]]
      if (!is.null(v) && length(v) == 1L && !is.na(v)) kept[[nm]] <- as.integer(v)
    }
    if (length(kept)) record$cut <- kept
  }
  list(record = record, redactions = applied$redactions + frag$redactions)
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

#' k-anonymise demographic tags WITHIN each split band.
#'
#' Once a split-band segmented view exists, a respondent's band (NPS Detractor/Passive/
#' Promoter) is a VISIBLE quasi-identifier: a tag safe across everyone can still be unique
#' among (say) the 6 detractors. So a tag combination must clear k *within its band*, not
#' just overall. Respondents with no band ("") form one group; with a single group this is
#' identical to `qual_kanon_tags`, so the no-split case is unchanged.
#'
#' @param rows List of per-respondent demos (named list label -> value/NA), order = `ids`.
#' @param ids Respondent ids, parallel to `rows`.
#' @param bands Each respondent's split band ("" when none), parallel to `ids`.
#' @param labels Demographic dimension labels to consider.
#' @param k Reporting threshold.
#' @return A named list (id -> k-anonymised demos), preserving `ids` order.
qual_kanon_tags_by_group <- function(rows, ids, bands, labels, k) {
  n <- length(ids)
  out <- vector("list", n)
  if (n == 0L) return(stats::setNames(out, ids))
  groups <- split(seq_len(n), bands)
  for (g in groups) {
    kan <- qual_kanon_tags(rows[g], labels, k)
    for (j in seq_along(g)) out[[g[[j]]]] <- kan[[j]]
  }
  stats::setNames(out, ids)
}

#' Build the island entry for one question (themed or raw).
#' @param question A classified question from the reader.
#' @param id_to_idx Named map from respondent id to 0-based index (the master).
#' @param text_mode One of QUAL_TEXT_MODES.
#' @param demo_labels Banner-dimension labels to carry as record demographics.
#' @param demo_map Optional named list (respondent id -> k-anonymised demos) used by the
#'   "safe" tagging mode; when supplied it replaces each record's raw demographics.
#' @param scope Verbatim scope ("all" or "noteworthy"), passed to each record build.
#' @param rid_map Optional named character vector (respondent id -> reader token) from
#'   `qual_reader_keys()`. NULL (the default) builds the pre-I20 island shape.
#' @return The per-question island list (code, title, type, base, themes, records, meta).
qual_build_question_island <- function(question, id_to_idx, text_mode, demo_labels = character(0),
                                       demo_map = NULL, scope = "all", rid_map = NULL,
                                       cut_map = NULL, comment_key = "respondent") {
  themes <- question$roles$themes
  theme_list <- lapply(seq_along(themes),
                       function(i) list(id = i - 1L, label = themes[[i]]$label))
  theme_id_map <- stats::setNames(as.list(seq_along(themes) - 1L),
                                  vapply(themes, function(t) t$label, character(1)))
  records <- list()
  redactions <- 0L
  shipped_text <- FALSE
  for (rec in question$records) {
    # Single-bracket lookup returns NA for an unknown id (the [[ ]] form errors); this
    # matters for the Phase-2 join, where a qual id may be absent from the host index.
    slot <- unname(id_to_idx[rec$id])
    if (length(slot) != 1L || is.na(slot)) next
    if (!is.null(demo_map)) rec$demos <- demo_map[[as.character(rec$id)]]   # "safe" mode k-anon tags
    # QUESTION-LOCAL KEYS. Both the respondent index and the reader token are the
    # SAME value for a person in every question they answered, so either one joins
    # that person's comments into a profile. One comment can be anonymous while six
    # are not. Under "question" the record carries its position in THIS question and
    # no token at all, and nothing in the file says the two are one person.
    #
    # The cost, and it is a real one: a reader mark is then keyed by position, so a
    # re-export that shifts a comment's position moves the mark with the position
    # rather than with the comment. That is the trade the client-safe build makes,
    # and the analyst's own full build is unaffected.
    local_key <- identical(comment_key, "question")
    emit_idx <- if (local_key) length(records) else slot
    # Same single-bracket lookup discipline as id_to_idx: an id the sidecar has never
    # seen yields NA, which the record builder drops (that record simply keeps idx keying).
    rid <- if (local_key || is.null(rid_map)) NULL
           else unname(rid_map[as.character(rec$id)])
    cut <- if (is.null(cut_map)) NULL else cut_map[[as.character(rec$id)]]
    built <- qual_build_record_island(rec, emit_idx, theme_id_map, text_mode, demo_labels, scope,
                                      rid, cut)
    records[[length(records) + 1L]] <- built$record
    redactions <- redactions + built$redactions
    if (!is.null(built$record$text) && !is.na(built$record$text)) shipped_text <- TRUE
  }
  # The scrub RAN when the dial asked for it and there was text for it to run on.
  # Distinct from whether it found anything, which is `redactions`.
  scrub_ran <- identical(text_mode, "redacted") && shipped_text
  out <- list(code = question$code, title = question$title, type = question$type,
       sheet = question$sheet,
       base = list(answered = length(records), asked = NA_integer_),
       themes = theme_list, records = records,
       # scrub_ran and redactions are two different facts and used to be one badly
       # named field. pii_scrubbed was `redactions > 0`, so a question whose text
       # WAS scrubbed and held no identifiers to remove reported FALSE, and read as
       # "no privacy scrub was applied". An independent review drew exactly that
       # conclusion from a build that had scrubbed every comment.
       meta = list(dropped_codes = question$meta$dropped_codes,
                   n_records = length(records),
                   scrub_ran = scrub_ran, redactions = redactions))
  # A split-bearing question (band-unioned open-end) carries its split axis so the JS
  # can offer an All / <band> segmented view over the records.
  if (!is.null(question$split)) out$split <- question$split
  out
}

#' Build the full DATA_QUAL island from questions + the respondent master + config.
#'
#' @param questions List of classified questions from `qual_read_workbook()`.
#' @param master The respondent master from `qual_build_respondent_master()`.
#' @param config List with `text_mode`, `demographic_cuts`, `noteworthy_default`.
#' @param rid_map Optional named character vector (respondent id -> reader token) from
#'   `qual_reader_keys()`. When supplied each record carries a stable `rid` beside its
#'   `idx`, so reader marks survive a re-export. NULL builds the pre-I20 island shape.
#' @return The DATA_QUAL island list (textMode, demographicCuts, noteworthyDefault, n, questions).
#' @examples
#' \dontrun{
#'   island <- qual_build_data_qual(res$questions, master,
#'                                  list(text_mode = "hidden", demographic_cuts = "allow"))
#' }
qual_build_data_qual <- function(questions, master, config = list(), rid_map = NULL,
                                 cut_levels = NULL) {
  text_mode <- qual_validate_text_mode(qual_cfg(config, "text_mode", "hidden"))
  raw_cuts <- qual_cfg(config, "demographic_cuts", "allow")
  cuts <- if (identical(raw_cuts, "block")) "block" else
          if (identical(raw_cuts, "safe")) "safe" else "allow"
  # Comment tagging is governed by the demographic_cuts dial, independent of the reporting
  # threshold: "block" ships no demographics at all (source-safe, Total-only); "allow" ships
  # every tag (internal, a fine crossing can identify on a small sample); "safe" k-anonymises
  # the tags against min_reporting_base, so a comment shows only the broadest combination of
  # tags that still covers >= k people ("Admin" when there are 70, not "Admin + <1yr" when 3).
  default_tier <- qual_cfg(config, "noteworthy_default", "all")
  if (!default_tier %in% QUAL_NOTEWORTHY_DEFAULTS) default_tier <- "all"
  # Verbatim scope: which comments ship their readable text. "all" ships everything bar
  # hide-marked comments; "noteworthy" ships only tier >= 1 (plus hide still withholds).
  # Withheld comments are still counted in every distribution, only their text is gone.
  scope <- qual_cfg(config, "verbatim_scope", "all")
  if (!scope %in% QUAL_VERBATIM_SCOPES) scope <- "all"
  # Demographics ride the island unless blocked (then the tab is Total-only, no demos leak).
  banner_dims <- if (identical(cuts, "block") || is.null(master$banner_dims)) list() else master$banner_dims
  demo_labels <- vapply(banner_dims, function(d) d$label, character(1))
  # "safe" mode: pre-compute the k-anonymised tag subset per respondent, so only tags that
  # survive the threshold ever enter the island (View-Source shows nothing finer than k).
  demo_map <- NULL
  if (identical(cuts, "safe") && length(demo_labels)) {
    k <- suppressWarnings(as.numeric(qual_cfg(config, "min_reporting_base", 1)))
    if (!(length(k) == 1L && !is.na(k) && k > 1)) {
      # "safe" tagging IS the k-anonymity pass, so with k unset (default 1) there
      # is nothing to anonymise against: raw tags used to ship while the island
      # still declared demographicCuts:"safe". A label that overstates the
      # protection actually applied is worse than no label, so the declaration is
      # downgraded to match reality and the operator is told why
      # (review 2026-08-21, I-12).
      cuts <- "allow"
      cat("\n┌─── TURAS DISCLOSURE WARNING ───────────────────────────────┐\n")
      cat("│ qual_demographic_cuts = 'safe' needs min_reporting_base > 1 to\n")
      cat("│ have anything to anonymise against; it is currently ",
          if (length(k) == 1L && !is.na(k)) k else "unset", ".\n", sep = "")
      cat("│ Demographic tags would ship RAW while the report claimed 'safe',\n")
      cat("│ so the report now declares 'allow', which is what it is doing.\n")
      cat("│ Fix: set min_reporting_base (e.g. 10) to get k-anonymised tags,\n")
      cat("│ or set qual_demographic_cuts = block to ship no tags at all.\n")
      cat("└────────────────────────────────────────────────────────────┘\n\n")
    } else {
      # Collect each unique respondent's demos + their split band (the real, non-empty band
      # wins if they appear in both a split and a non-split question) so tags are k-anonymised
      # within the band. The band being a visible quasi-identifier once the segment exists.
      band_of <- new.env(parent = emptyenv()); ids <- character(0); rows <- list()
      for (q in questions) for (rec in q$records) {
        id <- as.character(rec$id)
        b <- if (is.null(rec$band) || is.na(rec$band)) "" else as.character(rec$band)
        if (!exists(id, envir = band_of, inherits = FALSE)) {
          assign(id, b, envir = band_of)
          ids <- c(ids, id); rows[[length(rows) + 1L]] <- rec$demos
        } else if (nzchar(b) && !nzchar(get(id, envir = band_of, inherits = FALSE))) {
          assign(id, b, envir = band_of)                 # upgrade "" -> the real band
        }
      }
      bands <- vapply(ids, function(id) get(id, envir = band_of, inherits = FALSE), character(1))
      demo_map <- qual_kanon_tags_by_group(rows, ids, bands, demo_labels, k)
    }
  }
  # THE CUT. Which level of each declared variable each comment's author falls
  # in, so a live audience filter can reach the comments on a build that carries
  # no respondent records. The levels are the aggregate cube's own, so there is
  # no label matching between the two: a filter names a variable and some level
  # indices, and a comment either carries that variable's level or it does not.
  #
  # It is DEMOGRAPHIC information about the person who wrote a comment, so it
  # obeys the same dial the tags do. "block" ships none, and the comments then
  # do not follow a filter at all, which is the trade that dial already makes.
  # "safe" runs it through the SAME k-anonymiser, within band, so a comment
  # carries a variable only while the combination it belongs to still covers at
  # least k people. Anything finer is dropped, and a comment that cannot be
  # placed is left out of the cut rather than guessed at.
  cut_map <- NULL
  if (!is.null(cut_levels) && length(cut_levels) && !identical(cuts, "block")) {
    cut_vars <- names(cut_levels)
    ids <- character(0); bands <- character(0); rows <- list()
    band_of <- new.env(parent = emptyenv())
    for (q in questions) for (rec in q$records) {
      id <- as.character(rec$id)
      b <- if (is.null(rec$band) || is.na(rec$band)) "" else as.character(rec$band)
      if (!exists(id, envir = band_of, inherits = FALSE)) {
        assign(id, b, envir = band_of)
        slot <- unname(master$id_to_idx[id])
        row <- stats::setNames(vector("list", length(cut_vars)), cut_vars)
        if (length(slot) == 1L && !is.na(slot)) {
          for (v in cut_vars) {
            lv <- cut_levels[[v]][slot + 1L]
            row[[v]] <- if (is.na(lv)) NA_character_ else as.character(lv)
          }
        } else {
          for (v in cut_vars) row[[v]] <- NA_character_
        }
        ids <- c(ids, id); rows[[length(rows) + 1L]] <- row
      } else if (nzchar(b) && !nzchar(get(id, envir = band_of, inherits = FALSE))) {
        assign(id, b, envir = band_of)
      }
    }
    if (length(ids)) {
      bands <- vapply(ids, function(id) get(id, envir = band_of, inherits = FALSE), character(1))
      k_cut <- suppressWarnings(as.numeric(qual_cfg(config, "min_reporting_base", 1)))
      safe <- identical(cuts, "safe") && length(k_cut) == 1L && !is.na(k_cut) && k_cut > 1
      kept <- if (safe) qual_kanon_tags_by_group(rows, ids, bands, cut_vars, k_cut)
              else stats::setNames(rows, ids)
      cut_map <- kept
    }
  }
  # How a comment is keyed. "respondent" is the historic shape: one index and one
  # reader token per person, the same in every question. "question" keys a comment
  # by its position in its own question and ships no token, so no two comments in
  # the file can be known to come from the same person. The client-safe delivery
  # modes floor this dial, see tabs_delivery_qual_dials().
  comment_key <- tolower(trimws(as.character(qual_cfg(config, "comment_key", "respondent"))))
  if (!comment_key %in% c("respondent", "question")) comment_key <- "respondent"
  # An assertion by the analyst, never a measurement: no build can tell whether a
  # human read the comments. Reported as asserted wherever it is shown.
  manual_review <- isTRUE(qual_cfg(config, "manual_review", FALSE))

  islands <- lapply(questions,
                    function(q) qual_build_question_island(q, master$id_to_idx, text_mode, demo_labels,
                                                           demo_map, scope, rid_map, cut_map,
                                                           comment_key))
  out <- list(textMode = text_mode, demographicCuts = cuts, noteworthyDefault = default_tier,
              verbatimScope = scope, n = master$n, questions = islands)
  # Emitted only when it is not the historic default, so a records build's island is
  # byte-identical to one built before this existed.
  if (!identical(comment_key, "respondent")) out$commentKey <- comment_key
  if (isTRUE(manual_review)) out$manualReview <- TRUE
  if (length(demo_labels)) {
    out$demographics <- lapply(banner_dims, function(d) list(label = d$label, values = d$values))
  }
  # Which variables a filter may narrow the comments by. Absent on a records
  # build, where the respondent island answers the same question and this
  # machinery is not used at all.
  if (!is.null(cut_map)) out$cutVars <- as.list(names(cut_levels))
  out
}
