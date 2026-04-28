# ==============================================================================
# BRAND MODULE - AUDIENCE LENS: AUDIENCE DEFINITION PARSING
# ==============================================================================
# Parses audience definitions from the Survey_Structure AudienceLens sheet
# (project-level + category-specific rows) and the Brand_Config Categories
# sheet AudienceLens_Use opt-in column. Returns a normalised list of audience
# objects ready for the engine.
#
# Sheet schema (Survey_Structure.xlsx -> AudienceLens):
#   Category       "ALL" or short cat code (e.g. "DSS")
#   AudienceID     unique id within Category scope (also acts as join key)
#   AudienceLabel  display label
#   PairID         optional; rows sharing a PairID are paired (must have 2)
#   PairRole       "A" or "B" within a PairID
#   FilterColumn   data column name to test
#   FilterOp       == != < > <= >= in not_in
#   FilterValue    literal (or comma-separated for in / not_in)
#
# Per-category opt-in (Brand_Config.xlsx -> Categories sheet):
#   AudienceLens_Use   "ALL" | "ALL_AVAILABLE" | comma-separated AudienceIDs
#                      (blank = audience lens not enabled for this category)
#
# VERSION: 1.0
# ==============================================================================

BRAND_AL_AUDIENCES_VERSION <- "1.0"


#' Parse and validate audience definitions for one category
#'
#' Loads the AudienceLens sheet from the survey structure, joins it with the
#' AudienceLens_Use opt-in declared on the Categories sheet, and returns a
#' validated list of audience objects ready for \code{run_audience_lens()}.
#'
#' @param structure List. Loaded survey structure (must contain
#'   \code{audience_lens} or be NULL when the sheet is absent).
#' @param config List. Loaded brand config.
#' @param cat_code Character. Short category code (e.g. "DSS"). Determines
#'   which category-scoped audiences are eligible.
#' @param cat_name Character. Category display name (matches Categories$Category).
#' @param data Data frame. Survey data, used to validate filter columns exist.
#' @param thresholds List. From \code{.al_resolve_thresholds()}; we only need
#'   \code{max_audiences} here for the ceiling check.
#'
#' @return List of audience objects. Empty list when audience lens is not
#'   enabled for this category (Categories$AudienceLens_Use blank).
#'   TRS refusal when validation fails (unknown column, malformed filter,
#'   exceeded ceiling, broken pair).
#'
#' @export
parse_audience_lens_definitions <- function(structure, config, cat_code,
                                            cat_name, data,
                                            thresholds = NULL) {

  thresholds <- thresholds %||% list(max_audiences = 6L)
  max_a <- as.integer(thresholds$max_audiences %||% 6L)

  # 1) Locate the per-category opt-in
  cats <- config$categories
  if (is.null(cats) || nrow(cats) == 0) return(list())
  if (!"AudienceLens_Use" %in% names(cats)) return(list())

  cat_row <- cats[trimws(as.character(cats$Category)) == cat_name, , drop = FALSE]
  if (nrow(cat_row) == 0) return(list())

  use_raw <- trimws(as.character(cat_row$AudienceLens_Use[1]))
  if (is.na(use_raw) || !nzchar(use_raw)) return(list())

  # 2) Locate the audience definitions sheet
  defs <- structure$audience_lens
  if (is.null(defs) || !is.data.frame(defs) || nrow(defs) == 0) {
    return(.al_audience_refuse(
      "CFG_AUDIENCE_LENS_SHEET_MISSING",
      sprintf("Categories sheet enables AudienceLens_Use='%s' for '%s' but Survey_Structure has no AudienceLens sheet",
              use_raw, cat_name),
      "Add an AudienceLens sheet to Survey_Structure.xlsx with audience definitions, or clear AudienceLens_Use on Categories sheet"))
  }

  # Strip help / blank rows
  defs <- defs[!is.na(defs$AudienceID) &
                 trimws(as.character(defs$AudienceID)) != "" &
                 !grepl("^\\[", as.character(defs$AudienceID)), , drop = FALSE]
  if (nrow(defs) == 0) return(list())

  # 3) Filter to rows in scope: ALL or matching cat_code
  scope_mask <- trimws(as.character(defs$Category)) %in% c("ALL", cat_code)
  in_scope <- defs[scope_mask, , drop = FALSE]
  if (nrow(in_scope) == 0) return(list())

  # 4) Resolve which IDs apply to this category from the opt-in spec.
  #    Accept either AudienceID or PairID — listing a PairID pulls both
  #    pair members in.
  selected_ids <- if (toupper(use_raw) %in% c("ALL", "ALL_AVAILABLE")) {
    unique(trimws(as.character(in_scope$AudienceID)))
  } else {
    parts <- strsplit(use_raw, "[,;]")[[1]]
    parts <- trimws(parts[nzchar(trimws(parts))])
    if ("PairID" %in% names(in_scope)) {
      # Expand any token matching a PairID into the member AudienceIDs
      pair_tokens <- intersect(parts, trimws(as.character(in_scope$PairID)))
      members_from_pairs <- trimws(as.character(
        in_scope$AudienceID[in_scope$PairID %in% pair_tokens]))
      parts <- unique(c(parts, members_from_pairs))
    }
    parts
  }

  # 5) Pull pair partners along even if the user listed only one side: a pair
  #    is meaningless without both halves.
  if ("PairID" %in% names(in_scope)) {
    pair_ids_for_selected <- unique(trimws(as.character(
      in_scope$PairID[in_scope$AudienceID %in% selected_ids])))
    pair_ids_for_selected <- pair_ids_for_selected[
      !is.na(pair_ids_for_selected) & nzchar(pair_ids_for_selected)]
    partner_ids <- unique(trimws(as.character(
      in_scope$AudienceID[in_scope$PairID %in% pair_ids_for_selected])))
    selected_ids <- unique(c(selected_ids, partner_ids))
  }

  selected <- in_scope[trimws(as.character(in_scope$AudienceID)) %in% selected_ids,
                        , drop = FALSE]
  if (nrow(selected) == 0) return(list())

  # 6) Ceiling check (counts audiences, not rows: pair counts as 1)
  audience_count <- length(unique(.al_count_key(selected)))
  if (audience_count > max_a) {
    return(.al_audience_refuse(
      "CFG_AUDIENCE_CEILING_EXCEEDED",
      sprintf("Category '%s' declares %d audiences but the ceiling is %d",
              cat_name, audience_count, max_a),
      sprintf("Reduce AudienceLens_Use to <= %d audiences (pairs count as one)", max_a)))
  }

  # 7) Build typed audience objects + validate every filter
  out <- list()
  for (i in seq_len(nrow(selected))) {
    row <- selected[i, , drop = FALSE]
    a <- list(
      id          = trimws(as.character(row$AudienceID)),
      label       = trimws(as.character(row$AudienceLabel %||% row$AudienceID)),
      category    = trimws(as.character(row$Category)),
      pair_id     = if ("PairID" %in% names(row))
                       .al_blank_to_null(row$PairID) else NULL,
      pair_role   = if ("PairRole" %in% names(row))
                       toupper(trimws(as.character(row$PairRole %||% ""))) else "",
      filter_col  = trimws(as.character(row$FilterColumn)),
      filter_op   = trimws(as.character(row$FilterOp)),
      filter_value = trimws(as.character(row$FilterValue))
    )

    err <- validate_audience_filter(a, data)
    if (!is.null(err)) return(err)

    out[[length(out) + 1L]] <- a
  }

  # 8) Pair integrity: every PairID must have exactly two members with
  #    distinct roles A and B.
  pair_check <- .al_validate_pair_integrity(out, cat_name)
  if (!is.null(pair_check)) return(pair_check)

  out
}


