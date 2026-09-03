# ==============================================================================
# TABS. MICRODATA WRITER (V11, data-centric report v2)
# ==============================================================================
# Emits the anonymised `data-micro` island (TR.MICRO) the v2 renderer's stats
# engine recomputes from when a live filter or a custom ("+ Custom…") banner is
# active. Shape (verified against assets/js/20_data.js d2.validate + 21_stats.js):
#
#   { n, answers: { <qcode>: [rowIndex | [rowIndex…] | -2 | null  per respondent] },
#     banner_vars: { <banner_code>: [aggColumnIndex | -1  per respondent] },
#     weights: [w per respondent],
#     scores:  { <qcode>: [score | null  per respondent] },
#     boxes:   { <qcode>: [boxIndex | null  per respondent] },
#     series:  { <qcode>: { "<zero-based rows[] index>": [value | null  per
#                                                         respondent] } } }
#
# scores, boxes and series are each omitted when no question carries one, so a
# report gains a key only when it gains the feature. `series` is the ALLOCATION
# (constant-sum) case: such a question publishes one mean row per item, so it
# needs k series under one code where `scores` holds exactly one number per
# respondent. Its `answers` column carries the -2 marker (who is in the base)
# rather than a row index, because an Allocation has no category rows to land
# on. See micro_series_for_question().
#
# Anonymity: ONLY zero-based row/column indices and weights, never a respondent
# identifier, raw answer string, or free text. Indices are meaningless without
# the report they ship inside.
#
# Correctness contract: a respondent's answer is mapped to its display-row index
# with the SAME exact-string match the crosstab processors use
# (cell_calculator.R / calculate_rating_mean: trimmed OptionText equality), so a
# weighted recompute reproduces the PUBLISHED figures. Per-respondent weights are
# carried so the engine's weighted recompute matches the published weighted Total
# (filtering / custom banners would otherwise be unweighted and wrong).
#
# Consumes the BUILT data layer (build_data_layer) so the row order it indexes
# into is exactly the rows[] the renderer reads. The two can never drift.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Engine sentinels (mirror assets/js/21_stats.js).
MICRO_ANSWERED_UNSHOWN <- -2L   # answered, but the chosen option is not displayed
MICRO_NO_COLUMN        <- -1L   # respondent falls in no column of a banner group


#' Map a question's raw option values to their display labels
#'
#' Display label = DisplayText when present, else OptionText (mirrors the
#' processors). Returns a named character vector keyed by the trimmed raw
#' OptionText (the value stored in survey_data), or NULL when the question has
#' no options in the structure.
#'
#' @param qcode Question code
#' @param survey_structure Loaded structure (needs $options)
#' @return Named character vector raw -> display label, or NULL
#' @keywords internal
micro_display_map <- function(qcode, survey_structure) {
  opt <- survey_structure$options
  if (is.null(opt) || !("QuestionCode" %in% names(opt))) return(NULL)
  qopt <- opt[!is.na(opt$QuestionCode) & opt$QuestionCode == qcode, , drop = FALSE]
  if (nrow(qopt) == 0) {
    # Multi-mention options are keyed by slot code ({code}_1..{code}_N) rather
    # than the root code (the same convention prepare_question_data and the
    # banner slot fallback read), so fall back to the slot rows. Otherwise raw
    # OptionText values never resolve when DisplayText differs and every live
    # filter / custom-banner recompute shows the option at 0%. Anchored to
    # digits so a prefix-sharing code (Q1 vs Q1_STAFF) can't leak options;
    # deduplicated by OptionText like the banner fallback (banner.R).
    slot_pattern <- paste0("^\\Q", qcode, "\\E_[0-9]+$")
    qopt <- opt[!is.na(opt$QuestionCode) &
                  grepl(slot_pattern, opt$QuestionCode, perl = TRUE), , drop = FALSE]
    if (nrow(qopt) > 0) {
      qopt <- qopt[!duplicated(trimws(as.character(qopt$OptionText))), , drop = FALSE]
    }
  }
  if (nrow(qopt) == 0) return(NULL)
  disp <- ifelse(!is.na(qopt$DisplayText) & nzchar(as.character(qopt$DisplayText)),
                 as.character(qopt$DisplayText), as.character(qopt$OptionText))
  setNames(trimws(disp), trimws(as.character(qopt$OptionText)))
}


#' Normalise a label for tolerant matching
#'
#' Lower-cases, turns any dash variant into a space, strips punctuation, and
#' collapses whitespace, so "Yes  a casual" and "Yes – a casual" match. Used
#' only as a fallback after exact matching, and only when unambiguous.
#'
#' @param x Character vector
#' @return Normalised character vector
#' @keywords internal
micro_normalize_label <- function(x) {
  x <- tolower(trimws(as.character(x)))
  # U+2010 to U+2015 is the whole dash block, so the en and em dashes are
  # already inside the range and need no literal of their own.
  x <- gsub("[‐-―−-]", " ", x, perl = TRUE)  # dashes -> space
  x <- gsub("[^a-z0-9 ]", "", x, perl = TRUE)                          # strip punctuation
  trimws(gsub("\\s+", " ", x))
}


