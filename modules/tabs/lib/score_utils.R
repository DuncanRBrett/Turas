# ==============================================================================
# TABS — SCORING & NET-STRUCTURE HELPERS (data-centric report v2)
# ==============================================================================
# Shared helpers for the v2 data layer + microdata writers: numeric scoring
# (index_scores / per-respondent mean scores) and NET-structure derivation
# (the top-minus-bottom net difference). They reproduce the crosstab processors'
# logic exactly, so a recompute reproduces published figures. Kept in one place
# so the writers can never drift. Sourced BEFORE data_layer_writer.R /
# microdata_writer.R.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}


#' Numeric score for a survey option (OptionValue, else numeric(OptionText))
#'
#' Mirrors calculate_rating_mean()'s option->value lookup exactly.
#'
#' @param qopt One-row options data frame slice
#' @return Numeric score (may be NA)
#' @export
option_numeric_value <- function(qopt) {
  v <- NA_real_
  if ("OptionValue" %in% names(qopt) && !is.na(qopt$OptionValue) &&
      nzchar(as.character(qopt$OptionValue))) {
    v <- suppressWarnings(as.numeric(qopt$OptionValue))
  }
  if (is.na(v)) v <- suppressWarnings(as.numeric(qopt$OptionText))
  v
}


#' NPS bucket score for a 0-10 value: 9-10 -> +100, 7-8 -> 0, 0-6 -> -100
#'
#' The weighted mean of these per-respondent scores IS the published NPS
#' (%promoters - %detractors), so the engine's indexMeans reproduces NPS with
#' no bespoke NET arithmetic.
#'
#' @param v Numeric 0-10 value
#' @return 100, 0, -100, or NA
#' @export
nps_bucket_score <- function(v) {
  if (is.na(v)) return(NA_real_)
  if (v >= 9) return(100)
  if (v >= 7) return(0)
  if (v >= 0) return(-100)
  NA_real_
}


#' Mean option score per BoxCategory — the favourability score
#'
#' Each box's mean option score, using the SAME signal as the Index
#' (`option_numeric_value`: OptionValue when present, else OptionText). Lets NET
#' POSITIVE order its boxes by favourability rather than display position, so the
#' favourable box is "top" whether the scale is shown best-first or worst-first.
#'
#' @param opt_df Option rows for ONE question (needs BoxCategory + a numeric
#'   OptionValue or OptionText)
#' @return Named numeric BoxCategory -> mean option score (NA when a box has no
#'   numeric value), or NULL when there is nothing to score by.
#' @export
box_category_scores <- function(opt_df) {
  if (is.null(opt_df) || !("BoxCategory" %in% names(opt_df))) return(NULL)
  cats <- unique(opt_df$BoxCategory)
  cats <- cats[!is.na(cats) & nzchar(trimws(as.character(cats)))]
  if (length(cats) == 0) return(NULL)
  vapply(cats, function(cat) {
    sub <- opt_df[!is.na(opt_df$BoxCategory) & opt_df$BoxCategory == cat, , drop = FALSE]
    if (nrow(sub) == 0) return(NA_real_)
    vals <- vapply(seq_len(nrow(sub)), function(i) {
      v <- suppressWarnings(option_numeric_value(sub[i, , drop = FALSE]))
      if (length(v) == 1) as.numeric(v) else NA_real_   # no OptionValue/OptionText -> NA
    }, numeric(1))
    if (all(is.na(vals))) NA_real_ else mean(vals, na.rm = TRUE)
  }, numeric(1))
}

