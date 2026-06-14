# ==============================================================================
# TABS — SCORING HELPERS (data-centric report v2)
# ==============================================================================
# Numeric scoring helpers shared by the data-layer writer (index_scores) and the
# microdata writer (per-respondent mean scores). They reproduce the crosstab
# processors' option->value logic exactly, so a recompute reproduces published
# means. Kept in one place so the two writers can never drift on how an option
# becomes a score. Must be sourced BEFORE data_layer_writer.R / microdata_writer.R.
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
      if ("Index_Weight" %in% names(row_i)) suppressWarnings(as.numeric(row_i$Index_Weight)) else NA_real_
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
