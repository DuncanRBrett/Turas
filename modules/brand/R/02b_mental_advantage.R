# ==============================================================================
# BRAND MODULE - MENTAL ADVANTAGE (ROMANIUK)
# ==============================================================================
# Implements Romaniuk's Mental Advantage analysis for a stimulus x brand
# linkage tensor. Mental Advantage isolates "true" competitive strength on a
# CEP or brand-image attribute by removing two confounds:
#   1. Brand size effect: bigger brands attract more associations regardless
#      of fit.
#   2. Prototypicality: some stimuli are universally high (or low) across
#      every brand in the category.
#
# For each (stimulus s, brand b) the expected count is calculated as
#   expected[s,b] = row_total[s] * col_total[b] / grand_total
# and the Mental Advantage score is
#   ma[s,b] = (actual[s,b] - expected[s,b]) / n_respondents * 100   (pp)
#
# Significance: standardised chi-square residual
#   z[s,b] = (actual[s,b] - expected[s,b]) / sqrt(expected[s,b])
# Significant at 95% when |z| > 1.96. Bootstrap CIs are a documented stretch
# (see About drawer in panel) — not implemented in v1.
#
# Decision categorisation follows Quantilope/Romaniuk practice:
#   defend   if ma_score >=  +threshold_pp  (default 5pp)
#   build    if ma_score <=  -threshold_pp
#   maintain otherwise
#
# REFERENCES:
#   Romaniuk, J. (2022). Better Brand Health.
#   Quantilope (2024). Brand Health Tracking Series: Mental Advantage Analysis.
# VERSION: 1.0
# ==============================================================================

MENTAL_ADVANTAGE_VERSION <- "1.0"

#' Default threshold (in percentage points) for Defend/Build classification.
#' @keywords internal
MA_DEFAULT_THRESHOLD_PP <- 5

#' z-score threshold for the standardised chi-square residual (95% two-sided).
#' @keywords internal
MA_SIG_Z_THRESHOLD <- 1.96


# ==============================================================================
# SECTION 1: COUNT MATRIX FROM A LINKAGE TENSOR
# ==============================================================================

#' Aggregate a brand-keyed linkage tensor into a stimulus x brand count matrix
#'
#' For each (stimulus, brand) the cell holds either the unweighted count of
#' respondents who linked that brand to that stimulus, or the sum of weights
#' for those respondents when weights are supplied.
#'
#' @param linkage_tensor Named list. Each element is a respondents x stimuli
#'   binary matrix; names are brand codes and matrix columns share the same
#'   stimulus codes.
#' @param codes Character vector. Stimulus codes in the desired output order.
#' @param weights Numeric vector or NULL. Per-respondent weights.
#' @return Numeric matrix with rows = stimuli, cols = brand codes.
#' @keywords internal
.ma_count_matrix <- function(linkage_tensor, codes, weights = NULL) {
  brand_codes <- names(linkage_tensor)
  if (length(brand_codes) == 0)
    stop("[CALC_MA_NO_BRANDS] linkage_tensor has no brands", call. = FALSE)
  if (length(codes) == 0)
    stop("[CALC_MA_NO_CODES] codes vector is empty", call. = FALSE)

  n_brands <- length(brand_codes)
  n_stim   <- length(codes)
  out <- matrix(0, nrow = n_stim, ncol = n_brands,
                dimnames = list(codes, brand_codes))

  for (b in seq_along(brand_codes)) {
    bm <- linkage_tensor[[brand_codes[b]]]
    if (is.null(bm)) next
    cols <- intersect(codes, colnames(bm))
    if (length(cols) == 0) next
    for (s in cols) {
      v <- bm[, s]
      v[is.na(v)] <- 0
      out[s, b] <- if (is.null(weights)) sum(v) else sum(weights * v)
    }
  }

  out
}


# ==============================================================================
# SECTION 2: PER-STIMULUS PENETRATION (ANY BRAND)
# ==============================================================================