#' Derive net_diffs (NET POSITIVE = favourable box - unfavourable box) from rows
#'
#' Keyed by the NET POSITIVE row's zero-based index; values are the plus/minus
#' box row indices the renderer's net_diff path reads. When `box_scores`
#' (BoxCategory -> mean OptionValue) is supplied, the favourable box (highest
#' score) is "plus" and the unfavourable (lowest) is "minus", so the difference
#' is correct regardless of display direction. Without scores it falls back to
#' ROW order (first box = minus, last non-DK box = plus), the historical
#' behaviour — derived by order, never by parsing the (dash-containing) label.
#'
#' @param rows The built rows[] list of a data-layer question
#' @param box_scores Optional BoxCategory -> score (from box_category_scores)
#' @return Named list "<npIndex>" -> list(plus, minus), or NULL
#' @export
derive_net_diffs <- function(rows, box_scores = NULL) {
  net_idx <- which(vapply(rows, function(r) identical(r$kind, "net"), logical(1)))
  if (length(net_idx) < 3) return(NULL)
  is_np <- vapply(net_idx, function(i) grepl("^NET POSITIVE", rows[[i]]$label, ignore.case = TRUE),
                  logical(1))
  np <- net_idx[is_np]
  box_rows <- net_idx[!is_np]
  if (length(np) == 0 || length(box_rows) < 2) return(NULL)
  dk_pat <- "don'?t know|^DK$|not applicable|^NA$"
  is_dk <- vapply(box_rows, function(i) {
    grepl(dk_pat, rows[[i]]$label, ignore.case = TRUE)
  }, logical(1))
  non_dk <- box_rows[!is_dk]
  if (length(non_dk) == 0) return(NULL)

  # Prefer SCORE order (favourable box = highest OptionValue), so NET POSITIVE is
  # favourable - unfavourable whether the scale is displayed best-first or
  # worst-first. Fall back to ROW order when scores are unavailable.
  bottom <- top <- NA_integer_
  if (!is.null(box_scores) && length(non_dk) >= 2) {
    sc <- suppressWarnings(as.numeric(box_scores[
      vapply(non_dk, function(i) as.character(rows[[i]]$label), character(1))]))
    if (sum(!is.na(sc)) >= 2) {
      top <- non_dk[which.max(sc)]                # favourable
      bottom <- non_dk[which.min(sc)]             # unfavourable
    }
  }
  if (is.na(top) || is.na(bottom)) {              # historical row-order fallback
    bottom <- box_rows[1]
    top <- non_dk[length(non_dk)]
  }

  diffs <- list()
  for (i in np) diffs[[as.character(i - 1L)]] <- list(plus = top - 1L, minus = bottom - 1L)
  diffs
}


#' Derive index_scores (display label -> numeric score) for mean recompute
#'
#' Rating -> option value; NPS -> +-100 buckets; Likert -> Index_Weight. Keyed by
#' the display label (= the data-layer category row label) so the renderer's
#' indexMeans, which keys q.index_scores by row label, reproduces the published
#' weighted mean. Options flagged ExcludeFromIndex=Y are skipped, mirroring
#' calculate_rating_mean(). Returns NULL for types with no per-option score
#' (Numeric means are over raw values; allocation / derived rows).
#'
#' @param q_result A single element of all_results
#' @param survey_structure Loaded structure (needs $options), or NULL
#' @return Named list label -> score, or NULL
#' @export
derive_index_scores <- function(q_result, survey_structure) {
  if (is.null(survey_structure) || is.null(survey_structure$options)) return(NULL)
  vt <- as.character(q_result$question_type %||% "")
  source <- switch(vt, "NPS" = "nps", "Likert" = "index", "Rating" = "value", NA_character_)
  if (is.na(source)) return(NULL)

  opt <- survey_structure$options
  code <- as.character(q_result$question_code %||% "")
  qopt <- opt[!is.na(opt$QuestionCode) & opt$QuestionCode == code, , drop = FALSE]
  if (nrow(qopt) == 0) return(NULL)
  if ("ExcludeFromIndex" %in% names(qopt)) {
    qopt <- qopt[is.na(qopt$ExcludeFromIndex) | qopt$ExcludeFromIndex != "Y", , drop = FALSE]
  }
  if (nrow(qopt) == 0) return(NULL)

  disp <- ifelse(!is.na(qopt$DisplayText) & nzchar(as.character(qopt$DisplayText)),
                 as.character(qopt$DisplayText), as.character(qopt$OptionText))
  scores <- list()
  for (i in seq_len(nrow(qopt))) {
    row_i <- qopt[i, , drop = FALSE]
    sc <- if (source == "index") {
      iw <- if ("Index_Weight" %in% names(row_i)) row_i$Index_Weight else NA
      suppressWarnings(as.numeric(iw))
    } else if (source == "nps") {
      nps_bucket_score(option_numeric_value(row_i))
    } else {
      option_numeric_value(row_i)
    }
    lbl <- trimws(disp[i])
    if (!is.na(sc) && nzchar(lbl)) scores[[lbl]] <- sc
  }
  if (length(scores) == 0) NULL else scores
}

#' Box-category scores for a question (NET POSITIVE direction)
#'
#' Resolves the question's options from the structure (as derive_index_scores
#' does) and returns their per-box mean OptionValue, so the data layer can hand
#' derive_net_diffs the favourability order. NULL when no structure/options.
#'
#' @param q_result One question result (needs $question_code)
#' @param survey_structure Loaded structure (needs $options)
#' @return Named BoxCategory -> mean OptionValue, or NULL
#' @export
derive_box_scores <- function(q_result, survey_structure) {
  if (is.null(survey_structure) || is.null(survey_structure$options)) return(NULL)
  code <- as.character(q_result$question_code %||% "")
  if (!nzchar(code)) return(NULL)
  opt <- survey_structure$options
  qopt <- opt[!is.na(opt$QuestionCode) & opt$QuestionCode == code, , drop = FALSE]
  if (nrow(qopt) == 0) return(NULL)
  box_category_scores(qopt)
}