#' Raw value -> zero-based category row index maps for one data-layer question
#'
#' Aligns with the renderer's d2.catRows: the index is the position of the
#' option's display row in the data-layer rows[] array. Two exact sources,
#' combined, plus a normalised fallback:
#'   1. Every category row LABEL maps to its own index. This alone handles
#'      questions whose categories are derived from the data (e.g. multi-mention
#'      with no structure options): there the stored value IS the label.
#'   2. When the structure defines options, each raw OptionText also maps to its
#'      row via DisplayText, so raw values that differ from the display label
#'      resolve, and options that exist but are not displayed (e.g.
#'      ShowInOutput=N) map to MICRO_ANSWERED_UNSHOWN (counted in the base only).
#'   3. A normalised label map (unique normalisations only) catches whitespace /
#'      dash recodes the processor applies to data-derived labels.
#' Source 2 takes precedence on collisions (the structure is authoritative).
#'
#' @param dl_q One built data-layer question (with $rows, $code)
#' @param survey_structure Loaded structure
#' @return list(exact = named int vector value->index, norm = named int vector
#'   normalised-label->index), or NULL when the question has no category rows
#' @keywords internal
micro_value_index_map <- function(dl_q, survey_structure) {
  label_to_index <- list()
  for (i in seq_along(dl_q$rows)) {
    r <- dl_q$rows[[i]]
    if (identical(r$kind, "category")) {
      label_to_index[[trimws(as.character(r$label))]] <- i - 1L
    }
  }
  if (length(label_to_index) == 0) return(NULL)

  keys <- names(label_to_index)
  vals <- as.integer(unlist(label_to_index, use.names = FALSE))

  disp_map <- micro_display_map(dl_q$code, survey_structure)
  if (!is.null(disp_map)) {
    raw_idx <- vapply(unname(disp_map), function(lbl) {
      hit <- label_to_index[[lbl]]
      if (is.null(hit)) MICRO_ANSWERED_UNSHOWN else as.integer(hit)
    }, integer(1))
    keys <- c(keys, names(disp_map))
    vals <- c(vals, raw_idx)
  }
  exact <- vals
  names(exact) <- keys
  exact <- exact[!duplicated(names(exact), fromLast = TRUE)]   # structure-derived wins

  # Normalised fallback: category-row labels only, unique normalisations only.
  norm_keys <- micro_normalize_label(names(label_to_index))
  norm_vals <- as.integer(unlist(label_to_index, use.names = FALSE))
  dup <- norm_keys %in% norm_keys[duplicated(norm_keys)]
  norm <- norm_vals[!dup]
  names(norm) <- norm_keys[!dup]

  list(exact = exact, norm = norm)
}


#' Look up row indices for raw values: exact first, normalised fallback
#'
#' @param keys Trimmed character vector of raw values
#' @param maps list(exact, norm) from micro_value_index_map()
#' @return Integer vector (NA where unmatched / blank)
#' @keywords internal
micro_lookup_index <- function(keys, maps) {
  mapped <- unname(maps$exact[keys])
  miss <- is.na(mapped) & !is.na(keys) & keys != ""
  if (any(miss) && length(maps$norm) > 0) {
    mapped[miss] <- unname(maps$norm[micro_normalize_label(keys[miss])])
  }
  mapped[is.na(keys) | keys == ""] <- NA_integer_
  as.integer(mapped)
}


#' Per-respondent answers for a single-valued question (vectorised)
#'
#' @param col The survey_data column (length n)
#' @param maps list(exact, norm) from micro_value_index_map()
#' @return Integer vector length n: rowIndex, -2, or NA (no answer)
#' @keywords internal
micro_answers_single <- function(col, maps) {
  micro_lookup_index(trimws(as.character(col)), maps)
}


#' Per-respondent answers for a multi-mention question
#'
#' Expands the {code}_1.._k columns (falling back to a single {code} column) to
#' the set of selected row indices. Answered-but-only-unshown collapses to an
#' empty array (counts in the base, no displayed mention); never-answered is NA.
#'
#' @param survey_data The respondent data frame
#' @param code Question code
#' @param maps list(exact, norm) from micro_value_index_map()
#' @param n Respondent count
#' @return A length-n list of integer vectors / NA
#' @keywords internal
micro_answers_multi <- function(survey_data, code, maps, n) {
  # \Q…\E quotes the code literally, so a metacharacter in a question code
  # (e.g. a ".") can't act as a wildcard and over-match unrelated columns.
  cols <- grep(paste0("^\\Q", code, "\\E_\\d+$"), names(survey_data),
               perl = TRUE, value = TRUE)
  if (length(cols) == 0 && code %in% names(survey_data)) cols <- code
  out <- vector("list", n)
  for (r in seq_len(n)) {
    idxs <- integer(0)
    answered <- FALSE
    for (cc in cols) {
      key <- trimws(as.character(survey_data[[cc]][r]))
      if (is.na(key) || !nzchar(key)) next
      answered <- TRUE
      mi <- micro_lookup_index(key, maps)
      if (!is.na(mi) && mi >= 0L) idxs <- c(idxs, as.integer(mi))
    }
    out[[r]] <- if (length(idxs)) unique(idxs) else if (answered) integer(0) else NA_integer_
  }
  out
}


