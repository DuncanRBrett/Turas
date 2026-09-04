# ==============================================================================
# TABS. AGGREGATE CUBE WRITER (data-centric report v2)
# ==============================================================================
# Emits the `data-cube` island (TR.CUBE): precomputed sufficient statistics per
# (variable combination, question, cell), so the v2 renderer's stats engine can
# recompute a filtered or custom-bannered table WITHOUT carrying one array
# position per respondent.
#
# Why this exists. `data-micro` carries a row per respondent, and its indices
# join to the `data-agg` labels to reproduce a respondent-by-question dataset.
# The only alternative until now was html_report_v2_microdata = N, which ships
# published tables and switches off the live filter, custom banners,
# Differences, Pattern Recognition, confidence detail and the Reader's computed
# passages. The cube is the middle: the same figures, from aggregates.
#
# The rules this file implements, from
# docs/disclosure/DESIGN_aggregate_interactivity_FABLE.md:
#
#   * The unit of suppression is the BLOCK, one (variable combination,
#     question), never the cell. A cell suppressed on its own is recovered by
#     subtraction from the margin that remains, which was measured on the demo
#     and matched exactly.
#   * A block ships when every OCCUPIED cell's answered base for that question
#     is at least k. A cell nobody answered (base 0) discloses nothing and does
#     not block. Refused blocks are written as null so the renderer can say the
#     cut is not available rather than compute a wrong number.
#   * A block ships only if every projection of it ships (drop one variable).
#     Enforced constructively, from order 0 upward, so "every projection of a
#     shipped block is shipped" is an invariant of the file rather than a hope.
#   * Only DECLARED variables: the banner groups plus the questions named in
#     html_report_v2_filter_vars. A client cannot invent a cut that was not
#     declared.
#
# Correctness contract. Every accumulator below mirrors the corresponding loop
# in assets/js/21_stats.js, including its base definition, because the two must
# produce identical figures. The cube is built from the MICRODATA LIST that
# build_microdata() returns, never from survey_data, so the two engines consume
# byte-identical inputs and any difference between them is an accumulation bug
# rather than a mapping bug. Held to that by
# modules/tabs/lib/html_report_v2/tests/computed_parity_tests.mjs (CP-4), which
# runs the same enumerated views through both sources and compares them cell by
# cell, letters included.
#
# The five bases the engine actually has (21_stats.js), and where each lands:
#   tabulate      raw answer present OR box present        -> `b`
#   netCounts     raw answer present only                  -> `nb` (when it differs)
#   boxCounts     box present OR answer present            -> `b` (identical)
#   indexMeans    score present                            -> `s`
#   seriesMeans   item value present, per item row         -> `sr`
#   ratioOfTotals both values present, denominator above 0 -> `rt`
#   medians       score present, unweighted reports only    -> `m`
# plus the AUDIENCE, everyone in the cell regardless of any question, which is
# what the filter bar, disclosure.audienceBase() and the Reader count -> `a`.
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

CUBE_SCHEMA_VERSION <- 1L
CUBE_ANSWERED_UNSHOWN <- -2L   # answered, the chosen option is not displayed
CUBE_NO_COLUMN <- -1L          # respondent falls in no column of a banner group


#' Zero-based indices of a data-layer question's rows of one kind
#'
#' @param dl_q One built data-layer question
#' @param kind "category" or "net"
#' @return Integer vector of zero-based row indices (possibly empty)
#' @keywords internal
cube_row_indices <- function(dl_q, kind) {
  rows <- dl_q$rows
  if (is.null(rows) || length(rows) == 0) return(integer(0))
  keep <- vapply(rows, function(r) identical(r$kind, kind), logical(1))
  as.integer(which(keep) - 1L)
}


#' Per-respondent level of one declared variable
#'
#' A banner variable's level is the zero-based TR.AGG.columns index the
#' respondent's banner_vars entry carries; -1 ("in no column of this group")
#' means the respondent is in no cell of any slice containing this variable,
#' which is exactly what columnsFor does today.
#'
#' A question variable's level is the respondent's category row index. The
#' answered-unshown marker (-2) and a never-answered NA both mean no level.
#'
#' @param vdef One variable definition from cube_var_defs()
#' @param micro The microdata list
#' @return Integer vector length micro$n; NA means "in no cell of this variable"
#' @keywords internal
cube_var_levels <- function(vdef, micro) {
  n <- micro$n
  if (identical(vdef$kind, "banner")) {
    v <- as.integer(micro$banner_vars[[vdef$source]])
    v[is.na(v) | v == CUBE_NO_COLUMN | v < 0L] <- NA_integer_
    return(v)
  }
  a <- micro$answers[[vdef$source]]
  if (is.list(a)) {
    # A multi-mention answer is a set, not a partition, so it can never be a
    # declared filter variable. Guarded at config time (CFG_CUBE_FILTER_VAR);
    # this is the belt to that brace.
    return(rep(NA_integer_, n))
  }
  v <- as.integer(a)
  # The two sentinels are excluded by name rather than by "v >= 0", so the rule
  # reads as the thing it is: answered-but-not-displayed puts a respondent in no
  # category, and no-column-of-this-group puts them in no cell.
  ok <- !is.na(v) & v != CUBE_ANSWERED_UNSHOWN & v != CUBE_NO_COLUMN &
    v %in% vdef$levels
  out <- rep(NA_integer_, n)
  out[ok] <- v[ok]
  out
}


