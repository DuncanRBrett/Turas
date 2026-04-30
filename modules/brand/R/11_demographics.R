# ==============================================================================
# BRAND MODULE - DEMOGRAPHICS ELEMENT
# ==============================================================================
# Computes the demographic profile of the sample as a whole and by brand.
# A "demographic question" is any QuestionMap row whose Role is prefixed with
# "demo." (e.g. demo.AGE, demo.PROVINCE). The role's ClientCode resolves to
# a single column in the data file; cell values are coded option numbers
# whose labels live in either:
#   - the survey-structure Options sheet keyed by QuestionCode, or
#   - the role-registry OptionMap sheet keyed by OptionMapScale.
#
# The engine produces, per question:
#   * total       - weighted % of all respondents in each option
#   * buyer_cut   - % among focal-brand BUYERS vs NON-BUYERS  (when pen vec given)
#   * tier_cut    - % among LIGHT / MEDIUM / HEAVY focal buyers (when supplied)
#   * brand_cut   - % among each brand's buyers (matrix of brand x option)
#
# All percentages are weighted-aware. Wilson 95% CIs accompany every cell.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DEMOGRAPHICS_VERSION <- "1.0"


# ==============================================================================
# PUBLIC API
# ==============================================================================

#' Compute the cross-tab profile of one demographic question
#'
#' Given a single coded vector and a parallel list of option labels, computes
#' the weighted distribution over (a) the total sample, (b) buyer vs
#' non-buyer of the focal brand, (c) light/medium/heavy focal buyers, and
#' (d) every brand's buyer set (brand x option matrix).
#'
#' @param values Numeric or character vector. Coded responses (one per
#'   respondent). NAs are treated as "no answer" and excluded from the base.
#' @param option_codes Character. Vector of option codes in display order.
#' @param option_labels Character. Display labels parallel to option_codes.
#' @param weights Numeric or NULL. Respondent weights (length = n).
#' @param focal_buyer Integer/Logical or NULL. 1/TRUE for respondents who
#'   bought the focal brand in the target window, 0/FALSE for non-buyers.
#'   When NULL the buyer_cut sub-result is NULL (no focal pen data).
#' @param buyer_tiers Character or NULL. Vector of "Light"/"Medium"/"Heavy"
#'   labels (or NA for non-buyers) parallel to values. When NULL the
#'   tier_cut sub-result is NULL.
#' @param pen_mat Numeric matrix or NULL. Respondent x brand 0/1 indicator
#'   (any positive value = "this respondent buys this brand"). Required for
#'   the brand_cut matrix; if NULL only total/buyer_cut/tier_cut are returned.
#' @param brand_codes Character. Brand codes parallel to columns of pen_mat.
#' @param brand_labels Character or NULL. Display labels parallel to
#'   \code{brand_codes}. Falls back to brand_codes when NULL.
#' @param conf_level Numeric. Confidence level for Wilson CIs (default 0.95).
#'
#' @return List with status PASS/REFUSED and:
#'   \item{total}{Data frame: Code | Label | Order | n | Pct | CI_Lower | CI_Upper}
#'   \item{buyer_cut}{NULL or list(buyer = df, non_buyer = df) with same columns}
#'   \item{tier_cut}{NULL or list(light = df, medium = df, heavy = df)}
#'   \item{brand_cut}{NULL or data frame keyed by BrandCode + Base_n + Pct_<CODE>}
#'   \item{n_total}{Unweighted respondents with valid (non-NA) value}
#'   \item{n_respondents}{Total rows in input}
#'
#' @export
run_demographic_question <- function(values,
                                     option_codes,
                                     option_labels,
                                     weights      = NULL,
                                     focal_buyer  = NULL,
                                     buyer_tiers  = NULL,
                                     pen_mat      = NULL,
                                     brand_codes  = NULL,
                                     brand_labels = NULL,
                                     conf_level   = 0.95) {

  guard <- .demo_guard_inputs(values, option_codes, option_labels, weights)
  if (identical(guard$status, "REFUSED")) return(guard)

  n_rows <- length(values)
  w      <- .demo_normalise_weights(weights, n_rows)

  total_df <- .demo_distribution(values, option_codes, option_labels,
                                 mask = rep(TRUE, n_rows), w = w,
                                 conf_level = conf_level)

  buyer_cut <- .demo_buyer_cut(values, option_codes, option_labels,
                                focal_buyer, w, conf_level)

  tier_cut <- .demo_tier_cut(values, option_codes, option_labels,
                              buyer_tiers, w, conf_level)

  brand_cut <- .demo_brand_cut(values, option_codes, pen_mat,
                                brand_codes, brand_labels, w, conf_level)

  list(
    status        = "PASS",
    total         = total_df,
    buyer_cut     = buyer_cut,
    tier_cut      = tier_cut,
    brand_cut     = brand_cut,
    n_total       = sum(!is.na(values)),
    n_respondents = n_rows,
    weighted      = !is.null(weights),
    conf_level    = conf_level
  )
}