#' Validate one audience's filter against the survey data
#'
#' Checks the filter column exists, the operator is recognised, and the
#' filter value parses for the operator. Returns NULL on PASS, or a
#' brand_refuse-style refusal list.
#'
#' @keywords internal
validate_audience_filter <- function(a, data) {
  valid_ops <- c("==", "!=", "<", ">", "<=", ">=", "in", "not_in",
                 "is_na", "not_na")
  if (!a$filter_op %in% valid_ops) {
    return(.al_audience_refuse(
      "CFG_AUDIENCE_FILTER_OP_INVALID",
      sprintf("Audience '%s' uses unknown FilterOp '%s'",
              a$id, a$filter_op),
      sprintf("Use one of: %s", paste(valid_ops, collapse = ", "))))
  }

  if (!a$filter_op %in% c("is_na", "not_na")) {
    if (is.na(a$filter_value) || !nzchar(a$filter_value)) {
      return(.al_audience_refuse(
        "CFG_AUDIENCE_FILTER_VALUE_MISSING",
        sprintf("Audience '%s' (op '%s') has no FilterValue",
                a$id, a$filter_op),
        "Set FilterValue (or use is_na / not_na which take no value)"))
    }
  }

  if (!a$filter_col %in% names(data)) {
    return(.al_audience_refuse(
      "DATA_AUDIENCE_FILTER_COL_MISSING",
      sprintf("Audience '%s' filters on column '%s' which is not in the data",
              a$id, a$filter_col),
      sprintf("Either correct AudienceLens$FilterColumn for '%s' or check the data file has that column",
              a$id)))
  }

  NULL
}