#' The declared variables of a cube
#'
#' Banner groups first, in the data layer's own order, then the questions named
#' in html_report_v2_filter_vars, in the order they were declared. That order is
#' the slice-key order, so a cell key is unambiguous.
#'
#' @param micro The microdata list
#' @param data_layer The built data layer
#' @param filter_vars Character vector of declared question codes
#' @return Named list of variable definitions
#' @keywords internal
cube_var_defs <- function(micro, data_layer, filter_vars = character(0)) {
  defs <- list()
  groups <- data_layer$banner_groups
  group_ids <- if (is.null(groups)) character(0)
    else vapply(groups, function(g) as.character(g$id), character(1))
  cols <- data_layer$columns
  for (gid in group_ids) {
    if (is.null(micro$banner_vars[[gid]])) next
    levels <- integer(0)
    for (i in seq_along(cols)) {
      if (identical(as.character(cols[[i]]$group), gid)) levels <- c(levels, i - 1L)
    }
    if (length(levels) == 0) next
    defs[[gid]] <- list(name = gid, kind = "banner", source = gid,
                        levels = as.integer(levels))
  }
  qs <- data_layer$questions
  by_code <- list()
  for (q in qs) by_code[[q$code]] <- q
  rejected <- character(0)
  for (code in filter_vars) {
    if (!is.null(defs[[code]])) next          # already a banner variable
    if (is.null(by_code[[code]])) {
      rejected[code] <- "no such question in this report"
      next
    }
    levels <- cube_row_indices(by_code[[code]], "category")
    if (length(levels) == 0) {
      rejected[code] <- "no category rows to cut by (a mean-only or derived question)"
      next
    }
    if (is.list(micro$answers[[code]])) {
      # A multi-mention answer is a SET, not a partition: "filter to option 3"
      # and "filter to option 4" overlap, so their cells cannot be summed and
      # every figure under such a filter would double-count. Refused rather
      # than half-supported; inclusion and exclusion terms are a version 2 item.
      rejected[code] <- "a multi-mention question, which is a set rather than a partition"
      next
    }
    defs[[code]] <- list(name = code, kind = "question", source = code,
                         levels = as.integer(levels))
  }
  attr(defs, "rejected") <- rejected
  defs
}


