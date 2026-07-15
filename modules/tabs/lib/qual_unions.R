# ==============================================================================
# TABS MODULE — QUALITATIVE SHEET UNIONS (split-by-band comment questions)
# ==============================================================================
#
# Some open-ends are captured in SEVERAL comment sheets split by a routing cut —
# the canonical case is an NPS "why?" follow-up routed into Detractor / Passive /
# Promoter sheets (e.g. CCPB Q79). The reader is one-sheet -> one-question, and the
# jump map (qual_build_links) is one-target -> one-sheet, so three band sheets could
# not be presented as the ONE question they represent.
#
# This file adds a config-driven UNION: an open-end's `CommentSheet` cell may name
# several sheets, each tagged with a band, and the members are reassembled into one
# reported question. Each record carries its `band` as a first-class split attribute
# (NOT a demographic tag — the band is the report-level split axis, always shown and
# never k-anonymised away; centre/channel tags stay in `demos`). The question carries
# a `split = list(dim, bands)` so the JS can offer an All / <band> segmented view.
#
# The band label here is the SHEET-OF-ORIGIN band. The score-derived band + the
# reconciliation against it are a separate step (qual_derive_bands, built on the join).
#
# CommentSheet syntax (Excel forbids ':' in a sheet name, so ':' is unambiguous):
#   single    "Q75Comment"                                  -> unchanged (no union)
#   union     "DetractorComment:Detractor; PassiveComment:Passive; PromoterComment:Promoter"
#   union     "SheetA; SheetB"   (no ':' -> band defaults to the sheet name)
#
# Depends on (sourced by the pipeline): qual_workbook_reader.R (qual_sheet_code).
# Run the tests with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_unions.R")
# ==============================================================================

# Default label for the split dimension when a union row does not name one.
QUAL_SPLIT_DIM_DEFAULT <- "NPS band"

#' Is a config cell blank / NA / the literal "NA" (the config loader stringifies blanks)?
#' @param v A scalar value.
#' @return TRUE when the cell carries no usable value.
qual_cell_blank <- function(v) {
  v <- trimws(as.character(v))
  length(v) != 1L || is.na(v) || !nzchar(v) || v == "NA"
}

#' Parse a `CommentSheet` cell into member sheets (+ their bands).
#'
#' @param cell The raw CommentSheet cell value.
#' @return list(union, members) where `members` is a list of list(sheet, band).
#'   `union` is TRUE only when more than one member is named. A blank cell yields
#'   no members. A single sheet yields one member (band = the sheet name, unused).
qual_parse_comment_sheet <- function(cell) {
  if (qual_cell_blank(cell)) return(list(union = FALSE, members = list()))
  s <- trimws(as.character(cell))
  parts <- trimws(strsplit(s, "[;\n]+")[[1]])
  parts <- parts[nzchar(parts)]
  members <- lapply(parts, function(p) {
    if (grepl(":", p, fixed = TRUE)) {
      kv <- trimws(strsplit(p, ":", fixed = TRUE)[[1]])
      band <- if (length(kv) >= 2L && nzchar(kv[[2]])) kv[[2]] else kv[[1]]
      list(sheet = kv[[1]], band = band)
    } else {
      list(sheet = p, band = p)     # multi-sheet with no explicit band -> band = sheet name
    }
  })
  members <- Filter(function(m) nzchar(m$sheet), members)
  list(union = length(members) > 1L, members = members)
}

#' The synthetic question code for a union, derived from the open-end's QuestionCode
#' (so it is stable and both the union builder and the jump resolver agree on it).
#' Falls back to the joined member sheet names when no QuestionCode is available.
#' @param open_end_code The open-end row's QuestionCode (may be blank).
#' @param members The parsed members (list of list(sheet, band)).
#' @return A `QUAL_...` code string.
qual_union_code <- function(open_end_code, members) {
  oe <- trimws(as.character(open_end_code))
  if (length(oe) == 1L && !is.na(oe) && nzchar(oe) && oe != "NA") return(qual_sheet_code(oe))
  qual_sheet_code(paste(vapply(members, function(m) m$sheet, character(1)), collapse = "_"))
}