# ==============================================================================
# INTERNAL: BUYER + TIER CUTS
# ==============================================================================
# Buyer cut splits the sample into focal-brand buyers vs non-buyers using
# the provided 0/1 indicator. Tier cut applies only to focal buyers and uses
# the buyer_tiers vector (NA for non-buyers).

.demo_buyer_cut <- function(values, codes, labels, focal_buyer, w, conf_level) {
  if (is.null(focal_buyer)) return(NULL)
  if (length(focal_buyer) != length(values)) return(NULL)
  is_buyer <- !is.na(focal_buyer) & as.integer(focal_buyer) > 0L
  is_non   <- !is.na(focal_buyer) & as.integer(focal_buyer) == 0L
  list(
    buyer     = .demo_distribution(values, codes, labels, is_buyer, w, conf_level),
    non_buyer = .demo_distribution(values, codes, labels, is_non,   w, conf_level)
  )
}


.demo_tier_cut <- function(values, codes, labels, buyer_tiers, w, conf_level) {
  if (is.null(buyer_tiers)) return(NULL)
  if (length(buyer_tiers) != length(values)) return(NULL)
  tiers  <- toupper(trimws(as.character(buyer_tiers)))
  light  <- !is.na(tiers) & tiers == "LIGHT"
  medium <- !is.na(tiers) & tiers == "MEDIUM"
  heavy  <- !is.na(tiers) & tiers == "HEAVY"
  if (!any(light) && !any(medium) && !any(heavy)) return(NULL)
  list(
    light  = .demo_distribution(values, codes, labels, light,  w, conf_level),
    medium = .demo_distribution(values, codes, labels, medium, w, conf_level),
    heavy  = .demo_distribution(values, codes, labels, heavy,  w, conf_level)
  )
}


# ==============================================================================
# INTERNAL: BRAND CUT (brand x option matrix)
# ==============================================================================
# For every brand: filter to that brand's buyers (pen > 0), then compute the
# distribution over the option list. Returns one row per brand with Pct_<CODE>
# columns. CIs are returned in long form alongside (CI_<CODE>_Lower/Upper).

.demo_brand_cut <- function(values, codes, pen_mat, brand_codes,
                             brand_labels, w, conf_level) {
  if (is.null(pen_mat) || is.null(brand_codes) || length(brand_codes) == 0L) {
    return(NULL)
  }
  pen_mat <- as.matrix(pen_mat)
  if (ncol(pen_mat) != length(brand_codes)) return(NULL)
  if (nrow(pen_mat) != length(values)) return(NULL)
  if (is.null(brand_labels) || length(brand_labels) != length(brand_codes)) {
    brand_labels <- brand_codes
  }

  per_brand <- lapply(seq_along(brand_codes), function(b) {
    is_buyer <- pen_mat[, b] > 0 & !is.na(pen_mat[, b])
    base_n   <- as.integer(sum(is_buyer))
    dist_df  <- .demo_distribution(values, codes, codes,
                                    is_buyer, w, conf_level)
    pct_cells <- stats::setNames(as.list(dist_df$Pct), paste0("Pct_", codes))
    lo_cells  <- stats::setNames(as.list(dist_df$CI_Lower),
                                 paste0("CI_Lower_", codes))
    hi_cells  <- stats::setNames(as.list(dist_df$CI_Upper),
                                 paste0("CI_Upper_", codes))
    as.data.frame(c(list(BrandCode  = brand_codes[b],
                          BrandLabel = brand_labels[b],
                          Base_n     = base_n),
                     pct_cells, lo_cells, hi_cells),
                   stringsAsFactors = FALSE)
  })
  do.call(rbind, per_brand)
}


