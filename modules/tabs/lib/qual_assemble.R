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

# ==============================================================================
# PHASE-2 JOIN: resolve the comment workbook against the HOST survey by ResponseID
# ==============================================================================
#
# The integrated report puts the comments INTO the one main v2 report (Turas report
# = the full deliverable). The comment respondents join to the host survey by their
# ResponseID, so a comment and a closed answer from the same person share the
# anonymous MICRO row index (length nrow(survey_data)) and therefore the main banner
# and the live-filter masks — that is what lets the closed<->open jump filter the
# comments to "the people in this cell" (stats.mask of the active cut).
#
# Only the index changes: the workbook's embedded demographics are kept for the
# in-tab facet filter (so a Student workbook keeps Campus/Course/NPS facets), and a
# SACS workbook with no embedded demos simply yields no facets — the closed->open
# jump supplies the cut instead. Commenters with no matching host respondent are
# dropped (their id resolves to NA, which the island builder already skips).

# Anchor for the host survey's response-id column, matching the workbook reader's
# QUAL_ID_PATTERN so "ID" / "Response ID" / "ResponseID" all resolve.
QUAL_HOST_ID_PATTERN <- "^(response\\s*)?id$"

#' Locate the response-id column in the host survey (config override or the anchor).
#' @param survey_data The host survey data frame.
#' @param id_col Optional configured column name (`qual_join_id_column`); when given
#'   it wins (exact, else case-insensitive). Returns NA when nothing resolves.
#' @return The column name, or NA_character_ when no id column can be found.
qual_find_host_id_column <- function(survey_data, id_col = NULL) {
  nms <- names(survey_data)
  if (!is.null(id_col) && length(id_col) == 1L && !is.na(id_col) &&
      nzchar(trimws(id_col)) && !identical(trimws(id_col), "NA")) {
    id_col <- trimws(id_col)
    if (id_col %in% nms) return(id_col)
    ci <- nms[tolower(nms) == tolower(id_col)]
    return(if (length(ci)) ci[[1]] else NA_character_)
  }
  anchor <- grepl(QUAL_HOST_ID_PATTERN, nms, ignore.case = TRUE)
  if (any(anchor)) return(nms[which(anchor)[1]])
  NA_character_
}

#' Map each host respondent's ResponseID to its 0-based survey row index.
#' First occurrence wins on the (unexpected) duplicate; blank ids are dropped so a
#' blank workbook id never collides with a blank host id.
#' @return A named integer vector: trimmed ResponseID -> 0-based row index.
qual_host_id_to_idx <- function(survey_data, id_col) {
  ids <- trimws(as.character(survey_data[[id_col]]))
  keep <- nzchar(ids) & !is.na(ids) & ids != "NA"
  idx <- (seq_along(ids) - 1L)[keep]
  ids <- ids[keep]
  dup <- duplicated(ids)
  stats::setNames(idx[!dup], ids[!dup])
}

#' Resolve a comment workbook's respondents against the host survey (the Phase-2 join).
#'
#' Builds the same self-contained master (embedded demographics -> banner facets) but
#' re-keys the anonymous index to the host survey's MICRO rows, so the DATA_QUAL island
#' shares the main banner + filter masks. Downstream (`qual_build_data_qual`) is
#' unchanged: it maps each record by `id_to_idx` (NA -> the commenter is not in the
#' host survey, and is skipped) and reads the workbook demographics from the records.
#'
#' @param questions Classified questions from `qual_read_workbook()`.
#' @param survey_data The host survey data frame (the main report's respondents).
#' @param id_col Optional host id column name (`qual_join_id_column`); auto-detected
#'   via the response-id anchor when not supplied.
#' @return list(status, master, matched, total, id_column). `status` is "PASS" with a
#'   `master` keyed to the host rows, or "NO_ID_COLUMN" when no id column resolves
#'   (the caller then falls back to the standalone comment report).
#' @examples
#' \dontrun{
#'   res <- qual_read_workbook("comments.xlsx")
#'   joined <- qual_resolve_against_survey(res$questions, survey_data)
#'   if (joined$status == "PASS") island <- qual_build_data_qual(res$questions, joined$master, cfg)
#' }
qual_resolve_against_survey <- function(questions, survey_data, id_col = NULL) {
  id_column <- qual_find_host_id_column(survey_data, id_col)
  if (is.na(id_column)) {
    return(list(status = "NO_ID_COLUMN", master = NULL, matched = 0L,
                total = 0L, id_column = NA_character_))
  }
  base_master <- qual_build_respondent_master(questions)   # embedded demos + facets
  host_id_to_idx <- qual_host_id_to_idx(survey_data, id_column)

  # How many distinct workbook respondents found a host row (diagnostics only).
  wb_ids <- base_master$ids
  matched <- sum(!is.na(unname(host_id_to_idx[wb_ids])))

  master <- base_master
  master$id_to_idx <- host_id_to_idx           # workbook id -> host MICRO row index
  master$n <- nrow(survey_data)                 # the host respondent (idx) space
  master$ids <- names(host_id_to_idx)
  list(status = "PASS", master = master, matched = matched,
       total = length(wb_ids), id_column = id_column)
}