#' Build the answers payload for one question (the right shape for serialise)
#'
#' @param dl_q One built data-layer question
#' @param survey_data Respondent data
#' @param survey_structure Loaded structure
#' @param n Respondent count
#' @return I()-wrapped integer vector (single) or a list (multi); all-NA when the
#'   question carries no categorical answer (allocation / derived / no options)
#' @keywords internal
micro_answers_for_question <- function(dl_q, survey_data, survey_structure, n) {
  has_cols <- dl_q$code %in% names(survey_data) ||
    length(grep(paste0("^\\Q", dl_q$code, "\\E_\\d+$"), names(survey_data),
                perl = TRUE)) > 0

  # An ALLOCATION question has no bare data column and no category rows: it is
  # {code}_1..{code}_N of numbers, published as one mean row per option. Its N
  # numbers per respondent live under TR.MICRO.series (one per item row), not
  # here, because this island holds exactly one value per respondent per
  # question. What this column carries is WHO IS IN THE BASE: the
  # answered-but-unshown sentinel for any respondent with at least one non-NA
  # numeric slot, which is calculate_allocation_base() restated per
  # respondent, so a base recomputed under a filter is the published base
  # rule. stats.tabulate counts -2 in the base and tallies nothing, which is
  # right: an Allocation has no category rows to land on.
  #
  # Only when the series built. If the pairing was refused (duplicate labels,
  # rows out of option order) the column stays all-NA, recomputable() reads it
  # as "no microdata", and the card keeps its "n/a under filter" badge. A base
  # with blank rows under it would be worse than the badge.
  #
  # Before this it was always a full-length column of NA. That was the honest
  # stop-gap for the crash it fixed: the single-response path indexed a column
  # that does not exist and returned a zero-length vector, so the report
  # refused to open at all ("DATA_MICRO_Q microdata missing/short").
  if (identical(micro_variable_type(dl_q$code, survey_structure), "Allocation")) {
    series <- micro_series_for_question(dl_q, survey_data, survey_structure, n)
    if (is.null(series) || length(series) == 0) return(I(rep(NA_integer_, n)))
    answered <- rep(FALSE, n)
    for (s in series) answered <- answered | !is.na(as.numeric(s))
    return(I(ifelse(answered, MICRO_ANSWERED_UNSHOWN, NA_integer_)))
  }

  # A BINNED numeric question's rows are ranges ("R100 - R249") and its stored
  # values are numbers, so no value ever matched a row label: every respondent
  # landed on NA and the whole distribution vanished the moment anyone filtered
  #. Five rows of 0% on a base of 0, with the mean above them still moving.
  # Bin first, using the engine's own binner, then map the bin's label.
  binned <- micro_numeric_bins(dl_q, survey_data, survey_structure)
  if (!is.null(binned) && has_cols) {
    return(I(binned))
  }

  # An UNBINNED numeric question has no category rows to land on, but it still
  # has respondents who answered it, and the base row is read off this island.
  # Without them a filtered view reported a mean above a base of zero.
  if (identical(dl_q$type, "numeric") && dl_q$code %in% names(survey_data)) {
    answered <- !is.na(suppressWarnings(as.numeric(survey_data[[dl_q$code]])))
    return(I(ifelse(answered, MICRO_ANSWERED_UNSHOWN, NA_integer_)))
  }

  maps <- micro_value_index_map(dl_q, survey_structure)
  if (is.null(maps) || !has_cols) {
    return(I(rep(NA_integer_, n)))   # serialises to [null,…]: still length n
  }
  if (identical(dl_q$type, "multi")) {
    return(micro_answers_multi(survey_data, dl_q$code, maps, n))
  }
  I(micro_answers_single(survey_data[[dl_q$code]], maps))
}


#' Per-respondent bin row indices for a binned numeric question
#'
#' Uses \code{categorize_numeric_bins()}. The same function the numeric
#' processor bins with, so the recomputed distribution is the published one
#' when the audience is everyone. Bin labels are matched to the question's own
#' category rows, so a bin the processor did not publish maps to nothing rather
#' than to the wrong row.
#'
#' @param dl_q One built data-layer question.
#' @param survey_data Respondent data.
#' @param survey_structure Loaded structure.
#'
#' @return Integer vector length n, or NULL when the question is not a binned
#'   numeric (every other type keeps the label-matching path).
#' @keywords internal
micro_numeric_bins <- function(dl_q, survey_data, survey_structure) {
  if (!identical(dl_q$type, "numeric") || is.null(survey_structure)) {
    return(NULL)
  }
  if (!dl_q$code %in% names(survey_data)) {
    return(NULL)
  }
  options <- survey_structure$options
  if (is.null(options) || !all(c("Min", "Max") %in% names(options))) {
    return(NULL)
  }
  bins <- options[!is.na(options$QuestionCode) & options$QuestionCode == dl_q$code, ,
                  drop = FALSE]
  bins <- bins[!is.na(bins$Min) | !is.na(bins$Max), , drop = FALSE]
  if (!nrow(bins)) {
    return(NULL)
  }

  label_to_index <- list()
  for (i in seq_along(dl_q$rows)) {
    r <- dl_q$rows[[i]]
    if (identical(r$kind, "category")) {
      label_to_index[[trimws(as.character(r$label))]] <- i - 1L
    }
  }
  if (!length(label_to_index)) {
    return(NULL)
  }

  labels <- categorize_numeric_bins(
    suppressWarnings(as.numeric(survey_data[[dl_q$code]])), bins)
  idx <- vapply(trimws(as.character(labels)), function(lbl) {
    hit <- label_to_index[[lbl]]
    if (is.null(hit)) NA_integer_ else as.integer(hit)
  }, integer(1), USE.NAMES = FALSE)
  return(idx)
}


