# ==============================================================================
# BRAND MODULE - DEMOGRAPHICS ELEMENT
# ==============================================================================
# SIZE-EXCEPTION: ~315 active lines. The file is a cohesive engine pipeline —
# one `run_demographic_question()` entry point and five private helper
# sections (total distribution, focal-brand buyer/non-buyer cut, light/medium/
# heavy tier cut, per-brand audience-share cut, per-brand penetration-in-
# option + cat-wide baseline). Splitting helpers across files would fragment
# a single computation flow that's only readable end-to-end here.
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
#   * total                   - weighted % of all respondents in each option
#   * buyer_cut               - % among focal-brand BUYERS vs NON-BUYERS
#   * tier_cut                - % among LIGHT / MEDIUM / HEAVY focal buyers
#   * brand_cut               - % among each brand's BUYERS  (audience share)
#   * brand_nonbuyer_cut      - % among each brand's NON-BUYERS (audience share)
#   * brand_penetration_long  - within-option penetration per brand (the
#                                primary panel cell metric — "% of 30-35s
#                                who buy IPK")
#   * brand_total_penetration - per-brand cat-wide penetration (the heatmap
#                                baseline for brand_penetration_long)
#
# All percentages are weighted-aware. Wilson 95% CIs accompany every cell.
#
# VERSION: 2.0
# ==============================================================================

BRAND_DEMOGRAPHICS_VERSION <- "2.0"


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
#'   \item{buyer_cut}{NULL or list(buyer = df, non_buyer = df) with same columns. Focal-brand only.}
#'   \item{tier_cut}{NULL or list(light = df, medium = df, heavy = df). Focal-brand only.}
#'   \item{brand_cut}{NULL or data frame keyed by BrandCode + Base_n + Pct_<CODE>. Distribution of each brand's BUYERS across the option list.}
#'   \item{brand_nonbuyer_cut}{NULL or data frame, same shape as \code{brand_cut}. Distribution of each brand's NON-BUYERS (pen == 0, not NA) across the option list.}
#'   \item{brand_penetration_long}{NULL or data frame: one row per brand, columns Pct_<code> = % of respondents in option <code> who buy this brand, Base_n_<code> = unweighted known-base for that option. The panel cell metric — answers "is this brand over/under-performing in this demographic option?" at a glance.}
#'   \item{brand_total_penetration}{NULL or data frame: one row per brand, Pct_Total = cat-wide penetration (% of all respondents who buy this brand). Legend / context only — not used as the cell-shading baseline (see \code{option_avg_penetration}).}
#'   \item{option_avg_penetration}{Named numeric vector keyed by option_code: the per-option mean penetration across all brands. THIS is the competitive baseline used by the panel — table Cat-avg column and chart marker both read from this vector in penetration mode, and brand cells are shaded vs this baseline.}
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

  brand_nonbuyer_cut <- .demo_brand_nonbuyer_cut(
    values, option_codes, pen_mat,
    brand_codes, brand_labels, w, conf_level)

  brand_penetration_long <- .demo_brand_buyer_penetration(
    values, option_codes, pen_mat,
    brand_codes, brand_labels, w, conf_level)

  brand_total_penetration <- .demo_brand_total_penetration(
    pen_mat, brand_codes, brand_labels, w)

  option_avg_penetration <- .demo_option_avg_penetration(
    brand_penetration_long, option_codes)

  list(
    status                  = "PASS",
    total                   = total_df,
    buyer_cut               = buyer_cut,
    tier_cut                = tier_cut,
    brand_cut               = brand_cut,
    brand_nonbuyer_cut      = brand_nonbuyer_cut,
    brand_penetration_long  = brand_penetration_long,
    brand_total_penetration = brand_total_penetration,
    option_avg_penetration  = option_avg_penetration,
    n_total                 = sum(!is.na(values)),
    n_respondents           = n_rows,
    weighted                = !is.null(weights),
    conf_level              = conf_level
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
# INTERNAL: BRAND CUTS (brand x option matrices)
# ==============================================================================
# Two parallel views of the demographic distribution, one row per brand:
#   .demo_brand_cut          — buyers of that brand   (pen > 0)
#   .demo_brand_nonbuyer_cut — non-buyers of that brand (pen == 0, not NA)
#
# Both share .demo_per_brand_distribution which turns a respondent-x-brand
# logical mask matrix into the long-format Pct_<CODE> + CI_<CODE>_*
# row-per-brand data frame the panel renderer consumes.
#
# Non-buyer semantics:
#   pen == 0   -> respondent was asked and did NOT pick this brand (non-buyer)
#   pen >  0   -> respondent picked the brand (buyer)
#   pen == NA  -> respondent was not asked (routing skip; cross-category run);
#                 excluded from BOTH cuts to avoid inflating the non-buyer
#                 base with respondents who were never given the chance to
#                 answer. The per-brand Base_n reflects this exclusion.

.demo_brand_cut <- function(values, codes, pen_mat, brand_codes,
                             brand_labels, w, conf_level) {
  ctx <- .demo_brand_cut_setup(pen_mat, brand_codes, brand_labels,
                                length(values))
  if (is.null(ctx)) return(NULL)
  buyer_mask <- ctx$pen_mat > 0 & !is.na(ctx$pen_mat)
  .demo_per_brand_distribution(values, codes, buyer_mask,
                                brand_codes, ctx$brand_labels,
                                w, conf_level)
}


.demo_brand_nonbuyer_cut <- function(values, codes, pen_mat, brand_codes,
                                      brand_labels, w, conf_level) {
  ctx <- .demo_brand_cut_setup(pen_mat, brand_codes, brand_labels,
                                length(values))
  if (is.null(ctx)) return(NULL)
  nonbuyer_mask <- !is.na(ctx$pen_mat) & ctx$pen_mat == 0
  .demo_per_brand_distribution(values, codes, nonbuyer_mask,
                                brand_codes, ctx$brand_labels,
                                w, conf_level)
}


# ==============================================================================
# INTERNAL: PENETRATION-IN-OPTION (the v2 panel metric)
# ==============================================================================
# Cell semantics:
#   "% of respondents in this demographic option who buy this brand"
# i.e. the within-demo penetration. Different from .demo_brand_cut, which is
# the share of a brand's audience that falls in each option. Penetration-in-
# option lets the panel render buyer% + non-buyer% summing to 100% per cell
# and answer "is brand X over- or under-performing in 30-35?" at a glance.
#
# NA handling — NA pen entries (routing skips) are excluded from BOTH the
# numerator AND the per-option denominator so the buyer + complement still
# sum to 100% within the known base. Base_n_<code> exposes the option's
# unweighted known-base so the panel can warn on small-base cells.

.demo_brand_buyer_penetration <- function(values, codes, pen_mat,
                                           brand_codes, brand_labels,
                                           w, conf_level) {
  ctx <- .demo_brand_cut_setup(pen_mat, brand_codes, brand_labels,
                                length(values))
  if (is.null(ctx)) return(NULL)

  # Per-option known-base counts (same for all brands — known-base is per
  # respondent x brand, but for IPK-style per-cat data NAs are uniform per
  # column). For NA-heavy multi-cat data we compute per-brand later if needed.
  per_brand <- lapply(seq_along(brand_codes), function(b) {
    pen_b      <- ctx$pen_mat[, b]
    known      <- !is.na(pen_b)
    is_buyer   <- known & pen_b > 0

    pct_cells <- vapply(codes, function(cd) {
      mask_opt   <- !is.na(values) & as.character(values) == cd
      mask_known <- mask_opt & known
      base_w     <- sum(w[mask_known])
      if (base_w <= 0) return(NA_real_)
      100 * sum(w[mask_known & is_buyer]) / base_w
    }, numeric(1L))

    base_cells <- vapply(codes, function(cd) {
      mask_opt   <- !is.na(values) & as.character(values) == cd
      as.integer(sum(mask_opt & known))
    }, integer(1L))

    row <- c(
      list(BrandCode  = brand_codes[b],
           BrandLabel = brand_labels[b],
           Base_n     = as.integer(sum(known))),
      stats::setNames(as.list(pct_cells),  paste0("Pct_",    codes)),
      stats::setNames(as.list(base_cells), paste0("Base_n_", codes))
    )
    as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE)
  })
  do.call(rbind, per_brand)
}


