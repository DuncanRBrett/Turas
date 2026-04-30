# ==============================================================================
# BRAND MODULE - AD HOC QUESTIONS ELEMENT
# ==============================================================================
# Computes the cross-tab profile of project-specific questions that fall
# outside the standard CBM battery. An "ad hoc" question is any QuestionMap
# row whose Role is prefixed with "adhoc.":
#
#   adhoc.{KEY}.ALL          -> applies to all respondents
#   adhoc.{KEY}.{CATCODE}    -> applies to respondents in this focal category
#
# Every ad hoc question is profiled by (a) total scope-base and (b) per
# brand-buyer set when a penetration matrix is available.  Unlike
# demographics, ad hoc questions never expose buyer-tier cuts because the
# scope is specific to the question itself and the operator chooses what
# to compare it against in interpretation.
#
# Numeric ad hoc questions are bucketed using the engine's quantile binning
# (see .adhoc_numeric_bins) so the same distribution shape works regardless
# of measurement type.
#
# VERSION: 1.0
# ==============================================================================

BRAND_ADHOC_VERSION <- "1.0"

# Sentinel note rendered by the panel-data builder when no adhoc roles
# resolve (e.g. IPK Wave 1 has no ADHOC_* columns).
ADHOC_PLACEHOLDER_NOTE <- "Data not yet collected for Ad Hoc"


#' Compute the cross-tab profile of one ad hoc question
#'
#' Behaviour mirrors \code{run_demographic_question()} but exposes only
#' total + per-brand cuts. Numeric questions are bucketed into
#' quartiles before profiling; any value type is handled uniformly.
#'
#' @param values Character/numeric vector of responses (one per respondent
#'   in scope). NA = "no answer" and excluded from the base.
#' @param option_codes Character. Option codes in display order. For
#'   numeric questions pass NULL to auto-bucket into quartiles.
#' @param option_labels Character. Display labels parallel to option_codes.
#' @param weights Numeric or NULL. Weights parallel to values.
#' @param pen_mat Numeric matrix or NULL. Respondent x brand 0/1 indicator.
#' @param brand_codes Character. Brand codes parallel to pen_mat columns.
#' @param brand_labels Character or NULL. Display labels parallel to brand_codes.
#' @param variable_type Character. "Single_Response", "Multi_Mention",
#'   "Numeric", or "Rating". Drives bucketing strategy.
#' @param conf_level Numeric. Wilson CI level (default 0.95).
#'
#' @return List with status PASS/REFUSED + total | brand_cut | n_total.
#'   Schema matches the demographic engine for renderer reuse.
#'
#' @export
run_adhoc_question <- function(values,
                                option_codes  = NULL,
                                option_labels = NULL,
                                weights       = NULL,
                                pen_mat       = NULL,
                                brand_codes   = NULL,
                                brand_labels  = NULL,
                                variable_type = "Single_Response",
                                conf_level    = 0.95) {

  if (is.null(values) || length(values) == 0L) {
    return(.adhoc_refuse("DATA_NO_INPUT",
                          "Ad hoc question values vector is empty.",
                          "Pass the data column for this question."))
  }

  # Numeric / Rating fall back to auto-bucketed labels when no option list is
  # supplied. Single/Multi mention require option codes to know the universe.
  prep <- .adhoc_prepare(values, option_codes, option_labels, variable_type)
  if (identical(prep$status, "REFUSED")) return(prep)
  values_used  <- prep$values
  codes        <- prep$codes
  labels       <- prep$labels

  # Reuse the demographic engine — it gives us total + brand_cut for free
  # and applies the same Wilson CI logic.
  if (!exists("run_demographic_question", mode = "function")) {
    return(.adhoc_refuse("PKG_MISSING",
                         "run_demographic_question() not available.",
                         "Source modules/brand/R/11_demographics.R first."))
  }

  res <- run_demographic_question(
    values       = values_used,
    option_codes = codes,
    option_labels = labels,
    weights      = weights,
    focal_buyer  = NULL,
    buyer_tiers  = NULL,
    pen_mat      = pen_mat,
    brand_codes  = brand_codes,
    brand_labels = brand_labels,
    conf_level   = conf_level
  )
  if (identical(res$status, "REFUSED")) return(res)

  list(
    status        = "PASS",
    total         = res$total,
    brand_cut     = res$brand_cut,
    n_total       = res$n_total,
    n_respondents = res$n_respondents,
    weighted      = res$weighted,
    conf_level    = res$conf_level,
    variable_type = variable_type,
    bin_edges     = prep$bin_edges
  )
}