# ==============================================================================
# INTERNAL: DISTRIBUTION + WILSON CI ENGINE
# ==============================================================================

.demo_distribution <- function(values, codes, labels, mask, w, conf_level) {
  base_w <- sum(w[mask & !is.na(values)])
  base_n <- as.integer(sum(mask & !is.na(values)))

  ns  <- vapply(codes, function(cd) {
    as.integer(sum(mask & !is.na(values) & as.character(values) == cd))
  }, integer(1L))

  pcts <- vapply(codes, function(cd) {
    if (base_w <= 0) return(NA_real_)
    100 * sum(w[mask & !is.na(values) & as.character(values) == cd]) / base_w
  }, numeric(1L))

  ci_pairs <- lapply(seq_along(codes), function(i) {
    .demo_wilson_ci(pcts[i] / 100, base_n, conf_level)
  })

  data.frame(
    Code      = codes,
    Label     = labels,
    Order     = seq_along(codes),
    n         = ns,
    Pct       = round(pcts, 1),
    CI_Lower  = vapply(ci_pairs, function(p) round(100 * p$lower, 1), numeric(1L)),
    CI_Upper  = vapply(ci_pairs, function(p) round(100 * p$upper, 1), numeric(1L)),
    Base_n    = base_n,
    stringsAsFactors = FALSE
  )
}


# Wilson score interval. Returns NA pair when n is zero or p is NA.
# Reference: Wilson EB (1927); Brown, Cai & DasGupta (2001).
.demo_wilson_ci <- function(p, n, conf_level = 0.95) {
  if (is.na(p) || n <= 0L) return(list(lower = NA_real_, upper = NA_real_))
  z   <- stats::qnorm(1 - (1 - conf_level) / 2)
  z2  <- z * z
  den <- 1 + z2 / n
  cen <- (p + z2 / (2 * n)) / den
  rad <- z * sqrt((p * (1 - p) + z2 / (4 * n)) / n) / den
  list(lower = max(0, cen - rad), upper = min(1, cen + rad))
}


.demo_normalise_weights <- function(weights, n_rows) {
  w <- if (is.null(weights)) rep(1, n_rows) else as.numeric(weights)
  w[is.na(w) | w < 0] <- 0
  w
}


# ==============================================================================
# INTERNAL: GUARDS + REFUSAL HELPER
# ==============================================================================

.demo_refuse <- function(code, message, how_to_fix = NULL) {
  out <- list(status = "REFUSED", code = code, message = message)
  if (!is.null(how_to_fix)) out$how_to_fix <- how_to_fix
  cat(sprintf("\n[TURAS Brand/Demographics] REFUSED %s: %s\n", code, message))
  out
}


.demo_guard_inputs <- function(values, codes, labels, weights) {
  if (is.null(values) || length(values) == 0L) {
    return(.demo_refuse("DATA_NO_INPUT",
                         "Demographic question values vector is empty.",
                         "Pass the data column for this question."))
  }
  if (is.null(codes) || length(codes) == 0L) {
    return(.demo_refuse("CFG_NO_OPTIONS",
                         "No option codes supplied for this demographic question.",
                         "Add rows to the Options sheet keyed by the question code."))
  }
  if (length(codes) != length(labels)) {
    return(.demo_refuse("CFG_LABELS_LENGTH_MISMATCH",
                         sprintf("option_labels length (%d) != option_codes length (%d).",
                                 length(labels), length(codes))))
  }
  if (!is.null(weights) && length(weights) != length(values)) {
    return(.demo_refuse("DATA_WEIGHTS_MISMATCH",
                         sprintf("weights length (%d) != values length (%d).",
                                 length(weights), length(values))))
  }
  list(status = "PASS")
}