#' Per-respondent weights (length n), reusing the analysis weight vector
#'
#' Unweighted projects (and any run without a usable weight variable) get all
#' 1s, so the engine's weighted recompute collapses to the unweighted figures.
#' When weighting is on, reuses get_weight_vector() (the SAME repaired vector the
#' analysis weighted with) so the recompute matches the published weighted Total.
#'
#' @param survey_data Respondent data
#' @param config_obj Tabs config
#' @return Numeric vector length n
#' @keywords internal
micro_weights <- function(survey_data, config_obj) {
  n <- nrow(survey_data)
  if (!isTRUE(config_obj$apply_weighting)) return(rep(1, n))
  wv <- config_obj$weight_variable %||% config_obj$weighting_variable
  if (is.null(wv) || !nzchar(as.character(wv)) || !(wv %in% names(survey_data))) {
    return(rep(1, n))
  }
  w <- NULL
  if (exists("get_weight_vector", mode = "function")) {
    w <- tryCatch(get_weight_vector(survey_data, wv), error = function(e) NULL)
  }
  if (is.null(w) || length(w) != n) {
    w <- suppressWarnings(as.numeric(survey_data[[wv]]))
    w[is.na(w) | !is.finite(w) | w < 0] <- 0     # mirror weighting.R repair="exclude"
  }
  as.numeric(w)
}


#' Raw OptionText -> BoxCategory map for a box-category banner group
#'
#' Built from the group's own options (which carry BoxCategory). Options with
#' no BoxCategory map to nothing (the respondent falls in no column, exactly
#' how create_boxcategory_indices treats them).
#'
#' @param options The banner group's options data frame
#' @return Named character vector OptionText -> BoxCategory (possibly empty)
#' @keywords internal
micro_boxcat_value_map <- function(options) {
  empty <- setNames(character(0), character(0))
  if (is.null(options) || !is.data.frame(options) ||
      !all(c("OptionText", "BoxCategory") %in% names(options))) {
    return(empty)
  }
  bc <- trimws(as.character(options$BoxCategory))
  keep <- !is.na(bc) & nzchar(bc)
  if (!any(keep)) return(empty)
  setNames(bc[keep], trimws(as.character(options$OptionText[keep])))
}


#' Per-banner-group respondent column membership (length n each)
#'
#' For every banner group, each respondent maps to the zero-based AGG column
#' index of the column whose option they match (MICRO_NO_COLUMN when none).
#' Keyed by banner_code. The group id the engine's stats.columnsFor() reads.
#' Built-in single-response banners are covered. Box-category banners
#' (BannerBoxCategory = 'Y') map raw value -> BoxCategory -> column, because
#' their column labels are BoxCategory names, not option DisplayTexts. The
#' DisplayText path could never match and every column recomputed to base 0
#' under a live filter. Groups whose banner question has no options yield an
#' all-(-1) vector (safe: the engine still boots, that banner simply shows only
#' the Total column under a live filter).
#'
#' @param banner_info Banner structure
#' @param survey_data Respondent data
#' @param survey_structure Loaded structure
#' @param n Respondent count
#' @return Named list banner_code -> I()-wrapped integer vector
#' @keywords internal
micro_banner_vars <- function(banner_info, survey_data, survey_structure, n) {
  bgroups <- banner_info$banner_info
  if (is.null(bgroups) || length(bgroups) == 0) return(list())
  keys <- banner_info$internal_keys
  key_to_agg <- setNames(seq_along(keys) - 1L, keys)   # zero-based AGG col index
  k2d <- banner_info$key_to_display
  c2b <- banner_info$column_to_banner

  out <- list()
  for (gname in names(bgroups)) {
    grp <- bgroups[[gname]]
    grp_keys <- grp$internal_keys
    if (is.null(grp_keys) || length(grp_keys) == 0) next
    banner_code <- if (!is.null(c2b) && grp_keys[1] %in% names(c2b)) {
      unname(c2b[[grp_keys[1]]])
    } else {
      gname
    }

    # display label -> AGG column index for this group's columns
    lbl_to_agg <- integer(0)
    for (gk in grp_keys) {
      have_lbl <- !is.null(k2d) && gk %in% names(k2d)
      lbl <- if (have_lbl) trimws(as.character(k2d[[gk]])) else NA_character_
      if (!is.na(lbl) && gk %in% names(key_to_agg)) lbl_to_agg[[lbl]] <- key_to_agg[[gk]]
    }

    vec <- rep(MICRO_NO_COLUMN, n)
    qcode <- tryCatch(as.character(grp$question$QuestionCode[1]), error = function(e) NA_character_)
    if (!is.na(qcode) && qcode %in% names(survey_data)) {
      keysr <- trimws(as.character(survey_data[[qcode]]))
      if (isTRUE(grp$is_boxcategory)) {
        # Box-category banner: the column labels in lbl_to_agg are BoxCategory
        # names, so map respondent raw value -> BoxCategory -> AGG column.
        box_map <- micro_boxcat_value_map(grp$options)
        if (length(box_map) > 0) {
          boxes <- unname(box_map[keysr])                # respondent -> box name
          agg <- lbl_to_agg[boxes]                       # box name -> AGG col index
          vec <- ifelse(is.na(agg), MICRO_NO_COLUMN, as.integer(agg))
        }
      } else {
        disp_map <- micro_display_map(qcode, survey_structure)
        if (!is.null(disp_map)) {
          labels <- unname(disp_map[keysr])              # respondent -> display label
          agg <- lbl_to_agg[labels]                      # display label -> AGG col index
          vec <- ifelse(is.na(agg), MICRO_NO_COLUMN, as.integer(agg))
        }
      }
    }
    out[[banner_code]] <- I(as.integer(vec))
  }
  out
}