# ==============================================================================
# INTERNAL: VALUE PREPARATION
# ==============================================================================

.adhoc_prepare <- function(values, codes, labels, variable_type) {

  vt <- toupper(trimws(as.character(variable_type %||% "Single_Response")))

  if (vt %in% c("NUMERIC", "RATING") && is.null(codes)) {
    bins <- .adhoc_numeric_bins(values)
    if (is.null(bins)) {
      return(.adhoc_refuse("DATA_NO_NUMERIC",
                            "Ad hoc numeric question has no usable values.",
                            "Check the source column has numeric responses."))
    }
    return(list(status = "PASS", values = bins$values,
                 codes = bins$codes, labels = bins$labels,
                 bin_edges = bins$edges))
  }

  if (is.null(codes) || length(codes) == 0L) {
    return(.adhoc_refuse("CFG_NO_OPTIONS",
                          "No option codes supplied for this ad hoc question.",
                          "Add Options sheet rows for this question, or set its variable_type to Numeric."))
  }

  if (is.null(labels) || length(labels) != length(codes)) {
    labels <- codes
  }

  list(status = "PASS",
       values = as.character(values),
       codes  = as.character(codes),
       labels = as.character(labels),
       bin_edges = NULL)
}


# Quartile binning for numeric questions. Returns coded character vector
# matched against the quartile labels; NAs survive as NA. When fewer than
# four distinct values exist (e.g. only "Yes"/"No" coded as 1/2) we fall
# back to unique-value labelling.
.adhoc_numeric_bins <- function(values) {
  num <- suppressWarnings(as.numeric(values))
  if (all(is.na(num))) return(NULL)

  uniq <- sort(unique(num[!is.na(num)]))
  if (length(uniq) <= 5L) {
    codes  <- as.character(uniq)
    labels <- codes
    return(list(values = as.character(num), codes = codes,
                labels = labels, edges = uniq))
  }

  qs <- stats::quantile(num, probs = c(0, 0.25, 0.5, 0.75, 1.0),
                         na.rm = TRUE, names = FALSE, type = 7)
  qs[1] <- qs[1] - .Machine$double.eps  # include the lowest value
  bin_idx <- cut(num, breaks = qs, include.lowest = TRUE, right = TRUE,
                  labels = FALSE)
  codes  <- c("Q1", "Q2", "Q3", "Q4")
  labels <- c(
    sprintf("Q1: %s–%s",  .adhoc_fmt(qs[1] + .Machine$double.eps), .adhoc_fmt(qs[2])),
    sprintf("Q2: %s–%s",  .adhoc_fmt(qs[2]), .adhoc_fmt(qs[3])),
    sprintf("Q3: %s–%s",  .adhoc_fmt(qs[3]), .adhoc_fmt(qs[4])),
    sprintf("Q4: %s–%s",  .adhoc_fmt(qs[4]), .adhoc_fmt(qs[5]))
  )
  values_chr <- ifelse(is.na(bin_idx), NA_character_, codes[bin_idx])
  list(values = values_chr, codes = codes, labels = labels, edges = qs)
}


.adhoc_fmt <- function(x) {
  if (is.na(x)) return("—")
  if (abs(x - round(x)) < 1e-6) return(sprintf("%.0f", x))
  sprintf("%.1f", x)
}


# ==============================================================================
# INTERNAL: TRS REFUSAL
# ==============================================================================

.adhoc_refuse <- function(code, message, how_to_fix = NULL) {
  out <- list(status = "REFUSED", code = code, message = message)
  if (!is.null(how_to_fix)) out$how_to_fix <- how_to_fix
  cat(sprintf("\n[TURAS Brand/AdHoc] REFUSED %s: %s\n", code, message))
  out
}


# ==============================================================================
# ROLE RESOLUTION
# ==============================================================================

