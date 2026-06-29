# ==============================================================================
# TABS MODULE — QUALITATIVE SELF-CONTAINED ASSEMBLY (respondent master + banner)
# ==============================================================================
#
# Builds the self-contained respondent master from a coded workbook's classified
# questions: unions respondents by ID across sheets into one anonymous index, then
# curates which embedded demographics become banner cuts.
#
# THIS IS THE JOIN SEAM. In Phase 1 the banner + respondent index come from the
# workbook itself (here). In Phase 2 the same downstream code instead receives the
# index + banner from the host survey's microdata — only this file is swapped, the
# DATA_QUAL schema and the AGG/MICRO serialisation are identical. Keep the seam here.
#
# Banner curation: a demographic becomes a banner cut only if it appears in at least
# QUAL_MIN_BANNER_SHEET_FRACTION of the question sheets, so workbook-wide cuts (Campus,
# Centre, NPS category) qualify but per-question grids (e.g. CCPB "Orders" channels) do
# not, and a no-demographics workbook (SACS) yields a Total-only tab.
#
# KNOWN LIMITATION: intra-workbook label drift (e.g. SACAP "NPS" vs "NPS Category",
# Helderberg "Segment" vs "Persona run 3") is treated as distinct dimensions for now;
# a theme_aliases-style harmonisation map is the documented future refinement.
#
# Depends on (sourced by the pipeline): nothing (pure). Run the tests with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_assemble.R")
# ==============================================================================

# A demographic must appear in at least this fraction of question sheets to become
# a banner cut (the rest are treated as per-question detail, not banner dimensions).
QUAL_MIN_BANNER_SHEET_FRACTION <- 0.5

#' Sort respondent IDs or category values, numeric-aware when every value is digits.
#' @param values A character vector.
#' @return The unique values, sorted numerically when all-numeric, else lexically.
qual_sort_ids <- function(values) {
  values <- unique(values)
  if (length(values) && all(grepl("^[0-9]+$", values))) {
    return(values[order(as.numeric(values))])
  }
  sort(values)
}

#' Collect the distinct respondent IDs across all questions and assign a 0-based index.
#' @param questions List of classified questions (each with `$records`).
#' @return list(ids, id_to_idx, n) — `id_to_idx` maps id -> 0-based index.
qual_collect_ids <- function(questions) {
  per_q <- lapply(questions, function(q) vapply(q$records, function(r) r$id, character(1)))
  all_ids <- unlist(per_q, use.names = FALSE)
  all_ids <- all_ids[nzchar(all_ids)]
  sorted <- qual_sort_ids(all_ids)
  list(ids = sorted,
       id_to_idx = stats::setNames(seq_along(sorted) - 1L, sorted),
       n = length(sorted))
}

#' Select which demographic dimensions become banner cuts (frequency-curated).
#' @param questions List of classified questions (each with `$roles$demos`).
#' @return Character vector of banner dimension labels, ordered by prevalence.
qual_banner_dimensions <- function(questions) {
  labels <- unlist(lapply(questions, function(q) {
    vapply(q$roles$demos, function(d) d$label, character(1))
  }), use.names = FALSE)
  if (!length(labels)) return(character(0))
  counts <- table(labels)
  threshold <- max(1L, as.integer(ceiling(QUAL_MIN_BANNER_SHEET_FRACTION * length(questions))))
  kept <- names(counts)[counts >= threshold]
  if (!length(kept)) return(character(0))
  kept[order(-as.integer(counts[kept]), kept)]
}

#' Initialise the respondent master: one entry per id, demographics NA until filled.
#' @return A list of length n; each entry is list(idx, id, demos = named NA list).
qual_init_respondents <- function(ids, banner_labels) {
  lapply(seq_len(ids$n), function(i) {
    demos <- stats::setNames(as.list(rep(NA_character_, length(banner_labels))), banner_labels)
    list(idx = i - 1L, id = ids$ids[[i]], demos = demos)
  })
}

#' Fill each respondent's banner values from the questions (first non-NA value wins).
#' @return The respondents list with demographics populated.
qual_fill_demographics <- function(respondents, questions, id_to_idx, banner_labels) {
  for (q in questions) {
    demo_cols <- vapply(q$roles$demos, function(d) d$label, character(1))
    relevant <- intersect(demo_cols, banner_labels)
    if (!length(relevant)) next
    for (rec in q$records) {
      slot <- id_to_idx[[rec$id]]
      if (is.null(slot) || is.na(slot)) next
      slot <- slot + 1L
      for (label in relevant) {
        value <- rec$demos[[label]]
        if (!is.null(value) && !is.na(value) && is.na(respondents[[slot]]$demos[[label]])) {
          respondents[[slot]]$demos[[label]] <- value
        }
      }
    }
  }
  respondents
}

#' Distinct, sorted category values for one banner dimension across all respondents.
qual_distinct_dim_values <- function(respondents, label) {
  vals <- vapply(respondents, function(r) {
    v <- r$demos[[label]]
    if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
  }, character(1))
  qual_sort_ids(vals[!is.na(vals)])
}

#' Build the self-contained respondent master and curated banner from a workbook.
#'
#' @param questions List of classified questions from `qual_read_workbook()`.
#' @return list(n, ids, id_to_idx, respondents, banner_dims). `banner_dims` is a list
#'   of `list(label, values)`; empty when the workbook carries no shared demographics.
#' @examples
#' \dontrun{
#'   res <- qual_read_workbook("comments.xlsx")
#'   master <- qual_build_respondent_master(res$questions)
#'   length(master$banner_dims)   # number of banner cuts
#' }
qual_build_respondent_master <- function(questions) {
  ids <- qual_collect_ids(questions)
  banner_labels <- qual_banner_dimensions(questions)
  respondents <- qual_init_respondents(ids, banner_labels)
  respondents <- qual_fill_demographics(respondents, questions, ids$id_to_idx, banner_labels)
  banner_dims <- lapply(banner_labels, function(label) {
    list(label = label, values = qual_distinct_dim_values(respondents, label))
  })
  list(n = ids$n, ids = ids$ids, id_to_idx = ids$id_to_idx,
       respondents = respondents, banner_dims = banner_dims)
}