#' Original Variable_Type for a question code (from the structure)
#'
#' @param qcode Question code
#' @param survey_structure Loaded structure (needs $questions)
#' @return Character Variable_Type, or NA
#' @keywords internal
micro_variable_type <- function(qcode, survey_structure) {
  q <- survey_structure$questions
  if (is.null(q) || !("QuestionCode" %in% names(q))) return(NA_character_)
  row <- q[!is.na(q$QuestionCode) & q$QuestionCode == qcode, , drop = FALSE]
  if (nrow(row) == 0 || !("Variable_Type" %in% names(row))) return(NA_character_)
  as.character(row$Variable_Type[1])
}


#' Min_Value / Max_Value range for a Numeric question (from the structure)
#'
#' @param qcode Question code
#' @param survey_structure Loaded structure (needs $questions)
#' @return list(min, max): each numeric or NA when unset
#' @keywords internal
micro_numeric_range <- function(qcode, survey_structure) {
  none <- list(min = NA_real_, max = NA_real_)
  q <- survey_structure$questions
  if (is.null(q) || !("QuestionCode" %in% names(q))) return(none)
  row <- q[!is.na(q$QuestionCode) & q$QuestionCode == qcode, , drop = FALSE]
  if (nrow(row) == 0) return(none)
  rng <- none
  if ("Min_Value" %in% names(row)) {
    rng$min <- suppressWarnings(as.numeric(row$Min_Value[1]))
  }
  if ("Max_Value" %in% names(row)) {
    rng$max <- suppressWarnings(as.numeric(row$Max_Value[1]))
  }
  rng
}


#' Raw OptionText -> numeric mean score map for a scale/NPS/Likert question
#'
#' Reuses the processors' option->value logic exactly: Rating/NPS use
#' OptionValue (else numeric OptionText), NPS then bucketed; Likert uses
#' Index_Weight. Options flagged ExcludeFromIndex=Y are dropped, mirroring
#' calculate_rating_mean(). Values with no numeric score become NA (excluded).
#'
#' @param qcode Question code
#' @param survey_structure Loaded structure
#' @param vt Variable_Type ("Rating" | "Likert" | "NPS")
#' @return Named numeric vector OptionText -> score
#' @keywords internal
micro_score_value_map <- function(qcode, survey_structure, vt) {
  opt <- survey_structure$options
  empty <- setNames(numeric(0), character(0))
  if (is.null(opt) || !("QuestionCode" %in% names(opt))) return(empty)
  qopt <- opt[!is.na(opt$QuestionCode) & opt$QuestionCode == qcode, , drop = FALSE]
  if (nrow(qopt) == 0) return(empty)
  if ("ExcludeFromIndex" %in% names(qopt)) {
    qopt <- qopt[is.na(qopt$ExcludeFromIndex) | qopt$ExcludeFromIndex != "Y", , drop = FALSE]
  }
  if (nrow(qopt) == 0) return(empty)
  vals <- vapply(seq_len(nrow(qopt)), function(i) {
    if (vt == "Likert") {
      iw <- if ("Index_Weight" %in% names(qopt)) qopt$Index_Weight[i] else NA
      suppressWarnings(as.numeric(iw))
    } else {
      v <- option_numeric_value(qopt[i, , drop = FALSE])
      if (vt == "NPS") nps_bucket_score(v) else v
    }
  }, numeric(1))
  setNames(vals, trimws(as.character(qopt$OptionText)))
}


#' Declared slot count for an Allocation question (from the structure)
#'
#' The same Columns cell process_allocation_question() reads, so the writer and
#' the published table agree on how many slots the question has.
#'
#' @param qcode Question code
#' @param survey_structure Loaded structure (needs $questions)
#' @return Integer slot count, or NA_integer_
#' @keywords internal
micro_allocation_n_cols <- function(qcode, survey_structure) {
  q <- survey_structure$questions
  if (is.null(q) || !all(c("QuestionCode", "Columns") %in% names(q))) {
    return(NA_integer_)
  }
  row <- q[!is.na(q$QuestionCode) & q$QuestionCode == qcode, , drop = FALSE]
  if (nrow(row) == 0) return(NA_integer_)
  suppressWarnings(as.integer(row$Columns[1]))
}


#' Boxed console warning that one Allocation question carries no series
#'
#' Visible in the console the Shiny app runs in, which is where Duncan reads
#' them. The published table is untouched; only the live recompute is refused.
#'
#' @param code Question code
#' @param reason One-line reason
#' @return NULL, invisibly
#' @keywords internal
micro_series_refuse <- function(code, reason) {
  cat("\n")
  cat("┌─── TURAS WARNING ───────────────────────┐\n")
  cat("│ Allocation question: ", code, "\n", sep = "")
  cat("│ ", reason, "\n", sep = "")
  cat("│ The published table is unchanged. This question will say\n")
  cat("│ 'n/a under filter' in the v2 report instead of recomputing.\n")
  cat("└────────────────────────────────────┘\n\n")
  invisible(NULL)
}