#' Resolve an ad hoc role to a data column + option list + scope
#'
#' Ad hoc roles are namespaced by category code (or "ALL") so the same
#' QuestionMap can carry per-category and brand-level questions side by
#' side.  Returns NULL when the role is absent or its option list cannot
#' be resolved (caller silently skips that question).
#'
#' @param structure List. A loaded survey structure.
#' @param role Character. Exact role name (e.g. "adhoc.brand_love.DSS").
#' @return List with column, codes, labels, question_text, short_label,
#'   variable_type, scope ("ALL" or category code). NULL when not resolvable.
#' @export
resolve_adhoc_role <- function(structure, role) {

  qmap <- structure$questionmap
  if (is.null(qmap) || !"Role" %in% names(qmap) || nrow(qmap) == 0L) return(NULL)
  rows <- qmap[!is.na(qmap$Role) &
                 trimws(as.character(qmap$Role)) == role, , drop = FALSE]
  if (nrow(rows) == 0L) return(NULL)

  client_code <- trimws(as.character(rows$ClientCode[1]))
  if (is.na(client_code) || !nzchar(client_code)) return(NULL)

  question_text <- if ("QuestionText" %in% names(rows))
    as.character(rows$QuestionText[1]) else client_code
  short_label <- if ("QuestionTextShort" %in% names(rows))
    as.character(rows$QuestionTextShort[1]) else question_text
  variable_type <- if ("Variable_Type" %in% names(rows))
    as.character(rows$Variable_Type[1]) else "Single_Response"
  scale_name <- if ("OptionMapScale" %in% names(rows))
    trimws(as.character(rows$OptionMapScale[1])) else ""

  # Scope = trailing token after the question key. e.g.
  #   adhoc.brand_love.DSS   -> scope = "DSS"
  #   adhoc.future_intent.ALL -> scope = "ALL"
  parts <- strsplit(role, ".", fixed = TRUE)[[1]]
  scope <- if (length(parts) >= 3L) parts[length(parts)] else "ALL"

  # Numeric / Rating questions can run without an option list — engine bins
  # them. Other types require option codes (Options or OptionMap).
  if (!exists(".demo_lookup_options", mode = "function")) {
    return(NULL)  # demographics module not yet sourced
  }
  opts <- .demo_lookup_options(structure, client_code, scale_name)
  if (is.null(opts) && !toupper(variable_type) %in% c("NUMERIC", "RATING")) {
    return(NULL)
  }

  list(
    role          = role,
    column        = client_code,
    question_text = question_text,
    short_label   = short_label,
    variable_type = variable_type,
    scope         = scope,
    codes         = if (is.null(opts)) NULL else opts$codes,
    labels        = if (is.null(opts)) NULL else opts$labels
  )
}


# ==============================================================================
# V2 ROLE RESOLUTION + DISPATCH (role-map driven)
# ==============================================================================

#' Resolve an ad hoc role from the v2 role map
#'
#' v2 counterpart to \code{resolve_adhoc_role()}. Walks
#' \code{role_map[[role]]} for column_root + variable_type + option_scale,
#' then resolves the option list via \code{.demo_lookup_options()}. Returns
#' NULL when the role is unmapped or — when \code{data} is supplied — its
#' column is absent from the data (caller silently skips).
#'
#' @param role_map Named list from \code{build_brand_role_map()}.
#' @param role Character. Exact role name (e.g. "adhoc.brand_love.DSS").
#' @param structure List. Loaded survey structure (used to look up the
#'   option scale via the demographics helper).
#' @param data Data frame or NULL. When supplied, the resolver returns NULL
#'   if the resolved column is missing from the data.
#' @return List with role, column, question_text, short_label,
#'   variable_type, scope, codes, labels; or NULL.
#' @export
resolve_adhoc_role_v2 <- function(role_map, role, structure, data = NULL) {
  if (is.null(role_map) || is.null(role) || is.na(role) ||
      !nzchar(as.character(role))) return(NULL)
  entry <- role_map[[as.character(role)]]
  if (is.null(entry) || is.null(entry$column_root) ||
      !nzchar(entry$column_root)) return(NULL)

  column <- entry$column_root
  if (!is.null(data) && !column %in% names(data)) return(NULL)

  question_text <- entry$question_text %||% column
  short_label   <- entry$question_text %||% column
  variable_type <- entry$variable_type %||% "Single_Response"
  scale_name    <- entry$option_scale  %||% ""
  scope         <- .adhoc_scope_from_role(role)

  opts <- if (exists(".demo_lookup_options", mode = "function"))
    .demo_lookup_options(structure, column, scale_name) else NULL

  if (is.null(opts) && !toupper(variable_type) %in% c("NUMERIC", "RATING")) {
    return(NULL)
  }

  list(
    role          = as.character(role),
    column        = column,
    question_text = question_text,
    short_label   = short_label,
    variable_type = variable_type,
    scope         = scope,
    codes         = if (is.null(opts)) NULL else opts$codes,
    labels        = if (is.null(opts)) NULL else opts$labels
  )
}