# ==============================================================================
# ROLE / OPTION RESOLUTION
# ==============================================================================
# Demographics rely on either:
#   (a) the survey-structure Options sheet (rows where Code = QuestionCode), or
#   (b) the role-registry OptionMap sheet (rows where Scale = OptionMapScale).
# This resolver returns the parallel codes/labels vector regardless of which
# of the two pathways the project uses.

#' Resolve a demographic role to a data column + option list
#'
#' @param structure List. A loaded survey structure.
#' @param role Character. Exact role name (e.g. "demo.AGE").
#' @return List with column (character), codes, labels (parallel character
#'   vectors), question_text, and variable_type. NULL when the role cannot
#'   be resolved (caller silently skips that question).
#' @export
resolve_demographic_role <- function(structure, role) {

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

  opts <- .demo_lookup_options(structure, client_code, scale_name)
  if (is.null(opts)) return(NULL)

  list(
    role          = role,
    column        = client_code,
    question_text = question_text,
    short_label   = short_label,
    variable_type = variable_type,
    codes         = opts$codes,
    labels        = opts$labels
  )
}


# Look up option codes/labels for a question. Tries Options sheet first
# (QuestionCode column = question_code), then falls back to OptionMap by Scale.
# Survey_Structure schema: Options sheet uses QuestionCode | OptionText |
# DisplayText | DisplayOrder | ShowInOutput. OptionMap uses Scale |
# ClientCode | Role | ClientLabel | OrderIndex.
.demo_lookup_options <- function(structure, question_code, scale_name) {

  opts <- structure$options
  if (!is.null(opts) && nrow(opts) > 0L && "QuestionCode" %in% names(opts)) {
    rows <- opts[!is.na(opts$QuestionCode) &
                   trimws(as.character(opts$QuestionCode)) == question_code,
                  , drop = FALSE]
    # Filter to ShowInOutput = Y (or unspecified — default visible)
    if (nrow(rows) > 0L && "ShowInOutput" %in% names(rows)) {
      keep <- is.na(rows$ShowInOutput) |
              toupper(trimws(as.character(rows$ShowInOutput))) %in% c("", "Y", "YES")
      rows <- rows[keep, , drop = FALSE]
    }
    if (nrow(rows) > 0L &&
        all(c("OptionText", "DisplayText") %in% names(rows))) {
      if ("DisplayOrder" %in% names(rows)) {
        ord <- suppressWarnings(as.numeric(rows$DisplayOrder))
        rows <- rows[order(ifelse(is.na(ord), 999, ord)), , drop = FALSE]
      }
      return(list(codes  = trimws(as.character(rows$OptionText)),
                  labels = as.character(rows$DisplayText)))
    }
  }

  omap <- structure$optionmap
  if (!is.null(omap) && nrow(omap) > 0L && nzchar(scale_name) &&
      "Scale" %in% names(omap)) {
    rows <- omap[!is.na(omap$Scale) &
                   trimws(as.character(omap$Scale)) == scale_name, , drop = FALSE]
    if (nrow(rows) > 0L &&
        all(c("ClientCode", "ClientLabel") %in% names(rows))) {
      if ("OrderIndex" %in% names(rows)) {
        ord <- suppressWarnings(as.numeric(rows$OrderIndex))
        rows <- rows[order(ifelse(is.na(ord), 999, ord)), , drop = FALSE]
      }
      return(list(codes  = trimws(as.character(rows$ClientCode)),
                  labels = as.character(rows$ClientLabel)))
    }
  }

  NULL
}


# ==============================================================================
# V2: ROLE-MAP-DRIVEN DEMOGRAPHIC RESOLUTION
# ==============================================================================