#' Per-respondent value series for each item of an Allocation question
#'
#' An Allocation question is {code}_1..{code}_N of numbers published as one MEAN
#' row per option, so it needs N score series under one question code and
#' TR.MICRO.scores holds exactly one. These go under TR.MICRO.series instead,
#' keyed by the item's ZERO-BASED position in the question's data-layer rows[]
#' (the convention boxes and net_members already use), so the index the writer
#' emits is the index the renderer reads.
#'
#' Row j is paired with option j and therefore with column {code}_j, which is
#' the order process_allocation_question() builds its rows in. The pairing is
#' CHECKED against build_allocation_labels() before it is trusted: a label
#' mismatch means the data layer reordered or dropped a row, and a series
#' shifted by one column is the silent failure this guard exists to prevent.
#' On any mismatch, or on duplicate labels (which the data layer collapses to
#' one row via pair_ids), the whole question gets NO series and says so.
#'
#' @param dl_q One built data-layer question (with $rows, $code)
#' @param survey_data Respondent data
#' @param survey_structure Loaded structure (needs $questions, $options)
#' @param n Respondent count
#' @return Named list of length-n numeric vectors keyed by zero-based row
#'   index, or NULL when the question is not an Allocation or the pairing
#'   cannot be trusted
#' @keywords internal
micro_series_for_question <- function(dl_q, survey_data, survey_structure, n) {
  if (!identical(micro_variable_type(dl_q$code, survey_structure), "Allocation")) {
    return(NULL)
  }
  code <- as.character(dl_q$code)
  n_cols <- micro_allocation_n_cols(code, survey_structure)
  if (is.na(n_cols) || n_cols < 1L) return(NULL)

  # Filtered exactly as prepare_question_data() filters it for the processor
  # (Variable_Type is not Multi_Mention, so it is the plain code match, in
  # sheet order, unsorted). Any other order would resolve different labels and
  # refuse every Allocation question.
  opts <- survey_structure$options
  qo <- if (is.null(opts) || !("QuestionCode" %in% names(opts))) {
    NULL
  } else {
    opts[opts$QuestionCode == code, , drop = FALSE]
  }
  labels <- build_allocation_labels(qo, code, n_cols)

  dup <- unique(labels[duplicated(labels)])
  if (length(dup) > 0) {
    micro_series_refuse(code, paste0(
      "two or more options resolve to the same label ('",
      paste(dup, collapse = "', '"),
      "'), so no row can be matched to its own column."))
    return(NULL)
  }

  rows <- dl_q$rows
  if (is.null(rows) || length(rows) == 0) return(NULL)
  mean_idx <- which(vapply(rows, function(r) identical(r$kind, "mean"), logical(1)))
  if (length(mean_idx) != n_cols) {
    micro_series_refuse(code, paste0(
      "the published table has ", length(mean_idx), " mean rows but the question ",
      "declares ", n_cols, " columns, so the rows cannot be paired with them."))
    return(NULL)
  }

  series <- list()
  for (j in seq_along(mean_idx)) {
    ri <- mean_idx[j]
    got <- trimws(as.character(rows[[ri]]$label %||% ""))
    want <- trimws(as.character(labels[j]))
    if (!identical(got, want)) {
      micro_series_refuse(code, paste0(
        "row ", j, " is labelled '", got, "' but option ", j, " resolves to '",
        want, "', so the rows are not in option order."))
      return(NULL)
    }
    col_name <- paste0(code, "_", j)
    if (!(col_name %in% names(survey_data))) {
      micro_series_refuse(code, paste0(
        "column '", col_name, "' is missing from the survey data."))
      return(NULL)
    }
    # The raw slot values, exactly what collect_allocation_values() averages:
    # zero is a value, blank and non-numeric are NA, and no range filter
    # applies (an Allocation has no Min_Value / Max_Value).
    v <- suppressWarnings(as.numeric(survey_data[[col_name]]))
    vals <- rep(NA_real_, n)
    m <- min(n, length(v))
    if (m > 0) vals[seq_len(m)] <- v[seq_len(m)]
    series[[as.character(ri - 1L)]] <- I(vals)
  }
  series
}


#' Per-respondent numeric scores for a question carrying a mean
#'
#' The robust mean-recompute source: a numeric score per respondent (NA when no
#' valid answer), derived from the raw value via micro_score_value_map (Rating/
#' Likert/NPS) or directly (Numeric). Independent of category rows, so it works
#' even when a rating scale publishes only its mean (all categories hidden).
#' NULL when the question has no mean row or an unsupported type.
#'
#' @param dl_q One built data-layer question
#' @param survey_data Respondent data
#' @param survey_structure Loaded structure
#' @param n Respondent count
#' @return Numeric vector length n, or NULL
#' @keywords internal
micro_scores_for_question <- function(dl_q, survey_data, survey_structure, n) {
  has_mean <- any(vapply(dl_q$rows, function(r) identical(r$kind, "mean"), logical(1)))
  if (!has_mean || !(dl_q$code %in% names(survey_data))) return(NULL)
  vt <- micro_variable_type(dl_q$code, survey_structure)
  if (is.na(vt) || !vt %in% c("Rating", "Likert", "NPS", "Numeric")) return(NULL)
  raw <- trimws(as.character(survey_data[[dl_q$code]]))
  if (vt == "Numeric") {
    sc <- suppressWarnings(as.numeric(raw))
    # Mirror the published mean's Min_Value/Max_Value range filter
    # (calculate_numeric_statistics) so a live recomputed mean excludes the
    # same sentinel codes (e.g. 999 = "don't know") the published mean does.
    rng <- micro_numeric_range(dl_q$code, survey_structure)
    if (!is.na(rng$min)) sc[!is.na(sc) & sc < rng$min] <- NA_real_
    if (!is.na(rng$max)) sc[!is.na(sc) & sc > rng$max] <- NA_real_
  } else {
    vmap <- micro_score_value_map(dl_q$code, survey_structure, vt)
    if (length(vmap) == 0) return(NULL)
    sc <- unname(vmap[raw])
  }
  sc[is.na(raw) | raw == ""] <- NA_real_
  as.numeric(sc)
}