#' Per-respondent quantity matrix for one question
#'
#' One row per respondent, one column per number the cube has to sum. Built ONCE
#' per question and then aggregated by each slice's cell, which is what keeps a
#' 40-slice cube on a 2,000-respondent study cheap.
#'
#' Every column mirrors the matching loop in 21_stats.js. Read the base
#' definitions in this file's header before changing one.
#'
#' @param dl_q One built data-layer question
#' @param micro The microdata list
#' @param w Per-respondent weights (numeric, length n)
#' @return list(mat, spec, has, score_src, scores) or NULL when the question
#'   carries nothing the engine can recompute from
#' @keywords internal
cube_question_fields <- function(dl_q, micro, w, weighted = FALSE) {
  n <- micro$n
  code <- dl_q$code
  answers <- micro$answers[[code]]
  boxes <- if (!is.null(micro$boxes)) micro$boxes[[code]] else NULL
  series <- if (!is.null(micro$series)) micro$series[[code]] else NULL
  micro_scores <- if (!is.null(micro$scores)) micro$scores[[code]] else NULL

  is_multi <- is.list(answers)
  # A single-response channel is a plain integer vector; a multi-mention one is
  # a list of integer vectors. Both are normalised to "raw answer present" and
  # "is this row selected" below, never to a shape the JS does not have.
  if (is_multi) {
    # An answered-but-only-unshown multi-mention is an EMPTY vector, which is
    # still answered (it counts in the base and in no row). A length-1 NA is
    # never-answered. micro_answers_multi() writes exactly those three shapes.
    raw_present <- vapply(answers, function(a) {
      !(length(a) == 1L && is.na(a[[1]]))
    }, logical(1))
    av2 <- NULL
  } else {
    av2 <- as.integer(answers)
    raw_present <- !is.na(av2)
  }
  box_present <- if (is.null(boxes)) rep(FALSE, n) else !is.na(as.integer(boxes))
  answered <- raw_present | box_present          # tabulate / boxCounts base

  has <- character(0)
  if (any(raw_present)) has <- c(has, "answers")
  if (!is.null(micro_scores) && any(!is.na(micro_scores))) has <- c(has, "scores")
  if (!is.null(boxes)) has <- c(has, "boxes")
  if (!is.null(series) && length(series) > 0) has <- c(has, "series")

  cat_rows <- cube_row_indices(dl_q, "category")
  net_rows <- cube_row_indices(dl_q, "net")
  net_members <- dl_q$net_members
  member_rows <- if (is.null(net_members)) integer(0)
    else as.integer(names(net_members))

  # ---- the score channel -----------------------------------------------------
  # indexMeans prefers the carried per-respondent score and falls back to
  # mapping each respondent's category row through q$index_scores, keyed by the
  # ROW LABEL. Both paths are live (the parity fixture's Q5 has index_scores and
  # no carried score), so both are reproduced here. score_src records WHICH, so
  # the renderer's Differences scan can keep asking "did the island carry a real
  # score" the way it does today.
  score_src <- NULL
  scores <- NULL
  if (!is.null(micro_scores) && any(!is.na(micro_scores))) {
    scores <- as.numeric(micro_scores)
    score_src <- "scores"
  } else if (!is.null(dl_q$index_scores) && length(dl_q$index_scores) > 0 && !is_multi) {
    by_row <- rep(NA_real_, length(dl_q$rows))
    for (ri in cat_rows) {
      lab <- dl_q$rows[[ri + 1L]]$label
      s <- dl_q$index_scores[[as.character(lab)]]
      if (!is.null(s) && !is.na(s)) by_row[ri + 1L] <- as.numeric(s)
    }
    if (any(!is.na(by_row))) {
      scores <- rep(NA_real_, n)
      ok <- !is.na(av2) & av2 >= 0L & av2 < length(by_row)
      scores[ok] <- by_row[av2[ok] + 1L]
      if (all(is.na(scores))) scores <- NULL else score_src <- "index"
    }
  }

  # ---- assemble the columns --------------------------------------------------
  cols <- list()
  spec <- list()
  add <- function(name, vec) {
    cols[[length(cols) + 1L]] <<- vec
    spec[[length(spec) + 1L]] <<- name
  }

  add("b.n", as.numeric(answered))
  add("b.sw", ifelse(answered, w, 0))
  add("b.sw2", ifelse(answered, w * w, 0))
  # netCounts counts only respondents with a RAW answer, so its base differs
  # from tabulate's wherever a question carries box membership without an
  # answer. Written only when it actually differs (checked at assembly time).
  add("nb.n", as.numeric(raw_present))
  add("nb.sw", ifelse(raw_present, w, 0))
  add("nb.sw2", ifelse(raw_present, w * w, 0))

  # Category rows. A multi-mention respondent counts in EVERY row they selected,
  # exactly as tabulate's inner loop does. The answered-unshown marker counts in
  # the base and in no row.
  in_row <- function(ri) {
    if (is_multi) {
      vapply(answers, function(a) {
        length(a) > 0 && any(!is.na(a) & a == ri)
      }, logical(1))
    } else {
      !is.na(av2) & av2 == ri
    }
  }
  for (ri in cat_rows) add(paste0("r.", ri), ifelse(in_row(ri), w, 0))

  # Declared NETs. A NET is a UNION: a respondent in two member rows of one NET
  # counts ONCE, which is why every NET needs its own accumulator and cannot be
  # summed from its members.
  for (ri in member_rows) {
    members <- as.integer(net_members[[as.character(ri)]])
    if (is_multi) {
      hit <- vapply(answers, function(a) {
        length(a) > 0 && !all(is.na(a)) && any(a %in% members)
      }, logical(1))
    } else {
      hit <- !is.na(av2) & av2 %in% members
    }
    add(paste0("n.", ri), ifelse(hit, w, 0))
  }

  # Box membership. Keyed by NET row index, because the box index IS the row
  # index (stats.boxCounts / d2.boxRows).
  if (!is.null(boxes)) {
    bv <- as.integer(boxes)
    for (ri in net_rows) add(paste0("x.", ri), ifelse(!is.na(bv) & bv == ri, w, 0))
  }

  # Scores.
  score_values <- NULL
  if (!is.null(scores)) {
    ok <- !is.na(scores)
    add("s.n", as.numeric(ok))
    add("s.sw", ifelse(ok, w, 0))
    add("s.sw2", ifelse(ok, w * w, 0))
    add("s.swx", ifelse(ok, w * scores, 0))
    add("s.swx2", ifelse(ok, w * scores * scores, 0))

    # A MEDIAN cannot come from sums, and a median over a union of cells cannot
    # come from one median per cell either. On a DESIGNED scale (at most 12
    # distinct values, the same rule robustRange uses, because the widest
    # designed scale is 0 to 10 and NPS index scores are three values) the whole
    # distribution is at most 12 counts per cell, so the median of any union of
    # cells is exact. It discloses no more than the category counts beside it:
    # for a rating question the score IS a function of the category row, so `d`
    # and `r` carry the same information. A continuous measure (spend, counts)
    # gets no distribution, and its median is served only where the cut resolves
    # to a single cell.
    #
    # Unweighted only: stats.medians returns null on a weighted report, because
    # a weighted median needs a definition nobody has chosen here.
    if (!weighted) {
      vals <- sort(unique(scores[ok]))
      if (length(vals) > 0 && length(vals) <= 12) {
        score_values <- vals
        for (v in vals) {
          add(paste0("d.", cube_score_key(v)), as.numeric(ok & scores == v))
        }
      }
    }
  }

  # Allocation series: one accumulator set per item row.
  if (!is.null(series) && length(series) > 0) {
    for (key in names(series)) {
      sv <- as.numeric(series[[key]])
      ok <- !is.na(sv)
      add(paste0("sr.", key, ".n"), as.numeric(ok))
      add(paste0("sr.", key, ".sw"), ifelse(ok, w, 0))
      add(paste0("sr.", key, ".sw2"), ifelse(ok, w * w, 0))
      add(paste0("sr.", key, ".swx"), ifelse(ok, w * sv, 0))
      add(paste0("sr.", key, ".swx2"), ifelse(ok, w * sv * sv, 0))
    }
  }

  # Ratio of totals: the average of the UNITS, over everyone holding both values
  # with a denominator above zero. Its two channels are the SCORES of two other
  # questions, so it reads micro$scores directly.
  ratio <- dl_q$ratio
  if (!is.null(ratio) && !is.null(micro$scores)) {
    num <- micro$scores[[as.character(ratio$num)]]
    den <- micro$scores[[as.character(ratio$den)]]
    if (!is.null(num) && !is.null(den)) {
      nv <- as.numeric(num); dv <- as.numeric(den)
      ok <- !is.na(nv) & !is.na(dv) & dv > 0
      add("rt.k", as.numeric(ok))
      add("rt.num", ifelse(ok, w * nv, 0))
      add("rt.den", ifelse(ok, w * dv, 0))
    }
  }

  if (length(cols) == 0) return(NULL)
  mat <- matrix(unlist(cols, use.names = FALSE), nrow = n, byrow = FALSE)
  colnames(mat) <- unlist(spec, use.names = FALSE)
  list(mat = mat, has = has, score_src = score_src, scores = scores,
       score_values = score_values,
       cat_rows = cat_rows, net_rows = net_rows, member_rows = member_rows,
       has_boxes = !is.null(boxes))
}


