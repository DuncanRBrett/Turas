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
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Ad Hoc element loaded (v%s)",
                  BRAND_ADHOC_VERSION))
}