#' Resolve a demographic role from a v2 role map
#'
#' v2 alternative to \code{resolve_demographic_role()}. The legacy resolver
#' walks a Survey_Structure QuestionMap sheet; the v2 resolver reads the
#' inferred entry from \code{build_brand_role_map()}. The role naming
#' convention is \code{demographics.\{key\}} (lowercase) — e.g.
#' \code{demographics.age} for the column \code{DEMO_AGE}.
#'
#' Option codes/labels come from the survey structure's Options sheet
#' (preferred) or, when missing, from the OptionMap sheet keyed by the
#' role's \code{option_scale}. Returns NULL when the role can't be
#' resolved or the data column is absent so the caller can skip
#' silently.
#'
#' @param role_map Named list from \code{build_brand_role_map()}.
#' @param role Character. Role name (e.g. \code{"demographics.age"}).
#' @param structure List with \code{options} (and optionally
#'   \code{optionmap}) data frames.
#' @return List with \code{role}, \code{column}, \code{question_text},
#'   \code{short_label}, \code{variable_type}, \code{codes},
#'   \code{labels}; or NULL.
#' @export
resolve_demographic_role_v2 <- function(role_map, role, structure) {
  if (is.null(role_map) || is.null(role) || is.na(role) ||
      !nzchar(as.character(role))) return(NULL)
  entry <- role_map[[as.character(role)]]
  if (is.null(entry) || is.null(entry$column_root) ||
      !nzchar(entry$column_root)) return(NULL)

  column <- entry$column_root
  question_text <- entry$question_text %||% column
  scale_name    <- entry$option_scale  %||% ""
  variable_type <- entry$variable_type %||% "Single_Response"

  opts <- .demo_lookup_options(structure, column, scale_name)
  if (is.null(opts)) return(NULL)

  list(
    role          = role,
    column        = column,
    question_text = question_text,
    short_label   = question_text,
    variable_type = variable_type,
    codes         = opts$codes,
    labels        = opts$labels
  )
}


#' Build a demographics-question record from a v2 role
#'
#' Convenience wrapper around \code{resolve_demographic_role_v2()} +
#' \code{run_demographic_question()} that produces the record shape
#' \code{build_demographics_panel_data()} expects. Returns NULL when the
#' role is unresolvable or its data column is missing.
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()}.
#' @param role Character. Role name (e.g. \code{"demographics.age"}).
#' @param structure List with \code{options} data frame.
#' @param weights Numeric vector or NULL.
#' @param focal_buyer Numeric/Logical vector or NULL.
#' @param buyer_tiers Character vector or NULL.
#' @param pen_mat Numeric matrix or NULL.
#' @param brand_codes Character vector or NULL.
#' @param brand_labels Character vector or NULL.
#' @return Named list ready for \code{build_demographics_panel_data()}, or NULL.
#' @export
demographic_question_from_role_v2 <- function(data, role_map, role, structure,
                                              weights = NULL,
                                              focal_buyer = NULL,
                                              buyer_tiers = NULL,
                                              pen_mat = NULL,
                                              brand_codes = NULL,
                                              brand_labels = NULL) {
  spec <- resolve_demographic_role_v2(role_map, role, structure)
  if (is.null(spec)) return(NULL)
  if (!spec$column %in% names(data)) return(NULL)

  res <- run_demographic_question(
    values        = data[[spec$column]],
    option_codes  = spec$codes,
    option_labels = spec$labels,
    weights       = weights,
    focal_buyer   = focal_buyer,
    buyer_tiers   = buyer_tiers,
    pen_mat       = pen_mat,
    brand_codes   = brand_codes,
    brand_labels  = brand_labels
  )
  list(
    role           = spec$role,
    column         = spec$column,
    question_text  = spec$question_text,
    short_label    = spec$short_label,
    variable_type  = spec$variable_type,
    codes          = spec$codes,
    labels         = spec$labels,
    is_synthetic   = FALSE,
    synthetic_kind = NA_character_,
    result         = res
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Demographics element loaded (v%s)",
                  BRAND_DEMOGRAPHICS_VERSION))
}