#' Per-respondent numeric scores for a COMPOSITE index
#'
#' A composite (e.g. Q_Engage = the mean of the twelve engagement items) has no
#' column in the survey data and no row in the Questions sheet, so
#' micro_scores_for_question() cannot see it, which left composites out of the
#' island entirely. They then could not recompute under a live filter, and the
#' wave tracker skipped any Question_Mapping row pointing at one, silently
#' (\code{wave_contribution()} drops a metric with no scores). This computes the
#' same per-respondent vector the published composite is built from, by calling
#' the composite processor's own maths, so a live recompute and a wave point
#' can never drift from the published figure.
#'
#' @param code The composite's code (e.g. "Q_Engage")
#' @param survey_data Respondent data (the FULL frame, one score per row)
#' @param survey_structure Loaded structure (needs $questions, $options)
#' @param composite_defs The Composite_Metrics sheet, or NULL
#' @return Numeric vector, one per respondent (NA where unscoreable), or NULL
#'   when the code is not a defined composite / the definition is unusable
#' @keywords internal
micro_scores_for_composite <- function(code, survey_data, survey_structure,
                                       composite_defs) {
  if (is.null(composite_defs) || !is.data.frame(composite_defs) ||
      nrow(composite_defs) == 0 ||
      !all(c("CompositeCode", "SourceQuestions") %in% names(composite_defs))) {
    return(NULL)
  }
  if (!exists("calculate_composite_values", mode = "function")) return(NULL)

  hit <- composite_defs[!is.na(composite_defs$CompositeCode) &
                          trimws(as.character(composite_defs$CompositeCode)) == code, ,
                        drop = FALSE]
  if (nrow(hit) == 0) return(NULL)
  def <- hit[1, , drop = FALSE]

  # Parsed exactly as process_composite_question() parses it, so the score a
  # respondent contributes here is the score behind the published cell.
  sources <- trimws(strsplit(as.character(def$SourceQuestions), ",")[[1]])
  sources <- sources[nzchar(sources)]
  if (length(sources) == 0) return(NULL)

  calc_type <- if (!is.null(def$CalculationType) && length(def$CalculationType) > 0 &&
                   !is.na(def$CalculationType) && nzchar(trimws(as.character(def$CalculationType)))) {
    trimws(as.character(def$CalculationType))
  } else {
    "Mean"
  }
  calc_weights <- NULL
  if (identical(calc_type, "WeightedMean")) {
    if (is.null(def$Weights) || is.na(def$Weights) ||
        !nzchar(trimws(as.character(def$Weights)))) {
      return(NULL)   # validated (and refused) upstream; never guess a weighting here
    }
    calc_weights <- suppressWarnings(as.numeric(trimws(strsplit(as.character(def$Weights), ",")[[1]])))
    if (length(calc_weights) != length(sources) || any(is.na(calc_weights))) return(NULL)
  }

  sc <- tryCatch(
    calculate_composite_values(
      data_subset       = survey_data,
      source_questions  = sources,
      calculation_type  = calc_type,
      weights           = calc_weights,
      weight_vector     = NULL,          # NULL -> the per-respondent vector
      questions_df      = survey_structure$questions,
      options_df        = survey_structure$options
    ),
    error = function(e) NULL)

  if (is.null(sc) || length(sc) != nrow(survey_data)) return(NULL)
  sc <- as.numeric(sc)
  # rowMeans/rowSums over an all-NA row yields NaN / 0; the processor already
  # NAs those rows, but coerce defensively. A NaN would serialise as null and a
  # spurious 0 would drag a tracked mean down.
  sc[!is.finite(sc)] <- NA_real_
  sc
}