#' Calculate stimulus penetration — % of respondents linking any brand
#'
#' Used as the X-axis of the strategic quadrant: a stimulus that no one ever
#' associates with any brand is uninteresting, regardless of any single
#' brand's relative advantage on it.
#'
#' @param linkage_tensor Named list of brand matrices.
#' @param codes Character vector. Stimulus codes.
#' @param weights Numeric vector or NULL.
#' @return Numeric vector (0..100), names = stimulus codes.
#' @keywords internal
.ma_stimulus_penetration <- function(linkage_tensor, codes, weights = NULL) {
  if (length(linkage_tensor) == 0) return(stats::setNames(numeric(0), codes))
  n_resp <- nrow(linkage_tensor[[1]])
  if (is.null(n_resp) || n_resp == 0) return(stats::setNames(rep(0, length(codes)), codes))

  any_link <- matrix(0L, nrow = n_resp, ncol = length(codes),
                     dimnames = list(NULL, codes))
  for (bm in linkage_tensor) {
    if (is.null(bm)) next
    cols <- intersect(codes, colnames(bm))
    if (length(cols) == 0) next
    any_link[, cols] <- pmax(any_link[, cols], bm[, cols])
  }

  if (is.null(weights)) {
    stats::setNames(round(colMeans(any_link) * 100, 1), codes)
  } else {
    w_total <- sum(weights)
    pct <- if (w_total > 0)
      colSums(any_link * weights) / w_total * 100 else rep(0, length(codes))
    stats::setNames(round(pct, 1), codes)
  }
}


# ==============================================================================
# SECTION 3: DECISION CLASSIFIER
# ==============================================================================

#' Categorise an MA score into Defend / Build / Maintain
#'
#' @param ma_score Numeric. MA score in percentage points (can be NA).
#' @param threshold_pp Numeric. Symmetric threshold around zero.
#' @return Character — "defend", "build", "maintain", or "na".
#' @keywords internal
.ma_classify_decision <- function(ma_score, threshold_pp = MA_DEFAULT_THRESHOLD_PP) {
  ifelse(is.na(ma_score), "na",
    ifelse(ma_score >=  threshold_pp, "defend",
      ifelse(ma_score <= -threshold_pp, "build", "maintain")))
}


# ==============================================================================
# SECTION 4: MAIN ENTRY POINT
# ==============================================================================