#' Does this block clear the threshold?
#'
#' A block is one (variable combination, question) and ships WHOLE or not at
#' all. It ships when every occupied cell's answered base is at least k. A cell
#' nobody answered has a base of 0, discloses nothing, and does not block: the
#' published table already renders it as no value.
#'
#' Cell-level suppression is deliberately NOT offered. A suppressed cell is
#' recovered exactly by subtraction from the margins that remain, which was
#' measured on the demo report and reproduced the withheld distribution.
#'
#' @param bases Integer vector of per-cell unweighted bases
#' @param k The confidentiality threshold
#' @return TRUE when the block may ship
#' @export
cube_block_ok <- function(bases, k) {
  if (length(bases) == 0) return(TRUE)
  b <- as.numeric(bases)
  b <- b[!is.na(b)]
  !any(b > 0 & b < k)
}


#' Every combination of declared variables up to an order
#'
#' Order 0 (the empty combination, the whole sample) is always present: the
#' Total column, an unfiltered "the rest" and every projection check need it.
#'
#' @param var_names Character vector in slice-key order
#' @param order Highest combination order
#' @return List of character vectors, shortest first
#' @keywords internal
cube_combinations <- function(var_names, order) {
  out <- list(character(0))
  m <- min(order, length(var_names))
  if (m >= 1) {
    for (d in seq_len(m)) {
      idx <- utils::combn(seq_along(var_names), d, simplify = FALSE)
      for (i in idx) out[[length(out) + 1L]] <- var_names[i]
    }
  }
  out
}


#' Slice key for a variable combination
#'
#' The empty combination (the whole sample) is keyed "*". An empty string is not
#' a usable name in an R list or a JSON object, and "*" cannot collide with a
#' real combination: a one-variable key is a bare variable name, and a declared
#' variable whose name contains "*" is refused at config time
#' (CFG_CUBE_FILTER_VAR / CFG_CUBE_BANNER_NAME).
#' @keywords internal
CUBE_TOTAL_SLICE <- "*"
cube_slice_key <- function(vars) {
  if (length(vars) == 0) CUBE_TOTAL_SLICE else paste(vars, collapse = "*")
}