#' Per-respondent box-category membership for one question
#'
#' Maps each respondent to the data-layer row index of their box-category NET
#' (e.g. "Good (9-10)"), derived from their raw value's BoxCategory. Lets the
#' renderer recompute box NET rows under a filter / custom banner even when the
#' underlying scale is hidden (only the boxes are displayed). NULL when the
#' question has no box-category NET rows or no BoxCategory in the structure.
#'
#' @param dl_q One built data-layer question
#' @param survey_data Respondent data
#' @param survey_structure Loaded structure (needs $options$BoxCategory)
#' @param n Respondent count
#' @return Integer vector length n (box NET row index, or NA), or NULL
#' @keywords internal
micro_box_membership <- function(dl_q, survey_data, survey_structure, n) {
  box_label_to_index <- list()
  for (i in seq_along(dl_q$rows)) {
    r <- dl_q$rows[[i]]
    if (identical(r$kind, "net")) {
      box_label_to_index[[trimws(as.character(r$label))]] <- i - 1L
    }
  }
  if (length(box_label_to_index) == 0) return(NULL)

  opt <- survey_structure$options
  if (is.null(opt) || !all(c("QuestionCode", "BoxCategory") %in% names(opt))) return(NULL)
  qopt <- opt[!is.na(opt$QuestionCode) & opt$QuestionCode == dl_q$code, , drop = FALSE]
  if (nrow(qopt) == 0) return(NULL)
  has_box <- !is.na(qopt$BoxCategory) & nzchar(trimws(as.character(qopt$BoxCategory)))
  if (!any(has_box) || !(dl_q$code %in% names(survey_data))) return(NULL)

  raw_to_box <- setNames(trimws(as.character(qopt$BoxCategory)),
                         trimws(as.character(qopt$OptionText)))
  keys <- trimws(as.character(survey_data[[dl_q$code]]))
  boxcat <- unname(raw_to_box[keys])
  idx <- vapply(boxcat, function(bc) {
    hit <- if (!is.na(bc)) box_label_to_index[[bc]] else NULL
    if (is.null(hit)) NA_integer_ else as.integer(hit)
  }, integer(1))
  idx[is.na(keys) | keys == ""] <- NA_integer_
  if (all(is.na(idx))) NULL else as.integer(idx)
}


#' Build the complete TR.MICRO payload (pure, no file I/O)
#'
#' @param data_layer The built data layer (from build_data_layer)
#' @param survey_data Raw respondent data frame
#' @param survey_structure Loaded survey structure (needs $options)
#' @param banner_info Banner structure
#' @param config_obj Tabs config
#' @param composite_defs The Composite_Metrics sheet (optional). Supplied, each
#'   composite index carries per-respondent scores like any rated question, so it
#'   recomputes under a live filter and can be tracked across waves. Omitted, the
#'   island is exactly what it was before composites were scored.
#' @return A list {n, answers, banner_vars, weights}, plus {scores}, {boxes} and
#'   {series} when any question carries them. `series` is
#'   \code{series[[qcode]][["<zero-based row index>"]]} = a length-n numeric
#'   vector: the per-item value series of an Allocation question, one entry per
#'   published mean row. NULL when microdata
#'   cannot be built (no respondents or no structure): the report then degrades
#'   to published-only (no live filter / custom banner), exactly as before.
#' @export
build_microdata <- function(data_layer, survey_data, survey_structure,
                            banner_info, config_obj, composite_defs = NULL) {
  if (is.null(survey_data) || !is.data.frame(survey_data) || nrow(survey_data) == 0) {
    return(NULL)
  }
  if (is.null(survey_structure) || is.null(survey_structure$options)) return(NULL)
  if (is.null(data_layer$questions) || length(data_layer$questions) == 0) return(NULL)

  n <- nrow(survey_data)
  answers <- list()
  scores <- list()
  boxes <- list()
  series <- list()
  for (q in data_layer$questions) {
    answers[[q$code]] <- micro_answers_for_question(q, survey_data, survey_structure, n)
    sc <- micro_scores_for_question(q, survey_data, survey_structure, n)
    # A composite has no data column and no Questions row, so the standard path
    # returns NULL for it. Score it from its own definition instead.
    if (is.null(sc) && isTRUE(q$composite)) {
      sc <- micro_scores_for_composite(q$code, survey_data, survey_structure,
                                       composite_defs)
    }
    if (!is.null(sc) && any(!is.na(sc))) scores[[q$code]] <- I(sc)
    bx <- micro_box_membership(q, survey_data, survey_structure, n)
    if (!is.null(bx)) boxes[[q$code]] <- I(bx)
    # An Allocation question carries one series per item row instead of one
    # score (see micro_series_for_question). NULL for every other type, so no
    # existing report gains a key.
    sr <- micro_series_for_question(q, survey_data, survey_structure, n)
    if (!is.null(sr) && length(sr) > 0) series[[q$code]] <- sr
  }
  out <- list(
    n           = n,
    answers     = answers,
    banner_vars = micro_banner_vars(banner_info, survey_data, survey_structure, n),
    weights     = I(micro_weights(survey_data, config_obj))
  )
  # Per-respondent mean scores (rating/Likert/NPS/numeric) and box-category
  # membership. The sources for live mean / box-NET recompute; each omitted when
  # no question carries one.
  if (length(scores) > 0) out$scores <- scores
  if (length(boxes) > 0) out$boxes <- boxes
  # Per-item value series for Allocation (constant-sum) questions. Omitted when
  # no question carries one, so every existing report's island is unchanged.
  if (length(series) > 0) out$series <- series
  out
}


#' Serialise a microdata payload to the JSON island string
#'
#' Integer/numeric arrays stay arrays (never unboxed); NA becomes null.
#'
#' @param micro A list from build_microdata()
#' @return A single JSON string, or "null" when micro is NULL
#' @export
serialize_microdata <- function(micro) {
  if (is.null(micro)) return("null")
  jsonlite::toJSON(micro, auto_unbox = TRUE, na = "null", null = "null",
                   digits = 8, pretty = FALSE)
}