#' Scan the Selection sheet for union specs (rows whose CommentSheet names >1 sheet).
#'
#' @param selection_df The Selection sheet (named columns: CommentSheet, QuestionCode,
#'   and optionally CommentLink, SplitDimension, NpsScoreQuestion, QuestionText).
#' @return A list of union specs, each: list(code, title, dim, members, link_target,
#'   score_question, order). `members` carry the resolved sheet `code`. Empty when
#'   the sheet is absent or no row unions.
qual_selection_unions <- function(selection_df) {
  if (is.null(selection_df) || !is.data.frame(selection_df) || !nrow(selection_df) ||
      !("CommentSheet" %in% names(selection_df))) {
    return(list())
  }
  col <- function(name) if (name %in% names(selection_df)) selection_df[[name]] else NULL
  qc <- col("QuestionCode"); link <- col("CommentLink"); dimc <- col("SplitDimension")
  scorec <- col("NpsScoreQuestion"); qt <- col("QuestionText")
  pick <- function(v, i, default = NA_character_) {
    if (is.null(v) || qual_cell_blank(v[i])) default else trimws(as.character(v[i]))
  }
  unions <- list()
  for (i in seq_len(nrow(selection_df))) {
    spec <- qual_parse_comment_sheet(selection_df$CommentSheet[i])
    if (!isTRUE(spec$union)) next
    oe <- pick(qc, i)
    members <- lapply(spec$members, function(m)
      list(sheet = m$sheet, code = qual_sheet_code(m$sheet), band = m$band))
    link_target <- pick(link, i)
    unions[[length(unions) + 1L]] <- list(
      code = qual_union_code(oe, spec$members),
      title = pick(qt, i, default = if (is.na(oe)) "" else oe),
      dim = pick(dimc, i, default = QUAL_SPLIT_DIM_DEFAULT),
      members = members,
      link_target = link_target,
      score_question = pick(scorec, i, default = link_target),  # default: the linked closed question
      order = vapply(members, function(m) m$band, character(1)))
  }
  unions
}

#' Reassemble member sheets into single union questions, stamping each record's band.
#'
#' @param questions The classified per-sheet questions from `qual_read_workbook()`.
#' @param unions Union specs from `qual_selection_unions()`.
#' @return The questions list with each union's members replaced by one union question
#'   (records concatenated, `band` stamped; `split = list(dim, bands)`; type "themed"
#'   iff any member carried themes, else "raw"). Non-member questions pass through.
qual_apply_sheet_unions <- function(questions, unions) {
  if (!length(unions)) return(questions)
  by_code <- list()
  for (q in questions) by_code[[q$code]] <- q
  consumed <- character(0)
  built <- list()
  for (u in unions) {
    recs <- list(); dropped <- 0L; found_any <- FALSE
    themes_union <- list()                       # union of member themes, keyed by label
    for (m in u$members) {
      mq <- by_code[[m$code]]
      if (is.null(mq)) next                       # a named sheet that is not in the workbook
      found_any <- TRUE
      consumed <- c(consumed, m$code)
      for (rec in mq$records) {
        rec$band <- m$band
        recs[[length(recs) + 1L]] <- rec
      }
      md <- mq$meta$dropped_codes
      dropped <- dropped + (if (is.null(md) || is.na(md)) 0L else md)
      for (th in mq$roles$themes) themes_union[[th$label]] <- th
    }
    if (!found_any) next
    theme_list <- unname(themes_union)
    built[[length(built) + 1L]] <- list(
      skip = FALSE, sheet = u$code, code = u$code, title = u$title,
      type = if (length(theme_list)) "themed" else "raw",
      header_row = NA_integer_,
      roles = list(id = NA_integer_, verbatim = NA_integer_, noteworthy = NA_integer_,
                   sentiment = NA_integer_, rating = NA_integer_,
                   themes = theme_list, demos = list()),
      records = recs,
      split = list(dim = u$dim, bands = as.list(u$order)),
      meta = list(dropped_codes = dropped, n_records = length(recs),
                  n_themes = length(theme_list), n_demos = 0L))
  }
  kept <- Filter(function(q) !(q$code %in% consumed), questions)
  c(kept, built)
}

# ==============================================================================
# BAND DERIVATION FROM THE RECOMMEND SCORE (built on the host join)
# ==============================================================================
#
# Sheet-of-origin gives each comment a band, but which sheet the "why?" text landed
# in can drift from the actual 0-10 score (routing/coding error). Since the comments
# are joined to the host survey, we can derive each respondent's band straight from
# the score column and let it WIN — flagging (console, Shiny-visible) where the sheet
# disagreed. This is self-correcting and needs no per-study code: the score question
# defaults to the union's CommentLink target (the NPS question it explains).