# Per-option mean penetration across all brands. THE category-average
# baseline in penetration mode — answers "what's the typical brand's
# pen rate among 30-35s?". Per-row so the chart marker and the table's
# Cat-avg column can both move down the option list. NA brand cells are
# excluded from the mean (an option with zero respondents in one brand's
# known base shouldn't drag the option's typical rate to NA).
.demo_option_avg_penetration <- function(brand_pen_df, codes) {
  out <- stats::setNames(rep(NA_real_, length(codes)), codes)
  if (is.null(brand_pen_df) || !is.data.frame(brand_pen_df) ||
      nrow(brand_pen_df) == 0L) return(out)
  for (cd in codes) {
    col <- paste0("Pct_", cd)
    if (!col %in% names(brand_pen_df)) next
    vals <- brand_pen_df[[col]]
    if (all(is.na(vals))) next
    out[[cd]] <- mean(vals, na.rm = TRUE)
  }
  out
}


# Cat-wide penetration of each brand (single number per brand). Useful as
# legend context ("IPK overall pen = 16%") but no longer the cell-shading
# baseline — see .demo_option_avg_penetration for the per-row competitive
# baseline that drives both the chart marker and the table heatmap.
.demo_brand_total_penetration <- function(pen_mat, brand_codes, brand_labels,
                                           w) {
  ctx <- .demo_brand_cut_setup(pen_mat, brand_codes, brand_labels,
                                length(w))
  if (is.null(ctx)) return(NULL)

  out <- lapply(seq_along(brand_codes), function(b) {
    pen_b    <- ctx$pen_mat[, b]
    known    <- !is.na(pen_b)
    is_buyer <- known & pen_b > 0
    base_w   <- sum(w[known])
    pct      <- if (base_w > 0) 100 * sum(w[is_buyer]) / base_w
                else NA_real_
    data.frame(
      BrandCode  = brand_codes[b],
      BrandLabel = ctx$brand_labels[b],
      Pct_Total  = pct,
      Base_n     = as.integer(sum(known)),
      stringsAsFactors = FALSE, check.names = FALSE)
  })
  do.call(rbind, out)
}