# Internal: derive scope ("ALL" or category code) from the role suffix.
.adhoc_scope_from_role <- function(role) {
  parts <- strsplit(as.character(role), ".", fixed = TRUE)[[1]]
  if (length(parts) >= 3L) parts[length(parts)] else "ALL"
}


#' Walk the role map for adhoc.* roles in a given scope and run each
#'
#' v2 dispatcher. Replaces the legacy QuestionMap walk with a role-map
#' walk filtered to one scope ("ALL" or a category code). When no roles
#' resolve, returns a structured PASS-empty payload with
#' \code{placeholder = TRUE} and \code{note = ADHOC_PLACEHOLDER_NOTE} so
#' the panel-data renderer can surface a "Data not yet collected for Ad
#' Hoc" card. The orchestrator (00_main.R) is responsible for selecting
#' the right \code{data} / \code{weights} pair per scope (full sample for
#' ALL, category-filtered for a CATCODE).
#'
#' @param role_map Named list from \code{build_brand_role_map()}.
#' @param structure List. Loaded survey structure.
#' @param data Data frame already filtered to the scope's respondent set.
#' @param weights Numeric vector or NULL, parallel to data rows.
#' @param scope_filter Character. "ALL" or a category code.
#' @param pen_mat Numeric matrix or NULL. Respondent x brand 0/1 matrix
#'   for brand cuts (NULL for sample-wide ALL scope).
#' @param brand_codes Character or NULL. Parallel to pen_mat columns.
#' @param brand_labels Character or NULL. Parallel to brand_codes.
#' @return List with status PASS, optional placeholder flag, questions
#'   (named list of records keyed by role), n_roles, scope, n_total,
#'   weighted, and (when placeholder) note.
#' @export
run_adhoc_v2 <- function(role_map, structure, data,
                         weights      = NULL,
                         scope_filter = "ALL",
                         pen_mat      = NULL,
                         brand_codes  = NULL,
                         brand_labels = NULL) {

  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0L) {
    return(.adhoc_v2_placeholder(scope_filter, weights, n_total = 0L))
  }

  roles <- .adhoc_roles_in_scope(role_map, scope_filter)
  if (length(roles) == 0L) {
    return(.adhoc_v2_placeholder(scope_filter, weights, nrow(data)))
  }

  records <- list()
  for (role in roles) {
    spec <- resolve_adhoc_role_v2(role_map, role, structure, data)
    if (is.null(spec)) next
    res <- run_adhoc_question(
      values        = data[[spec$column]],
      option_codes  = spec$codes,
      option_labels = spec$labels,
      weights       = weights,
      pen_mat       = pen_mat,
      brand_codes   = brand_codes,
      brand_labels  = brand_labels,
      variable_type = spec$variable_type
    )
    records[[spec$role]] <- list(
      role          = spec$role,
      column        = spec$column,
      scope         = spec$scope,
      question_text = spec$question_text,
      short_label   = spec$short_label,
      variable_type = spec$variable_type,
      codes         = spec$codes,
      labels        = spec$labels,
      brand_codes   = brand_codes %||% character(0),
      brand_labels  = brand_labels %||% character(0),
      n_scope_base  = nrow(data),
      result        = res
    )
  }

  if (length(records) == 0L) {
    return(.adhoc_v2_placeholder(scope_filter, weights, nrow(data)))
  }

  list(
    status      = "PASS",
    placeholder = FALSE,
    questions   = records,
    n_roles     = length(records),
    scope       = scope_filter,
    n_total     = nrow(data),
    weighted    = !is.null(weights)
  )
}

# Internal: list of adhoc roles whose scope matches the filter.
.adhoc_roles_in_scope <- function(role_map, scope_filter) {
  if (is.null(role_map)) return(character(0))
  adhoc_roles <- grep("^adhoc\\.", names(role_map), value = TRUE)
  if (length(adhoc_roles) == 0L) return(character(0))
  scopes <- vapply(adhoc_roles, .adhoc_scope_from_role, character(1))
  adhoc_roles[scopes == scope_filter]
}

# Internal: structured PASS-empty payload for the renderer.
.adhoc_v2_placeholder <- function(scope_filter, weights, n_total) {
  list(
    status      = "PASS",
    placeholder = TRUE,
    questions   = list(),
    n_roles     = 0L,
    scope       = scope_filter,
    n_total     = n_total,
    weighted    = !is.null(weights),
    note        = ADHOC_PLACEHOLDER_NOTE
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Ad Hoc element loaded (v%s)",
                  BRAND_ADHOC_VERSION))
}
