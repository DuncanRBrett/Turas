# ==============================================================================
# TABS — MICRODATA WRITER (V11, data-centric report v2)
# ==============================================================================
# Emits the anonymised `data-micro` island (TR.MICRO) the v2 renderer's stats
# engine recomputes from when a live filter or a custom ("+ Custom…") banner is
# active. Shape (verified against assets/js/20_data.js d2.validate + 21_stats.js):
#
#   { n, answers: { <qcode>: [rowIndex | [rowIndex…] | -2 | null  per respondent] },
#     banner_vars: { <banner_code>: [aggColumnIndex | -1  per respondent] },
#     weights: [w per respondent] }
#
# Anonymity: ONLY zero-based row/column indices and weights — never a respondent
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
# into is exactly the rows[] the renderer reads — the two can never drift.
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
    # banner slot fallback read), so fall back to the slot rows — otherwise raw
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
#' collapses whitespace — so "Yes  a casual" and "Yes – a casual" match. Used
#' only as a fallback after exact matching, and only when unambiguous.
#'
#' @param x Character vector
#' @return Normalised character vector
#' @keywords internal
micro_normalize_label <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("[‐-―−–—-]", " ", x, perl = TRUE)  # dashes -> space
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
#'      with no structure options) — there the stored value IS the label.
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
  maps <- micro_value_index_map(dl_q, survey_structure)
  has_cols <- dl_q$code %in% names(survey_data) ||
    length(grep(paste0("^\\Q", dl_q$code, "\\E_\\d+$"), names(survey_data),
                perl = TRUE)) > 0
  if (is.null(maps) || !has_cols) {
    return(I(rep(NA_integer_, n)))   # serialises to [null,…] — still length n
  }
  if (identical(dl_q$type, "multi")) {
    return(micro_answers_multi(survey_data, dl_q$code, maps, n))
  }
  I(micro_answers_single(survey_data[[dl_q$code]], maps))
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
#' no BoxCategory map to nothing (the respondent falls in no column — exactly
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
#' Keyed by banner_code — the group id the engine's stats.columnsFor() reads.
#' Built-in single-response banners are covered. Box-category banners
#' (BannerBoxCategory = 'Y') map raw value -> BoxCategory -> column, because
#' their column labels are BoxCategory names, not option DisplayTexts — the
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
#' @return list(min, max) — each numeric or NA when unset
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


#' Build the complete TR.MICRO payload (pure — no file I/O)
#'
#' @param data_layer The built data layer (from build_data_layer)
#' @param survey_data Raw respondent data frame
#' @param survey_structure Loaded survey structure (needs $options)
#' @param banner_info Banner structure
#' @param config_obj Tabs config
#' @return A list {n, answers, banner_vars, weights}, or NULL when microdata
#'   cannot be built (no respondents or no structure) — the report then degrades
#'   to published-only (no live filter / custom banner), exactly as before.
#' @export
build_microdata <- function(data_layer, survey_data, survey_structure,
                            banner_info, config_obj) {
  if (is.null(survey_data) || !is.data.frame(survey_data) || nrow(survey_data) == 0) {
    return(NULL)
  }
  if (is.null(survey_structure) || is.null(survey_structure$options)) return(NULL)
  if (is.null(data_layer$questions) || length(data_layer$questions) == 0) return(NULL)

  n <- nrow(survey_data)
  answers <- list()
  scores <- list()
  boxes <- list()
  for (q in data_layer$questions) {
    answers[[q$code]] <- micro_answers_for_question(q, survey_data, survey_structure, n)
    sc <- micro_scores_for_question(q, survey_data, survey_structure, n)
    if (!is.null(sc) && any(!is.na(sc))) scores[[q$code]] <- I(sc)
    bx <- micro_box_membership(q, survey_data, survey_structure, n)
    if (!is.null(bx)) boxes[[q$code]] <- I(bx)
  }
  out <- list(
    n           = n,
    answers     = answers,
    banner_vars = micro_banner_vars(banner_info, survey_data, survey_structure, n),
    weights     = I(micro_weights(survey_data, config_obj))
  )
  # Per-respondent mean scores (rating/Likert/NPS/numeric) and box-category
  # membership — the sources for live mean / box-NET recompute; each omitted when
  # no question carries one.
  if (length(scores) > 0) out$scores <- scores
  if (length(boxes) > 0) out$boxes <- boxes
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