#' Build the aggregate cube
#'
#' @param micro The list build_microdata() returns. Consumed, never survey_data,
#'   so the cube and the microdata engine share their inputs exactly.
#' @param data_layer The built data layer (build_data_layer)
#' @param config_obj The crosstabs config object
#'
#' @return A list with structure:
#'   \item{schema_version}{Island schema version}
#'   \item{n}{Respondents in the study}
#'   \item{k}{The confidentiality threshold the cube was cut at}
#'   \item{order}{Highest combination order present}
#'   \item{weighted}{TRUE when any weight is not 1}
#'   \item{vars}{Declared variables, in slice-key order}
#'   \item{questions}{Per question, the filter-independent facts}
#'   \item{slices}{Per variable combination, the audience and question blocks}
#'   \item{blocks}{Shipped / refused counts, for the console and the About page}
#'   Returns NULL when there is nothing to build.
#'
#' @examples
#' \dontrun{
#'   micro <- build_microdata(dl, survey_data, structure, banner_info, config)
#'   cube  <- build_cube(micro, dl, config)
#'   json  <- serialize_cube(cube)
#' }
#'
#' @export
build_cube <- function(micro, data_layer, config_obj) {
  if (is.null(micro) || is.null(micro$n) || micro$n == 0) return(NULL)
  if (is.null(data_layer$questions) || length(data_layer$questions) == 0) return(NULL)

  n <- as.integer(micro$n)
  k <- suppressWarnings(as.numeric(config_obj$min_reporting_base))
  if (length(k) != 1L || is.na(k) || k <= 1) k <- 1
  k <- as.numeric(k)
  order <- suppressWarnings(as.integer(config_obj$html_report_v2_cube_order))
  if (length(order) != 1L || is.na(order)) order <- 2L
  order <- max(1L, min(3L, order))
  filter_vars <- config_obj$html_report_v2_filter_vars
  if (is.null(filter_vars)) filter_vars <- character(0)
  filter_vars <- trimws(as.character(filter_vars))
  filter_vars <- filter_vars[nzchar(filter_vars)]

  w <- micro$weights
  w <- if (is.null(w)) rep(1, n) else as.numeric(w)
  weighted <- any(w != 1)

  defs <- cube_var_defs(micro, data_layer, filter_vars)
  rejected_vars <- attr(defs, "rejected") %||% character(0)
  if (length(defs) == 0) return(NULL)
  var_names <- names(defs)
  levels_by_var <- lapply(defs, cube_var_levels, micro = micro)

  # ---- per-question quantities, built once -----------------------------------
  fields <- list()
  qmeta <- list()
  for (q in data_layer$questions) {
    f <- cube_question_fields(q, micro, w, weighted)
    if (is.null(f)) next
    fields[[q$code]] <- f
    meta <- list(has = as.list(f$has))
    if (!is.null(f$score_src)) meta$score_src <- f$score_src
    if (!is.null(f$score_values)) meta$score_values <- as.numeric(f$score_values)
    if (identical(f$score_src, "scores")) {
      sv <- f$scores[!is.na(f$scores)]
      if (length(sv) > 0) {
        meta$score_lo <- min(sv)
        meta$score_hi <- max(sv)
        meta$robust_range <- cube_robust_range(sv,
          max(0, max(sv)) - min(0, min(sv)))
      }
      h <- cube_histogram(q, f$scores, w)
      if (!is.null(h)) meta$histogram <- h
    }
    qmeta[[q$code]] <- meta
  }
  if (length(fields) == 0) return(NULL)

  # ---- slices ----------------------------------------------------------------
  combos <- cube_combinations(var_names, order)
  slices <- list()
  shipped <- 0L
  refused <- 0L
  slices_shipped <- 0L
  slices_refused <- 0L
  cells_suppressed <- 0L
  # A block ships only when every projection of it ships. Computed in increasing
  # order so the projections are already decided; that makes "every projection
  # of a shipped block is shipped" an invariant of the file, not an assertion
  # nobody enforced.
  ok_audience <- list()
  ok_block <- list()

  for (vars in combos) {
    key <- cube_slice_key(vars)
    projections <- if (length(vars) <= 1) list()
      else lapply(seq_along(vars), function(i) cube_slice_key(vars[-i]))
    # A one-variable slice on a BANNER variable IS that banner, and the
    # published crosstab already prints it column by column, base by base, with
    # the sub-k columns blanked. So withholding its small cells one at a time
    # exposes nothing the workbook does not already expose, and the whole-block
    # rule there costs a whole cut for one small group: a department of one
    # takes every other department with it.
    #
    # Every OTHER slice is a crossing nobody published. There the whole-block
    # rule stands, because a cell withheld on its own is recovered exactly by
    # subtraction from a margin the cube itself shipped, which was measured on
    # the demo and reproduced the withheld distribution.
    #
    # The two rules cannot contradict each other. If a banner cell is under k,
    # every finer cell inside it is smaller still, so no order-2 block
    # containing it can pass the whole-block rule and be summed back up.
    published_margin <- length(vars) == 1L &&
      identical(defs[[vars[1]]]$kind, "banner")

    cell_of <- cube_cell_ids(vars, levels_by_var, n)
    if (is.null(cell_of$ids)) {
      slices[key] <- list(NULL)
      ok_audience[[key]] <- FALSE
      for (code in names(fields)) ok_block[[paste0(key, "//", code)]] <- FALSE
      next
    }
    ids <- cell_of$ids
    keys <- cell_of$keys
    present <- !is.na(ids)

    # Audience: everyone in the cell, no question condition.
    aud <- cube_aggregate(cbind(n = 1, sw = w, sw2 = w * w), ids, length(keys), present)
    # A banner column's headcount is the published base row. Gating it would
    # withhold a number the workbook prints.
    aud_ok <- (published_margin || cube_block_ok(aud[, "n"], k)) &&
      all(vapply(projections, function(p) isTRUE(ok_audience[[p]]), logical(1)))
    ok_audience[[key]] <- aud_ok
    if (!aud_ok) {
      # The whole slice goes. Its audience cells are what the filter bar counts,
      # so shipping them while withholding the questions would still say how
      # many people sit in a cut of three.
      slices[key] <- list(NULL)
      slices_refused <- slices_refused + 1L
      refused <- refused + length(fields)
      for (code in names(fields)) ok_block[[paste0(key, "//", code)]] <- FALSE
      next
    }
    slices_shipped <- slices_shipped + 1L

    cells <- list()
    for (ci in seq_along(keys)) {
      if (aud[ci, "n"] == 0) next
      cells[[keys[ci]]] <- list(a = cube_round(c(aud[ci, "n"], aud[ci, "sw"], aud[ci, "sw2"])))
    }

    qblocks <- list()
    for (code in names(fields)) {
      f <- fields[[code]]
      agg <- cube_aggregate(f$mat, ids, length(keys), present)
      bases <- agg[, "b.n"]
      # On a published margin the cells are suppressed one at a time; the block
      # still has to carry SOMETHING, so it is refused only when nothing in it
      # clears the threshold.
      suppress <- if (published_margin) (bases > 0 & bases < k) else rep(FALSE, length(bases))
      # An EMPTY block (nobody anywhere answered this question) ships as it
      # always did: the published table prints those columns with a base of 0
      # and dashes, and calling that "withheld" would claim a protection that is
      # really just an unanswered question. A margin is refused only when it
      # HAS data and none of it clears the threshold.
      block_ok <- if (published_margin) (!any(bases > 0) || any(bases >= k))
                  else cube_block_ok(bases, k)
      block_ok <- block_ok &&
        all(vapply(projections, function(p) {
          isTRUE(ok_block[[paste0(p, "//", code)]])
        }, logical(1)))
      ok_block[[paste0(key, "//", code)]] <- block_ok
      if (!block_ok) {
        qblocks[code] <- list(NULL)
        refused <- refused + 1L
        next
      }
      shipped <- shipped + 1L
      if (any(suppress)) cells_suppressed <- cells_suppressed + sum(suppress)
      qblocks[[code]] <- cube_block_cells(agg, keys, f, k, weighted, ids, present,
                                          suppress)
    }
    slices[[key]] <- list(cells = cells, q = qblocks)
  }

  list(schema_version = CUBE_SCHEMA_VERSION,
       n = n, k = k, order = order, weighted = weighted,
       vars = lapply(defs, function(d) {
         list(kind = d$kind, levels = as.integer(d$levels))
       }),
       questions = qmeta,
       slices = slices,
       blocks = list(shipped = shipped, refused = refused,
                     slices_shipped = slices_shipped,
                     slices_refused = slices_refused,
                     cells_suppressed = cells_suppressed),
       blocks_shipped = shipped, blocks_refused = refused,
       slices_shipped = slices_shipped, slices_refused = slices_refused,
       rejected_vars = rejected_vars,
       cells_suppressed = cells_suppressed,
       # Each respondent's level on each declared variable, NA where they have
       # none. NOT serialised (serialize_cube strips it): it is one value per
       # respondent and is exactly what this island exists not to carry. It is
       # returned so the QUALITATIVE island can tag each comment with the cut
       # its author falls in, k-anonymised, which is what lets a live filter
       # reach the comments on a build with no respondent records.
       respondent_levels = levels_by_var)
}