#' Calculate Mental Advantage for a stimulus x brand linkage tensor
#'
#' Computes Romaniuk's Mental Advantage matrix together with significance
#' (standardised chi-square residuals) and Defend/Build/Maintain decisions.
#' Pure analytics — no I/O, no presentation. Throws on programming errors;
#' returns zero matrices on degenerate but legal data (zero linkage, single
#' brand, single stimulus).
#'
#' @param linkage_tensor Named list of brand matrices, as produced by
#'   \code{build_cep_linkage_from_matrix()} or \code{build_cep_linkage()}.
#' @param codes Character vector of stimulus codes (CEP or attribute).
#' @param weights Numeric vector or NULL.
#' @param n_respondents Integer. Survey base for converting differences into
#'   percentage points. Defaults to nrow of the first brand matrix.
#' @param threshold_pp Numeric. Defend/Build threshold in pp (default 5).
#'
#' @return List with:
#'   \item{status}{"PASS"}
#'   \item{version}{Module version}
#'   \item{threshold_pp}{Threshold used}
#'   \item{brand_codes}{Character vector}
#'   \item{stim_codes}{Character vector}
#'   \item{n_respondents}{Integer (or weighted total when weights supplied)}
#'   \item{grand_total}{Total brand-stimulus links}
#'   \item{stim_links}{Per-stimulus row totals}
#'   \item{brand_links}{Per-brand column totals}
#'   \item{actual}{Stimulus x brand count matrix}
#'   \item{expected}{Expected counts under independence}
#'   \item{advantage}{MA score matrix (pp)}
#'   \item{std_residual}{Standardised residuals}
#'   \item{is_significant}{Logical matrix, |z|>1.96}
#'   \item{decision}{Character matrix of decisions}
#'   \item{stim_penetration}{% of respondents linking any brand per stimulus}
#'
#' @export
calculate_mental_advantage <- function(linkage_tensor, codes,
                                       weights = NULL,
                                       n_respondents = NULL,
                                       threshold_pp = MA_DEFAULT_THRESHOLD_PP) {

  .ma_refuse <- function(code, problem, how_to_fix) {
    if (exists("brand_refuse", mode = "function")) {
      brand_refuse(code = code, title = "Mental Advantage Input Error",
                   problem = problem,
                   why_it_matters = "Cannot compute advantage matrix without valid inputs.",
                   how_to_fix = how_to_fix)
    } else {
      stop(sprintf("[%s] %s", code, problem), call. = FALSE)
    }
  }

  if (!is.list(linkage_tensor) || length(linkage_tensor) == 0)
    return(.ma_refuse("CALC_MA_INVALID_TENSOR",
      "linkage_tensor must be a non-empty named list",
      "Pass a named list where each element is a respondents x stimuli binary matrix"))
  if (length(codes) == 0)
    return(.ma_refuse("CALC_MA_NO_CODES",
      "codes must be a non-empty character vector",
      "Pass the stimulus (CEP or attribute) codes in the desired output order"))
  if (!is.numeric(threshold_pp) || length(threshold_pp) != 1 || threshold_pp < 0)
    return(.ma_refuse("CALC_MA_INVALID_THRESHOLD",
      "threshold_pp must be a single non-negative number",
      sprintf("Default is %g; pass a numeric scalar >= 0", MA_DEFAULT_THRESHOLD_PP)))

  brand_codes <- names(linkage_tensor)
  if (is.null(brand_codes) || any(!nzchar(brand_codes)))
    return(.ma_refuse("CALC_MA_UNNAMED_BRANDS",
      "linkage_tensor must be a *named* list of brand matrices",
      "Set names(linkage_tensor) to the brand codes before calling"))

  if (is.null(n_respondents)) {
    n_respondents <- if (is.null(weights)) nrow(linkage_tensor[[1]]) else sum(weights)
  }
  if (!is.numeric(n_respondents) || n_respondents <= 0)
    return(.ma_refuse("CALC_MA_NO_RESPONDENTS",
      "n_respondents must be > 0",
      "Check weights sum or ensure linkage_tensor matrices have at least one row"))

  actual <- .ma_count_matrix(linkage_tensor, codes, weights = weights)

  stim_links  <- rowSums(actual)
  brand_links <- colSums(actual)
  grand_total <- sum(actual)

  expected <- if (grand_total > 0) {
    outer(stim_links, brand_links) / grand_total
  } else {
    matrix(0, nrow = nrow(actual), ncol = ncol(actual),
           dimnames = dimnames(actual))
  }

  advantage    <- (actual - expected) / n_respondents * 100
  safe_expected <- ifelse(expected > 0, expected, NA_real_)
  # Pearson standardised residual — exact for unweighted data.
  # Under rim weighting the expected cell counts still use observed marginals
  # so this approximates the design-corrected residual; a Rao-Scott correction
  # would be more rigorous but is not material for the typical weight ranges
  # seen in brand tracking studies.
  std_residual  <- (actual - expected) / sqrt(safe_expected)
  std_residual[!is.finite(std_residual)] <- 0
  is_significant <- abs(std_residual) > MA_SIG_Z_THRESHOLD

  decision_vals <- .ma_classify_decision(as.numeric(advantage), threshold_pp)
  decision <- matrix(decision_vals, nrow = nrow(actual), ncol = ncol(actual),
                     dimnames = dimnames(actual))

  stim_penetration <- .ma_stimulus_penetration(linkage_tensor, codes, weights)

  list(
    status           = "PASS",
    version          = MENTAL_ADVANTAGE_VERSION,
    threshold_pp     = as.numeric(threshold_pp),
    brand_codes      = brand_codes,
    stim_codes       = codes,
    n_respondents    = as.numeric(n_respondents),
    grand_total      = as.numeric(grand_total),
    stim_links       = stim_links,
    brand_links      = brand_links,
    actual           = actual,
    expected         = expected,
    advantage        = advantage,
    std_residual     = std_residual,
    is_significant   = is_significant,
    decision         = decision,
    stim_penetration = stim_penetration
  )
}


# ==============================================================================
# SECTION 5: SAFE WRAPPER FOR ORCHESTRATION
# ==============================================================================

#' Run Mental Advantage with graceful degradation
#'
#' Wraps \code{calculate_mental_advantage()} so that any failure (including
#' the function not being loaded) accumulates a warning and returns NULL
#' instead of breaking the rest of the MA result. Used by
#' \code{run_mental_availability()}.
#' @keywords internal
.ma_safe_advantage <- function(linkage_tensor, codes, weights, n_resp,
                                label = "stimulus", warnings_acc = NULL) {
  if (!exists("calculate_mental_advantage", mode = "function")) {
    if (is.function(warnings_acc))
      warnings_acc(sprintf("Mental Advantage skipped for %s: analytics not loaded", label))
    return(NULL)
  }
  tryCatch(
    calculate_mental_advantage(linkage_tensor, codes,
                                weights = weights,
                                n_respondents = n_resp),
    error = function(e) {
      if (is.function(warnings_acc))
        warnings_acc(sprintf("Mental Advantage failed for %s: %s", label, e$message))
      NULL
    }
  )
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Mental Advantage element loaded (v%s)",
                  MENTAL_ADVANTAGE_VERSION))
}