# ==============================================================================
# HOST-SOURCED DEMOGRAPHIC TAGS (Feature 2) — tag comments with banner variables
# ==============================================================================
#
# The comment workbook may carry no demographics (e.g. CCPB), but the ResponseID join
# makes every host banner variable reachable per comment. These helpers stamp a chosen
# host column's value onto each comment record and register the dimension on the master
# banner, so host tags flow through the SAME demographic_cuts / k-anonymisation / island
# machinery as an embedded workbook demographic — no separate disclosure path.

#' Parse the `qual_tag_dimensions` config into host-column -> tag-label pairs.
#'
#' Syntax: a comma/semicolon list of "Column" or "Column:Label"
#' (e.g. "S03:Centre, S11:Channel"). ':' separates the host column from its display label.
#' @param cfg The config value (may be blank / "NA").
#' @return A list of list(col, label); empty when blank.
qual_parse_tag_dims <- function(cfg) {
  s <- trimws(as.character(cfg))
  if (length(s) != 1L || is.na(s) || !nzchar(s) || s == "NA") return(list())
  parts <- trimws(strsplit(s, "[,;\n]+")[[1]])
  parts <- parts[nzchar(parts)]
  lapply(parts, function(p) {
    if (grepl(":", p, fixed = TRUE)) {
      kv <- trimws(strsplit(p, ":", fixed = TRUE)[[1]])
      list(col = kv[[1]], label = if (length(kv) >= 2L && nzchar(kv[[2]])) kv[[2]] else kv[[1]])
    } else {
      list(col = p, label = p)
    }
  })
}

#' Attach host-survey demographic tags to each comment record.
#'
#' For each configured dimension (a host column + a display label) this stamps the
#' respondent's value onto the record's `demos` bag and registers the dimension on the
#' master banner, so it is k-anonymised and gated exactly like an embedded demographic.
#' A dimension whose column is absent — or whose label duplicates an existing banner
#' dimension — is skipped with a console warning (Shiny-visible).
#'
#' @param questions Classified questions (records carry `id` + a `demos` list).
#' @param master The join master (`id_to_idx` + `banner_dims`).
#' @param tag_dims list(col, label) pairs from `qual_parse_tag_dims()`.
#' @param survey_data The host survey data frame.
#' @return list(questions, master) with host tags stamped + banner dims registered.
qual_attach_host_tags <- function(questions, master, tag_dims, survey_data) {
  if (!length(tag_dims) || is.null(survey_data) || !is.data.frame(survey_data)) {
    return(list(questions = questions, master = master))
  }
  id_to_idx <- master$id_to_idx
  existing <- if (length(master$banner_dims))
    vapply(master$banner_dims, function(d) d$label, character(1)) else character(0)
  added <- list()
  for (td in tag_dims) {
    col <- td$col; label <- td$label
    if (!(col %in% names(survey_data))) {
      cat(sprintf("  [WARNING] qual_tag_dimensions: host column '%s' not found — skipped.\n", col))
      next
    }
    taken <- c(existing, vapply(added, function(d) d$label, character(1)))
    if (label %in% taken) {
      cat(sprintf("  [WARNING] qual_tag_dimensions: label '%s' already a banner dimension — skipped.\n", label))
      next
    }
    colvals <- as.character(survey_data[[col]])
    for (qi in seq_along(questions)) {
      recs <- questions[[qi]]$records
      for (ri in seq_along(recs)) {
        hidx <- unname(id_to_idx[recs[[ri]]$id])
        v <- if (length(hidx) == 1L && !is.na(hidx)) colvals[hidx + 1L] else NA_character_
        v <- if (is.null(v) || is.na(v) || !nzchar(trimws(v)) || trimws(v) == "NA") NA_character_ else trimws(v)
        questions[[qi]]$records[[ri]]$demos[[label]] <- v
      }
    }
    vals <- trimws(colvals); vals <- vals[!is.na(vals) & nzchar(vals) & vals != "NA"]
    added[[length(added) + 1L]] <- list(label = label, values = qual_sort_ids(unique(vals)))
  }
  master$banner_dims <- c(master$banner_dims, added)
  list(questions = questions, master = master)
}