#' Cell ids and keys for one variable combination
#' @keywords internal
cube_cell_ids <- function(vars, levels_by_var, n) {
  if (length(vars) == 0) {
    # One cell, the whole sample. Keyed "*" for the same reason the slice is:
    # an empty string is not a usable name in an R list or a JSON object.
    return(list(ids = rep(1L, n), keys = CUBE_TOTAL_SLICE))
  }
  lv <- lapply(vars, function(v) levels_by_var[[v]])
  # A cell exists for every DECLARED level combination, not only the observed
  # ones: an empty level still has to render as a base of 0 rather than vanish,
  # which is what columnsFor does today.
  level_sets <- lapply(vars, function(v) sort(unique(as.integer(levels_by_var[[v]][
    !is.na(levels_by_var[[v]])]))))
  if (any(vapply(level_sets, length, integer(1)) == 0)) {
    return(list(ids = NULL, keys = character(0)))
  }
  grid <- expand.grid(level_sets, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  keys <- do.call(paste, c(lapply(grid, as.integer), list(sep = "|")))
  index <- setNames(seq_along(keys), keys)
  own <- do.call(paste, c(lv, list(sep = "|")))
  any_na <- Reduce(`|`, lapply(lv, is.na))
  own[any_na] <- NA_character_
  ids <- unname(index[own])
  list(ids = as.integer(ids), keys = as.character(keys))
}


#' Sum a per-respondent quantity matrix into its cells
#' @keywords internal
cube_aggregate <- function(mat, ids, ncell, present) {
  out <- matrix(0, nrow = ncell, ncol = ncol(mat),
                dimnames = list(NULL, colnames(mat)))
  if (!any(present)) return(out)
  agg <- rowsum(mat[present, , drop = FALSE], group = ids[present], reorder = TRUE)
  rows <- as.integer(rownames(agg))
  out[rows, ] <- agg
  out
}


#' Assemble one shipped block's per-cell records
#'
#' Every optional record type is present for EVERY cell of the block or absent
#' from the whole block, gated on its own count by the same k. A mixed block
#' would let the missing cells be recovered from the margin.
#'
#' `suppress` marks cells that ship their BASE and nothing else. Only a
#' published banner margin sets it: there the base is the workbook's own base
#' row, and withholding the answers is what the workbook does with a column
#' under k. The record carries `sup` so the renderer blanks the column outright
#' rather than reading absent answers as zeros.
#' @keywords internal
cube_block_cells <- function(agg, keys, f, k, weighted, ids, present,
                             suppress = NULL) {
  cn <- colnames(agg)
  pick <- function(prefix) cn[startsWith(cn, prefix)]

  base_n <- agg[, "b.n"]
  occupied <- base_n > 0

  # Optional channels, each gated on its OWN count across the block.
  nb_differs <- any(abs(agg[, "nb.n"] - agg[, "b.n"]) > 1e-9)
  nb_ok <- nb_differs && cube_block_ok(agg[, "nb.n"], k)
  d_cols <- cn[startsWith(cn, "d.")]
  s_cols <- c("s.n", "s.sw", "s.sw2", "s.swx", "s.swx2")
  has_s <- all(s_cols %in% cn)
  s_ok <- has_s && cube_block_ok(agg[, "s.n"], k)
  rt_cols <- c("rt.k", "rt.num", "rt.den")
  has_rt <- all(rt_cols %in% cn)
  rt_ok <- has_rt && cube_block_ok(agg[, "rt.k"], k)
  sr_keys <- unique(sub("^sr\\.(.*)\\.n$", "\\1", grep("^sr\\..*\\.n$", cn, value = TRUE)))
  sr_ok <- length(sr_keys) > 0 &&
    all(vapply(sr_keys, function(kk) cube_block_ok(agg[, paste0("sr.", kk, ".n")], k),
               logical(1)))

  # The median is a scalar per cell, and only on an unweighted report: a
  # weighted median needs a definition nobody has chosen, and stats.medians
  # already returns null for one.
  med <- NULL
  if (!weighted && !is.null(f$scores) && identical(f$score_src, "scores") && s_ok) {
    med <- cube_medians(f$scores, ids, length(keys), present)
  }

  out <- list()
  for (ci in seq_along(keys)) {
    if (!occupied[ci]) next
    rec <- list(b = cube_round(c(agg[ci, "b.n"], agg[ci, "b.sw"], agg[ci, "b.sw2"])))
    if (!is.null(suppress) && isTRUE(suppress[ci])) {
      # Base only. The answers of a group this small do not enter the file.
      rec$sup <- TRUE
      out[[keys[ci]]] <- rec
      next
    }
    if (nb_ok) {
      rec$nb <- cube_round(c(agg[ci, "nb.n"], agg[ci, "nb.sw"], agg[ci, "nb.sw2"]))
    }
    rec$r <- cube_map(agg, ci, pick("r."), "r.")
    nn <- cube_map(agg, ci, pick("n."), "n.")
    if (length(nn) > 0) rec$n <- nn
    xx <- cube_map(agg, ci, pick("x."), "x.")
    if (length(xx) > 0) rec$x <- xx
    if (s_ok) {
      rec$s <- cube_round(c(agg[ci, "s.n"], agg[ci, "s.sw"], agg[ci, "s.sw2"],
                            agg[ci, "s.swx"], agg[ci, "s.swx2"]))
    }
    if (!is.null(med) && !is.na(med[ci])) rec$m <- cube_round(med[ci])
    if (s_ok && length(d_cols) > 0) rec$d <- cube_map(agg, ci, d_cols, "d.")
    if (sr_ok) {
      sr <- list()
      for (kk in sr_keys) {
        sr[[kk]] <- cube_round(c(agg[ci, paste0("sr.", kk, ".n")],
                                 agg[ci, paste0("sr.", kk, ".sw")],
                                 agg[ci, paste0("sr.", kk, ".sw2")],
                                 agg[ci, paste0("sr.", kk, ".swx")],
                                 agg[ci, paste0("sr.", kk, ".swx2")]))
      }
      rec$sr <- sr
    }
    if (rt_ok) {
      rec$rt <- cube_round(c(agg[ci, "rt.k"], agg[ci, "rt.num"], agg[ci, "rt.den"]))
    }
    out[[keys[ci]]] <- rec
  }
  out
}


#' Row / NET / box maps for one cell, zeros omitted
#'
#' The engine initialises every category row to 0 before it tabulates, so a
#' missing key reads back as 0 and the omission cannot change a figure.
#' @keywords internal
cube_map <- function(agg, ci, cols, prefix) {
  out <- structure(list(), names = character(0))
  for (cc in cols) {
    v <- agg[ci, cc]
    if (is.na(v) || v == 0) next
    out[[substring(cc, nchar(prefix) + 1L)]] <- cube_round(v)
  }
  out
}


#' Stable string key for one score value in the `d` distribution map
#'
#' JSON object keys are strings, so a score of 2.5 has to round-trip through
#' one. 15 significant digits is lossless for every double the engine will meet
#' and matches what JavaScript's Number() reads back.
#' @keywords internal
cube_score_key <- function(v) {
  format(as.numeric(v), digits = 15, trim = TRUE, scientific = FALSE)
}


#' Round a sum for the island
#'
#' digits = 8, the same precision the microdata island writes its weights at, so
#' the two sources cannot disagree on a rounding boundary. On an unweighted
#' report every sum is an integer and this is a no-op.
#' @keywords internal
cube_round <- function(x) {
  if (length(x) == 1) return(unname(round(as.numeric(x), 8)))
  unname(round(as.numeric(x), 8))
}


#' Per-cell median of a score vector, unweighted
#' @keywords internal
cube_medians <- function(scores, ids, ncell, present) {
  out <- rep(NA_real_, ncell)
  ok <- present & !is.na(scores)
  if (!any(ok)) return(out)
  sp <- split(as.numeric(scores[ok]), ids[ok])
  for (nm in names(sp)) {
    v <- sort(sp[[nm]])
    len <- length(v)
    if (len == 0) next
    mid <- len %/% 2L
    out[as.integer(nm)] <- if (len %% 2L == 1L) v[mid + 1L] else (v[mid] + v[mid + 1L]) / 2
  }
  out
}


#' Robust scoring range for a question's scores
#'
#' Mirrors robustRange() in assets/js/27d_diffs.js exactly, including the
#' 12-distinct-values rule: a designed scale (at most 12 distinct values, where
#' the widest designed scale is 0 to 10 and NPS index scores are three values)
#' keeps its full range, and anything wider uses the nearest-rank p5 and p95 so
#' one big spender cannot deflate every finding's effect.
#'
#' @param values Non-null scores, full sample, unweighted
#' @param full_range The full anchored range width
#' @return The range WIDTH
#' @keywords internal
cube_robust_range <- function(values, full_range) {
  v <- as.numeric(values)
  distinct <- 0L
  seen <- new.env(parent = emptyenv())
  for (i in seq_along(v)) {
    if (distinct > 12L) break
    key <- as.character(v[i])
    if (!exists(key, envir = seen, inherits = FALSE)) {
      assign(key, TRUE, envir = seen)
      distinct <- distinct + 1L
    }
  }
  if (distinct <= 12L) return(if (full_range > 0) full_range else 1)
  sorted <- sort(v)
  rank_at <- function(p) {
    idx <- min(length(sorted), max(1L, ceiling(p * length(sorted))))
    sorted[idx]
  }
  lo <- rank_at(0.05); hi <- rank_at(0.95)
  rng <- max(0, hi) - min(0, lo)
  if (rng > 0) rng else if (full_range > 0) full_range else 1
}


#' Weighted score histogram for the bimodality read
#'
#' Mirrors gatherBimodality() in assets/js/27f_takeout_data.js, including the
#' zero-based scale detection: "round(v) - 1" assumed a 1..K scale, so a 0 on an
#' NPS-style 0 to 10 scale mapped to bin -1 and the bottom camp was dropped.
#' Built only for the questions that family is eligible for, so an NPS or a
#' 0 to 100 composite gets no histogram here, exactly as today.
#'
#' @return list(counts, scale_max) or NULL
#' @keywords internal
cube_histogram <- function(dl_q, scores, w) {
  if (is.null(scores)) return(NULL)
  if (identical(dl_q$type, "nps") || isTRUE(dl_q$composite)) return(NULL)
  K <- cube_touchpoint_max(dl_q)
  if (is.null(K) || !is.finite(K) || K > 10) return(NULL)
  sv <- as.numeric(scores)
  ok <- !is.na(sv)
  if (!any(ok)) return(NULL)
  lo <- min(round(sv[ok]))
  zero_based <- lo <= 0
  bins <- if (zero_based) K + 1L else K
  shift <- if (zero_based) 0L else 1L
  counts <- rep(0, bins)
  idx <- round(sv[ok]) - shift
  ww <- w[ok]
  keep <- idx >= 0 & idx < bins
  if (any(keep)) {
    tab <- rowsum(ww[keep], group = idx[keep], reorder = TRUE)
    counts[as.integer(rownames(tab)) + 1L] <- as.numeric(tab)
  }
  list(counts = cube_round(counts), scale_max = bins)
}


#' The scale maximum the takeout family reads for a question
#'
#' Mirrors touchpointMax() in 27f_takeout_data.js: the declared scale_max when
#' the island states one, else the highest category label that parses as a
#' number. Returns NULL when neither is available.
#' @keywords internal
cube_touchpoint_max <- function(dl_q) {
  sm <- suppressWarnings(as.numeric(dl_q$scale_max))
  if (length(sm) == 1L && !is.na(sm) && sm != 0) return(sm)
  best <- 0
  if (!is.null(dl_q$index_scores)) {
    for (nm in names(dl_q$index_scores)) {
      v <- suppressWarnings(as.numeric(dl_q$index_scores[[nm]]))
      if (length(v) == 1L && !is.na(v) && v > best) best <- v
    }
  }
  if (best > 0) best else 100
}


#' Check the declared filter variables against the questions that exist
#'
#' The config layer validates the SHAPE of html_report_v2_filter_vars, because
#' that is all it can see. Whether a named question is a single-response
#' question with category rows is a fact about the data layer, so it is checked
#' here, where the questions are known.
#'
#' A multi-mention question is refused rather than half-supported: its answer is
#' a SET, not a partition, so "filter to option 3" and "filter to option 4" are
#' overlapping cuts whose cells cannot be summed. Supporting it needs inclusion
#' and exclusion terms, which is a version 2 item.
#'
#' @param cube The built cube (or NULL)
#' @param data_layer The built data layer
#' @param config_obj The built config object
#'
#' @return NULL when every declared variable is usable, else a TRS refusal list:
#'   \item{status}{"REFUSED"}
#'   \item{code}{"CFG_CUBE_FILTER_VAR"}
#'   \item{message}{Which variables were rejected, and why}
#'   \item{how_to_fix}{What to change in the Settings sheet}
#'
#' @export
cube_validate_filter_vars <- function(cube, data_layer, config_obj) {
  declared <- config_obj$html_report_v2_filter_vars
  if (is.null(declared) || length(declared) == 0) return(NULL)
  by_code <- list()
  for (q in (data_layer$questions %||% list())) by_code[[q$code]] <- q
  banner_ids <- if (is.null(data_layer$banner_groups)) character(0)
    else vapply(data_layer$banner_groups, function(g) as.character(g$id), character(1))
  rejected <- if (!is.null(cube)) (cube$rejected_vars %||% character(0)) else character(0)
  bad <- character(0)
  why <- character(0)
  for (code in declared) {
    if (code %in% banner_ids) next          # already a declared banner variable
    if (code %in% names(rejected)) {
      bad <- c(bad, code); why <- c(why, unname(rejected[code]))
      next
    }
    q <- by_code[[code]]
    if (is.null(q)) {
      bad <- c(bad, code); why <- c(why, "no such question in this report")
      next
    }
    if (length(cube_row_indices(q, "category")) == 0) {
      bad <- c(bad, code)
      why <- c(why, "no category rows to cut by (a mean-only or derived question)")
      next
    }
    if (!is.null(cube) && is.null(cube$vars[[code]])) {
      bad <- c(bad, code)
      why <- c(why, "could not be resolved to a partition of the sample")
    }
  }
  if (length(bad) == 0) return(NULL)
  msg <- paste(sprintf("'%s' (%s)", bad, why), collapse = "; ")
  list(
    status = "REFUSED",
    code = "CFG_CUBE_FILTER_VAR",
    message = paste0(
      "html_report_v2_filter_vars names variables the cube cannot cut by: ", msg, "."),
    how_to_fix = paste0(
      "Declare only single-response questions that publish category rows. ",
      "A multi-mention question is a set rather than a partition and is not ",
      "supported in this version. Remove the named codes from ",
      "html_report_v2_filter_vars, or switch html_report_v2_interactivity to ",
      "'records' if the client needs to cut by them."),
    context = list(declared = declared, rejected = bad)
  )
}


#' Serialise a cube to the JSON island string
#'
#' Sums at digits = 8, the same precision the microdata island writes. NA
#' becomes null. Returns "null" when the cube is NULL, so the caller can always
#' pass the result straight to the report bundler.
#'
#' @param cube A list from build_cube()
#' @return A single JSON string
#' @export
serialize_cube <- function(cube) {
  if (is.null(cube)) return("null")
  out <- cube
  out$blocks_shipped <- NULL
  out$blocks_refused <- NULL
  out$slices_shipped <- NULL
  out$slices_refused <- NULL
  out$rejected_vars <- NULL
  out$respondent_levels <- NULL
  out$cells_suppressed <- NULL
  jsonlite::toJSON(out, auto_unbox = TRUE, na = "null", null = "null",
                   digits = 8, pretty = FALSE)
}