#' Classify a band label as detractor / passive / promoter by keyword (case-insensitive).
#' @return "detractor" | "passive" | "promoter" | NA_character_.
qual_classify_band_label <- function(label) {
  l <- tolower(trimws(as.character(label)))
  if (grepl("detract", l)) return("detractor")
  if (grepl("passiv", l))  return("passive")
  if (grepl("promot", l))  return("promoter")
  NA_character_
}

#' Map the union's declared band labels to the three NPS buckets (first match wins).
#' @param order The union's ordered band labels.
#' @return list(detractor, passive, promoter) of the matching declared labels (NA if none).
qual_band_label_map <- function(order) {
  m <- list(detractor = NA_character_, passive = NA_character_, promoter = NA_character_)
  for (lab in order) {
    k <- qual_classify_band_label(lab)
    if (!is.na(k) && is.na(m[[k]])) m[[k]] <- as.character(lab)
  }
  m
}

#' Map an nps_bucket_score() result (100 / 0 / -100 / NA) to a declared band label.
#' @return The declared label, or NA when the bucket has no declared band.
qual_bucket_to_label <- function(bucket, lab_for) {
  if (length(bucket) != 1L || is.na(bucket)) return(NA_character_)
  if (bucket >= 100)  return(lab_for$promoter)
  if (bucket <= -100) return(lab_for$detractor)
  lab_for$passive
}

#' Override each union record's band with the score-derived band, reconciling.
#'
#' For every union question, look up each comment respondent's recommend score in the
#' host survey (via the join index), bucket it (reusing nps_bucket_score) and map it to
#' the union's declared band labels. The score-derived band WINS; sheet-of-origin is the
#' fallback when no score/label is available. Disagreements are counted and echoed to the
#' console (never silent). Requires nps_bucket_score() to be sourced (score_utils.R).
#'
#' @param questions Questions AFTER qual_apply_sheet_unions (union questions carry $split).
#' @param unions Union specs (carry $code + $score_question + $order).
#' @param survey_data The host survey data frame.
#' @param id_to_idx Named map: workbook ResponseID -> host 0-based row index (join master).
#' @return `questions` with union records' `band` reconciled to the score where possible.
qual_derive_bands <- function(questions, unions, survey_data, id_to_idx) {
  if (!length(unions) || is.null(survey_data) || !is.data.frame(survey_data)) return(questions)
  if (!exists("nps_bucket_score", mode = "function")) return(questions)  # score util not loaded
  u_by_code <- list()
  for (u in unions) u_by_code[[u$code]] <- u
  for (qi in seq_along(questions)) {
    q <- questions[[qi]]
    u <- u_by_code[[q$code]]
    if (is.null(u)) next
    score_q <- u$score_question
    if (length(score_q) != 1L || is.na(score_q) || !nzchar(score_q) ||
        !(score_q %in% names(survey_data))) next
    lab_for <- qual_band_label_map(u$order)
    scores <- survey_data[[score_q]]
    mism <- 0L; derived_n <- 0L
    for (ri in seq_along(q$records)) {
      rec <- q$records[[ri]]
      hidx <- unname(id_to_idx[rec$id])           # host 0-based idx (NA when unmatched)
      if (length(hidx) != 1L || is.na(hidx)) next
      v <- suppressWarnings(as.numeric(scores[hidx + 1L]))
      lab <- qual_bucket_to_label(nps_bucket_score(v), lab_for)
      if (is.null(lab) || length(lab) != 1L || is.na(lab)) next
      derived_n <- derived_n + 1L
      if (!is.null(rec$band) && !is.na(rec$band) && !identical(as.character(rec$band), lab)) {
        mism <- mism + 1L
      }
      q$records[[ri]]$band <- lab                  # the score wins
    }
    if (mism > 0L) {
      cat(sprintf(paste0("  Qualitative: %s — %d of %d comment band(s) reassigned from the ",
                         "recommend score '%s' (sheet-of-origin disagreed).\n"),
                  q$code, mism, derived_n, score_q))
    }
    questions[[qi]] <- q
  }
  questions
}