#' Resolve an audience definition to a logical row index over `data`
#'
#' @param a Audience definition (one element from
#'   \code{parse_audience_lens_definitions()}).
#' @param data Data frame.
#' @return Logical vector of length \code{nrow(data)}.
#' @export
resolve_audience_index <- function(a, data) {
  col <- data[[a$filter_col]]
  op  <- a$filter_op
  val <- a$filter_value

  # Numeric coercion when the column is numeric AND the value parses
  if (is.numeric(col) && !op %in% c("is_na", "not_na", "in", "not_in")) {
    num <- suppressWarnings(as.numeric(val))
    if (!is.na(num)) val_cmp <- num else val_cmp <- val
  } else {
    val_cmp <- val
  }

  idx <- switch(op,
    "==" = !is.na(col) & .al_coerce_eq(col, val_cmp),
    "!=" = !is.na(col) & !.al_coerce_eq(col, val_cmp),
    "<"  = !is.na(col) & col <  val_cmp,
    ">"  = !is.na(col) & col >  val_cmp,
    "<=" = !is.na(col) & col <= val_cmp,
    ">=" = !is.na(col) & col >= val_cmp,
    "in" = !is.na(col) & .al_coerce_in(col, .al_split_list(val)),
    "not_in" = !is.na(col) & !.al_coerce_in(col, .al_split_list(val)),
    "is_na"  = is.na(col),
    "not_na" = !is.na(col),
    rep(FALSE, length(col))
  )
  if (is.null(idx)) idx <- rep(FALSE, length(col))
  idx
}


# ==============================================================================
# Internals
# ==============================================================================

.al_coerce_eq <- function(col, val) {
  if (is.numeric(col) && is.numeric(val)) return(col == val)
  if (is.logical(col)) {
    val_lc <- tolower(as.character(val))
    if (val_lc %in% c("true", "t", "1", "yes", "y")) return(col)
    if (val_lc %in% c("false", "f", "0", "no", "n")) return(!col)
  }
  trimws(as.character(col)) == trimws(as.character(val))
}


.al_coerce_in <- function(col, vals) {
  if (is.numeric(col)) {
    nums <- suppressWarnings(as.numeric(vals))
    if (!any(is.na(nums))) return(col %in% nums)
  }
  trimws(as.character(col)) %in% trimws(as.character(vals))
}


.al_split_list <- function(val) {
  parts <- strsplit(as.character(val), "[,;|]")[[1]]
  trimws(parts[nzchar(trimws(parts))])
}


.al_blank_to_null <- function(x) {
  v <- trimws(as.character(x %||% ""))
  if (is.na(v) || !nzchar(v)) NULL else v
}


# Pair counts as one audience for the ceiling — give it a single key.
.al_count_key <- function(selected) {
  if ("PairID" %in% names(selected)) {
    pid <- trimws(as.character(selected$PairID))
    ifelse(is.na(pid) | !nzchar(pid),
           trimws(as.character(selected$AudienceID)), pid)
  } else {
    trimws(as.character(selected$AudienceID))
  }
}


.al_validate_pair_integrity <- function(audiences, cat_name) {
  pids <- vapply(audiences, function(a) a$pair_id %||% "", character(1))
  for (pid in unique(pids[nzchar(pids)])) {
    members <- audiences[pids == pid]
    if (length(members) != 2) {
      return(.al_audience_refuse(
        "CFG_AUDIENCE_PAIR_INCOMPLETE",
        sprintf("Pair '%s' for category '%s' has %d members (expected exactly 2)",
                pid, cat_name, length(members)),
        "Each PairID needs exactly two AudienceLens rows, with PairRole 'A' and 'B'"))
    }
    roles <- toupper(vapply(members, function(m) m$pair_role %||% "",
                            character(1)))
    if (!setequal(roles, c("A", "B"))) {
      return(.al_audience_refuse(
        "CFG_AUDIENCE_PAIR_ROLE_INVALID",
        sprintf("Pair '%s' members do not have PairRole A and B (got: %s)",
                pid, paste(roles, collapse = ", ")),
        "Set PairRole='A' and 'B' on the two AudienceLens rows for this PairID"))
    }
  }
  NULL
}


.al_audience_refuse <- function(code, problem, how_to_fix) {
  res <- list(status = "REFUSED", code = code,
              message = problem, how_to_fix = how_to_fix)
  cat(sprintf("\n[AUDIENCE LENS CONFIG] %s: %s\n  Fix: %s\n",
              code, problem, how_to_fix))
  res
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Audience lens audiences loaded (v%s)",
                  BRAND_AL_AUDIENCES_VERSION))
}