# Shared input validation + coercion for both per-brand cuts. Returns NULL on
# any shape mismatch; otherwise a list with the coerced pen_mat + resolved
# brand_labels so the caller doesn't need to re-validate.
.demo_brand_cut_setup <- function(pen_mat, brand_codes, brand_labels, n_rows) {
  if (is.null(pen_mat) || is.null(brand_codes) || length(brand_codes) == 0L) {
    return(NULL)
  }
  pen_mat <- as.matrix(pen_mat)
  if (ncol(pen_mat) != length(brand_codes)) return(NULL)
  if (nrow(pen_mat) != n_rows) return(NULL)
  if (is.null(brand_labels) || length(brand_labels) != length(brand_codes)) {
    brand_labels <- brand_codes
  }
  list(pen_mat = pen_mat, brand_labels = brand_labels)
}


# Distribution of a categorical demographic across every brand, given a
# respondent-x-brand logical mask matrix (one column per brand, TRUE = include
# that respondent in that brand's cut). Same row shape as v1 brand_cut.
#
# IMPORTANT — column-name preservation. Option codes that contain spaces or
# punctuation (e.g. "Gauteng Metro", "R25-R35") would be silently munged by
# the default as.data.frame() name-fixer to "Pct_Gauteng.Metro" etc., which
# then breaks the downstream paste0("Pct_", codes) lookup in
# .demo_panel_brand_long. check.names = FALSE keeps the literal "Pct_<code>"
# names so the panel builder can find them.
.demo_per_brand_distribution <- function(values, codes, mask_mat,
                                          brand_codes, brand_labels,
                                          w, conf_level) {
  per_brand <- lapply(seq_along(brand_codes), function(b) {
    mask     <- mask_mat[, b]
    base_n   <- as.integer(sum(mask))
    dist_df  <- .demo_distribution(values, codes, codes,
                                    mask, w, conf_level)
    pct_cells <- stats::setNames(as.list(dist_df$Pct), paste0("Pct_", codes))
    lo_cells  <- stats::setNames(as.list(dist_df$CI_Lower),
                                 paste0("CI_Lower_", codes))
    hi_cells  <- stats::setNames(as.list(dist_df$CI_Upper),
                                 paste0("CI_Upper_", codes))
    as.data.frame(c(list(BrandCode  = brand_codes[b],
                          BrandLabel = brand_labels[b],
                          Base_n     = base_n),
                     pct_cells, lo_cells, hi_cells),
                   stringsAsFactors = FALSE,
                   check.names = FALSE)
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
resolve_demographic_role <- function(role_map, role, structure) {
  if (is.null(role_map) || is.null(role) || is.na(role) ||
      !nzchar(as.character(role))) return(NULL)
  entry <- role_map[[as.character(role)]]
  if (is.null(entry) || is.null(entry$column_root) ||
      !nzchar(entry$column_root)) return(NULL)

  column <- entry$column_root
  # %||% only catches NULL; entry$question_text is typically NA_character_
  # when no Questions-sheet row exists for the column (common when the
  # demographic is wired purely through a QuestionMap override). Use the
  # humanised role tail as the fallback ("demographics.age" -> "Age") so
  # the panel's question chips never render literal "NA".
  question_text <- .demo_resolve_question_text(entry$question_text,
                                                role, column)
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


# Derive a display label for a demographic question. Priority:
#   1. The QuestionText supplied on the Questions sheet (entry$question_text)
#   2. The humanised role suffix ("demographics.age" -> "Age", or
#      "demographics.household_income" -> "Household Income")
#   3. The data column name as last resort
.demo_resolve_question_text <- function(entry_qt, role, column) {
  if (!is.null(entry_qt) && !is.na(entry_qt) &&
      nzchar(trimws(as.character(entry_qt)))) {
    return(as.character(entry_qt))
  }
  tail <- sub("^demographics\\.", "", as.character(role))
  if (nzchar(tail) && !identical(tail, as.character(role))) {
    parts <- strsplit(tail, "[_.]")[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) > 0L) {
      humanised <- paste(
        toupper(substr(parts, 1L, 1L)),
        substr(parts, 2L, nchar(parts)),
        sep = "", collapse = " ")
      return(humanised)
    }
  }
  as.character(column)
}


#' Build a demographics-question record from a v2 role
#'
#' Convenience wrapper around \code{resolve_demographic_role()} +
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
demographic_question_from_role <- function(data, role_map, role, structure,
                                              weights = NULL,
                                              focal_buyer = NULL,
                                              buyer_tiers = NULL,
                                              pen_mat = NULL,
                                              brand_codes = NULL,
                                              brand_labels = NULL) {
  spec <- resolve_demographic_role(role_map, role, structure)
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
